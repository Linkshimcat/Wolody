import Flutter
import UIKit

/// Flutter 위젯 뒤에 iOS 26의 진짜 Liquid Glass 머티리얼을 깔아주는 플랫폼 뷰.
/// Flutter는 자체 렌더러로 그리기 때문에 이 재질은 네이티브 뷰로만 얻을 수 있다.
enum GlassPlatformView {
  static let viewType = "wolody/glass"

  static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(GlassViewFactory(), withId: viewType)
    registrar.register(
      GlassTabBarViewFactory(messenger: registrar.messenger()),
      withId: GlassTabBarView.viewType
    )
  }
}

private final class GlassTabBarViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    GlassTabBarView(frame: frame, messenger: messenger, args: args)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

private final class GlassTabBarView: NSObject, FlutterPlatformView {
  static let viewType = "wolody/glass_tab_bar"
  private let container: GlassTabBarContainer

  init(frame: CGRect, messenger: FlutterBinaryMessenger, args: Any?) {
    container = GlassTabBarContainer(frame: frame, messenger: messenger, args: args)
    super.init()
  }

  func view() -> UIView { container }
}

/// iOS 26 탭 바처럼 유리 레일은 하나만 두고, 선택 표시는 그 안의 반투명 캡슐로 그린다.
/// 유리 위에 유리를 겹치면 위쪽 유리가 아래 유리를 다시 굴절시켜 어둡고 탁한 원반처럼 보인다.
/// 누르고 있는 동안에만 캡슐 자리에 레일 밖으로 부풀어 오르는 유리 렌즈를 띄운다.
private final class GlassTabBarContainer: UIView {
  /// 눌렀을 때 렌즈가 선택 캡슐보다 커지는 폭(가로, 세로).
  private static let lensGrowth = CGSize(width: 14, height: 10)

  private let railView: UIVisualEffectView
  private let selectionView = UIView()
  private let lensView = UIVisualEffectView(effect: nil)
  private let channel: FlutterMethodChannel
  /// 렌즈가 부풀 자리를 위해 Dart가 레일보다 사방으로 이만큼 크게 깐 여백.
  private let overflow: CGFloat
  private var selectedIndex: Int
  private var position: Double
  private var isDragging = false
  private var isPressed = false

  init(frame: CGRect, messenger: FlutterBinaryMessenger, args: Any?) {
    let params = args as? [String: Any] ?? [:]
    selectedIndex = params["selectedIndex"] as? Int ?? 0
    position = params["position"] as? Double ?? Double(selectedIndex)
    isPressed = params["pressed"] as? Bool ?? false
    overflow = params["overflow"] as? CGFloat ?? 0
    channel = FlutterMethodChannel(
      name: params["channelName"] as? String ?? "wolody/glass_tab_bar",
      binaryMessenger: messenger
    )

    if #available(iOS 26.0, *) {
      railView = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
    } else {
      railView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemThinMaterialDark)
      )
    }

    super.init(frame: frame)
    backgroundColor = .clear
    isUserInteractionEnabled = false
    selectionView.backgroundColor = UIColor.label.withAlphaComponent(0.12)
    selectionView.layer.cornerCurve = .continuous
    addSubview(railView)
    railView.contentView.addSubview(selectionView)
    // 렌즈는 레일 밖으로 부풀어야 하므로 레일 안이 아니라 위에 둔다.
    addSubview(lensView)
    if #available(iOS 26.0, *) {
      railView.cornerConfiguration = .capsule()
      lensView.cornerConfiguration = .capsule()
    } else {
      railView.layer.cornerCurve = .continuous
      railView.clipsToBounds = true
      lensView.layer.cornerCurve = .continuous
      lensView.clipsToBounds = true
    }

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self,
            call.method == "setSelection",
            let args = call.arguments as? [String: Any] else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.isDragging = args["dragging"] as? Bool ?? false
      self.isPressed = args["pressed"] as? Bool ?? false
      self.selectedIndex = min(max(args["index"] as? Int ?? 0, 0), 2)
      self.position = args["position"] as? Double ?? Double(self.selectedIndex)
      self.updateFrames(animated: true)
      result(nil)
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("not supported") }

  override func layoutSubviews() {
    super.layoutSubviews()
    updateFrames(animated: false)
  }

  private var lensEffect: UIVisualEffect {
    if #available(iOS 26.0, *) {
      return UIGlassEffect(style: .clear)
    }
    return UIBlurEffect(style: .systemUltraThinMaterialLight)
  }

  private func updateFrames(animated: Bool) {
    let railFrame = bounds.insetBy(dx: overflow, dy: overflow)
    railView.frame = railFrame
    if #unavailable(iOS 26.0) {
      railView.layer.cornerRadius = railFrame.height / 2
    }

    let selectionArea = railView.bounds.insetBy(dx: 4, dy: 4)
    let itemWidth = selectionArea.width / 4
    // 드래그 중에는 손가락을 따라가는 위치, 평소에는 선택된 탭 위치를 쓴다.
    let current = isDragging ? position : Double(selectedIndex)
    let selectionFrame = CGRect(
      x: selectionArea.minX + CGFloat(min(max(current, 0), 2)) * itemWidth,
      y: selectionArea.minY,
      width: itemWidth,
      height: selectionArea.height
    )
    let restingLensFrame = selectionFrame.offsetBy(
      dx: railFrame.minX,
      dy: railFrame.minY
    )
    let lensFrame = isPressed
      ? restingLensFrame.insetBy(
          dx: -Self.lensGrowth.width,
          dy: -Self.lensGrowth.height
        )
      : restingLensFrame
    let showLens = isPressed
    let changes = {
      self.selectionView.frame = selectionFrame
      self.selectionView.layer.cornerRadius = selectionFrame.height / 2
      self.selectionView.alpha = showLens ? 0 : 1
      self.lensView.frame = lensFrame
      if #unavailable(iOS 26.0) {
        self.lensView.layer.cornerRadius = lensFrame.height / 2
      }
      // 같은 효과를 매번 다시 넣으면 드래그 중 유리가 깜빡이므로 바뀔 때만 넣는다.
      if (self.lensView.effect != nil) != showLens {
        self.lensView.effect = showLens ? self.lensEffect : nil
      }
    }
    guard animated, !isDragging else {
      changes()
      return
    }
    UIView.animate(
      withDuration: 0.36,
      delay: 0,
      usingSpringWithDamping: 0.72,
      initialSpringVelocity: 0.12,
      options: [.beginFromCurrentState, .allowUserInteraction],
      animations: changes
    )
  }
}

