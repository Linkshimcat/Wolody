import 'package:flutter_test/flutter_test.dart';
import 'package:wolody/models/mood_entry.dart';

void main() {
  test('round-trips through json', () {
    final entry = MoodEntry(
      id: '1',
      date: DateTime(2026, 8, 2, 21, 30),
      emojis: const ['😄', '😜'],
      note: '좋은 하루',
      imageFileName: 'mood_123.jpg',
    );

    final restored = MoodEntry.fromJson(entry.toJson());

    expect(restored.id, entry.id);
    expect(restored.date, entry.date);
    expect(restored.emojis, entry.emojis);
    expect(restored.note, entry.note);
    expect(restored.imageFileName, entry.imageFileName);
  });

  test('reads single-emoji records saved before multi-select', () {
    final restored = MoodEntry.fromJson({
      'id': '2',
      'date': '2026-08-01T09:00:00.000',
      'emoji': '😢',
      'note': '옛 기록',
    });

    expect(restored.emojis, ['😢']);
    expect(restored.note, '옛 기록');
    expect(restored.imageFileName, isNull);
  });
}
