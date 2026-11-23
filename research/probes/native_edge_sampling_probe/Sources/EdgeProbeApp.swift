// Measures how the native scroll edge effect fills the blur where its kernel
// reaches past the window edge. Every scene paints horizontal bands fixed in
// window coordinates (independent of scroll), then the window is captured
// with screencapture and the effect's layer tree is dumped.
import AppKit
import SwiftUI

struct Band: Codable {
  var y0: Double
  var y1: Double
  var gray: Double = 0
  /// Measured from the window's bottom edge instead of its top.
  var fromBottom = false
  var red = false
}

struct ProbeScene: Codable {
  var name: String
  var background: Double
  var bands: [Band]
  var style = "soft"
  var text = false
}

/// A red reference line far from both edges, to map points to image rows.
let marker = Band(y0: 380, y1: 382, red: true)

func stripes() -> [Band] {
  stride(from: 0.0, to: 300, by: 4).map { Band(y0: $0, y1: $0 + 2) }
}

func allScenes() -> [ProbeScene] {
  var list: [ProbeScene] = []
  func add(_ style: String, _ name: String, _ bg: Double, _ bands: [Band], text: Bool = false) {
    list.append(ProbeScene(name: style + "_" + name, background: bg, bands: bands + [marker], style: style, text: text))
  }
  // .soft explicitly: .hard is the OS 27 default.
  let s = ProcessInfo.processInfo.environment["PROBE_STYLE"] ?? "soft"
  add(s, "white", 1, [])
  add(s, "black", 0, [])
  add(s, "gray", 0.5, [])
  // Black from far above the window down to d pt below its top edge.
  for d in [2.0, 8, 24] { add(s, "band\(Int(d))", 1, [Band(y0: -400, y1: d)]) }
  // Same on-screen pixels as band8 but white above the window edge.
  add(s, "band8x", 1, [Band(y0: 0, y1: 8)])
  // A 4 pt black line s pt below the top edge.
  for y in [0.0, 8, 16, 24, 32, 44] { add(s, "line\(Int(y))", 1, [Band(y0: y, y1: y + 4)]) }
  // Black from y down, to see whether content below the pocket bleeds in.
  for y in [48.0, 52, 56] { add(s, "below\(Int(y))", 1, [Band(y0: y, y1: 700)]) }
  // Bottom edge equivalents.
  add(s, "bband8", 1, [Band(y0: -400, y1: 8, fromBottom: true)])
  for y in [0.0, 16] { add(s, "bline\(Int(y))", 1, [Band(y0: y, y1: y + 4, fromBottom: true)]) }
  add(s, "stripes", 1, stripes())
  add(s, "text", 1, [], text: true)
  return list
}

func edgeStyle(_ name: String) -> ScrollEdgeEffectStyle {
  switch name {
  case "hard": .hard
  case "auto": .automatic
  default: .soft
  }
}

func gray(_ v: Double) -> Color { Color(.sRGB, white: v, opacity: 1) }

@MainActor
final class Probe: ObservableObject {
  static let shared = Probe()
  @Published var scene = allScenes()[0]
  @Published var windowHeight: CGFloat = 760
  let out = ProcessInfo.processInfo.environment["PROBE_OUT"]
    ?? FileManager.default.currentDirectoryPath + "/out"
  private var started = false

