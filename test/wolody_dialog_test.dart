import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wolody/widgets/wolody_dialog.dart';

void main() {
  Future<Object?> open(
    WidgetTester tester,
    Future<Object?> Function(BuildContext) show,
    Future<void> Function() act,
  ) async {
    Object? result = 'pending';
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) => CupertinoButton(
            child: const Text('open'),
            onPressed: () async => result = await show(context),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await act();
    await tester.pumpAndSettle();
    return result;
  }

  Future<bool?> confirm(BuildContext context) => showWolodyDialog<bool>(
    context: context,
    title: '로그아웃할까요?',
    message: '설명',
    actions: const [
      WolodyAction(label: '취소', value: false),
      WolodyAction(
        label: '로그아웃',
        value: true,
        style: WolodyActionStyle.destructive,
      ),
    ],
  );

  testWidgets('dialog returns the tapped action', (tester) async {
    final result = await open(
      tester,
      confirm,
      () => tester.tap(find.text('로그아웃')),
    );
    expect(result, isTrue);
    expect(find.text('로그아웃할까요?'), findsNothing);
  });

  testWidgets('tapping outside the dialog dismisses with null', (tester) async {
    final result = await open(
      tester,
      confirm,
      () => tester.tapAt(const Offset(10, 10)),
    );
    expect(result, isNull);
  });

  testWidgets('sheet returns the chosen option, cancel returns null', (
    tester,
  ) async {
    Future<String?> sheet(BuildContext context) => showWolodySheet<String>(
      context: context,
      actions: const [
        WolodyAction(label: '사진 촬영', value: 'camera'),
        WolodyAction(label: '앨범에서 선택', value: 'gallery'),
      ],
    );
    expect(
      await open(tester, sheet, () => tester.tap(find.text('앨범에서 선택'))),
      'gallery',
    );
    expect(
      await open(tester, sheet, () => tester.tap(find.text('취소'))),
      isNull,
    );
  });
}
