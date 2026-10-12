import UIKit

/// Where the system places bar chrome around a view, from the iOS 27.1
/// vertical bar trait and reserved-region APIs. Coordinates are in the
/// observed view's space, which is Flutter's logical coordinate space.
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
  /// The physical edge of the vertical bar, or nil when the system uses
  /// horizontal bars here. UIKit reports the preferred edge even while the
  /// app has disabled the vertical bar; see [verticalBarDisabled].
  public var verticalBarEdge: UIRectEdge?
  /// Whether the app opted out with `LiquidPrismViewController`.
  public var verticalBarDisabled = false
  /// Regions covered by system UI, such as the status bar in the rail or the
  /// camera. Inactive regions are included with `active == false`.
  public var occlusions: [Region]
  /// Regions content should divide around, such as the fold.
  public var divisions: [Region]

  public static let unsupported = SystemChrome(
    supported: false, verticalBarEdge: nil, occlusions: [], divisions: [])

  @MainActor
  public init(view: UIView, verticalBarDisabled: Bool = false) {
    self.verticalBarDisabled = verticalBarDisabled
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

  /// The channel payload: regions are `[x, y, width, height, marginLeft,
  /// marginTop, marginRight, marginBottom, active]`.
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
      "occlusions": occlusions.map(encode),
      "divisions": divisions.map(encode),
    ]
  }
}

/// Reports [SystemChrome] for a view whenever it may have changed: layout,
/// safe-area and vertical-bar trait changes cover folding, rotation, resizing
/// and Split View. UIKit has no change notification for reserved regions.
@MainActor
public final class SystemChromeObserver {
  public var onChange: ((SystemChrome) -> Void)?
  /// Reports the app's vertical bar opt-out, which UIKit's trait doesn't.
  public var verticalBarDisabled: (() -> Bool)?
  public private(set) var current: SystemChrome?
  private weak var view: UIView?
  private var sentinel: SentinelView?

  public init() {}

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
    if #available(iOS 27.1, *) {
      sentinel.registerForTraitChanges(
        UITraitCollection.systemTraitsAffectingVerticalBarEdge
      ) { (view: SentinelView, _) in view.onUpdate?() }
    }
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

/// A transparent view that tracks its host's size and safe area.
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
