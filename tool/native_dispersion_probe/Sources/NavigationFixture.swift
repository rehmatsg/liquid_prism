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
    if flag("--navigation-sheet") {
      Color.gray.sheet(isPresented: .constant(true)) { navigation }
    } else {
      navigation
    }
  }
  private var navigation: some View {
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
      .navigationTitle(value("--navigation-title", "Library"))
      .toolbarTitleDisplayMode(mode)
      .toolbar {
        if !flag("--no-leading") {
          ToolbarItem(placement: .topBarLeading) {
            Button("Back", systemImage: "chevron.left") { taps += 1 }
              .accessibilityIdentifier("navigation-back")
          }
        }
        if !flag("--no-trailing") {
          ToolbarItemGroup(placement: .topBarTrailing) {
            ForEach(0..<(Int(value("--trailing-count", "1")) ?? 1), id: \.self) { index in
              Button("More", systemImage: "ellipsis") { taps += 1 }
                .accessibilityIdentifier(index == 0 ? "navigation-more" : "navigation-more-\(index)")
            }
          }
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
