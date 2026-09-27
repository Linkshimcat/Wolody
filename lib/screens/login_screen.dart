import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/auth_service.dart';
import '../services/haptics.dart';
import '../theme.dart';
import '../widgets/glass_back_button.dart';

/// Figma "로그인" 화면. 구글·카카오 인앱 로그인 버튼을 보여준다.
///
/// 첫 실행에서는 [onSkip]이 있어 "로그인 없이 시작하기"를 보여주고,
/// 계정 정보에서 열 때는 뒤로 가기 버튼을 두고 로그인에 성공하면 닫힌다.
class LoginScreen extends StatefulWidget {
  final VoidCallback? onSkip;

  const LoginScreen({super.key, this.onSkip});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  LoginProvider? _loading;

  Future<void> _signIn(LoginProvider provider) async {
    if (_loading != null) return;
    HapticFeedback.lightImpact();
    setState(() => _loading = provider);
    try {
      final signedIn = await AuthService.signIn(provider);
      if (!signedIn || !mounted) return;
      HapticFeedback.mediumImpact();
      // 계정 정보에서 연 경우 닫는다. 첫 화면이면 AuthGate가 홈으로 바꾼다.
      if (widget.onSkip == null) Navigator.of(context).pop();
    } on LoginException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError('로그인에 실패했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  void _showError(String message) {
    Haptics.error();
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('로그인하지 못했어요'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return CupertinoPageScaffold(
      backgroundColor: WolodyColors.background,
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                const Spacer(flex: 5),
                const Text(
                  'Wolody',
                  style: TextStyle(
                    fontFamily: 'BM Jua',
                    fontSize: 64,
                    color: Color(0xFF80A4FF),
                  ),
                ),
                const Spacer(flex: 3),
                // Figma처럼 손 흔드는 울디의 아래쪽이 버튼 뒤로 숨는다.
                SizedBox(
                  height: 205,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      maxHeight: 280,
                      child: Image.asset(
                        'assets/AssetsDesign/wooldy_wave.png',
                        width: 205,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, bottom + 16),
                  child: Column(
                    children: [
                      _LoginButton(
                        label: 'Google로 로그인 하기',
                        logo: SvgPicture.asset(
                          'assets/AssetsDesign/Google.svg',
                          width: 26,
                          height: 26,
                        ),
                        background: CupertinoColors.white,
                        foreground: CupertinoColors.black,
                        loading: _loading == LoginProvider.google,
                        onPressed: () => _signIn(LoginProvider.google),
                      ),
                      const SizedBox(height: 18),
                      _LoginButton(
                        label: '카카오 로그인',
                        logo: SvgPicture.asset(
                          'assets/AssetsDesign/Kakao.svg',
                          width: 26,
                          height: 26,
                        ),
                        background: const Color(0xFFFEE500),
                        foreground: const Color(0xD9000000),
                        loading: _loading == LoginProvider.kakao,
                        onPressed: () => _signIn(LoginProvider.kakao),
                      ),
                      if (widget.onSkip != null)
                        CupertinoButton(
                          padding: const EdgeInsets.only(top: 14),
                          onPressed: _loading != null
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  widget.onSkip!();
                                },
                          child: const Text(
                            '로그인 없이 시작하기',
                            style: TextStyle(
                              color: WolodyColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.onSkip == null)
            Positioned(
              left: 24,
              top: MediaQuery.paddingOf(context).top + 14,
              child: GlassBackButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Figma의 캡슐형 소셜 로그인 버튼.
class _LoginButton extends StatelessWidget {
  final String label;
  final Widget logo;
  final Color background;
  final Color foreground;
  final bool loading;
  final VoidCallback onPressed;

  const _LoginButton({
    required this.label,
    required this.logo,
    required this.background,
    required this.foreground,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        color: background,
        borderRadius: BorderRadius.circular(30),
        onPressed: onPressed,
        child: loading
            ? CupertinoActivityIndicator(color: foreground)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  logo,
                  const SizedBox(width: 14),
                  Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
