import SwiftUI
import UIKit

@Observable final class ShowcaseModel {
    var dark = false
    var clear = false
    var labels = true
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
    var path: [ComponentKind] = []
    var query = ""
    var glass: Glass { clear ? .clear : .regular }
    var tint: Color { palette.first { $0.0 == accent }!.1 }
    var ink: Color { dark ? .white : .black }
    var muted: Color { Color(uiColor: .secondaryLabel) }
    var palette: [(String, Color)] {
        let colors: [(String, UIColor)] = [
            ("blue", .systemBlue), ("brown", .systemBrown), ("cyan", .systemCyan),
            ("green", .systemGreen), ("indigo", .systemIndigo), ("mint", .systemMint),
            ("orange", .systemOrange), ("pink", .systemPink), ("purple", .systemPurple),
            ("red", .systemRed), ("teal", .systemTeal), ("yellow", .systemYellow)
        ]
        return colors.map { ($0.0, Color(uiColor: $0.1.resolvedColor(with:
            UITraitCollection(userInterfaceStyle: dark ? .dark : .light)))) }
    }
    func reset() {
        dark = false; clear = false; labels = true; accent = "blue"
        wallpaper = 0; frost = 4; refraction = 24
    }
}

enum ComponentKind: String, CaseIterable, Identifiable {
    case surfaces, buttons, switches, sliders, segments, tabs, toolbar, menus, search, sheets
    var id: String { rawValue }
    var title: String { entry.0 }
    var subtitle: String { entry.1 }
    var icon: String { entry.2 }
    var color: Color { Color(hex: entry.3) }
    private var entry: (String, String, String, UInt32) {
        switch self {
        case .surfaces: ("Glass surfaces", "A window into what’s underneath.", "square.3.layers.3d", 0x467C73)
        case .buttons: ("Buttons", "Small actions. Satisfying feedback.", "hand.point.right", 0xBE674B)
        case .switches: ("Switches", "A familiar feel, down to the spring.", "switch.2", 0x587A4B)
        case .sliders: ("Sliders", "Find the sweet spot.", "slider.horizontal.3", 0x927137)
        case .segments: ("Segmented controls", "Slide into a different perspective.", "rectangle.split.3x1", 0x827497)
        case .tabs: ("Tab bars", "Navigation with a little lift.", "square.grid.2x2", 0x546EA2)
        case .toolbar: ("Toolbars", "A shared home for your actions.", "ellipsis", 0x8D6956)
        case .menus: ("Popup menus", "Real native menus, right where you tap.", "ellipsis.circle", 0x6B7C80)
        case .search: ("Search fields", "Clear your mind. Find your thing.", "magnifyingglass", 0x56828B)
        case .sheets: ("Sheets", "Room for the next idea.", "rectangle.on.rectangle", 0x8B6F87)
        }
    }
    var description: String {
        switch self {
        case .surfaces: "Glass bends the scene behind it while keeping your content crisp. Move the lens, then try regular, clear, and tinted materials."
        case .buttons: "An everyday action with a tactile response. Try a quiet glass button, a prominent action, or a circular favorite."
        case .switches: "Tap to change your outlook. Hold and drag the thumb to feel its lift and the spring that brings it home."
        case .sliders: "A little precision, a little play. Drag the thumb to change the value and watch it lift under your finger."
        case .segments: "A shared track with a gliding selection. Tap a perspective or hold the pill and slide to a new one."
        case .tabs: "A floating home for navigation. The selection lifts, follows your finger, and settles into its next destination."
        case .toolbar: "Related actions share a single glass capsule. Each icon responds individually while the whole group lifts together."
        case .menus: "A glass button, a real native popup. Try sections, checkmarks, SF Symbols, submenus, and items loaded when the menu opens. UIKit handles the presentation."
        case .search: "A field that makes space when you need it. Type a thought, clear it, or cancel to return to the moment."
        case .sheets: "A presentation that follows your hand. Open at half height, pull it up, scroll through, and glide it away."
        }
    }
    var hasDisabled: Bool { [.buttons, .switches, .sliders, .segments, .toolbar].contains(self) }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}
