import SwiftUI

/// Mirrors `ExplorePage` in pages.dart.
struct ExplorePage: View {
    @Environment(ShowcaseModel.self) private var model
    var body: some View {
        @Bindable var model = model
        LargeTitlePage(title: "Explore", subtitle: "Liquid glass for Flutter, made to feel native.",
                       identifier: "showcase-scroll") {
            ExploreHero().measure("hero-canvas")
            Color.clear.frame(height: 32)
            InsetSection("Try it") {
                ListRow(title: "A brighter idea", icon: "lightbulb.fill", iconColor: Color(uiColor: .systemYellow)) {
                    NativeToggle(label: "A brighter idea", value: $model.enabled)
                }
                SliderRow(title: "Intensity", value: $model.level,
                          display: "\(Int((model.level * 100).rounded()))%")
                Flow(spacing: 12) {
                    Button("Try a button") { model.taps += 1 }
                        .glassButton(prominent: true).labelled("Try a button")
                    FavoriteButton()
                    Text(model.taps == 0 ? "Hold to feel the lift." : "\(model.taps) \(model.taps == 1 ? "tap" : "taps")")
                        .font(showcaseFont(15)).foregroundStyle(.secondary)
                }.padding(16)
            }.id("explore-controls").measure("explore-controls")
            InsetSection("Featured") {
                ForEach([ComponentKind.surfaces, .tabs, .scrollEdges]) { ComponentRow(kind: $0) }
            }
        }
    }
}

/// The artwork card at the top of Explore, as `ExploreHero`.
struct ExploreHero: View {
    @Environment(ShowcaseModel.self) private var model
    var body: some View {
        let ink = Art.inks[model.wallpaper]
        ArtCanvas(variant: model.wallpaper, padding: EdgeInsets(top: 20, leading: 20, bottom: 18, trailing: 20)) {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(Art.names[model.wallpaper], color: ink)
                VStack(spacing: 0) {
                    Image(systemName: "sparkles").font(showcaseFont(30))
                    Text("Hello, glass.").font(showcaseFont(24, .bold)).tracking(0.2).padding(.top, 8)
                    Text("A fresh perspective.").font(showcaseFont(15))
                        .foregroundStyle(Color(hex: 0x3C3C43).opacity(0.6)).padding(.top, 4)
                }
                .foregroundStyle(.black).multilineTextAlignment(.center)
                .padding(.horizontal, 24).padding(.vertical, 22).fixedSize()
                .glassEffect(model.glass, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .measure("hero-glass")
                .frame(maxWidth: .infinity).padding(.top, 28)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { caption(ink); Spacer(minLength: 0); makeItYours }
                    VStack(alignment: .leading, spacing: 14) { caption(ink); makeItYours }
                }.padding(.top, 28)
            }
        }
    }
    private func caption(_ ink: Color) -> some View {
        Text("Real refraction,\nright on the artwork.").font(showcaseFont(15)).lineSpacing(2)
            .foregroundStyle(ink).fixedSize()
    }
    private var makeItYours: some View {
        Button("Make it yours") { model.tab = 1 }.glassButton(prominent: true).labelled("Make it yours")
    }
}

