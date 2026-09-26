import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/mood_entry.dart';
import '../services/live_activity_service.dart';
import '../services/mood_editor.dart';
import '../services/mood_storage.dart';
import '../services/photo_storage.dart';
import '../services/widget_service.dart';
import '../theme.dart';
import '../widgets/mood_card.dart';
import '../widgets/wolody_icon.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _dayLabels = ['일', '월', '화', '수', '목', '금', '토'];

  final _storage = MoodStorage();
  Map<DateTime, List<MoodEntry>> _byDay = {};
  late DateTime _month;
  late DateTime _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    MoodStorage.cache.addListener(_onCacheChanged);
    final today = _dateOnly(DateTime.now());
    _month = DateTime(today.year, today.month);
    _selected = today;
    _load();
  }

  @override
  void dispose() {
    MoodStorage.cache.removeListener(_onCacheChanged);
    super.dispose();
  }

  void _onCacheChanged() {
    if (!mounted) return;
    _apply(MoodStorage.cache.value);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _load() async {
    final entries = await _storage.load();
    _apply(entries);
  }

  void _apply(List<MoodEntry> entries) {
    final grouped = <DateTime, List<MoodEntry>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(_dateOnly(entry.date), () => []).add(entry);
    }
    setState(() {
      _byDay = grouped;
      _loading = false;
    });
  }

  Future<void> _edit(MoodEntry entry) async {
    HapticFeedback.lightImpact();
    if (await editMoodEntry(context, entry)) await _load();
  }

  Future<void> _delete(MoodEntry entry) async {
    HapticFeedback.mediumImpact();
    final entries = await _storage.load();
    entries.removeWhere((e) => e.id == entry.id);
    await _storage.save(entries);
    if (entry.imageFileName != null) {
      await PhotoStorage.delete(entry.imageFileName!);
    }
    await LiveActivityService.refresh();
    await WidgetService.refresh();
    await _load();
  }

  void _changeMonth(int delta) {
    HapticFeedback.lightImpact();
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final selectedEntries = _byDay[_selected] ?? const <MoodEntry>[];
    return CupertinoPageScaffold(
      backgroundColor: kAppBackground,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: kNavBarBackground,
        middle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Wolody 달력', style: TextStyle(fontFamily: 'BM Jua')),
            SizedBox(width: 6),
            WolodyIcon(
              'iconsax-calendar.svg',
              size: 18,
              color: CupertinoColors.white,
            ),
          ],
        ),
      ),
      child: _loading
          ? const Center(child: CupertinoActivityIndicator())
          : SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildMonthHeader()),
                  SliverToBoxAdapter(child: _buildWeekdayLabels(context)),
                  SliverToBoxAdapter(child: _buildGrid(context)),
                  SliverToBoxAdapter(child: _buildSelectedHeader(context)),
                  if (selectedEntries.isEmpty)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 216,
                        child: Center(
                          child: Text(
                            '이 날은 기록이 없어요.',
                            style: const TextStyle(
                              color: WolodyColors.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: selectedEntries.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: MoodCard(
                          entry: selectedEntries[i],
                          onDelete: () => _delete(selectedEntries[i]),
                          onTap: () => _edit(selectedEntries[i]),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: kBottomNavSpace),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMonthHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  DateFormat('M월 yyyy', 'ko_KR').format(_month),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 12,
                  color: WolodyColors.brandBlue,
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _changeMonth(-1),
            child: const Icon(CupertinoIcons.chevron_left, size: 20),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _changeMonth(1),
            child: const Icon(CupertinoIcons.chevron_right, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayLabels(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: _dayLabels
            .map(
              (label) => Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final firstDay = DateTime(_month.year, _month.month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // Figma 달력은 일요일부터 시작한다.
    final leadingBlanks = firstDay.weekday % 7;
    final cells = leadingBlanks + daysInMonth;
    final rows = (cells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Column(
        children: List.generate(rows, (row) {
          return Row(
            children: List.generate(7, (col) {
              final dayNumber = row * 7 + col - leadingBlanks + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const Expanded(child: SizedBox(height: 50));
              }
              return Expanded(
                child: _buildDayCell(
                  context,
                  DateTime(_month.year, _month.month, dayNumber),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildDayCell(BuildContext context, DateTime day) {
    final isSelected = day == _selected;
    final isToday = day == _dateOnly(DateTime.now());
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selected = day);
      },
      child: Container(
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF22365E) : null,
          border: isSelected
              ? Border.all(color: WolodyColors.brandBlue, width: 1)
              : null,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: isToday || isSelected
                    ? FontWeight.w700
                    : FontWeight.w400,
                color: isSelected
                    ? WolodyColors.brandBlue
                    : CupertinoColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Text(
        DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(_selected),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
    );
  }
}
