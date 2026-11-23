import SwiftUI

@main struct NativeShowcaseApp: App {
    @State private var model: ShowcaseModel
    init() {
        let args = ProcessInfo.processInfo.arguments
        let model = ShowcaseModel()
        model.dark = args.contains("--dark")
        if let i = args.firstIndex(of: "--screen"), args.count > i + 1 { model.open(screen: args[i + 1]) }
        if let i = args.firstIndex(of: "--accent"), args.count > i + 1 { model.accent = args[i + 1] }
        _model = State(initialValue: model)
    }
    var body: some Scene {
        WindowGroup {
            Group {
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "--tab-labels"), args.count > i + 1 {
                    TabLayoutProbe(labels: args[i + 1].components(separatedBy: "|"), hideLabels: args.contains("--hide-labels"))
                } else { ShowcaseRoot() }
            }
            .environment(model)
            .tint(model.tint)
            .preferredColorScheme(model.dark ? .dark : .light)
            .modifier(VerticalBarBehavior(enabled: model.verticalBar))
            .onPreferenceChange(GeometryKey.self) { frames in
                if GeometryStore.shared.frames != frames { GeometryStore.shared.frames = frames }
            }
            .background(InspectionHost(model: model))
        }
    }
}

/// Mirrors `ShowcaseHome` in app.dart: Explore, Studio and Library tabs, each
/// with its own navigation stack. Pushed pages hide the tab bar.
struct ShowcaseRoot: View {
    @Environment(ShowcaseModel.self) private var model
    var body: some View {
        @Bindable var model = model
        let tabs = TabView(selection: $model.tab) {
            Tab(value: 0) { TabStack(index: 0) { ExplorePage() } } label: { tabLabel("Explore", "sparkles") }
            Tab(value: 1) { TabStack(index: 1) { StudioPage() } } label: { tabLabel("Studio", "slider.horizontal.3") }
            // SwiftUI draws every tab item with the symbol's fill variant.
            Tab(value: 2) { TabStack(index: 2) { LibraryPage() } } label: { tabLabel("Library", "square.grid.2x2.fill") }
        }
        if model.sidebar { tabs.tabViewStyle(.sidebarAdaptable) } else { tabs }
    }

    @ViewBuilder private func tabLabel(_ title: String, _ symbol: String) -> some View {
        if model.labels { Label(title, systemImage: symbol) }
        else { Image(systemName: symbol).accessibilityLabel(title) }
    }
}

private struct TabStack<Root: View>: View {
    @Environment(ShowcaseModel.self) private var model
    var index: Int
    @ViewBuilder var root: Root
    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.paths[index]) {
            root.navigationDestination(for: Route.self) { RouteView(route: $0) }
        }
    }
}
