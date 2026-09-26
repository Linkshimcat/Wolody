import 'package:flutter/cupertino.dart';

abstract final class WolodyColors {
  static const background = Color(0xFF0D1118);
  static const surface = Color(0xFF161E2A);
  static const surfaceRaised = Color(0xFF23262D);
  static const selectorSurface = Color(0xFF242D3B);
  static const surfaceSelected = Color(0xFF060B12);
  static const outline = Color(0xFF303844);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF858B96);
  static const brandBlue = Color(0xFF346AE6);
  static const actionLavender = Color(0xFF96A1BF);
}

/// 네비게이션 바 배경.
///
/// Cupertino 기본값(0xF0F9F9F9)은 알파가 94%라 블러가 거의 드러나지 않고,
/// 라이트 모드에서는 그룹 배경색과 색이 겹쳐 경계가 보이지 않는다.
/// 알파를 70%로 낮춰 스크롤한 내용이 비치는 프로스티드 글래스로 만든다.
const kNavBarBackground = CupertinoDynamicColor.withBrightness(
  color: Color(0xB3FFFFFF),
  darkColor: Color(0xB31D1D1D),
);

/// 떠 있는 바텀 네비게이션이 가리는 높이. 각 화면은 스크롤 끝에 이만큼을
/// 비워둬야 마지막 카드가 바 뒤에 숨지 않는다.
/// (iOS 26 네이티브 바 83 + 하단 인셋 34 + 오프셋 8 + 여유)
const kBottomNavSpace = 132.0;

/// 화면 배경.
///
/// 라이트는 iOS 기본 그룹 배경을, 다크는 앱만의 짙은 청회색(0C0F14)을 쓴다.
const kAppBackground = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFF2F2F7),
  darkColor: WolodyColors.background,
);

/// 그룹 목록(설정 화면) 섹션 카드 배경.
///
/// 다크 모드에서는 배경(0C0F14)보다 살짝 밝아 카드가 드러나도록 한다.
const kListSectionBackground = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFFFFFFF),
  darkColor: WolodyColors.surface,
);

/// 선택된 탭 뒤에 깔리는 표시.
///
/// 유리보다 어둡게 하면 얼룩처럼 보인다. 반대로 더 밝고 불투명하게 만들어
/// 유리 위에 한 겹 얹힌 것처럼 보이게 한다.
const kTabIndicator = CupertinoDynamicColor.withBrightness(
  color: Color(0xF2FFFFFF),
  darkColor: Color(0x40FFFFFF),
);
