import 'package:flutter/cupertino.dart';

/// 화면 모드마다 다른 색. `WolodyColors.of(context)`로 꺼내 쓴다.
///
/// 다크는 원래 Wolody의 짙은 청회색, 라이트는 Figma 라이트 시안(홈 23:393)의 값이다.
@immutable
class WolodyPalette {
  final Brightness brightness;
  final Color background;

  /// 카드·배너처럼 배경 위에 뜨는 면.
  final Color surface;

  /// 설정 행처럼 배경 위에 놓이는 한 줄짜리 면.
  final Color surfaceRaised;

  /// 감정 고르기 카드.
  final Color selectorSurface;

  /// 카드 안에 한 겹 더 놓이는 칩·타일(통계, 태그 등).
  final Color inset;

  /// 설정의 루틴 카드처럼 여러 줄을 묶는 카드.
  final Color groupCard;
  final Color outline;
  final Color textPrimary;
  final Color textSecondary;

  /// 고르지 않은 칩·세그먼트 버튼.
  final Color chipIdle;

  /// 달력에서 고른 날의 바탕.
  final Color daySelected;
  final Color toastBackground;
  final Color closeIcon;

  /// 스크롤하면 내용이 비쳐 보이는 홈 헤더의 반투명 바탕.
  final Color headerScrim;
  final Color skeletonBase;
  final Color skeletonHighlight;

  /// 주 행동 버튼(기록하기 등)의 바탕.
  final Color ctaBackground;

  /// 'Wolody' 글자 로고.
  final Color logo;

  /// 카드 그림자. 다크는 배경과 면의 명도 차로 충분해 그림자를 쓰지 않는다.
  final List<BoxShadow> cardShadow;

  const WolodyPalette._({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.selectorSurface,
    required this.inset,
    required this.groupCard,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.chipIdle,
    required this.daySelected,
    required this.toastBackground,
    required this.closeIcon,
    required this.headerScrim,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.ctaBackground,
    required this.logo,
    required this.cardShadow,
  });

  bool get isLight => brightness == Brightness.light;

  static const dark = WolodyPalette._(
    brightness: Brightness.dark,
    background: Color(0xFF0D1118),
    surface: Color(0xFF161E2A),
    surfaceRaised: Color(0xFF23262D),
    selectorSurface: Color(0xFF242D3B),
    inset: Color(0xFF2D3648),
    groupCard: Color(0xFF202329),
    outline: Color(0xFF303844),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF858B96),
    chipIdle: Color(0xFF34373D),
    daySelected: Color(0xFF22365E),
    toastBackground: Color(0xFF202838),
    closeIcon: Color(0xFF747B86),
    headerScrim: Color(0x800D1118),
    skeletonBase: Color(0xFF242D3B),
    skeletonHighlight: Color(0xFF34405A),
    ctaBackground: Color(0xFF96A1BF),
    logo: Color(0xFF80A4FF),
    cardShadow: [],
  );

  static const light = WolodyPalette._(
    brightness: Brightness.light,
    background: Color(0xFFF5F7FA),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    selectorSurface: Color(0xFFFFFFFF),
    inset: Color(0xFFF1F4F9),
    groupCard: Color(0xFFFFFFFF),
    outline: Color(0xFFD7DEEA),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    chipIdle: Color(0xFFE8EDF5),
    daySelected: Color(0xFFE3ECFF),
    toastBackground: Color(0xFFFFFFFF),
    closeIcon: Color(0xFF9AA3B2),
    headerScrim: Color(0xB3F5F7FA),
    skeletonBase: Color(0xFFE8EDF5),
    skeletonHighlight: Color(0xFFF5F7FA),
    // 시안의 연회색 버튼은 주 행동치고 약해 보여 브랜드 블루로 채운다.
    ctaBackground: WolodyColors.brandBlue,
    // 시안의 하늘색(82A9FF)은 흰 배경에서 대비가 낮아 브랜드 블루로 쓴다.
    logo: WolodyColors.brandBlue,
    cardShadow: [
      BoxShadow(
        color: Color(0x0F0F172A),
        blurRadius: 16,
        spreadRadius: -4,
        offset: Offset(0, 4),
      ),
    ],
  );
}

abstract final class WolodyColors {
  /// 두 모드에서 같은 브랜드 색.
  static const brandBlue = Color(0xFF346AE6);

  /// 지금 화면 모드(설정 → 화면, 또는 iOS 설정)에 맞는 팔레트.
  static WolodyPalette of(BuildContext context) =>
      CupertinoTheme.brightnessOf(context) == Brightness.light
      ? WolodyPalette.light
      : WolodyPalette.dark;
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

/// 뒤로 가기 버튼 옆 화면 제목(설정, 계정 정보 등). Figma 설정 화면 기준.
const kPageTitleStyle = TextStyle(fontFamily: 'BM Jua', fontSize: 26);

/// 화면 안의 큰 섹션 제목(알림, 루틴, 기록 관리 등). Figma 설정 화면 기준.
const kSectionTitleStyle = TextStyle(fontFamily: 'BM Jua', fontSize: 30);

/// 떠 있는 바텀 네비게이션이 가리는 높이. 각 화면은 스크롤 끝에 이만큼을
/// 비워둬야 마지막 카드가 바 뒤에 숨지 않는다.
/// (iOS 26 네이티브 바 83 + 하단 인셋 34 + 오프셋 8 + 여유)
const kBottomNavSpace = 132.0;
