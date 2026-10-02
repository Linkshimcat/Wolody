import 'dart:io';

import 'package:flutter/services.dart';

import '../models/mood.dart';
import '../models/mood_entry.dart';
import 'mood_storage.dart';
import 'widget_service.dart';

/// 설정 → 실시간 화면에 표시. 오늘의 마음 기록 상태를 앱 밖에 계속 띄운다.
///
/// - iOS 16.1+: 잠금화면·다이나믹 아일랜드의 Live Activity
/// - Android 16+: 상태 바 칩·잠금화면의 Live Update(승격된 진행 중 알림)
/// - Android 15 이하: 같은 내용의 일반 진행 중 알림
///
/// 그 밖의 플랫폼이나 낮은 버전에서는 모든 호출이 조용히 무시된다.
class LiveActivityService {
  static const _channel = MethodChannel('wolody/live_activity');

  static bool get _available => Platform.isIOS || Platform.isAndroid;

  static Future<bool> isSupported() async {
    if (!_available) return false;
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
    if (!_available) return;
    try {
      await _channel.invokeMethod<bool>('end');
    } on PlatformException {
      // 표시할 활동이 없어도 문제될 것은 없다.
    }
  }

  /// 안드로이드 OS 버전(API 레벨). 안드로이드가 아니면 0.
  static Future<int> androidSdkInt() async {
    if (!Platform.isAndroid) return 0;
    try {
      return await _channel.invokeMethod<int>('sdkInt') ?? 0;
    } on PlatformException {
      return 0;
    }
  }

  /// 안드로이드 16+에서 이 앱의 Live Update가 허용돼 있는지. 꺼져 있으면
  /// 일반 진행 중 알림으로만 보인다. iOS·안드로이드 15 이하에서는 false.
  static Future<bool> canPromote() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('canPromote') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 안드로이드의 이 앱 Live Update 설정 화면을 연다.
  static Future<void> openPromotionSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openPromotionSettings');
    } on PlatformException {
      // 설정 화면을 못 열어도 알림은 그대로 보인다.
    }
  }

  static Future<void> _send(String method) async {
    if (!_available) return;
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
