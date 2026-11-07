import Darwin
import SwiftUI

/// UIKit's glass tint amount: the Liquid Glass setting (Settings > Appearance
/// > Liquid Glass on iOS 27). Research only.
enum TintAmount {
  private static let everyImage = UnsafeMutableRawPointer(bitPattern: -2)

  /// The getter returns an NSNumber: 0, 0.5 and 1 at the slider's lowest,
  /// middle and highest positions.
  static func read() -> NSNumber? {
    guard let pointer = dlsym(everyImage, "UIViewGlassGetTintAmount") else { return nil }
    let getter = unsafeBitCast(pointer, to: (@convention(c) () -> Unmanaged<AnyObject>?).self)
    return getter()?.takeUnretainedValue() as? NSNumber
  }

  /// The setter's argument type is unknown, so the value goes both as an
  /// NSNumber (x0) and as a double (d0); the setter reads whichever it takes.
  static func write(_ value: Double) -> Bool {
    guard let pointer = dlsym(everyImage, "UIViewGlassSetTintAmount") else { return false }
    let setter = unsafeBitCast(pointer, to: (@convention(c) (NSNumber, Double) -> Void).self)
    setter(NSNumber(value: value), value)
    return true
  }
}

/// --scene tint: system glass (glass shapes, glass and prominent buttons, a
/// toolbar item and a tab bar) over the chosen backdrop. Each time the app
/// becomes active, after the setting may have changed in Settings, it rebuilds
/// the glass and dumps every layer's filters as `current-<tint amount>`.
/// UIViewGlassSetTintAmount does not change the value in-process (tried on an
/// iOS 27.2 iPhone Duo: 0.5 and 1 still read 0), so the slider is moved in
/// Settings.
struct TintFixture: View {
  @State private var generation = 0
  @State private var status = "starting"

  var body: some View {
    TabView {
      Tab("Glass", systemImage: "circle.fill") {
        NavigationStack {
          ZStack {
            Backdrop()
            VStack(spacing: 20) {
              Text("Regular").frame(width: 160, height: 48)
                .glassEffect(.regular, in: .capsule)
              Text("Clear").frame(width: 160, height: 48)
                .glassEffect(.clear, in: .capsule)
              Button("Glass") {}.buttonStyle(.glass)
              Button("Prominent") {}.buttonStyle(.glassProminent)
              Text(status).font(.caption).padding(8).background(.background)
            }
          }
          .navigationTitle("Tint")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button("More", systemImage: "ellipsis") {}
            }
          }
        }
      }
      Tab("Second", systemImage: "square") { Backdrop() }
    }
    .id(generation)
    .task { await capture() }
    .onReceive(
      NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
    ) { _ in Task { await capture() } }
  }

  @MainActor private func capture() async {
    generation += 1  // Rebuild every glass layer under the current value.
    try? await Task.sleep(for: .seconds(2))
    let value = TintAmount.read()?.stringValue ?? "nil"
    DumpFilters("current-\(value)")
    status = "captured tint amount \(value)"
  }
}
