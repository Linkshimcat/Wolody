import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wolody/screens/auth_gate.dart';
import 'package:wolody/screens/intro_screen.dart';
import 'package:wolody/screens/setup_screen.dart';
import 'package:wolody/services/auth_service.dart';
import 'package:wolody/services/onboarding.dart';
import 'package:wolody/services/profile_storage.dart';

void main() {
  setUp(() async {
    await initializeDateFormatting('ko_KR');
    SharedPreferences.setMockInitialValues({});
    await Onboarding.load();
    AuthService.pendingNotice = null;
    ProfileStorage.profile.value = const UserProfile(
      nickname: UserProfile.defaultNickname,
    );
  });

  Widget app(Widget home) => CupertinoApp(home: home);

  group('AuthGate.pick', () {
    GateScreen pick({
      bool signedIn = false,
      bool guest = false,
      bool introSeen = false,
      bool setupPending = false,
    }) => AuthGate.pick(
      signedIn: signedIn,
      guest: guest,
      introSeen: introSeen,
      setupPending: setupPending,
    );

    test('first launch shows the intro, then login', () {
      expect(pick(), GateScreen.intro);
      expect(pick(introSeen: true), GateScreen.login);
    });

    test('a brand-new account goes through setup before the app', () {
      expect(pick(signedIn: true, setupPending: true), GateScreen.setup);
      expect(pick(signedIn: true), GateScreen.app);
    });

    test('guest preview skips intro and setup', () {
      expect(pick(guest: true, setupPending: true), GateScreen.app);
    });
  });

  test('first sign-in is when the account was created moments ago', () {
    expect(
      Onboarding.isFirstSignIn('2026-10-04T10:00:00Z', '2026-10-04T10:00:30Z'),
      isTrue,
    );
    expect(
      Onboarding.isFirstSignIn('2026-10-01T10:00:00Z', '2026-10-04T10:00:00Z'),
      isFalse,
    );
    expect(Onboarding.isFirstSignIn(null, '2026-10-04T10:00:00Z'), isFalse);
  });

  testWidgets('intro walks through three pages and remembers it was seen', (
    tester,
  ) async {
    await tester.pumpWidget(app(const IntroScreen()));
    await tester.pumpAndSettle();
    expect(find.text('안녕, 나는 울디야!'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('감정 카드로 10초면 끝'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('달력과 리캡으로 돌아봐요'), findsOneWidget);

    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(Onboarding.introSeen.value, isTrue);

    // 다시 켜도 소개는 다시 나오지 않는다.
    Onboarding.introSeen.value = false;
    await Onboarding.load();
    expect(Onboarding.introSeen.value, isTrue);
  });

  testWidgets('skipping the intro also counts as seen', (tester) async {
    await tester.pumpWidget(app(const IntroScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();
    expect(Onboarding.introSeen.value, isTrue);
  });

  testWidgets('setup saves the name and finishes with a welcome', (
    tester,
  ) async {
    await Onboarding.markNewAccount();
    ProfileStorage.profile.value = const UserProfile(nickname: '울디친구');

    await tester.pumpWidget(app(const SetupScreen()));
    await tester.pumpAndSettle();
    // 소셜 이름이 미리 채워져 있다.
    expect(find.text('울디친구'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoTextField), '새이름');
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(ProfileStorage.profile.value.nickname, '새이름');
    expect(find.text('언제 마음을 물어볼까요?'), findsOneWidget);

    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();
    expect(Onboarding.setupPending.value, isFalse);
    expect(AuthService.pendingNotice, '반가워요, 새이름!');
  });
}
