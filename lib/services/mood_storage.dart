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
/// 클라우드로 올려 병합한다. 앱이 켜져 있는 동안에는 [watchCloud]로 다른 기기의
/// 추가·수정·삭제를 실시간으로 받아 바로 반영한다.
class MoodStorage {
  static const _key = 'mood_entries';
  static const _table = 'mood_entries';

  /// 클라우드에 올라가 있다고 확인한 기록 id. 동기화할 때 클라우드에 없는 로컬 기록이
  /// 이 목록에 있으면 "다른 기기에서 지운 것"이라 지우고, 없으면 "아직 못 올린 새 기록"
  /// 이라 올린다. 이게 없으면 다른 기기에서 지운 기록이 다시 올라가 되살아난다.
  static const _syncedKey = 'mood_synced_ids';

  /// 오프라인이라 클라우드에서 지우지 못한 기록 id. 다음 동기화 때 먼저 지운다.
  static const _pendingDeleteKey = 'mood_pending_deletes';

  /// 가장 최근에 캐시/동기화된 기록 목록. 화면이 백그라운드 동기화 결과를
  /// 구독해 자동으로 다시 그리도록 한다.
  static final ValueNotifier<List<MoodEntry>> cache = ValueNotifier(
    const <MoodEntry>[],
  );

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
      final cached = await _cachedEntries();
      final removedIds = cached
          .map((e) => e.id)
          .toSet()
          .difference(entries.map((e) => e.id).toSet());
      final synced = await _readIds(_syncedKey);
      try {
        if (entries.isNotEmpty) {
          await _client
              .from(_table)
              .upsert(
                entries.map((e) => _toRow(e, user.id)).toList(),
                onConflict: 'id',
              );
          synced.addAll(entries.map((e) => e.id));
        }
      } catch (_) {
        // 오프라인 — 아직 못 올린 기록은 다음 동기화 때 올라간다.
      }
      if (removedIds.isNotEmpty) {
        try {
          await _client.from(_table).delete().inFilter('id', [...removedIds]);
        } catch (_) {
          // 오프라인 — 다음 동기화 때 지우도록 남겨 둔다.
          final pending = await _readIds(_pendingDeleteKey)
            ..addAll(removedIds);
          await _writeIds(_pendingDeleteKey, pending);
        }
        synced.removeAll(removedIds);
      }
      await _writeIds(_syncedKey, synced);
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
      final synced = await _readIds(_syncedKey);
      // 오프라인일 때 지운 기록을 먼저 클라우드에서도 지운다.
      final pending = await _readIds(_pendingDeleteKey);
      if (pending.isNotEmpty) {
        await _client.from(_table).delete().inFilter('id', [...pending]);
        await _writeIds(_pendingDeleteKey, {});
      }
      final rows = await _client
          .from(_table)
          .select()
          .order('date', ascending: false);
      final cloud = rows.map(_rowToEntry).toList();
      final plan = planSync(local: local, cloud: cloud, synced: synced);
      final localOnly = plan.upload;

      if (localOnly.isNotEmpty) {
        await _uploadEntries(localOnly, user.id);
      }
      // 사진은 한 장씩 기다리지 말고 한꺼번에 내려받는다.
      await Future.wait(
        cloud
            .where((e) => e.imageFileName != null)
            .map((e) => PhotoStorage.ensureLocal(e.imageFileName!)),
      );

      final merged = plan.merged;
      await _cacheLocally(merged);
      await _writeIds(_syncedKey, merged.map((e) => e.id).toSet());
      cache.value = merged;
    } catch (_) {
      // 네트워크 오류 — 기존 캐시 사본을 그대로 쓴다.
    } finally {
      syncing.value = false;
    }
  }

  /// 동기화 때 어떤 기록을 올리고 최종 목록을 무엇으로 할지 정한다.
  ///
  /// - 클라우드에 있는 기록은 클라우드 내용을 따른다(다른 기기에서 고친 것 반영).
  /// - 클라우드에 없는 로컬 기록 중 올린 적 없는 것([synced]에 없음)은 새 기록이라 올린다.
  /// - 올린 적 있는데 클라우드에서 사라진 기록은 다른 기기에서 지운 것이라 뺀다.
  static ({List<MoodEntry> merged, List<MoodEntry> upload}) planSync({
    required List<MoodEntry> local,
    required List<MoodEntry> cloud,
    required Set<String> synced,
  }) {
    final cloudIds = cloud.map((e) => e.id).toSet();
    final upload = local
        .where((e) => !cloudIds.contains(e.id) && !synced.contains(e.id))
        .toList();
    final merged = [...upload, ...cloud]
      ..sort((a, b) => b.date.compareTo(a.date));
    return (merged: merged, upload: upload);
  }

  /// 로그아웃할 때 이 기기에 남은 사본을 지운다. 계정의 기록은 클라우드에 남아
  /// 있어서 다시 로그인하면 돌아오고, 다음 계정에 섞여 올라가지 않는다.
  static Future<void> clearLocal() async {
    await _cacheLocally(const []);
    await _writeIds(_syncedKey, {});
    await _writeIds(_pendingDeleteKey, {});
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
        .upsert(
          entries.map((e) => _toRow(e, userId)).toList(),
          onConflict: 'id',
        );
  }

  // ---------------------------------------------------------------------------
  // 실시간 반영
  // ---------------------------------------------------------------------------

  static RealtimeChannel? _realtime;
  static Timer? _debounce;

  /// 다른 기기에서 기록을 추가·수정·삭제하면 곧바로 동기화해 [cache]를 갱신한다.
  /// 변경을 받아 동기화가 끝날 때마다 [onRemoteChange]를 부른다(위젯 갱신 등).
  ///
  /// 내 행의 추가·수정은 RLS가 걸러 준 것만 오고, 삭제는 Supabase가 행 주인을
  /// 확인할 수 없어 모든 구독자에게 id만 오므로, 내가 가진 기록일 때만 반응한다.
  static void watchCloud({required VoidCallback onRemoteChange}) {
    final user = _currentUser;
    if (user == null || _realtime != null) return;
    _realtime = _client
        .channel('mood-entries-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              final id = payload.oldRecord['id'];
              if (!cache.value.any((e) => e.id == id)) return;
            }
            // 여러 변경이 한꺼번에 오면 한 번만 동기화한다.
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), () async {
              await _sync();
              onRemoteChange();
            });
          },
        )
        .subscribe();
  }

  static Future<void> stopWatching() async {
    _debounce?.cancel();
    final channel = _realtime;
    _realtime = null;
    if (channel != null) await _client.removeChannel(channel);
  }

  static Future<Set<String>> _readIds(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(key) ?? const []).toSet();
  }

  static Future<void> _writeIds(String key, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, ids.toList());
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
