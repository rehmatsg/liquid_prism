import UIKit

/// Turns `MenuSpec` trees into `UIMenu`/`UIAction` hierarchies.
public enum MenuBuilder {

  /// Builds the menu tree, calling `onAction` on every tap, including repeated taps.
  public static func menu(
    from spec: MenuSpec,
    onAction: @escaping @MainActor (String) -> Void
  ) -> UIMenu {
    let menu = UIMenu(
      title: spec.title,
      image: spec.image?.resolved,
      identifier: spec.identifier.map { UIMenu.Identifier(rawValue: $0) },
      options: spec.options.uiKit,
      children: elements(from: spec.children, onAction: onAction)
    )
    if #available(iOS 16.0, *) {
      menu.preferredElementSize = spec.preferredElementSize.uiKit
    }
    return menu
  }

  static func elements(
    from children: [MenuElement],
    onAction: @escaping @MainActor (String) -> Void
  ) -> [UIMenuElement] {
    var out: [UIMenuElement] = []
    var run: [UIMenuElement] = []
    func flushRun() {
      guard !run.isEmpty else { return }
      out.append(UIMenu(options: .displayInline, children: run))
      run = []
    }
    for child in children {
      switch child {
      case .action(let action):
        run.append(self.action(action, onAction: onAction))
      case .submenu(let spec):
        run.append(submenu(spec, onAction: onAction))
      case .deferred(let deferred):
        run.append(self.deferred(deferred, onAction: onAction))
      case .section(let spec):
        flushRun()
        out.append(section(spec, onAction: onAction))
      case .divider:
        flushRun()
      }
    }
    flushRun()
    return out
  }

  static func action(
    _ spec: MenuAction,
    onAction: @escaping @MainActor (String) -> Void
  ) -> UIAction {
    var attributes: UIMenuElement.Attributes = []
    if spec.isDestructive { attributes.insert(.destructive) }
    if spec.isDisabled { attributes.insert(.disabled) }
    if spec.isHidden { attributes.insert(.hidden) }
    if #available(iOS 16.0, *), spec.keepsMenuPresented {
      attributes.insert(.keepsMenuPresented)
    }
    return UIAction(
      title: spec.title,
      image: spec.image?.resolved,
      identifier: UIAction.Identifier(rawValue: spec.id),
      discoverabilityTitle: spec.discoverabilityTitle,
      attributes: attributes,
      state: spec.state.uiKit
    ) { _ in
      MainActor.assumeIsolated { onAction(spec.id) }
    }
  }

  static func submenu(
    _ spec: MenuSpec,
    onAction: @escaping @MainActor (String) -> Void
  ) -> UIMenu {
    menu(from: spec, onAction: onAction)
  }

  static func section(
    _ spec: MenuSpec,
    onAction: @escaping @MainActor (String) -> Void
  ) -> UIMenu {
    let menu = UIMenu(
      title: spec.title,
      image: spec.image?.resolved,
      identifier: spec.identifier.map { UIMenu.Identifier(rawValue: $0) },
      options: spec.options.uiKit.union(.displayInline),
      children: elements(from: spec.children, onAction: onAction)
    )
    if #available(iOS 16.0, *) {
      menu.preferredElementSize = spec.preferredElementSize.uiKit
    }
    return menu
  }

  static func deferred(
    _ spec: MenuDeferred,
    onAction: @escaping @MainActor (String) -> Void
  ) -> UIMenuElement {
    UIDeferredMenuElement.uncached { completion in
      Task { @MainActor in
        do {
          completion(elements(from: try await spec.provider(), onAction: onAction))
        } catch {
          completion([])
        }
      }
    }
  }
}


extension MenuOptions {
  var uiKit: UIMenu.Options {
    var options: UIMenu.Options = []
    if isDestructive { options.insert(.destructive) }
    if singleSelection { options.insert(.singleSelection) }
    if #available(iOS 17.0, *), displayAsPalette {
      options.insert(.displayAsPalette)
    }
    return options
  }
}

extension MenuElementSize {
  @available(iOS 16.0, *)
  var uiKit: UIMenu.ElementSize {
    switch self {
    case .automatic:
      if #available(iOS 17.0, *) { return .automatic }
      return .medium
    case .small: return .small
    case .medium: return .medium
    case .large: return .large
    }
  }
}

extension MenuElementState {
  var uiKit: UIMenuElement.State {
    switch self {
    case .off: return .off
    case .on: return .on
    case .mixed: return .mixed
    }
  }
}

extension SymbolWeight {
  var uiKit: UIImage.SymbolWeight {
    switch self {
    case .ultraLight: return .ultraLight
    case .thin: return .thin
    case .light: return .light
    case .regular: return .regular
    case .medium: return .medium
    case .semibold: return .semibold
    case .bold: return .bold
    case .heavy: return .heavy
    case .black: return .black
    }
  }
}

extension SymbolScale {
  var uiKit: UIImage.SymbolScale {
    switch self {
    case .small: return .small
    case .medium: return .medium
    case .large: return .large
    }
  }
}

extension MenuIcon {
  var resolved: UIImage? {
    switch self {
    case .sfSymbol(let symbol):
      var config: UIImage.SymbolConfiguration?
      func apply(_ other: UIImage.SymbolConfiguration) {
        config = (config ?? UIImage.SymbolConfiguration(scale: .unspecified)).applying(other)
      }
      if let weight = symbol.weight {
        apply(UIImage.SymbolConfiguration(weight: weight.uiKit))
      }
      if let scale = symbol.scale {
        apply(UIImage.SymbolConfiguration(scale: scale.uiKit))
      }
      switch symbol.renderingMode {
      case .automatic:
        break
      case .monochrome:
        if #available(iOS 16.0, *) { apply(.preferringMonochrome()) }
      case .multicolor:
        apply(.preferringMulticolor())
      case .palette:
        if !symbol.palette.isEmpty {
          apply(UIImage.SymbolConfiguration(paletteColors: symbol.palette))
        }
      case .hierarchical:
        if let base = symbol.palette.first {
          apply(UIImage.SymbolConfiguration(hierarchicalColor: base))
        }
      }
      return UIImage(systemName: symbol.name, withConfiguration: config)
    case .image(let image, let templated):
      return templated ? image.withRenderingMode(.alwaysTemplate) : image
    }
  }
}
