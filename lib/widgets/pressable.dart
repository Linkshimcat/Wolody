import 'package:flutter/widgets.dart';

/// 누르는 동안 살짝 작아졌다가 떼면 통 튕기며 돌아오는 손맛.
///
/// 포인터만 지켜보고 제스처는 가로채지 않아서, 안쪽의 탭·스와이프나 바깥 스크롤과
/// 함께 쓸 수 있다. 손가락이 일정 거리 넘게 움직이면 누르기를 그만둔 것으로 본다.
/// iOS "동작 줄이기"가 켜져 있으면 크기를 바꾸지 않는다.
class Pressable extends StatefulWidget {
  final Widget child;
  final double scale;
  final bool enabled;

  const Pressable({
    super.key,
    required this.child,
    this.scale = 0.96,
    this.enabled = true,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  /// 이만큼 넘게 끌면 스크롤·스와이프로 보고 원래 크기로 돌린다.
  static const _slop = 12.0;

  bool _pressed = false;
  Offset? _origin;

  void _down(PointerDownEvent event) {
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) return;
    _origin = event.position;
    setState(() => _pressed = true);
  }

  void _move(PointerMoveEvent event) {
    final origin = _origin;
    if (!_pressed || origin == null) return;
    if ((event.position - origin).distance > _slop) _release();
  }

  void _release([PointerEvent? _]) {
    _origin = null;
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _release,
      onPointerCancel: _release,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: Duration(milliseconds: _pressed ? 90 : 260),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
