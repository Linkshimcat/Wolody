import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WolodyIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color? color;

  const WolodyIcon(this.asset, {super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/AssetsDesign/$asset',
      width: size,
      height: size,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
      fit: BoxFit.contain,
    );
  }
}
