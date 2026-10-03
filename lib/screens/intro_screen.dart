import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';

import '../models/mood.dart';
import '../services/haptics.dart';
import '../services/onboarding.dart';
import '../theme.dart';
import '../widgets/cover_flow_item.dart';
import '../widgets/pressable.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/wooldy_mood_portrait.dart';

/// 처음 설치했을 때 로그인 전에 보여주는 소개 3장.
///
/// 울디 소개 → 감정 카드로 기록하기 → 달력으로 돌아보기. 언제든 건너뛸 수 있고,
/// 마지막 장의 "시작하기"나 "이미 계정이 있어요"를 누르면 로그인 화면으로 간다.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroPageData {
  final String title;
  final String body;
  final Color glow;

  const _IntroPageData(this.title, this.body, this.glow);
}

class _IntroScreenState extends State<IntroScreen> {
  static const _pages = [
    _IntroPageData(
      '안녕, 나는 울디야!',
      '하루에 한 번, 오늘의 마음을\n울디와 함께 기록해요.',
      WolodyColors.brandBlue,
    ),
    _IntroPageData(
      '감정 카드로 10초면 끝',
      '오늘 마음에 맞는 울디를 고르고\n한 줄 메모와 사진을 남겨요.',
      Color(0xFFFFD58A),
    ),
    _IntroPageData(
      '달력과 리캡으로 돌아봐요',
      '기록이 쌓이면 한 달의 마음이\n한눈에 보여요.',
      Color(0xFFAAA6DB),
    ),
  ];

