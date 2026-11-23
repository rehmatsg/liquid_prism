import UIKit

/// Owns the shared transparent overlay used to anchor menus in the app window.
@MainActor
public final class MenuOverlayHost {
  public static let shared = MenuOverlayHost()

  /// The anchor container, available after installation in an existing window.
  public private(set) var hostView: UIView?

  /// The preferred Flutter window, used before searching connected scenes.
  public var preferredWindow: (@MainActor () -> UIWindow?)?

  /// Called when the host window changes size so an anchored menu can close.
  public var onResize: (@MainActor () -> Void)?

  private var observersAdded = false

  private init() {}

  /// Ensures the overlay is installed, retrying when a window becomes available.
  @discardableResult
  public func ensureInstalled() -> Bool {
    addObserversIfNeeded()
    let target = preferredWindow?() ?? Self.activeWindow()
    if let host = hostView, host.window != nil, target == nil || host.window === target {
      return true
    }
    guard let root = target?.rootViewController else {
      if hostView != nil { return true }
      DispatchQueue.main.async { [weak self] in
        guard let self, self.hostView == nil else { return }
        if (self.preferredWindow?() ?? Self.activeWindow())?.rootViewController != nil {
          self.ensureInstalled()
        }
      }
      return false
    }
    hostView?.removeFromSuperview()
    install(in: root)
    return true
  }

  private func install(in root: UIViewController) {
    let host = MenuHostView()
    host.onResize = { [weak self] in self?.onResize?() }
    host.isUserInteractionEnabled = false
    host.backgroundColor = .clear
    host.translatesAutoresizingMaskIntoConstraints = false
    root.view.addSubview(host)

    NSLayoutConstraint.activate([
      host.topAnchor.constraint(equalTo: root.view.topAnchor),
      host.bottomAnchor.constraint(equalTo: root.view.bottomAnchor),
      host.leadingAnchor.constraint(equalTo: root.view.leadingAnchor),
      host.trailingAnchor.constraint(equalTo: root.view.trailingAnchor),
    ])

    hostView = host
  }

  func bringToFront() {
    guard let host = hostView, let superview = host.superview else { return }
    superview.bringSubviewToFront(host)
  }

  /// Returns a key window, preferring the foreground-active scene.
  public static func activeWindow() -> UIWindow? {
    let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = windowScenes.first { $0.activationState == .foregroundActive }
      ?? windowScenes.first { $0.activationState == .foregroundInactive }
      ?? windowScenes.first
    guard let scene else { return nil }
    return scene.windows.first { $0.isKeyWindow } ?? scene.windows.first
  }

  private func addObserversIfNeeded() {
    guard !observersAdded else { return }
    observersAdded = true
    NotificationCenter.default.addObserver(
      forName: UIScene.didActivateNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return }
        if self.hostView == nil { self.ensureInstalled() } else { self.bringToFront() }
      }
    }
  }
}

final class MenuHostView: UIView {
  var onResize: (@MainActor () -> Void)?
  private var laidOutSize: CGSize?

  override func layoutSubviews() {
    super.layoutSubviews()
    let size = bounds.size
    defer { laidOutSize = size }
    if let previous = laidOutSize, previous != size, previous != .zero {
      onResize?()
    }
  }
}
