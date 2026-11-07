import SwiftUI
import UIKit

/// Mirrors `ComponentPage` in component_page.dart.
struct ComponentPage: View {
    var kind: ComponentKind
    var body: some View {
        LargeTitlePage(title: kind.title, subtitle: kind.description, identifier: "detail-\(kind.rawValue)") {
            ComponentPreview(kind: kind).measure("preview")
            Color.clear.frame(height: 28)
            if kind.hasDisabled {
                InsetSection("Disabled", footer: "Disabled controls keep their place, quietly.") {
                    DisabledPreview(kind: kind).padding(16)
                }
            }
            InsetSection("Details") {
                ForEach(kind.details.indices, id: \.self) { i in
                    ListRow(title: kind.details[i].0, subtitle: kind.details[i].1)
                }
            }
        }
    }
}

/// A draggable lens over the artwork, as `LensPlayground` in previews.dart.
struct LensPlayground: View {
    @Environment(ShowcaseModel.self) private var model
    var expert = false
    var glass: Glass? = nil
    @State private var position = CGPoint(x: 0.5, y: 0.5)
    @State private var start: CGPoint?
    private let lensHeight: CGFloat = 115

    var body: some View {
        let canvasHeight = lensHeight + 130
        let ink = Art.inks[model.wallpaper]
        GeometryReader { proxy in
            let width = min(max(proxy.size.width - 44, 80), 200)
            let travelX = max(proxy.size.width - width - 24, 0), travelY = canvasHeight - lensHeight - 24
            ZStack(alignment: .topLeading) {
                Artwork(variant: model.wallpaper)
                Eyebrow("Drag the glass", color: ink).offset(x: 20, y: 18)
                lens(width: width)
                    .offset(x: 12 + position.x * travelX, y: 12 + position.y * travelY)
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let origin = start ?? position
                            if start == nil { start = position }
                            position = CGPoint(
                                x: travelX == 0 ? 0 : min(max(origin.x + value.translation.width / travelX, 0), 1),
                                y: min(max(origin.y + value.translation.height / travelY, 0), 1))
                        }
                        .onEnded { _ in start = nil })
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right").font(showcaseFont(19))
                    .foregroundStyle(ink.opacity(0.65))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 18).padding(.bottom, 17)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: canvasHeight)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .measure("lens-canvas")
    }

    private func lens(width: CGFloat) -> some View {
        // Public glass has no frost or refraction parameters; expert mode
        // keeps the Flutter optics' 8% accent tint.
        let material = glass ?? (expert ? model.glass.tint(model.tint.opacity(0.08)) : model.glass)
        return VStack(spacing: 0) {
            Image(systemName: "cube").font(showcaseFont(30))
            Text("A new view.").font(showcaseFont(19, .semibold)).tracking(-0.6).padding(.top, 10)
            Text("Hold. Move. Explore.").font(showcaseFont(11)).padding(.top, 5)
        }
        .foregroundStyle(.black)
        .padding(14)
        .frame(width: width, height: lensHeight)
        .glassEffect(material, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(Rectangle())
        .measure("studio-lens")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Draggable glass preview").accessibilityIdentifier("studio-lens")
    }
}

/// Mirrors `ComponentPreview` in previews.dart.
struct ComponentPreview: View {
    @Environment(ShowcaseModel.self) private var model
    var kind: ComponentKind
    @State private var selectedTab = 0
    @State private var selectedSurface = 0
    @State private var actions = 0
    @State private var extraAction = false
    @State private var query = ""
    @State private var menuResult = "Choose something. See what happens."

    private var ink: Color { Art.inks[model.wallpaper] }

