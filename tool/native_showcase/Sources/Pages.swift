import SwiftUI

struct ExplorePage: View {
    @Environment(ShowcaseModel.self) private var model
    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("An interactive collection").padding(.top, 10)
            VStack(alignment: .leading, spacing: 0) {
                Text("A little glass.").fixedSize().frame(height: 40)
                Text("A lot of possibility.").fixedSize().frame(height: 40)
            }.font(showcaseFont(38, .semibold)).tracking(-1.8)
                .measure("explore-title").padding(.top, 13)
            Note("Beautifully tactile components.\nMade for the way you move.").padding(.top, 14)
            HeroCanvas().measure("hero-canvas").padding(.top, 24)
            Flow(spacing: 10) {
                ActionButton(text: "Make it yours", icon: "arrow.up.right", prominent: true) { model.tab = 1 }
                ActionButton(text: "All components") { model.tab = 2 }
            }.padding(.top, 17)
            SectionTitle("Made to be touched").padding(.top, 32)
            Note("A few favorites. Go ahead, play.").padding(.top, 6)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                Panel {
                    VStack(alignment: .leading, spacing: 0) {
                        Eyebrow("01 / Controls")
                        HStack {
                            Text("A brighter idea").fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .leading)
                            NativeToggle(label: "A brighter idea", value: $model.enabled)
                        }.padding(.top, 16)
                        NativeSlider(label: "Preview intensity", value: $model.level).padding(.top, 12)
                        HStack { Note("A little or a lot"); Spacer(); Note("\(Int((model.level * 100).rounded()))%") }.padding(.top, 4)
                    }
                }.id("explore-controls").measure("explore-controls")
                Panel {
                    VStack(alignment: .leading, spacing: 0) {
                        Eyebrow("02 / Actions")
                        Text("Good things, on tap.").font(showcaseFont(20, .semibold)).tracking(-0.5).padding(.top, 16)
                        Flow {
                            ActionButton(text: "Try a button", icon: "plus", prominent: true) { model.taps += 1 }
                            NativeButton(label: "Favorite", circle: true, action: { model.favorite.toggle() }) {
                                Image(systemName: model.favorite ? "heart.fill" : "heart").font(showcaseFont(21)).frame(width: 35, height: 35)
                            }
                        }.padding(.top, 16)
                        Note(model.taps == 0 ? "Press and hold to feel the lift." : "\(model.taps) \(model.taps == 1 ? "tap" : "taps"). One more?").padding(.top, 12)
                    }
                }
            }.padding(.top, 16)
            SectionTitle("The collection").padding(.top, 30)
            VStack(spacing: 14) {
                ForEach([ComponentKind.surfaces, .tabs, .search]) { kind in
                    ComponentRow(kind: kind) { model.path.append(kind) }
                }
            }.padding(.top, 14)
            Eyebrow("Thoughtfully made. Delightfully fluid.").frame(maxWidth: .infinity).padding(.top, 20)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HeroCanvas: View {
    @Environment(ShowcaseModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("Light, with a life of its own", color: Color(hex: 0x314D47))
            HStack {
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    Image(systemName: "sparkles").font(showcaseFont(32)).frame(height: 32)
                    Text("Hello, glass.").font(showcaseFont(23, .semibold)).tracking(-0.7).padding(.top, 9)
                    Text("A fresh perspective.").font(showcaseFont(12)).padding(.top, 5)
                }.foregroundStyle(.black).padding(.horizontal, 25).padding(.vertical, 22)
                    .frame(maxWidth: 230).fixedSize()
                    .glassEffect(model.glass, in: RoundedRectangle(cornerRadius: 27, style: .continuous)).measure("hero-glass")
                Spacer(minLength: 0)
            }.offset(x: 8).padding(.top, 25)
            HStack {
                Text("LIVE MATERIAL").font(showcaseFont(9, .bold)).tracking(1.4).foregroundStyle(Color(hex: 0x314D47))
                Spacer(minLength: 12)
                NativeToolbar(items: [ToolbarAction("Change artwork", "arrow.trianglehead.2.clockwise.rotate.90") { model.wallpaper = (model.wallpaper + 1) % 3 }], navigation: true)
                    .frame(width: 46, height: 44)
            }.padding(.top, 19)
        }.padding(22).background { Artwork(variant: model.wallpaper) }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
}

