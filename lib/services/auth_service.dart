import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_config.dart';
import 'mood_storage.dart';
import 'profile_storage.dart';
import 'supabase_config.dart';
import 'trash_storage.dart';

enum LoginProvider { google, kakao }

/// 로그인하다 사용자에게 보여줄 문제가 생겼을 때 던진다.
class LoginException implements Exception {
  final String message;
  const LoginException(this.message);

  @override
  String toString() => message;
}

/// 구글·카카오 **인앱 로그인**.
///
/// 흐름은 두 로그인이 같다.
/// 1. 각 회사의 SDK로 앱 안에서 로그인 창을 띄워 **ID 토큰**(누구인지 증명하는
///    서명된 문서)을 받는다.
/// 2. 그 토큰을 Supabase에 `signInWithIdToken`으로 넘기면, Supabase가 서명을
///    확인한 뒤 Wolody 계정 세션을 만들어 준다.
///
/// 브라우저로 나갔다 돌아오는 웹 로그인과 달리 앱을 벗어나지 않는다.
class AuthService {
  static const _skippedKey = 'login_skipped';

  static bool _googleReady = false;

  /// 구글 SDK는 앱을 켤 때 한 번만 초기화할 수 있어서, 그때 만든 nonce를 기억해 둔다.
  static String? _googleRawNonce;

  static SupabaseClient get _client => Supabase.instance.client;

  /// Supabase가 준비되지 않은 환경(테스트 등)에서는 로그인 기능을 숨긴다.
  static bool get isAvailable => SupabaseConfig.isInitialized;

  static User? get currentUser => isAvailable ? _client.auth.currentUser : null;

  static Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  /// 앱을 켤 때 한 번 부른다. 키가 없는 로그인은 건너뛴다.
  static Future<void> init() async {
    if (AuthConfig.kakaoReady) {
      await kakao.KakaoSdk.init(nativeAppKey: AuthConfig.kakaoNativeAppKey);
    }
    if (AuthConfig.googleReady) {
      _googleRawNonce = _randomNonce();
      await GoogleSignIn.instance.initialize(
        // iOS는 iOS용 클라이언트 ID로 로그인 창을 띄우고,
        // 발급되는 ID 토큰은 웹 클라이언트 ID(Supabase 쪽)를 대상으로 한다.
        clientId: Platform.isIOS ? AuthConfig.googleIosClientId : null,
        serverClientId: AuthConfig.googleWebClientId,
        nonce: _sha256(_googleRawNonce!),
      );
      _googleReady = true;
    }
  }

  /// 로그인에 성공하면 true, 사용자가 창을 닫아 취소하면 false.
  static Future<bool> signIn(LoginProvider provider) async {
    if (!isAvailable) {
      throw const LoginException('지금은 로그인할 수 없어요. 인터넷 연결을 확인해 주세요.');
    }
    final signedIn = switch (provider) {
      LoginProvider.google => await _signInWithGoogle(),
      LoginProvider.kakao => await _signInWithKakao(),
    };
    if (signedIn) {
      // 로그인한 SNS의 이름·프로필 사진을 Wolody 프로필로 가져온다.
      await _applySocialProfile();
      // 기기에만 있던 기록을 계정으로 올리고, 계정에 있던 기록을 내려받는다.
      await MoodStorage.syncToCloud();
    }
    return signedIn;
  }

  /// 구글·카카오가 ID 토큰에 담아 준 이름과 사진으로 프로필을 바꾼다.
  /// 사진을 못 받아도 이름은 바꾸고, 둘 다 없으면 지금 프로필을 그대로 둔다.
  static Future<void> _applySocialProfile() async {
    final meta = currentUser?.userMetadata ?? const <String, dynamic>{};
    final name =
        [
              meta['name'],
              meta['full_name'],
              meta['nickname'],
              meta['preferred_username'],
            ]
            .whereType<String>()
            .map((e) => e.trim())
            .firstWhere((e) => e.isNotEmpty, orElse: () => '');
    final pictureUrl = [
      meta['avatar_url'],
      meta['picture'],
    ].whereType<String>().firstWhere((e) => e.isNotEmpty, orElse: () => '');
    if (name.isEmpty && pictureUrl.isEmpty) return;

    final current = ProfileStorage.profile.value;
    final nickname = name.isEmpty
        ? current.nickname
        : name.characters.take(UserProfile.maxNicknameLength).toString();
    final photoPath = pictureUrl.isEmpty ? null : await _download(pictureUrl);
    await ProfileStorage.save(nickname: nickname, photoSourcePath: photoPath);
  }

  /// 프로필 사진을 임시 파일로 받는다. 실패하면 null.
  static Future<String?> _download(String url) async {
    // 구글은 주소 끝의 크기(=s96-c)를 키우면 더 선명한 사진을 준다.
    // 카카오는 http 주소를 줄 때가 있어 iOS가 막지 않게 https로 바꾼다.
    final uri = Uri.parse(
      url
          .replaceFirst(RegExp(r'=s\d+-c$'), '=s400-c')
          .replaceFirst(RegExp(r'^http://'), 'https://'),
    );
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final response = await (await client.getUrl(uri)).close();
      if (response.statusCode != 200) return null;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/social_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await response.pipe(file.openWrite());
      return file.path;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static Future<bool> _signInWithGoogle() async {
    if (!_googleReady) {
      throw const LoginException('구글 로그인 설정이 아직 끝나지 않았어요.');
    }
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      throw LoginException('구글 로그인에 실패했어요. (${e.code.name})');
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const LoginException('구글에서 로그인 정보를 받지 못했어요.');
    }
    await _exchange(
      OAuthProvider.google,
      idToken: idToken,
      rawNonce: _googleRawNonce,
    );
    return true;
  }

