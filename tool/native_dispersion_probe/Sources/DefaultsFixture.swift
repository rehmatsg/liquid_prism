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
    }
}

private struct DefaultsContent: View {
    @State private var off = false
    @State private var on = true
    @State private var slider = Double(value("--slider", "0.62")) ?? 0.62
    @State private var segment = Int(value("--segment", "0")) ?? 0
    @State private var query = ""
    private let disabled = flag("--disabled")

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
                Button("Glass") {}.buttonStyle(.glass).controlSize(.large)
                    .accessibilityIdentifier("button").position(x: 105, y: 350)
                Button("Prominent") {}.buttonStyle(.glassProminent).controlSize(.large)
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
