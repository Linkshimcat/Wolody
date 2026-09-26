import SwiftUI

/// 앱이 App Group에 써둔 위젯용 요약 데이터.
struct MoodWidgetData {
  /// 오늘 기록 여부와 내용.
  var recorded: Bool
  var emojis: String
  var label: String
  /// 오늘 기분들의 울디 얼굴 번호(0~11). 첫 번째가 대표 얼굴이다.
  var faces: [Int]
  /// 첫 기분 색(RRGGBB). 얼굴 뒤 은은한 빛에 쓴다.
  var colorHex: String?
  /// "yyyy-MM-dd" → 그날 기분 색(RRGGBB). 잔디 그리드에 쓴다.
  var colorsByDay: [String: String]

  static let appGroupId = "group.com.linkcat.todayMood"
  static let storageKey = "widget_payload"

  static let placeholder = MoodWidgetData(
    recorded: true,
    emojis: "😄",
    label: "행복",
    faces: [0],
    colorHex: "FFD58A",
    colorsByDay: samplePreviewDays()
  )

  static let empty = MoodWidgetData(
    recorded: false,
    emojis: "",
    label: "",
    faces: [],
    colorHex: nil,
    colorsByDay: [:]
  )

  static func load() -> MoodWidgetData {
    guard
      let defaults = UserDefaults(suiteName: appGroupId),
      let raw = defaults.string(forKey: storageKey),
      let data = raw.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return .empty
    }

    return MoodWidgetData(
      recorded: json["recorded"] as? Bool ?? false,
      emojis: json["emojis"] as? String ?? "",
      label: json["label"] as? String ?? "",
      faces: json["faces"] as? [Int] ?? [],
      colorHex: json["color"] as? String,
      colorsByDay: json["days"] as? [String: String] ?? [:]
    )
  }

  /// 위젯 갤러리 미리보기에 쓸 그럴듯한 더미 데이터.
  private static func samplePreviewDays() -> [String: String] {
    let palette = ["FFD58A", "F3A8C7", "9DD6C1", "91B8E8", "E88E8E", "B5A8E8"]
    var days: [String: String] = [:]
    let formatter = MoodWidgetData.dayFormatter
    for offset in 0..<90 where offset % 3 != 0 {
      guard
        let date = Calendar.current.date(
          byAdding: .day, value: -offset, to: Date()
        )
      else { continue }
      days[formatter.string(from: date)] = palette[offset % palette.count]
    }
    return days
  }

  static let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()
}

/// Design.md의 Wolody 색 토큰. 위젯과 Live Activity는 앱처럼 항상 어두운 화면으로 그린다.
enum WolodyStyle {
  static let background = Color(red: 0x0D / 255, green: 0x11 / 255, blue: 0x18 / 255)
  static let surface = Color(red: 0x16 / 255, green: 0x1E / 255, blue: 0x2A / 255)
  static let selectorSurface = Color(red: 0x24 / 255, green: 0x2D / 255, blue: 0x3B / 255)
  static let textSecondary = Color(red: 0x85 / 255, green: 0x8B / 255, blue: 0x96 / 255)
  static let brandBlue = Color(red: 0x34 / 255, green: 0x6A / 255, blue: 0xE6 / 255)

  static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일 EEEE"
    return formatter
  }()
}

/// 앱의 WooldyMoodPortrait와 같은 울디 얼굴. 얼굴이 없으면(기록 전) 메모하는 울디를 그린다.
/// 기분 색이 있으면 앱의 감정 카드처럼 얼굴 뒤에 은은한 빛을 깐다.
struct WooldyPortrait: View {
  let face: Int?
  var glow: Color? = nil
  let size: CGFloat

  var body: some View {
    ZStack {
      if let glow {
        Circle()
          .fill(
            RadialGradient(
              colors: [glow.opacity(0.5), glow.opacity(0)],
              center: .center,
              startRadius: 0,
              endRadius: size * 0.7
            )
          )
          .frame(width: size * 1.4, height: size * 1.4)
      }
      Image(assetName)
        .resizable()
        .scaledToFit()
        .frame(width: size, height: size)
    }
    .frame(width: size, height: size)
  }

  private var assetName: String {
    guard let face, (0..<12).contains(face) else { return "WooldyWriting" }
    return "WooldyFace\(face)"
  }
}

extension View {
  /// iOS 17부터는 위젯이 배경을 직접 선언해야 하고, 그 이전에는 시스템이 넣어준다.
  @ViewBuilder
  func widgetContainerBackground() -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(WolodyStyle.surface, for: .widget)
        .environment(\.colorScheme, .dark)
    } else {
      background(WolodyStyle.surface)
        .environment(\.colorScheme, .dark)
    }
  }
}

extension Color {
  /// "FFD54F" 형태의 문자열을 색으로 바꾼다.
  init?(hex: String) {
    var value: UInt64 = 0
    guard Scanner(string: hex).scanHexInt64(&value), hex.count == 6 else {
      return nil
    }
    self.init(
      .sRGB,
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255
    )
  }
}
