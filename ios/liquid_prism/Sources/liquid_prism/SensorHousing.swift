import UIKit

enum SensorHousing: Equatable {
  case island(CGRect)
  case notch(CGRect)

  @MainActor
  static func current(in view: UIView) -> SensorHousing? {
    guard UIDevice.current.userInterfaceIdiom == .phone,
      let window = view.window,
      let scene = window.windowScene
    else { return nil }
    let screen = scene.screen
    let bounds = screen.bounds
    guard orientation(of: scene) == .portrait,
      abs(window.frame.width - bounds.width) < 1,
      abs(window.frame.height - bounds.height) < 1
    else { return nil }
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

  private static func exclusionRect(of screen: UIScreen) -> CGRect? {
    let area = NSSelectorFromString(["Area", "exclusion", "_"].reversed().joined())
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
    if rect.maxX > screen.bounds.width * 1.5 {
      let scale = screen.scale
      rect = CGRect(
        x: rect.minX / scale, y: rect.minY / scale,
        width: rect.width / scale, height: rect.height / scale)
    }
    return rect
  }

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
      let size = CGSize(width: 162, height: insets.top - 14)
      return .notch(
        CGRect(x: (bounds.width - size.width) / 2, y: 0, width: size.width, height: size.height))
    default:
      return nil
    }
  }
}
