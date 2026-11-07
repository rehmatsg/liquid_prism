import SwiftUI
import UIKit

/// Mirrors `ShowcaseModel` in example/lib/showcase/model.dart.
@Observable final class ShowcaseModel {
    var dark = false
    var clear = false
    var labels = true
    /// Keeps bars in the iPhone Duo side bar, or asks iOS for horizontal bars.
    var verticalBar = true
    var sidebar = false
    var accent = "blue"
    var wallpaper = 0
    var frost = 4.0
    var refraction = 24.0
    var enabled = true
    var favorite = false
    var level = 0.62
    var segment = 0
    var taps = 0
    var tab = 0
    /// One navigation path per tab, as each tab owns a NavigationStack.
    var paths: [[Route]] = [[], [], []]
    var query = ""

    /// The selected tab's navigation path.
    var path: [Route] {
        get { paths[tab] }
        set { paths[tab] = newValue }
    }
    var glass: Glass { clear ? .clear : .regular }
    var tint: Color { Self.accents.first { $0.0 == accent }?.1 ?? Color(uiColor: .systemBlue) }

    /// The package's `GlassColors.accents`, in the same order. These are the
    /// iOS 26 system colors, so UIKit resolves them for light and dark.
    static let accents: [(String, Color)] = [
        ("blue", UIColor.systemBlue), ("brown", .systemBrown), ("cyan", .systemCyan),
        ("green", .systemGreen), ("indigo", .systemIndigo), ("mint", .systemMint),
        ("orange", .systemOrange), ("pink", .systemPink), ("purple", .systemPurple),
        ("red", .systemRed), ("teal", .systemTeal), ("yellow", .systemYellow),
    ].map { ($0.0, Color(uiColor: $0.1)) }

    func reset() {
        dark = false; clear = false; labels = true; accent = "blue"
        wallpaper = 0; frost = 4; refraction = 24
    }

    /// Opens a screen by name: a tab, a component or one of the page demos.
    func open(screen: String) {
        if let tab = ["explore", "studio", "library"].firstIndex(of: screen) {
            paths = [[], [], []]; self.tab = tab
        } else if let route = Route.path(for: screen) {
            paths = [[], [], []]; tab = 2; paths[2] = route
        }
    }
}

/// Every pushed screen. Page demos open from the Page Layouts component.
enum Route: Hashable {
    case component(ComponentKind)
    case scaffoldLab, header, conversation, sliverBar, search

    var id: String {
        switch self {
        case .component(let kind): kind.rawValue
        case .scaffoldLab: "scaffold-lab"
        case .header: "header-page"
        case .conversation: "conversation"
        case .sliverBar: "sliver-bar"
        case .search: "search-page"
        }
    }

    /// The stack that shows a screen, as the Flutter showcase reaches it.
    static func path(for screen: String) -> [Route]? {
        if let kind = ComponentKind(rawValue: screen) { return [.component(kind)] }
        let pages: [Route] = [.scaffoldLab, .header, .conversation, .sliverBar, .search]
        return pages.first { $0.id == screen }.map { [.component(.pages), $0] }
    }
}

/// Mirrors `ComponentKind` and `components` in model.dart, in the same order.
enum ComponentKind: String, CaseIterable, Identifiable, Hashable {
    case surfaces, buttons, switches, sliders, segments, tabs, toolbar, scrollEdges, pages, menus, search

    var id: String { rawValue }
    var title: String { info.title }
    var subtitle: String { info.subtitle }
    var icon: String { info.icon }
    var color: Color { Color(hex: info.color) }
    var description: String { info.description }
    var details: [(String, String)] { info.details }

