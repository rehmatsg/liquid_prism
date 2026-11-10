import Flutter
import SwiftUI
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LiquidPrismBench") {
      BenchChannel.register(registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LiquidPrismParity") {
      ParityChannel.register(registrar.messenger())
    }
  }
}

/// Research only, for lib/parity_main.dart (tool/glass_parity): SwiftUI
/// `glassEffect(.regular)` shapes in a non-interactive hosting view above the
/// Flutter view, so native glass samples Flutter's backdrop. Also reads the
/// device glass tint amount through private UIKit API and dumps the native
/// glass layers' filter inputs.
enum ParityChannel {
  private static var channel: FlutterMethodChannel?
  private static var host: UIViewController?
  private static var status: UIView?
  private static var observers: [NSObjectProtocol] = []
  private static let everyImage = UnsafeMutableRawPointer(bitPattern: -2)

  /// `UIViewGlassGetTintAmount` returns an NSNumber (see TintSweep.swift).
  static var amount: NSNumber? {
    guard let pointer = dlsym(everyImage, "UIViewGlassGetTintAmount") else { return nil }
    let getter = unsafeBitCast(pointer, to: (@convention(c) () -> Unmanaged<AnyObject>?).self)
    return getter()?.takeUnretainedValue() as? NSNumber
  }

  static let changeName: Notification.Name? = {
    guard let pointer = dlsym(everyImage, "UIViewGlassTintAmountDidChangeNotification") else { return nil }
    let name = pointer.assumingMemoryBound(to: Unmanaged<NSString>?.self).pointee
    return name.map { Notification.Name($0.takeUnretainedValue() as String) }
  }()

  static var documents: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("parity")
  }

  static func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "liquid_prism/parity", binaryMessenger: messenger)
    self.channel = channel
    for name in [changeName, UIApplication.didBecomeActiveNotification].compactMap({ $0 }) {
      observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { note in
        channel.invokeMethod("amountChanged", arguments: [
          "amount": amount ?? NSNull(), "reason": note.name.rawValue,
        ])
      })
    }
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "info":
        try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        result([
          "amount": amount ?? NSNull(),
          "arguments": ProcessInfo.processInfo.arguments,
          "documents": documents.path,
          "os": ProcessInfo.processInfo.operatingSystemVersionString,
          "model": UIDevice.current.model,
          "notification": changeName?.rawValue ?? NSNull(),
        ])
      case "show":
        show(rects: args["rects"] as? [[Double]] ?? [], dark: args["dark"] as? Bool ?? false,
             generation: args["generation"] as? Int ?? 0)
        result(nil)
      case "status":
        setStatus(args["label"] as? String ?? "")
        result(nil)
      case "dump":
        result(dump(name: args["name"] as? String ?? "filters"))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static var window: UIWindow? {
    let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
    return windows.first(where: \.isKeyWindow) ?? windows.first
  }

  /// rects: [x, y, width, height, cornerRadius, capsule (0/1)] in the window's points.
  private static func show(rects: [[Double]], dark: Bool, generation: Int) {
    guard let window, let root = window.rootViewController else { return }
    let content: AnyView
    if #available(iOS 26.0, *) {
      content = AnyView(ParityGlass(rects: rects).id(generation))
    } else {
      content = AnyView(Color.clear)
    }
    let controller: UIHostingController<AnyView>
    if let existing = host as? UIHostingController<AnyView> {
      controller = existing
      controller.rootView = content
    } else {
      controller = UIHostingController(rootView: content)
      if #available(iOS 16.4, *) { controller.safeAreaRegions = [] }
      root.addChild(controller)
      controller.view.frame = root.view.bounds
      controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      controller.view.backgroundColor = .clear
      controller.view.isUserInteractionEnabled = false
      root.view.addSubview(controller.view)
      controller.didMove(toParent: root)
      host = controller
    }
    let style: UIUserInterfaceStyle = dark ? .dark : .light
    controller.overrideUserInterfaceStyle = style
    controller.view.overrideUserInterfaceStyle = style
  }

  /// A 2-pt accessibility element (outside the measured regions) that UI tests
  /// poll; it lives in the window because Flutter's view replaces its own
  /// accessibility children with the semantics tree.
  private static func setStatus(_ label: String) {
    guard let window else { return }
    if status == nil {
      let view = UIView(frame: CGRect(x: window.bounds.width - 4, y: window.bounds.height - 4, width: 2, height: 2))
      view.isAccessibilityElement = true
      view.accessibilityIdentifier = "parity-status"
      view.isUserInteractionEnabled = false
      window.addSubview(view)
      status = view
    }
    status?.accessibilityLabel = label
    status?.accessibilityValue = label
  }

  /// Writes every native glass layer's filters (inputs discovered from the
  /// filter's keyed archive, as tool/native_dispersion_probe's Extractor.m).
  private static func dump(name: String) -> String? {
    guard let view = host?.view, let window else { return nil }
    var layers: [[String: Any]] = []
    func encode(_ value: Any) -> Any {
      if let number = value as? NSNumber { return number.doubleValue.isFinite ? number : "nonfinite" }
      if let string = value as? String { return string }
      if let array = value as? [Any] { return array.map(encode) }
      if CFGetTypeID(value as CFTypeRef) == CGColor.typeID {
        return (value as! CGColor).components?.map(Double.init) ?? []
      }
      return String(describing: value)
    }
    func keys(_ object: Any, _ found: inout Set<String>) {
      if let string = object as? String, string.hasPrefix("input") { found.insert(string) }
      if let array = object as? [Any] { for item in array { keys(item, &found) } }
      if let dict = object as? [String: Any] { for (k, v) in dict { keys(k, &found); keys(v, &found) } }
    }
    func walk(_ layer: CALayer, _ path: String) {
      let shown = layer.presentation() ?? layer
      let filters = (shown.filters ?? []).compactMap { $0 as? NSObject }.map { filter -> [String: Any] in
        var found = Set<String>()
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: filter, requiringSecureCoding: false),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) { keys(plist, &found) }
        var inputs: [String: Any] = [:]
        for key in found { if let value = filter.value(forKey: key) { inputs[key] = encode(value) } }
        return ["name": filter.value(forKey: "name").map(encode) ?? "", "inputs": inputs]
      }
      if !filters.isEmpty {
        let frame = layer.convert(layer.bounds, to: window.layer)
        layers.append(["path": path, "class": NSStringFromClass(type(of: layer)),
          "delegate": layer.delegate.map { NSStringFromClass(type(of: $0)) } ?? "",
          "win": [frame.minX, frame.minY, frame.width, frame.height], "filters": filters])
      }
      for (i, sublayer) in (layer.sublayers ?? []).enumerated() { walk(sublayer, "\(path)/\(i)") }
    }
    walk(view.layer, "host")
    let record: [String: Any] = [
      "name": name, "tintAmount": amount ?? NSNull(), "style": view.traitCollection.userInterfaceStyle == .dark ? "dark" : "light",
      "os": ProcessInfo.processInfo.operatingSystemVersionString, "scale": Double(window.screen.scale), "layers": layers,
    ]
    let url = documents.appendingPathComponent("\(name).json")
    try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
    guard let data = try? JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]),
      (try? data.write(to: url)) != nil
    else { return nil }
    return url.path
  }
}

