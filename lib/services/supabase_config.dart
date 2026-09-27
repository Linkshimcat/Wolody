import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 프로젝트 접속 정보.
///
/// 1. https://supabase.com/dashboard 의 Wolody 프로젝트(ref: yqbkqgvlolwwlfyoxluq)를 쓴다.
/// 2. 프로젝트 설정(Settings) → API Keys의 "Project URL"과 publishable 키
///    (`sb_publishable_...`)를 아래 두 상수에 채워 넣는다. secret 키는 절대 넣지 않는다.
///    스키마는 supabase/migrations의 SQL을 순서대로 적용한다.
/// 3. 구글 로그인을 쓰려면 Authentication → Providers에서 Google을 활성화하고
///    Google Cloud Console에서 발급한 OAuth 클라이언트 ID를 등록해야 한다.
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://yqbkqgvlolwwlfyoxluq.supabase.co',
);

const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_oyOSZLEbDXU0KsNPb2XGFQ_I2IL_4uA',
);

/// 구글 로그인이 끝난 뒤 앱으로 돌아오는 딥링크 스킴.
/// iOS Info.plist의 CFBundleURLSchemes와 Android의 intent-filter에 같게 등록돼 있다.
const supabaseRedirectScheme = 'wolody';

/// 딥링크로 앱에 돌아올 때 호출되는 콜백 주소.
/// Supabase 대시보드의 Authentication → URL Configuration에
/// `wolody://login-callback/`을 Redirect URL로 추가해야 한다.
const supabaseRedirectUrl = '$supabaseRedirectScheme://login-callback/';

class SupabaseConfig {
  static bool _initialized = false;

  /// Supabase가 초기화됐는지 여부. 로그인 전/미설정 상태에서도
  /// 저장소가 안전하게 로컬 모드로 동작하도록 하는 데 쓴다.
  static bool get isInitialized => _initialized;

  /// 앱 시작 시 한 번 호출한다. URL/키가 채워지기 전이면 명확한 안내와 함께 실패한다.
  static Future<void> initialize() async {
    if (_initialized) return;
    if (supabaseUrl.startsWith('YOUR_') || supabaseAnonKey.startsWith('YOUR_')) {
      throw StateError(
        'Supabase 접속 정보가 없습니다.\n'
        'supabase.com에서 프로젝트를 만든 뒤 '
        'lib/services/supabase_config.dart의 supabaseUrl, supabaseAnonKey를 채워주세요.',
      );
    }
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
      debug: kDebugMode,
    );
    _initialized = true;
  }
}
