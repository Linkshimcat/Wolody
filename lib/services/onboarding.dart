import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 처음 설치했을 때의 소개 화면과, 처음 가입했을 때의 설정 단계를 보여줄지 기억한다.
///
/// - 소개([introSeen])는 기기 기준이라 앱을 다시 설치하면 다시 본다.
/// - 설정([setupPending])은 처음 가입한 계정에서만 켜지고, 설정 도중 앱을 꺼도
///   다음에 이어서 하도록 기기에 남겨 둔다.
abstract final class Onboarding {
  static const _introKey = 'onboarding_intro_seen';
  static const _setupKey = 'onboarding_setup_pending';

  static final introSeen = ValueNotifier(false);
  static final setupPending = ValueNotifier(false);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    introSeen.value = prefs.getBool(_introKey) ?? false;
    setupPending.value = prefs.getBool(_setupKey) ?? false;
  }

  static Future<void> finishIntro() async {
    introSeen.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introKey, true);
  }

  /// 방금 가입한 계정이면 로그인 뒤 설정 단계를 보여준다.
  static Future<void> markNewAccount() async {
    setupPending.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupKey, true);
  }

  static Future<void> finishSetup() async {
    setupPending.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupKey, false);
  }

  /// 개발용: 소개와 설정을 처음부터 다시 보게 한다. 로그인 중이면 설정 단계가
  /// 바로 나오고, 소개는 로그아웃(또는 둘러보기를 끝낸) 뒤에 나온다.
  static Future<void> reset() async {
    introSeen.value = false;
    setupPending.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introKey, false);
    await prefs.setBool(_setupKey, true);
  }

  /// 처음 가입한 로그인인지. 가입 시각과 마지막 로그인 시각이 거의 같으면 첫 로그인이다.
  ///
  /// 계정 프로필이 있는지로 판단하면 오프라인일 때 기존 계정도 새 계정처럼 보여서
  /// 서버가 기록한 두 시각을 비교한다.
  static bool isFirstSignIn(String? createdAt, String? lastSignInAt) {
    if (createdAt == null || lastSignInAt == null) return false;
    final created = DateTime.tryParse(createdAt);
    final lastSignIn = DateTime.tryParse(lastSignInAt);
    if (created == null || lastSignIn == null) return false;
    return lastSignIn.difference(created).abs() < const Duration(minutes: 1);
  }
}
