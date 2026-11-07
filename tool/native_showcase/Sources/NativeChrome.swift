import SwiftUI
import UIKit

// Inline UIKit bars, search and tab bars for previews that sit inside page
// content. The native controls own their glass, gestures and animations;
// these wrappers only place them.

struct ToolbarAction {
    var id: String
    var title: String
    var symbol: String
    var menu: UIMenu?
    var enabled: Bool
    var action: () -> Void
    init(_ title: String, _ symbol: String, id: String? = nil, menu: UIMenu? = nil, enabled: Bool = true,
         action: @escaping () -> Void = {}) {
        self.id = id ?? title; self.title = title; self.symbol = symbol
        self.menu = menu; self.enabled = enabled; self.action = action
    }
}

/// A navigation bar (`navigation: true`) or bottom toolbar holding groups of
/// bar button items, leading-aligned. A zero fixed space separates groups so
/// each gets its own glass capsule; changes animate, as UIKit materializes
/// items and capsules in and out.
struct NativeToolbar: UIViewRepresentable {
    var groups: [[ToolbarAction]]
    var navigation = false
    func makeUIView(context: Context) -> ToolbarHost { ToolbarHost(navigation: navigation) }
    func updateUIView(_ view: ToolbarHost, context: Context) {
        view.configure(groups, enabled: context.environment.isEnabled)
    }
}

final class ToolbarHost: UIView {
    private let navigation: Bool
    private let navBar = UINavigationBar()
    private let navItem = UINavigationItem(title: "")
    private let toolbar = UIToolbar()
    private var configuration: String?
    private var buttons: [String: UIBarButtonItem] = [:]
    private var actions: [String: () -> Void] = [:]

    init(navigation: Bool) {
        self.navigation = navigation
        super.init(frame: .zero)
        if navigation {
            let appearance = UINavigationBarAppearance(); appearance.configureWithTransparentBackground()
            navBar.standardAppearance = appearance; navBar.scrollEdgeAppearance = appearance
            navBar.setItems([navItem], animated: false)
            addSubview(navBar)
        } else {
            let appearance = UIToolbarAppearance(); appearance.configureWithTransparentBackground()
            toolbar.standardAppearance = appearance; toolbar.scrollEdgeAppearance = appearance
            addSubview(toolbar)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ groups: [[ToolbarAction]], enabled: Bool) {
        for item in groups.joined() { actions[item.id] = item.action }
        // Geometry preferences can refresh SwiftUI's representables. Replacing
        // native bar items on each refresh restarts their layout/animations.
        func menuKey(_ element: UIMenuElement) -> String {
            let state = (element as? UIAction).map { String($0.state.rawValue) } ?? ""
            return element.title + state + ((element as? UIMenu)?.children.map(menuKey).joined(separator: "/") ?? "")
        }
        let key = groups.map { group in
            group.map { "\($0.id)|\($0.title)|\($0.symbol)|\($0.enabled && enabled)|\($0.menu.map(menuKey) ?? "")" }
                .joined(separator: ";")
        }.joined(separator: "#")
        guard configuration != key else { return }
        let animated = configuration != nil
        configuration = key
        var items: [UIBarButtonItem] = []
        for group in groups where !group.isEmpty {
            if !items.isEmpty { items.append(.fixedSpace(0)) }
            for item in group {
                let id = item.id
                let button = buttons[id] ?? {
                    let button = item.menu == nil
                        ? UIBarButtonItem(primaryAction: UIAction { [weak self] _ in self?.actions[id]?() })
                        : UIBarButtonItem()
                    buttons[id] = button
                    return button
                }()
                button.image = UIImage(systemName: item.symbol)
                button.title = nil
                if let menu = item.menu { button.menu = menu }
                button.accessibilityLabel = item.title
                button.accessibilityIdentifier = item.title
                button.isEnabled = item.enabled && enabled
                items.append(button)
            }
        }
        if navigation {
            navItem.setLeftBarButtonItems(items, animated: animated)
        } else {
            toolbar.setItems(items + [.flexibleSpace()], animated: animated)
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Measured on iPhone Duo (iOS 27.1): an inline navigation bar starts
        // its first capsule at its own edge; a toolbar insets it 19⅓ points.
        // The toolbar's offset cancels that so both start at the content edge.
        if navigation { navBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 44) }
        else { toolbar.frame = CGRect(x: -58.0 / 3, y: 0, width: bounds.width + 116.0 / 3, height: 48) }
    }
}

/// An inline UIKit search field with a Cancel button while focused.
struct NativeSearch: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UISearchBar {
        let bar = UISearchBar()
        bar.searchBarStyle = .minimal
        bar.delegate = context.coordinator
        bar.searchTextField.font = .systemFont(ofSize: 17)
        bar.accessibilityIdentifier = placeholder
        bar.searchTextField.accessibilityIdentifier = placeholder
        return bar
    }
    func updateUIView(_ bar: UISearchBar, context: Context) {
        context.coordinator.parent = self
        if bar.text != text { bar.text = text }
        bar.placeholder = placeholder
        bar.isUserInteractionEnabled = context.environment.isEnabled
    }
    final class Coordinator: NSObject, UISearchBarDelegate {
        var parent: NativeSearch
        init(_ parent: NativeSearch) { self.parent = parent }
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { parent.text = searchText }
        func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) { searchBar.setShowsCancelButton(true, animated: true) }
        func searchBarTextDidEndEditing(_ searchBar: UISearchBar) { searchBar.setShowsCancelButton(false, animated: true) }
        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            parent.text = ""; searchBar.text = ""; searchBar.resignFirstResponder()
        }
        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
    }
}

