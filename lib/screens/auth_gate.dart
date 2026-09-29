import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import 'root_screen.dart';

/// 스플래시 다음 화면을 고른다.
///
/// Wolody는 기록을 계정(클라우드)에 저장하므로 로그인해야 쓸 수 있다.
/// 로그인돼 있으면 앱으로, 아니면 로그인 화면을 보여준다. 로그아웃하면
/// 인증 상태가 바뀌면서 자동으로 로그인 화면으로 돌아간다.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Supabase를 쓸 수 없는 환경(테스트)에서는 로그인 없이 앱을 띄운다.
    if (!AuthService.isAvailable) return const RootScreen();
    return StreamBuilder<AuthState>(
      stream: AuthService.authChanges,
      builder: (context, _) => AuthService.currentUser != null
          ? const RootScreen()
          : const LoginScreen(),
    );
  }
}
