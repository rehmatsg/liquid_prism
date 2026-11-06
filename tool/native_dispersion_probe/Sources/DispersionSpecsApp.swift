import SwiftUI

/// Native glass over hard-edged black/white backdrops, held one at a time by
/// the UI tests, so screenshots show any colour fringe at lifted lens rims and
/// the extractor records the filters (glassForeground inputAberration*).
///   --scene controls|tabbar|toolbar   --pattern v|h|edge   --light
/// Position-encoded and plain backdrops (see EncodedBackdrop) for decoding the
/// lens displacement field from screenshots:
///   --pattern ramp|phasex|phasey|grayx|grayy|white   [--period 32] [--shift k]
/// Tab fixture variants: --outline (house/magnifyingglass/person instead of the
/// .fill names), --no-fill (outline names with symbolVariants .none), --mono
/// (black selection tint so every channel has contrast on white).
/// --dump-delay S moves the held-state dump/marker (default 1 s).
@main struct DispersionSpecsApp: App {
    init() {
        if let d = Double(value("--dump-delay", "")) { SetDispersionDumpDelay(d) }
        StartDispersionCapture(run())
    }
    var body: some Scene {
        WindowGroup {
            Root().preferredColorScheme(flag("--light") ? .light : .dark)
        }
    }
}

func flag(_ s: String) -> Bool { ProcessInfo.processInfo.arguments.contains(s) }
func value(_ k: String, _ d: String) -> String {
    let a = ProcessInfo.processInfo.arguments
    return a.firstIndex(of: k).map { a[$0 + 1] } ?? d
}
func run() -> String {
    var r = "\(value("--scene", "controls"))-\(value("--pattern", "v"))-\(flag("--light") ? "light" : "dark")"
    if flag("--period") { r += "-p\(value("--period", "32"))" }
    if flag("--shift") { r += "-s\(value("--shift", "0"))" }
    if flag("--outline") { r += "-outline" }
    if flag("--no-fill") { r += "-nofill" }
    if flag("--mono") { r += "-mono" }
    return r
}

/// 8-point white/black stripes (vertical or horizontal), or one vertical edge.
struct Backdrop: View {
    let pattern = value("--pattern", "v")
    var body: some View {
        GeometryReader { g in
            if EncodedBackdrop.patterns.contains(pattern) {
                EncodedBackdrop(pattern: pattern)
            } else if pattern == "edge" {
                HStack(spacing: 0) { Color.white; Color.black }
            } else if pattern == "h" {
                VStack(spacing: 0) {
                    ForEach(0..<Int(g.size.height / 8) + 2, id: \.self) { i in
                        (i % 2 == 0 ? Color.white : Color.black).frame(height: 8)
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(0..<Int(g.size.width / 8) + 2, id: \.self) { i in
                        (i % 2 == 0 ? Color.white : Color.black).frame(width: 8)
                    }
                }
            }
        }.ignoresSafeArea()
    }
}

struct Root: View {
    var body: some View {
        switch value("--scene", "controls") {
        case "tabbar":
            // --mono tints the selected item black so all three channels have
            // contrast on a white backdrop (fringe measurement only).
            if flag("--mono") { TabsFixture().tint(.black) } else { TabsFixture() }
        case "toolbar": ToolbarFixture()
        default: ControlsFixture()
        }
    }
}

struct ControlsFixture: View {
    @State private var on = false
    @State private var v = 0.4
    @State private var seg = 0
    var body: some View {
        ZStack(alignment: .topLeading) {
            Backdrop()
            VStack(alignment: .leading, spacing: 22) {
                Toggle("Switch", isOn: $on).labelsHidden().accessibilityIdentifier("switch")
                Slider(value: $v).frame(width: 300).accessibilityIdentifier("slider")
                Picker("Segmented", selection: $seg) {
                    Text("First").tag(0); Text("Second").tag(1); Text("Third").tag(2)
                }.pickerStyle(.segmented).frame(width: 300).accessibilityIdentifier("segments")
                HStack(spacing: 16) {
                    Button("Glass") {}.buttonStyle(.glass).accessibilityIdentifier("glassButton")
                    Button("Prominent") {}.buttonStyle(.glassProminent).accessibilityIdentifier("prominentButton")
                }
                HStack(spacing: 16) {
                    Text("Regular").frame(width: 120, height: 44)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .accessibilityIdentifier("regularInteractive")
                    Text("Clear").frame(width: 120, height: 44)
                        .glassEffect(.clear.interactive(), in: .capsule)
                        .accessibilityIdentifier("clearInteractive")
                }
                Text("Large").frame(width: 240, height: 88)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .accessibilityIdentifier("largeInteractive")
                Text("Static").frame(width: 120, height: 44)
                    .glassEffect(.regular, in: .capsule)
                    .accessibilityIdentifier("staticGlass")
            }
            .padding(.leading, 36).padding(.top, 80)
        }
    }
}

struct TabsFixture: View {
    @State private var tab = 0
    /// --outline names the outline symbols so any fill variant is applied by
    /// the system rather than by the fixture; the default keeps the .fill names.
    /// --no-fill also clears the tab bar's automatic .fill symbol variant on
    /// each label (environment symbolVariants = .none), with outline names.
    let outline = flag("--outline") || flag("--no-fill")
    var body: some View {
        if flag("--no-fill") {
            TabView(selection: $tab) {
                Tab(value: 0) { Backdrop() } label: { Label("Home", systemImage: "house").environment(\.symbolVariants, .none) }
                Tab(value: 1) { Backdrop() } label: { Label("Search", systemImage: "magnifyingglass").environment(\.symbolVariants, .none) }
                Tab(value: 2) { Backdrop() } label: { Label("Profile", systemImage: "person").environment(\.symbolVariants, .none) }
            }
        } else {
            TabView(selection: $tab) {
                Tab("Home", systemImage: outline ? "house" : "house.fill", value: 0) { Backdrop() }
                Tab("Search", systemImage: "magnifyingglass", value: 1) { Backdrop() }
                Tab("Profile", systemImage: outline ? "person" : "person.fill", value: 2) { Backdrop() }
            }
        }
    }
}

struct ToolbarFixture: View {
    @State private var q = ""
    var body: some View {
        NavigationStack {
            Backdrop()
                .navigationTitle("Toolbar")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Back", systemImage: "chevron.left") {}.accessibilityIdentifier("back") }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Favorite", systemImage: "star") {}.accessibilityIdentifier("favorite")
                        Button("More", systemImage: "ellipsis") {}.accessibilityIdentifier("more")
                    }
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Share", systemImage: "square.and.arrow.up") {}.accessibilityIdentifier("share")
                        Spacer()
                        Button("Add", systemImage: "plus") {}.accessibilityIdentifier("add")
                    }
                }
        }
    }
}

