import SwiftUI

@main struct NativeShowcaseApp: App {
    @State private var model = ShowcaseModel()
    init() {
        let args = ProcessInfo.processInfo.arguments
        let model = ShowcaseModel()
        model.dark = args.contains("--dark")
        if let i = args.firstIndex(of: "--screen"), args.count > i + 1 {
            let screen = args[i + 1]
            model.tab = ["explore", "studio", "library"].firstIndex(of: screen) ?? 2
            if let kind = ComponentKind(rawValue: screen) { model.path = [kind] }
        }
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
            }.environment(model).tint(model.tint)
                .preferredColorScheme(model.dark ? .dark : .light)
                .font(showcaseFont(16)).foregroundStyle(model.ink)
                .onPreferenceChange(GeometryKey.self) { frames in
                    if GeometryStore.shared.frames != frames { GeometryStore.shared.frames = frames }
                }
                .background(InspectionHost(model: model))
        }
    }
}

struct ShowcaseRoot: View {
    @Environment(ShowcaseModel.self) private var model
    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            TabView(selection: $model.tab) {
                Tab(value: 0) { HomePage(tab: 0) } label: {
                    if model.labels { Label("Explore", systemImage: "sparkles") }
                    else { Image(systemName: "sparkles").accessibilityLabel("Explore") }
                }
                Tab(value: 1) { HomePage(tab: 1) } label: {
                    if model.labels { Label("Studio", systemImage: "slider.horizontal.3") }
                    else { Image(systemName: "slider.horizontal.3").accessibilityLabel("Studio") }
                }
                Tab(value: 2) { HomePage(tab: 2) } label: {
                    if model.labels { Label("Library", systemImage: "square.grid.2x2") }
                    else { Image(systemName: "square.grid.2x2").accessibilityLabel("Library") }
                }
            }
            .toolbarBackground(.hidden, for: .tabBar)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ComponentKind.self) { ComponentPage(kind: $0) }
        }.toolbar(.hidden, for: .navigationBar)
    }
}

struct HomePage: View {
    @Environment(ShowcaseModel.self) private var model
    var tab: Int
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "cube").font(showcaseFont(20))
                    .foregroundStyle(model.dark ? Color(hex: 0x151B20) : Color(hex: 0xF5F3ED))
                    .frame(width: 33, height: 33)
                    .background(model.ink, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text("liquid prism").font(showcaseFont(19, .semibold)).tracking(-0.6)
                Spacer(minLength: 0)
                IconAction(icon: model.dark ? "sun.max" : "moon", label: "Toggle appearance") { model.dark.toggle() }
            }.padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 14).measure("header")
            ScrollViewReader { proxy in
                ScrollView {
                    Group {
                        switch tab {
                        case 0: ExplorePage()
                        case 1: StudioPage()
                        default: LibraryPage()
                        }
                    }.frame(maxWidth: 940, alignment: .leading).frame(maxWidth: .infinity)
                        .padding(.horizontal, 24).padding(.top, 6).padding(.bottom, 26)
                }.scrollDismissesKeyboard(.interactively).accessibilityIdentifier("showcase-scroll")
                    .onChange(of: GeometryStore.shared.scrollTarget) { _, target in
                        if let target { proxy.scrollTo(target, anchor: .top) }
                    }
                    .task {
                        let args = ProcessInfo.processInfo.arguments
                        if let i = args.firstIndex(of: "--scroll"), args.count > i + 1 {
                            try? await Task.sleep(for: .milliseconds(350))
                            proxy.scrollTo(args[i + 1], anchor: .top)
                        }
                    }
            }
        }.padding(.bottom, 10).background { Backdrop() }
    }
}

struct ComponentPage: View {
    @Environment(ShowcaseModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var kind: ComponentKind
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                IconAction(icon: "chevron.left", label: "Back to showcase") { dismiss() }
                Text(kind.title).font(showcaseFont(16, .semibold)).frame(maxWidth: .infinity, alignment: .leading)
                IconAction(icon: model.dark ? "sun.max" : "moon", label: "Toggle appearance") { model.dark.toggle() }
            }.padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 16).measure("header")
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow("The collection / \(kind.rawValue)")
                    Text(kind.title).font(showcaseFont(36, .semibold)).tracking(-1.4).padding(.top, 14)
                    Note(kind.description).padding(.top, 12)
                    ComponentPreview(kind: kind).measure("preview").padding(.top, 28)
                    if kind.hasDisabled {
                        SectionTitle("At rest, too.").padding(.top, 26)
                        Note("Disabled controls keep their place, quietly.").padding(.top, 8)
                        Panel { DisabledPreview(kind: kind) }.padding(.top, 14)
                    }
                    Panel {
                        VStack(alignment: .leading, spacing: 0) {
                            Eyebrow("The finishing touches")
                            Text("Made to feel familiar.").font(showcaseFont(21, .semibold)).tracking(-0.5).padding(.top, 14)
                            Note("Native palette colors, continuous corners, and touch-driven springs. Your appearance and accent from Studio follow you here.").padding(.top, 10)
                        }
                    }.padding(.top, 26)
                }.frame(maxWidth: 700, alignment: .leading).frame(maxWidth: .infinity)
                    .padding(.horizontal, 24).padding(.top, 6).padding(.bottom, 32)
            }.scrollDismissesKeyboard(.interactively).accessibilityIdentifier("detail-\(kind.rawValue)")
        }.background { Backdrop() }.toolbar(.hidden, for: .navigationBar).toolbar(.hidden, for: .tabBar)
    }
}
