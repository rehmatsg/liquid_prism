import SwiftUI

@available(iOS 27.0, *)
struct NavigationFixture: View {
  @State private var taps = 0
  private var mode: ToolbarTitleDisplayMode {
    switch value("--title-mode", "large") {
    case "inline": .inline
    case "inlineLarge": .inlineLarge
    default: .large
    }
  }
  private var minimization: ToolbarMinimizationBehavior {
    switch value("--minimization", "never") {
    case "onScrollDown": .onScrollDown
    case "onScrollUp": .onScrollUp
    case "automatic": .automatic
    default: .never
    }
  }
  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(0..<80) { index in
            Text("Row \(index)")
              .frame(maxWidth: .infinity, alignment: .leading)
              .frame(height: 52)
              .padding(.horizontal, 20)
              .accessibilityIdentifier("navigation-row-\(index)")
          }
        }
      }
      .accessibilityIdentifier("navigation-scroll")
      .background(NavigationSampler())
      .navigationTitle("Library")
      .toolbarTitleDisplayMode(mode)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Back", systemImage: "chevron.left") { taps += 1 }
            .accessibilityIdentifier("navigation-back")
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("More", systemImage: "ellipsis") { taps += 1 }
            .accessibilityIdentifier("navigation-more")
        }
      }
      .toolbarMinimizationBehavior(minimization, for: .navigationBar)
      .toolbarMinimizationRestoration(
        flag("--restore-at-edge") ? .atScrollEdge : .automatic, for: .navigationBar
      )
      .toolbarMinimizationSafeAreaAdjustment(
        flag("--fixed-insets") ? .disabled : .automatic, for: .navigationBar)
    }
  }
}