/// Screen-pixel bitmap whose colour encodes its own screen position, so a
/// screenshot pixel seen through a lens decodes to where it was sampled from.
/// Values are written directly into an 8-bit sRGB bitmap (one texel per screen
/// pixel, no interpolation) at the pixel centre (i + .5) / scale, P = --period.
///   ramp:   R = fract(x/P), G = fract(y/P), B = .5
///   phasex: R = .5 + .35 cos(2πx/P), G = .5 + .35 sin(2πx/P), B = .5
///   phasey: the same along y. Phase decoding cancels additive and grey alpha
///           contamination and Gaussian blur (amplitude only).
///   grayx/grayy: R = G = B = .5 + .35 cos(2π(x/P + k/3)), k = --shift 0|1|2;
///           three captures give 3-step phase shifting, exact under any
///           per-channel affine colour transform (e.g. vibrant matrices).
///   white:  plain white.
struct EncodedBackdrop: View {
    static let patterns: Set<String> = ["ramp", "phasex", "phasey", "grayx", "grayy", "white"]
    let pattern: String
    var body: some View {
        let b = UIScreen.main.bounds
        Image(uiImage: Self.cached(pattern))
            .resizable().interpolation(.none)
            .frame(width: b.width, height: b.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .ignoresSafeArea()
    }
    @MainActor static var cache: [String: UIImage] = [:]
    @MainActor static func cached(_ pattern: String) -> UIImage {
        if let i = cache[pattern] { return i }
        let i = image(pattern, period: Double(value("--period", "32")) ?? 32)
        cache[pattern] = i
        return i
    }
    static func image(_ pattern: String, period p: Double) -> UIImage {
        let s = UIScreen.main.scale, b = UIScreen.main.bounds
        let w = Int((b.width * s).rounded()), h = Int((b.height * s).rounded())
        var px = [UInt8](repeating: 255, count: w * h * 4)
        func q(_ v: Double) -> UInt8 { UInt8(max(0, min(255, (v * 255).rounded()))) }
        func fr(_ v: Double) -> Double { v - v.rounded(.down) }
        let shift = Double(value("--shift", "0")) ?? 0
        for j in 0..<h {
            let y = (Double(j) + 0.5) / s
            for i in 0..<w {
                let x = (Double(i) + 0.5) / s, o = (j * w + i) * 4
                var c = (1.0, 1.0, 1.0)
                switch pattern {
                case "ramp": c = (fr(x / p), fr(y / p), 0.5)
                case "phasex": let t = 2 * Double.pi * x / p; c = (0.5 + 0.35 * cos(t), 0.5 + 0.35 * sin(t), 0.5)
                case "phasey": let t = 2 * Double.pi * y / p; c = (0.5 + 0.35 * cos(t), 0.5 + 0.35 * sin(t), 0.5)
                case "grayx", "grayy":
                    let t = 2 * Double.pi * ((pattern == "grayx" ? x : y) / p + shift / 3)
                    let v = 0.5 + 0.35 * cos(t); c = (v, v, v)
                default: break
                }
                px[o] = q(c.0); px[o + 1] = q(c.1); px[o + 2] = q(c.2); px[o + 3] = 255
            }
        }
        let img = px.withUnsafeMutableBytes { buf -> CGImage in
            let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            return ctx.makeImage()!
        }
        return UIImage(cgImage: img, scale: s, orientation: .up)
    }
}
