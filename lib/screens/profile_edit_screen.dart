import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/haptics.dart';
import '../services/profile_storage.dart';
import '../theme.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/wolody_icon.dart';
import '../widgets/wolody_dialog.dart';

/// 마이 페이지에서 프로필 사진과 닉네임을 바꾸는 화면.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _initial = ProfileStorage.profile.value;
  late final _nicknameController = TextEditingController(
    text: _initial.nickname,
  );

  /// 새로 고른 사진. 저장하기 전까지는 미리보기로만 쓴다.
  String? _pickedPath;
  bool _removePhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  String get _nickname => _nicknameController.text.trim();

  bool get _hasPhoto =>
      _pickedPath != null || (!_removePhoto && _initial.photoFileName != null);

  bool get _canSave =>
      !_saving &&
      _nickname.isNotEmpty &&
      (_nickname != _initial.nickname ||
          _pickedPath != null ||
          (_removePhoto && _initial.photoFileName != null));

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _pickedPath = picked.path;
        _removePhoto = false;
      });
    } on PlatformException {
      // 카메라가 없는 기기(시뮬레이터)나 권한 거부 — 기존 사진을 그대로 둔다.
    }
  }

  void _showPhotoOptions() {
    Haptics.light();
    FocusScope.of(context).unfocus();
    showWolodySheet<String>(
      context: context,
      title: '프로필 사진',
      actions: [
        const WolodyAction(
          label: '사진 촬영',
          value: 'camera',
          icon: CupertinoIcons.camera_fill,
        ),
        const WolodyAction(
          label: '앨범에서 선택',
          value: 'gallery',
          icon: CupertinoIcons.photo_fill_on_rectangle_fill,
        ),
        if (_hasPhoto)
          const WolodyAction(
            label: '기본 이미지로 변경',
            value: 'reset',
            style: WolodyActionStyle.destructive,
            icon: CupertinoIcons.arrow_counterclockwise,
          ),
      ],
    ).then((choice) {
      if (!mounted) return;
      switch (choice) {
        case 'camera':
          _pickImage(ImageSource.camera);
        case 'gallery':
          _pickImage(ImageSource.gallery);
        case 'reset':
          setState(() {
            _pickedPath = null;
            _removePhoto = true;
          });
      }
    });
  }

  Future<void> _save() async {
    Haptics.medium();
    setState(() => _saving = true);
    await ProfileStorage.save(
      nickname: _nickname,
      photoSourcePath: _pickedPath,
      removePhoto: _removePhoto,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return CupertinoPageScaffold(
      backgroundColor: WolodyColors.of(context).background,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(
                onBack: () {
                  Haptics.light();
                  Navigator.pop(context);
                },
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                  children: [
                    Center(child: _buildAvatarPicker()),
                    const SizedBox(height: 48),
                    const Text('닉네임', style: kSectionTitleStyle),
                    const SizedBox(height: 20),
                    CupertinoTextField(
                      controller: _nicknameController,
                      placeholder: '닉네임을 입력해 주세요',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      clearButtonMode: OverlayVisibilityMode.editing,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(
                          UserProfile.maxNicknameLength,
                        ),
                      ],
                      onSubmitted: (_) {
                        if (_canSave) _save();
                      },
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: WolodyColors.of(context).textPrimary,
                      ),
                      placeholderStyle: TextStyle(
                        fontSize: 14,
                        color: WolodyColors.of(context).textSecondary,
                      ),
                      decoration: BoxDecoration(
                        color: WolodyColors.of(context).surface,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: WolodyColors.of(context).cardShadow,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _nickname.isEmpty
                                ? '닉네임은 한 글자 이상이어야 해요'
                                : '프로필과 마이 탭에 보여요',
                            style: TextStyle(
                              fontSize: 12,
                              color: WolodyColors.of(context).textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          '${_nicknameController.text.characters.length}'
                          '/${UserProfile.maxNicknameLength}',
                          style: TextStyle(
                            fontSize: 12,
                            color: WolodyColors.of(context).textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 10, 24, bottom + 15),
                child: PrimaryActionButton(
                  label: '저장하기',
                  onPressed: _canSave ? _save : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPicker() {
    return GestureDetector(
      onTap: _showPhotoOptions,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ProfileAvatar(
                size: 112,
                overridePath: _pickedPath,
                forceDefault: _removePhoto,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: WolodyColors.brandBlue,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: WolodyColors.of(context).background,
                      width: 3,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const WolodyIcon(
                    'iconsax-camera.svg',
                    size: 17,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '프로필 사진 변경',
            style: TextStyle(
              color: WolodyColors.brandBlue,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Row(
        children: [
          GlassBackButton(onPressed: onBack),
          const SizedBox(width: 14),
          const Text('프로필 수정', style: kPageTitleStyle),
        ],
      ),
    );
  }
}
