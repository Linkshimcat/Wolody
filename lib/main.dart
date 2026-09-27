import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'theme.dart';
import 'screens/root_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'services/photo_storage.dart';
import 'services/profile_storage.dart';
import 'services/supabase_config.dart';
import 'services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 세로 모드 고정 — 플랫폼 설정과 함께 가로 회전을 막는다.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final initialization = _initializeApp();
  runApp(MyApp(initialization: initialization));
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
    // 로그인·백업용. 실패해도 기기 저장만으로 앱은 그대로 쓸 수 있다.
    await SupabaseConfig.initialize();
    await AuthService.init();
  } catch (e) {
    debugPrint('로그인 초기화 실패: $e');
  }
  // 프로필 사진은 문서 폴더에 있으므로 PhotoStorage 다음에 읽는다.
  await ProfileStorage.load();
  await NotificationService.instance.init();
  // 앱을 껐다 켜는 사이 기록이 바뀌었을 수 있으니 위젯을 한 번 맞춰둔다.
  await WidgetService.refresh();
}

class MyApp extends StatelessWidget {
  final Future<void>? initialization;

  const MyApp({super.key, this.initialization});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Wolody',
      debugShowCheckedModeBanner: false,
      // 날짜·시간 휠과 시스템 문구(복사/붙여넣기 등)를 한국어로 띄운다.
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: WolodyColors.brandBlue,
      ),
      home: initialization == null
          ? const RootScreen()
          : SplashScreen(initialization: initialization!),
    );
  }
}
