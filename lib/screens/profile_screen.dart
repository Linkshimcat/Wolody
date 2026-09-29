import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../models/mood_entry.dart';
import '../services/mood_editor.dart';
import '../services/mood_storage.dart';
import '../services/profile_storage.dart';
import '../theme.dart';
import '../widgets/cover_flow_item.dart';
import '../widgets/memory_card.dart';
import '../widgets/profile_avatar.dart';
import 'profile_edit_screen.dart';
import 'recap_screen.dart';
import 'reminder_screen.dart';

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
    HapticFeedback.lightImpact();
    Navigator.of(
      context,
    ).push(CupertinoPageRoute<void>(builder: (_) => const RecapScreen()));
  }

  int get _streak {
    final dates = _entries
        .map(
          (entry) =>
              DateTime(entry.date.year, entry.date.month, entry.date.day),
        )
        .toSet();
    var day = DateTime.now();
    var count = 0;
    while (dates.contains(DateTime(day.year, day.month, day.day))) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

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
    HapticFeedback.lightImpact();
    // 아래쪽 저장 버튼이 탭 바에 가리지 않도록 탭 밖(루트)에서 띄운다.
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(CupertinoPageRoute<void>(builder: (_) => const ProfileEditScreen()));
  }

  void _openSettings() {
    HapticFeedback.lightImpact();
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
      backgroundColor: WolodyColors.background,
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
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _openSettings,
                      child: const Icon(CupertinoIcons.gear_alt_fill, size: 24),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: WolodyColors.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      // 사진·닉네임 줄을 누르면 프로필 수정으로 간다.
                      GestureDetector(
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
                            const Icon(
                              CupertinoIcons.chevron_right,
                              size: 18,
                              color: WolodyColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 33),
                      Row(
                        children: [
                          _ProfileStat(
                            label: '연속 출석',
                            value: '$_streak',
                            icon: CupertinoIcons.checkmark_seal_fill,
                          ),
                          const SizedBox(width: 8),
                          _ProfileStat(
                            label: '총 기록 수',
                            value: '${_entries.length}',
                            icon: CupertinoIcons.calendar,
                          ),
                          const SizedBox(width: 8),
                          _ProfileStat(
                            label: '최대 감정',
                            value: '$_maxMoodCount',
                            icon: CupertinoIcons.smiley,
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
                          const Icon(
                            CupertinoIcons.chevron_right,
                            size: 20,
                            color: CupertinoColors.white,
                          ),
                        ],
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
                      '아직 ${ProfileStorage.profile.value.nickname}의 리캡이 없어요.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: WolodyColors.textSecondary,
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
  final String value;
  final IconData icon;

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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF2D3648),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: CupertinoColors.white),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: Text(
                value,
                style: const TextStyle(
                  color: WolodyColors.brandBlue,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
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
        onPageChanged: (_) => HapticFeedback.selectionClick(),
        itemBuilder: (context, index) => CoverFlowItem(
          controller: _controller,
          index: index,
          child: Center(
            child: MemoryCard(
              entry: widget.memories[index],
              width: 188,
              height: 250,
              onTap: () {
                HapticFeedback.lightImpact();
                editMoodEntry(context, widget.memories[index]);
              },
            ),
          ),
        ),
      ),
    );
  }
}