/// An inline UIKit tab bar with the preview's three tabs.
struct NativeTabBar: UIViewRepresentable {
    @Binding var selection: Int
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UITabBar {
        let bar = UITabBar()
        bar.delegate = context.coordinator
        bar.items = zip(["Discover", "Saved", "Home"], ["safari", "bookmark", "house"]).enumerated().map { i, entry in
            let item = UITabBarItem(title: entry.0, image: UIImage(systemName: entry.1), tag: i)
            item.accessibilityIdentifier = entry.0
            return item
        }
        let appearance = UITabBarAppearance(); appearance.configureWithTransparentBackground()
        bar.standardAppearance = appearance; bar.scrollEdgeAppearance = appearance
        return bar
    }
    func updateUIView(_ bar: UITabBar, context: Context) {
        context.coordinator.parent = self
        bar.selectedItem = bar.items?[selection]
    }
    final class Coordinator: NSObject, UITabBarDelegate {
        var parent: NativeTabBar
        init(_ parent: NativeTabBar) { self.parent = parent }
        func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) { parent.selection = item.tag }
    }
}

/// The showcase action menu as a UIMenu, with an item loaded when it opens.
func nativeMenu(model: ShowcaseModel, selected: @escaping (String) -> Void) -> UIMenu {
    let favorite = UIAction(title: model.favorite ? "Remove favorite" : "Add to favorites", image: UIImage(systemName: "heart"), state: model.favorite ? .on : .off) { _ in model.favorite.toggle(); selected("Favorite") }
    let new = UIAction(title: "A new idea", image: UIImage(systemName: "sparkles")) { _ in model.taps += 1; selected("A new idea") }
    let art = UIMenu(title: "Artwork", image: UIImage(systemName: "photo"), options: .singleSelection, children:
        Art.names.enumerated().map { i, title in
            UIAction(title: title, state: model.wallpaper == i ? .on : .off) { _ in model.wallpaper = i; selected(title) }
        })
    let deferred = UIDeferredMenuElement.uncached { completion in
        completion([UIAction(title: "\(model.taps) ideas so far", image: UIImage(systemName: "lightbulb")) { _ in selected("Idea count") }])
    }
    let unavailable = UIAction(title: "Coming soon", image: UIImage(systemName: "clock"), attributes: .disabled) { _ in }
    let reset = UIAction(title: "Reset this demo", image: UIImage(systemName: "arrow.counterclockwise"), attributes: .destructive) { _ in model.taps = 0; model.favorite = false; selected("Demo reset") }
    return UIMenu(children: [UIMenu(options: .displayInline, children: [favorite, new]), art,
        UIMenu(title: "On opening", options: .displayInline, children: [deferred]), unavailable,
        UIMenu(options: .displayInline, children: [reset])])
}