    var body: some View {
        if kind == .surfaces {
            surfaces
        } else {
            ArtCanvas(variant: model.wallpaper) {
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow("Live preview", color: ink)
                    preview.padding(.top, 24)
                }.padding(.bottom, 8)
            }
        }
    }

    private func surfaceGlass(_ i: Int) -> Glass {
        switch i {
        case 1: .clear
        case 2: .regular.tint(model.tint.opacity(0.3))
        case 3: .identity
        default: .regular
        }
    }

    private var surfaces: some View {
        VStack(spacing: 16) {
            LensPlayground(glass: surfaceGlass(selectedSurface))
            GlassEffectContainer {
                Flow(spacing: 12) {
                    ForEach(0..<4) { i in
                        Button { selectedSurface = i } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark").font(showcaseFont(14))
                                    .frame(width: 14, height: 14).opacity(selectedSurface == i ? 1 : 0)
                                Text(["Regular", "Clear", "Tinted", "Identity"][i]).font(showcaseFont(13))
                            }.padding(.vertical, 4)
                        }
                        .buttonStyle(.glass(surfaceGlass(i)))
                        .labelled("Select surface \(i)")
                        .accessibilityAddTraits(selectedSurface == i ? .isSelected : [])
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func headline(_ text: String) -> some View {
        Text(text).font(showcaseFont(22, .semibold)).foregroundStyle(ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func copy(_ text: String, size: CGFloat = 14) -> some View {
        Text(text).font(showcaseFont(size)).lineSpacing(size == 13 ? 2 : 0).foregroundStyle(ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var preview: some View {
        @Bindable var model = model
        switch kind {
        case .surfaces: EmptyView()
        case .buttons:
            VStack(alignment: .leading, spacing: 0) {
                Flow(spacing: 12) {
                    Button("Glass") { model.taps += 1 }.glassButton(glass: model.glass).labelled("Add a tap")
                    Button("Prominent") { model.taps += 1 }.glassButton(prominent: true).labelled("Add a prominent tap")
                    Button { model.favorite.toggle() } label: {
                        Image(systemName: model.favorite ? "heart.fill" : "heart").font(showcaseFont(22))
                    }
                    .buttonStyle(.glass(model.glass)).buttonBorderShape(.circle).controlSize(.extraLarge)
                    .labelled("Favorite").accessibilityAddTraits(model.favorite ? .isSelected : [])
                }
                Text("\(model.taps) \(model.taps == 1 ? "tap" : "taps")").font(showcaseFont(26, .semibold))
                    .foregroundStyle(ink).padding(.top, 26)
                copy("Press and hold any button.", size: 13).padding(.top, 8)
            }
        case .switches:
            VStack(spacing: 0) {
                HStack {
                    Text("Let it glow").font(showcaseFont(20, .semibold)).foregroundStyle(ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    NativeToggle(label: "Let it glow", value: $model.enabled)
                }
                Image(systemName: model.enabled ? "sun.max.fill" : "moon.fill").font(showcaseFont(52))
                    .foregroundStyle(ink).frame(height: 52).padding(.top, 28)
                copy(model.enabled ? "A brighter outlook." : "A moment of quiet.", size: 15).padding(.top, 12)
            }
        case .sliders:
            VStack(spacing: 0) {
                HStack {
                    Text("Just the right amount.").font(showcaseFont(20, .semibold)).foregroundStyle(ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(Int((model.level * 100).rounded()))%").font(showcaseFont(18, .semibold)).foregroundStyle(ink)
                }
                NativeSlider(label: "Intensity", value: $model.level).padding(.top, 26)
                HStack {
                    Image(systemName: "sun.min").font(showcaseFont(19))
                    Spacer()
                    Image(systemName: "sun.max").font(showcaseFont(25))
                }.foregroundStyle(ink).padding(.top, 20)
            }
        case .segments:
            VStack(spacing: 0) {
                NativeSegments(label: "Perspective", labels: ["Day", "Dusk", "Night"], selection: $model.segment)
                Image(systemName: ["sun.max", "sunset", "moon.stars"][model.segment]).font(showcaseFont(50))
                    .foregroundStyle(ink).frame(height: 50).padding(.top, 30)
                copy(["Start with a little light.", "Take the scenic route.", "Find your quiet moment."][model.segment],
                     size: 15).padding(.top, 12)
            }
        case .tabs:
            VStack(alignment: .leading, spacing: 0) {
                headline("Take a different path.")
                copy(["Discover something new.", "Keep what speaks to you.", "Make yourself at home."][selectedTab])
                    .padding(.top, 10)
                NativeTabBar(selection: $selectedTab).frame(height: 62).padding(.top, 30).measure("component-tabs")
                // UIKit has no public vertical tab bar outside the system rail,
                // so the rail itself is the app's own TabView on iPhone Duo.
                copy("Beside the iPhone Duo sensor bar, the same tabs stack into an icon-only rail. Hold the pill and glide in either direction.",
                     size: 13).padding(.top, 24)
            }
        case .toolbar:
            VStack(alignment: .leading, spacing: 0) {
                headline("A little group effort.")
                NativeToolbar(groups: toolbarGroups, navigation: true)
                    .frame(height: 44).padding(.top, 26).measure("demo-toolbar")
                NativeToolbar(groups: [[
                    ToolbarAction("Previous", "chevron.left") { actions += 1 },
                    ToolbarAction("Next", "chevron.right") { actions += 1 },
                ]]).frame(height: 48).padding(.top, 20)
                copy("\(actions) actions. Tap the plus to add items and a group. Hold an icon to lift its capsule. In a side rail, groups stack vertically.",
                     size: 13).padding(.top, 18)
            }
        case .scrollEdges:
            VStack(alignment: .leading, spacing: 0) {
                headline("Soft where it meets the bar.")
                copy("Scroll the list. The bar’s glass stays clear of the blur.").padding(.top, 12)
                ScrollEdgePreview(ink: UIColor(ink))
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(.top, 20)
                FeaturesDemo().frame(height: 420).id("features-demo").padding(.top, 20)
                copy("A scroll fade softens whichever edge content runs past.", size: 13).padding(.top, 20)
                ScrollFadePreview(ink: ink).padding(.top, 12)
            }
        case .pages:
            VStack(alignment: .leading, spacing: 0) {
                headline("A page in a few lines.")
                copy("Each page below is one LiquidPrismScaffold or sliver bar, with no scroll view, padding or grouping of its own.")
                    .padding(.top, 12)
                VStack(spacing: 12) {
                    ForEach(Self.pageLinks, id: \.key) { link in
                        NavigationLink(value: link.route) {
                            Text(link.title).frame(maxWidth: .infinity)
                        }
                        .glassButton(glass: model.glass)
                        .accessibilityLabel(link.label).accessibilityIdentifier(link.key)
                    }
                }.padding(.top, 20).padding(.bottom, 12)
            }
        case .menus:
            VStack(alignment: .leading, spacing: 0) {
                headline("A familiar kind of magic.")
                copy("Your glass trigger. The system’s popup.").padding(.top, 12)
                Flow(spacing: 14) {
                    Menu { menuItems } label: {
                        HStack(spacing: 8) {
                            Text("Choose an action")
                            Image(systemName: "chevron.down").font(showcaseFont(16))
                        }
                    }
                    .glassButton(prominent: true)
                    .labelled("Open native menu")
                    NativeToolbar(groups: [[ToolbarAction("Open toolbar menu", "ellipsis",
                                                          menu: nativeMenu(model: model, selected: menuSelected))]])
                        .frame(width: 48, height: 48)
                }.padding(.top, 24)
                HStack(spacing: 12) {
                    Image(systemName: "hand.draw").font(showcaseFont(23))
                    Text("Hold here for a context menu").font(showcaseFont(14))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(ink)
                .padding(18)
                .glassEffect(model.glass, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .contextMenu { menuItems }
                .accessibilityIdentifier("native-context-menu")
                .padding(.top, 22)
                copy(menuResult, size: 13).padding(.top, 18)
            }
        case .search:
            VStack(alignment: .leading, spacing: 0) {
                headline("What’s on your mind?")
                NativeSearch(text: $query, placeholder: "Search your ideas")
                    .frame(height: 48).padding(.top, 22).measure("demo-search")
                copy(query.isEmpty ? "Try typing “a fresh start”." : "Looking for “\(query)”").padding(.top, 22)
                NavigationLink(value: Route.search) {
                    Text("Search Page").frame(maxWidth: .infinity)
                }
                .glassButton(glass: model.glass)
                .accessibilityLabel("Open the search page").accessibilityIdentifier("open-search-page")
                .padding(.top, 22)
            }
        }
    }

    static let pageLinks: [(key: String, title: String, label: String, route: Route)] = [
        ("open-scaffold-lab", "Scaffold Lab", "Switch every page option live", .scaffoldLab),
        ("open-header-page", "Header Page", "A header that scrolls away and a bottom bar", .header),
        ("open-conversation", "Conversation", "A glass title with an avatar, and a text button", .conversation),
        ("open-sliver-bar", "Sliver App Bar", "The bar inside your own CustomScrollView", .sliverBar),
        ("open-search-page-2", "Search Page", "A fixed search field with an always-visible close", .search),
    ]

    /// One toolbar, two groups: the first fills and empties as the plus item
    /// is tapped, so UIKit materializes its capsule and the gap.
    private var toolbarGroups: [[ToolbarAction]] {
        let more = ToolbarAction("More", "ellipsis", menu: nativeMenu(model: model, selected: menuSelected))
        var second = [
            ToolbarAction(extraAction ? "Remove star" : "Add star", extraAction ? "minus.circle" : "plus.circle",
                          id: "toggle-star") { extraAction.toggle() },
            ToolbarAction("Share", "square.and.arrow.up") { actions += 1 },
        ]
        if extraAction { second.append(ToolbarAction("Compose", "square.and.pencil") { actions += 1 }) }
        second.append(more)
        return [extraAction ? [ToolbarAction("Star", "star") { actions += 1 }] : [], second]
    }

    private func menuSelected(_ value: String) { menuResult = "Selected: \(value)" }

    @ViewBuilder private var menuItems: some View {
        Toggle(isOn: Binding(get: { model.favorite }, set: { model.favorite = $0; menuSelected("Favorite") })) {
            Label(model.favorite ? "Remove favorite" : "Add to favorites", systemImage: "heart")
        }
        Button("A new idea", systemImage: "sparkles") { model.taps += 1; menuSelected("A new idea") }
        Divider()
        Menu("Artwork", systemImage: "photo") {
            Picker("Artwork", selection: Binding(get: { model.wallpaper }, set: {
                model.wallpaper = $0; menuSelected(Art.names[$0])
            })) {
                ForEach(Art.names.indices, id: \.self) { Text(Art.names[$0]).tag($0) }
            }.pickerStyle(.inline)
        }
        Section("On opening") {
            Button("\(model.taps) ideas so far", systemImage: "lightbulb") { menuSelected("Idea count") }
        }
        Button("Coming soon", systemImage: "clock") {}.disabled(true)
        Divider()
        Button("Reset this demo", systemImage: "arrow.counterclockwise", role: .destructive) {
            model.taps = 0; model.favorite = false; menuSelected("Demo reset")
        }
    }
}

/// The Disabled section's controls, as `ComponentPage._disabled`.
struct DisabledPreview: View {
    var kind: ComponentKind
    var body: some View {
        Group {
            switch kind {
            case .buttons:
                Button("Taking a moment") {}.glassButton().labelled("Unavailable action")
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .switches:
                HStack {
                    Text("Unavailable switch").frame(maxWidth: .infinity, alignment: .leading)
                    NativeToggle(label: "Unavailable switch", value: .constant(true))
                }
            case .sliders:
                NativeSlider(label: "Unavailable slider", value: .constant(0.62))
            case .segments:
                NativeSegments(label: "Unavailable segments", labels: ["Day", "Dusk", "Night"], selection: .constant(0))
            case .toolbar:
                NativeToolbar(groups: [[
                    ToolbarAction("Unavailable star", "star", enabled: false),
                    ToolbarAction("Unavailable share", "square.and.arrow.up", enabled: false),
                ]]).frame(height: 48)
            default:
                EmptyView()
            }
        }.disabled(true)
    }
}
