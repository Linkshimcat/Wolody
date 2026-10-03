import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../services/haptics.dart';
import '../models/mood.dart';
import '../models/mood_entry.dart';
import '../services/mood_storage.dart';
import '../services/photo_storage.dart';
import '../theme.dart';
import 'wooldy_mood_portrait.dart';
import 'wolody_icon.dart';
import 'photo_viewer.dart';
import 'pressable.dart';
import 'skeleton.dart';

class MoodCard extends StatefulWidget {
  final MoodEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  /// false면 밀어서 수정/삭제하는 동작 없이 누르기만 받는다(휴지통 등).
  final bool swipeable;

  /// 카드의 울디 얼굴과 수정 화면의 큰 얼굴을 잇는 Hero 태그.
  static String faceHeroTag(MoodEntry entry) => 'face-${entry.id}';

  const MoodCard({
    super.key,
    required this.entry,
    required this.onDelete,
    required this.onTap,
    this.swipeable = true,
  });

  @override
  State<MoodCard> createState() => _MoodCardState();
}

class _MoodCardState extends State<MoodCard> {
  static const _actionWidth = 89.0;
  static const _actionGap = 12.0;
  static const _swipeDistance = _actionWidth + _actionGap;

  double _offset = 0;
  bool _dragging = false;

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragging = true;
      _offset = (_offset + details.delta.dx).clamp(
        -_swipeDistance,
        _swipeDistance,
      );
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldOpen =
        _offset.abs() >= _swipeDistance * .38 || velocity.abs() > 520;
    final direction = velocity.abs() > 520 ? velocity.sign : _offset.sign;
    Haptics.selection();
    setState(() {
      _dragging = false;
      _offset = shouldOpen ? direction * _swipeDistance : 0;
    });
  }

  void _closeActions() => setState(() => _offset = 0);

  Widget _action({
    required bool left,
    required Color color,
    required String icon,
    required VoidCallback onPressed,
  }) {
    return Positioned(
      left: left ? 0 : null,
      right: left ? null : 0,
      top: 0,
      bottom: 16,
      width: _actionWidth,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: left
                ? const BorderRadius.horizontal(left: Radius.circular(24))
                : const BorderRadius.horizontal(right: Radius.circular(24)),
          ),
          child: Center(
            child: WolodyIcon(icon, size: 28, color: CupertinoColors.white),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moods = widget.entry.emojis.map(Mood.fromEmoji).toList();
    final colors = WolodyColors.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (widget.swipeable) ...[
          _action(
            left: true,
            color: const Color(0xFF80A4FF),
            icon: 'pencil 1.svg',
            onPressed: () {
              _closeActions();
              widget.onTap();
            },
          ),
          _action(
            left: false,
            color: const Color(0xFFE92F38),
            icon: 'trash.fill 1.svg',
            onPressed: widget.onDelete,
          ),
        ],
        AnimatedContainer(
          duration: _dragging
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(_offset, 0, 0),
          transformAlignment: Alignment.topLeft,
          child: GestureDetector(
            onHorizontalDragUpdate: widget.swipeable ? _onDragUpdate : null,
            onHorizontalDragEnd: widget.swipeable ? _onDragEnd : null,
            onTap: () {
              if (_offset != 0) {
                _closeActions();
              } else {
                widget.onTap();
              }
            },
            child: Pressable(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: colors.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: moods.isEmpty
                              ? const SizedBox.shrink()
                              // 수정 화면의 큰 울디 얼굴로 이어진다(MoodEntryFlowScreen).
                              : Hero(
                                  tag: MoodCard.faceHeroTag(widget.entry),
                                  child: ClipOval(
                                    child: WooldyMoodPortrait(
                                      faceIndex: moods.first.faceIndex,
                                      size: 44,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                moods.map((m) => m.label).join(' · '),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat(
                                  'M월 d일 (E) HH:mm',
                                  'ko_KR',
                                ).format(widget.entry.date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        WolodyIcon(
                          'iconsax-note.svg',
                          size: 16,
                          color: colors.textPrimary,
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          '기록',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (widget.entry.note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.entry.note,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    if (widget.entry.imageFileName != null) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => PhotoViewer.show(
                          context,
                          PhotoStorage.pathFor(widget.entry.imageFileName!),
                          heroTag: 'photo-${widget.entry.imageFileName}',
                        ),
                        // 누르면 이 자리에서 전체 화면 사진으로 커진다.
                        child: Hero(
                          tag: 'photo-${widget.entry.imageFileName}',
                          flightShuttleBuilder: PhotoViewer.flightShuttle(
                            PhotoStorage.pathFor(widget.entry.imageFileName!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              File(
                                PhotoStorage.pathFor(
                                  widget.entry.imageFileName!,
                                ),
                              ),
                              width: double.infinity,
                              height: 140,
                              fit: BoxFit.cover,
                              // 사진을 풀어 그리는 동안 빈칸 대신 스켈레톤을 보여준다.
                              frameBuilder: (context, child, frame, sync) =>
                                  sync || frame != null
                                  ? child
                                  : const Shimmer(
                                      child: SkeletonBox(
                                        height: 140,
                                        radius: 14,
                                      ),
                                    ),
                              errorBuilder: (context, error, stackTrace) =>
                                  // 새 기기에서 로그인한 직후처럼 사진을 아직 받는 중이면
                                  // 스켈레톤을, 정말 없는 사진이면 사진 아이콘을 보여준다.
                                  MoodStorage.syncing.value
                                  ? const Shimmer(
                                      child: SkeletonBox(
                                        height: 140,
                                        radius: 14,
                                      ),
                                    )
                                  : Container(
                                      height: 160,
                                      alignment: Alignment.center,
                                      color: colors.inset,
                                      child: Icon(
                                        CupertinoIcons.photo,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
