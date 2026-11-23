import Flutter
import UIKit



extension UIColor {
  convenience init(argb: Int) {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    self.init(red: r, green: g, blue: b, alpha: a)
  }
}


extension MenuIcon {
  init?(wire value: Any?) {
    guard let map = value as? [String: Any],
          let kind = map["kind"] as? String else { return nil }
    switch kind {
    case "sfSymbol":
      guard let name = map["name"] as? String else { return nil }
      let palette = (map["palette"] as? [NSNumber])?.map { UIColor(argb: $0.intValue) } ?? []
      self = .sfSymbol(
        SFSymbolIcon(
          name: name,
          weight: map.enumValue("weight"),
          scale: map.enumValue("scale"),
          renderingMode: map.enumValue("renderingMode", default: .automatic),
          palette: palette
        )
      )
    case "image":
      guard let bytes = (map["bytes"] as? FlutterStandardTypedData)?.data,
            let image = UIImage(data: bytes) else { return nil }
      self = .image(image, templated: map.bool("templated", default: false))
    default:
      return nil
    }
  }
}


extension MenuAnchor {
  init?(wire value: Any?) {
    guard let map = value as? [String: Any],
          let type = map["type"] as? String else { return nil }
    switch type {
    case "point":
      guard let x = map.cgFloat("x"), let y = map.cgFloat("y") else { return nil }
      self = .point(CGPoint(x: x, y: y))
    case "rect":
      guard let x = map.cgFloat("x"), let y = map.cgFloat("y"),
            let w = map.cgFloat("width"), let h = map.cgFloat("height") else { return nil }
      self = .rect(CGRect(x: x, y: y, width: w, height: h))
    default:
      return nil
    }
  }
}


extension MenuOptions {
  init(wire map: [String: Any]) {
    self.init(
      isDestructive: map.bool("destructive", default: false),
      singleSelection: map.bool("singleSelection", default: false),
      displayAsPalette: map.bool("palette", default: false)
    )
  }
}

extension MenuAction {
  init?(wire map: [String: Any]) {
    guard let id = map["id"] as? String,
          let title = map["title"] as? String else { return nil }
    self.init(
      id: id,
      title: title,
      image: MenuIcon(wire: map["icon"]),
      state: map.enumValue("state", default: .off),
      isDestructive: map.bool("destructive", default: false),
      isDisabled: map.bool("disabled", default: false),
      isHidden: map.bool("hidden", default: false),
      keepsMenuPresented: map.bool("keepsMenuPresented", default: false),
      discoverabilityTitle: map["discoverabilityTitle"] as? String
    )
  }
}

extension MenuElement {
  static func wire(
    _ value: Any?,
    deferred makeDeferred: (String) -> MenuDeferred
  ) -> MenuElement? {
    guard let map = value as? [String: Any],
          let type = map["type"] as? String else { return nil }
    switch type {
    case "action":
      return MenuAction(wire: map).map { .action($0) }
    case "submenu":
      return (map["menu"] as? [String: Any])
        .flatMap { MenuSpec(wire: $0, deferred: makeDeferred) }
        .map { .submenu($0) }
    case "section":
      return (map["menu"] as? [String: Any])
        .flatMap { MenuSpec(wire: $0, deferred: makeDeferred) }
        .map { .section($0) }
    case "divider":
      return .divider
    case "deferred":
      return (map["id"] as? String).map { .deferred(makeDeferred($0)) }
    default:
      return nil
    }
  }
}

extension MenuSpec {
  init?(wire value: Any?, deferred makeDeferred: (String) -> MenuDeferred) {
    guard let map = value as? [String: Any] else { return nil }
    self.init(
      title: map["title"] as? String ?? "",
      image: MenuIcon(wire: map["image"]),
      identifier: map["identifier"] as? String,
      options: MenuOptions(wire: (map["options"] as? [String: Any]) ?? [:]),
      preferredElementSize: map.enumValue("elementSize", default: .automatic),
      children: ((map["items"] as? [Any]) ?? []).compactMap {
        MenuElement.wire($0, deferred: makeDeferred)
      }
    )
  }
}
