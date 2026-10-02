import 'mood.dart';

/// 감정 기록 화면에서 고른 감정·메모·사진.
class MoodPickerResult {
  final List<Mood> moods;
  final String note;
  final String? imagePath;

  const MoodPickerResult({
    required this.moods,
    required this.note,
    this.imagePath,
  });
}
