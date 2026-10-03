import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';

import '../theme.dart';
import 'pressable.dart';
import 'wooldy_mood_portrait.dart';

/// 대화상자·시트 버튼의 성격.
enum WolodyActionStyle {
  /// 취소처럼 가벼운 선택(회색 칩).
  normal,

  /// 권장하는 선택(브랜드 블루).
  primary,

  /// 되돌릴 수 없는 선택(빨강).
  destructive,
}

/// 대화상자·시트의 버튼 하나. 누르면 [value]를 돌려주며 닫힌다.
class WolodyAction<T> {
  final String label;
  final T value;
  final WolodyActionStyle style;

  /// 시트에서 글자 앞에 붙는 아이콘.
  final IconData? icon;

  const WolodyAction({
    required this.label,
    required this.value,
    this.style = WolodyActionStyle.normal,
    this.icon,
  });
}

/// Wolody 스타일 알림 대화상자(Alert).
///
/// 둥근 카드 위에 (선택) 울디 얼굴 → BM Jua 제목 → 설명 → 캡슐 버튼들이 놓이고,
/// 뒤 화면은 흐려지며 카드는 통 튀어나온다. iOS 기본 CupertinoAlertDialog 대신 쓴다.
/// 버튼은 2개까지 한 줄, 3개 이상이면 세로로 쌓인다. 바깥을 누르면 null로 닫힌다.
Future<T?> showWolodyDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  int? face,
  required List<WolodyAction<T>> actions,
  bool barrierDismissible = true,
}) {
  return _showWolodyRoute<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    alignment: Alignment.center,
    builder: (context) => _WolodyDialog<T>(
      title: title,
      message: message,
      face: face,
      actions: actions,
    ),
    transition: (animation, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.88, end: 1).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeInCubic,
          ),
        ),
        child: child,
      ),
    ),
  );
}

/// Wolody 스타일 액션 시트(Action Sheet). 아래에서 올라오는 선택지 목록과 취소 버튼.
/// iOS 기본 CupertinoActionSheet 대신 쓴다. 취소하거나 바깥을 누르면 null.
Future<T?> showWolodySheet<T>({
  required BuildContext context,
  String? title,
  required List<WolodyAction<T>> actions,
  String cancelLabel = '취소',
}) {
  return _showWolodyRoute<T>(
    context: context,
    barrierDismissible: true,
    alignment: Alignment.bottomCenter,
    builder: (context) => _WolodySheet<T>(
      title: title,
      actions: actions,
      cancelLabel: cancelLabel,
    ),
    transition: (animation, child) => SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
      ),
      child: child,
    ),
  );
}

Future<T?> _showWolodyRoute<T>({
  required BuildContext context,
  required bool barrierDismissible,
  required Alignment alignment,
  required WidgetBuilder builder,
  required Widget Function(Animation<double> animation, Widget child)
  transition,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0x00000000),
    transitionDuration: reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 320),
    pageBuilder: (context, _, _) => builder(context),
    transitionBuilder: (context, animation, _, child) {
      final colors = WolodyColors.of(context);
      return Stack(
        children: [
          // 뒤 화면을 흐리고 어둡게. 바깥을 누르면 닫힌다.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: barrierDismissible
                  ? () => Navigator.of(context).maybePop()
                  : null,
              child: FadeTransition(
                opacity: animation,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: ColoredBox(
                    color: colors.isLight
                        ? const Color(0x590F172A)
                        : const Color(0x8C000000),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: alignment,
              child: reduceMotion ? child : transition(animation, child),
            ),
          ),
        ],
      );
    },
  );
}

class _WolodyDialog<T> extends StatelessWidget {
  final String title;
  final String? message;
  final int? face;
  final List<WolodyAction<T>> actions;

  const _WolodyDialog({
    required this.title,
    required this.message,
    required this.face,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = WolodyColors.of(context);
    final width = math.min(MediaQuery.sizeOf(context).width - 48, 340.0);
    final buttons = [
      for (final action in actions)
        _ActionButton(
          label: action.label,
          style: action.style,
          onTap: () => Navigator.of(context).pop(action.value),
        ),
    ];
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.isLight
                ? const Color(0x1F0F172A)
                : const Color(0x59000000),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (face != null) ...[
            WooldyMoodPortrait(faceIndex: face!, size: 72),
            const SizedBox(height: 12),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: kSectionTitleStyle.copyWith(
              fontSize: 22,
              color: colors.textPrimary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: colors.textSecondary,
                decoration: TextDecoration.none,
              ),
            ),
          ],
          const SizedBox(height: 22),
          if (buttons.length <= 2)
            Row(
              children: [
                for (var i = 0; i < buttons.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: buttons[i]),
                ],
              ],
            )
          else
            Column(
              children: [
                for (var i = 0; i < buttons.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  buttons[i],
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _WolodySheet<T> extends StatelessWidget {
  final String? title;
  final List<WolodyAction<T>> actions;
  final String cancelLabel;

  const _WolodySheet({
    required this.title,
    required this.actions,
    required this.cancelLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = WolodyColors.of(context);
    final destructive = CupertinoColors.systemRed.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Text(
                      title!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                for (var i = 0; i < actions.length; i++)
                  _SheetRow(
                    action: actions[i],
                    divider: i > 0 || title != null,
                    color: actions[i].style == WolodyActionStyle.destructive
                        ? destructive
                        : colors.textPrimary,
                    onTap: () => Navigator.of(context).pop(actions[i].value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _ActionButton(
            label: cancelLabel,
            style: WolodyActionStyle.normal,
            height: 56,
            background: colors.surface,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final WolodyAction action;
  final bool divider;
  final Color color;
  final VoidCallback onTap;

  const _SheetRow({
    required this.action,
    required this.divider,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = WolodyColors.of(context);
    return Pressable(
      scale: 0.98,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: divider
                ? Border(top: BorderSide(color: colors.outline, width: 0.5))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (action.icon != null) ...[
                Icon(action.icon, size: 20, color: color),
                const SizedBox(width: 10),
              ],
              Text(
                action.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 캡슐 버튼. 주 버튼(PrimaryActionButton)과 같은 둥근 모양·눌림 손맛.
class _ActionButton extends StatelessWidget {
  final String label;
  final WolodyActionStyle style;
  final VoidCallback onTap;
  final double height;
  final Color? background;

  const _ActionButton({
    required this.label,
    required this.style,
    required this.onTap,
    this.height = 52,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final colors = WolodyColors.of(context);
    final (fill, text) = switch (style) {
      WolodyActionStyle.normal => (
        background ?? colors.chipIdle,
        colors.textPrimary,
      ),
      WolodyActionStyle.primary => (
        WolodyColors.brandBlue,
        CupertinoColors.white,
      ),
      WolodyActionStyle.destructive => (
        CupertinoColors.systemRed.resolveFrom(context),
        CupertinoColors.white,
      ),
    };
    return Pressable(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: text,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
