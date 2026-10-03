import 'package:flutter/cupertino.dart';

import '../models/mood_entry.dart';
import '../services/auth_service.dart';
import '../services/haptics.dart';
import '../services/mood_storage.dart';
import '../services/profile_storage.dart';
import '../services/trash_storage.dart';
import '../theme.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/wolody_top_bar.dart';
import '../widgets/pressable.dart';

/// 계정 정보 → 계정 탈퇴.
///
/// 지워지는 것을 보여 주고, "확인했어요"를 체크해야 탈퇴 버튼이 켜진다.
/// 마지막으로 한 번 더 묻고 나서 [AuthService.deleteAccount]로 계정을 지운다.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _confirmed = false;
  bool _deleting = false;

  void _toggleConfirmed() {
    if (_deleting) return;
    Haptics.selection();
    setState(() => _confirmed = !_confirmed);
  }

  Future<void> _delete() async {
    Haptics.light();
    final sure = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('정말 탈퇴할까요?'),
        content: const Text('탈퇴하면 기록과 사진을 다시 되돌릴 수 없어요.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    Haptics.heavy();
    setState(() => _deleting = true);
    try {
      await AuthService.deleteAccount();
    } on LoginException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      Haptics.error();
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('탈퇴하지 못했어요'),
          content: Text(e.message),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }
    Haptics.success();
    // 계정이 사라지면 AuthGate가 로그인 화면으로 바뀐다. 그 위에 떠 있는 화면들을 걷어낸다.
    if (mounted) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = WolodyColors.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    // 지우는 동안에는 뒤로 가지 못하게 한다.
    return PopScope(
      canPop: !_deleting,
      child: CupertinoPageScaffold(
        backgroundColor: colors.background,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const WolodyTopBar(title: '계정 탈퇴'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/AssetsDesign/wooldy_surprised.png',
                        height: 180,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '정말 떠나시나요?',
                      textAlign: TextAlign.center,
                      style: kSectionTitleStyle,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '탈퇴하면 아래 내용이 모두 지워지고\n되돌릴 수 없어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildLosses(colors),
                    const SizedBox(height: 20),
                    _buildConfirmRow(colors),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 10, 24, bottom + 15),
                child: _deleting
                    ? const SizedBox(
                        height: 58,
                        child: Center(child: CupertinoActivityIndicator()),
                      )
                    : PrimaryActionButton(
                        label: '탈퇴하기',
                        color: CupertinoColors.systemRed,
                        onPressed: _confirmed ? _delete : null,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 탈퇴하면 지워지는 것들. 기록이 바뀌면 바로 다시 센다.
  Widget _buildLosses(WolodyPalette colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: colors.cardShadow,
      ),
      child: ValueListenableBuilder<List<MoodEntry>>(
        valueListenable: MoodStorage.cache,
        builder: (context, entries, _) => ValueListenableBuilder<int>(
          valueListenable: TrashStorage.count,
          builder: (context, trashed, _) {
            final photos = entries.where((e) => e.imageFileName != null);
            final provider = switch (AuthService.currentProvider) {
              LoginProvider.google => 'Google',
              LoginProvider.kakao => '카카오',
              null => '연결된 계정',
            };
            return Column(
              children: [
                _lossRow(
                  colors,
                  CupertinoIcons.book_fill,
                  '마음 기록',
                  '${entries.length}개',
                ),
                _lossRow(
                  colors,
                  CupertinoIcons.photo_fill,
                  '사진',
                  '${photos.length}장',
                ),
                _lossRow(
                  colors,
                  CupertinoIcons.trash_fill,
                  '삭제된 기록',
                  '$trashed개',
                ),
                ValueListenableBuilder<UserProfile>(
                  valueListenable: ProfileStorage.profile,
                  builder: (context, profile, _) => _lossRow(
                    colors,
                    CupertinoIcons.person_crop_circle_fill,
                    '프로필',
                    profile.nickname,
                  ),
                ),
                _lossRow(
                  colors,
                  CupertinoIcons.link,
                  '앱 연결',
                  provider,
                  last: true,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _lossRow(
    WolodyPalette colors,
    IconData icon,
    String label,
    String value, {
    bool last = false,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: colors.outline, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.textSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmRow(WolodyPalette colors) {
    return Pressable(
      scale: 0.98,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleConfirmed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(
                _confirmed
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.circle,
                size: 24,
                color: _confirmed
                    ? WolodyColors.brandBlue
                    : colors.textSecondary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '위 내용을 모두 확인했어요',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
