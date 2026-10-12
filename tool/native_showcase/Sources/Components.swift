import SwiftUI

struct LensPlayground: View {
    @Environment(ShowcaseModel.self) private var model
    var expert = false
    var glass: Glass? = nil
    @State private var position = UnitPoint.center
    @State private var dragStart = UnitPoint.center
    var body: some View {
        GeometryReader { proxy in
            let width = min(max(proxy.size.width - 44, 80), 200.0)
            let travelX = max(proxy.size.width - width - 24, 0), travelY = 106.0
            ZStack(alignment: .topLeading) {
                Artwork(variant: model.wallpaper)
                Eyebrow("Move / Discover", color: Color(hex: 0x314D47)).offset(x: 20, y: 20)
                VStack(spacing: 0) {
                    Image(systemName: "cube").font(showcaseFont(30)).frame(height: 30)
                    Text("A new view.").font(showcaseFont(19, .semibold)).tracking(-0.6).padding(.top, 10)
                    Text("Hold. Move. Explore.").font(showcaseFont(11)).padding(.top, 5)
                }.foregroundStyle(.black).frame(width: width, height: 115)
                    .glassEffect(glass ?? model.glass, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .measure("studio-lens")
                    .offset(x: 12 + position.x * travelX, y: 12 + position.y * travelY)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            position = UnitPoint(x: min(max(dragStart.x + value.translation.width / max(travelX, 1), 0), 1),
                                                 y: min(max(dragStart.y + value.translation.height / travelY, 0), 1))
                        }.onEnded { _ in dragStart = position })
                    .accessibilityLabel("Draggable glass canvas").accessibilityIdentifier("studio-lens")
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right").font(showcaseFont(19))
                    .foregroundStyle(Color(hex: 0x314D47).opacity(2.0 / 3))
                    .position(x: proxy.size.width - 27.5, y: proxy.size.height - 26.5)
            }
        }.frame(height: 245).clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous)).measure("lens-canvas")
    }
}

