import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'photo_storage.dart';
import 'supabase_config.dart';

/// 마이 페이지에 보이는 닉네임과 프로필 사진.
@immutable
class UserProfile {
  static const defaultNickname = 'Accounts';
  static const maxNicknameLength = 20;

  final String nickname;

  /// 문서 폴더에 저장된 프로필 사진 파일명. null이면 기본 울디 이미지를 쓴다.
  final String? photoFileName;

  const UserProfile({required this.nickname, this.photoFileName});

  String? get photoPath =>
      photoFileName == null ? null : PhotoStorage.pathFor(photoFileName!);
}

/// 프로필을 기기에 보관하고, 바뀌면 탭 바·마이 페이지가 바로 다시 그리도록 알린다.
///
/// 로그인한 계정의 프로필은 Supabase `profiles` 테이블(사진은 mood-photos 버킷)에도
/// 저장해, 앱을 다시 깔거나 다른 기기에서 로그인해도 같은 프로필이 돌아온다.
class ProfileStorage {
  static const _nicknameKey = 'profile_nickname';
  static const _photoKey = 'profile_photo_file';
  static const _table = 'profiles';

  static final profile = ValueNotifier(
    const UserProfile(nickname: UserProfile.defaultNickname),
  );

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final photo = prefs.getString(_photoKey);
    profile.value = UserProfile(
      nickname: prefs.getString(_nicknameKey) ?? UserProfile.defaultNickname,
      // 앱을 다시 설치해 파일이 사라졌다면 기본 이미지로 돌아간다.
      photoFileName:
          photo != null && File(PhotoStorage.pathFor(photo)).existsSync()
          ? photo
          : null,
    );
  }

  /// [photoSourcePath]가 있으면 새 사진으로 바꾸고, [removePhoto]면 기본 이미지로 되돌린다.
  static Future<void> save({
    required String nickname,
    String? photoSourcePath,
    bool removePhoto = false,
  }) async {
    final previousPhoto = profile.value.photoFileName;
    var photo = previousPhoto;

    if (photoSourcePath != null) {
      final extension = photoSourcePath.split('.').last;
      // 파일명을 매번 바꿔야 Image.file 캐시가 예전 사진을 보여주지 않는다.
      photo = 'profile_${DateTime.now().microsecondsSinceEpoch}.$extension';
      await File(photoSourcePath).copy(PhotoStorage.pathFor(photo));
    } else if (removePhoto) {
      photo = null;
    }

    await _writeLocal(nickname, photo);
    if (previousPhoto != null && previousPhoto != photo) {
      // 기기와 계정 저장소에 남은 예전 사진을 함께 지운다.
      await PhotoStorage.delete(previousPhoto);
    }
    await _push();
  }

  /// 계정에 저장된 프로필을 기기로 가져온다. 계정에 프로필이 없거나
  /// 오프라인이면 false를 돌려주고 기기의 프로필을 그대로 둔다.
  static Future<bool> pullFromCloud() async {
    final userId = _userId;
    if (userId == null) return false;
    try {
      final row = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return false;
      final photo = row['photo_file_name'] as String?;
      if (photo != null) await PhotoStorage.ensureLocal(photo);
      final hasPhoto =
          photo != null && File(PhotoStorage.pathFor(photo)).existsSync();
      final previousPhoto = profile.value.photoFileName;
      await _writeLocal(row['nickname'] as String, hasPhoto ? photo : null);
      if (previousPhoto != null && previousPhoto != photo) {
        // 다른 계정이나 예전 사진 파일이 기기에 남지 않게 한다(계정 사본은 그대로).
        final old = File(PhotoStorage.pathFor(previousPhoto));
        if (old.existsSync()) await old.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 로그아웃할 때 기기의 프로필을 기본값으로 되돌린다. 계정 사본은 그대로 남는다.
  static Future<void> resetLocal() async {
    final photo = profile.value.photoFileName;
    if (photo != null) {
      final file = File(PhotoStorage.pathFor(photo));
      if (file.existsSync()) await file.delete();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_nicknameKey);
    await prefs.remove(_photoKey);
    profile.value = const UserProfile(nickname: UserProfile.defaultNickname);
  }

  static Future<void> _writeLocal(String nickname, String? photo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nicknameKey, nickname);
    if (photo == null) {
      await prefs.remove(_photoKey);
    } else {
      await prefs.setString(_photoKey, photo);
    }
    profile.value = UserProfile(nickname: nickname, photoFileName: photo);
  }

  /// 지금 프로필을 로그인한 계정에 올린다. 오프라인이면 다음 저장 때 다시 올린다.
  static Future<void> _push() async {
    final userId = _userId;
    if (userId == null) return;
    final current = profile.value;
    try {
      if (current.photoFileName != null) {
        await PhotoStorage.upload(current.photoFileName!);
      }
      await _client.from(_table).upsert({
        'user_id': userId,
        'nickname': current.nickname,
        'photo_file_name': current.photoFileName,
      });
    } catch (_) {
      // 오프라인 — 기기에는 이미 저장됐다.
    }
  }

  static String? get _userId {
    if (!SupabaseConfig.isInitialized) return null;
    return Supabase.instance.client.auth.currentUser?.id;
  }

  static SupabaseClient get _client => Supabase.instance.client;
}
