import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mood_entry.dart';
import 'photo_storage.dart';

/// 휴지통에 들어간 기록과 지운 시각.
@immutable
class DeletedEntry {
  final MoodEntry entry;
  final DateTime deletedAt;

  const DeletedEntry({required this.entry, required this.deletedAt});

  /// 영구 삭제까지 남은 날 수(오늘 지웠으면 30).
  int daysLeft(DateTime now) {
    final elapsed = now.difference(deletedAt).inDays;
    return (TrashStorage.retention.inDays - elapsed).clamp(0, 999);
  }

  Map<String, dynamic> toJson() => {
    'entry': entry.toJson(),
    'deletedAt': deletedAt.toIso8601String(),
  };

  factory DeletedEntry.fromJson(Map<String, dynamic> json) => DeletedEntry(
    entry: MoodEntry.fromJson(json['entry'] as Map<String, dynamic>),
    deletedAt: DateTime.parse(json['deletedAt'] as String),
  );
}

/// 삭제한 기록을 30일 동안 보관하는 휴지통.
///
/// 기록을 지워도 사진 파일은 남겨두었다가, 영구 삭제하거나 보관 기간이
/// 지날 때 함께 지운다. 기기에만 보관한다.
class TrashStorage {
  static const _key = 'deleted_mood_entries';
  static const retention = Duration(days: 30);

  /// 휴지통에 있는 기록 수. 설정·계정 정보 행이 구독한다.
  static final count = ValueNotifier<int>(0);

  /// 최근에 지운 순서로 돌려준다. 보관 기간이 지난 기록은 이때 정리한다.
  static Future<List<DeletedEntry>> load({DateTime? now}) async {
    final all = await _read();
    final cutoff = (now ?? DateTime.now()).subtract(retention);
    final expired = all.where((e) => e.deletedAt.isBefore(cutoff)).toList();
    if (expired.isEmpty) {
      count.value = all.length;
      return all;
    }
    final kept = all.where((e) => !e.deletedAt.isBefore(cutoff)).toList();
    await _deletePhotos(expired);
    await _write(kept);
    return kept;
  }

  static Future<void> add(MoodEntry entry, {DateTime? now}) async {
    final all = await _read();
    all.insert(0, DeletedEntry(entry: entry, deletedAt: now ?? DateTime.now()));
    await _write(all);
  }

  /// 휴지통에서 꺼낸다. 기록을 목록에 되돌리는 건 호출한 쪽이 한다.
  static Future<void> remove(String entryId) async {
    final all = await _read();
    all.removeWhere((e) => e.entry.id == entryId);
    await _write(all);
  }

  /// 기록과 사진을 되돌릴 수 없게 지운다.
  static Future<void> deleteForever(DeletedEntry deleted) async {
    await _deletePhotos([deleted]);
    await remove(deleted.entry.id);
  }

  /// 휴지통을 비운다(사진 포함).
  static Future<void> clear() async {
    await _deletePhotos(await _read());
    await _write(const []);
  }

  static Future<void> _deletePhotos(List<DeletedEntry> entries) async {
    for (final deleted in entries) {
      final photo = deleted.entry.imageFileName;
      if (photo != null) await PhotoStorage.delete(photo);
    }
  }

  static Future<List<DeletedEntry>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw
        .map(
          (e) => DeletedEntry.fromJson(jsonDecode(e) as Map<String, dynamic>),
        )
        .toList()
      ..sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
  }

  static Future<void> _write(List<DeletedEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      entries.map((e) => jsonEncode(e.toJson())).toList(),
    );
    count.value = entries.length;
  }
}
