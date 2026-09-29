import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wolody/models/reminder_settings.dart';
import 'package:wolody/screens/home_screen.dart';
import 'package:wolody/screens/reminder_screen.dart';

void main() {
  const bannerTitle = '기록 알림을 설정해볼까요?';

  setUp(() async {
    await initializeDateFormatting('ko_KR');
    ReminderSettings.current.value = null;
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(const CupertinoApp(home: HomeScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the reminder banner while reminders are off', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pumpHome(tester);

    expect(find.text(bannerTitle), findsOneWidget);

    // 배너를 누르면 알림 설정 화면으로 간다.
    await tester.tap(find.text(bannerTitle));
    await tester.pumpAndSettle();
    expect(find.byType(ReminderScreen), findsOneWidget);
  });

  testWidgets('hides the reminder banner once reminders are on', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'reminder_enabled': true});
    await pumpHome(tester);

    expect(find.text(bannerTitle), findsNothing);
  });

  testWidgets('turning reminders on removes the banner right away', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pumpHome(tester);
    expect(find.text(bannerTitle), findsOneWidget);

    await tester.runAsync(
      () => ReminderSettings.defaults.copyWith(enabled: true).save(),
    );
    await tester.pumpAndSettle();
    expect(find.text(bannerTitle), findsNothing);
  });
}
