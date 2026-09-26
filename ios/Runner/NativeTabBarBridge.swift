import Flutter
import UIKit

/// iOS 26 전용 네이티브 Liquid Glass 하단 탭 바 브리지.
///
/// Flutter는 자체 렌더러로 그리기 때문에 Apple의 진짜 Liquid Glass 재질은
/// 네이티브 UIKit으로만 얻을 수 있다. iOS 26에서 `UITabBar`는 시스템이 자동으로
/// Liquid Glass 재질·떠 있는 모양·선택 캡슐을 입혀 주므로, 실제 `UITabBar`를
/// 플랫폼 뷰로 올리고 선택/기록 버튼 탭을 메서드 채널로 주고받는다.
enum NativeTabBarBridge {
  static let viewType = "today_mood/tab_bar"

  static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(
      NativeTabBarFactory(messenger: registrar.messenger()),
      withId: viewType
    )

    // Dart에서 iOS 주 버전을 읽어 26+일 때만 네이티브 바를 쓰도록 한다.
    let channel = FlutterMethodChannel(
      name: "today_mood/platform_info",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "getOsMajorVersion" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
    }
  }
}

private final class NativeTabBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    NativeTabBarView(frame: frame, args: args, messenger: messenger)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

private final class NativeTabBarView: NSObject, FlutterPlatformView {
  private let container: NativeBarContainer

  init(frame: CGRect, args: Any?, messenger: FlutterBinaryMessenger) {
    let params = args as? [String: Any] ?? [:]
    container = NativeBarContainer(
      frame: frame,
      args: params,
      channelName: params["channelName"] as? String ?? "today_mood/tab_bar",
      messenger: messenger
    )
    super.init()
  }

  func view() -> UIView { container }
}

private final class NativeBarContainer: UIView, UITabBarDelegate {
  private let tabBar = UITabBar()
  private let channel: FlutterMethodChannel
  private let primaryTint: UIColor

  private static let sideInset = 20.0
  // [+]는 캡슐의 4번째 아이템으로 들어간다.
  private static let addItemIndex = 3
  /// icons에 이 이름이 오면 SF Symbol 대신 프로필 사진을 동그랗게 그린다.
  private static let avatarIcon = "avatar"
  private static let defaultAvatarAsset = "assets/AssetsDesign/image 5.png"
  private static let avatarSize = CGSize(width: 26, height: 26)
  // [+]를 탭하면 선택 캡슐이 남지 않도록 이전 탭으로 되돌린다.
  private var lastTabIndex = 0

  init(
    frame: CGRect,
    args: [String: Any],
    channelName: String,
    messenger: FlutterBinaryMessenger
  ) {
    let titles = args["titles"] as? [String] ?? []
    let symbols = args["icons"] as? [String] ?? []
    let selectedIndex = args["selectedIndex"] as? Int ?? 0
    let tintARGB = args["tintColor"] as? Int ?? 0xFFC05050

    func color(from argb: Int) -> UIColor {
      let a = CGFloat((argb >> 24) & 0xFF) / 255
      let r = CGFloat((argb >> 16) & 0xFF) / 255
      let g = CGFloat((argb >> 8) & 0xFF) / 255
      let b = CGFloat(argb & 0xFF) / 255
      return UIColor(red: r, green: g, blue: b, alpha: a)
    }
    primaryTint = color(from: tintARGB)
    channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)

    super.init(frame: frame)

    backgroundColor = .clear

    // 앱은 항상 어두운 화면이므로 시스템이 라이트 모드여도 어두운 유리로 그린다.
    overrideUserInterfaceStyle = .dark

    var items: [UITabBarItem] = []
    for (index, title) in titles.enumerated() {
      let symbol = symbols.indices.contains(index) ? symbols[index] : "circle"
      let item = UITabBarItem(
        title: title,
        image: symbol == Self.avatarIcon ? nil : UIImage(systemName: symbol),
        tag: index
      )
      if symbol == Self.avatarIcon {
        Self.applyAvatar(
          to: item,
          path: args["avatarPath"] as? String,
          tint: primaryTint
        )
      }
      items.append(item)
    }
    // [+] 액션: 라벨 없이 아이콘만, 항상 강조 색으로 그린다.
    let addItem = UITabBarItem(
      title: nil,
      image: UIImage(systemName: "plus")?
        .withTintColor(primaryTint, renderingMode: .alwaysOriginal),
      tag: Self.addItemIndex
    )
    items.append(addItem)

    tabBar.setItems(items, animated: false)
    if selectedIndex < titles.count {
      lastTabIndex = selectedIndex
    }
    tabBar.selectedItem = items.indices.contains(selectedIndex)
      ? items[selectedIndex]
      : items.first
    tabBar.delegate = self
    configureAppearance()

    addSubview(tabBar)
    layout(tabBar: tabBar)

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "setAvatar":
        let path = (call.arguments as? [String: Any])?["path"] as? String
        if let self,
           let index = symbols.firstIndex(of: Self.avatarIcon),
           let item = self.tabBar.items?[index] {
          Self.applyAvatar(to: item, path: path, tint: self.primaryTint)
        }
        result(nil)
      case "setSelected":
        let index = (call.arguments as? [String: Any])?["index"] as? Int ?? 0
        if let items = self?.tabBar.items, items.indices.contains(index) {
          self?.tabBar.selectedItem = items[index]
          if index != Self.addItemIndex {
            self?.lastTabIndex = index
          }
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("not supported") }

