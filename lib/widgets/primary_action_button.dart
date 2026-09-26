import 'package:flutter/cupertino.dart';

import '../theme.dart';

class PrimaryActionButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        borderRadius: BorderRadius.circular(17),
        color: WolodyColors.actionLavender,
        disabledColor: WolodyColors.actionLavender.withValues(alpha: 0.45),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
