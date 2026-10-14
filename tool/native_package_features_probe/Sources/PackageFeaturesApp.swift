import SwiftUI
import UIKit

@main
struct PackageFeaturesApp: App {
    var body: some Scene { WindowGroup {
        if ProcessInfo.processInfo.arguments.contains("--toolbar") {
            ToolbarBadgeScene()
        } else if let mode = NavProbe.mode {
            NavProbeScene(mode: mode)
        } else { Fixture() }
    } }
}
struct Fixture: View {
    @State private var segment = 0
    @State private var selection = 0
    private var tabCount: Int {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--tabs"), i + 1 < args.count, let n = Int(args[i + 1]) { return n }
        return 3
    }
    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Unframed segmented Picker")
                        Picker("Range", selection: $segment) {
                            Text("Short").tag(0)
                            Text("A wider label").tag(1)
                        }.pickerStyle(.segmented)
                        Text("Intrinsic segmented Picker (fixedSize, no frame)")
                        Picker("Intrinsic range", selection: $segment) {
                            Text("Short").tag(0)
                            Text("A wider label").tag(1)
                        }.pickerStyle(.segmented).fixedSize(horizontal: true, vertical: false)
                        Text("Unframed First/Second/Third")
                        Picker("Three", selection: $segment) {
                            Text("First").tag(0)
                            Text("Second").tag(1)
                            Text("Third").tag(2)
                        }.pickerStyle(.segmented)
                        Text("Intrinsic First/Second/Third (fixedSize)")
                        Picker("Three intrinsic", selection: $segment) {
                            Text("First").tag(0)
                            Text("Second").tag(1)
                            Text("Third").tag(2)
                        }.pickerStyle(.segmented).fixedSize(horizontal: true, vertical: false)
                        ForEach(0..<80) { row in
                            Text("Row \(row): title collapse calibration").frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }.padding(.horizontal, 16)
                }
                .navigationTitle("Feature Measurements")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {} label: { Image(systemName: "chevron.left") }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {} label: { Image(systemName: "bell.badge") }
                    }
                }
            }
            .tabItem { Image(systemName: "tray") }.badge(125).tag(0)
            Text("Second").tabItem { Image(systemName: "star") }.badge(" ").tag(1)
            Text("Third").tabItem { Image(systemName: "person") }.badge(7).tag(2)
            if tabCount >= 4 { Text("Fourth").tabItem { Image(systemName: "gear") }.badge(42).tag(3) }
            if tabCount >= 5 { Text("Fifth").tabItem { Image(systemName: "magnifyingglass") }.badge(1000).tag(4) }
        }
        .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--dark") ? .dark : .light)
        .task {
            // Direct view/layer samples during UI-test swipes. These are
            // observations, not a reconstruction of UIKit's animation law.
            FrameSampler.shared.start()
            for sample in 0..<160 {
                try? await Task.sleep(for: .milliseconds(100))
                await MainActor.run { Measurement.write(sample) }
            }
        }
    }
}
// JSONSerialization raises an Objective-C exception (not a Swift error) on NaN
// or infinity, which aborts the app; replace non-finite numbers with null.
func jsonSafe(_ value: Any) -> Any {
    switch value {
    case let d as Double: return d.isFinite ? d : NSNull()
    case let f as CGFloat: return f.isFinite ? Double(f) : NSNull()
    case let f as Float: return f.isFinite ? Double(f) : NSNull()
    case let a as [Any]: return a.map(jsonSafe)
    case let m as [String: Any]: return m.mapValues(jsonSafe)
    default: return value
    }
}
@MainActor enum Measurement {
    static func frame(_ rect: CGRect) -> [Double] { [rect.origin.x, rect.origin.y, rect.width, rect.height].map(Double.init) }
    static func rgba(_ color: UIColor, _ traits: UITraitCollection) -> [CGFloat] {
        let color = color.resolvedColor(with: traits)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a]
    }
    static func write(_ sample: Int) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var records: [[String: Any]] = []
        func visit(_ view: UIView, window: UIWindow) {
            var row: [String: Any] = ["class": NSStringFromClass(type(of: view)), "frame": frame(view.convert(view.bounds, to: window)), "hidden": view.isHidden,
                "alpha": view.alpha, "layerOpacity": view.layer.opacity,
                "backgroundRGBA": view.backgroundColor.map { rgba($0, view.traitCollection) } ?? [],
                "layerBackgroundComponents": view.layer.backgroundColor?.components ?? [],
                "presentationOpacity": view.layer.presentation()?.opacity ?? view.layer.opacity]
            row["cornerRadius"] = Double(view.layer.cornerRadius)
            row["cornerCurve"] = view.layer.cornerCurve.rawValue
            row["masksToBounds"] = view.layer.masksToBounds || view.clipsToBounds
            let viewLayers = Set(view.subviews.map { ObjectIdentifier($0.layer) })
            // Non-view sublayers, recursively (toolbar badges are bare layers).
            func layerRow(_ layer: CALayer, depth: Int) -> [String: Any] {
                var r: [String: Any] = ["class": NSStringFromClass(type(of: layer)), "frame": frame(window.layer.convert(layer.bounds, from: layer)),
                 "cornerRadius": Double(layer.cornerRadius), "cornerCurve": layer.cornerCurve.rawValue, "opacity": Double(layer.opacity),
                 "backgroundComponents": layer.backgroundColor?.components ?? [], "hasContents": layer.contents != nil]
                if let text = layer as? CATextLayer {
                    r["string"] = (text.string as? String) ?? (text.string as? NSAttributedString)?.string ?? ""
                    r["fontSize"] = Double(text.fontSize)
                    if let attributed = text.string as? NSAttributedString, attributed.length > 0 {
                        let attrs = attributed.attributes(at: 0, effectiveRange: nil)
                        if let font = attrs[.font] as? UIFont { r["fontName"] = font.fontName; r["attrFontSize"] = Double(font.pointSize) }
                        if let color = attrs[.foregroundColor] as? UIColor { r["textRGBA"] = rgba(color, view.traitCollection) }
                    }
                }
                if depth < 4 { r["sublayers"] = (layer.sublayers ?? []).map { layerRow($0, depth: depth + 1) } }
                return r
            }
            row["sublayers"] = (view.layer.sublayers ?? []).filter { !viewLayers.contains(ObjectIdentifier($0)) }.map { layerRow($0, depth: 0) }
            if let image = view as? UIImageView, let img = image.image {
                row["imageSize"] = [Double(img.size.width), Double(img.size.height)]
                row["imageDescription"] = String(describing: img).prefix(300).description
            }
            if let label = view as? UILabel {
                row["text"] = label.text ?? ""
                row["fontName"] = label.font.fontName
                row["fontSize"] = label.font.pointSize
                let color = label.textColor.resolvedColor(with: view.traitCollection)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                color.getRed(&r, green: &g, blue: &b, alpha: &a)
                row["textRGBA"] = [r, g, b, a]
                row["numberOfLines"] = label.numberOfLines
                row["lineBreakMode"] = label.lineBreakMode.rawValue
                row["textAlignment"] = label.textAlignment.rawValue
                row["intrinsicSize"] = [Double(label.intrinsicContentSize.width), Double(label.intrinsicContentSize.height)]
                row["fontWeightTrait"] = ((label.font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any])?[.weight] as? Double) ?? NSNull()
                row["fontTextStyle"] = (label.font.fontDescriptor.object(forKey: .textStyle) as? String) ?? ""
            }
            if let scroll = view as? UIScrollView {
                row["scrollOffset"] = [scroll.contentOffset.x, scroll.contentOffset.y]
                row["adjustedInset"] = [scroll.adjustedContentInset.top, scroll.adjustedContentInset.bottom]
            }
            if let presentation = view.layer.presentation() {
                row["presentationFrameInParent"] = frame(presentation.frame)
            }
            records.append(row)
            view.subviews.forEach { visit($0, window: window) }
        }
        for scene in scenes { for window in scene.windows { visit(window, window: window) } }
        let screen = scenes.first?.screen
        let packet: [String: Any] = ["sample": sample, "uptime": ProcessInfo.processInfo.systemUptime,
            "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "screenPoints": screen.map { frame($0.bounds) } ?? [], "dpr": screen?.scale ?? 0, "launchArguments": ProcessInfo.processInfo.arguments,
            "contentSizeCategory": scenes.first?.traitCollection.preferredContentSizeCategory.rawValue ?? "unknown", "views": records]
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("measurements")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let safe = jsonSafe(packet)
        if JSONSerialization.isValidJSONObject(safe), let data = try? JSONSerialization.data(withJSONObject: safe, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: directory.appendingPathComponent(String(format: "%03d.json", sample)))
        }
    }
}

