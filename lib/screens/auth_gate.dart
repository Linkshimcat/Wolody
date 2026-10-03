import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/onboarding.dart';
import 'intro_screen.dart';
import 'login_screen.dart';
import 'root_screen.dart';
import 'setup_screen.dart';

/// [AuthGate]가 보여줄 화면.
enum GateScreen { intro, login, setup, app }

/// 스플래시 다음 화면을 고른다.
///
/// Wolody는 기록을 계정(클라우드)에 저장하므로 로그인해야 쓸 수 있다.
/// - 처음 설치했으면 소개 화면 → 로그인 화면
/// - 방금 가입한 계정이면 설정 단계(이름·알림) → 앱
/// - 로그인돼 있으면 앱. 로그아웃하면 인증 상태가 바뀌면서 로그인 화면으로 돌아간다.
/// 디버그 빌드에서는 "로그인 없이 둘러보기"([AuthService.guest])로도 들어갈 수 있다.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  /// 상태에 따라 보여줄 화면. 위에서부터 차례로 따진다.
  static GateScreen pick({
    required bool signedIn,
    required bool guest,
    required bool introSeen,
    required bool setupPending,
  }) {
    if (signedIn && setupPending) return GateScreen.setup;
    if (signedIn || guest) return GateScreen.app;
    if (!introSeen) return GateScreen.intro;
    return GateScreen.login;
  }

  @override
  Widget build(BuildContext context) {
    // Supabase를 쓸 수 없는 환경(테스트)에서는 로그인 없이 앱을 띄운다.
    if (!AuthService.isAvailable) return const RootScreen();
    return StreamBuilder<AuthState>(
      stream: AuthService.authChanges,
      builder: (context, _) => ListenableBuilder(
        listenable: Listenable.merge([
          AuthService.guest,
          Onboarding.introSeen,
          Onboarding.setupPending,
        ]),
        builder: (context, _) {
          final screen = pick(
            signedIn: AuthService.currentUser != null,
            guest: AuthService.guest.value,
            introSeen: Onboarding.introSeen.value,
            setupPending: Onboarding.setupPending.value,
          );
          // 화면이 바뀔 때 짧게 겹쳐 흐려지며 넘어간다.
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(
              key: ValueKey(screen),
              child: switch (screen) {
                GateScreen.intro => const IntroScreen(),
                GateScreen.login => const LoginScreen(),
                GateScreen.setup => const SetupScreen(),
                GateScreen.app => const RootScreen(),
              },
            ),
          );
        },
      ),
    );
  }
}
