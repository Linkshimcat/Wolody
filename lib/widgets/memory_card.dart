import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../models/mood_entry.dart';
import '../services/mood_storage.dart';
import '../services/photo_storage.dart';
import 'skeleton.dart';

/// 사진이 있는 기록을 세로 카드로 보여준다(마이 캐러셀·리캡).
/// 위쪽에 메모 첫 줄을 얹고, 글자가 읽히도록 위아래를 어둡게 깐다.
class MemoryCard extends StatelessWidget {
  final MoodEntry entry;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const MemoryCard({
    super.key,
    required this.entry,
    this.width = 188,
    this.height = 250,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final path = PhotoStorage.pathFor(entry.imageFileName!);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(path),
                fit: BoxFit.cover,
                // 사진을 풀어 그리거나 아직 받는 중이면 스켈레톤을 보여준다.
                frameBuilder: (context, child, frame, sync) =>
                    sync || frame != null
                    ? child
                    : const Shimmer(
                        child: SkeletonBox(height: double.infinity),
                      ),
                errorBuilder: (_, _, _) => MoodStorage.syncing.value
                    ? const Shimmer(child: SkeletonBox(height: double.infinity))
                    : const ColoredBox(color: Color(0xFF242D3B)),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x990D1118),
                      Color(0x000D1118),
                      Color(0xCC0D1118),
                    ],
                    stops: [0, 0.38, 1],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                top: 16,
                child: Text(
                  entry.note.isEmpty ? '오늘의 마음' : entry.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