// Public UIKit badge API, distinct from an SF Symbol with a badge drawn in it.
struct ToolbarBadgeScene: View {
    var body: some View {
        ToolbarBadgeFixture()
            .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--dark") ? .dark : .light)
            .task {
                for sample in 0..<100 {
                    try? await Task.sleep(for: .milliseconds(100))
                    await MainActor.run { Measurement.write(sample) }
                }
            }
    }
}
struct ToolbarBadgeFixture: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UINavigationController {
        let root = UIViewController()
        root.view.backgroundColor = .systemBackground
        root.title = "Toolbar badge measurements"
        let indicator = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal.decrease"), style: .plain, target: nil, action: nil)
        indicator.badge = .indicator()
        let count = UIBarButtonItem(image: UIImage(systemName: "envelope"), style: .plain, target: nil, action: nil)
        count.badge = .count(125)
        let one = UIBarButtonItem(image: UIImage(systemName: "bell"), style: .plain, target: nil, action: nil)
        one.badge = .count(7)
        let two = UIBarButtonItem(image: UIImage(systemName: "tray"), style: .plain, target: nil, action: nil)
        two.badge = .count(42)
        let big = UIBarButtonItem(image: UIImage(systemName: "person"), style: .plain, target: nil, action: nil)
        big.badge = .count(1000)
        root.navigationItem.rightBarButtonItems = [count, indicator]
        root.navigationItem.leftBarButtonItems = [one, two, big]
        let navigation = UINavigationController(rootViewController: root)
        return navigation
    }
    func updateUIViewController(_ controller: UINavigationController, context: Context) {}
}

