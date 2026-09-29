import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/mood_entry.dart';
import '../services/auth_service.dart';
import '../services/mood_editor.dart';
import '../services/mood_storage.dart';
import '../services/profile_storage.dart';
import '../services/trash_storage.dart';
import '../theme.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/wolody_top_bar.dart';
import 'profile_edit_screen.dart';

/// 설정 → 계정 정보. 로그인 전에는 프로필과 이 기기에 저장된 데이터를 관리한다.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  void initState() {
    super.initState();
    // 목록과 휴지통 개수를 최신으로 맞춘다. 화면은 두 알림값을 구독해 다시 그린다.
    MoodStorage().load();
    TrashStorage.load();
  }

  void _openProfileEdit() {
    HapticFeedback.lightImpact();
    // 아래쪽 저장 버튼이 탭 바에 가리지 않도록 탭 밖(루트)에서 띄운다.
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(CupertinoPageRoute<void>(builder: (_) => const ProfileEditScreen()));
  }

  Future<void> _confirmSignOut() async {
    HapticFeedback.lightImpact();
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('로그아웃할까요?'),
        content: const Text(
          '기록은 계정에 그대로 남아 다시 로그인하면 돌아와요.\n'
          '이 기기에 있던 사본과 삭제된 기록은 비워져요.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    HapticFeedback.mediumImpact();
    await AuthService.signOut();
    // 홈 배너에서 루트로 띄운 설정 화면이라면 로그인 화면 위에 남지 않게 걷어낸다.
    if (mounted) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((route) => route.isFirst);
    }
  }

  /// 로그인한 계정과 로그아웃을 보여준다.
  Widget _buildLoginSection() {
    // 앱은 로그인해야 쓸 수 있어서, 로그아웃되는 순간에만 비어 있다.
    if (AuthService.currentUser == null) return const SizedBox.shrink();

    final provider = AuthService.currentProvider;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('로그인'),
        _row(
          child: Row(
            children: [
              _ProviderBadge(provider: provider),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      switch (provider) {
                        LoginProvider.google => 'Google 계정',
                        LoginProvider.kakao => '카카오 계정',
                        null => '로그인됨',
                      },
                      style: const TextStyle(
                        fontSize: 12,
                        color: WolodyColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AuthService.displayName ?? '연결된 계정',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _row(
          onTap: _confirmSignOut,
          child: const Row(
            children: [
              Icon(
                CupertinoIcons.square_arrow_right,
                size: 20,
                color: CupertinoColors.white,
              ),
              SizedBox(width: 10),
              Text(
                '로그아웃',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 34),
      ],
    );
  }

  Future<void> _confirmDeleteAll() async {
    HapticFeedback.lightImpact();
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('모든 기록을 삭제할까요?'),
        content: const Text(
          '기록과 사진, 삭제된 기록까지 모두 지워지고 되돌릴 수 없어요.\n'
          '프로필과 알림 설정은 그대로 남아요.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('모두 삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    HapticFeedback.heavyImpact();
    await deleteAllMoodEntries();
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      title,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    ),
  );

  Widget _row({required Widget child, VoidCallback? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: WolodyColors.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );
  }

  Widget _dataStat(String label, int value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: WolodyColors.brandBlue,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: WolodyColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: WolodyColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const WolodyTopBar(title: '계정 정보'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, kBottomNavSpace),
                children: [
                  if (AuthService.isAvailable)
                    StreamBuilder(
                      stream: AuthService.authChanges,
                      builder: (context, _) => _buildLoginSection(),
                    ),
                  _sectionTitle('프로필'),
                  _row(
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
                        const Text(
                          '수정',
                          style: TextStyle(
                            color: WolodyColors.brandBlue,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          CupertinoIcons.chevron_right,
                          size: 18,
                          color: WolodyColors.brandBlue,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 34),
                  _sectionTitle('저장된 데이터'),
                  ValueListenableBuilder<List<MoodEntry>>(
                    valueListenable: MoodStorage.cache,
                    builder: (context, entries, _) =>
                        ValueListenableBuilder<int>(
                          valueListenable: TrashStorage.count,
                          builder: (context, trashed, _) => _row(
                            child: Row(
                              children: [
                                _dataStat('기록', entries.length),
                                _dataStat(
                                  '사진',
                                  entries
                                      .where((e) => e.imageFileName != null)
                                      .length,
                                ),
                                _dataStat('삭제된 기록', trashed),
                              ],
                            ),
                          ),
                        ),
                  ),
                  const SizedBox(height: 10),
                  // 로그인·로그아웃하면 안내 문구도 바뀌도록 인증 상태를 구독한다.
                  StreamBuilder(
                    stream: AuthService.isAvailable
                        ? AuthService.authChanges
                        : null,
                    builder: (context, _) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        AuthService.currentUser == null
                            ? '지금은 모든 기록이 이 기기에만 저장돼요.'
                            : '기록·사진·프로필이 계정에 저장돼요. 다른 기기에서도 그대로 볼 수 있어요.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: WolodyColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 34),
                  _row(
                    onTap: _confirmDeleteAll,
                    child: const Row(
                      children: [
                        Icon(
                          CupertinoIcons.trash_fill,
                          size: 18,
                          color: CupertinoColors.systemRed,
                        ),
                        SizedBox(width: 10),
                        Text(
                          '모든 기록 삭제',
                          style: TextStyle(
                            color: CupertinoColors.systemRed,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 로그인한 서비스의 로고(구글 G, 카카오 말풍선).
class _ProviderBadge extends StatelessWidget {
  final LoginProvider? provider;

  const _ProviderBadge({required this.provider});

  @override
  Widget build(BuildContext context) {
    final kakao = provider == LoginProvider.kakao;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kakao ? const Color(0xFFFEE500) : CupertinoColors.white,
        shape: BoxShape.circle,
      ),
      child: SvgPicture.asset(
        kakao
            ? 'assets/AssetsDesign/Kakao.svg'
            : 'assets/AssetsDesign/Google.svg',
        width: 22,
        height: 22,
      ),
    );
  }
}
