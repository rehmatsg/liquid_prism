import UIKit

// Development-only presentation-layer measurements. The native components
// render themselves; this recorder never changes their geometry or animation.
final class LensMotionRecorder: NSObject {
    private weak var host: UIView?
    private var link: CADisplayLink?
    private var start = CACurrentMediaTime()
    private var frames: [[String: Any]] = []
    private let name: String
    init(host: UIView, name: String) {
        self.host = host; self.name = name
        super.init()
        let link = CADisplayLink(target: self, selector: #selector(sample))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common); self.link = link
    }
    deinit { link?.invalidate() }
    @objc private func sample() {
        guard let window = host?.window else { return }
        var lenses: [[String: Any]] = []
        func visit(_ node: UIView, owner: String) {
            let kind = NSStringFromClass(type(of: node))
            let owner = ["Switch", "Slider", "SegmentedControl", "TabBar"].first(where: { kind.contains($0) }) ?? owner
            if kind == "_UILiquidLensView" {
                let p = node.layer.presentation() ?? node.layer
                let rect = p.convert(p.bounds, to: window.layer.presentation() ?? window.layer)
                let t = p.transform
                lenses.append(["owner": owner, "frame": [rect.minX, rect.minY, rect.width, rect.height],
                    "bounds": [p.bounds.width, p.bounds.height], "alpha": p.opacity,
                    "transform": [t.m11, t.m12, t.m21, t.m22, t.m41, t.m42]])
            }
            for child in node.subviews { visit(child, owner: owner) }
        }
        visit(window, owner: "")
        frames.append(["t": CACurrentMediaTime() - start, "lenses": lenses])
        if frames.count % 60 == 0 { save() }
        if CACurrentMediaTime() - start > 45 { link?.invalidate(); link = nil; save() }
    }
    private func save() {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("motion-\(name).json")
        if let data = try? JSONSerialization.data(withJSONObject: ["frames": frames, "name": name, "maxFPS": 60]) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
