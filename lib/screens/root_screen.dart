import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../services/auth_service.dart';
import '../services/haptics.dart';
import '../models/mood.dart';
import '../services/mood_editor.dart';
import '../services/live_activity_service.dart';
import '../services/mood_storage.dart';
import '../services/widget_service.dart';
import '../services/platform_info.dart';
import '../theme.dart';
import '../widgets/celebration_burst.dart';
import '../widgets/glass_surface.dart';
import '../widgets/native_tab_bar.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/wolody_icon.dart';
import '../widgets/wolody_toast.dart';
import 'calendar_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> with WidgetsBindingObserver {
  static const _barHeight = 64.0;

  /// 네이티브 UITabBar의 자연 높이(intrinsicContentSize).
  static const _nativeBarHeight = 83.0;

  int _index = 0;
  double _barDragPosition = 0;
  // 값이 바뀌면 화면이 새로 만들어지면서 저장소를 다시 읽는다.
  int _refreshToken = 0;
  // 마이 탭은 자체 Navigator를 둔다. 설정·리캡 같은 하위 화면을 탭 바를 남긴 채
  // push해서 iOS 가장자리 스와이프로 뒤로 갈 수 있게 한다.
  final _myTabNavigator = GlobalKey<NavigatorState>();
  bool _showToast = false;
  String _toastMessage = '';
  IconData _toastIcon = CupertinoIcons.checkmark_circle_fill;
  bool _barDragging = false;
  bool _barPressed = false;
  // iOS 26+에서는 시스템 UITabBar를 그대로 쓴다. null이면 아직 판별 전.
  bool? _useNativeBar;
  Timer? _toastTimer;
  // 기록할 때마다 하나씩 늘려 축하 파티클을 터뜨린다.
  int _celebration = 0;
  List<Color> _celebrationColors = const [];

  @override
  void initState() {
    super.initState();
    PlatformInfo.supportsNativeLiquidGlass.then((native) {
      if (mounted) setState(() => _useNativeBar = native);
    });
    MoodEvents.recorded.addListener(_onRecorded);
    MoodEvents.cheer.addListener(_onCheer);
    // 다른 기기에서 기록을 바꾸면 바로 받아 화면·위젯에 반영한다.
    WidgetsBinding.instance.addObserver(this);
    MoodStorage.watchCloud(onRemoteChange: _onRemoteChange);
    // 첫 가입 설정을 마치고 들어왔으면 환영 인사를 한 번 띄운다.
    final notice = AuthService.pendingNotice;
    if (notice != null) {
      AuthService.pendingNotice = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toast(notice, CupertinoIcons.heart_fill);
      });
    }
  }

  void _toast(String message, IconData icon) {
    setState(() {
      _toastMessage = message;
      _toastIcon = icon;
      _showToast = true;
    });
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _showToast = false);
    });
  }

  @override
  void dispose() {
    MoodEvents.recorded.removeListener(_onRecorded);
    MoodEvents.cheer.removeListener(_onCheer);
    WidgetsBinding.instance.removeObserver(this);
    MoodStorage.stopWatching();
    _toastTimer?.cancel();
    super.dispose();
  }

  /// 앱을 다시 열면 닫혀 있는 동안 다른 기기에서 바뀐 기록을 받아온다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    MoodStorage.syncToCloud().then((_) => _onRemoteChange());
  }

  /// 클라우드에서 기록이 바뀌었다. 목록은 MoodStorage.cache를 듣는 화면들이
  /// 알아서 다시 그리고, 여기서는 홈 화면 위젯과 실시간 표시만 맞춘다.
  void _onRemoteChange() {
    WidgetService.refresh();
    LiveActivityService.refresh();
  }

  /// 완료 배너를 누르면 오늘 고른 감정 색으로 파티클만 다시 터뜨린다.
  void _onCheer() {
    if (!mounted) return;
    final today = DateTime.now();
    final latest = MoodStorage.cache.value.where(
      (e) =>
          e.date.year == today.year &&
          e.date.month == today.month &&
          e.date.day == today.day,
    );
    final colors = latest.isEmpty
        ? const <Color>[]
        : latest.first.emojis.map((e) => Mood.fromEmoji(e).color).toList();
    setState(() {
      _celebration++;
      _celebrationColors = [...colors, WolodyColors.brandBlue];
    });
  }

  /// 어디서 기록했든(탭 바 [+], 홈의 기록하기 버튼) 토스트와 축하를 보여준다.
  void _onRecorded() {
    final entry = MoodEvents.recorded.value;
    if (!mounted || entry == null) return;
    final colors = entry.emojis.map((e) => Mood.fromEmoji(e).color).toList();
    Haptics.success();
    setState(() {
      _celebration++;
      _celebrationColors = [...colors, WolodyColors.brandBlue];
    });
    _toast('오늘의 기록을 완료 했어요!', CupertinoIcons.checkmark_circle_fill);
  }

  Widget get _currentScreen {
    switch (_index) {
      case 0:
        return HomeScreen(key: ValueKey('home-$_refreshToken'));
      case 1:
        return CalendarScreen(key: ValueKey('calendar-$_refreshToken'));
      default:
        return NavigatorPopHandler(
          onPopWithResult: (_) => _myTabNavigator.currentState?.maybePop(),
          child: Navigator(
            key: _myTabNavigator,
            onGenerateRoute: (settings) => CupertinoPageRoute<void>(
              settings: settings,
              builder: (_) => const ProfileScreen(),
            ),
          ),
        );
    }
  }

  void _selectTab(int index) {
    if (index == _index) {
      // iOS 관례: 보고 있는 탭을 다시 누르면 그 탭의 첫 화면으로 돌아간다.
      final navigator = _myTabNavigator.currentState;
      if (index == 2 && navigator != null && navigator.canPop()) {
        Haptics.selection();
        navigator.popUntil((route) => route.isFirst);
      }
      return;
    }
    Haptics.selection();
    setState(() {
      _index = index;
      _barDragPosition = index.toDouble();
    });
  }

  void _onBarDragStart(DragStartDetails details) {
    setState(() {
      _barDragging = true;
      _barDragPosition = _index.toDouble();
    });
  }

  void _onBarDragUpdate(DragUpdateDetails details, double itemWidth) {
    final position = (details.localPosition.dx / itemWidth - 0.5).clamp(
      0.0,
      2.0,
    );
    final index = position.round();
    if (index != _index) Haptics.selection();
    setState(() {
      _barDragPosition = position;
      _index = index;
    });
  }

  void _onBarDragEnd(DragEndDetails details) {
    setState(() {
      _barDragging = false;
      _barDragPosition = _index.toDouble();
    });
  }

  void _onBarDragCancel() {
    setState(() {
      _barDragging = false;
      _barDragPosition = _index.toDouble();
    });
  }

  Future<void> _addMood() async {
    Haptics.light();
    if (!await createMoodEntry(context)) return;
    // 기록하면 목록으로 돌아가 방금 쓴 카드를 보여준다.
    // 토스트와 축하는 MoodEvents.recorded를 들은 _onRecorded가 맡는다.
    setState(() {
      _index = 0;
      _barDragPosition = 0;
      _refreshToken++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 바텀 시트 같은 모달이 떠 있으면 유리 바가 위로 새어 보인다.
    // (iOS 플랫폼 뷰는 Flutter의 반투명 배리어에 가려지지 않는다)
    final coveredByModal = !(ModalRoute.of(context)?.isCurrent ?? true);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Stack(
      children: [
        Positioned.fill(child: _currentScreen),
        // 토스트 아래에서 감정 색 하트·별이 터져 내린다.
        Positioned.fill(
          top: MediaQuery.paddingOf(context).top + 60,
          child: IgnorePointer(
            child: CelebrationBurst(
              trigger: _celebration,
              colors: _celebrationColors,
            ),
          ),
        ),
        // 토스트는 항상 자리에 두고, 보일 때 위에서 스르륵 내려오고
        // 사라질 때 다시 위로 빠지며 흐려진다.
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          left: 58,
          right: 58,
          child: IgnorePointer(
            child: WolodyToast(
              visible: _showToast && !coveredByModal,
              icon: _toastIcon,
              message: _toastMessage,
            ),
          ),
        ),
        // 판별이 끝나기 전에 Flutter 바가 잠깐 보였다 바뀌지 않도록 기다린다.
        if (!coveredByModal && !keyboardUp && _useNativeBar == true)
          Positioned(
            left: 0,
            right: 0,
            // UITabBar는 자체 하단 여백을 품고 있어 홈 인디케이터 쪽으로 내려 맞춘다.
            bottom: bottomInset - 30,
            height: _nativeBarHeight,
            child: NativeTabBar(
              selectedIndex: _index,
              tintColor: WolodyColors.brandBlue,
              onSelect: _selectTab,
              onAdd: _addMood,
            ),
          ),
        if (!coveredByModal && !keyboardUp && _useNativeBar == false)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: _buildBar(context),
          ),
      ],
    );
  }

  Widget _buildBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: _barHeight,
        child: GlassTabBarSurface(
          selectedIndex: _index,
          position: _barDragPosition,
          dragging: _barDragging,
          pressed: _barPressed,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(
                color: Platform.isIOS
                    ? const Color(0x00000000)
                    : WolodyColors.of(context).outline,
              ),
              borderRadius: BorderRadius.circular(34),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / 4;
                // 탭 영역을 누르고 있는 동안 선택 캡슐을 유리 렌즈로 띄운다.
                // [+] 버튼은 선택 캡슐과 상관없으니 제외한다.
                return Listener(
                  onPointerDown: (event) {
                    if (event.localPosition.dx < itemWidth * 3) {
                      setState(() => _barPressed = true);
                    }
                  },
                  onPointerUp: (_) => setState(() => _barPressed = false),
                  onPointerCancel: (_) => setState(() => _barPressed = false),
                  child: GestureDetector(
                    onHorizontalDragStart: _onBarDragStart,
                    onHorizontalDragUpdate: (details) =>
                        _onBarDragUpdate(details, itemWidth),
                    onHorizontalDragEnd: _onBarDragEnd,
                    onHorizontalDragCancel: _onBarDragCancel,
                    child: SizedBox(
                      height: double.infinity,
                      child: Stack(
                        children: [
                          if (!Platform.isIOS)
                            AnimatedPositioned(
                              duration: _barDragging
                                  ? Duration.zero
                                  : const Duration(milliseconds: 420),
                              curve: Curves.easeOutCubic,
                              top: 0,
                              bottom: 0,
                              left: _index * itemWidth,
                              width: itemWidth,
                              child: IgnorePointer(
                                child: GlassSurface(
                                  capsule: true,
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              _buildTab(
                                context,
                                0,
                                CupertinoIcons.house_fill,
                                '홈',
                              ),
                              _buildTab(
                                context,
                                1,
                                CupertinoIcons.calendar,
                                '기록',
                              ),
                              _buildTab(
                                context,
                                2,
                                CupertinoIcons.person_crop_circle,
                                '마이',
                              ),
                              Expanded(child: _buildAddButton(context)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(
    BuildContext context,
    int index,
    IconData icon,
    String label,
  ) {
    final selected = _index == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectTab(index),
        child: SizedBox(
          height: double.infinity,
          // 렌즈가 떠 있는 동안 그 아래 아이콘도 돋보기처럼 살짝 커진다.
          child: AnimatedScale(
            scale: selected && _barPressed ? 1.15 : 1,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutBack,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (index == 1)
                  WolodyIcon(
                    'iconsax-calendar.svg',
                    size: 22,
                    color: selected
                        ? WolodyColors.brandBlue
                        : WolodyColors.of(context).textPrimary,
                  )
                else if (index == 2)
                  const ProfileAvatar(size: 23)
                else
                  Icon(
                    icon,
                    size: 22,
                    color: selected
                        ? WolodyColors.brandBlue
                        : WolodyColors.of(context).textPrimary,
                  ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? WolodyColors.brandBlue
                        : WolodyColors.of(context).textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _addMood,
      child: const Icon(
        CupertinoIcons.add,
        size: 28,
        color: WolodyColors.brandBlue,
      ),
    );
  }
}
