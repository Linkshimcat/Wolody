import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wolody/screens/home_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ko_KR');
  });

  testWidgets('pull to refresh shows the refreshing message', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        const CupertinoApp(
          theme: CupertinoThemeData(
            primaryColor: Color.fromARGB(255, 192, 80, 80),
          ),
          home: HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 빈 목록(내용이 화면을 채우지 않음)에서도 당기면 리프레시가 동작해야 한다.
      final gesture = await tester.startGesture(const Offset(400, 250));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 300));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // 스냅백이 끝나 refresh 상태가 되는 동안 문구가 표시된다.
      var sawMessage = false;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text('오늘의 기분 리프레시 중..').evaluate().isNotEmpty) {
          sawMessage = true;
          break;
        }
      }

      expect(
        sawMessage,
        isTrue,
        reason: '리프레시 중 문구가 표시되어야 한다.',
      );

      // 리프레시가 끝나면 문구가 사라진다.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('오늘의 기분 리프레시 중..'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
