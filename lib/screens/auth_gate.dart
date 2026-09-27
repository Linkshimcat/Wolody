import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'root_screen.dart';

/// 스플래시 다음 화면을 고른다.
///
/// 로그인했거나 첫 화면에서 "로그인 없이 시작하기"를 누른 적이 있으면 바로 앱으로,
/// 아니면 로그인 화면을 보여준다. 앱을 쓰다 로그아웃해도 게스트로 계속 쓴다.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _skipped;

  @override
  void initState() {
    super.initState();
    AuthService.hasSkippedLogin().then((skipped) {
      if (mounted) setState(() => _skipped = skipped);
    });
  }

  Future<void> _skip() async {
    await AuthService.skipLogin();
    if (mounted) setState(() => _skipped = true);
  }

  @override
  Widget build(BuildContext context) {
    // Supabase를 쓸 수 없는 환경(테스트, 초기화 실패)에서는 로그인 없이 쓴다.
    if (!AuthService.isAvailable) return const RootScreen();
    final skipped = _skipped;
    if (skipped == null) {
      return const CupertinoPageScaffold(
        backgroundColor: WolodyColors.background,
        child: SizedBox.expand(),
      );
    }
    return StreamBuilder<AuthState>(
      stream: AuthService.authChanges,
      builder: (context, _) {
        final signedIn = AuthService.currentUser != null;
        if (signedIn || skipped) return const RootScreen();
        return LoginScreen(onSkip: _skip);
      },
    );
  }
}
