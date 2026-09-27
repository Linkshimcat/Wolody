/// 구글·카카오 인앱 로그인에 쓰는 앱 키.
///
/// 모두 앱 안에 들어가도 되는 공개용 값이다(비밀 키·Client Secret은 넣지 않는다).
/// 값을 바꾸면 iOS 설정(`ios/Flutter/Auth.xcconfig`)의 URL 스킴도 같이 바꿔야 한다.
abstract final class AuthConfig {
  /// Google Cloud Console → 사용자 인증 정보 → **iOS** 유형 OAuth 클라이언트 ID.
  /// 예: `1234-abcd.apps.googleusercontent.com`
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue:
        '542936341445-to5pgsbr9oh73uvnvcktori0ccmjtk92.apps.googleusercontent.com',
  );

  /// 같은 곳의 **웹 애플리케이션** 유형 OAuth 클라이언트 ID.
  /// 구글이 발급하는 ID 토큰의 대상(aud)이 되고, Supabase Google 설정에도 넣는다.
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '542936341445-b34599lvqi0pg0rqe1sk290pkrsvdapr.apps.googleusercontent.com',
  );

  /// Kakao Developers → 내 애플리케이션 → 앱 키 → **네이티브 앱 키**.
  static const kakaoNativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: '7eb2c801338a24d4f83dff2d0c703d2d',
  );

  static bool get googleReady =>
      googleIosClientId.isNotEmpty && googleWebClientId.isNotEmpty;

  static bool get kakaoReady => kakaoNativeAppKey.isNotEmpty;
}