@available(iOS 26.0, *)
private struct ParityGlass: View {
  let rects: [[Double]]

  var body: some View {
    ZStack(alignment: .topLeading) {
      Color.clear
      ForEach(rects.indices, id: \.self) { i in
        let r = rects[i]
        Group {
          if r[5] != 0 {
            Color.clear.frame(width: r[2], height: r[3])
              .glassEffect(.regular, in: Capsule(style: .continuous))
          } else {
            Color.clear.frame(width: r[2], height: r[3])
              .glassEffect(.regular, in: RoundedRectangle(cornerRadius: r[4], style: .continuous))
          }
        }
        .offset(x: r[0], y: r[1])
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .ignoresSafeArea()
    .allowsHitTesting(false)
  }
}

/// Device telemetry for lib/bench_main.dart: keeps the screen awake at a fixed
/// brightness and reports thermal state, battery and process CPU time.
enum BenchChannel {
  static func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "liquid_prism/bench", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setup":
        let args = call.arguments as? [String: Any]
        UIApplication.shared.isIdleTimerDisabled = true
        UIDevice.current.isBatteryMonitoringEnabled = true
        if let brightness = args?["brightness"] as? Double {
          for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.screen.brightness = brightness
          }
        }
        result(nil)
      case "stats":
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        let cpu = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1e6
          + Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1e6
        var brightness = -1.0
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
          brightness = Double(scene.screen.brightness)
        }
        UIApplication.shared.isIdleTimerDisabled = true
        result([
          "thermal": ProcessInfo.processInfo.thermalState.rawValue,
          "battery": Double(UIDevice.current.batteryLevel),
          "batteryState": UIDevice.current.batteryState.rawValue,
          "lowPower": ProcessInfo.processInfo.isLowPowerModeEnabled,
          "cpu": cpu,
          "brightness": brightness,
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