  final _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) return _finish();
    _controller.nextPage(
      duration: MediaQuery.disableAnimationsOf(context)
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _finish() {
    Haptics.light();
    Onboarding.finishIntro();
  }

  @override
  Widget build(BuildContext context) {
    final colors = WolodyColors.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return CupertinoPageScaffold(
      backgroundColor: colors.background,
      child: Stack(
        children: [
          // 장마다 색이 바뀌는 은은한 빛. 감정 기록 화면의 배경과 같은 방식이다.
          Positioned.fill(
            child: IgnorePointer(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 480),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.3),
                      radius: 0.85,
                      colors: [
                        _pages[_page].glow.withValues(alpha: 0.32),
                        _pages[_page].glow.withValues(alpha: 0.12),
                        colors.background.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.45, 1],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedOpacity(
                      opacity: _isLast ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        onPressed: _isLast ? null : _finish,
                        child: Text(
                          '건너뛰기',
                          style: TextStyle(
                            fontSize: 15,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (page) {
                      Haptics.selection();
                      setState(() => _page = page);
                    },
                    itemBuilder: (context, index) => _IntroPage(
                      controller: _controller,
                      index: index,
                      data: _pages[index],
                      illustration: switch (index) {
                        0 => Image.asset(
                          'assets/AssetsDesign/wooldy_wave.png',
                          height: 250,
                          fit: BoxFit.contain,
                        ),
                        1 => const _MoodPeek(),
                        _ => _CalendarPeek(active: _page == 2),
                      },
                    ),
                  ),
                ),
                _Dots(count: _pages.length, current: _page),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 4),
                  child: PrimaryActionButton(
                    label: _isLast ? '시작하기' : '다음',
                    onPressed: _next,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 8),
                  onPressed: _finish,
                  child: Text(
                    '이미 계정이 있어요',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 한 장. 넘길 때 그림이 글자보다 조금 더 빨리 움직이고(패럴랙스) 글자는 흐려진다.
class _IntroPage extends StatelessWidget {
  final PageController controller;
  final int index;
  final _IntroPageData data;
  final Widget illustration;

  const _IntroPage({
    required this.controller,
    required this.index,
    required this.data,
    required this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    final colors = WolodyColors.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final page = controller.hasClients && controller.position.haveDimensions
            ? controller.page ?? 0
            : 0.0;
        final offset = (index - page).clamp(-1.0, 1.0);
        final width = MediaQuery.sizeOf(context).width;
        final textOpacity = (1 - offset.abs() * 1.4).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Transform.translate(
                offset: Offset(reduceMotion ? 0 : offset * width * 0.3, 0),
                child: SizedBox(
                  height: 270,
                  child: Center(child: illustration),
                ),
              ),
              const Spacer(),
              Opacity(
                opacity: reduceMotion ? 1 : textOpacity,
                child: Column(
                  children: [
                    Text(
                      data.title,
                      textAlign: TextAlign.center,
                      style: kSectionTitleStyle.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      data.body,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        );
      },
    );
  }
}

/// 페이지 점. 지금 장은 길쭉한 파란 캡슐로 늘어난다.
class _Dots extends StatelessWidget {
  final int count;
  final int current;

  const _Dots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    final colors = WolodyColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == current ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current ? WolodyColors.brandBlue : colors.outline,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

/// 2장: 실제 감정 기록 화면처럼 넘기고 눌러 볼 수 있는 작은 감정 카드들.
class _MoodPeek extends StatefulWidget {
  const _MoodPeek();

  @override
  State<_MoodPeek> createState() => _MoodPeekState();
}

class _MoodPeekState extends State<_MoodPeek> {
  /// 행복 · 보통 · 설렘 · 슬픔 · 화남
  static final _moods = [0, 4, 2, 5, 8].map((i) => Mood.all[i]).toList();

  final _controller = PageController(viewportFraction: 0.42, initialPage: 1);
  final _picked = <int>{};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = WolodyColors.of(context);
    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: _controller,
        itemCount: _moods.length,
        onPageChanged: (_) => Haptics.selection(),
        itemBuilder: (context, index) {
          final mood = _moods[index];
          final picked = _picked.contains(index);
          return CoverFlowItem(
            controller: _controller,
            index: index,
            child: Center(
              child: Pressable(
                child: GestureDetector(
                  onTap: () {
                    Haptics.selection();
                    setState(() {
                      if (!_picked.remove(index)) _picked.add(index);
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 132,
                    height: 196,
                    decoration: BoxDecoration(
                      color: colors.selectorSurface,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: colors.cardShadow,
                      border: Border.all(
                        color: picked ? mood.color : const Color(0x00000000),
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 36,
                          child: WooldyMoodPortrait(
                            faceIndex: mood.faceIndex,
                            size: 84,
                          ),
                        ),
                        Positioned(
                          bottom: 22,
                          child: Text(
                            mood.label,
                            style: TextStyle(
                              fontFamily: 'BM Jua',
                              fontSize: 15,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        if (picked)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: mood.color,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.checkmark,
                                size: 13,
                                color: Color(0xFF161E2A),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 3장: 2주치 미니 달력. 이 장에 오면 기록한 날마다 울디 얼굴이 차례로 톡톡 나타난다.
class _CalendarPeek extends StatefulWidget {
  final bool active;

  const _CalendarPeek({required this.active});

  @override
  State<_CalendarPeek> createState() => _CalendarPeekState();
}

class _CalendarPeekState extends State<_CalendarPeek>
    with SingleTickerProviderStateMixin {
  static const _labels = ['일', '월', '화', '수', '목', '금', '토'];

  /// 2주(14칸) 중 기록한 날과 그날의 감정 얼굴 번호. 마지막 5일이 연속 기록이다.
  static const _faces = {1: 1, 3: 3, 4: 0, 9: 2, 10: 4, 11: 0, 12: 6, 13: 1};

  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    // 이 장이 그려지는 순간 이미 현재 장일 수도 있다(빠르게 넘긴 경우).
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _play();
      });
    }
  }

  @override
  void didUpdateWidget(_CalendarPeek oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _play();
  }

  void _play() {
    _controller.value = 0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = WolodyColors.of(context);
    final order = _faces.keys.toList();
    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                '10월',
                style: TextStyle(fontFamily: 'BM Jua', fontSize: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: WolodyColors.brandBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '연속 5일',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: WolodyColors.brandBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final label in _labels)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (var row = 0; row < 2; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(child: _cell(colors, row * 7 + col, order)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(WolodyPalette colors, int index, List<int> order) {
    final face = _faces[index];
    return SizedBox(
      height: 54,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${index + 5}',
            style: TextStyle(fontSize: 13, color: colors.textPrimary),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 22,
            child: face == null
                ? null
                : AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      // 기록한 날마다 조금씩 늦게 통 튀어나온다.
                      final start = order.indexOf(index) * 0.09;
                      final t = Interval(
                        start,
                        (start + 0.35).clamp(0.0, 1.0),
                        curve: Curves.easeOutBack,
                      ).transform(_controller.value);
                      return Transform.scale(scale: t, child: child);
                    },
                    child: WooldyMoodPortrait(faceIndex: face, size: 22),
                  ),
          ),
        ],
      ),
    );
  }
}
