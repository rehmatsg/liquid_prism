import SwiftUI
import UIKit

// Inline equivalents of the UIKit views used by SwiftUI's search/toolbar/tab APIs.
// The native controls own their glass and gestures; these wrappers only place them.
struct ToolbarAction {
    var title: String, symbol: String
    var menu: UIMenu? = nil
    var enabled = true
    var action: () -> Void
    init(_ title: String, _ symbol: String, menu: UIMenu? = nil, enabled: Bool = true, action: @escaping () -> Void) {
        self.title = title; self.symbol = symbol; self.menu = menu; self.enabled = enabled; self.action = action
    }
}

struct NativeToolbar: UIViewRepresentable {
    var items: [ToolbarAction]
    var navigation = false
    func makeUIView(context: Context) -> ToolbarHost { ToolbarHost(navigation: navigation) }
    func updateUIView(_ view: ToolbarHost, context: Context) {
        view.configure(items, enabled: context.environment.isEnabled)
    }
}

final class ToolbarHost: UIView {
    private let navigation: Bool
    private let navBar = UINavigationBar()
    private let toolbar = UIToolbar()
    private var configuration: String?
    init(navigation: Bool) {
        self.navigation = navigation
        super.init(frame: .zero)
        if navigation {
            let appearance = UINavigationBarAppearance(); appearance.configureWithTransparentBackground()
            navBar.standardAppearance = appearance; navBar.scrollEdgeAppearance = appearance
            addSubview(navBar)
        } else {
            let appearance = UIToolbarAppearance(); appearance.configureWithTransparentBackground()
            toolbar.standardAppearance = appearance; toolbar.scrollEdgeAppearance = appearance
            addSubview(toolbar)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(_ items: [ToolbarAction], enabled: Bool) {
        // Geometry preferences can refresh SwiftUI's representables. Replacing
        // native bar items on each refresh restarts their layout/animations.
        func menuKey(_ element: UIMenuElement) -> String {
            let state = (element as? UIAction).map { String($0.state.rawValue) } ?? ""
            return element.title + state + ((element as? UIMenu)?.children.map(menuKey).joined(separator: "/") ?? "")
        }
        let key = items.map { "\($0.title)|\($0.symbol)|\($0.enabled && enabled)|\($0.menu.map(menuKey) ?? "")" }.joined(separator: ";")
        guard configuration != key else { return }
        configuration = key
        let buttons = items.map { item in
            let button = UIBarButtonItem(title: nil, image: UIImage(systemName: item.symbol), primaryAction: item.menu == nil ? UIAction { _ in item.action() } : nil, menu: item.menu)
            button.accessibilityLabel = item.title; button.accessibilityIdentifier = item.title
            button.isEnabled = item.enabled && enabled
            return button
        }
        if navigation {
            let item = UINavigationItem(title: "")
            item.rightBarButtonItems = buttons.reversed()
            navBar.setItems([item], animated: false)
        } else { toolbar.setItems(buttons, animated: false) }
        setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        if navigation { navBar.frame = CGRect(x: -16, y: 0, width: bounds.width + 32, height: 44) }
        else { toolbar.frame = CGRect(x: -8, y: 0, width: bounds.width + 16, height: 48) }
    }
}

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
        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            parent.text = ""; searchBar.text = ""; searchBar.resignFirstResponder(); searchBar.setShowsCancelButton(false, animated: true)
        }
        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
    }
}

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

func nativeMenu(model: ShowcaseModel, selected: @escaping (String) -> Void) -> UIMenu {
    let favorite = UIAction(title: model.favorite ? "Remove favorite" : "Add to favorites", image: UIImage(systemName: "heart"), state: model.favorite ? .on : .off) { _ in model.favorite.toggle(); selected("Favorite") }
    let new = UIAction(title: "A new idea", image: UIImage(systemName: "sparkles")) { _ in model.taps += 1; selected("A new idea") }
    let art = UIMenu(title: "Artwork", image: UIImage(systemName: "photo"), options: .singleSelection, children:
        ["Meadow", "Dusk", "Apricot"].enumerated().map { i, title in
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
