import SwiftUI
import UIKit

func showcaseFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight)
}

/// Widest readable column on iPad and the unfolded iPhone Duo.
let readableWidth: CGFloat = 720

/// The appearance toggle and artwork menu shared by every screen, as
/// `appearanceActions` in app.dart: two items, so iOS gives them one capsule.
struct AppearanceActions: ToolbarContent {
    @Bindable var model: ShowcaseModel
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { model.dark.toggle() } label: {
                Label("Toggle appearance", systemImage: model.dark ? "sun.max" : "moon")
            }
            Menu {
                Picker("Artwork", selection: $model.wallpaper) {
                    ForEach(Art.names.indices, id: \.self) { Text(Art.names[$0]).tag($0) }
                }.pickerStyle(.inline)
            } label: {
                Label("Choose artwork", systemImage: "photo")
            }
        }
    }
}

/// A scrolling page that starts with its own large title, as `LargeTitlePage`
/// in widgets.dart. The navigation bar carries only the appearance actions, so
/// iOS draws the scroll edge effect under them. A bent iPhone Duo reports its
/// fold as a division region; the sections then reflow into two columns.
struct LargeTitlePage<Content: View>: View {
    @Environment(ShowcaseModel.self) private var model
    var title: String
    var subtitle: String?
    var identifier: String
    @ViewBuilder var content: Content
    @State private var fold: CGRect?

    var body: some View {
        ScrollViewReader { proxy in
            Group {
                if let fold {
                    Group(subviews: content) { subviews in
                        let split = (subviews.count + 1) / 2
                        HStack(spacing: 0) {
                            column(leading: 20, trailing: 20) {
                                header
                                ForEach(subviews.prefix(split)) { $0 }
                            }.frame(width: max(fold.minX, 0))
                            Color.clear.frame(width: fold.width)
                            column(leading: 20, trailing: 20) {
                                ForEach(subviews.dropFirst(split)) { $0 }
                            }
                        }
                    }
                } else {
                    column(leading: 20, trailing: 20) { header; content }
                }
            }
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
        .background { Color.groupedBackground.ignoresSafeArea() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { AppearanceActions(model: model) }
        .modifier(FoldReader(fold: $fold))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.largeTitle.bold())
                .measure(title == "Explore" ? "explore-title" : "page-title")
            if let subtitle {
                Text(subtitle).font(showcaseFont(15)).foregroundStyle(.secondary)
                    .lineSpacing(2).padding(.top, 6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 20)
    }

    private func column(leading: CGFloat, trailing: CGFloat, @ViewBuilder _ items: () -> some View) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { items() }
                .frame(maxWidth: readableWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.leading, leading).padding(.trailing, trailing)
                .padding(.top, 4).padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.immediately)
        .accessibilityIdentifier(identifier)
    }
}

/// Reads the fold of a bent iPhone Duo (iOS 27.1 division regions).
private struct FoldReader: ViewModifier {
    @Binding var fold: CGRect?
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onGeometryChange(for: CGRect?.self) { proxy in
                proxy.reservedRegions(kind: .division).map(\.frame)
                    .first { $0.height > $0.width && $0.minX > 0 && $0.maxX < proxy.size.width }
            } action: { fold = $0 }
        } else {
            content
        }
    }
}

/// Asks iOS for the iPhone Duo side bar, or for horizontal bars (iOS 27.1).
struct VerticalBarBehavior: ViewModifier {
    var enabled: Bool
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.toolbarVerticalBehavior(enabled ? .automatic : .disabled)
        } else {
            content
        }
    }
}

