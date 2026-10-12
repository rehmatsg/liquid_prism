import SwiftUI
import UIKit

func showcaseFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight)
}

struct Backdrop: View {
    @Environment(ShowcaseModel.self) private var model
    var body: some View {
        GeometryReader { proxy in
            (model.dark ? Color(hex: 0x151B20) : Color(hex: 0xF5F3ED))
                .overlay {
                    RadialGradient(colors: [
                        (model.dark ? Color(hex: 0x315652) : Color(hex: 0xC9DED1)).opacity(0.45), .clear
                    ], center: UnitPoint(x: 1, y: 80 / proxy.size.height),
                       startRadius: 0, endRadius: proxy.size.width * 0.95)
                }
        }.ignoresSafeArea()
    }
}

struct Artwork: View {
    var variant = 0
    static let palettes: [[Color]] = [
        [0x8EBEB5, 0xDAE5C8, 0xF0AF86, 0x476862],
        [0x495D96, 0xB2BDD8, 0xEEABBB, 0x3E3C71],
        [0xB57248, 0xF2CD82, 0xFAE5BF, 0x6D4E45]
    ].map { $0.map { Color(hex: $0) } }
    var body: some View {
        Canvas { context, size in
            let c = Self.palettes[variant], w = size.width, h = size.height
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

struct Eyebrow: View {
    let text: String
    var color: Color = Color(uiColor: .secondaryLabel)
    init(_ text: String, color: Color = Color(uiColor: .secondaryLabel)) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased()).font(showcaseFont(10, .bold))
            .tracking(1.8).foregroundStyle(color).fixedSize(horizontal: false, vertical: true)
    }
}

struct Note: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(showcaseFont(13)).foregroundStyle(Color(uiColor: .secondaryLabel))
            .lineSpacing(3.34).fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 1.667)
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(showcaseFont(22, .semibold)).tracking(-0.6) }
}

struct Panel<Content: View>: View {
    @Environment(ShowcaseModel.self) private var model
    var padding: CGFloat = 20
    @ViewBuilder let content: Content
    var body: some View {
        content.frame(maxWidth: .infinity, alignment: .leading).padding(padding)
            .background(model.dark ? Color(hex: 0x20292C) : Color(hex: 0xFCFBF7),
                        in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(model.ink.opacity(0.055), lineWidth: 1) }
    }
}

// A wrapping flow with exactly the Flutter showcase's gap and order.
struct Flow: Layout {
    var spacing: CGFloat = 12
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
        var x = CGFloat.zero, y = CGFloat.zero, row = CGFloat.zero
        var points: [CGPoint] = []
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += row + spacing; row = 0 }
            points.append(CGPoint(x: x, y: y)); x += size.width + spacing; row = max(row, size.height)
        }
        return (CGSize(width: width, height: y + row), points)
    }
}

struct NativeButton<Content: View>: View {
    @Environment(ShowcaseModel.self) private var model
    var label: String
    var prominent = false
    var glass: Glass? = nil
    var circle = false
    var action: () -> Void
    @ViewBuilder var content: Content
    var body: some View {
        Group {
            if prominent {
                Button(action: action) { content }.buttonStyle(.glassProminent)
            } else {
                Button(action: action) { content }.buttonStyle(.glass(glass ?? model.glass))
            }
        }.buttonBorderShape(circle ? .circle : .capsule)
            .controlSize(.regular).tint(model.tint).font(showcaseFont(14, .semibold))
            .foregroundStyle(prominent ? Color.white : model.tint)
            .accessibilityLabel(label).accessibilityIdentifier(label).measure(label)
    }
}

struct ActionButton: View {
    var text: String, icon: String? = nil, prominent = false, label: String? = nil
    var action: () -> Void
    var body: some View {
        NativeButton(label: label ?? text, prominent: prominent, action: action) {
            HStack(spacing: 8) { Text(text); if let icon { Image(systemName: icon).font(showcaseFont(16)) } }
                .padding(.horizontal, 4).padding(.vertical, 6)
        }
    }
}

struct IconAction: View {
    var icon: String, label: String
    var action: () -> Void
    var body: some View {
        NativeButton(label: label, circle: true, action: action) {
            Image(systemName: icon).font(showcaseFont(19)).frame(width: 31, height: 31).foregroundStyle(.primary)
        }
    }
}

struct ComponentRow: View {
    var kind: ComponentKind
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Panel(padding: 17) {
                HStack(spacing: 14) {
                    Image(systemName: kind.icon).font(showcaseFont(23)).foregroundStyle(kind.color)
                        .frame(width: 48, height: 48)
                        .background(kind.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind.title).font(showcaseFont(16, .semibold)).foregroundStyle(.primary)
                        Note(kind.subtitle)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "arrow.up.right").font(showcaseFont(16)).foregroundStyle(.secondary)
                }
            }
        }.buttonStyle(.plain).accessibilityLabel("Explore \(kind.title)")
            .accessibilityIdentifier("Explore \(kind.title)").measure("row-\(kind.rawValue)")
    }
}

struct NativeToggle: View {
    var label: String
    @Binding var value: Bool
    var body: some View {
        Toggle(label, isOn: $value).labelsHidden().frame(width: 63, height: 44)
            .accessibilityIdentifier(label).measure(label)
    }
}

struct NativeSlider: View {
    var label: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var fill = false
    var body: some View {
        Slider(value: $value, in: range).frame(height: 44)
            .frame(maxWidth: fill ? .infinity : 300, alignment: .leading).accessibilityLabel(label)
            .accessibilityIdentifier(label).measure(label)
    }
}

struct NativeSegments: View {
    var label: String, labels: [String]
    @Binding var selection: Int
    var fill = false
    var body: some View {
        Picker(label, selection: $selection) {
            ForEach(labels.indices, id: \.self) { Text(labels[$0]).tag($0) }
        }.pickerStyle(.segmented).frame(height: 44)
            .frame(maxWidth: fill ? .infinity : 300, alignment: .leading).accessibilityIdentifier(label).measure(label)
    }
}
