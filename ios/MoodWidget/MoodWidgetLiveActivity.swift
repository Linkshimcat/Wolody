import ActivityKit
import SwiftUI
import WidgetKit

/// 잠금화면과 Dynamic Island에 오늘의 마음 기록 상태를 보여준다.
struct MoodWidgetLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: MoodActivityAttributes.self) { context in
      LockScreenView(state: context.state, title: context.attributes.title)
        .activityBackgroundTint(WolodyStyle.background.opacity(0.9))
        .activitySystemActionForegroundColor(Color.white)
    } dynamicIsland: { context in
      let state = context.state
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          WooldyPortrait(face: state.face, glow: glow(state), size: 44)
            .padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          StatusBadge(recorded: state.recorded)
            .padding(.trailing, 4)
        }
        DynamicIslandExpandedRegion(.bottom) {
          Text(state.recorded ? state.label : "오늘의 마음을 기록해보세요")
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
      } compactLeading: {
        WooldyPortrait(face: state.face, size: 22)
      } compactTrailing: {
        Image(systemName: state.recorded ? "checkmark.circle.fill" : "pencil")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(WolodyStyle.brandBlue)
      } minimal: {
        WooldyPortrait(face: state.face, size: 20)
      }
      .keylineTint(WolodyStyle.brandBlue)
    }
  }

  private func glow(_ state: MoodActivityAttributes.ContentState) -> Color? {
    state.colorHex.flatMap { Color(hex: $0) }
  }
}

private struct LockScreenView: View {
  let state: MoodActivityAttributes.ContentState
  let title: String

  var body: some View {
    HStack(spacing: 14) {
      WooldyPortrait(
        face: state.face,
        glow: state.colorHex.flatMap { Color(hex: $0) },
        size: 52
      )

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(WolodyStyle.textSecondary)
        Text(state.recorded ? state.label : "아직 기록하지 않았어요")
          .font(.system(size: 17, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }

      Spacer(minLength: 0)

      StatusBadge(recorded: state.recorded)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 16)
  }
}

/// 기록했으면 파란 체크, 아직이면 앱의 주요 버튼처럼 "기록하기" 캡슐을 보여준다.
private struct StatusBadge: View {
  let recorded: Bool

  var body: some View {
    if recorded {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 22))
        .foregroundStyle(WolodyStyle.brandBlue)
    } else {
      Text("기록하기")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(WolodyStyle.brandBlue))
    }
  }
}
