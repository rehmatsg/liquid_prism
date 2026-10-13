import SwiftUI

/// A navigation bar with glass bar buttons over a scroll view whose top edge
/// takes the system scroll edge effect. The content starts with 2-point
/// black/white stripes so a screenshot column measures the blur profile, then
/// solid colour bands so the fade profile reads from a flat tone.
@main struct ScrollEdgeSpecsApp: App {
    var body: some Scene { WindowGroup { Fixture() } }
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
