import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/reminder_settings.dart';
import 'theme.dart';
import 'screens/root_screen.dart';
import 'screens/splash_screen.dart';
import 'services/appearance_settings.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'services/live_activity_service.dart';
import 'services/photo_storage.dart';
import 'services/profile_storage.dart';
import 'services/supabase_config.dart';
import 'services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 세로 모드 고정 — 플랫폼 설정과 함께 가로 회전을 막는다.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // 스플래시부터 고른 화면 모드로 그리도록 가장 먼저 읽는다.
  await AppearanceSettings.load();
  final initialization = _initializeApp();
  runApp(MyApp(initialization: initialization));
  // 앱 창이 늦게 붙는 경우를 대비해 첫 화면을 그린 뒤 한 번 더 맞춘다.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => AppearanceSettings.syncNative(),
  );
}

Future<void> _initializeApp() async {
  // 앱에 넣은 BM Jua 폰트의 OFL 라이선스를 오픈소스 라이선스 화면에 함께 싣는다.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'BM Jua (Jua 폰트)',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  await initializeDateFormatting('ko_KR');
  await PhotoStorage.init();
  try {
    // 로그인과 계정 저장소. 세션은 기기에 남아 있어서 오프라인이어도 초기화된다.
    await SupabaseConfig.initialize();
    await AuthService.init();
  } catch (e) {
    debugPrint('로그인 초기화 실패: $e');
  }
  // 프로필 사진은 문서 폴더에 있으므로 PhotoStorage 다음에 읽는다.
  await ProfileStorage.load();
  // 개발용 "로그인 없이 둘러보기"를 켜 뒀다면 바로 앱으로 들어간다.
  await AuthService.loadGuest();
  // 다른 기기에서 바꾼 프로필이 있을 수 있으니 계정 사본을 뒤에서 가져온다.
  if (AuthService.currentUser != null) {
    unawaited(ProfileStorage.pullFromCloud());
  }
  await NotificationService.instance.init();
  // 홈의 알림 배너가 처음부터 알림 설정 여부를 알고 그리도록 미리 읽어 둔다.
  await ReminderSettings.load();
  // 앱을 껐다 켜는 사이 기록이 바뀌었을 수 있으니 위젯을 한 번 맞춰둔다.
  await WidgetService.refresh();
  // 실시간 표시를 켜 뒀다면 다시 띄운다. 안드로이드 알림은 재부팅·강제 종료 때 사라지고,
  // iOS 활동도 시간이 지나면 끝나기 때문이다. 이미 떠 있으면 내용만 갱신된다.
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('live_activity_enabled') ?? false) {
    unawaited(LiveActivityService.start());
  }
}

class MyApp extends StatelessWidget {
  final Future<void>? initialization;

  const MyApp({super.key, this.initialization});

  @override
  Widget build(BuildContext context) {
    // 설정 → 화면에서 모드를 바꾸면 앱 전체가 바로 다시 그려진다.
    return ValueListenableBuilder<AppearanceMode>(
      valueListenable: AppearanceSettings.mode,
      builder: (context, mode, _) => CupertinoApp(
        title: 'Wolody',
        debugShowCheckedModeBanner: false,
        // 날짜·시간 휠과 시스템 문구(복사/붙여넣기 등)를 한국어로 띄운다.
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [Locale('ko', 'KR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: CupertinoThemeData(
          // null이면 iOS 설정의 라이트/다크를 따라간다.
          brightness: mode.brightness,
          primaryColor: WolodyColors.brandBlue,
        ),
        // 내비게이션 바가 없는 화면에서도 상태 바 글자색이 배경과 반대가 되게 한다.
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: WolodyColors.of(context).isLight
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light,
          child: child!,
        ),
        home: initialization == null
            ? const RootScreen()
            : SplashScreen(initialization: initialization!),
      ),
    );
  }
}
