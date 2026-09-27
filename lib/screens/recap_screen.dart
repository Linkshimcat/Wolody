import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../models/mood.dart';
import '../models/mood_entry.dart';
import '../services/mood_editor.dart';
import '../services/mood_storage.dart';
import '../theme.dart';
import '../widgets/memory_card.dart';
import '../widgets/wolody_top_bar.dart';
import '../widgets/wooldy_mood_portrait.dart';

/// 마이 → Wolody의 리캡. 달마다 기록을 요약하고 그 달의 사진 기록을 모아 보여준다.
class RecapScreen extends StatelessWidget {
  const RecapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: WolodyColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const WolodyTopBar(title: 'Wolody의 리캡'),
            Expanded(
              child: ValueListenableBuilder<List<MoodEntry>>(
                valueListenable: MoodStorage.cache,
                builder: (context, entries, _) {
                  final months = MonthRecap.group(entries);
                  if (months.isEmpty) {
                    return const Center(
                      child: Text(
                        '아직 Wolody의 리캡이 없어요.',
                        style: TextStyle(
                          color: WolodyColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(
                      top: 24,
                      bottom: kBottomNavSpace,
                    ),
                    itemCount: months.length,
                    itemBuilder: (context, index) =>
                        _MonthSection(recap: months[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 한 달치 기록 요약.
class MonthRecap {
  final DateTime month;
  final List<MoodEntry> entries;

  /// 감정별로 고른 횟수. 많이 고른 순서로 정렬돼 있다.
  final List<MapEntry<Mood, int>> moodCounts;

  MonthRecap._(this.month, this.entries, this.moodCounts);

  int get recordedDays => entries
      .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
      .toSet()
      .length;

  int get totalMoods => moodCounts.fold(0, (sum, e) => sum + e.value);

  List<MoodEntry> get photoEntries =>
      entries.where((e) => e.imageFileName != null).toList();

  /// 기록을 달별로 묶어 최신 달부터 돌려준다.
  static List<MonthRecap> group(List<MoodEntry> entries) {
    final byMonth = <DateTime, List<MoodEntry>>{};
    for (final entry in entries) {
      byMonth
          .putIfAbsent(DateTime(entry.date.year, entry.date.month), () => [])
          .add(entry);
    }
    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final month in months)
        MonthRecap._(
          month,
          byMonth[month]!..sort((a, b) => b.date.compareTo(a.date)),
          _countMoods(byMonth[month]!),
        ),
    ];
  }

  static List<MapEntry<Mood, int>> _countMoods(List<MoodEntry> entries) {
    final counts = <String, int>{};
    final moods = <String, Mood>{};
    for (final entry in entries) {
      for (final emoji in entry.emojis) {
        final mood = Mood.fromEmoji(emoji);
        moods[mood.label] = mood;
        counts.update(mood.label, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    return counts.entries.map((e) => MapEntry(moods[e.key]!, e.value)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }
}

class _MonthSection extends StatelessWidget {
  final MonthRecap recap;

  const _MonthSection({required this.recap});

  @override
  Widget build(BuildContext context) {
    final photos = recap.photoEntries;
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '${recap.month.year}년 ${recap.month.month}월',
              style: const TextStyle(fontFamily: 'BM Jua', fontSize: 22),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _SummaryCard(recap: recap),
          ),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 18),
            SizedBox(
              height: 200,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => MemoryCard(
                  entry: photos[index],
                  width: 150,
                  height: 200,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    editMoodEntry(context, photos[index]);
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final MonthRecap recap;

  const _SummaryCard({required this.recap});

  @override
  Widget build(BuildContext context) {
    final top = recap.moodCounts.isEmpty ? null : recap.moodCounts.first;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: WolodyColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (top != null)
            Row(
              children: [
                _GlowPortrait(mood: top.key),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '가장 많이 느낀 마음',
                        style: TextStyle(
                          fontSize: 12,
                          color: WolodyColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        top.key.label,
                        style: const TextStyle(
                          fontFamily: 'BM Jua',
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${top.value}번 골랐어요',
                        style: const TextStyle(
                          fontSize: 12,
                          color: WolodyColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              _Stat(label: '기록', value: '${recap.entries.length}개'),
              _Stat(label: '기록한 날', value: '${recap.recordedDays}일'),
              _Stat(label: '사진', value: '${recap.photoEntries.length}장'),
            ],
          ),
          if (recap.totalMoods > 0) ...[
            const SizedBox(height: 18),
            _MoodBar(recap: recap),
          ],
        ],
      ),
    );
  }
}

/// 울디 얼굴 뒤로 그 감정 색을 은은하게 번지게 한다(감정 선택 카드와 같은 표현).
class _GlowPortrait extends StatelessWidget {
  final Mood mood;

  const _GlowPortrait({required this.mood});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            mood.color.withValues(alpha: 0.45),
            mood.color.withValues(alpha: 0),
          ],
        ),
      ),
      child: WooldyMoodPortrait(faceIndex: mood.faceIndex, size: 56),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2D3648),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: WolodyColors.brandBlue,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: WolodyColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 감정 비율을 감정 색으로 이어 칠한 막대와 상위 3개 범례.
class _MoodBar extends StatelessWidget {
  final MonthRecap recap;

  const _MoodBar({required this.recap});

  @override
  Widget build(BuildContext context) {
    final total = recap.totalMoods;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              // 자식(ColoredBox)이 높이를 갖도록 막대 높이만큼 늘린다.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in recap.moodCounts)
                  Expanded(
                    flex: entry.value,
                    child: ColoredBox(color: entry.key.color),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final entry in recap.moodCounts.take(3))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: entry.key.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${entry.key.label} ${(entry.value * 100 / total).round()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: WolodyColors.textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
