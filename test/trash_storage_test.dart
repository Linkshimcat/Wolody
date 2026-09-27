import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wolody/models/mood_entry.dart';
import 'package:wolody/services/trash_storage.dart';

MoodEntry _entry(String id) =>
    MoodEntry(id: id, date: DateTime(2026, 9, 1), emojis: const ['😄']);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('지운 기록은 최근 순으로 쌓이고 개수가 알려진다', () async {
    await TrashStorage.add(_entry('a'), now: DateTime(2026, 9, 1));
    await TrashStorage.add(_entry('b'), now: DateTime(2026, 9, 2));

    final items = await TrashStorage.load(now: DateTime(2026, 9, 3));
    expect(items.map((e) => e.entry.id), ['b', 'a']);
    expect(TrashStorage.count.value, 2);
    expect(items.first.daysLeft(DateTime(2026, 9, 3)), 29);
  });

  test('휴지통에서 빼면 목록에서 사라진다', () async {
    await TrashStorage.add(_entry('a'));
    await TrashStorage.remove('a');

    expect(await TrashStorage.load(), isEmpty);
    expect(TrashStorage.count.value, 0);
  });

  test('30일이 지난 기록은 불러올 때 정리된다', () async {
    await TrashStorage.add(_entry('old'), now: DateTime(2026, 8, 1));
    await TrashStorage.add(_entry('new'), now: DateTime(2026, 8, 25));

    final items = await TrashStorage.load(now: DateTime(2026, 9, 3));
    expect(items.map((e) => e.entry.id), ['new']);
    // 정리한 결과가 저장돼 다음에 불러와도 그대로다.
    expect(
      (await TrashStorage.load(now: DateTime(2026, 9, 3))).length,
      1,
    );
  });

  test('비우면 모두 사라진다', () async {
    await TrashStorage.add(_entry('a'));
    await TrashStorage.add(_entry('b'));
    await TrashStorage.clear();

    expect(await TrashStorage.load(), isEmpty);
  });
}