    private var info: (title: String, subtitle: String, icon: String, color: UInt32, description: String, details: [(String, String)]) {
        switch self {
        case .surfaces:
            ("Glass Surfaces", "A window into what’s underneath.", "square.stack.3d.up.fill", 0x30B0C7,
             "Glass bends the scene behind it while keeping your content crisp. Move the lens, then try regular, clear and tinted materials.",
             [("LiquidPrism", "Any shape, with your content on top"),
              ("Glass", "Regular, clear, tinted and identity variants"),
              ("LiquidPrismGroup", "Nearby surfaces share one pass")])
        case .buttons:
            ("Buttons", "Small actions. Satisfying feedback.", "hand.point.right.fill", 0xFF9500,
             "An everyday action with a tactile response. Try a quiet glass button, a prominent action, or a circular favorite.",
             [("LiquidPrismButton", "Glass and prominent styles"),
              ("Feedback", "Lifts and flexes while held"),
              ("Menus", "LiquidPrismButton.menu opens a native menu")])
        case .switches:
            ("Switches", "A familiar feel, down to the spring.", "arrow.triangle.2.circlepath.camera.fill", 0x34C759,
             "Tap to change your outlook. Hold and drag the thumb to feel its lift and the spring that brings it home.",
             [("LiquidPrismSwitch", "Controlled value with onChanged"),
              ("Haptics", "A light tap when the value changes")])
        case .sliders:
            ("Sliders", "Find the sweet spot.", "slider.horizontal.3", 0x5856D6,
             "A little precision, a little play. Drag the thumb to change the value and watch it lift under your finger.",
             [("LiquidPrismSlider", "Any range, continuous fill"),
              ("Thumb", "Grows into a lens while held")])
        case .segments:
            ("Segmented Controls", "Slide into a different perspective.", "rectangle.split.3x1.fill", 0xAF52DE,
             "A shared track with a gliding selection. Tap a perspective or hold the pill and slide to a new one.",
             [("LiquidPrismSegmentedControl", "Typed values, any widgets"),
              ("Gesture", "Tap, or hold and slide")])
        case .tabs:
            ("Tab Bars", "Navigation with a little lift.", "square.grid.2x2.fill", 0x007AFF,
             "A floating home for navigation. The selection lifts, follows your finger and settles into its next destination.",
             [("LiquidPrismTabBar", "Compact by default, rows or columns"),
              ("LiquidPrismScaffold", "Bottom bar on iPhone, side rail on iPhone Duo")])
        case .toolbar:
            ("Toolbars", "A shared home for your actions.", "ellipsis.circle.fill", 0xA2845E,
             "Related actions share a single glass capsule. Each icon responds individually while the whole group lifts together.",
             [("LiquidPrismToolbarGroup", "Navigation and bottom sizes"),
              ("LiquidPrismToolbar", "Several capsules; empty groups collapse"),
              ("Items", "Materialize in and out as the list changes"),
              ("Axis", "Stacks vertically in the iPhone Duo rail")])
        case .scrollEdges:
            ("Scroll Edges", "Content softens under the bar.", "rectangle.dock", 0x0A84FF,
             "Scroll and the content under a bar blurs and fades, strongest at the edge. The glass controls see straight through it, as native bar buttons do.",
             [("LiquidPrismScrollEdge", "A bar’s effect, driven by scroll progress"),
              ("LiquidPrismScaffold", "Draws it under the top bar by default"),
              ("LiquidPrismEdgeBlur", "Progressive blur and fade of any edge"),
              ("LiquidPrismScrollFade", "Edges of a scroll view, as content passes"),
              ("LiquidPrismGroup", "Glass over the effect refracts the content, not the blur")])
        case .pages:
            ("Page Layouts", "Bars, headers and bottom bars.", "rectangle.stack", 0x5856D6,
             "Hand the scaffold your slivers and it builds the page: the bar, a large title or header, an accessory, a bottom bar, pull to refresh and the edge effects, with its glass grouped for you.",
             [("LiquidPrismScaffold.slivers", "The scaffold builds the scroll view"),
              ("header", "Your own heading, scrolling away under the bar"),
              ("bottomBar", "Pinned above the home indicator or keyboard"),
              ("onRefresh", "Native pull to refresh below the bar"),
              ("LiquidPrismSliverAppBar", "The same bar inside your own scroll view")])
        case .menus:
            ("Popup Menus", "Real native menus, right where you tap.", "list.bullet.below.rectangle", 0xFF2D55,
             "A glass button, a real native popup. Try sections, checkmarks, SF Symbols, submenus and items loaded when the menu opens. UIKit handles the presentation.",
             [("LiquidMenu", "Actions, sections, submenus, deferred items"),
              ("LiquidMenuRegion", "Context menus on long press")])
        case .search:
            ("Search Fields", "Clear your mind. Find your thing.", "magnifyingglass", 0x8E8E93,
             "A field that makes space when you need it. Type a thought, clear it, or cancel to return to the moment.",
             [("LiquidPrismSearchField", "Owned or borrowed controller"),
              ("Cancel", "Appears while focused")])
        }
    }

    /// Kinds whose page shows a Disabled section.
    var hasDisabled: Bool { [.buttons, .switches, .sliders, .segments, .toolbar].contains(self) }
}

/// Original abstract artwork, as `Art` in widgets.dart.
enum Art {
    static let names = ["Meadow", "Dusk", "Apricot"]
    /// Legible ink on each artwork.
    static let inks = [Color(hex: 0x233B36), Color(hex: 0x1F1D3D), Color(hex: 0x4A3029)]
    /// Each artwork's base color.
    static let backgrounds = [Color(hex: 0x8EBEB5), Color(hex: 0x495D96), Color(hex: 0xB57248)]
    static let palettes: [[Color]] = [
        [0x8EBEB5, 0xDAE5C8, 0xF0AF86, 0x476862],
        [0x495D96, 0xB2BDD8, 0xEEABBB, 0x3E3C71],
        [0xB57248, 0xF2CD82, 0xFAE5BF, 0x6D4E45],
    ].map { $0.map { Color(hex: $0) } }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }

    /// Flutter's `HSLColor.fromAHSL(1, hue, saturation, lightness)`.
    init(hue: Double, saturation s: Double, lightness l: Double) {
        let c = (1 - abs(2 * l - 1)) * s
        let h = hue.truncatingRemainder(dividingBy: 360) / 60
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let (r, g, b): (Double, Double, Double) = switch h {
        case ..<1: (c, x, 0)
        case ..<2: (x, c, 0)
        case ..<3: (0, c, x)
        case ..<4: (0, x, c)
        case ..<5: (x, 0, c)
        default: (c, 0, x)
        }
        let m = l - c / 2
        self.init(.sRGB, red: r + m, green: g + m, blue: b + m, opacity: 1)
    }

    /// System grouped-list colors, as `ShowcaseColors` in widgets.dart.
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let cell = Color(uiColor: .secondarySystemGroupedBackground)
    static let separator = Color(uiColor: .separator)
}
