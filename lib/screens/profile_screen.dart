import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../models/mood_entry.dart';
import '../services/mood_storage.dart';
import '../services/photo_storage.dart';
import '../services/profile_storage.dart';
import '../theme.dart';
import '../widgets/profile_avatar.dart';
import 'profile_edit_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onOpenSettings;

  const ProfileScreen({super.key, required this.onOpenSettings});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<MoodEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    MoodStorage().load().then((entries) {
      if (mounted) setState(() => _entries = entries);
    });
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
    Navigator.of(
      context,
    ).push(CupertinoPageRoute<void>(builder: (_) => const ProfileEditScreen()));
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
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        widget.onOpenSettings();
                      },
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
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Wolody의 리캡',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      CupertinoIcons.chevron_right,
                      color: WolodyColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            if (memories.isEmpty)
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 240,
                  child: Center(
                    child: Text(
                      '아직 Wolody의 리캡이 없어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: WolodyColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 250,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    scrollDirection: Axis.horizontal,
                    itemCount: memories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) =>
                        _MemoryCard(entry: memories[index]),
                  ),
                ),
              ),
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

class _MemoryCard extends StatelessWidget {
  final MoodEntry entry;

  const _MemoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final path = PhotoStorage.pathFor(entry.imageFileName!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        width: 188,
        height: 250,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(path), fit: BoxFit.cover),
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
    );
  }
}
