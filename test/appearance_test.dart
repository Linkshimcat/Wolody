import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wolody/screens/home_screen.dart';
import 'package:wolody/services/appearance_settings.dart';
import 'package:wolody/theme.dart';

void main() {
  setUp(() async {
    await initializeDateFormatting('ko_KR');
    AppearanceSettings.mode.value = AppearanceMode.system;
  });

  test('saved appearance mode survives a reload', () async {
    SharedPreferences.setMockInitialValues({});
    await AppearanceSettings.load();
    expect(AppearanceSettings.mode.value, AppearanceMode.system);

    await AppearanceSettings.save(AppearanceMode.dark);
    AppearanceSettings.mode.value = AppearanceMode.system;
    await AppearanceSettings.load();
    expect(AppearanceSettings.mode.value, AppearanceMode.dark);
  });

  Future<Color?> homeBackground(WidgetTester tester, Brightness b) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      CupertinoApp(
        theme: CupertinoThemeData(brightness: b),
        home: const HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();
    return tester
        .widget<CupertinoPageScaffold>(find.byType(CupertinoPageScaffold))
        .backgroundColor;
  }

  testWidgets('home uses the light palette in light mode', (tester) async {
    expect(
      await homeBackground(tester, Brightness.light),
      WolodyPalette.light.background,
    );
  });

  testWidgets('home keeps the dark palette in dark mode', (tester) async {
    expect(
      await homeBackground(tester, Brightness.dark),
      WolodyPalette.dark.background,
    );
  });
}
