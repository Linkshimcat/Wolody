import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mood_entry.dart';
import 'photo_storage.dart';
import 'supabase_config.dart';

/// 기분 기록 저장소.
///
/// 로그인 상태에서는 Supabase를 원본으로 쓴다. 네트워크가 끊기면 기기에
/// 캐시된 사본으로 동작하고, 다시 온라인이 되거나 로그인할 때 로컬 기록을
/// 클라우드로 올려 병합한다.
class MoodStorage {
  static const _key = 'mood_entries';
  static const _table = 'mood_entries';

  /// 가장 최근에 캐시/동기화된 기록 목록. 화면이 백그라운드 동기화 결과를
  /// 구독해 자동으로 다시 그리도록 한다.
  static final ValueNotifier<List<MoodEntry>> cache =
      ValueNotifier(const <MoodEntry>[]);

  /// 백그라운드 동기화가 도는 동안 true. 화면이 '동기화 중' 표시를 하는 데 쓴다.
  static final ValueNotifier<bool> syncing = ValueNotifier(false);

  // 동시에 여러 번 시작돼도 하나로 합치기 위한 인플라이트 가드.
  static Future<void>? _syncInFlight;

  /// 기록 목록을 돌려준다. 로그인 상태여도 로컬 캐시를 즉시 반환하고,
  /// 클라우드 동기화는 백그라운드에서 진행한다.
  ///
  /// 재접속 시 캐시만으로 화면을 바로 그리므로 체감 로딩이 빠르다.
  /// 동기화가 끝나면 [cache]를 갱신해 구독 중인 화면이 새 데이터를 받는다.
  Future<List<MoodEntry>> load() async {
    final cached = await _cachedEntries();
    cache.value = cached;
    unawaited(_sync());
    return cached;
  }

  /// 당겨서 새로고침 등에 쓴다. 클라우드와 맞춘 결과를 기다린다.
  Future<void> refresh() async {
    cache.value = await _cachedEntries();
    await _sync();
  }

  /// 기록 목록 전체를 저장한다.
  ///
  /// 목록에서 빠진 기록은 삭제로 처리하고, 네트워크가 안 되면 로컬 캐시만
  /// 갱신해 다음 기회에 클라우드와 맞춘다.
  Future<void> save(List<MoodEntry> entries) async {
    final user = _currentUser;
    if (user != null) {
      try {
        final cached = await _cachedEntries();
        final removedIds = cached
            .map((e) => e.id)
            .toSet()
            .difference(entries.map((e) => e.id).toSet())
            .toList();

        if (entries.isNotEmpty) {
          await _client
              .from(_table)
              .upsert(entries.map((e) => _toRow(e, user.id)).toList(),
                  onConflict: 'id');
        }
        if (removedIds.isNotEmpty) {
          await _client.from(_table).delete().inFilter('id', removedIds);
        }
      } catch (_) {
        // 오프라인 — 로컬 캐시만 갱신한다.
      }
    }
    final sorted = [...entries]..sort((a, b) => b.date.compareTo(a.date));
    await _cacheLocally(sorted);
    cache.value = sorted;
  }

  /// 로그인 직후 호출한다. 기기에만 남아 있는 기록을 클라우드로 올리고
  /// 다른 기기에서 쓴 기록을 내려받아 한 목록으로 합친다. 화면 로딩을
  /// 막지 않도록 [load]와 함께 백그라운드에서 수행된다.
  static Future<void> syncToCloud() => _sync();

  /// 백그라운드 동기화. 이미 도는 중이면 그걸 함께 기다린다.
  static Future<void> _sync() {
    if (_syncInFlight != null) return _syncInFlight!;
    final future = _syncNow().whenComplete(() => _syncInFlight = null);
    _syncInFlight = future;
    return future;
  }

  static Future<void> _syncNow() async {
    final user = _currentUser;
    if (user == null) return;
    syncing.value = true;
    try {
      final local = await _cachedEntries();
      final rows = await _client
          .from(_table)
          .select()
          .order('date', ascending: false);
      final cloud = rows.map(_rowToEntry).toList();
      final cloudIds = cloud.map((e) => e.id).toSet();
      final localOnly = local.where((e) => !cloudIds.contains(e.id)).toList();

      if (localOnly.isNotEmpty) {
        await _uploadEntries(localOnly, user.id);
      }
      // 사진은 한 장씩 기다리지 말고 한꺼번에 내려받는다.
      await Future.wait(
        cloud
            .where((e) => e.imageFileName != null)
            .map((e) => PhotoStorage.ensureLocal(e.imageFileName!)),
      );

      final merged = [...localOnly, ...cloud]
        ..sort((a, b) => b.date.compareTo(a.date));
      await _cacheLocally(merged);
      cache.value = merged;
    } catch (_) {
      // 네트워크 오류 — 기존 캐시 사본을 그대로 쓴다.
    } finally {
      syncing.value = false;
    }
  }

  /// 로그아웃할 때 이 기기에 남은 사본을 지운다. 계정의 기록은 클라우드에 남아
  /// 있어서 다시 로그인하면 돌아오고, 다음 계정에 섞여 올라가지 않는다.
  static Future<void> clearLocal() async {
    await _cacheLocally(const []);
    cache.value = const [];
  }

  static User? get _currentUser {
    if (!SupabaseConfig.isInitialized) return null;
    return Supabase.instance.client.auth.currentUser;
  }

  static SupabaseClient get _client => Supabase.instance.client;

  static Map<String, dynamic> _toRow(MoodEntry e, String userId) => {
        'id': e.id,
        'user_id': userId,
        'date': e.date.toIso8601String(),
        'emojis': e.emojis,
        'note': e.note,
        'image_file_name': e.imageFileName,
      };

  static MoodEntry _rowToEntry(Map<String, dynamic> row) => MoodEntry(
        id: row['id'] as String,
        date: DateTime.parse(row['date'] as String),
        emojis: (row['emojis'] as List).cast<String>(),
        note: row['note'] as String? ?? '',
        imageFileName: row['image_file_name'] as String?,
      );

  static Future<void> _uploadEntries(
    List<MoodEntry> entries,
    String userId,
  ) async {
    // 사진을 먼저 올린 뒤 기록 행을 만든다.
    for (final entry in entries) {
      if (entry.imageFileName != null) {
        await PhotoStorage.upload(entry.imageFileName!);
      }
    }
    await _client
        .from(_table)
        .upsert(entries.map((e) => _toRow(e, userId)).toList(),
            onConflict: 'id');
  }

  static Future<List<MoodEntry>> _cachedEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((e) => MoodEntry.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static Future<void> _cacheLocally(List<MoodEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = entries.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_key, raw);
  }
}
