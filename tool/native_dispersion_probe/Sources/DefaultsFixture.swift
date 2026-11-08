import SwiftUI
import UIKit

struct DefaultsFixture: View {
    @State private var tab = Int(value("--tab", "0")) ?? 0
    var body: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house.fill", value: 0) { DefaultsContent() }
            Tab("Search", systemImage: "magnifyingglass", value: 1) { DefaultsContent() }
            Tab("Profile", systemImage: "person.fill", value: 2) { DefaultsContent() }
        }
        .tint(Color(uiColor: .systemBlue))
        .disabled(flag("--disabled"))
        .onPreferenceChange(ButtonGeometry.self) { frames in
            guard flag("--button-size") else { return }
            let values = frames.mapValues { [$0.minX, $0.minY, $0.width, $0.height] }
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("button-sizes.json")
            if let data = try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys]) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
}

private struct DefaultsContent: View {
    @State private var off = false
    @State private var on = true
    @State private var slider = Double(value("--slider", "0.62")) ?? 0.62
    @State private var segment = Int(value("--segment", "0")) ?? 0
    @State private var query = ""
    private let disabled = flag("--disabled")
    private let buttonSize: ControlSize = {
        switch value("--button-size", "large") {
        case "mini": return .mini
        case "small": return .small
        case "regular": return .regular
        case "extraLarge": return .extraLarge
        default: return .large
        }
    }()

    var body: some View {
        GeometryReader { geometry in
            let center = geometry.size.width / 2
            ZStack(alignment: .topLeading) {
                background
                Text("Regular").font(.system(size: 17))
                    .frame(width: 150, height: 48).glassEffect(.regular, in: .capsule)
                    .position(x: 105, y: 140)
                Text("Clear").font(.system(size: 17))
                    .frame(width: 150, height: 48).glassEffect(.clear, in: .capsule)
                    .position(x: center * 2 - 105, y: 140)
                Text("Surface").font(.system(size: 17))
                    .frame(width: 150, height: 96)
                    .glassEffect(.regular, in: .rect(cornerRadius: 28))
                    .position(x: 105, y: 250)
                Text("Tinted").font(.system(size: 17))
                    .frame(width: 150, height: 96)
                    .glassEffect(.regular.tint(Color(uiColor: .systemBlue).opacity(0.3)), in: .rect(cornerRadius: 28))
                    .position(x: center * 2 - 105, y: 250)
                Button {} label: { Text("Glass").buttonGeometry("label") }
                    .buttonStyle(.glass).controlSize(buttonSize).buttonGeometry("button")
                    .accessibilityIdentifier("button").position(x: 105, y: 350)
                Button("Prominent") {}.buttonStyle(.glassProminent).controlSize(buttonSize)
                    .accessibilityIdentifier("prominent").position(x: center * 2 - 105, y: 350)
                Toggle("Off", isOn: $off).labelsHidden().accessibilityIdentifier("off")
                    .frame(width: 63, height: 44).position(x: 105, y: 430)
                Toggle("On", isOn: $on).labelsHidden().accessibilityIdentifier("on")
                    .frame(width: 63, height: 44).position(x: center * 2 - 105, y: 430)
                Slider(value: $slider).accessibilityIdentifier("slider")
                    .frame(width: 342, height: 44).position(x: center, y: 510)
                Picker("Segments", selection: $segment) {
                    Text("First").tag(0); Text("Second").tag(1); Text("Third").tag(2)
                }.pickerStyle(.segmented).accessibilityIdentifier("segments")
                    .frame(width: 342, height: 44).position(x: center, y: 590)
                DefaultsSearch(text: $query).frame(width: 342, height: 44)
                    .position(x: center, y: 670)
                if flag("--button-size") {
                    Button("Favorite", systemImage: "heart") {}.labelStyle(.iconOnly)
                        .buttonStyle(.glass).buttonBorderShape(.circle).controlSize(buttonSize)
                        .buttonGeometry("icon").position(x: center, y: 750)
                }
            }
            .disabled(disabled)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder private var background: some View {
        switch value("--pattern", "grouped") {
        case "grouped": Color(uiColor: .systemGroupedBackground)
        case "cell": Color(uiColor: .secondarySystemGroupedBackground)
        case "base": Color(uiColor: .systemBackground)
        default: Backdrop()
        }
    }
}

private struct ButtonGeometry: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private extension View {
    func buttonGeometry(_ name: String) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(key: ButtonGeometry.self, value: [name: proxy.frame(in: .global)])
            }
        }
    }
}

private struct DefaultsSearch: UIViewRepresentable {
    @Binding var text: String
    func makeUIView(context: Context) -> UISearchBar {
        let view = UISearchBar()
        view.searchBarStyle = .minimal
        view.placeholder = "Search"
        return view
    }
    func updateUIView(_ view: UISearchBar, context: Context) { view.text = text }
}
