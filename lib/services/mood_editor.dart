import 'package:flutter/cupertino.dart';

import '../models/mood_entry.dart';
import '../screens/mood_entry_flow_screen.dart';
import '../widgets/mood_picker_sheet.dart';
import 'live_activity_service.dart';
import 'mood_storage.dart';
import 'widget_service.dart';
import 'photo_storage.dart';

/// 새 기록 시트를 열고 저장까지 처리한다. 실제로 기록됐으면 true.
///
/// 햅틱은 버튼을 누른 쪽(홈·탭 바·달력)에서 이미 주므로 여기서는 주지 않는다.
Future<bool> createMoodEntry(BuildContext context) async {
  final result = await Navigator.of(context).push<MoodPickerResult>(
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
  final result = await Navigator.of(context).push<MoodPickerResult>(
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
