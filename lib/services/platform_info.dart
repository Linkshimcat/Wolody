import 'dart:io';

import 'package:flutter/services.dart';

/// iOS 네이티브 레이어에 물어본 OS 정보. 26+ 여부에 따라 하단 탭 바의
/// 구현을 갈아끼우는 데 쓴다.
class PlatformInfo {
  PlatformInfo._();

  static int? _iosMajor;

  /// iOS 주 버전. iOS가 아니면 0을 돌려준다.
  static Future<int> get iosMajorVersion async {
    if (!Platform.isIOS) return 0;
    final cached = _iosMajor;
    if (cached != null) return cached;
    const channel = MethodChannel('wolody/platform_info');
    final version = await channel.invokeMethod<int>('getOsMajorVersion') ?? 0;
    _iosMajor = version;
    return version;
  }

  /// iOS 26 이상에서만 네이티브 Liquid Glass 탭 바를 쓸 수 있다.
  static Future<bool> get supportsNativeLiquidGlass async {
    if (!Platform.isIOS) return false;
    return await iosMajorVersion >= 26;
  }
}
