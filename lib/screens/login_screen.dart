import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/auth_service.dart';
import '../services/haptics.dart';
import '../theme.dart';
import '../widgets/wolody_toast.dart';

/// Figma "로그인" 화면. 구글·카카오 인앱 로그인 버튼을 보여준다.
///
/// 로그인해야 앱을 쓸 수 있다. 로그인에 성공하면 AuthGate가 홈으로 바꾼다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  /// 카카오톡에서 로그인을 마치고 돌아왔다면 이 안에 SDK가 답을 준다.
  static const _returnGrace = Duration(seconds: 2);

  LoginProvider? _loading;

  /// 로그인 시도 번호. 그만둔 시도의 결과가 뒤늦게 와도 화면을 건드리지 않게 한다.
  int _attempt = 0;

  /// 로그인하는 동안 카카오톡 등으로 앱을 벗어났는지.
  bool _leftApp = false;
  Timer? _returnCheck;

  bool _showCanceledToast = false;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _returnCheck?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_loading == null) return;
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _leftApp = true;
      _returnCheck?.cancel();
    } else if (state == AppLifecycleState.resumed && _leftApp) {
      _leftApp = false;
      _returnCheck = Timer(_returnGrace, _abandonIfStuck);
    }
  }

  /// 카카오톡으로 넘어갔다가 로그인하지 않고 돌아오면 SDK가 끝내 답을 주지 않아
  /// 버튼이 계속 돌기만 한다. 기다림을 풀어 다시 누를 수 있게 한다.
  void _abandonIfStuck() {
    if (!mounted || _loading == null || !AuthService.awaitingProvider) return;
    _attempt++;
    setState(() => _loading = null);
    _showCanceled();
  }

  Future<void> _signIn(LoginProvider provider) async {
    if (_loading != null) {
      // 다른 로그인이 진행 중이라 누를 수 없다.
      Haptics.error();
      return;
    }
    Haptics.light();
    final attempt = ++_attempt;
    _leftApp = false;
    _toastTimer?.cancel();
    setState(() {
      _loading = provider;
      _showCanceledToast = false;
    });
    try {
      final signedIn = await AuthService.signIn(provider);
      if (attempt != _attempt || !mounted) return;
      if (signedIn) {
        Haptics.success();
      } else {
        // 로그인 창을 닫고 나왔다.
        _showCanceled();
      }
    } on LoginException catch (e) {
      if (attempt == _attempt && mounted) _showError(e.message);
    } catch (e) {
      if (attempt == _attempt && mounted) {
        _showError('로그인에 실패했어요. 잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (attempt == _attempt && mounted) {
        _returnCheck?.cancel();
        setState(() => _loading = null);
      }
    }
  }

  void _showCanceled() {
    setState(() => _showCanceledToast = true);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _showCanceledToast = false);
    });
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
    final padding = MediaQuery.paddingOf(context);
    final bottom = padding.bottom;
    return CupertinoPageScaffold(
      backgroundColor: WolodyColors.of(context).background,
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                const Spacer(flex: 5),
                Text(
                  'Wolody',
                  style: TextStyle(
                    fontFamily: 'BM Jua',
                    fontSize: 64,
                    color: WolodyColors.of(context).logo,
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
                      // 안드로이드 로그인 설정이 끝나기 전에도 앱을 확인할 수 있도록
                      // 디버그 빌드에만 둔다. 출시용 빌드에는 나타나지 않는다.
                      if (kDebugMode)
                        CupertinoButton(
                          padding: const EdgeInsets.only(top: 14),
                          minimumSize: Size.zero,
                          onPressed: _loading == null
                              ? () {
                                  Haptics.light();
                                  AuthService.setGuest(true);
                                }
                              : null,
                          child: Text(
                            '로그인 없이 둘러보기 (개발용)',
                            style: TextStyle(
                              fontSize: 13,
                              color: WolodyColors.of(context).textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: padding.top + 8,
            left: 24,
            right: 24,
            child: IgnorePointer(
              child: WolodyToast(
                visible: _showCanceledToast,
                icon: CupertinoIcons.exclamationmark_circle_fill,
                message: '로그인이 취소됐어요. 다시 로그인해 주세요.',
              ),
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
    final colors = WolodyColors.of(context);
    return Container(
      width: double.infinity,
      height: 60,
      // 라이트 배경에서는 흰 구글 버튼이 배경에 묻히지 않게 테두리를 두른다.
      foregroundDecoration:
          colors.isLight && background == CupertinoColors.white
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: colors.outline),
            )
          : null,
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
