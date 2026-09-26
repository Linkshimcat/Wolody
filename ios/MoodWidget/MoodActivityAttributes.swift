import ActivityKit
import Foundation

/// 앱(Runner)과 위젯 익스텐션이 함께 쓰는 Live Activity 데이터 정의.
/// 두 타겟에 같은 파일이 포함되므로 타입이 정확히 일치한다.
@available(iOS 16.1, *)
struct MoodActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    /// 오늘 기록한 이모지를 이어붙인 문자열. 기록 전이면 빈 값.
    var emojis: String
    /// "행복 · 활발"처럼 기분 이름을 이어붙인 문자열.
    var label: String
    /// 오늘 기록을 남겼는지 여부.
    var recorded: Bool
    /// 첫 기분의 울디 얼굴 번호(0~11). 이전 버전 상태와 호환되도록 옵셔널이다.
    var face: Int?
    /// 첫 기분 색(RRGGBB). 얼굴 뒤 은은한 빛에 쓴다.
    var colorHex: String?
  }

  /// 활동이 살아있는 동안 바뀌지 않는 제목.
  var title: String
}