// MARK: - Scroll edges

/// A navigation bar over a scrolling list, as `ScrollEdgePreview`: a real
/// UINavigationController whose bar draws the scroll edge effect, switched
/// between the soft and hard styles by its own bar button.
struct ScrollEdgePreview: UIViewControllerRepresentable {
    var ink: UIColor
    func makeUIViewController(context: Context) -> UINavigationController {
        let navigation = UINavigationController(rootViewController: ScrollEdgeList())
        navigation.view.backgroundColor = .clear
        return navigation
    }
    func updateUIViewController(_ navigation: UINavigationController, context: Context) {
        (navigation.viewControllers.first as? ScrollEdgeList)?.ink = ink
    }
}

final class ScrollEdgeList: UIViewController {
    var ink: UIColor = .black { didSet { if oldValue != ink { recolor() } } }
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private var likes = 0
    private var hard = false
    private lazy var like = UIBarButtonItem(primaryAction: UIAction { [weak self] _ in
        self?.likes += 1; self?.update()
    })
    private lazy var edge = UIBarButtonItem(primaryAction: UIAction { [weak self] _ in
        self?.hard.toggle(); self?.update()
    })

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        scroll.backgroundColor = .clear
        scroll.accessibilityIdentifier = "scroll-edge-list"
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll); scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -12),
        ])
        for i in 0..<24 {
            let label = UILabel()
            label.text = "Row \(i + 1) stays sharp until it meets the bar"
            label.font = .systemFont(ofSize: 14, weight: .semibold)
            label.textColor = .white
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            let row = UIView()
            row.layer.cornerRadius = 14; row.layer.cornerCurve = .continuous
            row.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: row.topAnchor, constant: 16),
                label.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -16),
                label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
                label.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            ])
            stack.addArrangedSubview(row)
        }
        let back = UIBarButtonItem(image: UIImage(systemName: "chevron.backward"), primaryAction: UIAction { [weak self] _ in
            guard let scroll = self?.scroll else { return }
            scroll.setContentOffset(CGPoint(x: 0, y: -scroll.adjustedContentInset.top), animated: true)
        })
        back.accessibilityLabel = "Back to top"
        navigationItem.leftBarButtonItem = back
        navigationItem.rightBarButtonItems = [edge, like]
        setContentScrollView(scroll, for: .top)
        recolor(); update()
    }

    private func recolor() {
        for (i, row) in stack.arrangedSubviews.enumerated() {
            row.backgroundColor = ink.withAlphaComponent(i.isMultiple(of: 2) ? 0.85 : 0.6)
        }
    }

    private func update() {
        like.image = UIImage(systemName: likes % 2 == 1 ? "heart.fill" : "heart")
        like.accessibilityLabel = "Like"
        edge.image = UIImage(systemName: hard ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
        edge.accessibilityLabel = hard ? "Soft edge" : "Hard edge"
        scroll.topEdgeEffect.style = hard ? .hard : .soft
    }
}

/// An embedded tab bar controller with a large-title navigation bar, badges,
/// two capsules and a fitted segmented control, as `PackageFeaturesDemo`.
struct FeaturesDemo: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> FeaturesTabs { FeaturesTabs() }
    func updateUIViewController(_ controller: FeaturesTabs, context: Context) {}
}

