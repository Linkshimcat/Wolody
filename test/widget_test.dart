import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wolody/main.dart';
import 'package:wolody/widgets/mood_card.dart';
import 'package:wolody/widgets/mood_picker_sheet.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ko_KR');
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('기분 기록하기'));
    await tester.pumpAndSettle();
  }

  CupertinoButton recordButton(WidgetTester tester) => tester
      .widget<CupertinoButton>(find.widgetWithText(CupertinoButton, '기록하기'));

  testWidgets('shows empty state, then records and lists a mood', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('아직 기록된 기분이 없어요.\n오늘의 기분을 기록해보세요!'), findsOneWidget);

    await tester.tap(find.text('기분 기록하기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('😄'));
    await tester.pump();

    await tester.enterText(find.byType(CupertinoTextField), '좋은 하루였다');
    await tester.tap(find.text('기록하기'));
    await tester.pumpAndSettle();

    expect(find.text('행복'), findsOneWidget);
    expect(find.text('좋은 하루였다'), findsOneWidget);
    expect(find.text('아직 기록된 기분이 없어요.\n오늘의 기분을 기록해보세요!'), findsNothing);
  });

  testWidgets('records multiple moods on one card', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('😄'));
    await tester.tap(find.text('😜'));
    await tester.pump();

    await tester.tap(find.text('기록하기'));
    await tester.pumpAndSettle();

    // 카드에는 선택한 기분들이 함께 표시된다.
    expect(find.text('행복 · 활발'), findsOneWidget);
  });

  testWidgets('tapping a selected mood again deselects it', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);

    // 선택 전에는 기록 버튼이 비활성 상태다.
    expect(recordButton(tester).onPressed, isNull);

    await tester.tap(find.text('😄'));
    await tester.pump();
    expect(recordButton(tester).onPressed, isNotNull);

    // 같은 이모지를 다시 누르면 선택이 해제된다.
    await tester.tap(find.text('😄'));
    await tester.pump();
    expect(recordButton(tester).onPressed, isNull);
  });

  testWidgets('dragging the sheet down dismisses it', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);

    expect(find.byType(MoodPickerSheet), findsOneWidget);

    await tester.drag(find.text('😄'), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(find.byType(MoodPickerSheet), findsNothing);
  });

  testWidgets('sends haptic feedback when selecting and recording', (
    WidgetTester tester,
  ) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await openSheet(tester);
    haptics.clear(); // 시트를 여는 탭에서 발생한 진동은 제외한다.

    await tester.tap(find.text('😄'));
    await tester.pump();
    expect(haptics, ['HapticFeedbackType.selectionClick']);

    await tester.tap(find.text('기록하기'));
    await tester.pumpAndSettle();
    expect(haptics, contains('HapticFeedbackType.mediumImpact'));
  });

  testWidgets('tapping a card edits the existing record in place', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'mood_entries': [
        jsonEncode({
          'id': 'keep-me',
          'date': DateTime.now().toIso8601String(),
          'emojis': ['😄'],
          'note': '수정 전 메모',
        }),
      ],
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('수정 전 메모'));
    await tester.pumpAndSettle();

    // 시트가 기존 내용으로 채워져 열린다.
    expect(find.text('수정 완료'), findsOne);
    expect(find.widgetWithText(CupertinoTextField, '수정 전 메모'), findsOne);

    // 기분을 바꾸고 메모를 고쳐 저장한다.
    // 뒤에 깔린 카드에도 같은 이모지가 있으므로 시트 안에서만 찾는다.
    Finder inSheet(String emoji) => find.descendant(
      of: find.byType(MoodPickerSheet),
      matching: find.text(emoji),
    );
    await tester.tap(inSheet('😄'));
    await tester.tap(inSheet('😢'));
    await tester.pump();
    await tester.enterText(find.byType(CupertinoTextField), '수정 후 메모');
    await tester.tap(find.text('수정 완료'));
    await tester.pumpAndSettle();

    expect(find.text('슬픔'), findsOne);
    expect(find.text('수정 후 메모'), findsOne);
    expect(find.text('수정 전 메모'), findsNothing);
    // 새 기록이 생기는 게 아니라 기존 기록이 바뀌어야 한다.
    expect(find.byType(MoodCard), findsOne);
  });

  testWidgets('calendar shows recorded moods and the selected day', (
    WidgetTester tester,
  ) async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'mood_entries': [
        jsonEncode({
          'id': '1',
          'date': today.toIso8601String(),
          'emojis': ['😄'],
          'note': '달력에서 보이는 기록',
        }),
      ],
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.calendar));
    await tester.pumpAndSettle();

    expect(find.text(DateFormat('yyyy년 M월', 'ko_KR').format(today)), findsOne);
    // 달력 칸의 이모지와 아래 카드의 이모지가 각각 하나씩 있어야 한다.
    expect(find.text('😄'), findsNWidgets(2));
    expect(find.text('달력에서 보이는 기록'), findsOne);
  });

  testWidgets('settings tab opens reminder settings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.gear_alt_fill));
    await tester.pumpAndSettle();

    expect(find.text('알림 받기'), findsOneWidget);
    // 알림이 꺼진 상태에서는 요일/시간 섹션이 보이지 않아야 한다.
    expect(find.text('요일'), findsNothing);
  });

  testWidgets('bottom nav switches tabs and the center button records', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // 홈 탭으로 시작한다.
    expect(find.text('오늘의 기분은?'), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.calendar));
    await tester.pumpAndSettle();
    expect(find.text('달력'), findsWidgets);
    expect(find.text('오늘의 기분은?'), findsNothing);

    // 달력 탭에 있어도 가운데 ⊕ 로 기록하면 홈으로 돌아온다.
    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('😄'));
    await tester.pump();
    await tester.tap(find.text('기록하기'));
    await tester.pumpAndSettle();

    expect(find.text('오늘의 기분은?'), findsOneWidget);
    expect(find.text('행복'), findsOneWidget);
  });
}
