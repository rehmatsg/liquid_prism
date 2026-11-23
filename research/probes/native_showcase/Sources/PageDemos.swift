import SwiftUI

/// Every pushed screen hides the tab bar, as the Flutter routes cover it.
struct RouteView: View {
    var route: Route
    var body: some View {
        Group {
            switch route {
            case .component(let kind): ComponentPage(kind: kind)
            case .scaffoldLab: ScaffoldLabPage()
            case .header: HeaderPage()
            case .conversation: ConversationPage()
            case .sliverBar: SliverBarPage()
            case .search: SearchPage()
            }
        }.toolbar(.hidden, for: .tabBar)
    }
}

/// A navigation subtitle only while `text` is set.
private struct OptionalSubtitle: ViewModifier {
    var text: String?
    func body(content: Content) -> some View {
        if let text { content.navigationSubtitle(text) } else { content }
    }
}

/// A full-width glass action in a bottom bar, as the scaffold's `bottomBar`.
private struct BottomAction: View {
    @Environment(ShowcaseModel.self) private var model
    var title: String
    var label: String
    var identifier: String?
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) { Text(title).frame(maxWidth: .infinity) }
            .glassButton(glass: model.glass)
            .accessibilityLabel(label).accessibilityIdentifier(identifier ?? label)
            .padding(.horizontal, 16).padding(.vertical, 8)
    }
}

// MARK: - Scaffold Lab

/// Mirrors `ScaffoldLabPage`: one page with every page-level option
/// switchable live, built from NavigationStack's own bar and toolbar items.
struct ScaffoldLabPage: View {
    enum Heading: Hashable { case large, header, inline }
    enum EdgeVariant: Hashable { case soft, hard, off }

    @Environment(ShowcaseModel.self) private var model
    @State private var heading = Heading.large
    @State private var edge = EdgeVariant.soft
    @State private var accessory = false
    @State private var bottomBar = true
    @State private var twoCapsules = true
    @State private var badges = true
    @State private var refresh = true
    @State private var subtitle = false
    @State private var segment = 0
    @State private var refreshed = 0
    @State private var sheet = false

    var body: some View {
        refreshable(page.modifier(OptionalSubtitle(text: subtitle ? "Every page option, live" : nil)))
            .sheet(isPresented: $sheet) { NavigationStack { SheetPage() } }
    }

    /// Pull to refresh only while the option is on.
    @ViewBuilder private func refreshable(_ content: some View) -> some View {
        if refresh {
            content.refreshable {
                try? await Task.sleep(for: .milliseconds(900))
                refreshed += 1
            }
        } else {
            content
        }
    }

