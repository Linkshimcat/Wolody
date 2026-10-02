import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'dart:ui' show ImageFilter;

import '../services/haptics.dart';
import '../models/mood_entry.dart';
import '../models/reminder_settings.dart';
import '../services/mood_editor.dart';
import '../services/mood_storage.dart';
import '../theme.dart';
import '../widgets/mood_card.dart';
import '../widgets/skeleton.dart';
import '../widgets/primary_action_button.dart';
import 'reminder_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = MoodStorage();
  List<MoodEntry> _entries = [];
  bool _loading = true;
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    MoodStorage.cache.addListener(_onCacheChanged);
    MoodStorage.syncing.addListener(_onSyncingChanged);
    ReminderSettings.current.addListener(_onReminderChanged);
    // 앱 시작 때 읽어 두지만, 미리보기처럼 초기화를 건너뛴 경우를 대비한다.
    if (ReminderSettings.current.value == null) ReminderSettings.load();
    _load();
  }

  @override
  void dispose() {
    MoodStorage.cache.removeListener(_onCacheChanged);
    MoodStorage.syncing.removeListener(_onSyncingChanged);
    ReminderSettings.current.removeListener(_onReminderChanged);
    super.dispose();
  }

  void _onReminderChanged() {
    if (mounted) setState(() {});
  }

  void _onCacheChanged() {
    if (!mounted) return;
    setState(() => _entries = MoodStorage.cache.value);
  }

  void _onSyncingChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _load() async {
    final entries = await _storage.load();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    // 당겨서 새로고침이 걸리는 순간을 손끝으로도 알려준다.
    Haptics.medium();
    await Future.wait([
      _storage.refresh(),
      Future<void>.delayed(const Duration(milliseconds: 1200)),
    ]);
  }

  static const _indicatorRadius = 15.0;

  Widget _buildRefreshIndicator(
    BuildContext context,
    RefreshIndicatorMode refreshState,
    double pulledExtent,
    double refreshTriggerPullDistance,
    double refreshIndicatorExtent,
  ) {
    final percentageComplete = (pulledExtent / refreshTriggerPullDistance)
        .clamp(0.0, 1.0)
        .toDouble();
    final primary = CupertinoTheme.of(context).primaryColor;
    final blue = CupertinoColors.systemBlue.resolveFrom(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primary.withValues(alpha: 0.16),
            blue.withValues(alpha: 0.09),
            primary.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 18,
              left: 0,
              right: 0,
              child: _indicatorForState(refreshState, percentageComplete),
            ),
            if (refreshState == RefreshIndicatorMode.refresh)
              Positioned(
                top: 56,
                left: 0,
                right: 0,
                child: Text(
                  '오늘의 기분 리프레시 중..',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: WolodyColors.of(context).textPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _indicatorForState(
    RefreshIndicatorMode refreshState,
    double percentageComplete,
  ) {
    switch (refreshState) {
      case RefreshIndicatorMode.drag:
        return Opacity(
          opacity: const Interval(
            0.0,
            0.35,
            curve: Curves.easeInOut,
          ).transform(percentageComplete),
          child: CupertinoActivityIndicator.partiallyRevealed(
            radius: _indicatorRadius,
            progress: percentageComplete,
          ),
        );
      case RefreshIndicatorMode.armed:
      case RefreshIndicatorMode.refresh:
        return CupertinoActivityIndicator(radius: _indicatorRadius);
      case RefreshIndicatorMode.done:
        return CupertinoActivityIndicator(
          radius: _indicatorRadius * percentageComplete,
        );
      case RefreshIndicatorMode.inactive:
        return const SizedBox.shrink();
    }
  }

  Future<void> _addMood() async {
    Haptics.light();
    if (await createMoodEntry(context)) await _load();
  }

  Future<void> _editMood(MoodEntry entry) async {
    Haptics.light();
    if (await editMoodEntry(context, entry)) await _load();
  }

  void _openReminderSettings() {
    Haptics.light();
    // 알림을 켜고 돌아오면 ReminderSettings.current가 바뀌면서 배너가 사라진다.
    Navigator.of(
      context,
    ).push(CupertinoPageRoute<void>(builder: (_) => const ReminderScreen()));
  }

  Future<void> _deleteMood(MoodEntry entry) async {
    Haptics.medium();
    setState(() => _entries.removeWhere((e) => e.id == entry.id));
    // 바로 지우지 않고 휴지통(설정 → 삭제된 기록)으로 옮긴다.
    await deleteMoodEntry(entry);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final now = DateTime.now();
    final recordedToday = _entries.any(
      (entry) =>
          entry.date.year == now.year &&
          entry.date.month == now.month &&
          entry.date.day == now.day,
    );
    // 오늘 기록했으면 완료 배너를, 아직이면 알림을 켜지 않은 사람에게만 알림 배너를 띄운다.
    final reminderOff = ReminderSettings.current.value?.enabled == false;
    final showBanner = !_bannerDismissed && (recordedToday || reminderOff);
    final contentTop = showBanner ? 30.0 : 18.0;
    return CupertinoPageScaffold(
      backgroundColor: WolodyColors.of(context).background,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _HomeHeaderDelegate(
              topInset: topInset,
              colors: WolodyColors.of(context),
            ),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: _refresh,
            refreshIndicatorExtent: 120 + topInset,
            refreshTriggerPullDistance: 140 + topInset,
            builder: _buildRefreshIndicator,
          ),
          if (showBanner)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  recordedToday ? 18 : 35,
                  24,
                  0,
                ),
                child: _HomeBanner(
                  completed: recordedToday,
                  onTap: recordedToday ? null : _openReminderSettings,
                  onClose: () => setState(() => _bannerDismissed = true),
                ),
              ),
            ),
          // 동기화는 알림 없이 뒤에서 조용히 돈다. 다만 새 기기에서 처음 로그인해
          // 아직 받아온 기록이 없을 때는 빈 화면 대신 카드 모양 스켈레톤을 보여준다.
          if (_loading || (_entries.isEmpty && MoodStorage.syncing.value))
            SliverPadding(
              padding: EdgeInsets.fromLTRB(24, contentTop, 24, kBottomNavSpace),
              sliver: const SliverToBoxAdapter(child: MoodListSkeleton()),
            )
          else if (_entries.isEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(24, contentTop, 24, kBottomNavSpace),
              sliver: SliverToBoxAdapter(child: _EmptyState(onAdd: _addMood)),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(24, contentTop, 24, kBottomNavSpace),
              sliver: SliverList.builder(
                itemCount: _entries.length,
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return _MoodCardEntrance(
                    key: ValueKey('home-card-${entry.id}'),
                    delay: Duration(milliseconds: index.clamp(0, 4) * 70),
                    child: MoodCard(
                      entry: entry,
                      onDelete: () => _deleteMood(entry),
                      onTap: () => _editMood(entry),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MoodCardEntrance extends StatefulWidget {
  const _MoodCardEntrance({
    super.key,
    required this.delay,
    required this.child,
  });

  final Duration delay;
  final Widget child;

  @override
  State<_MoodCardEntrance> createState() => _MoodCardEntranceState();
}

class _MoodCardEntranceState extends State<_MoodCardEntrance> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, .035),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: _visible ? 1 : .98,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double topInset;

  /// 헤더는 shouldRebuild가 참일 때만 다시 그려져서, 화면 모드가 바뀐 걸
  /// 알 수 있도록 팔레트를 밖에서 받아 비교한다.
  final WolodyPalette colors;

  const _HomeHeaderDelegate({required this.topInset, required this.colors});

  @override
  double get minExtent => topInset + 48;

  @override
  double get maxExtent => topInset + 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 65, sigmaY: 65),
        child: Container(
          color: colors.headerScrim,
          padding: EdgeInsets.fromLTRB(24, topInset + 20, 24, 0),
          alignment: Alignment.topLeft,
          child: Text(
            'Wolody',
            style: TextStyle(
              fontFamily: 'BM Jua',
              fontSize: 23,
              fontWeight: FontWeight.w700,
              // 다크는 흰 글씨, 라이트는 흰 배경에서 또렷한 브랜드 블루.
              color: colors.isLight ? colors.logo : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeHeaderDelegate oldDelegate) =>
      topInset != oldDelegate.topInset || colors != oldDelegate.colors;
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colors = WolodyColors.of(context);
    return Container(
      height: 447,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: colors.cardShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            top: 24,
            left: 18,
            right: 18,
            child: Text(
              '아직 오늘의 마음을 기록하지\n않았어요',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.35,
                color: colors.textPrimary,
              ),
            ),
          ),
          Positioned.fill(
            top: 60,
            bottom: 66,
            child: Center(
              child: SizedBox(
                width: 238,
                height: 260,
                child: Image.asset(
                  'assets/AssetsDesign/wooldy_writing.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: PrimaryActionButton(
              label: '지금 감정 기록하러 가기',
              onPressed: onAdd,
              height: 55,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBanner extends StatelessWidget {
  final bool completed;

  /// 배너를 눌렀을 때. 알림 배너는 알림 설정 화면으로 보낸다.
  final VoidCallback? onTap;
  final VoidCallback onClose;

  const _HomeBanner({
    required this.completed,
    this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colors = WolodyColors.of(context);
    final banner = Container(
      height: completed ? 250 : 100,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: colors.cardShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 18,
            top: completed ? 22 : 19,
            right: completed ? 12 : 86,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (completed)
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: '오늘도 '),
                        TextSpan(
                          text: '기록 완료!',
                          style: TextStyle(color: WolodyColors.brandBlue),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (!completed)
                  const Text(
                    '기록 알림을 설정해볼까요?',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                const SizedBox(height: 3),
                Text(
                  completed ? '연속 1일차에 도전 중입니다' : '울디가 매일 마음 기록을 챙겨줄게요.',
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          Positioned(
            right: completed ? 12 : 26,
            bottom: completed ? -2 : -5,
            child: Image.asset(
              completed
                  ? 'assets/AssetsDesign/wooldy_done.png'
                  : 'assets/AssetsDesign/wooldy_bell.png',
              width: completed ? 176 : 124,
              height: completed ? 190 : 100,
              fit: BoxFit.contain,
            ),
          ),
          // 배너 전체가 눌리므로, 닫기를 살짝 빗나가도 설정으로 넘어가지 않게
          // 아이콘 둘레까지 닫기 영역으로 잡는다.
          Positioned(
            top: 1,
            right: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Haptics.light();
                onClose();
              },
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 20,
                  color: colors.closeIcon,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return banner;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: banner,
    );
  }
}
