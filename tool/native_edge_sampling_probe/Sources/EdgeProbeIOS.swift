// iOS version of the edge sampling probe. The scene comes from the `-scene`
// launch argument; `-dump 1` also writes the layer tree and meta.json to
// Documents/out. run_ios.sh launches one scene at a time and screenshots it.
import SwiftUI
import UIKit

struct Band: Codable {
  var y0: Double
  var y1: Double
  var gray: Double = 0
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

let marker = Band(y0: 380, y1: 382, red: true)

func allScenes() -> [ProbeScene] {
  var list: [ProbeScene] = []
  let style = "soft"
  func add(_ name: String, _ bg: Double, _ bands: [Band], text: Bool = false) {
    list.append(ProbeScene(name: style + "_" + name, background: bg, bands: bands + [marker], style: style, text: text))
  }
  add("white", 1, [])
  add("black", 0, [])
  add("gray", 0.5, [])
  for d in [2.0, 8, 24] { add("band\(Int(d))", 1, [Band(y0: -400, y1: d)]) }
  add("band8x", 1, [Band(y0: 0, y1: 8)])
  for y in [0.0, 8, 16, 32, 48, 64, 96, 128] { add("line\(Int(y))", 1, [Band(y0: y, y1: y + 4)]) }
  for y in [150.0, 160] { add("below\(Int(y))", 1, [Band(y0: y, y1: 700)]) }
  add("bband8", 1, [Band(y0: -400, y1: 8, fromBottom: true)])
  for y in [0.0, 16] { add("bline\(Int(y))", 1, [Band(y0: y, y1: y + 4, fromBottom: true)]) }
  add("stripes", 1, stride(from: 0.0, to: 300, by: 4).map { Band(y0: $0, y1: $0 + 2) })
  add("text", 1, [], text: true)
  return list
}

func gray(_ v: Double) -> Color { Color(.sRGB, white: v, opacity: 1) }

struct PatternView: View {
  let scene: ProbeScene
  let screenHeight: CGFloat
  @State private var minY: CGFloat = 0

  var body: some View {
    ZStack(alignment: .topLeading) {
      Rectangle().fill(gray(scene.background))
      ForEach(Array(scene.bands.enumerated()), id: \.offset) { _, band in
        let y0 = band.fromBottom ? screenHeight - band.y1 : band.y0
        let y1 = band.fromBottom ? screenHeight - band.y0 : band.y1
        Rectangle()
          .fill(band.red ? Color(.sRGB, red: 1, green: 0, blue: 0) : gray(band.gray))
          .frame(maxWidth: .infinity)
          .frame(height: y1 - y0)
          .offset(y: y0 - minY)
      }
      if scene.text {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(0..<30, id: \.self) { i in
            HStack(spacing: 10) {
              Rectangle().fill([Color.red, .green, .blue, .orange][i % 4]).frame(width: 60, height: 14)
              Text("Scroll edge sampling \(i) — quick brown fox")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
            }
            .frame(height: 22)
          }
        }
        .padding(.leading, 16)
        .offset(y: -9 - minY)
      }
    }
    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { minY = $0 }
  }
}

struct ContentView: View {
  let scene: ProbeScene
  let screenHeight = UIScreen.main.bounds.height

  var body: some View {
    NavigationStack {
      ScrollView {
        PatternView(scene: scene, screenHeight: screenHeight)
          .frame(height: 5000)
      }
      .defaultScrollAnchor(.center)
      .scrollEdgeEffectStyle(.soft, for: .all)
      .safeAreaBar(edge: .bottom) {
        HStack {
          Spacer()
          Button("Bottom") {}.buttonStyle(.glass)
        }
        .padding(.horizontal, 16)
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) { Button("Top") {} }
      }
    }
    .task {
      guard UserDefaults.standard.bool(forKey: "dump") else { return }
      try? await Task.sleep(for: .seconds(2))
      dump()
    }
  }

  @MainActor private func dump() {
    let out = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("out").path
    try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
    guard let window = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene }).first?.keyWindow else { return }
    PrismDumpLayers(window.layer, out, "layers_soft")
    let meta: [String: Any] = [
      "screen": NSCoder.string(for: UIScreen.main.bounds),
      "scale": UIScreen.main.scale,
      "safeArea": NSCoder.string(for: window.safeAreaInsets),
      "os": ProcessInfo.processInfo.operatingSystemVersionString,
      "scenes": (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(allScenes()))) ?? [],
    ]
    let data = try! JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted, .sortedKeys])
    try? data.write(to: URL(fileURLWithPath: out + "/meta.json"))
    try? "done".write(toFile: out + "/done", atomically: true, encoding: .utf8)
  }
}

@main
struct EdgeProbeIOSApp: App {
  let scene: ProbeScene = {
    let name = UserDefaults.standard.string(forKey: "scene") ?? "soft_white"
    return allScenes().first { $0.name == name } ?? allScenes()[0]
  }()

  var body: some Scene {
    WindowGroup { ContentView(scene: scene).preferredColorScheme(.light) }
  }
}
