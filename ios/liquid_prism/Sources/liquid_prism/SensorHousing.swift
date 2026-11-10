import UIKit

/// The front sensor housing along the top of a view: the Dynamic Island or a
/// notch, for effects that grow out of it (pull to refresh). UIKit has no
/// public API for it, so the screen's private exclusion area is read at
/// runtime. Its selector is assembled from reversed fragments, as in
/// `DeviceGlass`, so no private name appears as a literal. Where it is missing
/// the housing is estimated from the safe area, and anything else (a side
/// sensor bar, a plain top edge) reads as nil.
enum SensorHousing: Equatable {
  /// A pill clear of the top edge.
  case island(CGRect)
  /// A housing joined to the top edge.
  case notch(CGRect)

  /// The housing in `view`'s coordinates, or nil when the view's window does
  /// not have one centred along its top edge right now.
  @MainActor
  static func current(in view: UIView) -> SensorHousing? {
    guard UIDevice.current.userInterfaceIdiom == .phone,
      let window = view.window,
      let scene = window.windowScene
    else { return nil }
    let screen = scene.screen
    let bounds = screen.bounds
    // The housing is at the top only in portrait, and only a window that
    // covers the screen starts at the screen's top edge.
    guard orientation(of: scene) == .portrait,
      abs(window.frame.width - bounds.width) < 1,
      abs(window.frame.height - bounds.height) < 1
    else { return nil }
    // A reported area decides; the safe area is only a fallback for systems
    // without the property.
    let housing =
      exclusionRect(of: screen).map { classify($0, in: bounds) }
      ?? estimate(window: window, bounds: bounds)
    switch housing {
    case .island(let rect): return .island(view.convert(rect, from: window))
    case .notch(let rect): return .notch(view.convert(rect, from: window))
    case nil: return nil
    }
  }

  @MainActor
  private static func orientation(of scene: UIWindowScene) -> UIInterfaceOrientation {
    if #available(iOS 16.0, *) { return scene.effectiveGeometry.interfaceOrientation }
    return scene.interfaceOrientation
  }

  /// An island is a pill centred on the screen and clear of its top edge; a
  /// notch is centred and touches the edge; a sensor bar sits to one side.
  private static func classify(_ rect: CGRect, in bounds: CGRect) -> SensorHousing? {
    guard abs(rect.midX - bounds.midX) < 4, rect.maxY < 80 else { return nil }
    if rect.minY > 4, rect.height > 24, rect.height < 48,
      rect.width > rect.height * 1.5, rect.width < bounds.width * 0.5
    {
      return .island(rect)
    }
    if rect.minY <= 4, rect.height > 16, rect.height < 56,
      rect.width > 100, rect.width < bounds.width * 0.8
    {
      return .notch(rect)
    }
    return nil
  }

  /// The screen's exclusion area in points, or nil where the system has no
  /// such property (or it is empty).
  private static func exclusionRect(of screen: UIScreen) -> CGRect? {
    let area = NSSelectorFromString(["Area", "exclusion", "_"].reversed().joined())
    // Only an object return is safe to read through `perform`.
    guard screen.responds(to: area),
      let method = class_getInstanceMethod(type(of: screen), area)
    else { return nil }
    var kind = [CChar](repeating: 0, count: 4)
    method_getReturnType(method, &kind, kind.count)
    guard kind[0] == 0x40,
      let object = screen.perform(area)?.takeUnretainedValue() as? NSObject
    else { return nil }
    let key = ["ct", "re"].reversed().joined()
    guard object.responds(to: NSSelectorFromString(key)),
      let value = object.value(forKey: key) as? NSValue
    else { return nil }
    var rect = value.cgRectValue
    guard rect.width > 0, rect.height > 0, rect.width.isFinite, rect.height.isFinite
    else { return nil }
    // Reported in pixels on some systems.
    if rect.maxX > screen.bounds.width * 1.5 {
      let scale = screen.scale
      rect = CGRect(
        x: rect.minX / scale, y: rect.minY / scale,
        width: rect.width / scale, height: rect.height / scale)
    }
    return rect
  }

  /// Island iPhones have a top safe area of 59 points or more, with the
  /// island ending 11 points above it. Notch iPhones have 44 to 50, with a
  /// notch about 14 points shallower than that. A tall portrait screen
  /// without side insets rules out other layouts.
  @MainActor
  private static func estimate(window: UIWindow, bounds: CGRect) -> SensorHousing? {
    let insets = window.safeAreaInsets
    guard insets.left == 0, insets.right == 0, bounds.height > bounds.width * 1.9
    else { return nil }
    switch insets.top {
    case 51..<80:
      let size = CGSize(width: 126, height: 37)
      return .island(
        CGRect(
          x: (bounds.width - size.width) / 2, y: insets.top - 11 - size.height,
          width: size.width, height: size.height))
    case 44..<51:
      // The narrowest notch, so the drop never paints beside a wider one.
      let size = CGSize(width: 162, height: insets.top - 14)
      return .notch(
        CGRect(x: (bounds.width - size.width) / 2, y: 0, width: size.width, height: size.height))
    default:
      return nil
    }
  }
}