/// A titled inset-grouped list section, as `InsetSection` in widgets.dart.
struct InsetSection<Content: View>: View {
    var header: String?
    var footer: String?
    @ViewBuilder var content: Content
    init(_ header: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.header = header; self.footer = footer; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header {
                Text(header).font(showcaseFont(15, .semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 16).padding(.bottom, 8)
            }
            VStack(alignment: .leading, spacing: 0) {
                Group(subviews: content) { subviews in
                    ForEach(subviews) { subview in
                        if subview.id != subviews.first?.id {
                            Color.separator.frame(height: 0.5).padding(.leading, 16)
                        }
                        subview
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cell)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            if let footer {
                Text(footer).font(showcaseFont(13)).foregroundStyle(.secondary).lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16).padding(.top, 8)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 28)
    }
}

/// The contents of one list row: optional tile, title and subtitle, trailing.
struct RowContent<Trailing: View>: View {
    var title: String
    var subtitle: String?
    var icon: String?
    var iconColor: Color = Color(uiColor: .systemBlue)
    var chevron = false
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(spacing: 0) {
            if let icon {
                SymbolTile(icon: icon, color: iconColor).padding(.trailing, 14)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(showcaseFont(17)).foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle).font(showcaseFont(13)).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
            trailing.padding(.leading, 12)
            if chevron {
                Image(systemName: "chevron.forward").font(showcaseFont(17))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel)).padding(.leading, 12)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

/// A list row with an optional trailing control and no action of its own.
struct ListRow<Trailing: View>: View {
    var title: String
    var subtitle: String?
    var icon: String?
    var iconColor: Color = Color(uiColor: .systemBlue)
    @ViewBuilder var trailing: Trailing
    var body: some View {
        RowContent(title: title, subtitle: subtitle, icon: icon, iconColor: iconColor) { trailing }
    }
}

extension ListRow where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, icon: String? = nil, iconColor: Color = Color(uiColor: .systemBlue)) {
        self.init(title: title, subtitle: subtitle, icon: icon, iconColor: iconColor) { EmptyView() }
    }
}

/// A row that pushes a route, with the system list highlight while pressed.
struct NavigationRow: View {
    var route: Route
    var title: String
    var subtitle: String?
    var icon: String?
    var iconColor: Color = Color(uiColor: .systemBlue)
    var label: String?
    var body: some View {
        NavigationLink(value: route) {
            RowContent(title: title, subtitle: subtitle, icon: icon, iconColor: iconColor, chevron: true) { EmptyView() }
        }
        .buttonStyle(RowButtonStyle())
        .accessibilityLabel(label ?? title)
        .accessibilityIdentifier(label ?? title)
    }
}

/// A list row for one component, opening its page.
struct ComponentRow: View {
    var kind: ComponentKind
    var body: some View {
        NavigationRow(route: .component(kind), title: kind.title, subtitle: kind.subtitle,
                      icon: kind.icon, iconColor: kind.color, label: "Explore \(kind.title)")
            .measure("row-\(kind.rawValue)")
    }
}

/// The cell highlight UIKit lists draw under a pressed row.
struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color(uiColor: .systemGray4) : .clear)
    }
}

/// A Settings-style rounded square with a white symbol.
struct SymbolTile: View {
    var icon: String
    var color: Color
    var size: CGFloat = 30
    var body: some View {
        Image(systemName: icon).font(.system(size: size * 0.6)).foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    }
}

/// A titled slider with its value, in a list, as `SliderRow` in pages.dart.
struct SliderRow: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var display: String
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(showcaseFont(17))
                Spacer()
                Text(display).font(showcaseFont(17)).foregroundStyle(.secondary)
            }
            NativeSlider(label: title, value: $value, range: range)
        }.padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
    }
}

