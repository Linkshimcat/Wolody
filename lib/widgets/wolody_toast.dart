import 'package:flutter/cupertino.dart';

import '../theme.dart';

/// 화면 위쪽에 잠깐 뜨는 캡슐 토스트. 위에서 살짝 튕기듯 내려오고, 위로 빠지며 사라진다.
///
/// 들어오고 나가는 움직임이 보이도록 늘 자리에 두고 [visible]만 바꾼다.
class WolodyToast extends StatelessWidget {
  final bool visible;
  final IconData icon;
  final String message;

  const WolodyToast({
    super.key,
    required this.visible,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = WolodyColors.of(context);
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, -1.6),
      duration: Duration(milliseconds: visible ? 520 : 320),
      curve: visible ? Curves.easeOutBack : Curves.easeInCubic,
      child: AnimatedScale(
        scale: visible ? 1 : 0.9,
        duration: Duration(milliseconds: visible ? 520 : 320),
        curve: visible ? Curves.easeOutBack : Curves.easeInCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: Duration(milliseconds: visible ? 220 : 280),
          curve: Curves.easeOut,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colors.toastBackground,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: colors.isLight
                      ? const Color(0x260F172A)
                      : const Color(0x66000000),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: colors.textPrimary),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