// Per-frame samples of the navigation title labels and the scroll offset, for
// collapse timing. Direct observations only; opacity is the product of the
// presentation opacities of the label and all its ancestors.
@MainActor final class FrameSampler: NSObject {
    static let shared = FrameSampler()
    private var link: CADisplayLink?
    private var rows: [[String: Any]] = []
    private var lastFlush = 0.0
    func start() {
        guard link == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }
    @objc func tick(_ link: CADisplayLink) {
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first?.windows.first else { return }
        // Sheet top edge (presentation layer) for presented-controller cases.
        var sheets: [[Double]] = []
        var labels: [[String: Any]] = []
        var offsets: [Double] = []
        func visit(_ view: UIView) {
            if let scroll = view as? UIScrollView, scroll.bounds.height > 300 { offsets.append(Double(scroll.contentOffset.y)) }
            if NSStringFromClass(type(of: view)).contains("DropShadowView"), let l = view.layer.presentation() {
                let r = window.layer.convert(l.bounds, from: l); sheets.append([r.origin.x, r.origin.y, r.width, r.height].map(Double.init))
            }
            if let label = view as? UILabel, let text = label.text, NavProbe.trackedTexts.contains(text) {
                var opacity: Float = 1
                var modelOpacity: Float = 1
                var hidden = false
                var v: UIView? = label
                while let cur = v { opacity *= cur.layer.presentation()?.opacity ?? cur.layer.opacity; modelOpacity *= cur.layer.opacity; hidden = hidden || cur.isHidden; v = cur.superview }
                let pf = label.layer.presentation().map { l -> [Double] in
                    let r = window.layer.convert(l.bounds, from: l); return [r.origin.x, r.origin.y, r.width, r.height].map(Double.init)
                } ?? []
                let mf = label.convert(label.bounds, to: window)
                labels.append(["text": text, "fontName": label.font.fontName, "fontSize": Double(label.font.pointSize), "opacity": Double(opacity), "modelOpacity": Double(modelOpacity), "hidden": hidden,
                               "frame": [mf.origin.x, mf.origin.y, mf.width, mf.height].map(Double.init), "presentationWindowFrame": pf])
            }
            view.subviews.forEach(visit)
        }
        visit(window)
        rows.append(["t": link.timestamp, "offsets": offsets, "titles": labels, "sheets": sheets])
        if link.timestamp - lastFlush > 1 {
            lastFlush = link.timestamp
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("measurements")
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let safe = jsonSafe(rows)
            if JSONSerialization.isValidJSONObject(safe), let data = try? JSONSerialization.data(withJSONObject: safe, options: []) {
                try? data.write(to: directory.appendingPathComponent("frames.json"))
            }
        }
    }
}

