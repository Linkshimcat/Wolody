import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reminder_settings.dart';
import '../services/live_activity_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/glass_switch.dart';
import '../widgets/wolody_icon.dart';

class ReminderScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ReminderScreen({super.key, this.onBack});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  ReminderSettings? _settings;
  bool _liveActivitySupported = false;
  bool _liveActivityOn = false;

  @override
  void initState() {
    super.initState();
    ReminderSettings.load().then((settings) {
      if (mounted) setState(() => _settings = settings);
    });
    _loadLiveActivity();
  }

  Future<void> _loadLiveActivity() async {
    final supported = await LiveActivityService.isSupported();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _liveActivitySupported = supported;
      _liveActivityOn = prefs.getBool('live_activity_enabled') ?? false;
    });
  }

  Future<void> _persist(ReminderSettings settings) async {
    await settings.save();
    await NotificationService.instance.apply(settings);
  }

  Future<void> _update(ReminderSettings next) async {
    setState(() => _settings = next);
    await _persist(next);
  }

  Future<void> _toggleEnabled(bool value) async {
    HapticFeedback.selectionClick();
    if (value) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted) {
        if (!mounted) return;
        await showCupertinoDialog<void>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('알림 권한이 필요해요'),
            content: const Text('설정 앱에서 이 앱의 알림을 허용해주세요.'),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        if (mounted) setState(() {});
        return;
      }
    }
    await _update(_settings!.copyWith(enabled: value));
  }

  Future<void> _toggleLiveActivity(bool value) async {
    HapticFeedback.selectionClick();
    setState(() => _liveActivityOn = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('live_activity_enabled', value);
    if (value) {
      await LiveActivityService.start();
    } else {
      await LiveActivityService.end();
    }
  }

  Future<void> _showNotice(String title, String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
  );

  Widget _toggleRow({
    required String icon,
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: WolodyColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          WolodyIcon(icon, size: 17, color: CupertinoColors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          GlassSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _modeButton({
    required ReminderMode mode,
    required String icon,
    required String label,
    required bool selected,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          _update(_settings!.copyWith(mode: mode));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          decoration: BoxDecoration(
            color: selected ? WolodyColors.brandBlue : const Color(0xFF34373D),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              WolodyIcon(icon, size: 17, color: CupertinoColors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
  static const _intervals = [30, 60, 120, 180];

  /// iOS는 앱 하나당 예약 알림을 64개까지만 보관한다.
  static const _maxPendingNotifications = 64;

  static String _formatTime(int hour, int minute) =>
      DateFormat('a h:mm', 'ko_KR').format(DateTime(2000, 1, 1, hour, minute));

  static String _formatInterval(int minutes) =>
      minutes < 60 ? '$minutes분' : '${minutes ~/ 60}시간';

  Future<void> _toggleWeekday(int weekday) async {
    final days = Set<int>.from(_settings!.weekdays);
    // 요일이 하나도 없으면 알림이 영영 오지 않으니 마지막 하루는 남겨둔다.
    if (days.contains(weekday) && days.length == 1) {
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.selectionClick();
    if (!days.remove(weekday)) days.add(weekday);
    await _update(_settings!.copyWith(weekdays: days));
  }

  Future<void> _pickTime({
    required String title,
    required int hour,
    required int minute,
    required void Function(int hour, int minute) onPicked,
  }) async {
    HapticFeedback.lightImpact();
    var picked = DateTime(2000, 1, 1, hour, minute);
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => Container(
        height: 320 + MediaQuery.paddingOf(sheetContext).bottom,
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(sheetContext).bottom,
        ),
        decoration: const BoxDecoration(
          color: WolodyColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(sheetContext);
                      onPicked(picked.hour, picked.minute);
                    },
                    child: const Text(
                      '완료',
                      style: TextStyle(
                        color: WolodyColors.brandBlue,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: picked,
                onDateTimeChanged: (value) => picked = value,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 루틴 카드 안의 "라벨 ··· 파란 값 >" 한 줄.
  Widget _routineRow({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: WolodyColors.brandBlue,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: WolodyColors.brandBlue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _routineDivider() =>
      Container(height: 0.5, color: WolodyColors.outline);

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? WolodyColors.brandBlue : const Color(0xFF34373D),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _chipRow(List<Widget> chips) => Row(
    children: [
      for (var i = 0; i < chips.length; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        chips[i],
      ],
    ],
  );

  /// 하루 동안 울릴 알림 횟수(여러 번 모드).
  int _dailySlots(ReminderSettings settings) {
    if (!settings.endAfterStart) return 0;
    final span =
        settings.endHour * 60 +
        settings.endMinute -
        (settings.startHour * 60 + settings.startMinute);
    return (span + settings.intervalMinutes - 1) ~/ settings.intervalMinutes;
  }

  String _weekdaySummary(Set<int> weekdays) {
    if (weekdays.length == 7) return '매일';
    if (weekdays.length == 5 &&
        !weekdays.contains(6) &&
        !weekdays.contains(7)) {
      return '평일';
    }
    if (weekdays.length == 2 && weekdays.containsAll({6, 7})) return '주말';
    final sorted = weekdays.toList()..sort();
    return sorted.map((day) => _weekdayLabels[day - 1]).join('·');
  }

  /// 루틴 카드 아래에 지금 설정이 어떻게 울리는지 한 줄로 풀어준다.
  Widget _routineSummary(ReminderSettings settings) {
    final days = _weekdaySummary(settings.weekdays);
    final String message;
    var warning = false;
    if (settings.mode == ReminderMode.once) {
      message =
          '$days ${_formatTime(settings.hour, settings.minute)}에 '
          '기록 알림을 보내드려요';
    } else if (!settings.endAfterStart) {
      message = '종료 시간은 시작 시간보다 늦어야 해요';
      warning = true;
    } else {
      final slots = _dailySlots(settings);
      final total = settings.weekdays.length == 7
          ? slots
          : slots * settings.weekdays.length;
      if (total > _maxPendingNotifications) {
        message = '알림이 너무 많아 일부만 예약돼요. 간격을 늘리거나 요일을 줄여주세요';
        warning = true;
      } else {
        message =
            '$days ${_formatTime(settings.startHour, settings.startMinute)}'
            '부터 ${_formatInterval(settings.intervalMinutes)}마다 '
            '하루 $slots번 알려드려요';
      }
    }
    return Text(
      settings.enabled ? message : '알림 받기를 켜면 $message',
      style: TextStyle(
        fontSize: 12,
        height: 1.4,
        color: warning ? const Color(0xFFE88E8E) : WolodyColors.textSecondary,
      ),
    );
  }

  Widget _buildRoutine(ReminderSettings settings) {
    final once = settings.mode == ReminderMode.once;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
          decoration: BoxDecoration(
            color: const Color(0xFF202329),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _modeButton(
                    mode: ReminderMode.once,
                    icon: 'iconsax-bell2.svg',
                    label: '하루 한 번',
                    selected: once,
                  ),
                  const SizedBox(width: 12),
                  _modeButton(
                    mode: ReminderMode.repeat,
                    icon: 'iconsax-repeat-arrow.svg',
                    label: '여러 번',
                    selected: !once,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    if (once)
                      _routineRow(
                        label: '알림 시간',
                        value: _formatTime(settings.hour, settings.minute),
                        onTap: () => _pickTime(
                          title: '알림 시간',
                          hour: settings.hour,
                          minute: settings.minute,
                          onPicked: (hour, minute) => _update(
                            settings.copyWith(hour: hour, minute: minute),
                          ),
                        ),
                      )
                    else ...[
                      _routineRow(
                        label: '시작',
                        value: _formatTime(
                          settings.startHour,
                          settings.startMinute,
                        ),
                        onTap: () => _pickTime(
                          title: '시작 시간',
                          hour: settings.startHour,
                          minute: settings.startMinute,
                          onPicked: (hour, minute) => _update(
                            settings.copyWith(
                              startHour: hour,
                              startMinute: minute,
                            ),
                          ),
                        ),
                      ),
                      _routineDivider(),
                      _routineRow(
                        label: '종료',
                        value: _formatTime(
                          settings.endHour,
                          settings.endMinute,
                        ),
                        onTap: () => _pickTime(
                          title: '종료 시간',
                          hour: settings.endHour,
                          minute: settings.endMinute,
                          onPicked: (hour, minute) => _update(
                            settings.copyWith(endHour: hour, endMinute: minute),
                          ),
                        ),
                      ),
                      _routineDivider(),
                      const SizedBox(height: 14),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '간격',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _chipRow([
                        for (final interval in _intervals)
                          _chip(
                            label: _formatInterval(interval),
                            selected: settings.intervalMinutes == interval,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _update(
                                settings.copyWith(intervalMinutes: interval),
                              );
                            },
                          ),
                      ]),
                    ],
                    if (once) _routineDivider(),
                    const SizedBox(height: 14),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '요일',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _chipRow([
                      for (var day = 1; day <= 7; day++)
                        _chip(
                          label: _weekdayLabels[day - 1],
                          selected: settings.weekdays.contains(day),
                          onTap: () => _toggleWeekday(day),
                        ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _routineSummary(settings),
        ),
      ],
    );
  }

  Widget _actionRow({
    required String icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: WolodyColors.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            WolodyIcon(icon, size: 18, color: CupertinoColors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(CupertinoIcons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return CupertinoPageScaffold(
      backgroundColor: WolodyColors.background,
      child: settings == null
          ? const Center(child: CupertinoActivityIndicator())
          : SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 120),
                children: [
                  Row(
                    children: [
                      GlassBackButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          widget.onBack?.call();
                        },
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        '설정',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  _sectionTitle('알림'),
                  const SizedBox(height: 32),
                  _toggleRow(
                    icon: 'iconsax-bell2.svg',
                    title: '알림 받기',
                    value: settings.enabled,
                    onChanged: _toggleEnabled,
                  ),
                  const SizedBox(height: 26),
                  _toggleRow(
                    icon: 'iconsax-screenmirroring.svg',
                    title: '잠금화면에 표시',
                    value: _liveActivityOn,
                    onChanged: _liveActivitySupported
                        ? _toggleLiveActivity
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('루틴'),
                  const SizedBox(height: 28),
                  _buildRoutine(settings),
                  const SizedBox(height: 24),
                  _sectionTitle('기록 관리'),
                  const SizedBox(height: 20),
                  _actionRow(
                    icon: 'iconsax-note.svg',
                    title: '삭제된 기록 보기',
                    onTap: () => _showNotice('삭제된 기록', '삭제된 기록이 없어요.'),
                  ),
                  const SizedBox(height: 34),
                  _sectionTitle('계정 관리'),
                  const SizedBox(height: 22),
                  _actionRow(
                    icon: 'iconsax-security-user.svg',
                    title: '계정 정보',
                    onTap: () => _showNotice('계정 정보', '로그인 기능은 아직 연결되지 않았어요.'),
                  ),
                ],
              ),
            ),
    );
  }
}
