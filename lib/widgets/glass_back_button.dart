import 'package:flutter/cupertino.dart';

import '../theme.dart';
import 'glass_surface.dart';

/// 보조 화면 TopBar의 뒤로 가기 버튼.
/// iOS에서는 탭 바와 같은 네이티브 Liquid Glass 원 위에 화살표를 얹는다.
class GlassBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const GlassBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: 42,
        child: GlassSurface(
          child: Center(
            child: Icon(
              CupertinoIcons.chevron_left,
              size: 20,
              color: WolodyColors.of(context).textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