  static Future<bool> _signInWithKakao() async {
    if (!AuthConfig.kakaoReady) {
      throw const LoginException('카카오 로그인 설정이 아직 끝나지 않았어요.');
    }
    // 토큰을 가로채 다시 쓰는 공격을 막는 일회용 값. 카카오에는 해시를,
    // Supabase에는 원래 값을 줘서 서로 맞는지 확인하게 한다.
    final rawNonce = _randomNonce();
    final nonce = _sha256(rawNonce);

    kakao.OAuthToken token;
    try {
      if (await kakao.isKakaoTalkInstalled()) {
        try {
          // 카카오톡 앱이 있으면 카카오톡으로 바로 로그인한다.
          token = await kakao.UserApi.instance.loginWithKakaoTalk(nonce: nonce);
        } on PlatformException catch (e) {
          if (e.code == 'CANCELED') return false;
          // 카카오톡에 연결된 계정이 없는 경우 등 — 카카오계정 로그인으로 넘어간다.
          token = await kakao.UserApi.instance.loginWithKakaoAccount(
            nonce: nonce,
          );
        }
      } else {
        // 카카오톡이 없으면 앱 안에 뜨는 카카오계정 로그인 창을 쓴다.
        token = await kakao.UserApi.instance.loginWithKakaoAccount(
          nonce: nonce,
        );
      }
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') return false;
      throw LoginException('카카오 로그인에 실패했어요. (${e.code})');
    } on kakao.KakaoException catch (e) {
      throw LoginException('카카오 로그인에 실패했어요. ($e)');
    }

    final idToken = token.idToken;
    if (idToken == null) {
      // Kakao Developers에서 OpenID Connect를 켜야 ID 토큰이 온다.
      throw const LoginException('카카오 로그인 설정(OpenID Connect)이 꺼져 있어요.');
    }
    await _exchange(
      OAuthProvider.kakao,
      idToken: idToken,
      accessToken: token.accessToken,
      rawNonce: rawNonce,
    );
    return true;
  }

  /// SDK가 준 ID 토큰을 Supabase 세션으로 바꾼다.
  static Future<void> _exchange(
    OAuthProvider provider, {
    required String idToken,
    String? accessToken,
    String? rawNonce,
  }) async {
    try {
      await _client.auth.signInWithIdToken(
        provider: provider,
        idToken: idToken,
        accessToken: accessToken,
        nonce: rawNonce,
      );
    } on AuthException catch (e) {
      throw LoginException('Wolody 계정을 만들지 못했어요. (${e.message})');
    }
  }

  /// 로그아웃. 계정 기록은 클라우드에 남고, 이 기기의 사본과 휴지통은 지운다.
  static Future<void> signOut() async {
    final provider = currentProvider;
    // 오프라인에서 쓴 기록이 있다면 지우기 전에 한 번 더 올려 둔다.
    await MoodStorage.syncToCloud();
    try {
      if (provider == LoginProvider.google && _googleReady) {
        await GoogleSignIn.instance.signOut();
      } else if (provider == LoginProvider.kakao && AuthConfig.kakaoReady) {
        await kakao.UserApi.instance.logout();
      }
    } catch (_) {
      // SDK 쪽 로그아웃이 실패해도 Wolody 세션만 끊으면 로그아웃된 것이다.
    }
    // 다른 사람이 이 기기로 로그인해도 지난 계정의 기록이 보이지 않게 비운다.
    // 휴지통은 기기에만 있으므로 세션이 살아 있을 때 사진까지 정리한다.
    await TrashStorage.clear();
    await _client.auth.signOut();
    await MoodStorage.clearLocal();
  }

  /// 로그인한 계정의 제공자(구글/카카오).
  static LoginProvider? get currentProvider {
    return switch (currentUser?.appMetadata['provider']) {
      'google' => LoginProvider.google,
      'kakao' => LoginProvider.kakao,
      _ => null,
    };
  }

  /// 계정 정보 화면에 보여줄 이름(이메일이 없으면 닉네임).
  static String? get displayName {
    final user = currentUser;
    if (user == null) return null;
    final meta = user.userMetadata ?? const {};
    return user.email ??
        meta['email'] as String? ??
        meta['name'] as String? ??
        meta['nickname'] as String? ??
        meta['full_name'] as String?;
  }

  /// 첫 화면에서 "로그인 없이 시작하기"를 눌렀는지.
  static Future<bool> hasSkippedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_skippedKey) ?? false;
  }

  static Future<void> skipLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_skippedKey, true);
  }

  static String _randomNonce() {
    final random = Random.secure();
    return base64Url.encode(List.generate(32, (_) => random.nextInt(256)));
  }

  static String _sha256(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}
