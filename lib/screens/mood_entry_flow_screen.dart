import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/mood.dart';
import '../models/mood_entry.dart';
import '../services/photo_storage.dart';
import '../theme.dart';
import '../widgets/mood_picker_sheet.dart';
import '../widgets/glass_back_button.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/wooldy_mood_portrait.dart';
import '../widgets/wolody_icon.dart';

class MoodEntryFlowScreen extends StatefulWidget {
  final MoodEntry? initial;

  const MoodEntryFlowScreen({super.key, this.initial});

  @override
  State<MoodEntryFlowScreen> createState() => _MoodEntryFlowScreenState();
}

class _MoodEntryFlowScreenState extends State<MoodEntryFlowScreen> {
  late final PageController _pageController;
  final _noteController = TextEditingController();
  final _selected = <String>{};
  int _focusedIndex = 4;
  int _step = 0;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _selected.addAll(
        initial.emojis.map((emoji) => Mood.fromEmoji(emoji).emoji),
      );
      _noteController.text = initial.note;
      _imagePath = initial.imageFileName == null
          ? null
          : PhotoStorage.pathFor(initial.imageFileName!);
      _focusedIndex = Mood.all.indexOf(Mood.fromEmoji(initial.emojis.first));
    }
    _pageController = PageController(
      initialPage: _focusedIndex,
      viewportFraction: .59,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _toggleMood(Mood mood) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.add(mood.emoji)) _selected.remove(mood.emoji);
      _focusedIndex = Mood.all.indexOf(mood);
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null && mounted) setState(() => _imagePath = picked.path);
  }

  void _showImageOptions() {
    HapticFeedback.lightImpact();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _pickImage(ImageSource.camera);
            },
            child: const Text('사진 촬영'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(sheetContext);
              _pickImage(ImageSource.gallery);
            },
            child: const Text('앨범에서 선택'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('취소'),
        ),
      ),
    );
  }

  void _continue() {
    if (_step == 0) {
      if (_selected.isEmpty) return;
      HapticFeedback.selectionClick();
      setState(() => _step = 1);
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      MoodPickerResult(
        moods: Mood.all
            .where((mood) => _selected.contains(mood.emoji))
            .toList(),
        note: _noteController.text.trim(),
        imagePath: _imagePath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return CupertinoPageScaffold(
      backgroundColor: WolodyColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              onBack: () {
                HapticFeedback.lightImpact();
                if (_step == 1) {
                  setState(() => _step = 0);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            Expanded(
              child: _step == 0 ? _buildMoodSelection() : _buildMemoEntry(),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 10, 24, bottom + 15),
              child: PrimaryActionButton(
                label: _step == 0
                    ? '다음으로 넘어가기'
                    : (widget.initial == null ? '기록하기' : '수정 완료'),
                onPressed: _step == 0 && _selected.isEmpty ? null : _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodSelection() {
    return Column(
      children: [
        const SizedBox(height: 36),
        const Text(
          '오늘은 어떤 기분을 느끼시나요?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'BM Jua',
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '여러 개 선택할 수 있어요',
          style: TextStyle(fontSize: 14, color: WolodyColors.textSecondary),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 480),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -.12),
                          radius: .92,
                          colors: [
                            Mood.all[_focusedIndex].color.withValues(
                              alpha: .52,
                            ),
                            Mood.all[_focusedIndex].color.withValues(
                              alpha: .27,
                            ),
                            WolodyColors.brandBlue.withValues(alpha: .17),
                            const Color(0x000D1118),
                          ],
                          stops: const [0, .36, .72, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -28),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: Mood.all.length,
                  onPageChanged: (index) {
                    HapticFeedback.selectionClick();
                    setState(() => _focusedIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final mood = Mood.all[index];
                    final selected = _selected.contains(mood.emoji);
                    return Center(
                      child: GestureDetector(
                        onTap: () => _toggleMood(mood),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 198,
                          height: 360,
                          decoration: BoxDecoration(
                            color: WolodyColors.selectorSurface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: selected
                                  ? mood.color
                                  : const Color(0x00000000),
                              width: 2,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                top: 82,
                                child: WooldyMoodPortrait(
                                  faceIndex: mood.faceIndex,
                                  size: 128,
                                ),
                              ),
                              Positioned(
                                bottom: 35,
                                child: Text(
                                  mood.label,
                                  style: TextStyle(
                                    fontFamily: 'BM Jua',
                                    color: selected
                                        ? mood.color
                                        : CupertinoColors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (selected)
                                Positioned(
                                  top: 14,
                                  right: 14,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: mood.color,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.checkmark,
                                      size: 16,
                                      color: Color(0xFF161E2A),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemoEntry() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 12),
      children: [
        const Row(
          children: [
            WolodyIcon(
              'iconsax-note.svg',
              size: 22,
              color: CupertinoColors.white,
            ),
            SizedBox(width: 10),
            Text(
              '오늘의 하루를 기록 해 보세요',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 28),
        CupertinoTextField(
          controller: _noteController,
          minLines: 6,
          maxLines: 9,
          placeholder: '오늘 있었던 일을 적어보세요.. (선택)',
          padding: const EdgeInsets.all(20),
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: WolodyColors.textPrimary,
          ),
          placeholderStyle: const TextStyle(
            fontSize: 13,
            color: WolodyColors.textSecondary,
          ),
          decoration: BoxDecoration(
            color: WolodyColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        const SizedBox(height: 60),
        const Row(
          children: [
            WolodyIcon(
              'iconsax-camera.svg',
              size: 22,
              color: CupertinoColors.white,
            ),
            SizedBox(width: 10),
            Text(
              '찍은 사진이 있나요?',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_imagePath == null)
          GestureDetector(
            onTap: _showImageOptions,
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                color: WolodyColors.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  WolodyIcon(
                    'iconsax-camera.svg',
                    size: 19,
                    color: CupertinoColors.white,
                  ),
                  SizedBox(width: 12),
                  Text(
                    '사진 추가',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          )
        else
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.file(
                  File(_imagePath!),
                  width: double.infinity,
                  height: 170,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _imagePath = null);
                  },
                  child: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Row(
        children: [
          GlassBackButton(onPressed: onBack),
          const SizedBox(width: 10),
          const Text(
            '감정 기록',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
