import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'theme.dart';
import 'screens/root_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/photo_storage.dart';
import 'services/profile_storage.dart';
import 'services/widget_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 세로 모드 고정 — 플랫폼 설정과 함께 가로 회전을 막는다.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final initialization = _initializeApp();
  runApp(MyApp(initialization: initialization));
}

Future<void> _initializeApp() async {
  await initializeDateFormatting('ko_KR');
  await PhotoStorage.init();
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
