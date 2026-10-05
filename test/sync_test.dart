import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wolody/models/mood_entry.dart';
import 'package:wolody/services/mood_storage.dart';
import 'package:wolody/services/popup_tracker.dart';
import 'package:wolody/widgets/wolody_dialog.dart';

void main() {
  MoodEntry entry(String id, {String note = ''}) => MoodEntry(
    id: id,
    date: DateTime(2026, 10, 5, int.parse(id)),
    emojis: const ['😄'],
    note: note,
  );

  group('planSync', () {
    test(
      'uploads records made on this device that never reached the cloud',
      () {
        final plan = MoodStorage.planSync(
          local: [entry('1'), entry('2')],
          cloud: [entry('1')],
          synced: {'1'},
        );
        expect(plan.upload.map((e) => e.id), ['2']);
        expect(plan.merged.map((e) => e.id), containsAll(['1', '2']));
      },
    );

    test(
      'drops records another device deleted instead of re-uploading them',
      () {
        final plan = MoodStorage.planSync(
          local: [entry('1'), entry('2')],
          cloud: [entry('1')],
          synced: {'1', '2'},
        );
        expect(plan.upload, isEmpty);
        expect(plan.merged.map((e) => e.id), ['1']);
      },
    );

    test('takes records and edits made on another device', () {
      final plan = MoodStorage.planSync(
        local: [entry('1', note: '예전')],
        cloud: [
          entry('1', note: '고친 메모'),
          entry('3'),
        ],
        synced: {'1'},
      );
      expect(plan.upload, isEmpty);
      expect(plan.merged.map((e) => e.id), ['3', '1']);
      expect(plan.merged.last.note, '고친 메모');
    });
  });

  testWidgets('popup tracker counts open dialogs until they fully close', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        navigatorObservers: [PopupTracker()],
        home: Builder(
          builder: (context) => CupertinoButton(
            child: const Text('open'),
            onPressed: () => showWolodyDialog<void>(
              context: context,
              title: '제목',
              actions: const [WolodyAction(label: '확인', value: null)],
            ),
          ),
        ),
      ),
    );
    expect(PopupTracker.open.value, 0);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(PopupTracker.open.value, 1);

    await tester.tap(find.text('확인'));
    await tester.pump();
    // 닫히는 애니메이션이 끝나기 전에는 아직 열린 것으로 본다.
    expect(PopupTracker.open.value, 1);
    await tester.pumpAndSettle();
    expect(PopupTracker.open.value, 0);
  });
}
