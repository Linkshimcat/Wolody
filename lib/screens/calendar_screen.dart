import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../services/haptics.dart';
import '../models/mood.dart';
import '../models/mood_entry.dart';
import '../services/mood_editor.dart';
import '../services/mood_storage.dart';
import '../theme.dart';
import '../widgets/mood_card.dart';
import '../widgets/skeleton.dart';
import '../widgets/wolody_icon.dart';
import '../widgets/wooldy_mood_portrait.dart';
import '../widgets/pressable.dart';

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
  int _slideDirection = 1;
  late DateTime _selected;
  bool _loading = true;
  // "M월 yyyy ›"를 누르면 달력 격자 자리에 년·월·일 휠이 펼쳐진다.
  bool _pickingDate = false;

  @override
  void initState() {
    super.initState();
    MoodStorage.cache.addListener(_onCacheChanged);
    MoodStorage.syncing.addListener(_onSyncingChanged);
    final today = _dateOnly(DateTime.now());
    _month = DateTime(today.year, today.month);
    _selected = today;
    _load();
  }

  @override
  void dispose() {
    MoodStorage.cache.removeListener(_onCacheChanged);
    MoodStorage.syncing.removeListener(_onSyncingChanged);
    super.dispose();
  }

  void _onSyncingChanged() {
    if (mounted) setState(() {});
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
    Haptics.light();
    if (await editMoodEntry(context, entry)) await _load();
  }

  Future<void> _delete(MoodEntry entry) async {
    Haptics.medium();
    // 바로 지우지 않고 휴지통(설정 → 삭제된 기록)으로 옮긴다.
    await deleteMoodEntry(entry);
    await _load();
  }

  void _togglePicker() {
    Haptics.light();
    setState(() => _pickingDate = !_pickingDate);
  }

  /// 휠에서 날짜를 돌리면 달력의 달과 아래 기록 목록이 바로 따라온다.
  void _pickDate(DateTime value) {
    final day = _dateOnly(value);
    setState(() {
      _selected = day;
      _setMonth(DateTime(day.year, day.month));
    });
  }

  /// 달을 바꾸면서, 새 달이 어느 쪽에서 미끄러져 들어올지 정한다.
  /// 다음 달(미래)이면 오른쪽에서, 이전 달이면 왼쪽에서 들어온다.
  void _setMonth(DateTime month) {
    if (month == _month) return;
    _slideDirection = month.isAfter(_month) ? 1 : -1;
    _month = month;
  }

  /// 휠에서 고를 수 있는 가장 이른 연도. 가장 오래된 기록의 해까지만 보여준다.
  int get _firstYear {
    final years = _byDay.keys.map((day) => day.year);
    final now = DateTime.now().year;
    return years.isEmpty ? now : years.reduce((a, b) => a < b ? a : b);
  }

  /// 오늘이 있는 달로 돌아가 오늘을 고른다. 휠이 열려 있으면 달력으로 접는다.
  void _goToToday() {
    Haptics.light();
    final today = _dateOnly(DateTime.now());
    setState(() {
      _selected = today;
      _setMonth(DateTime(today.year, today.month));
      _pickingDate = false;
    });
  }

  void _changeMonth(int delta) {
    Haptics.light();
    setState(() => _setMonth(DateTime(_month.year, _month.month + delta)));
  }

  /// 날짜 격자. 좌우로 쓸어 달을 넘기고, 달이 바뀌면 그 방향으로 미끄러진다.
  Widget _buildSwipeableGrid(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 300) return;
        // 왼쪽으로 쓸면 다음 달, 오른쪽으로 쓸면 이전 달.
        _changeMonth(velocity < 0 ? 1 : -1);
      },
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) {
            final incoming = child.key == ValueKey(_month);
            final shift = 0.25 * _slideDirection * (incoming ? 1 : -1);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: Offset(shift, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_month),
            child: _buildGrid(context),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedEntries = _byDay[_selected] ?? const <MoodEntry>[];
    final colors = WolodyColors.of(context);
    return CupertinoPageScaffold(
      backgroundColor: colors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: kNavBarBackground,
        middle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Wolody 달력', style: TextStyle(fontFamily: 'BM Jua')),
            const SizedBox(width: 6),
            WolodyIcon(
              'iconsax-calendar.svg',
              size: 18,
              color: colors.textPrimary,
            ),
          ],
        ),
      ),
      // 달력 자체는 기록 없이도 그릴 수 있으니 바로 보여주고,
      // 기록 목록 자리만 불러오는 동안 스켈레톤으로 채운다.
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildMonthHeader()),
            SliverToBoxAdapter(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _pickingDate
                      ? _buildDatePicker()
                      : Column(
                          key: const ValueKey('grid'),
                          children: [
                            _buildWeekdayLabels(context),
                            _buildSwipeableGrid(context),
                          ],
                        ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildSelectedHeader(context)),
            if (_loading || (_byDay.isEmpty && MoodStorage.syncing.value))
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
                sliver: SliverToBoxAdapter(child: MoodListSkeleton(count: 1)),
              )
            else if (selectedEntries.isEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 216,
                  child: Center(
                    child: Text(
                      '이 날은 기록이 없어요.',
                      style: TextStyle(
                        color: colors.textSecondary,
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
            const SliverToBoxAdapter(child: SizedBox(height: kBottomNavSpace)),
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
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _togglePicker,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('M월 yyyy', 'ko_KR').format(_month),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _pickingDate
                              ? WolodyColors.brandBlue
                              : WolodyColors.of(context).textPrimary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      // 휠이 열리면 iOS 캘린더처럼 셰브런이 아래를 향한다.
                      AnimatedRotation(
                        turns: _pickingDate ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          CupertinoIcons.chevron_right,
                          size: 12,
                          color: WolodyColors.brandBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _buildTodayButton(),
          // 휠로 고르는 동안에는 달 넘기기 버튼을 숨긴다.
          if (!_pickingDate) ...[
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
          ] else
            const SizedBox(height: 44),
        ],
      ),
    );
  }

  /// 이미 오늘을 보고 있으면 흐리게 두고 눌리지 않게 한다.
  Widget _buildTodayButton() {
    final surface = WolodyColors.of(context).surface;
    final today = _dateOnly(DateTime.now());
    final atToday =
        !_pickingDate &&
        _selected == today &&
        _month == DateTime(today.year, today.month);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Pressable(
        enabled: !atToday,
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 30),
          color: surface,
          disabledColor: surface,
          borderRadius: BorderRadius.circular(15),
          onPressed: atToday ? null : _goToToday,
          child: Text(
            '오늘',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: atToday
                  ? WolodyColors.of(context).textSecondary
                  : WolodyColors.brandBlue,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    final today = _dateOnly(DateTime.now());
    return SizedBox(
      key: const ValueKey('picker'),
      height: 260,
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        dateOrder: DatePickerDateOrder.ymd,
        initialDateTime: _selected.isAfter(today) ? today : _selected,
        // ‹ 로 더 이전 달을 골라둔 경우에도 휠이 그 날짜를 보여줄 수 있어야 한다.
        minimumYear: _selected.year < _firstYear ? _selected.year : _firstYear,
        maximumDate: DateTime(today.year, today.month, today.day, 23, 59),
        onDateTimeChanged: _pickDate,
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
                return const Expanded(
                  child: SizedBox(height: _cellHeight + 10),
                );
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

  /// 날짜 숫자 아래에 울디 얼굴이 들어갈 자리까지 포함한 칸 높이.
  static const _cellHeight = 56.0;

  /// 그날 가장 나중에 쓴 기록의 첫 감정. 기록이 없으면 null.
  Mood? _moodOf(DateTime day) {
    final entries = _byDay[day];
    if (entries == null || entries.isEmpty) return null;
    final latest = entries.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
    if (latest.emojis.isEmpty) return null;
    return Mood.fromEmoji(latest.emojis.first);
  }

  Widget _buildDayCell(BuildContext context, DateTime day) {
    final isSelected = day == _selected;
    final isToday = day == _dateOnly(DateTime.now());
    final mood = _moodOf(day);
    return Pressable(
      scale: 0.9,
      child: GestureDetector(
        onTap: () {
          Haptics.selection();
          setState(() => _selected = day);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: _cellHeight,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? WolodyColors.of(context).daySelected : null,
            border: isSelected
                ? Border.all(color: WolodyColors.brandBlue, width: 1)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: isSelected
                      ? WolodyColors.brandBlue
                      : WolodyColors.of(context).textPrimary,
                ),
              ),
              // 기록한 날은 그날 고른 감정의 울디 얼굴을 숫자 아래에 미리 보여준다.
              if (mood != null) ...[
                const SizedBox(height: 2),
                WooldyMoodPortrait(faceIndex: mood.faceIndex, size: 24),
              ],
            ],
          ),
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
