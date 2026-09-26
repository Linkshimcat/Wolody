import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'photo_storage.dart';

/// 마이 페이지에 보이는 닉네임과 프로필 사진.
@immutable
class UserProfile {
  static const defaultNickname = '이윤재';
  static const maxNicknameLength = 10;

  final String nickname;

  /// 문서 폴더에 저장된 프로필 사진 파일명. null이면 기본 울디 이미지를 쓴다.
  final String? photoFileName;

  const UserProfile({required this.nickname, this.photoFileName});

  String? get photoPath =>
      photoFileName == null ? null : PhotoStorage.pathFor(photoFileName!);
}

/// 프로필을 기기에 보관하고, 바뀌면 탭 바·마이 페이지가 바로 다시 그리도록 알린다.
class ProfileStorage {
  static const _nicknameKey = 'profile_nickname';
  static const _photoKey = 'profile_photo_file';

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
    final prefs = await SharedPreferences.getInstance();
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

    await prefs.setString(_nicknameKey, nickname);
    if (photo == null) {
      await prefs.remove(_photoKey);
    } else {
      await prefs.setString(_photoKey, photo);
    }
    if (previousPhoto != null && previousPhoto != photo) {
      final old = File(PhotoStorage.pathFor(previousPhoto));
      if (old.existsSync()) await old.delete();
    }

    profile.value = UserProfile(nickname: nickname, photoFileName: photo);
  }
}
