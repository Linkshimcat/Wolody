import 'package:flutter/cupertino.dart';

import '../models/mood_entry.dart';
import '../screens/mood_entry_flow_screen.dart';
import '../models/mood_picker_result.dart';
import 'live_activity_service.dart';
import 'mood_storage.dart';
import 'widget_service.dart';
import 'photo_storage.dart';
import 'trash_storage.dart';

/// 새 기록 시트를 열고 저장까지 처리한다. 실제로 기록됐으면 true.
///
/// 햅틱은 버튼을 누른 쪽(홈·탭 바·달력)에서 이미 주므로 여기서는 주지 않는다.
Future<bool> createMoodEntry(BuildContext context) async {
  // 마이 탭 안(리캡 등)에서 불러도 기록 화면은 탭 바 없이 전체 화면으로 띄운다.
  final result = await Navigator.of(context, rootNavigator: true)
      .push<MoodPickerResult>(
        CupertinoPageRoute(builder: (_) => const MoodEntryFlowScreen()),
      );
  if (result == null) return false;

  final storage = MoodStorage();
  final entries = await storage.load();
  final imageFileName = result.imagePath == null
      ? null
      : await PhotoStorage.save(result.imagePath!);
  entries.insert(
    0,
    MoodEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      date: DateTime.now(),
      emojis: result.moods.map((m) => m.emoji).toList(),
      note: result.note,
      imageFileName: imageFileName,
    ),
  );
  await storage.save(entries);
  if (imageFileName != null) await PhotoStorage.upload(imageFileName);
  await LiveActivityService.refresh();
  await WidgetService.refresh();
  return true;
}

/// 기록 수정 시트를 열고 저장까지 처리한다. 실제로 수정됐으면 true.
///
/// 호출한 화면은 true를 받으면 목록을 다시 읽어야 한다.
Future<bool> editMoodEntry(BuildContext context, MoodEntry entry) async {
  final result = await Navigator.of(context, rootNavigator: true)
      .push<MoodPickerResult>(
        CupertinoPageRoute(builder: (_) => MoodEntryFlowScreen(initial: entry)),
      );
  if (result == null) return false;

  final oldFileName = entry.imageFileName;
  final oldPath = oldFileName == null
      ? null
      : PhotoStorage.pathFor(oldFileName);

  // 시트가 돌려준 경로가 원래 사진 그대로면 파일을 다시 저장할 필요가 없다.
  final String? newFileName;
  if (result.imagePath == null) {
    newFileName = null;
  } else if (result.imagePath == oldPath) {
    newFileName = oldFileName;
  } else {
    newFileName = await PhotoStorage.save(result.imagePath!);
  }
  if (oldFileName != null && newFileName != oldFileName) {
    await PhotoStorage.delete(oldFileName);
  }

  final storage = MoodStorage();
  final entries = await storage.load();
  final index = entries.indexWhere((e) => e.id == entry.id);
  if (index == -1) return false;

  entries[index] = MoodEntry(
    id: entry.id,
    date: entry.date,
    emojis: result.moods.map((m) => m.emoji).toList(),
    note: result.note,
    imageFileName: newFileName,
  );
  await storage.save(entries);
  if (newFileName != null) await PhotoStorage.upload(newFileName);
  await LiveActivityService.refresh();
  await WidgetService.refresh();
  return true;
}

/// 기록을 휴지통으로 옮긴다. 사진은 영구 삭제할 때까지 남겨둔다.
Future<void> deleteMoodEntry(MoodEntry entry) async {
  final storage = MoodStorage();
  final entries = await storage.load();
  entries.removeWhere((e) => e.id == entry.id);
  await storage.save(entries);
  await TrashStorage.add(entry);
  await LiveActivityService.refresh();
  await WidgetService.refresh();
}

/// 휴지통의 기록을 목록으로 되돌린다.
Future<void> restoreMoodEntry(DeletedEntry deleted) async {
  final storage = MoodStorage();
  final entries = await storage.load();
  if (!entries.any((e) => e.id == deleted.entry.id)) {
    entries.add(deleted.entry);
    await storage.save(entries);
  }
  final photo = deleted.entry.imageFileName;
  if (photo != null) await PhotoStorage.upload(photo);
  await TrashStorage.remove(deleted.entry.id);
  await LiveActivityService.refresh();
  await WidgetService.refresh();
}

/// 모든 기록과 휴지통, 연결된 사진을 되돌릴 수 없게 지운다.
/// 프로필과 알림 설정은 그대로 둔다.
Future<void> deleteAllMoodEntries() async {
  final storage = MoodStorage();
  final entries = await storage.load();
  await storage.save(const []);
  for (final entry in entries) {
    final photo = entry.imageFileName;
    if (photo != null) await PhotoStorage.delete(photo);
  }
  await TrashStorage.clear();
  await LiveActivityService.refresh();
  await WidgetService.refresh();
}
