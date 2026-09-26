import 'package:flutter/cupertino.dart';

class WooldyMoodPortrait extends StatelessWidget {
  final int faceIndex;
  final double size;

  const WooldyMoodPortrait({
    super.key,
    required this.faceIndex,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final column = faceIndex % 4;
    final row = faceIndex ~/ 4;
    return SizedBox.square(
      dimension: size,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: -column * size,
              top: -row * size,
              child: Image.asset(
                'assets/AssetsDesign/EmotionAssets.png',
                width: size * 4,
                height: size * 3,
                fit: BoxFit.fill,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
