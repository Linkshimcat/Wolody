import 'dart:io';

import 'package:flutter/services.dart';

/// 앱 전체의 햅틱. 화면에서는 [HapticFeedback] 대신 이걸 쓴다.
///
/// - iOS: 탭·선택은 Flutter 기본 햅틱(UIImpactFeedbackGenerator)이 잘 울려서 그대로 쓰고,
///   성공·오류는 알림 햅틱(UINotificationFeedbackGenerator)을 직접 부른다.
/// - Android: Flutter 기본 햅틱은 View.performHapticFeedback의 상수를 쓰는데, 삼성 등
///   많은 기기에서 거의 느껴지지 않는다. 그래서 진동 모터에 직접 효과를 요청한다
///   (android/.../HapticsBridge.kt).
///
/// 성공은 짧게 두 번, 오류는 톡톡톡 세 번 울려서 "안 돼요"를 손끝으로 알린다.
abstract final class Haptics {
  static const _channel = MethodChannel('wolody/haptics');

  /// 고르기·토글처럼 아주 가벼운 톡.
  static Future<void> selection() =>
      _impact('selection', HapticFeedback.selectionClick);

  /// 버튼을 눌렀을 때의 가벼운 톡.
  static Future<void> light() => _impact('light', HapticFeedback.lightImpact);

  static Future<void> medium() =>
      _impact('medium', HapticFeedback.mediumImpact);

  static Future<void> heavy() => _impact('heavy', HapticFeedback.heavyImpact);

  static Future<void> error() => _notify('error', HapticFeedback.heavyImpact);

  static Future<void> success() =>
      _notify('success', HapticFeedback.mediumImpact);

  static Future<void> _impact(
    String type,
    Future<void> Function() fallback,
  ) async {
    if (!Platform.isAndroid) return fallback();
    await _invoke('impact', type, fallback);
  }

  static Future<void> _notify(
    String type,
    Future<void> Function() fallback,
  ) async {
    if (!Platform.isIOS && !Platform.isAndroid) return fallback();
    await _invoke('notification', type, fallback);
  }

  static Future<void> _invoke(
    String method,
    String type,
    Future<void> Function() fallback,
  ) async {
    try {
      await _channel.invokeMethod<void>(method, type);
    } on MissingPluginException {
      await fallback();
    } on PlatformException {
      await fallback();
    }
  }
}
