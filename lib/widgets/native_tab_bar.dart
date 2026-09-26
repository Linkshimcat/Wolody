import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../services/profile_storage.dart';

/// iOS 26+의 네이티브 Liquid Glass 하단 탭 바.
///
/// 실제 `UITabBar`를 플랫폼 뷰로 올려 Apple이 시스템에 입힌 유리 재질·떠 있는
/// 모양·선택 캡슐·누르면 부푸는 렌즈를 그대로 쓴다. 아이템을 넘기면 네이티브가
/// 그리고, 탭/기록 버튼 이벤트는 메서드 채널로 받는다.
class NativeTabBar extends StatefulWidget {
  const NativeTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAdd,
    this.tintColor,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final Color? tintColor;

  @override
  State<NativeTabBar> createState() => _NativeTabBarState();
}

class _NativeTabBarState extends State<NativeTabBar> {
  // 바가 여러 개 만들어져도 상태를 섞지 않도록 채널 이름을 매번 다르게 한다.
  static int _channelSequence = 0;
  late final MethodChannel _channel = MethodChannel(
    'today_mood/tab_bar_${_channelSequence++}',
  );

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleNativeCall);
    ProfileStorage.profile.addListener(_sendAvatar);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onSelect':
        final index = (call.arguments as Map?)?['index'] as int? ?? 0;
        widget.onSelect(index);
      case 'onAdd':
        widget.onAdd();
    }
    return null;
  }

  /// 프로필 사진을 바꾸면 "마이" 탭 아이콘도 새 사진으로 다시 그린다.
  void _sendAvatar() {
    _channel.invokeMethod<void>('setAvatar', {
      'path': ProfileStorage.profile.value.photoPath,
    });
  }

  @override
  void didUpdateWidget(NativeTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Dart 쪽에서 탭을 바꿨을 때(예: 기록 후 홈 복귀) 네이티브 선택을 맞춘다.
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _channel.invokeMethod<void>('setSelected', {
        'index': widget.selectedIndex,
      });
    }
  }

  @override
  void dispose() {
    ProfileStorage.profile.removeListener(_sendAvatar);
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) return const SizedBox.shrink();
    return UiKitView(
      viewType: 'today_mood/tab_bar',
      creationParams: {
        'channelName': _channel.name,
        'selectedIndex': widget.selectedIndex,
        'tintColor':
            (widget.tintColor ?? CupertinoTheme.of(context).primaryColor)
                .toARGB32(),
        'titles': const ['홈', '기록', '마이'],
        // 'avatar'는 SF Symbol 대신 프로필 사진을 동그랗게 그린다.
        'icons': const ['house.fill', 'calendar', 'avatar'],
        'avatarPath': ProfileStorage.profile.value.photoPath,
      },
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
