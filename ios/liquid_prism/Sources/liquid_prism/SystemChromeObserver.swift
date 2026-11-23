import UIKit


/// System bar placement and reserved regions in the observed view’s coordinates.
public struct SystemChrome: Equatable, Sendable {
  /// A reserved region in the observed view's space.
  public struct Region: Equatable, Sendable {
    /// The region, including [margins] for interactive content.
    public var frame: CGRect
    public var margins: UIEdgeInsets
    public var active: Bool

    public init(frame: CGRect, margins: UIEdgeInsets = .zero, active: Bool = true) {
      self.frame = frame
      self.margins = margins
      self.active = active
    }
  }

  /// False before iOS 27.1, where neither API exists.
  public var supported: Bool
  /// The preferred vertical bar edge, even when disabled, or nil for horizontal bars.
  public var verticalBarEdge: UIRectEdge?
  /// Whether the app opted out with `LiquidPrismViewController`.
  public var verticalBarDisabled = false
  /// The view’s horizontal size class.
  public var horizontalSizeClass: UIUserInterfaceSizeClass = .unspecified
  public var verticalSizeClass: UIUserInterfaceSizeClass = .unspecified
  /// Regions covered by system UI, including inactive regions.
  public var occlusions: [Region]
  /// Regions content should divide around, such as the fold.
  public var divisions: [Region]
  /// The device’s Liquid Glass tint amount, or nil if unavailable.
  public var glassTintAmount: Double? = DeviceGlass.tintAmount
  /// Accessibility's Reduce Transparency, public on every iOS version.
  public var reduceTransparency: Bool = UIAccessibility.isReduceTransparencyEnabled
  /// The centred Dynamic Island in the view’s coordinates, or nil if absent.
  public var island: CGRect?
  /// A notch in the view's space: a sensor housing joined to the top edge.
  public var notch: CGRect?

  public static let unsupported = SystemChrome(
    supported: false, verticalBarEdge: nil, occlusions: [], divisions: [])

  @MainActor
  public init(view: UIView, verticalBarDisabled: Bool = false) {
    self.verticalBarDisabled = verticalBarDisabled
    switch SensorHousing.current(in: view) {
    case .island(let frame): island = frame
    case .notch(let frame): notch = frame
    case nil: break
    }
    horizontalSizeClass = view.traitCollection.horizontalSizeClass
    verticalSizeClass = view.traitCollection.verticalSizeClass
    #if canImport(UIKit, _version: 9127.0.85)
    guard #available(iOS 27.1, *) else {
      supported = false
      verticalBarEdge = nil
      occlusions = []
      divisions = []
      return
    }
    let rtl = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
    switch view.traitCollection.verticalBarEdge {
    case .leading: verticalBarEdge = rtl ? .right : .left
    case .trailing: verticalBarEdge = rtl ? .left : .right
    default: verticalBarEdge = nil
    }
    supported = true
    func regions(_ kind: UIView.ReservedRegion.Kind) -> [Region] {
      view.reservedRegions(kind: kind, options: .includeInactive).map {
        Region(frame: $0.frame, margins: $0.margins, active: $0.isActive)
      }
    }
    occlusions = regions(.occlusion)
    divisions = regions(.division)
    #else
    supported = false
    verticalBarEdge = nil
    occlusions = []
    divisions = []
    #endif
  }

  public init(
    supported: Bool,
    verticalBarEdge: UIRectEdge?,
    occlusions: [Region],
    divisions: [Region]
  ) {
    self.supported = supported
    self.verticalBarEdge = verticalBarEdge
    self.occlusions = occlusions
    self.divisions = divisions
  }

  private static func encode(_ rect: CGRect?) -> Any {
    guard let rect else { return NSNull() }
    return [Double(rect.minX), Double(rect.minY), Double(rect.width), Double(rect.height)]
  }

  private static func name(_ sizeClass: UIUserInterfaceSizeClass) -> Any {
    switch sizeClass {
    case .compact: "compact"
    case .regular: "regular"
    default: NSNull()
    }
  }

  /// The channel payload, with region frames, margins, and active flags.
  public var map: [String: Any] {
    func encode(_ region: Region) -> [Double] {
      let r = region.frame
      let m = region.margins
      return [
        Double(r.minX), Double(r.minY), Double(r.width), Double(r.height),
        Double(m.left), Double(m.top), Double(m.right), Double(m.bottom),
        region.active ? 1 : 0,
      ]
    }
    var edgeName: Any = NSNull()
    if verticalBarEdge == .left { edgeName = "left" }
    if verticalBarEdge == .right { edgeName = "right" }
    return [
      "supported": supported,
      "verticalBarEdge": edgeName,
      "verticalBarBehavior": verticalBarDisabled ? "disabled" : "automatic",
      "horizontalSizeClass": Self.name(horizontalSizeClass),
      "verticalSizeClass": Self.name(verticalSizeClass),
      "occlusions": occlusions.map(encode),
      "divisions": divisions.map(encode),
      "glassTintAmount": glassTintAmount.map { $0 as Any } ?? NSNull(),
      "reduceTransparency": reduceTransparency,
      "island": Self.encode(island),
      "notch": Self.encode(notch),
    ]
  }
}

/// Reports system chrome changes caused by layout, safe-area, and trait updates.
@MainActor
public final class SystemChromeObserver {
  public var onChange: ((SystemChrome) -> Void)?
  /// Reports the app's vertical bar opt-out, which UIKit's trait doesn't.
  public var verticalBarDisabled: (() -> Bool)?
  public private(set) var current: SystemChrome?
  private weak var view: UIView?
  private var sentinel: SentinelView?
  private var glassObservers: [NSObjectProtocol] = []

  public init() {
    let names = [
      DeviceGlass.didChange,
      UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      UIApplication.didBecomeActiveNotification,
    ]
    for name in names.compactMap({ $0 }) {
      glassObservers.append(
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
          [weak self] _ in
          Task { @MainActor in self?.refresh() }
        })
    }
  }

  deinit {
    for observer in glassObservers { NotificationCenter.default.removeObserver(observer) }
  }

  public func attach(to view: UIView) {
    if self.view === view {
      refresh()
      return
    }
    sentinel?.removeFromSuperview()
    let sentinel = SentinelView(frame: view.bounds)
    sentinel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    sentinel.isUserInteractionEnabled = false
    sentinel.onUpdate = { [weak self] in self?.refresh() }
    #if canImport(UIKit, _version: 9127.0.85)
    if #available(iOS 27.1, *) {
      sentinel.registerForTraitChanges(
        UITraitCollection.systemTraitsAffectingVerticalBarEdge
      ) { (view: SentinelView, _) in view.onUpdate?() }
    }
    #endif
    view.insertSubview(sentinel, at: 0)
    self.view = view
    self.sentinel = sentinel
    current = nil
    refresh()
  }

  public func detach() {
    sentinel?.removeFromSuperview()
    sentinel = nil
    view = nil
    current = nil
  }

  public func refresh() {
    guard let view else { return }
    let chrome = SystemChrome(view: view, verticalBarDisabled: verticalBarDisabled?() ?? false)
    guard chrome != current else { return }
    current = chrome
    onChange?(chrome)
  }
}

final class SentinelView: UIView {
  var onUpdate: (@MainActor () -> Void)?

  override func layoutSubviews() {
    super.layoutSubviews()
    onUpdate?()
  }

  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    onUpdate?()
  }
}