struct ComponentPreview: View {
    @Environment(ShowcaseModel.self) private var model
    var kind: ComponentKind
    @State private var selectedSurface = 0
    @State private var selectedTab = 0
    @State private var actions = 0
    @State private var query = ""
    @State private var menuResult = "Choose something. See what happens."
    @State private var sheetResult = "A little more room to explore."
    @State private var presented = false
    var selectedGlass: Glass {
        switch selectedSurface {
        case 1: .clear
        case 2: .regular.tint(model.tint.opacity(0.3))
        case 3: .identity
        default: .regular
        }
    }
    var body: some View {
        @Bindable var model = model
        Group {
            if kind == .surfaces {
                VStack(spacing: 16) {
                    LensPlayground(glass: selectedGlass)
                    Flow {
                        ForEach(0..<4) { i in
                            let label = ["Regular", "Clear", "Tinted", "Identity"][i]
                            Group {
                                if i == 3 {
                                    Button { selectedSurface = i } label: { surfaceLabel(label, selected: i == selectedSurface) }
                                        .buttonStyle(.plain).padding(.horizontal, 20).padding(.vertical, 15)
                                } else {
                                    NativeButton(label: "Select surface \(i)", glass: i == 0 ? .regular : i == 1 ? .clear : .regular.tint(model.tint.opacity(0.3)), action: { selectedSurface = i }) {
                                        surfaceLabel(label, selected: i == selectedSurface).padding(.vertical, 4).padding(.horizontal, 4)
                                    }
                                }
                            }.accessibilityIdentifier("Select surface \(i)")
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow("The live preview", color: Color(hex: 0x314D47))
                    preview.padding(.top, 28)
                    Color.clear.frame(height: 12)
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.black).background { Artwork(variant: model.wallpaper) }
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            }
        }.sheet(isPresented: $presented, onDismiss: {
            if sheetResult == "A little more room to explore." { sheetResult = "Back to the bigger picture." }
        }) {
            ShowcaseSheet(result: $sheetResult).environment(model)
                .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
                .preferredColorScheme(model.dark ? .dark : .light)
        }
    }
    @ViewBuilder private func surfaceLabel(_ text: String, selected: Bool) -> some View {
        HStack(spacing: 6) {
            Group { if selected { Image(systemName: "checkmark") } else { Color.clear } }.frame(width: 14, height: 14)
            Text(text)
        }.font(showcaseFont(13, .semibold)).foregroundStyle(model.tint)
    }
    @ViewBuilder private var preview: some View {
        @Bindable var model = model
        switch kind {
        case .surfaces: EmptyView()
        case .buttons:
            VStack(alignment: .leading, spacing: 0) {
                Flow {
                    ActionButton(text: "Glass", label: "Add a tap") { model.taps += 1 }
                    ActionButton(text: "Prominent", prominent: true, label: "Add a prominent tap") { model.taps += 1 }
                    NativeButton(label: "Favorite", circle: true, action: { model.favorite.toggle() }) {
                        Image(systemName: model.favorite ? "heart.fill" : "heart").font(showcaseFont(22)).frame(width: 38, height: 38)
                    }
                }
                Text("\(model.taps) \(model.taps == 1 ? "tap" : "taps")").font(showcaseFont(26, .semibold)).padding(.top, 26)
                Text("Press and hold any button.").font(showcaseFont(13)).padding(.top, 8)
            }
        case .switches:
            VStack(spacing: 0) {
                HStack {
                    Text("Let it glow").font(showcaseFont(20, .semibold)).frame(maxWidth: .infinity, alignment: .leading)
                    NativeToggle(label: "Let it glow", value: $model.enabled)
                }
                Image(systemName: model.enabled ? "sun.max.fill" : "moon.fill").font(showcaseFont(52)).frame(height: 52).padding(.top, 28)
                Text(model.enabled ? "A brighter outlook." : "A moment of quiet.").font(showcaseFont(15)).padding(.top, 12)
            }
        case .sliders:
            VStack(alignment: .leading, spacing: 0) {
                HStack { Text("Just the right amount.").font(showcaseFont(20, .semibold)); Spacer(); Text("\(Int((model.level * 100).rounded()))%").font(showcaseFont(18, .semibold)) }
                NativeSlider(label: "Intensity", value: $model.level, fill: true).padding(.top, 26)
                HStack { Image(systemName: "sun.min").font(showcaseFont(19)); Spacer(); Image(systemName: "sun.max").font(showcaseFont(25)) }.padding(.top, 20)
            }
        case .segments:
            VStack(spacing: 0) {
                NativeSegments(label: "Perspective", labels: ["Day", "Dusk", "Night"], selection: $model.segment, fill: true)
                Image(systemName: ["sun.max", "sunset", "moon.stars"][model.segment]).font(showcaseFont(50)).frame(height: 50).padding(.top, 30)
                Text(["Start with a little light.", "Take the scenic route.", "Find your quiet moment."][model.segment]).font(showcaseFont(15)).padding(.top, 12)
            }
        case .tabs:
            VStack(alignment: .leading, spacing: 0) {
                Text("Take a different path.").font(showcaseFont(22, .semibold))
                Text(["Discover something new.", "Keep what speaks to you.", "Make yourself at home."][selectedTab]).font(showcaseFont(14)).padding(.top, 10)
                NativeTabBar(selection: $selectedTab).frame(height: 62).padding(.top, 34).measure("component-tabs")
                Text("Hold the pill and glide between tabs.").font(showcaseFont(12)).padding(.top, 16)
            }
        case .toolbar:
            VStack(alignment: .leading, spacing: 0) {
                Text("A little group effort.").font(showcaseFont(22, .semibold))
                Flow(spacing: 14) {
                    NativeToolbar(items: toolbarActions, navigation: true).frame(width: 159, height: 44).measure("demo-toolbar")
                    NativeToolbar(items: [ToolbarAction("Compose", "square.and.pencil") { actions += 1 }]).frame(width: 48, height: 48)
                }.padding(.top, 26)
                NativeToolbar(items: [ToolbarAction("Previous", "chevron.left") { actions += 1 }, ToolbarAction("Next", "chevron.right") { actions += 1 }]).frame(width: 100, height: 48).padding(.top, 20)
                Text("\(actions) actions. Hold an icon to lift its group.").font(showcaseFont(13)).padding(.top, 18)
            }
        case .menus:
            VStack(alignment: .leading, spacing: 0) {
                Text("A familiar kind of magic.").font(showcaseFont(22, .semibold))
                Text("Your glass trigger. The system’s popup.").font(showcaseFont(14)).padding(.top, 12)
                Flow(spacing: 14) {
                    Menu { menuItems } label: {
                        HStack(spacing: 8) { Text("Choose an action"); Image(systemName: "chevron.down").font(showcaseFont(16)) }
                    }.buttonStyle(.glassProminent).font(showcaseFont(17, .semibold)).accessibilityIdentifier("Open native menu").measure("Open native menu")
                    NativeToolbar(items: [ToolbarAction("Open toolbar menu", "ellipsis", menu: nativeMenu(model: model, selected: menuSelected), action: {})]).frame(width: 48, height: 48)
                }.padding(.top, 24)
                HStack(spacing: 12) {
                    Image(systemName: "hand.draw").font(showcaseFont(23)); Text("Hold here for a context menu").font(showcaseFont(14)).frame(maxWidth: .infinity, alignment: .leading)
                }.padding(18).glassEffect(model.glass, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .contextMenu { menuItems }.accessibilityIdentifier("native-context-menu").padding(.top, 22)
                Text(menuResult).font(showcaseFont(13)).padding(.top, 18)
            }
        case .search:
            VStack(alignment: .leading, spacing: 0) {
                Text("What’s on your mind?").font(showcaseFont(22, .semibold))
                NativeSearch(text: $query, placeholder: "Search your ideas").frame(height: 48).padding(.top, 22).measure("demo-search")
                Text(query.isEmpty ? "Try typing “a fresh start”." : "Looking for “\(query)”").font(showcaseFont(14)).padding(.top, 22)
            }
        case .sheets:
            VStack(spacing: 0) {
                Image(systemName: "rectangle.on.rectangle").font(showcaseFont(48)).frame(height: 48)
                Text("Make room for more.").font(showcaseFont(24, .semibold)).tracking(-0.6).padding(.top, 16)
                ActionButton(text: "Open a sheet", icon: "arrow.up", prominent: true) { presented = true }.padding(.top, 20)
                Text(sheetResult).font(showcaseFont(13)).padding(.top, 18)
            }.frame(maxWidth: .infinity)
        }
    }
    var toolbarActions: [ToolbarAction] {
        [ToolbarAction("Star", "star") { actions += 1 }, ToolbarAction("Share", "square.and.arrow.up") { actions += 1 },
         ToolbarAction("More", "ellipsis", menu: nativeMenu(model: model, selected: menuSelected), action: {})]
    }
    func menuSelected(_ value: String) { menuResult = "Selected: \(value)" }
    @ViewBuilder var menuItems: some View {
        Toggle(isOn: Binding(get: { model.favorite }, set: { model.favorite = $0; menuSelected("Favorite") })) {
            Label(model.favorite ? "Remove favorite" : "Add to favorites", systemImage: "heart")
        }
        Button("A new idea", systemImage: "sparkles") { model.taps += 1; menuSelected("A new idea") }
        Divider()
        Menu("Artwork", systemImage: "photo") {
            Picker("Artwork", selection: Binding(get: { model.wallpaper }, set: { model.wallpaper = $0; menuSelected(["Meadow", "Dusk", "Apricot"][$0]) })) {
                ForEach(0..<3) { Text(["Meadow", "Dusk", "Apricot"][$0]).tag($0) }
            }
        }
        Section("On opening") { Button("\(model.taps) ideas so far", systemImage: "lightbulb") { menuSelected("Idea count") } }
        Button("Coming soon", systemImage: "clock") {}.disabled(true)
        Divider()
        Button("Reset this demo", systemImage: "arrow.counterclockwise", role: .destructive) { model.taps = 0; model.favorite = false; menuSelected("Demo reset") }
    }
}

struct IdentityPlayground: View {
    @Environment(ShowcaseModel.self) private var model
    var body: some View {
        ZStack {
            Artwork(variant: model.wallpaper)
            VStack(spacing: 5) { Image(systemName: "cube").font(showcaseFont(30)); Text("A new view.").font(showcaseFont(19, .semibold)); Text("Hold. Move. Explore.").font(showcaseFont(11)) }.foregroundStyle(.black)
            VStack { HStack { Eyebrow("Move / Discover", color: Color(hex: 0x314D47)); Spacer() }; Spacer() }.padding(20)
        }.frame(height: 245).clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

struct DisabledPreview: View {
    var kind: ComponentKind
    var body: some View {
        Group {
            switch kind {
            case .buttons: NativeButton(label: "Unavailable action", action: {}) { Text("Taking a moment").font(showcaseFont(17, .semibold)).padding(.horizontal, 7).padding(.vertical, 8) }
            case .switches: HStack { Text("Unavailable switch"); Spacer(); NativeToggle(label: "Unavailable switch", value: .constant(true)) }
            case .sliders: NativeSlider(label: "Unavailable slider", value: .constant(0.62))
            case .segments: NativeSegments(label: "Unavailable segments", labels: ["Day", "Dusk", "Night"], selection: .constant(0))
            case .toolbar: NativeToolbar(items: [ToolbarAction("Unavailable star", "star", enabled: false, action: {}), ToolbarAction("Unavailable share", "square.and.arrow.up", enabled: false, action: {})], navigation: false).frame(width: 100, height: 48)
            default: EmptyView()
            }
        }.disabled(true)
    }
}

struct ShowcaseSheet: View {
    @Environment(ShowcaseModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Binding var result: String
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack { Eyebrow("A fresh perspective"); Spacer(); IconAction(icon: "xmark", label: "Close sheet") { dismiss() } }
                Text("Good ideas\nneed a little space.").font(showcaseFont(32, .semibold)).tracking(-1.2).padding(.top, 18)
                Note("Pull up to see more. Pull down when you’re done. The glass follows your lead.").padding(.top, 14)
                Panel { HStack(spacing: 14) { Image(systemName: "sparkles").foregroundStyle(model.tint); Text("Something worth keeping.").fontWeight(.semibold) } }.padding(.top, 24)
                ActionButton(text: "Keep this feeling", icon: "checkmark", prominent: true) { result = "A good feeling, saved."; dismiss() }.padding(.top, 22)
                SectionTitle("A few small details").padding(.top, 30)
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(["Two heights, one fluid gesture.", "Smooth corners, all the way around.", "Content that scrolls with you.", "A backdrop that becomes a canvas.", "A natural place to pause."], id: \.self) { text in
                        HStack(spacing: 12) { Image(systemName: "checkmark.circle").font(showcaseFont(21)).foregroundStyle(model.tint); Text(text).font(showcaseFont(15)) }
                    }
                }.padding(.top, 18)
            }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 36)
        }.foregroundStyle(.black).measure("sheet-content")
    }
}