/// Original abstract artwork for glass to refract, as `_ArtPainter`.
struct Artwork: View {
    var variant = 0
    var body: some View {
        Canvas { context, size in
            let c = Art.palettes[variant], w = size.width, h = size.height
            let bounds = CGRect(origin: .zero, size: size)
            // Flutter Alignment.topLeft → bottomRight maps directly to these points.
            context.fill(Path(bounds), with: .linearGradient(
                Gradient(colors: [c[0], c[1]]), startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
            var rotated = context
            rotated.translateBy(x: w * 0.5, y: h * 0.48)
            rotated.rotate(by: .radians(-0.48))
            let oval = CGRect(x: w * 0.06 - w * 1.45 / 2,
                              y: h * 0.45 - h * 0.84 / 2, width: w * 1.45, height: h * 0.84)
            rotated.fill(Path(ellipseIn: oval), with: .linearGradient(
                Gradient(colors: [c[2], c[2], c[3]]),
                startPoint: CGPoint(x: oval.minX, y: oval.midY), endPoint: CGPoint(x: oval.maxX, y: oval.midY)))
            let ring = CGRect(x: -w * 0.2 - w * 1.12 / 2,
                              y: -h * 0.19 - h * 0.95 / 2, width: w * 1.12, height: h * 0.95)
            rotated.stroke(Path(ellipseIn: ring), with: .color(c[3].opacity(0.2)), lineWidth: w * 0.18)
            context.fill(Path(bounds), with: .radialGradient(
                Gradient(colors: [.white.opacity(0.4), .clear]),
                center: CGPoint(x: w * 0.8, y: h * 0.05), startRadius: 0, endRadius: w * 0.75))
        }
    }
}

/// Artwork clipped to a continuous rounded rectangle, as `ArtCanvas`.
struct ArtCanvas<Content: View>: View {
    var variant: Int
    var padding = EdgeInsets(top: 22, leading: 22, bottom: 22, trailing: 22)
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background { Artwork(variant: variant) }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

/// An uppercase label over artwork.
struct Eyebrow: View {
    let text: String
    var color: Color
    init(_ text: String, color: Color) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased()).font(showcaseFont(12, .semibold)).tracking(1.2).foregroundStyle(color)
    }
}

// A wrapping flow with the Flutter showcase's gap and order (Wrap).
struct Flow: Layout {
    var spacing: CGFloat = 12
    var runSpacing: CGFloat? = nil
    var alignment: VerticalAlignment = .center
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? 354, subviews: subviews).0
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let positions = arrange(width: bounds.width, subviews: subviews).1
        for (i, view) in subviews.enumerated() {
            view.place(at: CGPoint(x: bounds.minX + positions[i].x, y: bounds.minY + positions[i].y), proposal: .unspecified)
        }
    }
    private func arrange(width: CGFloat, subviews: Subviews) -> (CGSize, [CGPoint]) {
        var rows: [[(Int, CGSize)]] = [[]]
        var x = CGFloat.zero
        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { rows.append([]); x = 0 }
            rows[rows.count - 1].append((i, size)); x += size.width + spacing
        }
        var points = Array(repeating: CGPoint.zero, count: subviews.count)
        var y = CGFloat.zero, widest = CGFloat.zero
        for row in rows where !row.isEmpty {
            let height = row.map(\.1.height).max() ?? 0
            var x = CGFloat.zero
            for (i, size) in row {
                let dy = alignment == .center ? (height - size.height) / 2 : alignment == .bottom ? height - size.height : 0
                points[i] = CGPoint(x: x, y: y + dy); x += size.width + spacing
            }
            widest = max(widest, x - spacing)
            y += height + (runSpacing ?? spacing)
        }
        return (CGSize(width: min(width, max(widest, 0)), height: max(y - (runSpacing ?? spacing), 0)), points)
    }
}

extension View {
    /// The package's glass or prominent button treatment, as iOS draws it.
    @ViewBuilder func glassButton(prominent: Bool = false, glass: Glass = .regular) -> some View {
        if prominent {
            buttonStyle(.glassProminent).controlSize(.large)
        } else {
            buttonStyle(.glass(glass)).controlSize(.large)
        }
    }
}

struct NativeToggle: View {
    var label: String
    @Binding var value: Bool
    var body: some View {
        Toggle(label, isOn: $value).labelsHidden().fixedSize()
            .accessibilityIdentifier(label).measure(label)
    }
}

struct NativeSlider: View {
    var label: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var body: some View {
        Slider(value: $value, in: range).frame(minHeight: 44)
            .accessibilityLabel(label).accessibilityIdentifier(label).measure(label)
    }
}

struct NativeSegments: View {
    var label: String
    var labels: [String]
    @Binding var selection: Int
    /// Segments sized to their labels rather than filling the width.
    var fit = false
    var body: some View {
        let picker = Picker(label, selection: $selection) {
            ForEach(labels.indices, id: \.self) { Text(labels[$0]).tag($0) }
        }.pickerStyle(.segmented).accessibilityIdentifier(label).measure(label)
        if fit { picker.fixedSize() } else { picker }
    }
}

/// A round avatar with an initial or a symbol, as `_Avatar`.
struct Avatar: View {
    var color: Color
    var initial: String?
    var symbol: String?
    var size: CGFloat
    var body: some View {
        Circle().fill(color).frame(width: size, height: size).overlay {
            if let initial {
                Text(initial).font(.system(size: size * 0.45, weight: .semibold)).foregroundStyle(.white)
            } else if let symbol {
                Image(systemName: symbol).font(.system(size: size * 0.55)).foregroundStyle(.white)
            }
        }
    }
}

/// Colored demo rows, as the scaffold demos' HSL rows.
struct ColorRow: View {
    var text: String
    var hue: Double
    var saturation = 0.7
    var lightness = 0.6
    var height: CGFloat = 64
    var radius: CGFloat = 16
    var textColor: Color? = Color(hex: 0x111111)
    var body: some View {
        Text(text).font(showcaseFont(17)).foregroundStyle(textColor ?? .primary)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .leading)
            .background(Color(hue: hue, saturation: saturation, lightness: lightness),
                        in: RoundedRectangle(cornerRadius: radius))
    }
}
