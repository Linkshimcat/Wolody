import 'package:flutter/cupertino.dart';

import '../services/haptics.dart';
import '../models/mood_entry.dart';
import '../services/mood_editor.dart';
import '../services/mood_storage.dart';
import '../services/profile_storage.dart';
import '../theme.dart';
import '../widgets/cover_flow_item.dart';
import '../widgets/memory_card.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/wolody_icon.dart';
import 'profile_edit_screen.dart';
import 'recap_screen.dart';
import 'reminder_screen.dart';
import '../widgets/pressable.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<MoodEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    // 리캡에서 기록을 고치거나 설정에서 지우면 캐시가 바뀌므로 구독해 둔다.
    MoodStorage.cache.addListener(_onCacheChanged);
    MoodStorage().load().then((entries) {
      if (mounted) setState(() => _entries = entries);
    });
  }

  @override
  void dispose() {
    MoodStorage.cache.removeListener(_onCacheChanged);
    super.dispose();
  }

  void _onCacheChanged() {
    if (mounted) setState(() => _entries = MoodStorage.cache.value);
  }

  void _openRecap() {
    Haptics.light();
    Navigator.of(
      context,
    ).push(CupertinoPageRoute<void>(builder: (_) => const RecapScreen()));
  }

  int get _streak => MoodEntry.streak(_entries);

  int get _maxMoodCount {
    final counts = <String, int>{};
    for (final entry in _entries) {
      for (final emoji in entry.emojis) {
        counts.update(emoji, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return counts.values.fold<int>(
      0,
      (maximum, count) => count > maximum ? count : maximum,
    );
  }

  void _openProfileEdit() {
    Haptics.light();
    // 아래쪽 저장 버튼이 탭 바에 가리지 않도록 탭 밖(루트)에서 띄운다.
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(CupertinoPageRoute<void>(builder: (_) => const ProfileEditScreen()));
  }

  void _openSettings() {
    Haptics.light();
    // 마이 탭 Navigator에 쌓아 탭 바를 남기고 가장자리 스와이프로 돌아오게 한다.
    Navigator.of(
      context,
    ).push(CupertinoPageRoute<void>(builder: (_) => const ReminderScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final memories = _entries
        .where((entry) => entry.imageFileName != null)
        .toList();
    return CupertinoPageScaffold(
      backgroundColor: WolodyColors.of(context).background,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 17, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder<UserProfile>(
                        valueListenable: ProfileStorage.profile,
                        builder: (context, profile, _) => Text(
                          '${profile.nickname}의 프로필',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'BM Jua',
                            fontSize: 26,
                          ),
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _openSettings,
                      // 다크에서는 흰색, 라이트에서는 검정에 가까운 글자색을 따른다.
                      child: Icon(
                        CupertinoIcons.gear_alt_fill,
                        size: 24,
                        color: WolodyColors.of(context).textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                  decoration: BoxDecoration(
                    color: WolodyColors.of(context).surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: WolodyColors.of(context).cardShadow,
                  ),
                  child: Column(
                    children: [
                      // 사진·닉네임 줄을 누르면 프로필 수정으로 간다.
                      Pressable(
                        scale: 0.97,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _openProfileEdit,
                          child: Row(
                            children: [
                              const ProfileAvatar(size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ValueListenableBuilder<UserProfile>(
                                  valueListenable: ProfileStorage.profile,
                                  builder: (context, profile, _) => Text(
                                    profile.nickname,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              Icon(
                                CupertinoIcons.chevron_right,
                                size: 18,
                                color: WolodyColors.of(context).textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 34),
                      Row(
                        children: [
                          _ProfileStat(
                            label: '연속 출석',
                            value: _streak,
                            icon: 'iconsax-tick-circle.svg',
                          ),
                          const SizedBox(width: 8),
                          _ProfileStat(
                            label: '총 기록 수',
                            value: _entries.length,
                            icon: 'iconsax-note.svg',
                          ),
                          const SizedBox(width: 8),
                          _ProfileStat(
                            label: '최다 감정',
                            value: _maxMoodCount,
                            icon: 'iconsax-emoji-normal.svg',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 72, 24, 14),
              sliver: SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openRecap,
                    child: Pressable(
                      scale: 0.97,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: ValueListenableBuilder<UserProfile>(
                                valueListenable: ProfileStorage.profile,
                                builder: (context, profile, _) => Text(
                                  '${profile.nickname}의 리캡',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'BM Jua',
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              CupertinoIcons.chevron_right,
                              size: 20,
                              color: WolodyColors.of(context).textPrimary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (memories.isEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 240,
                  child: Center(
                    child: Text(
                      '아직 Wolody의 리캡이 없어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: WolodyColors.of(context).textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(child: _MemoryCarousel(memories: memories)),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final int value;
  final String icon;

  const _ProfileStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 122,
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 0),
        decoration: BoxDecoration(
          color: WolodyColors.of(context).inset,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                WolodyIcon(
                  icon,
                  size: 17,
                  color: WolodyColors.of(context).textPrimary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            // 숫자는 라벨 아래 남은 영역의 한가운데에 둔다.
            Expanded(
              child: Center(
                // 0부터 숫자가 올라간다. 값이 바뀌면 이전 값에서 이어서 올라간다.
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value.toDouble()),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, shown, _) => Text(
                    '${shown.round()}',
                    style: const TextStyle(
                      color: WolodyColors.brandBlue,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      // 숫자가 바뀌는 동안 폭이 흔들리지 않게 고정폭 숫자를 쓴다.
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Figma처럼 가운데 카드는 크게, 옆 카드는 뒤로 기울여 보여주는 커버플로 캐러셀.
class _MemoryCarousel extends StatefulWidget {
  final List<MoodEntry> memories;

  const _MemoryCarousel({required this.memories});

  @override
  State<_MemoryCarousel> createState() => _MemoryCarouselState();
}

class _MemoryCarouselState extends State<_MemoryCarousel> {
  final _controller = PageController(viewportFraction: 0.5);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.memories.length,
        onPageChanged: (_) => Haptics.selection(),
        itemBuilder: (context, index) => CoverFlowItem(
          controller: _controller,
          index: index,
          child: Center(
            child: MemoryCard(
              entry: widget.memories[index],
              width: 188,
              height: 250,
              onTap: () {
                Haptics.light();
                editMoodEntry(context, widget.memories[index]);
              },
            ),
          ),
        ),
      ),
    );
  }
}