struct StudioPage: View {
    @Environment(ShowcaseModel.self) private var model
    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("Your creative playground")
            Text("Find your feel.").font(showcaseFont(36, .semibold)).tracking(-1.4).padding(.top, 12)
            Note("Change the light. Shift the color. Make it yours.").padding(.top, 10)
            LensPlayground(expert: true).padding(.top, 22)
            Note("Drag the glass across the artwork.").frame(maxWidth: .infinity).padding(.top, 8)
            VStack(spacing: 14) {
                Panel {
                    VStack(alignment: .leading, spacing: 18) {
                        Eyebrow("Look & feel")
                        SettingRow(title: "Dark appearance", subtitle: "A different kind of glow.", value: $model.dark)
                        SettingRow(title: "Clear material", subtitle: "Let more of the world through.", value: $model.clear)
                        SettingRow(title: "Tab labels", subtitle: "Keep a little context.", value: $model.labels)
                    }
                }.id("look-feel").measure("look-feel")
                Panel {
                    VStack(alignment: .leading, spacing: 0) {
                        Eyebrow("A color story")
                        Note("Native palette. Your signature accent.").padding(.top, 12)
                        Flow {
                            ForEach(model.palette, id: \.0) { entry in
                                Button { model.accent = entry.0 } label: {
                                    Circle().fill(entry.1).frame(width: 40, height: 40)
                                        .overlay { if model.accent == entry.0 { Image(systemName: "checkmark").font(showcaseFont(19)).foregroundStyle(.white) } }
                                }.buttonStyle(.plain).accessibilityLabel("Use \(entry.0) tint")
                            }
                        }.padding(.top, 18)
                        Note("Selected: \(model.accent)").padding(.top, 14)
                    }
                }.id("palette").measure("palette")
                Panel {
                    VStack(alignment: .leading, spacing: 0) {
                        Eyebrow("The optics")
                        HStack { Text("Frost").fontWeight(.semibold); Spacer(); Note(String(format: "%.1f", model.frost)) }.padding(.top, 16)
                        NativeSlider(label: "Frost", value: $model.frost, range: 0...12)
                        HStack { Text("Refraction").fontWeight(.semibold); Spacer(); Note("\(Int(model.refraction.rounded()))") }.padding(.top, 10)
                        NativeSlider(label: "Refraction", value: $model.refraction, range: 0...64)
                        Note("These adjustments affect the glass in this canvas.")
                    }
                }.id("optics").measure("optics")
                Panel {
                    VStack(alignment: .leading, spacing: 0) {
                        Eyebrow("Behind the glass")
                        NativeSegments(label: "Artwork", labels: ["Meadow", "Dusk", "Apricot"], selection: $model.wallpaper).padding(.top, 16)
                        Note("Three original canvases. A new view every time.").padding(.top, 16)
                        ActionButton(text: "Restore defaults", icon: "arrow.counterclockwise") { model.reset() }.padding(.top, 16)
                    }
                }.id("artwork").measure("artwork")
            }.padding(.top, 24)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingRow: View {
    var title: String, subtitle: String
    @Binding var value: Bool
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(showcaseFont(15, .semibold)); Note(subtitle)
            }.frame(maxWidth: .infinity, alignment: .leading)
            NativeToggle(label: title, value: $value)
        }
    }
}

struct LibraryPage: View {
    @Environment(ShowcaseModel.self) private var model
    var results: [ComponentKind] {
        let query = model.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ComponentKind.allCases.filter { "\($0.title) \($0.subtitle)".lowercased().contains(query) || query.isEmpty }
    }
    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow("The complete collection")
            Text("The building blocks.").font(showcaseFont(36, .semibold)).tracking(-1.4).padding(.top, 12)
            Note("Ten components. Endless possibilities.\nOpen one to get a feel for every detail.").padding(.top, 10)
            NativeSearch(text: $model.query, placeholder: "Find a component").frame(height: 48).padding(.top, 22).measure("library-search")
            Eyebrow("\(results.count) \(results.count == 1 ? "component" : "components")").padding(.top, 22)
            if results.isEmpty {
                Panel {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Nothing here just yet.").font(showcaseFont(20, .semibold))
                        Note("Try “glass”, “slider”, or “button”.").padding(.top, 8)
                        ActionButton(text: "Clear search", label: "Reset library search") { model.query = "" }.padding(.top, 16)
                    }
                }.padding(.top, 12)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                ForEach(results) { kind in ComponentRow(kind: kind) { model.path.append(kind) } }
            }.padding(.top, 12)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