  func start() {
    guard !started else { return }
    started = true
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(1.2))
      guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }) else {
        print("no window"); exit(1)
      }
      window.setFrame(NSRect(x: 160, y: 60, width: 640, height: 760), display: true)
      NSApp.activate(ignoringOtherApps: true)
      window.makeKeyAndOrderFront(nil)
      try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
      windowHeight = window.contentView!.bounds.height
      try? await Task.sleep(for: .seconds(1.0))
      var dumped: Set<String> = []
      for scene in allScenes() {
        self.scene = scene
        try? await Task.sleep(for: .seconds(0.9))
        if !dumped.contains(scene.style) {
          dumped.insert(scene.style)
          var root = window.contentView!.layer!
          while let up = root.superlayer { root = up }
          PrismDumpLayers(root, out, "layers_" + scene.style)
          var views = ""
          dumpViews(window.contentView!.superview ?? window.contentView!, depth: 0, into: &views)
          try? views.write(toFile: "\(out)/views_\(scene.style).txt", atomically: true, encoding: .utf8)
        }
        capture(window.windowNumber, to: "\(out)/\(scene.name).png")
      }
      let meta: [String: Any] = [
        "windowFrame": NSStringFromRect(window.frame),
        "contentBounds": NSStringFromRect(window.contentView!.bounds),
        "backingScale": window.backingScaleFactor,
        "screen": NSStringFromRect(window.screen?.frame ?? .zero),
        "os": ProcessInfo.processInfo.operatingSystemVersionString,
        "scenes": (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(allScenes()))) ?? [],
      ]
      let data = try! JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted, .sortedKeys])
      try? data.write(to: URL(fileURLWithPath: "\(out)/meta.json"))
      NSApp.terminate(nil)
    }
  }

  /// screencapture sometimes fails to read a window; retry a few times.
  private func capture(_ window: Int, to path: String) {
    for _ in 0..<4 {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
      process.arguments = ["-x", "-o", "-l", "\(window)", path]
      try? process.run()
      process.waitUntilExit()
      if FileManager.default.fileExists(atPath: path) { return }
      Thread.sleep(forTimeInterval: 0.4)
    }
    print("capture failed: \(path)")
  }

  private func dumpViews(_ view: NSView, depth: Int, into text: inout String) {
    let frame = view.convert(view.bounds, to: nil)
    text += String(repeating: "  ", count: depth)
      + "\(type(of: view)) \(NSStringFromRect(frame)) layer=\(view.layer.map { String(describing: type(of: $0)) } ?? "-")\n"
    for sub in view.subviews { dumpViews(sub, depth: depth + 1, into: &text) }
  }
}

struct PatternView: View {
  let scene: ProbeScene
  let windowHeight: CGFloat
  @State private var minY: CGFloat = 0

  var body: some View {
    ZStack(alignment: .topLeading) {
      Rectangle().fill(gray(scene.background))
      ForEach(Array(scene.bands.enumerated()), id: \.offset) { _, band in
        let y0 = band.fromBottom ? windowHeight - band.y1 : band.y0
        let y1 = band.fromBottom ? windowHeight - band.y0 : band.y1
        Rectangle()
          .fill(band.red ? Color(.sRGB, red: 1, green: 0, blue: 0) : gray(band.gray))
          .frame(maxWidth: .infinity)
          .frame(height: y1 - y0)
          .offset(y: y0 - minY)
      }
      if scene.text {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(0..<24, id: \.self) { i in
            HStack(spacing: 12) {
              Rectangle().fill([Color.red, .green, .blue, .orange][i % 4]).frame(width: 120, height: 14)
              Text("Scroll edge sampling \(i) — the quick brown fox")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
            }
            .frame(height: 22)
          }
        }
        .padding(.leading, 100)
        .offset(y: -9 - minY)
      }
    }
    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { minY = $0 }
  }
}

struct ContentView: View {
  @ObservedObject var probe = Probe.shared

  var body: some View {
    ScrollView {
      PatternView(scene: probe.scene, windowHeight: probe.windowHeight)
        .frame(height: 5000)
    }
    .defaultScrollAnchor(.center)
    .scrollEdgeEffectStyle(edgeStyle(probe.scene.style), for: .all)
    .safeAreaBar(edge: .bottom) {
      HStack {
        Spacer()
        Button("Bottom") {}
      }
      .padding(12)
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) { Button("Top") {} }
    }
    .toolbar(removing: .title)
    .onAppear { probe.start() }
  }
}

@main
struct EdgeProbeApp: App {
  init() {
    NSApplication.shared.setActivationPolicy(.regular)
    NSApplication.shared.appearance = NSAppearance(named: .aqua)
  }

  var body: some Scene {
    WindowGroup { ContentView() }
      .defaultSize(width: 640, height: 760)
      .windowToolbarStyle(.unified)
  }
}
