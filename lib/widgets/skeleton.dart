import 'package:flutter/cupertino.dart';

import '../theme.dart';

/// 스켈레톤 조각들 위로 은은한 빛이 왼쪽에서 오른쪽으로 지나가게 한다.
///
/// 한 화면의 스켈레톤을 이 위젯 하나로 감싸면 모든 조각이 같은 박자로 빛나서,
/// 조각마다 제각각 반짝이는 것보다 차분해 보인다. 카드 배경은 그대로 두고
/// [SkeletonBox]만 빛난다. '동작 줄이기'를 켠 사용자에게는 고정된 모양만 보여준다.
class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerScope(animation: _controller, child: widget.child);
  }
}

class _ShimmerScope extends InheritedNotifier<Animation<double>> {
  const _ShimmerScope({
    required Animation<double> animation,
    required super.child,
  }) : super(notifier: animation);

  static Animation<double>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.notifier;
}

/// 내용이 들어갈 자리를 나타내는 둥근 회색 조각.
class SkeletonBox extends StatelessWidget {
  static const base = WolodyColors.selectorSurface;
  static const highlight = Color(0xFF34405A);

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
    this.shape = BoxShape.rectangle,
  });

  const SkeletonBox.circle({super.key, required double size})
    : width = size,
      height = size,
      radius = 0,
      shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    final animation = _ShimmerScope.of(context);
    // -0.5 → 1.5로 지나가는 밝은 띠. Shimmer 밖에서는 빛 없이 그린다.
    final t = animation == null ? null : animation.value * 2 - 0.5;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: t == null ? base : null,
        gradient: t == null
            ? null
            : LinearGradient(
                colors: const [base, highlight, base],
                stops: [t - 0.35, t, t + 0.35],
              ),
        shape: shape,
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(radius),
      ),
    );
  }
}

/// [MoodCard]와 같은 모양의 로딩 카드(얼굴 · 감정/날짜 · 기록 · 사진).
class MoodCardSkeleton extends StatelessWidget {
  final bool withPhoto;

  const MoodCardSkeleton({super.key, this.withPhoto = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: WolodyColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              SkeletonBox.circle(size: 44),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 96, height: 14),
                  SizedBox(height: 6),
                  SkeletonBox(width: 128, height: 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SkeletonBox(width: 44, height: 12),
          const SizedBox(height: 10),
          const SkeletonBox(height: 10),
          const SizedBox(height: 6),
          const SkeletonBox(width: 180, height: 10),
          if (withPhoto) ...[
            const SizedBox(height: 12),
            const SkeletonBox(height: 140, radius: 14),
          ],
        ],
      ),
    );
  }
}

/// 기록 목록이 오기 전에 보여줄 카드 몇 장.
class MoodListSkeleton extends StatelessWidget {
  final int count;

  const MoodListSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: [
          for (var i = 0; i < count; i++) MoodCardSkeleton(withPhoto: i.isEven),
        ],
      ),
    );
  }
}
