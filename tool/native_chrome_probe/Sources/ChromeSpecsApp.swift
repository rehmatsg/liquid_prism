import SwiftUI

@main struct ChromeSpecsApp: App {
    init() { PrepareNativeInspection() }
    var body: some Scene {
        WindowGroup {
            ChromeFixture().preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--light") ? .light : .dark)
        }
    }
}
struct ChromeFixture: View {
    @State private var query = ""
    @State private var searching = false
    @State private var taps = 0
    var mode: String { ProcessInfo.processInfo.arguments.contains("--light") ? "light" : "dark" }
    var search: Bool { ProcessInfo.processInfo.arguments.contains("--search") }
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.cyan,.blue,.yellow], startPoint:.topLeading,endPoint:.bottomTrailing).ignoresSafeArea()
                Text("Actions: \(taps)")
            }
            .navigationTitle(search ? "Search" : "Toolbar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !search {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Favorite", systemImage: "star") { taps += 1 }.accessibilityIdentifier("favorite")
                        Button("Share", systemImage: "square.and.arrow.up") { taps += 1 }.accessibilityIdentifier("share")
                        Button("More", systemImage: "ellipsis") { taps += 1 }.accessibilityIdentifier("more")
                    }
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("Back", systemImage: "chevron.left") { taps += 1 }.accessibilityIdentifier("back")
                        Button("Forward", systemImage: "chevron.right") { taps += 1 }.accessibilityIdentifier("forward")
                        Spacer()
                        Button("Compose", systemImage: "square.and.pencil") { taps += 1 }.accessibilityIdentifier("compose")
                    }
                }
            }
            .modifier(SearchIf(enabled: search, query: $query, searching: $searching))
            .task {
                try? await Task.sleep(for:.milliseconds(800))
                StartMotionLog("chrome-\(mode)-\(search ? "search" : "toolbar")",[:],8)
                try? await Task.sleep(for:.seconds(2))
                ExtractGlass("chrome-\(mode)-\(search ? "search" : "toolbar")-rest",[:])
            }
            .onChange(of: searching) { _, value in
                if value { Task {
                    try? await Task.sleep(for:.seconds(1))
                    ExtractGlass("chrome-\(mode)-search-focused",[:])
                } }
            }
            .onChange(of: query) { _, value in
                if value == "Prism" { Task {
                    try? await Task.sleep(for:.seconds(1))
                    ExtractGlass("chrome-\(mode)-search-filled",[:])
                } }
            }
        }
    }
}
struct SearchIf: ViewModifier {
    let enabled: Bool
    @Binding var query: String
    @Binding var searching: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if enabled { content.searchable(text:$query,isPresented:$searching,prompt:"Search") }
        else { content }
    }
}
