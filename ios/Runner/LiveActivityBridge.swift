import ActivityKit
import Flutter
import UIKit

/// Dart에서 Live Activity를 시작/갱신/종료할 수 있게 해주는 메서드 채널.
enum LiveActivityBridge {
  private static let channelName = "wolody/live_activity"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      handle(call, result)
    }
  }

  private static func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      // 16.1 미만에서는 조용히 무시한다 — 앱의 다른 기능은 그대로 동작해야 한다.
      result(call.method == "isSupported" ? false : nil)
      return
    }

    switch call.method {
    case "isSupported":
      result(ActivityAuthorizationInfo().areActivitiesEnabled)
    case "start":
      start(args: call.arguments, result: result)
    case "update":
      update(args: call.arguments, result: result)
    case "end":
      end(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 16.1, *)
  private static func contentState(
    from args: Any?
  ) -> MoodActivityAttributes.ContentState {
    let map = args as? [String: Any] ?? [:]
    return MoodActivityAttributes.ContentState(
      emojis: map["emojis"] as? String ?? "",
      label: map["label"] as? String ?? "",
      recorded: map["recorded"] as? Bool ?? false,
      face: map["face"] as? Int,
      colorHex: map["color"] as? String
    )
  }

  @available(iOS 16.1, *)
  private static func start(args: Any?, result: @escaping FlutterResult) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      result(FlutterError(
        code: "not_enabled",
        message: "설정에서 실시간 활동이 꺼져 있습니다.",
        details: nil
      ))
      return
    }

    // 이미 떠 있는 활동이 있으면 새로 만들지 않고 내용만 갱신한다.
    if !Activity<MoodActivityAttributes>.activities.isEmpty {
      update(args: args, result: result)
      return
    }

    do {
      let map = args as? [String: Any] ?? [:]
      _ = try Activity.request(
        attributes: MoodActivityAttributes(
          title: map["title"] as? String ?? "오늘의 마음"
        ),
        contentState: contentState(from: args)
      )
      result(true)
    } catch {
      result(FlutterError(
        code: "start_failed",
        message: error.localizedDescription,
        details: nil
      ))
    }
  }

  @available(iOS 16.1, *)
  private static func update(args: Any?, result: @escaping FlutterResult) {
    let state = contentState(from: args)
    Task {
      for activity in Activity<MoodActivityAttributes>.activities {
        await activity.update(using: state)
      }
      result(true)
    }
  }

  @available(iOS 16.1, *)
  private static func end(result: @escaping FlutterResult) {
    Task {
      for activity in Activity<MoodActivityAttributes>.activities {
        await activity.end(dismissalPolicy: .immediate)
      }
      result(true)
    }
  }
}
