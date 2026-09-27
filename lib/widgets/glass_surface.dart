import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// iOS에서는 네이티브 Liquid Glass 머티리얼을, 그 밖에서는 블러로 대체한 배경.
///
/// Flutter는 자체 렌더러로 그리기 때문에 유리 재질을 직접 만들 수 없다.
/// iOS에서는 플랫폼 뷰를 깔고 그 위에 Flutter 위젯을 얹는다.
class GlassSurface extends StatelessWidget {
  /// 캡슐(양끝이 완전히 둥근) 모양인지. false면 [radius]를 쓴다.
  final bool capsule;
  final double radius;
  final Widget child;

  const GlassSurface({
    super.key,
    this.capsule = true,
    this.radius = 26,
    required this.child,
  });

  BorderRadius get _borderRadius =>
      capsule ? BorderRadius.circular(999) : BorderRadius.circular(radius);

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) return _fallback(context);

    return Stack(
      // 유리와 그 위 내용이 모두 부모 크기를 그대로 채우게 한다.
      fit: StackFit.expand,
      children: [
        UiKitView(
          viewType: 'wolody/glass',
          creationParams: {
            'capsule': capsule,
            'radius': radius,
            'interactive': true,
          },
          creationParamsCodec: const StandardMessageCodec(),
          // 유리는 배경일 뿐이고 탭은 위에 얹힌 Flutter 위젯이 받는다.
          hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        ),
        child,
      ],
    );
  }

  /// iOS가 아니거나 플랫폼 뷰를 못 쓸 때의 근사치.
  Widget _fallback(BuildContext context) {
    return ClipRRect(
      borderRadius: _borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground
                .resolveFrom(context)
                .withValues(alpha: 0.7),
            borderRadius: _borderRadius,
            border: Border.all(
              color: CupertinoColors.separator.resolveFrom(context),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Figma-shaped navigation rail with separate native glass shapes on iOS.
/// The Flutter child remains responsible for content and gestures.
class GlassTabBarSurface extends StatefulWidget {
  const GlassTabBarSurface({
    super.key,
    required this.selectedIndex,
    required this.position,
    required this.dragging,
    this.pressed = false,
    required this.child,
  });

  final int selectedIndex;
  final double position;
  final bool dragging;

  /// 누르고 있는 동안 선택 캡슐이 레일 밖으로 부푼 유리 렌즈가 된다.
  final bool pressed;
  final Widget child;

  @override
  State<GlassTabBarSurface> createState() => _GlassTabBarSurfaceState();
}

class _GlassTabBarSurfaceState extends State<GlassTabBarSurface> {
  /// 렌즈가 레일 위아래로 부풀 자리를 위해 네이티브 뷰를 사방으로 더 크게 깐다.
  static const _lensOverflow = 16.0;
  static int _channelSequence = 0;
  late final MethodChannel _channel = MethodChannel(
    'wolody/glass_tab_bar_${_channelSequence++}',
  );

  void _updateNativeSelection() {
    if (!Platform.isIOS) return;
    _channel.invokeMethod<void>('setSelection', {
      'index': widget.selectedIndex,
      'position': widget.position,
      'dragging': widget.dragging,
      'pressed': widget.pressed,
    });
  }

  @override
  void didUpdateWidget(GlassTabBarSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.position != widget.position ||
        oldWidget.dragging != widget.dragging ||
        oldWidget.pressed != widget.pressed) {
      _updateNativeSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -_lensOverflow,
            top: -_lensOverflow,
            right: -_lensOverflow,
            bottom: -_lensOverflow,
            child: UiKitView(
              viewType: 'wolody/glass_tab_bar',
              creationParams: {
                'channelName': _channel.name,
                'selectedIndex': widget.selectedIndex,
                'position': widget.position,
                'dragging': widget.dragging,
                'pressed': widget.pressed,
                'overflow': _lensOverflow,
              },
              creationParamsCodec: const StandardMessageCodec(),
              hitTestBehavior: PlatformViewHitTestBehavior.transparent,
            ),
          ),
          widget.child,
        ],
      );
    }

    return GlassSurface(capsule: true, child: widget.child);
  }
}
