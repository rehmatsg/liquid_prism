import UIKit

/// Where the system places bar chrome around a view, from the iOS 27.1
/// vertical bar trait and reserved-region APIs. Coordinates are in the
/// observed view's space, which is Flutter's logical coordinate space.
public struct SystemChrome: Equatable, Sendable {
  public struct Division: Equatable, Sendable {
    /// The region, including its margins for interactive content.
    public var frame: CGRect
    public var margins: UIEdgeInsets
  }

  /// False before iOS 27.1, where neither API exists.
  public var supported: Bool
  /// The physical edge of the vertical bar, or nil when the system uses
  /// horizontal bars here.
  public var verticalBarEdge: UIRectEdge?
  /// Active regions occluded by system UI, such as the status bar in the rail.
  public var occlusions: [CGRect]
  /// Active regions content should divide around, such as a partial fold.
  public var divisions: [Division]

  public static let unsupported = SystemChrome(
    supported: false, verticalBarEdge: nil, occlusions: [], divisions: [])

  @MainActor
  public init(view: UIView) {
    guard #available(iOS 27.1, *) else {
      self = .unsupported
      return
    }
    let rtl = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
    switch view.traitCollection.verticalBarEdge {
    case .leading: verticalBarEdge = rtl ? .right : .left
    case .trailing: verticalBarEdge = rtl ? .left : .right
    default: verticalBarEdge = nil
    }
    supported = true
    occlusions = view.reservedRegions(kind: .occlusion)
      .filter(\.isActive)
      .map(\.frame)
    divisions = view.reservedRegions(kind: .division)
      .filter(\.isActive)
      .map { Division(frame: $0.frame, margins: $0.margins) }
  }

  public init(
    supported: Bool,
    verticalBarEdge: UIRectEdge?,
    occlusions: [CGRect],
    divisions: [Division]
  ) {
    self.supported = supported
    self.verticalBarEdge = verticalBarEdge
    self.occlusions = occlusions
    self.divisions = divisions
  }

  /// The channel payload.
  public var map: [String: Any] {
    func rect(_ r: CGRect) -> [Double] {
      [Double(r.minX), Double(r.minY), Double(r.width), Double(r.height)]
    }
    var edgeName: Any = NSNull()
    if verticalBarEdge == .left { edgeName = "left" }
    if verticalBarEdge == .right { edgeName = "right" }
    return [
      "supported": supported,
      "verticalBarEdge": edgeName,
      "occlusions": occlusions.map(rect),
      "divisions": divisions.map { division in
        rect(division.frame) + [
          Double(division.margins.left), Double(division.margins.top),
          Double(division.margins.right), Double(division.margins.bottom),
        ]
      },
    ]
  }
}

/// Reports [SystemChrome] for a view whenever it may have changed: layout,
/// safe-area and vertical-bar trait changes cover folding, rotation, resizing
/// and Split View. UIKit has no change notification for reserved regions.
@MainActor
public final class SystemChromeObserver {
  public var onChange: ((SystemChrome) -> Void)?
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
    let chrome = SystemChrome(view: view)
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
