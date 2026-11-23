import UIKit

/// The native menu facade for presenting and dismissing menus.
@MainActor
public enum LiquidMenu {

  /// Whether programmatic native menus are supported (iOS 17.4+).
  public static var isSupported: Bool { MenuPresenter.isSupported }

  /// Whether a menu is currently up.
  public static var isPresented: Bool { presenter.isPresented }

  /// Presents `spec` in the key window; returns false if unsupported or no window exists.
  @discardableResult
  public static func present(
    _ spec: MenuSpec,
    at anchor: MenuAnchor,
    onAction: @escaping @MainActor (String) -> Void = { _ in },
    onLifecycle: @escaping @MainActor (MenuLifecycleEvent) -> Void = { _ in }
  ) -> Bool {
    guard Self.isSupported, MenuOverlayHost.shared.ensureInstalled(),
          let host = MenuOverlayHost.shared.hostView else {
      return false
    }
    return presenter.present(
      spec,
      at: anchor,
      in: host,
      onAction: onAction,
      onLifecycle: onLifecycle
    )
  }

  /// Dismisses the presented menu, if any.
  public static func dismiss() {
    presenter.dismiss()
  }

  private static let presenter = MenuPresenter()
}
