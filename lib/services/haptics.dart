import 'dart:io';

import 'package:flutter/services.dart';

/// iOS 알림 햅틱(UINotificationFeedbackGenerator).
///
/// 성공은 짧게 두 번, 오류는 톡톡톡 세 번 울려서 "안 돼요"를 손끝으로 알린다.
/// iOS가 아니거나 채널이 없으면 비슷한 세기의 기본 햅틱으로 대신한다.
abstract final class Haptics {
  static const _channel = MethodChannel('wolody/haptics');

  static Future<void> error() => _notify('error', HapticFeedback.heavyImpact);

  static Future<void> success() =>
      _notify('success', HapticFeedback.mediumImpact);

  static Future<void> _notify(
    String type,
    Future<void> Function() fallback,
  ) async {
    if (!Platform.isIOS) return fallback();
    try {
      await _channel.invokeMethod<void>('notification', type);
    } on MissingPluginException {
      await fallback();
    } on PlatformException {
      await fallback();
    }
  }
}