    private var page: some View {
        content
            .background { Color.groupedBackground.ignoresSafeArea() }
            .navigationTitle("Scaffold Lab")
            .navigationBarTitleDisplayMode(heading == .inline ? .inline : .large)
            .toolbar { toolbar }
            .scrollEdgeEffectStyle(edge == .hard ? .hard : .soft, for: .all)
            .scrollEdgeEffectHidden(edge == .off, for: .all)
            .safeAreaBar(edge: .top) { accessoryBar }
            .safeAreaBar(edge: .bottom) { bottom }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                options
                Button { sheet = true } label: { Text("Open in a Sheet").frame(maxWidth: .infinity) }
                    .glassButton(glass: model.glass)
                    .accessibilityLabel("Open the same page in a sheet").accessibilityIdentifier("lab-open-sheet")
                    .padding(.bottom, 20)
                if refreshed > 0 {
                    Text("Refreshed \(refreshed) \(refreshed == 1 ? "time" : "times").")
                        .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.bottom, 16)
                }
                LazyVStack(spacing: 8) {
                    ForEach(0..<24, id: \.self) { i in
                        ColorRow(text: "Row \(i): scroll it under the bar", hue: Double(i * 23 % 360))
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 8)
        }
    }

    @ViewBuilder private var options: some View {
        InsetSection("Heading") {
            choice("Style", $heading, [(.large, "Large title"), (.header, "Header"), (.inline, "Inline")])
        }
        InsetSection("Edge effect",
                     footer: "Content under the bar blurs and fades. The glass refracts it as it is, before the effect.") {
            choice("Variant", $edge, [(.soft, "Soft"), (.hard, "Hard"), (.off, "Off")])
        }
        InsetSection("Chrome") {
            toggle("Accessory row", $accessory)
            toggle("Bottom bar", $bottomBar)
            toggle("Two capsules", $twoCapsules)
            toggle("Badges", $badges)
            toggle("Pull to refresh", $refresh)
            toggle("Subtitle", $subtitle)
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if heading == .header {
            ToolbarItem(placement: .largeTitle) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scaffold Lab").font(showcaseFont(30, .bold))
                    Text("A header of your own that scrolls away under the bar.")
                        .font(showcaseFont(15)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Inbox", systemImage: "tray") {}.badge(badges ? 3 : 0)
        }
        if twoCapsules { ToolbarSpacer(.fixed, placement: .topBarTrailing) }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Share", systemImage: "square.and.arrow.up") {}
            Button("More", systemImage: "ellipsis") {}
        }
    }

    @ViewBuilder private var accessoryBar: some View {
        if accessory {
            NativeSegments(label: "Accessory", labels: ["Overview", "Activity", "Notes"],
                           selection: $segment, fit: true)
                .frame(maxWidth: .infinity).frame(height: 48)
        }
    }

    @ViewBuilder private var bottom: some View {
        if bottomBar { BottomAction(title: "Continue", label: "Primary action", identifier: "lab-bottom-action") }
    }

    private func choice<T: Hashable>(_ title: String, _ value: Binding<T>, _ options: [(T, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(showcaseFont(17))
            Picker(title, selection: value) {
                ForEach(options, id: \.0) { Text($0.1).tag($0.0) }
            }.pickerStyle(.segmented).fixedSize().accessibilityIdentifier(title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func toggle(_ title: String, _ value: Binding<Bool>) -> some View {
        ListRow(title: title) {
            Toggle(title, isOn: value).labelsHidden().fixedSize().accessibilityIdentifier("lab-\(title)")
        }
    }
}

/// Mirrors `_SheetPage`: the same kind of page presented in a sheet.
struct SheetPage: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(0..<20, id: \.self) { i in
                    ColorRow(text: "Sheet row \(i)", hue: Double(i * 31 % 360), saturation: 0.6, lightness: 0.62,
                             height: 56, radius: 14, textColor: nil)
                }
            }.padding(.horizontal, 16)
        }
        .background { Color.groupedBackground.ignoresSafeArea() }
        .navigationTitle("Sheet")
        .navigationSubtitle("Scaffold with sheet: true")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button(role: .close) { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) { Button("Done", systemImage: "checkmark") { dismiss() } }
        }
    }
}

// MARK: - Header Page

/// Mirrors `HeaderPage`: a header that scrolls away before the inline title
/// appears (the bar's large-title slot), sticky tabs pinned below the bar, a
/// trailing pill, pull to refresh and a bottom bar.
struct HeaderPage: View {
    @State private var tab = 0
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                Section {
                    ForEach(0..<30, id: \.self) { i in
                        ColorRow(text: "Detail \(i)", hue: Double(i * 23 % 360)).padding(.bottom, 8)
                    }.padding(.horizontal, 16)
                } header: {
                    NativeSegments(label: "header-tabs", labels: ["Overview", "Activity", "Notes"],
                                   selection: $tab, fit: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 12)
                        .frame(height: 56)
                        .background(Color.groupedBackground)
                }
            }
        }
        .background { Color.groupedBackground.ignoresSafeArea() }
        .navigationTitle("Glass Surfaces")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .largeTitle) {
                HStack(spacing: 14) {
                    SymbolTile(icon: "square.3.layers.3d", color: Color(hex: 0x30B0C7))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Glass Surfaces").font(showcaseFont(28, .bold))
                        Text("A window into what’s underneath.").font(showcaseFont(15)).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            // The subtitle belongs to the collapsed title only.
            ToolbarItem(placement: .subtitle) { Text("Component") }
            ToolbarItem(placement: .topBarTrailing) {
                Text("12 left").font(showcaseFont(13, .semibold)).foregroundStyle(Color(uiColor: .systemBlue))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color(uiColor: .systemBlue).opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                    .fixedSize()
                    .accessibilityIdentifier("header-trailing")
            }.sharedBackgroundVisibility(.hidden)
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Save", systemImage: "bookmark") {}
                Button("More", systemImage: "ellipsis") {}
            }
        }
        .safeAreaBar(edge: .bottom) { BottomAction(title: "Use This Surface", label: "Use this surface") }
        .refreshable { try? await Task.sleep(for: .seconds(1)) }
    }
}