// Navigation subtitle and sheet navigation-bar fixtures (--nav <mode>).
// Modes: subtitleInline, subtitleLarge, subtitleLong, sheetLarge, sheetMedium,
// sheetMediumIndicator, sheetLargeIndicator, sheetLargeTitle, sheetMediumLargeTitle.
enum NavProbe {
    static var mode: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--nav"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    static let longTitle = "Feature Measurements With A Very Long Navigation Title"
    static let longSubtitle = "Amazon Web Services Marketplace Order Details And More"
    static let trackedTexts: Set<String> = ["Feature Measurements", "Amazon", "Sheet Title", longTitle, longSubtitle]
}
struct StripeRows: View {
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(0..<80) { row in
                Text("Row \(row): stripe").font(.body)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 16)
                    .background(row % 2 == 0 ? Color.red : Color.blue)
                    .foregroundStyle(.white)
            }
        }
    }
}
struct NavProbeScene: View {
    let mode: String
    @State private var presented = false
    private var dark: Bool { ProcessInfo.processInfo.arguments.contains("--dark") }
    var body: some View {
        Group {
            if mode.hasPrefix("sheet") {
                Color(.systemBackground).overlay(Text("Presenter")).ignoresSafeArea()
                    .sheet(isPresented: $presented) { sheetContent }
                    .task { try? await Task.sleep(for: .milliseconds(400)); presented = true }
            } else {
                NavigationStack { subtitleContent }
            }
        }
        .preferredColorScheme(dark ? .dark : .light)
        .task {
            FrameSampler.shared.start()
            for sample in 0..<200 {
                try? await Task.sleep(for: .milliseconds(100))
                await MainActor.run { Measurement.write(sample) }
            }
        }
    }
    @ToolbarContentBuilder var items: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) { Button {} label: { Image(systemName: "chevron.left") } }
        ToolbarItem(placement: .topBarTrailing) { Button {} label: { Image(systemName: "bell") } }
    }
    @ViewBuilder var subtitleContent: some View {
        let long = mode == "subtitleLong"
        ScrollView { StripeRows() }
            .navigationTitle(long ? NavProbe.longTitle : "Feature Measurements")
            .navigationSubtitle(long ? NavProbe.longSubtitle : "Amazon")
            .navigationBarTitleDisplayMode(mode == "subtitleLarge" ? .large : .inline)
            .toolbar { items }
    }
    @ViewBuilder var sheetContent: some View {
        let large = mode.hasSuffix("LargeTitle")
        let medium = mode.contains("Medium")
        let indicator = mode.hasSuffix("Indicator")
        let stack = NavigationStack {
            ScrollView { StripeRows() }
                .navigationTitle("Sheet Title")
                .navigationBarTitleDisplayMode(large ? .large : .inline)
                .toolbar { items }
        }
        if medium {
            stack.presentationDetents([.medium, .large]).presentationDragIndicator(indicator ? .visible : .automatic)
        } else {
            stack.presentationDragIndicator(indicator ? .visible : .automatic)
        }
    }
}
