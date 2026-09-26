import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show ImageFilter;

import '../models/mood_entry.dart';
import '../services/live_activity_service.dart';
import '../services/mood_editor.dart';
import '../services/mood_storage.dart';
import '../services/photo_storage.dart';
import '../services/widget_service.dart';
import '../theme.dart';
import '../widgets/mood_card.dart';
import '../widgets/primary_action_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = MoodStorage();
  List<MoodEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    MoodStorage.cache.addListener(_onCacheChanged);
    MoodStorage.syncing.addListener(_onSyncingChanged);
    _load();
  }

  @override
  void dispose() {
    MoodStorage.cache.removeListener(_onCacheChanged);
    MoodStorage.syncing.removeListener(_onSyncingChanged);
    super.dispose();
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
    HapticFeedback.mediumImpact();
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
                child: const Text(
                  '오늘의 기분 리프레시 중..',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel,
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
    HapticFeedback.lightImpact();
    if (await createMoodEntry(context)) await _load();
  }

  Future<void> _editMood(MoodEntry entry) async {
    HapticFeedback.lightImpact();
    if (await editMoodEntry(context, entry)) await _load();
  }

  Future<void> _deleteMood(MoodEntry entry) async {
    HapticFeedback.mediumImpact();
    setState(() => _entries.removeWhere((e) => e.id == entry.id));
    await _storage.save(_entries);
    if (entry.imageFileName != null) {
      await PhotoStorage.delete(entry.imageFileName!);
    }
    await LiveActivityService.refresh();
    await WidgetService.refresh();
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
    return CupertinoPageScaffold(
      backgroundColor: kAppBackground,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _HomeHeaderDelegate(topInset: topInset),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: _refresh,
            refreshIndicatorExtent: 120 + topInset,
            refreshTriggerPullDistance: 140 + topInset,
            builder: _buildRefreshIndicator,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, recordedToday ? 18 : 35, 24, 0),
              child: _HomeBanner(completed: recordedToday),
            ),
          ),
          if (MoodStorage.syncing.value)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: _SyncBadge(),
              ),
            ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (_entries.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, kBottomNavSpace),
              sliver: SliverToBoxAdapter(child: _EmptyState(onAdd: _addMood)),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, kBottomNavSpace),
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

  const _HomeHeaderDelegate({required this.topInset});

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
          color: const Color(0x800D1118),
          padding: EdgeInsets.fromLTRB(24, topInset + 20, 24, 0),
          alignment: Alignment.topLeft,
          child: const Text(
            'Wolody',
            style: TextStyle(
              fontFamily: 'BM Jua',
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.white,
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeHeaderDelegate oldDelegate) =>
      topInset != oldDelegate.topInset;
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 447,
      decoration: BoxDecoration(
        color: WolodyColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: 24,
            left: 18,
            right: 18,
            child: Text(
              '아직 오늘의 마음을 기록하지\n않았어요',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                height: 1.35,
                color: CupertinoColors.white,
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
                  'assets/AssetsDesign/메모하는울디.png',
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

class _HomeBanner extends StatefulWidget {
  final bool completed;

  const _HomeBanner({required this.completed});

  @override
  State<_HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends State<_HomeBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final completed = widget.completed;
    if (_dismissed) return const SizedBox.shrink();
    return Container(
      height: completed ? 250 : 100,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: WolodyColors.surface,
        borderRadius: BorderRadius.circular(24),
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: WolodyColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: completed ? 12 : 26,
            bottom: completed ? -2 : -5,
            child: Image.asset(
              completed
                  ? 'assets/AssetsDesign/기록완료울디.png'
                  : 'assets/AssetsDesign/푸시알림울디.png',
              width: completed ? 176 : 124,
              height: completed ? 190 : 100,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            top: 11,
            right: 10,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _dismissed = true);
              },
              child: const Icon(
                CupertinoIcons.xmark_circle_fill,
                size: 20,
                color: Color(0xFF747B86),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 클라우드 동기화가 도는 동안 상단에 표시되는 작은 배지.
class _SyncBadge extends StatelessWidget {
  const _SyncBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(radius: 8),
            const SizedBox(width: 8),
            Text(
              '동기화 중..',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
