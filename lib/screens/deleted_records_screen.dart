import 'package:flutter/cupertino.dart';

import '../services/haptics.dart';
import '../services/mood_editor.dart';
import '../services/trash_storage.dart';
import '../theme.dart';
import '../widgets/mood_card.dart';
import '../widgets/wolody_top_bar.dart';
import '../widgets/wolody_dialog.dart';

/// 설정 → 삭제된 기록. 지운 기록을 30일 동안 보관했다가 복구하거나 영구 삭제한다.
class DeletedRecordsScreen extends StatefulWidget {
  const DeletedRecordsScreen({super.key});

  @override
  State<DeletedRecordsScreen> createState() => _DeletedRecordsScreenState();
}

class _DeletedRecordsScreenState extends State<DeletedRecordsScreen> {
  List<DeletedEntry>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await TrashStorage.load();
    if (mounted) setState(() => _items = items);
  }

  void _showActions(DeletedEntry deleted) {
    Haptics.light();
    showWolodySheet<bool>(
      context: context,
      title: '이 기록을 어떻게 할까요?',
      actions: const [
        WolodyAction(
          label: '복구하기',
          value: true,
          icon: CupertinoIcons.arrow_uturn_left,
        ),
        WolodyAction(
          label: '영구 삭제',
          value: false,
          style: WolodyActionStyle.destructive,
          icon: CupertinoIcons.trash_fill,
        ),
      ],
    ).then((restore) async {
      if (restore == null) return;
      if (restore) {
        Haptics.medium();
        await restoreMoodEntry(deleted);
      } else {
        Haptics.heavy();
        await TrashStorage.deleteForever(deleted);
      }
      await _load();
    });
  }

  Future<void> _confirmClear() async {
    Haptics.light();
    final confirmed = await showWolodyDialog<bool>(
      context: context,
      face: 11,
      title: '삭제된 기록을 모두 지울까요?',
      message: '사진까지 영구 삭제되고 되돌릴 수 없어요.',
      actions: const [
        WolodyAction(label: '취소', value: false),
        WolodyAction(
          label: '모두 삭제',
          value: true,
          style: WolodyActionStyle.destructive,
        ),
      ],
    );
    if (confirmed != true) return;
    Haptics.heavy();
    await TrashStorage.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return CupertinoPageScaffold(
      backgroundColor: WolodyColors.of(context).background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            WolodyTopBar(
              title: '삭제된 기록',
              trailing: items == null || items.isEmpty
                  ? null
                  : CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onPressed: _confirmClear,
                      child: const Text(
                        '모두 삭제',
                        style: TextStyle(
                          color: CupertinoColors.systemRed,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: items == null
                  ? const Center(child: CupertinoActivityIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        24,
                        20,
                        24,
                        kBottomNavSpace,
                      ),
                      children: [
                        Text(
                          '삭제한 기록은 30일 동안 보관된 뒤 영구 삭제돼요.\n'
                          '기록을 누르면 복구하거나 바로 지울 수 있어요.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: WolodyColors.of(context).textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (items.isEmpty)
                          SizedBox(
                            height: 320,
                            child: Center(
                              child: Text(
                                '삭제된 기록이 없어요.',
                                style: TextStyle(
                                  color: WolodyColors.of(context).textSecondary,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          )
                        else
                          for (final deleted in items) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 8,
                              ),
                              child: Text(
                                '${deleted.daysLeft(DateTime.now())}일 남음',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: WolodyColors.of(context).textSecondary,
                                ),
                              ),
                            ),
                            MoodCard(
                              entry: deleted.entry,
                              swipeable: false,
                              onTap: () => _showActions(deleted),
                              onDelete: () => _showActions(deleted),
                            ),
                          ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
