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
