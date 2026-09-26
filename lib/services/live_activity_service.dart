import 'dart:io';

import 'package:flutter/services.dart';

import '../models/mood.dart';
import '../models/mood_entry.dart';
import 'mood_storage.dart';
import 'widget_service.dart';

/// 잠금화면/다이나믹 아일랜드의 Live Activity를 제어한다. iOS 16.1+ 전용이며,
/// 다른 플랫폼이나 낮은 버전에서는 모든 호출이 조용히 무시된다.
class LiveActivityService {
  static const _channel = MethodChannel('today_mood/live_activity');

  static Future<bool> isSupported() async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> start() => _send('start');

  /// 오늘 기록이 바뀌었을 때 이미 떠 있는 활동의 내용을 갱신한다.
  static Future<void> refresh() => _send('update');

  static Future<void> end() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<bool>('end');
    } on PlatformException {
      // 표시할 활동이 없어도 문제될 것은 없다.
    }
  }

  static Future<void> _send(String method) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<bool>(method, await _todayState());
    } on PlatformException {
      // 사용자가 시스템 설정에서 실시간 활동을 꺼둔 경우 등 — 무시한다.
    }
  }

  static Future<Map<String, dynamic>> _todayState() async {
    final entries = await MoodStorage().load();
    final now = DateTime.now();
    final today = entries.where(
      (e) =>
          e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.day == now.day,
    );

    // 하루에 여러 번 기록했다면 가장 최근 것을 보여준다.
    final MoodEntry? latest = today.isEmpty ? null : today.first;
    final moods = latest?.emojis.map(Mood.fromEmoji).toList() ?? const <Mood>[];

    return {
      'title': '오늘의 마음',
      'emojis': moods.map((m) => m.emoji).join(),
      'label': moods.map((m) => m.label).join(' · '),
      'recorded': latest != null,
      'face': moods.isEmpty ? null : moods.first.faceIndex,
      'color': moods.isEmpty ? null : WidgetService.hex(moods.first.color),
    };
  }
}