// MARK: - Conversation

/// Mirrors `ConversationPage`: a one-to-one chat whose principal toolbar item
/// is an avatar above a tappable name, which iOS draws in a glass capsule.
/// Tapping it switches to a group chat with a small avatar in the capsule, a
/// glass Invite text button and a More action.
struct ConversationPage: View {
    @State private var direct = true

    static let directMessages: [(Bool, String)] = [
        (false, "Are we still on for coffee on Saturday?"),
        (true, "Yes! The café by the park at ten?"),
        (false, "Perfect. I will bring the book I mentioned."),
        (true, "Great, I would love to hear what you thought of it."),
        (false, "See you then."),
    ]
    static let groupMessages: [(Bool, String)] = [
        (false, "This month’s pick is in the shared folder."),
        (true, "Thanks! Three chapters in and enjoying it."),
        (false, "Should we ask Sam to join us next time?"),
        (true, "Good idea, I will send an invite."),
        (false, "Same time next month, then."),
    ]

    var body: some View {
        let messages = direct ? Self.directMessages : Self.groupMessages
        ScrollView {
            VStack(spacing: 0) {
                Text("Tap the name to switch the title layout").font(showcaseFont(13)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    .padding(.top, direct ? 24 : 4).padding(.bottom, 12)
                LazyVStack(spacing: 10) {
                    ForEach(0..<messages.count * 3, id: \.self) { index in
                        let (mine, text) = messages[index % messages.count]
                        Text(text).font(showcaseFont(17))
                            .foregroundStyle(mine ? Color.white : Color.primary)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(mine ? Color(uiColor: .systemBlue) : Color(uiColor: .tertiarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 20))
                            .frame(maxWidth: 280, alignment: mine ? .trailing : .leading)
                            .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
                    }
                }.padding(.horizontal, 16).padding(.bottom, 32)
            }
        }
        .background { Color(uiColor: .systemBackground).ignoresSafeArea() }
        .navigationTitle(direct ? "Maya" : "Book Club")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                // iOS draws no capsule for a principal item on its own and
                // does not grow the bar for it; the glass button style draws
                // the capsule, tucked under the avatar.
                VStack(spacing: -6) {
                    if direct {
                        Avatar(color: Color(uiColor: .systemTeal), initial: "M", size: 64)
                            .accessibilityHidden(true).zIndex(1)
                    }
                    Button { withAnimation { direct.toggle() } } label: {
                        HStack(spacing: 10) {
                            if !direct {
                                Avatar(color: Color(uiColor: .systemIndigo), symbol: "book.fill", size: 26)
                            }
                            Text(direct ? "Maya" : "Book Club").font(.headline).foregroundStyle(Color.primary)
                        }
                    }
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("conversation-title")
                }
            }
            if !direct {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Invite") {}.accessibilityIdentifier("conversation-invite")
                }
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if direct {
                    Button("Call", systemImage: "phone") {}
                } else {
                    Button("More", systemImage: "ellipsis") {}
                }
            }
        }
    }
}

// MARK: - Sliver App Bar

/// Mirrors `SliverBarPage`: a large title that collapses with the scroll,
/// two capsules and a segmented accessory under the bar.
struct SliverBarPage: View {
    @State private var segment = 0
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(0..<40, id: \.self) { i in
                    ColorRow(text: "Row \(i): fine detail to show the glass", hue: Double(i * 23 % 360))
                }
            }.padding(.horizontal, 16)
        }
        .accessibilityIdentifier("sliver-bar-scroll")
        .background { Color.groupedBackground.ignoresSafeArea() }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Activity", systemImage: "bell") {}.badge(Text(""))
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Share", systemImage: "square.and.arrow.up") {}
                Button("More", systemImage: "ellipsis") {}
            }
        }
        .safeAreaBar(edge: .top) {
            NativeSegments(label: "Collection", labels: ["All", "Saved"], selection: $segment, fit: true)
                .frame(maxWidth: .infinity).frame(height: 48)
        }
    }
}

