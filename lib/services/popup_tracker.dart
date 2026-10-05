import 'package:flutter/widgets.dart';

/// 대화상자·시트처럼 화면 위에 뜨는 팝업이 몇 개 열려 있는지 센다.
///
/// iOS 네이티브 유리 버튼·스위치(플랫폼 뷰)는 Flutter가 그리는 흐림·어둠 막 위로
/// 그대로 비쳐 보인다. 팝업이 떠 있는 동안에는 이 값을 보고 Flutter로 그린
/// 대체 모양으로 바꿔, 막 아래로 함께 흐려지게 한다.
class PopupTracker extends NavigatorObserver {
  static final open = ValueNotifier<int>(0);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) open.value++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _closed(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _closed(route);

  /// 닫히는 애니메이션이 끝난 뒤에 줄인다. 막이 사라지기 전에 네이티브 뷰가
  /// 먼저 튀어나오지 않게 하려는 것이다.
  void _closed(Route<dynamic> route) {
    if (route is! PopupRoute) return;
    route.completed.whenComplete(() {
      if (open.value > 0) open.value--;
    });
  }
}
