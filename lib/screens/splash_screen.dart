import 'package:flutter/cupertino.dart';

import '../theme.dart';
import 'root_screen.dart';

class SplashScreen extends StatefulWidget {
  final Future<void> initialization;

  const SplashScreen({super.key, required this.initialization});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // 글자들이 차례로 굴러 들어와 멈추는 데 걸리는 시간.
  late final _roll = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void initState() {
    super.initState();
    _openHome();
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  Future<void> _openHome() async {
    await Future.wait([
      widget.initialization,
      // 워드마크가 다 멈춘 뒤 잠깐 머물렀다가 홈으로 넘어간다.
      Future<void>.delayed(const Duration(milliseconds: 1500)),
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const RootScreen(),
        transitionDuration: const Duration(milliseconds: 240),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: WolodyColors.background,
      child: Center(
        child: _RollingWordmark(word: 'Wolody', progress: _roll),
      ),
    );
  }
}

/// 슬롯머신처럼 글자마다 다른 글자들이 위로 굴러 지나간 뒤 제자리에 멈추는 워드마크.
class _RollingWordmark extends StatelessWidget {
  final String word;
  final Animation<double> progress;

  const _RollingWordmark({required this.word, required this.progress});

  static const _style = TextStyle(
    fontFamily: 'BM Jua',
    fontSize: 54,
    height: 1.2,
    letterSpacing: 4,
    color: Color(0xFF80A4FF),
  );

  /// 각 글자가 멈추기 전에 지나가는 글자 수.
  static const _reelLength = 3;

  @override
  Widget build(BuildContext context) {
    final letters = word.characters.toList();
    // 글자마다 시작을 조금씩 늦춰 왼쪽부터 차례로 멈추게 한다.
    const stagger = 0.08;
    final span = 1 - stagger * (letters.length - 1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < letters.length; i++)
          _RollingLetter(
            reel: [
              for (var k = 1; k <= _reelLength; k++)
                letters[(i + k) % letters.length],
              letters[i],
            ],
            style: _style,
            progress: CurvedAnimation(
              parent: progress,
              curve: Interval(
                stagger * i,
                stagger * i + span,
                curve: Curves.easeOutBack,
              ),
            ),
          ),
      ],
    );
  }
}

class _RollingLetter extends AnimatedWidget {
  /// 위에서부터 차례로 지나갈 글자들. 마지막이 최종 글자다.
  final List<String> reel;
  final TextStyle style;

  const _RollingLetter({
    required this.reel,
    required this.style,
    required Animation<double> progress,
  }) : super(listenable: progress);

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    final lineHeight = style.fontSize! * style.height!;
    return ClipRect(
      child: Stack(
        children: [
          // 칸 크기는 최종 글자에 맞춰 레이아웃이 흔들리지 않게 한다.
          Opacity(opacity: 0, child: Text(reel.last, style: style)),
          Positioned(
            left: 0,
            right: 0,
            // 첫 글자 한 줄 아래(빈칸)에서 출발해 마지막 글자에서 멈춘다.
            top: lineHeight * (1 - t * reel.length),
            child: Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Column(
                children: [
                  for (final letter in reel)
                    SizedBox(
                      height: lineHeight,
                      child: Text(
                        letter,
                        style: style,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
