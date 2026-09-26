import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// 카드에 첨부된 사진을 전체 화면에서 본다.
///
/// 검은 배경 위에 원본 사진을 잘리지 않게(contain) 최대 크기로 보여주고,
/// 핀치 줌/팬이 가능하다. 화면을 탭하거나 닫기 버튼을 누르면 닫힌다.
class PhotoViewer extends StatelessWidget {
  const PhotoViewer({super.key, required this.filePath});

  final String filePath;

  static Future<void> show(BuildContext context, String filePath) {
    HapticFeedback.lightImpact();
    return Navigator.of(context).push<void>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: CupertinoColors.black,
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, _, _) => PhotoViewer(filePath: filePath),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
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
                child: Center(
                  child: Image.file(
                    File(filePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(
                        CupertinoIcons.photo,
                        size: 48,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              right: 16,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  HapticFeedback.lightImpact();
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
