import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wolody/models/mood_entry.dart';
import 'package:wolody/screens/calendar_screen.dart';
import 'package:wolody/screens/home_screen.dart';
import 'package:wolody/screens/profile_screen.dart';
import 'package:wolody/screens/root_screen.dart';
import 'package:wolody/services/mood_editor.dart';
import 'package:wolody/widgets/pressable.dart';
import 'package:wolody/widgets/wolody_toast.dart';

void main() {
  setUp(() async {
    await initializeDateFormatting('ko_KR');
    SharedPreferences.setMockInitialValues({});
  });

  Widget app(Widget home) => CupertinoApp(home: home);

  double pressScale(WidgetTester tester) => tester
      .widget<AnimatedScale>(
        find.descendant(
          of: find.byType(Pressable),
          matching: find.byType(AnimatedScale),
        ),
      )
      .scale;

  testWidgets('Pressable shrinks while pressed and springs back', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Center(
          child: Pressable(
            child: GestureDetector(
              onTap: () {},
              child: const ColoredBox(
                color: Color(0xFF346AE6),
                child: ColoredBox(
                  color: Color(0xFF346AE6),
                  child: SizedBox(width: 100, height: 100),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Pressable)),
    );
    await tester.pump();
    expect(pressScale(tester), 0.96);

    await gesture.up();
    await tester.pump();
    expect(pressScale(tester), 1);
  });

  testWidgets('Pressable lets go once the finger starts scrolling', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const Center(
          child: Pressable(
            child: ColoredBox(
              color: Color(0xFF346AE6),
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Pressable)),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    expect(pressScale(tester), 1);
    await gesture.up();
  });

  testWidgets('profile stats count up to their values', (tester) async {
    final now = DateTime.now();
    final entries = [
      for (var i = 0; i < 3; i++)
        MoodEntry(
          id: '$i',
          date: now.subtract(Duration(days: i)),
          emojis: const ['😄'],
          note: '',
        ),
    ];
    SharedPreferences.setMockInitialValues({
      'mood_entries': entries.map((e) => jsonEncode(e.toJson())).toList(),
    });

    await tester.pumpWidget(app(const ProfileScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // 숫자가 올라가는 중에는 아직 최종값이 아니다.
    await tester.pumpAndSettle();
    // 연속 출석 3, 총 기록 수 3, 최다 감정 3.
    expect(find.text('3'), findsNWidgets(3));
  });

  testWidgets('swiping the calendar grid left moves to the next month', (
    tester,
  ) async {
    await tester.pumpWidget(app(const CalendarScreen()));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final thisMonth = DateFormat('M월 yyyy', 'ko_KR').format(now);
    final nextMonth = DateFormat(
      'M월 yyyy',
      'ko_KR',
    ).format(DateTime(now.year, now.month + 1));
    expect(find.text(thisMonth), findsOneWidget);

    await tester.fling(find.text('15'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(nextMonth), findsOneWidget);
  });

  testWidgets('recording anywhere shows the saved toast', (tester) async {
    await tester.pumpWidget(app(const RootScreen()));
    await tester.pumpAndSettle();

    WolodyToast toast() => tester.widget<WolodyToast>(find.byType(WolodyToast));
    expect(toast().visible, isFalse);

    MoodEvents.recorded.value = MoodEntry(
      id: 'new',
      date: DateTime.now(),
      emojis: const ['😄'],
      note: '',
    );
    await tester.pump();
    expect(toast().visible, isTrue);
    expect(toast().message, '오늘의 기록을 완료 했어요!');

    // 토스트가 사라질 때까지 기다려 남은 타이머를 정리한다.
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  test('streak counts consecutive days ending today', () {
    final today = DateTime(2026, 10, 4, 21);
    MoodEntry on(int daysAgo) => MoodEntry(
      id: '$daysAgo',
      date: DateTime(2026, 10, 4 - daysAgo, 9),
      emojis: const ['😄'],
      note: '',
    );
    expect(MoodEntry.streak([on(0), on(1), on(2)], today: today), 3);
    // 하루라도 비면 거기서 끊긴다.
    expect(MoodEntry.streak([on(0), on(2)], today: today), 1);
    // 오늘 기록이 없으면 0.
    expect(MoodEntry.streak([on(1), on(2)], today: today), 0);
    // 하루에 여러 번 기록해도 하루로 센다.
    expect(MoodEntry.streak([on(0), on(0), on(1)], today: today), 2);
  });

  Future<void> pumpHomeWithStreak(WidgetTester tester, int days) async {
    final now = DateTime.now();
    final entries = [
      for (var i = 0; i < days; i++)
        MoodEntry(
          id: '$i',
          date: DateTime(now.year, now.month, now.day - i, 9),
          emojis: const ['😄'],
          note: '',
        ),
    ];
    SharedPreferences.setMockInitialValues({
      'mood_entries': entries.map((e) => jsonEncode(e.toJson())).toList(),
      'reminder_enabled': true,
    });
    await tester.pumpWidget(app(const HomeScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('completed banner shows the real streak', (tester) async {
    await pumpHomeWithStreak(tester, 3);
    expect(find.text('연속 3일차에 도전 중입니다'), findsOneWidget);
  });

  testWidgets('closing the banner folds it away smoothly', (tester) async {
    await pumpHomeWithStreak(tester, 1);
    // 다 접히면 높이 0이라 화면 밖으로 취급되므로 skipOffstage를 끈다.
    final banner = find.ancestor(
      of: find.text('연속 1일차에 도전 중입니다', skipOffstage: false),
      matching: find.byType(SizeTransition, skipOffstage: false),
    );
    final fullHeight = tester.getSize(banner).height;
    expect(fullHeight, greaterThan(200));

    await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    // 접히는 중에는 높이가 줄어드는 중이다.
    final midHeight = tester.getSize(banner).height;
    expect(midHeight, lessThan(fullHeight));
    expect(midHeight, greaterThan(0));

    await tester.pumpAndSettle();
    expect(tester.getSize(banner).height, 0);
  });
}