  private func configureAppearance() {
    if #available(iOS 26.0, *) {
      // iOS 26에서는 시스템이 유리 재질·선택 캡슐을 자동으로 그린다.
      // appearance의 배경을 직접 지정하면 유리 재질이 벗겨질 수 있어
      // 아이템 색상만 조절한다.
      let appearance = UITabBarAppearance()
      let normal = appearance.stackedLayoutAppearance.normal
      normal.iconColor = .secondaryLabel
      normal.titleTextAttributes = [
        .foregroundColor: UIColor.secondaryLabel,
        .font: UIFont.systemFont(ofSize: 10),
      ]
      let selected = appearance.stackedLayoutAppearance.selected
      selected.iconColor = primaryTint
      selected.titleTextAttributes = [
        .foregroundColor: primaryTint,
        .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
      ]
      tabBar.standardAppearance = appearance
      tabBar.scrollEdgeAppearance = appearance
    } else {
      // 구형 OS 근사치: 둥근 모서리 캡슐 + 시스템 머티리얼.
      tabBar.layer.cornerRadius = 26
      tabBar.layer.cornerCurve = .continuous
      tabBar.layer.masksToBounds = true
    }
    tabBar.itemPositioning = .centered
  }

  /// 프로필 사진(없으면 기본 울디)을 원형으로 잘라 탭 아이콘으로 쓴다.
  /// 원본 색을 유지해야 하므로 템플릿이 아닌 원본 이미지로 넣고,
  /// 선택됐을 때는 강조 색 테두리를 둘러 선택 상태를 알 수 있게 한다.
  private static func applyAvatar(to item: UITabBarItem, path: String?, tint: UIColor) {
    let photo = path.flatMap { UIImage(contentsOfFile: $0) }
    // lookupKey는 앱 번들 기준 상대 경로(Frameworks/App.framework/flutter_assets/...)이고,
    // Flutter는 에셋 파일명을 퍼센트 인코딩해 담는다("image 5.png" → "image%205.png").
    let key = FlutterDartProject.lookupKey(forAsset: defaultAvatarAsset)
    let fallback = [key, key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)]
      .compactMap { $0 }
      .lazy
      .compactMap { UIImage(contentsOfFile: Bundle.main.bundlePath + "/" + $0) }
      .first
    guard let source = photo ?? fallback else { return }
    // 기본 울디 이미지는 배경이 투명하므로 앱과 같은 밝은 원 위에 올린다.
    let backdrop = photo == nil
      ? UIColor(red: 0xE9 / 255, green: 0xEC / 255, blue: 0xF3 / 255, alpha: 1)
      : nil
    item.image = circularAvatar(source, backdrop: backdrop, ring: nil)
    item.selectedImage = circularAvatar(source, backdrop: backdrop, ring: tint)
  }

  private static func circularAvatar(
    _ source: UIImage,
    backdrop: UIColor?,
    ring: UIColor?
  ) -> UIImage {
    let rect = CGRect(origin: .zero, size: avatarSize)
    let image = UIGraphicsImageRenderer(size: avatarSize).image { context in
      context.cgContext.saveGState()
      UIBezierPath(ovalIn: rect).addClip()
      if let backdrop {
        backdrop.setFill()
        context.fill(rect)
      }
      // 가운데를 기준으로 원을 가득 채우도록(aspect fill) 그린다.
      let scale = max(
        rect.width / source.size.width,
        rect.height / source.size.height
      )
      let drawSize = CGSize(
        width: source.size.width * scale,
        height: source.size.height * scale
      )
      source.draw(in: CGRect(
        x: (rect.width - drawSize.width) / 2,
        y: (rect.height - drawSize.height) / 2,
        width: drawSize.width,
        height: drawSize.height
      ))
      context.cgContext.restoreGState()
      if let ring {
        ring.setStroke()
        let border = UIBezierPath(ovalIn: rect.insetBy(dx: 0.75, dy: 0.75))
        border.lineWidth = 1.5
        border.stroke()
      }
    }
    return image.withRenderingMode(.alwaysOriginal)
  }

  private func layout(tabBar: UITabBar) {
    tabBar.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      tabBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.sideInset),
      tabBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.sideInset),
      tabBar.topAnchor.constraint(equalTo: topAnchor),
      tabBar.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    if item.tag == Self.addItemIndex {
      // [+] 액션: 선택 캡슐이 남지 않게 이전 탭으로 되돌린다.
      if let items = tabBar.items, items.indices.contains(lastTabIndex) {
        tabBar.selectedItem = items[lastTabIndex]
      }
      channel.invokeMethod("onAdd", arguments: nil)
    } else {
      lastTabIndex = item.tag
      channel.invokeMethod("onSelect", arguments: ["index": item.tag])
    }
  }

}
