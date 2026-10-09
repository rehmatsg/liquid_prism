import Flutter
import UIKit

public final class LiquidPrismPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "dev.liquidprism/system", binaryMessenger: registrar.messenger())
        channel.setMethodCallHandler { call, result in
            if call.method == "appearanceVersion" {
                result(ProcessInfo.processInfo.operatingSystemVersion.majorVersion); return
            }
            guard call.method == "isSupported" else { result(FlutterMethodNotImplemented); return }
            if #available(iOS 26.0, *) { result(true) } else { result(false) }
        }
        registrar.register(GlassFactory(messenger: registrar.messenger()), withId: "dev.liquidprism/material")
    }
}

private final class GlassFactory: NSObject, FlutterPlatformViewFactory {
    let messenger: FlutterBinaryMessenger
    init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        GlassView(frame: frame, id: viewId, messenger: messenger, arguments: args as? [String: Any] ?? [:])
    }
}

private final class GlassView: NSObject, FlutterPlatformView {
    private let surface = GlassSurface()
    private let channel: FlutterMethodChannel
    init(frame: CGRect, id: Int64, messenger: FlutterBinaryMessenger, arguments: [String: Any]) {
        channel = FlutterMethodChannel(name: "dev.liquidprism/material/\(id)", binaryMessenger: messenger)
        super.init()
        surface.frame = frame
        surface.isUserInteractionEnabled = false
        surface.isAccessibilityElement = false
        surface.accessibilityElementsHidden = true
        surface.apply(arguments)
        channel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "update", let values = call.arguments as? [String: Any] else {
                result(FlutterMethodNotImplemented); return
            }
            self?.surface.apply(values)
            result(nil)
        }
    }
    func view() -> UIView { surface }
    deinit { channel.setMethodCallHandler(nil) }
}

private final class GlassSurface: UIView {
    private let effectView = UIVisualEffectView()
    private var radius: CGFloat = 10000
    private var circle = false
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(effectView)
        effectView.clipsToBounds = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func apply(_ values: [String: Any]) {
        radius = (values["radius"] as? NSNumber).map { CGFloat(truncating: $0) } ?? 10000
        circle = values["circle"] as? Bool ?? false
        effectView.layer.cornerCurve = values["smooth"] as? Bool == true ? .continuous : .circular
        overrideUserInterfaceStyle = values["dark"] as? Bool == true ? .dark : .light
        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect(style: values["clear"] as? Bool == true ? .clear : .regular)
            if let argb = values["tint"] as? NSNumber {
                let value = argb.uint32Value
                effect.tintColor = UIColor(red: CGFloat((value >> 16) & 255) / 255,
                    green: CGFloat((value >> 8) & 255) / 255,
                    blue: CGFloat(value & 255) / 255, alpha: CGFloat(value >> 24) / 255)
            }
            effectView.effect = effect
        }
        setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let side = min(bounds.width, bounds.height)
        effectView.frame = circle ? CGRect(x: (bounds.width-side)/2, y: (bounds.height-side)/2, width: side, height: side) : bounds
        effectView.layer.cornerRadius = min(radius, min(effectView.bounds.width, effectView.bounds.height)/2)
    }
}