final class FeaturesTabs: UITabBarController, UITabBarControllerDelegate, UIGestureRecognizerDelegate {
    private let names = ["Inbox", "Saved"]
    private var inboxes: [FeaturesInbox] = []
    private var held: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        // Both tabs show the same inbox, as the Flutter demo's single body.
        viewControllers = zip(names, ["tray", "bookmark"]).enumerated().map { i, entry in
            let inbox = FeaturesInbox()
            inboxes.append(inbox)
            let navigation = UINavigationController(rootViewController: inbox)
            navigation.navigationBar.prefersLargeTitles = true
            navigation.tabBarItem = UITabBarItem(title: entry.0, image: UIImage(systemName: entry.1), tag: i)
            return navigation
        }
        viewControllers?.first?.tabBarItem.badgeValue = "125"
        // Reports which tab is held; the tab bar keeps its own gestures.
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(hold(_:)))
        hold.cancelsTouchesInView = false
        hold.delegate = self
        tabBar.addGestureRecognizer(hold)
        refresh()
    }

    @objc private func hold(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        var index = recognizer.location(in: tabBar).x < tabBar.bounds.midX ? 0 : 1
        if tabBar.effectiveUserInterfaceLayoutDirection == .rightToLeft { index = 1 - index }
        held = names[index]
        refresh()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        refresh()
    }

    private func refresh() {
        let message = held.map { "Held \($0); selection remains \(names[selectedIndex])." }
            ?? "Scroll to collapse the title. Hold a tab for its action."
        inboxes.forEach { $0.message = message }
    }
}

final class FeaturesInbox: UITableViewController {
    var message = "" {
        didSet { if isViewLoaded, oldValue != message { tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none) } }
    }
    private var segment = 0

    init() { super.init(style: .plain) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Inbox"
        navigationItem.largeTitleDisplayMode = .always
        let activity = UIBarButtonItem(image: UIImage(systemName: "bell"), primaryAction: UIAction { _ in })
        activity.badge = .indicator()
        activity.accessibilityLabel = "Activity"
        let share = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), primaryAction: UIAction { _ in })
        share.accessibilityLabel = "Share"
        let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), primaryAction: UIAction { _ in })
        more.accessibilityLabel = "More"
        // Right items run from the trailing edge: [share, more] then [activity].
        navigationItem.rightBarButtonItems = [more, share, .fixedSpace(0), activity]
        tableView.backgroundColor = .systemGroupedBackground
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "text")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "segment")
    }

    private var expanded = false
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // SwiftUI sizes the embedded controller after loading it; let the bar
        // lay out its large title again once the view has its real size.
        guard !expanded, view.bounds.height > 200 else { return }
        expanded = true
        navigationController?.navigationBar.sizeToFit()
        tableView.setContentOffset(CGPoint(x: 0, y: -tableView.adjustedContentInset.top), animated: false)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 18 }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "segment", for: indexPath)
            cell.backgroundColor = .clear
            if cell.contentView.subviews.isEmpty {
                let control = UISegmentedControl(items: ["All", "Unread messages"])
                control.apportionsSegmentWidthsByContent = true
                control.selectedSegmentIndex = segment
                control.addAction(UIAction { [weak self, weak control] _ in
                    self?.segment = control?.selectedSegmentIndex ?? 0
                }, for: .valueChanged)
                control.translatesAutoresizingMaskIntoConstraints = false
                cell.contentView.addSubview(control)
                NSLayoutConstraint.activate([
                    control.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
                    control.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 4),
                    control.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -4),
                ])
            }
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "text", for: indexPath)
        cell.backgroundColor = .clear
        var content = UIListContentConfiguration.cell()
        content.text = indexPath.row == 0 ? message : "Message \(indexPath.row - 1)"
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        cell.contentConfiguration = content
        return cell
    }
}

/// A horizontal row of chips, as `ScrollFadePreview`. iOS has no public fade
/// for a scroll view's edges outside bars, so the row asks for the soft scroll
/// edge effect and shows whatever the system draws there.
struct ScrollFadePreview: View {
    var ink: Color
    static let names = ["Meadow", "Dusk", "Apricot", "Harbor", "Moss", "Ember", "Slate", "Lilac", "Sand", "Tide",
                        "Fern", "Plum", "Clay", "Mist"]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.names, id: \.self) { name in
                    Text(name).font(showcaseFont(14)).foregroundStyle(ink)
                        .padding(.horizontal, 16).frame(height: 44)
                        .overlay { Capsule().strokeBorder(ink.opacity(0.35), lineWidth: 1) }
                }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .horizontal)
        .frame(height: 44)
        .accessibilityIdentifier("scroll-fade")
    }
}
