import SwiftUI

/// Native glass over hard-edged black/white backdrops, held one at a time by
/// the UI tests, so screenshots show any colour fringe at lifted lens rims and
/// the extractor records the filters (glassForeground inputAberration*).
///   --scene controls|tabbar|toolbar   --pattern v|h|edge   --light
@main struct DispersionSpecsApp: App {
    init() { StartDispersionCapture(run()) }
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
func run() -> String { "\(value("--scene", "controls"))-\(value("--pattern", "v"))-\(flag("--light") ? "light" : "dark")" }

/// 8-point white/black stripes (vertical or horizontal), or one vertical edge.
struct Backdrop: View {
    let pattern = value("--pattern", "v")
    var body: some View {
        GeometryReader { g in
            if pattern == "edge" {
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
        case "tabbar": TabsFixture()
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
    var body: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house.fill", value: 0) { Backdrop() }
            Tab("Search", systemImage: "magnifyingglass", value: 1) { Backdrop() }
            Tab("Profile", systemImage: "person.fill", value: 2) { Backdrop() }
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
