import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 화면 모드. [system]이면 iOS 설정(라이트/다크)을 그대로 따라간다.
enum AppearanceMode {
  system('시스템'),
  light('라이트'),
  dark('다크');

  final String label;
  const AppearanceMode(this.label);

  /// CupertinoThemeData.brightness에 넣을 값. null이면 플랫폼을 따른다.
  Brightness? get brightness => switch (this) {
    AppearanceMode.system => null,
    AppearanceMode.light => Brightness.light,
    AppearanceMode.dark => Brightness.dark,
  };
}

/// 설정 → 화면에서 고른 화면 모드를 기기에 보관하고, 바뀌면 앱 전체가 다시 그린다.
abstract final class AppearanceSettings {
  static const _key = 'appearance_mode';
  static const _channel = MethodChannel('wolody/appearance');

  static final mode = ValueNotifier(AppearanceMode.system);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    mode.value = AppearanceMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => AppearanceMode.system,
    );
    await syncNative();
  }

  static Future<void> save(AppearanceMode value) async {
    mode.value = value;
    await syncNative();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.name);
  }

  /// 네이티브 탭 바·스위치·상태 바도 같은 모드로 그리도록 iOS 창의 모드를 맞춘다.
  static Future<void> syncNative() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('setMode', mode.value.name);
    } on MissingPluginException {
      // 테스트처럼 네이티브가 없는 환경에서는 Flutter 화면만 바꾼다.
    } on PlatformException {
      // 창 모드를 못 바꿔도 Flutter 화면은 이미 바뀌었다.
    }
  }
}
