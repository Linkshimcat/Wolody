import Flutter
import UIKit
import WidgetKit

/// Dart가 만든 위젯용 요약 JSON을 App Group에 저장하고 위젯을 다시 그리게 한다.
enum WidgetBridge {
  private static let channelName = "wolody/widget"
  private static let appGroupId = "group.com.linkcat.wolody"
  private static let storageKey = "widget_payload"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "update":
        guard
          let json = call.arguments as? String,
          let defaults = UserDefaults(suiteName: appGroupId)
        else {
          // App Group을 못 열면 위젯에 데이터를 넘길 방법이 없다.
          result(false)
          return
        }
        defaults.set(json, forKey: storageKey)
        if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
        }
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
