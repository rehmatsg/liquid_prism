import SwiftUI

/// A navigation bar with glass bar buttons over a scroll view whose top edge
/// takes the system scroll edge effect. The content starts with 2-point
/// black/white stripes so a screenshot column measures the blur profile, then
/// solid colour bands so the fade profile reads from a flat tone.
@main struct ScrollEdgeSpecsApp: App {
    var body: some Scene { WindowGroup { if arg("--hairline") { HairlineFixture() } else { Fixture() } } }
}

func arg(_ s: String) -> Bool { ProcessInfo.processInfo.arguments.contains(s) }

struct Fixture: View {
    var styleName: String { arg("--hard") ? "hard" : arg("--auto") ? "automatic" : "soft" }
    var style: ScrollEdgeEffectStyle { arg("--hard") ? .hard : arg("--auto") ? .automatic : .soft }
    var mode: String { arg("--light") ? "light" : "dark" }
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // 2-point stripes: the blur profile reads from their contrast.
                        ForEach(0..<150, id: \.self) { i in
                            Rectangle().fill(i % 2 == 0 ? Color.white : Color.black).frame(height: 2).id(i)
                        }
                        // Flat bands: the fade profile reads from one tone.
                        ForEach(0..<30, id: \.self) { i in
                            Rectangle().fill([Color.orange, .blue, .green, .pink, .teal, .purple][i % 6]).frame(height: 120).id(200 + i)
                        }
                    }
                }
                .scrollEdgeEffectStyle(style, for: .top)
                .navigationTitle("Edge")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Back", systemImage: "chevron.left") {} }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Favorite", systemImage: "star") {}
                        Button("More", systemImage: "ellipsis") {}
                    }
                }
                .task {
                    try? await Task.sleep(for: .milliseconds(1200))
                    ExtractScrollEdge("rest-\(styleName)-\(mode)", ["style": styleName, "mode": mode, "state": "rest"])
                    withAnimation(.linear(duration: 0.1)) { proxy.scrollTo(204, anchor: .top) }
                    try? await Task.sleep(for: .milliseconds(2500))
                    ExtractScrollEdge("scrolled-\(styleName)-\(mode)", ["style": styleName, "mode": mode, "state": "scrolled"])
                    try? await Task.sleep(for: .milliseconds(4000))
                    withAnimation(.linear(duration: 0.1)) { proxy.scrollTo(100, anchor: .top) }
                    try? await Task.sleep(for: .milliseconds(2500))
                    ExtractScrollEdge("stripes-\(styleName)-\(mode)", ["style": styleName, "mode": mode, "state": "stripes"])
                }
            }
        }
        .preferredColorScheme(mode == "light" ? .light : .dark)
    }
}

/// Hard edge hairline fixture (`--hairline`, with `--light`, `--bottom` for a
/// `.safeAreaBar` accessory or `--bottombar` for a bottom toolbar). Content is
/// flat white (light) or black (dark) with one 50% grey band (scrolled to straddle the bar edge, 16-216 pt), so the hairline's
/// compositing reads against known tones. Scrolls itself through rest, plain
/// content under the bar and the grey band straddling the bar edge, tracing
/// the edge layers' opacity each frame while it scrolls.
struct HairlineFixture: View {
    @State var position = ScrollPosition(edge: .top)
    var mode: String { arg("--light") ? "light" : "dark" }
    var variant: String { arg("--bottom") ? "accessory" : arg("--bottombar") ? "bottombar" : "top" }
    var plain: Color { arg("--light") ? .white : .black }
    func tag(_ s: String) -> String { "h-\(s)-\(variant)-\(mode)" }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    plain.frame(height: 400)
                    Color(.sRGB, white: 0.5, opacity: 1).frame(height: 200)
                    plain.frame(height: 3000)
                }
            }
            .scrollPosition($position)
            .background(plain)
            .scrollEdgeEffectStyle(.hard, for: .all)
            .navigationTitle("Edge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("More", systemImage: "ellipsis") {} }
                if arg("--bottombar") {
                    ToolbarItem(placement: .bottomBar) { Button("Share", systemImage: "square.and.arrow.up") {} }
                }
            }
            .safeAreaBar(edge: .bottom) {
                if arg("--bottom") {
                    Button("Accessory") {}.buttonStyle(.glass).padding(.vertical, 8)
                }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(1500))
                ExtractScrollEdge(tag("rest"), ["state": "rest", "mode": mode, "variant": variant])
                try? await Task.sleep(for: .milliseconds(1500))
                TraceScrollEdge(tag("trace-in"), 2.0)
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(.easeInOut(duration: 0.6)) { position.scrollTo(y: 150) }
                try? await Task.sleep(for: .milliseconds(3000))
                ExtractScrollEdge(tag("plain"), ["state": "plain", "mode": mode, "variant": variant])
                try? await Task.sleep(for: .milliseconds(1500))
                position.scrollTo(y: 500)
                try? await Task.sleep(for: .milliseconds(2500))
                ExtractScrollEdge(tag("grey"), ["state": "grey", "mode": mode, "variant": variant])
                try? await Task.sleep(for: .milliseconds(1500))
                TraceScrollEdge(tag("trace-out"), 2.0)
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(.easeInOut(duration: 0.6)) { position.scrollTo(y: 0) }
                try? await Task.sleep(for: .milliseconds(3000))
                ExtractScrollEdge(tag("back"), ["state": "back", "mode": mode, "variant": variant])
            }
        }
        .preferredColorScheme(mode == "light" ? .light : .dark)
    }
}
