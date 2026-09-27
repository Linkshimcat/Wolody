import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../services/haptics.dart';
import '../theme.dart';

/// Figma의 라벤더 CTA 버튼.
///
/// [onPressed]가 null이면 비활성으로 보이고, 그래도 누르면 오류 햅틱과 함께
/// 버튼이 좌우로 흔들려 "아직 누를 수 없어요"를 알려준다.
class PrimaryActionButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final double height;

  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 58,
  });

  @override
  State<PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<PrimaryActionButton>
    with SingleTickerProviderStateMixin {
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _rejectTap() {
    Haptics.error();
    _shake.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        // 세 번 왕복하며 점점 잦아드는 흔들림(최대 10pt).
        final t = _shake.value;
        final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: GestureDetector(
        // 비활성 CupertinoButton은 탭을 받지 않으므로 바깥에서 대신 받는다.
        onTap: enabled ? null : _rejectTap,
        child: SizedBox(
          width: double.infinity,
          height: widget.height,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            borderRadius: BorderRadius.circular(17),
            color: WolodyColors.actionLavender,
            disabledColor: WolodyColors.actionLavender.withValues(alpha: 0.45),
            onPressed: widget.onPressed,
            child: Text(
              widget.label,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
