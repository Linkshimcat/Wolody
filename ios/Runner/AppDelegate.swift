import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    LiveActivityBridge.register(
      with: engineBridge.pluginRegistry.registrar(forPlugin: "LiveActivityBridge")!
    )
    WidgetBridge.register(
      with: engineBridge.pluginRegistry.registrar(forPlugin: "WidgetBridge")!
    )
    GlassPlatformView.register(
      with: engineBridge.pluginRegistry.registrar(forPlugin: "GlassPlatformView")!
    )
    GlassSwitchPlatformView.register(
      with: engineBridge.pluginRegistry.registrar(forPlugin: "GlassSwitchPlatformView")!
    )
    NativeTabBarBridge.register(
      with: engineBridge.pluginRegistry.registrar(forPlugin: "NativeTabBarBridge")!
    )
    registerHaptics(
      messenger: engineBridge.pluginRegistry.registrar(forPlugin: "Haptics")!.messenger()
    )
    registerAppearance(
      messenger: engineBridge.pluginRegistry.registrar(forPlugin: "Appearance")!.messenger()
    )
  }

  /// 앱에서 고른 화면 모드(시스템/라이트/다크)를 창에 입힌다. 네이티브 탭 바·스위치·
  /// 상태 바가 시스템 설정과 상관없이 Flutter 화면과 같은 모드로 그려진다.
  private func registerAppearance(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "wolody/appearance", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "setMode" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let style: UIUserInterfaceStyle
      switch call.arguments as? String {
      case "light": style = .light
      case "dark": style = .dark
      default: style = .unspecified
      }
      for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
        for window in scene.windows {
          window.overrideUserInterfaceStyle = style
        }
      }
      result(nil)
    }
  }

  /// Flutter의 HapticFeedback에는 없는 iOS 알림 햅틱(성공·경고·오류)을 열어 준다.
  private func registerHaptics(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "wolody/haptics", binaryMessenger: messenger)
    let generator = UINotificationFeedbackGenerator()
    channel.setMethodCallHandler { call, result in
      guard call.method == "notification" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let type: UINotificationFeedbackGenerator.FeedbackType
      switch call.arguments as? String {
      case "success": type = .success
      case "warning": type = .warning
      default: type = .error
      }
      generator.notificationOccurred(type)
      result(nil)
    }
  }
}
