import SwiftUI
import UIKit

struct GeometryKey: PreferenceKey {
    static var defaultValue: [String: [Double]] = [:]
    static func reduce(value: inout [String: [Double]], nextValue: () -> [String: [Double]]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
extension View {
    func measure(_ name: String) -> some View {
        background {
            GeometryReader { proxy in
                let r = proxy.frame(in: .global)
                Color.clear.preference(key: GeometryKey.self, value: [name: [r.minX, r.minY, r.width, r.height]])
            }
        }
    }
}
@Observable final class GeometryStore {
    static let shared = GeometryStore()
    var frames: [String: [Double]] = [:]
    var scrollTarget: String?
}

// Opt-in development instrumentation. No private API calls or app dependencies.
// The command file allows the comparison runner to select identical app states.
struct InspectionHost: UIViewRepresentable {
    let model: ShowcaseModel
    func makeUIView(context: Context) -> UIView {
        let view = UIView(); view.isUserInteractionEnabled = false
        context.coordinator.start(view)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) { context.coordinator.model = model }
    func makeCoordinator() -> Coordinator { Coordinator(model) }
    final class Coordinator {
        var model: ShowcaseModel
        private var timer: Timer?
        private weak var view: UIView?
        private var modified: Date?
        private var snapshotName = "latest"
        private var motion: LensMotionRecorder?
        private let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        init(_ model: ShowcaseModel) { self.model = model }
        deinit { timer?.invalidate() }
        func start(_ view: UIView) {
            self.view = view
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "--motion"), args.count > i + 1 {
                motion = LensMotionRecorder(host: view, name: args[i + 1])
            }
            guard ProcessInfo.processInfo.arguments.contains("--inspect") else { return }
            modified = (try? FileManager.default.attributesOfItem(atPath:
                documents.appendingPathComponent("command.json").path))?[.modificationDate] as? Date
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.tick() }
        }
        private func tick() {
            let commandURL = documents.appendingPathComponent("command.json")
            if let attributes = try? FileManager.default.attributesOfItem(atPath: commandURL.path),
               let date = attributes[.modificationDate] as? Date, date != modified,
               let data = try? Data(contentsOf: commandURL),
               let command = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                modified = date
                if let dark = command["dark"] as? Bool { model.dark = dark }
                if let accent = command["accent"] as? String { model.accent = accent }
                if let tab = command["tab"] as? Int { model.tab = tab; model.path = [] }
                if let screen = command["screen"] as? String {
                    if let kind = ComponentKind(rawValue: screen) { model.path = [kind] }
                    else { model.path = []; model.tab = ["explore", "studio", "library"].firstIndex(of: screen) ?? 0 }
                }
                if let query = command["query"] as? String { model.query = query }
                if let frost = command["frost"] as? Double { model.frost = frost }
                if let level = command["level"] as? Double { model.level = level }
                if let scroll = command["scroll"] as? String {
                    GeometryStore.shared.scrollTarget = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { GeometryStore.shared.scrollTarget = scroll }
                }
                if let name = command["snapshot"] as? String { snapshotName = name }
                view?.window?.endEditing(true)
            }
            guard let window = view?.window else { return }
            var views: [[String: Any]] = []
            var sliderLayers: [[String: Any]] = []
            func rgba(_ color: UIColor?) -> [Double]? {
                guard let color else { return nil }
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                guard color.resolvedColor(with: window.traitCollection).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
                return [r, g, b, a]
            }
            func visit(_ node: UIView, path: String) {
                let name = NSStringFromClass(type(of: node)), rect = node.convert(node.bounds, to: window)
                let presentation = node.layer.presentation()
                var record: [String: Any] = ["class": name, "path": path,
                    "frame": [rect.minX, rect.minY, rect.width, rect.height],
                    "bounds": [node.bounds.width, node.bounds.height],
                    "hidden": node.isHidden, "alpha": node.alpha,
                    "cornerRadius": node.layer.cornerRadius,
                    "shadow": [node.layer.shadowOpacity, Float(node.layer.shadowRadius), Float(node.layer.shadowOffset.width), Float(node.layer.shadowOffset.height)]]
                if let color = rgba(node.backgroundColor) { record["background"] = color }
                if let id = node.accessibilityIdentifier { record["id"] = id }
                if let label = node.accessibilityLabel { record["label"] = label }
                if let label = node as? UILabel {
                    record["text"] = label.text; record["fontSize"] = label.font.pointSize
                    record["textColor"] = rgba(label.textColor)
                }
                if let image = node as? UIImageView, let size = image.image?.size { record["imageSize"] = [size.width, size.height] }
                if let control = node as? UIControl { record["enabled"] = control.isEnabled }
                if node is UISlider {
                    func layers(_ layer: CALayer, path: String) {
                        var info: [String: Any] = ["class": NSStringFromClass(type(of: layer)),
                            "name": layer.name ?? "", "path": path,
                            "bounds": [layer.bounds.width, layer.bounds.height],
                            "position": [layer.position.x, layer.position.y], "hidden": layer.isHidden]
                        if let color = layer.backgroundColor { info["background"] = rgba(UIColor(cgColor: color)) }
                        if let delegate = layer.delegate { info["delegate"] = NSStringFromClass(type(of: delegate)) }
                        sliderLayers.append(info)
                        for (i, child) in (layer.sublayers ?? []).enumerated() { layers(child, path: "\(path)/\(i)") }
                    }
                    layers(node.layer, path: path)
                }
                if let presentation { record["presentationBounds"] = [presentation.bounds.width, presentation.bounds.height]; record["presentationPosition"] = [presentation.position.x, presentation.position.y] }
                if name.contains("Switch") || name.contains("Slider") || name.contains("Segment") || name.contains("TabBar") || name.contains("Glass") || name.contains("Lens") || name.contains("Loupe") || name.contains("Search") || name.contains("Button") || node is UILabel || node is UIImageView { views.append(record) }
                for (i, child) in node.subviews.enumerated() { visit(child, path: "\(path)/\(i)") }
            }
            visit(window, path: "window")
            let result: [String: Any] = ["screen": [window.bounds.width, window.bounds.height], "scale": window.windowScene?.screen.scale ?? 1,
                "safeArea": [window.safeAreaInsets.top, window.safeAreaInsets.left, window.safeAreaInsets.bottom, window.safeAreaInsets.right],
                "dark": model.dark, "accent": model.accent, "tab": model.tab,
                "systemTextScale": UIFont.preferredFont(forTextStyle: .body).pointSize / 17,
                "contentSizeCategory": window.traitCollection.preferredContentSizeCategory.rawValue,
                "fontProText": UIFont(name: ".SF Pro Text", size: 38)?.fontName ?? "unavailable",
                "fonts": [".SFUIText-Semibold", ".SFUI-Semibold", "SFProText-Semibold", "HelveticaNeue-Medium"].map { name in
                    let font = UIFont(name: name, size: 38) ?? UIFont.systemFont(ofSize: 38, weight: .semibold)
                    return ["requested": name, "actual": font.fontName,
                        "width": ("A lot of possibility." as NSString).size(withAttributes: [.font: font, .kern: -1.8]).width] as [String: Any]
                },
                "level": model.level, "sliderLayers": sliderLayers,
                "path": model.path.map(\.rawValue), "geometry": GeometryStore.shared.frames, "views": views]
            if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: documents.appendingPathComponent("\(snapshotName).json"), options: .atomic)
            }
        }
    }
}
