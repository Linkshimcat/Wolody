import SwiftUI
import WidgetKit

struct MoodEntryView: TimelineEntry {
  let date: Date
  let data: MoodWidgetData
}

struct MoodTodayProvider: TimelineProvider {
  func placeholder(in context: Context) -> MoodEntryView {
    MoodEntryView(date: Date(), data: .placeholder)
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (MoodEntryView) -> Void
  ) {
    let data = context.isPreview ? MoodWidgetData.placeholder : MoodWidgetData.load()
    completion(MoodEntryView(date: Date(), data: data))
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<MoodEntryView>) -> Void
  ) {
    let entry = MoodEntryView(date: Date(), data: MoodWidgetData.load())
    // 날짜가 바뀌면 "오늘"의 기준도 바뀌므로 자정에 다시 그린다.
    let midnight = Calendar.current.startOfDay(
      for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    )
    completion(Timeline(entries: [entry], policy: .after(midnight)))
  }
}

struct MoodTodayWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: "MoodTodayWidget",
      provider: MoodTodayProvider()
    ) { entry in
      MoodTodayView(data: entry.data, date: entry.date)
        .widgetContainerBackground()
    }
    .configurationDisplayName("오늘의 마음")
    .description("오늘 기록한 마음을 울디 얼굴로 보여줍니다.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct MoodTodayView: View {
  let data: MoodWidgetData
  let date: Date

  @Environment(\.widgetFamily) private var family

  private var glow: Color? { data.colorHex.flatMap { Color(hex: $0) } }

  var body: some View {
    if family == .systemMedium {
      mediumLayout
    } else {
      smallLayout
    }
  }

  private var smallLayout: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Spacer(minLength: 0)
      WooldyPortrait(face: data.faces.first, glow: glow, size: 62)
        .frame(maxWidth: .infinity)
      Spacer(minLength: 0)
      Text(data.recorded ? data.label : "아직 기록 전")
        .font(.system(size: 16, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      footnote
        .padding(.top, 2)
    }
  }

  private var mediumLayout: some View {
    HStack(spacing: 18) {
      WooldyPortrait(face: data.faces.first, glow: glow, size: 96)
      VStack(alignment: .leading, spacing: 0) {
        header
        Spacer(minLength: 6)
        Text(data.recorded ? data.label : "아직 오늘의 마음을\n기록하지 않았어요")
          .font(.system(size: data.recorded ? 22 : 17, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
          .lineLimit(2)
          .minimumScaleFactor(0.6)
        if data.faces.count > 1 {
          // 여러 기분을 골랐다면 나머지 얼굴도 작게 이어 보여준다.
          HStack(spacing: 2) {
            ForEach(Array(data.faces.dropFirst().prefix(4).enumerated()), id: \.offset) {
              WooldyPortrait(face: $0.element, size: 22)
            }
          }
          .padding(.top, 6)
        }
        Spacer(minLength: 6)
        footnote
      }
      Spacer(minLength: 0)
    }
  }

  private var header: some View {
    HStack(spacing: 4) {
      Text("오늘의 마음")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(WolodyStyle.textSecondary)
      Spacer(minLength: 0)
      if data.recorded {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 14))
          .foregroundStyle(WolodyStyle.brandBlue)
      }
    }
  }

  /// 기록했으면 날짜를, 아직이면 앱으로 들어가 기록하라는 안내를 보여준다.
  @ViewBuilder
  private var footnote: some View {
    if data.recorded {
      Text(WolodyStyle.dateFormatter.string(from: date))
        .font(.system(size: 11))
        .foregroundStyle(WolodyStyle.textSecondary)
        .lineLimit(1)
    } else {
      Text("눌러서 기록하기")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(WolodyStyle.brandBlue)
        .lineLimit(1)
    }
  }
}
