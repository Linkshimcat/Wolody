import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../services/haptics.dart';

/// 카드에 첨부된 사진을 전체 화면에서 본다.
///
/// 검은 배경 위에 원본 사진을 잘리지 않게(contain) 최대 크기로 보여주고,
/// 핀치 줌/팬이 가능하다. 화면을 탭하거나 닫기 버튼을 누르면 닫힌다.
class PhotoViewer extends StatelessWidget {
  const PhotoViewer({super.key, required this.filePath, this.heroTag});

  final String filePath;

  /// 카드의 사진과 같은 태그를 주면 그 자리에서 커지며 열리고, 닫을 때 돌아간다.
  final String? heroTag;

  static Future<void> show(
    BuildContext context,
    String filePath, {
    String? heroTag,
  }) {
    Haptics.light();
    return Navigator.of(context).push<void>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: CupertinoColors.black,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) =>
            PhotoViewer(filePath: filePath, heroTag: heroTag),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  /// 카드의 잘린 사진(cover, 둥근 모서리)에서 전체 사진으로 커지는 동안 그리는 모습.
  /// 날아가는 내내 영역을 꽉 채우고(cover) 모서리만 14 → 0으로 펴진다.
  static HeroFlightShuttleBuilder flightShuttle(String filePath) {
    return (flightContext, animation, direction, fromContext, toContext) =>
        AnimatedBuilder(
          animation: animation,
          builder: (context, _) => ClipRRect(
            borderRadius: BorderRadius.circular(14 * (1 - animation.value)),
            child: Image.file(File(filePath), fit: BoxFit.cover),
          ),
        );
  }

  Widget _photo() {
    final image = Image.file(
      File(filePath),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(
          CupertinoIcons.photo,
          size: 48,
          color: CupertinoColors.systemGrey,
        ),
      ),
    );
    final tag = heroTag;
    if (tag == null) return image;
    return Hero(
      tag: tag,
      flightShuttleBuilder: flightShuttle(filePath),
      child: image,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Haptics.light();
        Navigator.of(context).pop();
      },
      child: Container(
        color: CupertinoColors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(child: _photo()),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              right: 16,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  Haptics.light();
                  Navigator.of(context).pop();
                },
                child: const Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 32,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
