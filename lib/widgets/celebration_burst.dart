import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 기록을 마쳤을 때 위쪽 가운데에서 감정 색 하트·별·동그라미가 터져 내린다.
///
/// [trigger]가 바뀔 때마다 한 번 터진다. 화면을 덮어도 터치를 막지 않도록
/// 부모에서 IgnorePointer로 감싸 쓴다. "동작 줄이기"가 켜져 있으면 터지지 않는다.
class CelebrationBurst extends StatefulWidget {
  final int trigger;
  final List<Color> colors;

  const CelebrationBurst({
    super.key,
    required this.trigger,
    required this.colors,
  });

  @override
  State<CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<CelebrationBurst>
    with SingleTickerProviderStateMixin {
  static const _count = 28;

  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  final _random = math.Random();
  List<_Particle> _particles = const [];

  @override
  void didUpdateWidget(CelebrationBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) _burst();
  }

  void _burst() {
    if (MediaQuery.disableAnimationsOf(context) || widget.colors.isEmpty) {
      return;
    }
    _particles = List.generate(_count, (i) {
      // 아래쪽으로 부채꼴(가운데 ±70°)로 퍼진다.
      final angle = math.pi / 2 + (_random.nextDouble() - 0.5) * math.pi * 0.78;
      final speed = 260 + _random.nextDouble() * 320;
      return _Particle(
        velocity: Offset(
          math.cos(angle) * speed,
          math.sin(angle) * speed - 180,
        ),
        color: widget.colors[i % widget.colors.length],
        shape: _Shape.values[_random.nextInt(_Shape.values.length)],
        size: 7 + _random.nextDouble() * 7,
        spin: (_random.nextDouble() - 0.5) * 10,
      );
    });
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _controller.isAnimating
          ? CustomPaint(
              size: Size.infinite,
              painter: _BurstPainter(_particles, _controller.value),
            )
          : const SizedBox.expand(),
    );
  }
}

enum _Shape { heart, star, dot }

class _Particle {
  final Offset velocity;
  final Color color;
  final _Shape shape;
  final double size;
  final double spin;

  const _Particle({
    required this.velocity,
    required this.color,
    required this.shape,
    required this.size,
    required this.spin,
  });
}

class _BurstPainter extends CustomPainter {
  final List<_Particle> particles;

  /// 0 → 1 진행도.
  final double t;

  _BurstPainter(this.particles, this.t);

  static const _gravity = 900.0;
  static const _seconds = 1.4;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, 0);
    final time = t * _seconds;
    // 마지막 40% 구간에서 서서히 사라진다.
    final opacity = t < 0.6 ? 1.0 : (1 - (t - 0.6) / 0.4).clamp(0.0, 1.0);
    for (final p in particles) {
      final position =
          origin + p.velocity * time + Offset(0, 0.5 * _gravity * time * time);
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas
        ..save()
        ..translate(position.dx, position.dy)
        ..rotate(p.spin * time);
      switch (p.shape) {
        case _Shape.heart:
          canvas.drawPath(_heart(p.size), paint);
        case _Shape.star:
          canvas.drawPath(_star(p.size), paint);
        case _Shape.dot:
          canvas.drawCircle(Offset.zero, p.size * 0.45, paint);
      }
      canvas.restore();
    }
  }

  Path _heart(double s) {
    final h = s / 2;
    return Path()
      ..moveTo(0, h * 0.9)
      ..cubicTo(-h * 1.6, -h * 0.2, -h * 0.6, -h * 1.4, 0, -h * 0.45)
      ..cubicTo(h * 0.6, -h * 1.4, h * 1.6, -h * 0.2, 0, h * 0.9)
      ..close();
  }

  Path _star(double s) {
    final path = Path();
    final outer = s * 0.6;
    final inner = outer * 0.45;
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final point = Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
