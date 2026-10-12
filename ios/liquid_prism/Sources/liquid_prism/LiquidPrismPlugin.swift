import Flutter
import UIKit

/// Thin bridge between Flutter and the native menu presenter. Decodes
/// method-channel arguments into `MenuSpec`s, drives `MenuPresenter`, and
/// streams lifecycle events back over the event channel. Flutter invokes
/// channel handlers on the main thread, so UI is touched directly (no actor
/// hop).
///
/// Everything it presents with comes from the `LiquidMenu` core package; this
/// target adds only the channel plumbing and the wire format.
public class LiquidPrismPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var methods: FlutterMethodChannel?

  /// The presenter lives on the plugin instance — one per engine. Created
  /// lazily: `MenuPresenter` is main-actor-isolated and the plugin's own
  /// initializer is not.
  private var _presenter: MenuPresenter?

  @MainActor
  private var presenter: MenuPresenter {
    if let _presenter { return _presenter }
    let created = MenuPresenter()
    _presenter = created
    return created
  }

  /// Streams the system's bar placement for the Flutter view.
  private var systemChrome: SystemChromeStreamHandler?

  /// The menuId currently bound to `presenter` callbacks. A stale dismissal
  /// from a replaced menu must not be reported as the new menu's.
  private var currentMenuId: String?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methods = FlutterMethodChannel(name: "liquid_prism/menus", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(name: "liquid_prism/menus/events", binaryMessenger: registrar.messenger())
    let instance = LiquidPrismPlugin()
    instance.methods = methods
    registrar.addMethodCallDelegate(instance, channel: methods)
    events.setStreamHandler(instance)
    let chrome = SystemChromeStreamHandler(registrar: registrar)
    instance.systemChrome = chrome
    FlutterEventChannel(name: "liquid_prism/system_chrome", binaryMessenger: registrar.messenger())
      .setStreamHandler(chrome)
    FlutterMethodChannel(name: "liquid_prism/system", binaryMessenger: registrar.messenger())
      .setMethodCallHandler { [weak chrome] call, result in
        MainActor.assumeIsolated {
          guard let chrome else { return result(FlutterMethodNotImplemented) }
          chrome.handle(call, result: result)
        }
      }
    // Menus belong to the window showing this engine's Flutter view, and
    // close when that window resizes, as UIKit menus do (iPhone Duo folds,
    // Split View, Stage Manager).
    MainActor.assumeIsolated {
      let host = MenuOverlayHost.shared
      host.preferredWindow = { [weak registrar] in registrar?.viewController?.view.window }
      host.onResize = { [weak instance] in instance?.presenter.dismiss() }
      // Install the overlay eagerly so the first menu can anchor immediately.
      host.ensureInstalled()
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    MainActor.assumeIsolated {
      route(call, result: result)
    }
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    MainActor.assumeIsolated {
      presenter.dismiss()
      eventSink = nil
      methods = nil
    }
  }

  @MainActor
  private func route(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]

    switch call.method {
    case "handshake":
      // Fresh Dart isolate: drop any menu state left over from a hot restart.
      presenter.dismiss()
      currentMenuId = nil
      MenuOverlayHost.shared.ensureInstalled()
      result([
        "capabilities": ["nativeMenu": MenuPresenter.isSupported]
      ])

    case "show":
      MenuOverlayHost.shared.ensureInstalled()
      guard let menuId = args?.string("menuId"),
            let anchor = MenuAnchor(wire: args?["anchor"]),
            let menuMap = args?["menu"] as? [String: Any],
            let spec = MenuSpec(
              wire: menuMap,
              deferred: { [weak self] id in self?.makeDeferred(id, menuId: menuId) ?? MenuDeferred(id: id) { [] } }
            )
      else {
        result(FlutterError(code: "INVALID_ARGS", message: "show: missing menuId/anchor/menu", details: nil))
        return
      }
      guard let host = MenuOverlayHost.shared.hostView else {
        result(["accepted": false, "menuId": menuId, "reason": "no_window"])
        return
      }

      currentMenuId = menuId
      switch menuMap["appearance"] as? String {
      case "dark": host.overrideUserInterfaceStyle = .dark
      case "light": host.overrideUserInterfaceStyle = .light
      default: host.overrideUserInterfaceStyle = .unspecified
      }
      let accepted = presenter.present(
        spec,
        at: anchor,
        in: host,
        onAction: { [weak self] actionId in
          self?.emit(["event": "action", "menuId": menuId, "actionId": actionId])
        },
        onLifecycle: { [weak self] event in
          self?.emit([
            "event": event == .presented ? "presented" : "dismissed",
            "menuId": menuId,
          ])
          if event == .dismissed { self?.currentMenuId = nil }
        }
      )
      result(["accepted": accepted, "menuId": menuId])

    case "dismiss":
      let wasPresented = presenter.isPresented
      presenter.dismiss()
      result(["dismissed": wasPresented])

    case "debugSelect":
      // Testing hook — see MenuPresenter.debugSelect.
      let actionId = (call.arguments as? [String: Any])?["actionId"] as? String ?? ""
      presenter.debugSelect(actionId)
      result(nil)

    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func emit(_ map: [String: Any]) {
    eventSink?(map)
  }

  /// A deferred element's provider round-trips to Dart: the wire element
  /// carries only an id; Dart resolves its children at display time.
  private func makeDeferred(_ id: String, menuId: String) -> MenuDeferred {
    MenuDeferred(id: id) { [methods] in
      guard let methods else { return [] }
      let reply = await withCheckedContinuation { (cont: CheckedContinuation<Any?, Never>) in
        methods.invokeMethod("resolveDeferred", arguments: ["menuId": menuId, "id": id]) { value in
          cont.resume(returning: value)
        }
      }
      guard let list = reply as? [Any] else { return [] }
      return list.compactMap {
        MenuElement.wire($0, deferred: { [weak self] id in
          self?.makeDeferred(id, menuId: menuId) ?? MenuDeferred(id: id) { [] }
        })
      }
    }
  }

  // MARK: - FlutterStreamHandler

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

/// Streams [SystemChrome] for the engine's Flutter view on
/// `liquid_prism/system_chrome`, and applies preferences sent on
/// `liquid_prism/system`. The view may not exist when Dart listens, so
/// attaching retries briefly.
final class SystemChromeStreamHandler: NSObject, FlutterStreamHandler {
  private weak var registrar: (any FlutterPluginRegistrar)?
  private var sink: FlutterEventSink?
  private var observer: SystemChromeObserver?

  init(registrar: any FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    MainActor.assumeIsolated { attach(attempt: 0) }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    MainActor.assumeIsolated {
      observer?.detach()
      observer = nil
    }
    return nil
  }

  @MainActor
  func handle(_ call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "setVerticalBarBehavior":
      // Applies only where UIKit has a vertical bar and the app opted into
      // the view controller that can report a preference.
      guard #available(iOS 27.1, *),
        let controller = registrar?.viewController as? LiquidPrismViewController
      else {
        result(false)
        return
      }
      let args = call.arguments as? [String: Any]
      controller.verticalBarDisabled = (args?["behavior"] as? String) == "disabled"
      observer?.refresh()
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @MainActor
  private func attach(attempt: Int) {
    guard sink != nil else { return }
    guard let view = registrar?.viewController?.view else {
      if attempt < 50 {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
          MainActor.assumeIsolated { self?.attach(attempt: attempt + 1) }
        }
      }
      return
    }
    let observer = self.observer ?? SystemChromeObserver()
    observer.onChange = { [weak self] chrome in self?.sink?(chrome.map) }
    observer.verticalBarDisabled = { [weak self] in
      (self?.registrar?.viewController as? LiquidPrismViewController)?.verticalBarDisabled ?? false
    }
    self.observer = observer
    observer.attach(to: view)
  }
}
