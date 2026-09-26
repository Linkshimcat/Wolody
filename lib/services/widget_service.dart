import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/mood.dart';
import '../models/mood_entry.dart';
import 'mood_storage.dart';

/// 홈 화면 위젯이 읽을 요약 데이터를 App Group에 써준다.
class WidgetService {
  static const _channel = MethodChannel('today_mood/widget');

  /// 잔디 그리드는 폭에 따라 최대 26주(182일)까지 그린다. 넉넉히 잡아둔다.
  static const _grassDays = 190;

  static Future<void> refresh() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<bool>('update', jsonEncode(await _payload()));
    } on PlatformException {
      // App Group을 못 쓰는 환경이면 위젯만 갱신되지 않을 뿐이다.
    }
  }

  static Future<Map<String, dynamic>> _payload() async {
    final entries = await MoodStorage().load();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    MoodEntry? todayEntry;
    final colorsByDay = <String, String>{};

    for (final entry in entries) {
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (day == today) todayEntry ??= entry;

      if (today.difference(day).inDays >= _grassDays) continue;
      // 하루에 여러 번 기록했으면 가장 최근 것의 색을 쓴다.
      colorsByDay.putIfAbsent(
        _formatDay(day),
        () => hex(Mood.fromEmoji(entry.emojis.first).color),
      );
    }

    final todayMoods =
        todayEntry?.emojis.map(Mood.fromEmoji).toList() ?? const <Mood>[];

    return {
      'recorded': todayEntry != null,
      'emojis': todayMoods.map((m) => m.emoji).join(),
      'label': todayMoods.map((m) => m.label).join(' · '),
      // 위젯은 이모지 대신 울디 얼굴(faceIndex)과 첫 기분 색의 은은한 빛으로 그린다.
      'faces': todayMoods.map((m) => m.faceIndex).toList(),
      'color': todayMoods.isEmpty ? null : hex(todayMoods.first.color),
      'days': colorsByDay,
    };
  }

  static String _formatDay(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// Swift 쪽에서 파싱하는 RRGGBB 형식.
  static String hex(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return rgb.toRadixString(16).padLeft(6, '0').toUpperCase();
  }
}