private final class GlassViewFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    GlassView(frame: frame, args: args)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

private final class GlassView: NSObject, FlutterPlatformView {
  private let container: GlassContainer

  init(frame: CGRect, args: Any?) {
    let params = args as? [String: Any] ?? [:]
    container = GlassContainer(
      frame: frame,
      isCapsule: params["capsule"] as? Bool ?? true,
      radius: params["radius"] as? CGFloat ?? 26,
      interactive: params["interactive"] as? Bool ?? true
    )
    super.init()
  }

  func view() -> UIView { container }
}

/// iOS 26의 Liquid Glass 스타일 UISwitch를 올려주는 플랫폼 뷰.
///
/// UISwitch는 iOS 26 SDK로 컴파일하면 시스템이 자동으로 새 유리 모양과
/// 상호작용(스위치 손잡이의 형태 변화)을 입혀 준다. 구형 OS에서는 기존
/// 시스템 스위치로 그려진다.
enum GlassSwitchPlatformView {
  static let viewType = "wolody/glass_switch"

  static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(
      GlassSwitchViewFactory(messenger: registrar.messenger()),
      withId: viewType
    )
  }
}

private final class GlassSwitchViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    GlassSwitchView(frame: frame, messenger: messenger, args: args)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

private final class GlassSwitchView: NSObject, FlutterPlatformView {
  private let container: UIView
  private let control: UISwitch
  private let channel: FlutterMethodChannel

  init(frame: CGRect, messenger: FlutterBinaryMessenger, args: Any?) {
    let params = args as? [String: Any] ?? [:]
    container = UIView(frame: frame)
    control = UISwitch()
    control.isOn = params["value"] as? Bool ?? false
    control.onTintColor = UIColor(
      red: 52.0 / 255.0,
      green: 106.0 / 255.0,
      blue: 230.0 / 255.0,
      alpha: 1
    )
    channel = FlutterMethodChannel(
      name: params["channelName"] as? String ?? "wolody/glass_switch",
      binaryMessenger: messenger
    )
    super.init()

    // UISwitch는 받은 프레임을 무시하고 고유 크기로 왼쪽 위에 붙는다. iOS 26의
    // 스위치는 예전(51pt)보다 넓어서 그대로 두면 오른쪽으로 삐져나와 카드 여백을
    // 먹는다. 컨테이너 오른쪽 끝·세로 가운데에 맞춰 Flutter 레이아웃 안에 둔다.
    control.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(control)
    NSLayoutConstraint.activate([
      control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      control.centerYAnchor.constraint(equalTo: container.centerYAnchor),
    ])

    // 사용자가 토글하면 Dart 상태를 바꾸고, 반영된 값은 setValue로 내려온다.
    control.addTarget(self, action: #selector(controlChanged), for: .valueChanged)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "setValue":
        let value = (call.arguments as? [String: Any])?["value"] as? Bool ?? false
        self?.control.setOn(value, animated: true)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @objc private func controlChanged() {
    channel.invokeMethod("onChanged", arguments: ["value": control.isOn])
  }

  func view() -> UIView { container }
}

private final class GlassContainer: UIView {
  private let effectView: UIVisualEffectView
  private let isCapsule: Bool
  private let radius: CGFloat

  init(frame: CGRect, isCapsule: Bool, radius: CGFloat, interactive: Bool) {
    self.isCapsule = isCapsule
    self.radius = radius

    if #available(iOS 26.0, *) {
      let glass = UIGlassEffect(style: .regular)
      // interactive를 켜면 눌림에 반응해 유리가 일렁인다.
      glass.isInteractive = interactive
      effectView = UIVisualEffectView(effect: glass)
    } else {
      // iOS 26 미만에서는 시스템 블러로 대체한다.
      effectView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemThinMaterial)
      )
    }

    super.init(frame: frame)

    backgroundColor = .clear
    isUserInteractionEnabled = false
    addSubview(effectView)
    applyShape()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("not supported") }

  override func layoutSubviews() {
    super.layoutSubviews()
    effectView.frame = bounds
    applyShape()
  }

  private func applyShape() {
    if #available(iOS 26.0, *) {
      effectView.cornerConfiguration = isCapsule
        ? .capsule()
        : .uniformCorners(radius: .fixed(radius))
    } else {
      effectView.layer.cornerRadius = isCapsule
        ? min(bounds.height, bounds.width) / 2
        : radius
      effectView.layer.cornerCurve = .continuous
      effectView.clipsToBounds = true
    }
  }
}
