import 'package:flutter/cupertino.dart';

class Mood {
  final String emoji;
  final String label;
  final Color color;
  final int faceIndex;

  const Mood({
    required this.emoji,
    required this.label,
    required this.color,
    required this.faceIndex,
  });

  static const List<Mood> all = [
    Mood(emoji: '😄', label: '행복', color: Color(0xFFFFD58A), faceIndex: 0),
    Mood(emoji: '🙂', label: '만족', color: Color(0xFFF3A8C7), faceIndex: 1),
    Mood(emoji: '🤩', label: '설렘', color: Color(0xFFFFC36D), faceIndex: 2),
    Mood(emoji: '😌', label: '편안함', color: Color(0xFF9DD6C1), faceIndex: 3),
    Mood(emoji: '😐', label: '보통', color: Color(0xFFFFD58A), faceIndex: 4),
    Mood(emoji: '😢', label: '슬픔', color: Color(0xFF91B8E8), faceIndex: 5),
    Mood(emoji: '🥺', label: '외로움', color: Color(0xFFAAA6DB), faceIndex: 6),
    Mood(emoji: '😞', label: '서운함', color: Color(0xFFC4A6D8), faceIndex: 7),
    Mood(emoji: '😠', label: '화남', color: Color(0xFFE88E8E), faceIndex: 8),
    Mood(emoji: '😤', label: '답답함', color: Color(0xFFE6AA7D), faceIndex: 9),
    Mood(emoji: '😟', label: '불안', color: Color(0xFFB5A8E8), faceIndex: 10),
    Mood(emoji: '😳', label: '당황', color: Color(0xFFF0A5B7), faceIndex: 11),
  ];

  static Mood fromEmoji(String emoji) {
    final index = all.indexWhere((mood) => mood.emoji == emoji);
    if (index != -1) return all[index];
    return switch (emoji) {
      '😴' => const Mood(
        emoji: '😴',
        label: '피곤',
        color: Color(0xFFB5A8E8),
        faceIndex: 3,
      ),
      '🤨' => const Mood(
        emoji: '🤨',
        label: '의아',
        color: Color(0xFFAAA6DB),
        faceIndex: 10,
      ),
      '😮‍💨' => const Mood(
        emoji: '😮‍💨',
        label: '무기력',
        color: Color(0xFFC4A6D8),
        faceIndex: 7,
      ),
      '😜' => const Mood(
        emoji: '😜',
        label: '활발',
        color: Color(0xFFFFC36D),
        faceIndex: 2,
      ),
      '🫩' => const Mood(
        emoji: '🫩',
        label: '예민',
        color: Color(0xFFE6AA7D),
        faceIndex: 9,
      ),
      _ => all[4],
    };
  }
}
