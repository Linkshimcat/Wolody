import 'dart:io';

import 'package:flutter/cupertino.dart';

import '../services/profile_storage.dart';

/// 원형 프로필 사진. 사용자가 고른 사진이 없으면 기본 울디 이미지를 보여준다.
///
/// [overridePath]를 주면 저장 전 미리보기처럼 그 파일을 대신 그린다.
class ProfileAvatar extends StatelessWidget {
  final double size;
  final String? overridePath;
  final bool forceDefault;

  const ProfileAvatar({
    super.key,
    required this.size,
    this.overridePath,
    this.forceDefault = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile>(
      valueListenable: ProfileStorage.profile,
      builder: (context, profile, _) {
        final path = forceDefault ? null : overridePath ?? profile.photoPath;
        return ClipOval(
          child: path == null
              // 기본 울디 이미지는 배경이 투명하므로 Figma처럼 밝은 원 위에 올린다.
              ? Container(
                  color: const Color(0xFFE9ECF3),
                  child: Image.asset(
                    'assets/AssetsDesign/image 5.png',
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  ),
                )
              : Image.file(
                  File(path),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                ),
        );
      },
    );
  }
}
