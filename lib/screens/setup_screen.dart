import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/reminder_settings.dart';
import '../services/auth_service.dart';
import '../services/haptics.dart';
import '../services/notification_service.dart';
import '../services/onboarding.dart';
import '../services/profile_storage.dart';
import '../theme.dart';
import '../widgets/pressable.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/profile_avatar.dart';

/// 처음 가입한 뒤 한 번만 보는 설정 2단계: ① 부를 이름 ② 기록 알림 시간.
///
/// 각 단계는 "나중에"로 건너뛸 수 있다. 끝나면 [Onboarding.finishSetup]으로
/// AuthGate가 홈을 보여주고, 홈에 환영 토스트가 한 번 뜬다.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const _presets = [(9, 0, '아침'), (12, 30, '점심'), (21, 0, '저녁')];

  final _pages = PageController();
  final _nicknameController = TextEditingController();
  int _step = 0;

  /// 사용자가 이름을 직접 고쳤는지. 고치기 전에는 소셜 이름이 늦게 도착해도 채워 준다.
  bool _nicknameEdited = false;
  int _hour = 21;
  int _minute = 0;
  bool _customTime = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nicknameController.text = _socialNickname;
    // 가입 직후에는 소셜 이름·사진을 뒤에서 받아오는 중일 수 있다.
    ProfileStorage.profile.addListener(_onProfileChanged);
  }

  @override
  void dispose() {
    ProfileStorage.profile.removeListener(_onProfileChanged);
    _pages.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  String get _socialNickname {
    final nickname = ProfileStorage.profile.value.nickname;
    return nickname == UserProfile.defaultNickname ? '' : nickname;
  }

  void _onProfileChanged() {
    if (!mounted || _nicknameEdited) return;
    setState(() => _nicknameController.text = _socialNickname);
  }

  String get _nickname => _nicknameController.text.trim();

  Future<void> _goTo(int step) async {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    await _pages.animateToPage(
      step,
      duration: MediaQuery.disableAnimationsOf(context)
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _saveNickname() async {
    if (_nickname.isEmpty || _busy) return;
    Haptics.light();
    setState(() => _busy = true);
    if (_nickname != ProfileStorage.profile.value.nickname) {
      await ProfileStorage.save(nickname: _nickname);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _goTo(1);
  }

  Future<void> _enableReminder() async {
    if (_busy) return;
    Haptics.light();
    setState(() => _busy = true);
    final granted = await NotificationService.instance.requestPermission();
    if (granted) {
      final settings = ReminderSettings.defaults.copyWith(
        enabled: true,
        hour: _hour,
        minute: _minute,
      );
      await settings.save();
      await NotificationService.instance.apply(settings);
    }
    await _finish(
      granted
          ? '반가워요, ${ProfileStorage.profile.value.nickname}!'
          : '알림은 나중에 설정에서 켤 수 있어요',
    );
  }

  /// 오른쪽 위 "나중에". 지금 단계부터 끝까지 건너뛴다.
  Future<void> _skip() async {
    Haptics.light();
    await _finish('반가워요, ${ProfileStorage.profile.value.nickname}!');
  }

  Future<void> _finish(String notice) async {
    Haptics.success();
    AuthService.pendingNotice = notice;
    await Onboarding.finishSetup();
  }

  Future<void> _pickCustomTime() async {
    Haptics.light();
    var picked = DateTime(2000, 1, 1, _hour, _minute);
    final colors = WolodyColors.of(context);
    final done = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (sheetContext) => Container(
        height: 320 + MediaQuery.paddingOf(sheetContext).bottom,
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(sheetContext).bottom,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '알림 시간',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
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
    if (done != true || !mounted) return;
    Haptics.selection();
    setState(() {
      _hour = picked.hour;
      _minute = picked.minute;
      _customTime = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = WolodyColors.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return CupertinoPageScaffold(
      backgroundColor: colors.background,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(colors),
              Expanded(
                child: PageView(
                  controller: _pages,
                  // 단계는 버튼으로만 넘긴다. 이름을 비운 채 넘어가지 않게 한다.
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildNameStep(colors),
                    _buildReminderStep(colors),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 10, 24, bottom + 15),
                child: _busy
                    ? const SizedBox(
                        height: 58,
                        child: Center(child: CupertinoActivityIndicator()),
                      )
                    : PrimaryActionButton(
                        label: _step == 0 ? '다음' : '알림 받기',
                        onPressed: _step == 0
                            ? (_nickname.isEmpty ? null : _saveNickname)
                            : _enableReminder,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 2칸짜리 진행 막대와 "나중에".
  Widget _buildTopBar(WolodyPalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 8, 0),
      child: Row(
        children: [
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 5,
                decoration: BoxDecoration(
                  color: i <= _step ? WolodyColors.brandBlue : colors.outline,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
          const SizedBox(width: 60),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: _busy ? null : _skip,
            child: Text(
              '나중에',
              style: TextStyle(fontSize: 15, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(String title, String body, WolodyPalette colors) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: kSectionTitleStyle.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: colors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildNameStep(WolodyPalette colors) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: [
        const Center(child: ProfileAvatar(size: 88)),
        const SizedBox(height: 28),
        _title('뭐라고 불러줄까요?', '울디가 이 이름으로 불러드릴게요.', colors),
        const SizedBox(height: 32),
        CupertinoTextField(
          controller: _nicknameController,
          placeholder: '이름을 입력해 주세요',
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          clearButtonMode: OverlayVisibilityMode.editing,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            LengthLimitingTextInputFormatter(UserProfile.maxNicknameLength),
          ],
          onChanged: (_) => setState(() => _nicknameEdited = true),
          onSubmitted: (_) => _saveNickname(),
          suffix: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              '${_nicknameController.text.characters.length}'
              '/${UserProfile.maxNicknameLength}',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
          placeholderStyle: TextStyle(
            fontSize: 14,
            color: colors.textSecondary,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: colors.cardShadow,
          ),
        ),
      ],
    );
  }

  Widget _buildReminderStep(WolodyPalette colors) {
    String format(int hour, int minute) => DateFormat(
      'a h:mm',
      'ko_KR',
    ).format(DateTime(2000, 1, 1, hour, minute));
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: [
        Center(
          child: Image.asset(
            'assets/AssetsDesign/wooldy_bell.png',
            height: 120,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 28),
        _title('언제 마음을 물어볼까요?', '정한 시간에 울디가 살짝 알려드려요.', colors),
        const SizedBox(height: 32),
        Row(
          children: [
            for (final (hour, minute, label) in _presets) ...[
              _timeChip(
                colors,
                label: label,
                time: format(hour, minute),
                selected: !_customTime && _hour == hour && _minute == minute,
                onTap: () {
                  Haptics.selection();
                  setState(() {
                    _hour = hour;
                    _minute = minute;
                    _customTime = false;
                  });
                },
              ),
              const SizedBox(width: 8),
            ],
            _timeChip(
              colors,
              label: '직접',
              time: _customTime ? format(_hour, _minute) : '고르기',
              selected: _customTime,
              onTap: _pickCustomTime,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '알림 시간과 요일은 설정에서 언제든 바꿀 수 있어요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
      ],
    );
  }

  Widget _timeChip(
    WolodyPalette colors, {
    required String label,
    required String time,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final foreground = selected ? CupertinoColors.white : colors.textPrimary;
    return Expanded(
      child: Pressable(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 64,
            decoration: BoxDecoration(
              color: selected ? WolodyColors.brandBlue : colors.chipIdle,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    color: foreground.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