/// Mirrors `StudioPage` in pages.dart.
struct StudioPage: View {
    @Environment(ShowcaseModel.self) private var model
    var body: some View {
        @Bindable var model = model
        LargeTitlePage(title: "Studio", subtitle: "Shape the glass. Every screen follows.",
                       identifier: "showcase-scroll") {
            LensPlayground(expert: true)
            Text("Drag the glass across the artwork.").font(showcaseFont(13)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 28)
            InsetSection("Appearance") {
                ListRow(title: "Dark appearance", icon: "moon.fill", iconColor: Color(uiColor: .systemIndigo)) {
                    NativeToggle(label: "Dark appearance", value: $model.dark)
                }
                ListRow(title: "Clear material", icon: "drop.fill", iconColor: Color(uiColor: .systemCyan)) {
                    NativeToggle(label: "Clear material", value: $model.clear)
                }
                // Only where iOS has a vertical bar, such as iPhone Duo.
                if #available(iOS 27.1, *) { VerticalBarRow() }
                ListRow(title: "Sidebar", subtitle: "Tabs in a sidebar on wide windows", icon: "sidebar.left",
                        iconColor: Color(uiColor: .systemPurple)) {
                    NativeToggle(label: "Sidebar", value: $model.sidebar)
                }
                ListRow(title: "Tab labels", icon: "textformat", iconColor: Color(uiColor: .systemOrange)) {
                    NativeToggle(label: "Tab labels", value: $model.labels)
                }
            }.id("look-feel").measure("look-feel")
            InsetSection("Accent", footer: "Buttons, switches and the selected tab use your accent.") {
                Flow(spacing: 12) {
                    ForEach(ShowcaseModel.accents, id: \.0) { entry in
                        let selected = model.accent == entry.0
                        Button { model.accent = entry.0 } label: {
                            Circle().fill(entry.1).frame(width: 36, height: 36)
                                .overlay { if selected { Circle().strokeBorder(Color.cell, lineWidth: 3) } }
                                .background { if selected { Circle().fill(entry.1).padding(-2) } }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Use \(entry.0) tint")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }.padding(16)
            }.id("palette").measure("palette")
            InsetSection("Optics", footer: "Frost and refraction apply to the canvas above.") {
                SliderRow(title: "Frost", value: $model.frost, range: 0...12,
                          display: String(format: "%.1f", model.frost))
                SliderRow(title: "Refraction", value: $model.refraction, range: 0...64,
                          display: "\(Int(model.refraction.rounded()))")
            }.id("optics").measure("optics")
            InsetSection("Artwork") {
                NativeSegments(label: "Artwork", labels: Art.names, selection: $model.wallpaper).padding(16)
            }.id("artwork").measure("artwork")
            InsetSection {
                Button { model.reset() } label: {
                    Text("Restore Defaults").font(showcaseFont(17)).foregroundStyle(Color(uiColor: .systemRed))
                        .frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
                }.buttonStyle(RowButtonStyle()).labelled("Restore defaults")
            }
        }
    }
}

/// The iPhone Duo side bar switch. Shown where iOS reports a vertical bar
/// edge, and kept while the bar is off so it can be turned back on.
@available(iOS 27.1, *)
struct VerticalBarRow: View {
    @Environment(\.toolbarVerticalEdge) private var edge
    @Environment(ShowcaseModel.self) private var model
    var body: some View {
        @Bindable var model = model
        if edge != nil || !model.verticalBar {
            ListRow(title: "Side bar", subtitle: "Bars beside the content on iPhone Duo", icon: "sidebar.right",
                    iconColor: Color(uiColor: .systemGreen)) {
                NativeToggle(label: "Side bar", value: $model.verticalBar)
            }
        }
    }
}

/// Mirrors `LibraryPage` in pages.dart.
struct LibraryPage: View {
    @Environment(ShowcaseModel.self) private var model
    var results: [ComponentKind] {
        let query = model.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ComponentKind.allCases.filter { query.isEmpty || "\($0.title) \($0.subtitle)".lowercased().contains(query) }
    }
    var body: some View {
        @Bindable var model = model
        let results = results
        LargeTitlePage(title: "Library", subtitle: "Every component, with a live preview.",
                       identifier: "showcase-scroll") {
            NativeSearch(text: $model.query, placeholder: "Search components")
                .frame(height: 48).measure("library-search")
            Color.clear.frame(height: 24)
            if results.isEmpty {
                InsetSection {
                    VStack(spacing: 0) {
                        Text("Nothing here just yet.").font(showcaseFont(20, .semibold))
                        Text("Try “glass”, “slider” or “button”.").font(showcaseFont(15))
                            .foregroundStyle(.secondary).padding(.top, 6)
                        Button("Clear Search") { model.query = "" }
                            .glassButton(glass: model.glass).labelled("Reset library search").padding(.top, 16)
                    }
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    .padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 18)
                }
            } else {
                InsetSection("\(results.count) \(results.count == 1 ? "component" : "components")") {
                    ForEach(results) { ComponentRow(kind: $0) }
                }
            }
        }
    }
}

/// A circular glass favorite button, as `FavoriteButton`.
struct FavoriteButton: View {
    @Environment(ShowcaseModel.self) private var model
    var body: some View {
        Button { model.favorite.toggle() } label: {
            Image(systemName: model.favorite ? "heart.fill" : "heart").font(showcaseFont(22))
                .foregroundStyle(model.favorite ? AnyShapeStyle(Color(uiColor: .systemPink)) : AnyShapeStyle(.tint))
        }
        .buttonStyle(.glass(model.glass)).buttonBorderShape(.circle).controlSize(.large)
        .labelled("Favorite")
        .accessibilityAddTraits(model.favorite ? .isSelected : [])
    }
}

extension View {
    /// The Flutter widget's semantics label, also used as the test identifier
    /// and the inspection geometry key.
    func labelled(_ label: String) -> some View {
        accessibilityLabel(label).accessibilityIdentifier(label).measure(label)
    }
}
