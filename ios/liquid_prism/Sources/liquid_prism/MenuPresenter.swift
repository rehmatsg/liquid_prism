import UIKit

/// Lifecycle events of one presented menu.
public enum MenuLifecycleEvent: Equatable, Sendable {
  case presented
  case dismissed
}

/// Presents one native menu at a time through an overlay anchor control.
@MainActor
public final class MenuPresenter {
  public init() {}

  /// Whether a menu is currently presented (or mid-presentation).
  public private(set) var isPresented = false

  /// Whether programmatic presentation is supported (iOS 17.4+).
  public static var isSupported: Bool {
    if #available(iOS 17.4, *) { return true }
    return false
  }

  private weak var control: MenuAnchorControl?
  private var actionHandler: (@MainActor (String) -> Void)?
  private var generation = 0

  private final class _Presentation {
    var presented = false
    var dismissed = false
  }

  /// Presents a menu with action and lifecycle callbacks; returns false if unsupported.
  @discardableResult
  public func present(
    _ spec: MenuSpec,
    at anchor: MenuAnchor,
    in host: UIView,
    onAction: @escaping @MainActor (String) -> Void,
    onLifecycle: @escaping @MainActor (MenuLifecycleEvent) -> Void
  ) -> Bool {
    guard #available(iOS 17.4, *) else { return false }

    generation += 1
    let gen = generation
    control?.contextMenuInteraction?.dismissMenu()
    control?.removeFromSuperview()

    let (controlFrame, attachment) = anchor.resolvedControl(in: host.bounds)
    let control = MenuAnchorControl(frame: controlFrame)
    control.attachmentUnitPoint = attachment
    actionHandler = onAction
    control.presentedMenu = MenuBuilder.menu(from: spec, onAction: onAction)
    let state = _Presentation()
    control.onWillPresent = { [weak self] in
      guard let self, self.generation == gen, !state.dismissed else { return }
      state.presented = true
      self.isPresented = true
      onLifecycle(.presented)
    }
    control.onWillDismiss = { [weak self, weak control] in
      guard let self, self.generation == gen, !state.dismissed else { return }
      state.dismissed = true
      self.isPresented = false
      onLifecycle(.dismissed)
      control?.removeFromSuperview()
    }

    host.addSubview(control)
    host.layoutIfNeeded()
    self.control = control

    DispatchQueue.main.async { [weak control] in
      control?.performPrimaryAction()
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak control] in
      guard let self, self.generation == gen, !state.presented, !state.dismissed else { return }
      state.dismissed = true
      control?.removeFromSuperview()
      if self.control === control { self.control = nil }
      onLifecycle(.dismissed)
    }
    return true
  }

  /// Dismisses the current menu, removing its anchor when dismissal finishes.
  public func dismiss() {
    control?.contextMenuInteraction?.dismissMenu()
  }

  /// Routes a test action through the current handler and dismisses the menu.
  public func debugSelect(_ actionId: String) {
    actionHandler?(actionId)
    dismiss()
  }
}

extension MenuAnchor {
  private static let rectGap: CGFloat = 6

  func resolvedControl(in container: CGRect) -> (frame: CGRect, attachment: CGPoint) {
    switch self {
    case .point(let point):
      return (
        CGRect(x: point.x - 0.5, y: point.y - 0.5, width: 1, height: 1),
        CGPoint(x: 0.5, y: 0.5)
      )
    case .rect(let rect):
      let below = rect.midY <= container.midY
      let strip = below
        ? CGRect(x: rect.minX, y: rect.maxY + Self.rectGap, width: rect.width, height: 1)
        : CGRect(x: rect.minX, y: rect.minY - Self.rectGap - 1, width: rect.width, height: 1)
      return (strip, CGPoint(x: 0.5, y: below ? 1 : 0))
    }
  }
}