// MARK: - Search Page

/// Mirrors `SearchPage`: a page that only searches. The field is SwiftUI's
/// navigation-bar search field, always shown under the bar; cancelling the
/// search closes the page.
struct SearchPage: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ShowcaseModel.self) private var model
    @State private var query = ""
    @State private var searching = false
    /// Set while a result opens, so only Cancel closes the page.
    @State private var opening = false
    @FocusState private var focused: Bool

    static let ideas: [(String, String)] = [
        ("Morning light", "Warm glass over a sunrise wallpaper"),
        ("Night mode", "Dark glass with a deeper rim"),
        ("A fresh start", "Reset every control to its default"),
        ("Frosted panel", "Heavy blur behind a toolbar"),
        ("Clear lens", "Unfrosted glass that only refracts"),
        ("Tinted capsule", "Accent colour through the glass"),
        ("Floating tabs", "A compact bar over scrolling content"),
        ("Side rail", "Tabs in a column on wide windows"),
        ("Soft edge", "Content blurs and fades under the bar"),
        ("Hard edge", "A flat backdrop with a hairline"),
        ("Held slider", "The knob lifts and grows on touch"),
        ("Quiet switch", "Toggles with no haptics"),
        ("Segment pill", "Labels bend under the lifted lens"),
        ("Native menu", "A UIKit menu from a glass button"),
        ("Badged inbox", "Counts and dots on tabs and actions"),
        ("Large title", "Scrolls away into the inline title"),
        ("Keyboard once", "Padding that counts the keyboard once"),
        ("Reduce motion", "Springs settle without travel"),
        ("Right to left", "Every control mirrored"),
        ("Big text", "Controls grow with the text size"),
    ]

    var body: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let q = trimmed.lowercased()
        let matches = { (title: String, subtitle: String) in q.isEmpty || "\(title) \(subtitle)".lowercased().contains(q) }
        let found = ComponentKind.allCases.filter { matches($0.title, $0.subtitle) }
        let ideas = Self.ideas.filter { matches($0.0, $0.1) }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if found.isEmpty && ideas.isEmpty {
                    VStack(spacing: 0) {
                        Image(systemName: "magnifyingglass").font(showcaseFont(44)).foregroundStyle(.secondary)
                        Text("No results for “\(trimmed)”").font(showcaseFont(20, .semibold)).padding(.top, 12)
                        Text("Check the spelling or try a new search.").font(showcaseFont(15))
                            .foregroundStyle(.secondary).padding(.top, 6)
                    }.multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 48)
                }
                if !found.isEmpty {
                    InsetSection("Components") {
                        ForEach(found) { kind in
                            Button {
                                opening = true; focused = false
                                model.path.append(.component(kind))
                            } label: {
                                RowContent(title: kind.title, subtitle: kind.subtitle, icon: kind.icon,
                                           iconColor: kind.color, chevron: true) { EmptyView() }
                            }
                            .buttonStyle(RowButtonStyle())
                            .accessibilityLabel(kind.title).accessibilityIdentifier(kind.title)
                        }
                    }
                }
                if !ideas.isEmpty {
                    InsetSection(q.isEmpty ? "Suggestions" : "Ideas") {
                        ForEach(ideas, id: \.0) { ListRow(title: $0.0, subtitle: $0.1) }
                    }
                }
            }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
        .background { Color.groupedBackground.ignoresSafeArea() }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, isPresented: $searching,
                    placement: .navigationBarDrawer(displayMode: .always), prompt: "Components and ideas")
        .searchFocused($focused)
        .onChange(of: searching) { was, now in
            // The page only searches: cancelling closes it.
            if was && !now && !opening { dismiss() }
        }
        .onAppear { opening = false }
        .refreshable { try? await Task.sleep(for: .seconds(1)) }
        .safeAreaBar(edge: .bottom) {
            if !q.isEmpty {
                BottomAction(title: "Show \(found.count + ideas.count) results", label: "Show results",
                             identifier: "search-page-done") { focused = false }
            }
        }
    }
}
