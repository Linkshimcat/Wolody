import SwiftUI
import WidgetKit

struct MoodGrassProvider: TimelineProvider {
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
    let midnight = Calendar.current.startOfDay(
      for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    )
    completion(Timeline(entries: [entry], policy: .after(midnight)))
  }
}

/// 깃허브 잔디처럼 하루 한 칸씩, 그날 기분 색으로 채운다.
struct MoodGrassWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: "MoodGrassWidget",
      provider: MoodGrassProvider()
    ) { entry in
      MoodGrassView(data: entry.data)
        .widgetContainerBackground()
    }
    .configurationDisplayName("마음 잔디")
    .description("기록한 날을 그날의 마음 색으로 채웁니다.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct MoodGrassView: View {
  let data: MoodWidgetData

  private let spacing: CGFloat = 2.5
  /// 칸 하나의 목표 크기. 위젯 폭에 맞춰 보여줄 주 수를 여기서 역산한다.
  private let targetCell: CGFloat = 11

  var body: some View {
    GeometryReader { geometry in
      let weeks = weekCount(for: geometry.size.width)
      let cell = (geometry.size.width - spacing * CGFloat(weeks - 1))
        / CGFloat(weeks)

      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 6) {
          if data.recorded {
            WooldyPortrait(face: data.faces.first, size: 20)
          }
          Text("마음 잔디")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
          Spacer(minLength: 0)
          recordedCountText(weeks: weeks)
        }

        Spacer(minLength: 0)

        HStack(spacing: spacing) {
          ForEach(0..<weeks, id: \.self) { column in
            VStack(spacing: spacing) {
              ForEach(0..<7, id: \.self) { row in
                cellView(
                  column: column, row: row, size: cell, weeks: weeks
                )
              }
            }
          }
        }

        Spacer(minLength: 0)
      }
    }
  }

  /// 칸 크기를 일정하게 유지하려고 폭에 따라 주 수를 정한다.
  private func weekCount(for width: CGFloat) -> Int {
    let raw = Int((width + spacing) / (targetCell + spacing))
    return min(26, max(8, raw))
  }

  private func cellView(
    column: Int, row: Int, size: CGFloat, weeks: Int
  ) -> some View {
    let date = dateFor(column: column, row: row, weeks: weeks)
    let today = Calendar.current.startOfDay(for: Date())
    let isFuture = date > today
    let key = MoodWidgetData.dayFormatter.string(from: date)
    let color = data.colorsByDay[key].flatMap { Color(hex: $0) }

    let shape = RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
    return shape
      .fill(color ?? WolodyStyle.selectorSurface)
      // 오늘 아직 기록하지 않았다면 오늘 칸을 파란 테두리로 짚어준다.
      .overlay(
        shape.strokeBorder(
          WolodyStyle.brandBlue.opacity(date == today && color == nil ? 1 : 0),
          lineWidth: 1
        )
      )
      .frame(width: size, height: size)
      .opacity(isFuture ? 0 : 1)
  }

  /// 맨 오른쪽 열이 이번 주가 되도록 역산한다. 행은 월요일(0)~일요일(6).
  private func dateFor(column: Int, row: Int, weeks: Int) -> Date {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    // Calendar의 weekday는 일요일이 1이므로 월요일 시작으로 옮긴다.
    let mondayBased = (calendar.component(.weekday, from: today) + 5) % 7
    let daysFromStart = (column - (weeks - 1)) * 7 + (row - mondayBased)
    return calendar.date(byAdding: .day, value: daysFromStart, to: today) ?? today
  }

  /// "168일 중 60일". 기록해서 숫자가 바뀌면 자릿수가 위아래로 굴러 바뀐다.
  @ViewBuilder
  private func recordedCountText(weeks: Int) -> some View {
    let span = weeks * 7
    let recorded = recordedDays(span: span)
    let count = Text("\(recorded)")
      .foregroundColor(WolodyStyle.brandBlue)
      .fontWeight(.semibold)
    let text = Text("\(span)일 중 \(count)일")
      .font(.system(size: 11))
    .foregroundColor(WolodyStyle.textSecondary)
    .lineLimit(1)

    if #available(iOS 17.0, *) {
      text.contentTransition(.numericText(value: Double(recorded)))
    } else {
      text.contentTransition(.numericText())
    }
  }

  private func recordedDays(span: Int) -> Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    return data.colorsByDay.keys.filter { key in
      guard let date = MoodWidgetData.dayFormatter.date(from: key) else {
        return false
      }
      let days = calendar.dateComponents([.day], from: date, to: today).day ?? 0
      return days >= 0 && days < span
    }.count
  }
}
