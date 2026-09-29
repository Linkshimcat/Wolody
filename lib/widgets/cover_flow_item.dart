import 'package:flutter/widgets.dart';

/// PageView 한 칸을 커버 플로우처럼 기울인다.
///
/// 가운데 카드는 정면을 보고, 옆으로 갈수록(-1~1) 작아지면서 바깥쪽으로
/// 원근감 있게 돌아간다. PageView의 itemBuilder에서 각 카드를 감싸 쓴다.
class CoverFlowItem extends StatelessWidget {
  final PageController controller;
  final int index;
  final Widget child;

  const CoverFlowItem({
    super.key,
    required this.controller,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // 첫 레이아웃 전에는 page를 알 수 없어 시작 페이지로 대신한다.
        final page = controller.hasClients && controller.position.haveDimensions
            ? controller.page ?? controller.initialPage.toDouble()
            : controller.initialPage.toDouble();
        final offset = (index - page).clamp(-1.0, 1.0);
        return Transform(
          alignment: offset > 0 ? Alignment.centerLeft : Alignment.centerRight,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(-offset * 0.45)
            ..scaleByDouble(
              1 - offset.abs() * 0.15,
              1 - offset.abs() * 0.15,
              1,
              1,
            ),
          child: child,
        );
      },
      child: child,
    );
  }
}
