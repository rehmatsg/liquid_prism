import XCTest

/// Drives example/lib/parity_main.dart (bundle dev.rehmatsg.liquidPrismExample)
/// for tool/glass_parity. Each frame the app announces "ready <seq> ..." on the
/// accessibility element `parity-status`; the test screenshots it (XCTest
/// attachment) and taps to advance until "done <seq> ...". Screenshots are
/// self-describing through the app's code strip.
///
/// Environment (pass with TEST_RUNNER_ prefixes through xcodebuild):
///   PARITY_AMOUNTS      launch-argument sweep, e.g. "0,0.05,...,1"
///   PARITY_APPEARANCES  default "light,dark"
///   PARITY_PATTERNS     default "all"
///   PARITY_LAYOUT       "default" or "ladder"
///   PARITY_POSITIONS    Settings slider positions (default 11)
///   PARITY_WATCH_MINUTES  watch-mode duration (default 20)
final class ParityTests: XCTestCase {
  private let bundle = "dev.rehmatsg.liquidPrismExample"
  private var env: [String: String] { ProcessInfo.processInfo.environment }
  private var appearances: String { env["PARITY_APPEARANCES"] ?? "light,dark" }
  private var patterns: String { env["PARITY_PATTERNS"] ?? "all" }
  private var layout: String { env["PARITY_LAYOUT"] ?? "default" }

  override func setUp() {
    continueAfterFailure = true
    XCUIDevice.shared.orientation = .portrait
  }

  private func status(_ app: XCUIApplication) -> String {
    let element = app.descendants(matching: .any).matching(identifier: "parity-status").firstMatch
    return element.exists ? element.label : ""
  }

  private func seq(_ label: String) -> Int {
    let parts = label.split(separator: " ")
    return parts.count > 1 ? Int(parts[1]) ?? -1 : -1
  }

  private func wait(_ app: XCUIApplication, _ timeout: TimeInterval, _ match: (String) -> Bool) -> String? {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
      let label = status(app)
      if match(label) { return label }
      Thread.sleep(forTimeInterval: 0.15)
    } while Date() < deadline
    return nil
  }

  private func note(_ text: String) {
    let attachment = XCTAttachment(string: text)
    attachment.name = "note"
    attachment.lifetime = .keepAlways
    add(attachment)
    print("PARITY \(text)")
  }

  /// Screenshots every frame after [after] until the app reports done.
  /// Returns the last sequence number, or nil when no frame arrived.
  @discardableResult
  private func captureAll(_ app: XCUIApplication, after: Int, tag: String, firstTimeout: TimeInterval = 90)
    -> Int?
  {
    var last = after
    var timeout = firstTimeout
    while true {
      guard
        let label = wait(app, timeout, {
          ($0.hasPrefix("ready ") && self.seq($0) > last) || ($0.hasPrefix("done ") && self.seq($0) == last && last > after)
        })
      else {
        note("\(tag): no frame after seq \(last); status '\(status(app))'")
        return last > after ? last : nil
      }
      if label.hasPrefix("done ") {
        note("\(tag): \(label)")
        return last
      }
      let shot = XCUIScreen.main.screenshot()
      let attachment = XCTAttachment(data: shot.pngRepresentation, uniformTypeIdentifier: "public.png")
      attachment.name = "\(tag) \(label).png"
      attachment.lifetime = .keepAlways
      add(attachment)
      last = seq(label)
      timeout = 60
      // Left screen edge, clear of every layout's glass.
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)).tap()
    }
  }

  private func launchParity(_ extra: [String]) -> XCUIApplication {
    let app = XCUIApplication(bundleIdentifier: bundle)
    app.launchArguments = ["--parity-appearances", appearances, "--parity-patterns", patterns,
      "--parity-layout", layout] + extra
    app.launch()
    return app
  }

  /// Process-local amounts through `-UIViewGlassTintAmount`.
  func testSweep() throws {
    let amounts = (env["PARITY_AMOUNTS"] ?? "0,0.25,0.5,0.75,1").split(separator: ",").map(String.init)
    for (i, amount) in amounts.enumerated() {
      // The first launch clears Documents/parity so the pulled dumps are this run's.
      let app = launchParity(["-UIViewGlassTintAmount", amount] + (i == 0 ? ["--parity-clean"] : []))
      XCTAssertNotNil(captureAll(app, after: 0, tag: "\(layout)-arg-t\(amount)"), "amount \(amount)")
      app.terminate()
    }
  }

  // MARK: Settings > Appearance > Liquid Glass

  private func tapRow(_ settings: XCUIApplication, _ names: [String]) -> Bool {
    for _ in 0..<6 {
      for name in names {
        for element in [settings.cells[name], settings.staticTexts[name], settings.buttons[name]]
        where element.exists && element.isHittable {
          element.tap()
          return true
        }
      }
      settings.swipeUp()
    }
    return false
  }

  private func glassSlider(_ settings: XCUIApplication) -> XCUIElement? {
    for _ in 0..<5 {
      let sliders = settings.sliders.allElementsBoundByIndex
      if let named = sliders.first(where: { $0.label.localizedCaseInsensitiveContains("glass") }) { return named }
      if sliders.count == 1 { return sliders[0] }
      if tapRow(settings, ["Liquid Glass"]), settings.sliders.firstMatch.waitForExistence(timeout: 3) {
        continue
      }
      settings.swipeUp()
    }
    return nil
  }

  /// Opens the slider from Settings' root and moves it to [position].
  private func setSlider(_ settings: XCUIApplication, _ position: Double) -> String? {
    settings.terminate()
    settings.launch()
    guard tapRow(settings, ["Appearance", "Display & Brightness"]) else {
      note("Settings: no Appearance row\n\(settings.debugDescription)")
      return nil
    }
    Thread.sleep(forTimeInterval: 1)
    guard let slider = glassSlider(settings) else {
      note("Settings: no Liquid Glass slider\n\(settings.debugDescription)")
      return nil
    }
    // adjust(toNormalizedSliderPosition:) lands off target (0.25 read 35 % on
    // the iOS 27 simulator), so correct by the reading a few times.
    // The correction is damped: an undamped step oscillated on the phone.
    var request = position
    var reading = ""
    for attempt in 0..<8 {
      slider.adjust(toNormalizedSliderPosition: CGFloat(min(max(request, 0), 1)))
      Thread.sleep(forTimeInterval: 0.8)
      reading = slider.value as? String ?? "\(slider.value ?? "")"
      guard let percent = Double(reading.filter { $0.isNumber || $0 == "." }) else { break }
      let error = position - percent / 100
      if abs(error) < 0.005 { break }
      request += error * (attempt < 2 ? 0.7 : 0.4)
    }
    return reading
  }

  /// Dumps Settings' hierarchy at the root and in Appearance (navigation aid).
  func testSettingsExplore() throws {
    let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    settings.terminate()
    settings.launch()
    note("root\n\(settings.debugDescription)")
    if tapRow(settings, ["Appearance", "Display & Brightness"]) {
      Thread.sleep(forTimeInterval: 1)
      note("appearance\n\(settings.debugDescription)")
      if let slider = glassSlider(settings) {
        note("slider '\(slider.label)' value \(String(describing: slider.value))\n\(settings.debugDescription)")
      }
    }
  }

  /// The real Settings slider, driven by this test; the app (launched without
  /// `-UIViewGlassTintAmount`) restarts its frames whenever the amount changes.
  func testSettings() throws {
    let count = max(2, Int(env["PARITY_POSITIONS"] ?? "11") ?? 11)
    let app = launchParity(["--parity-settings"])
    guard let first = wait(app, 90, { $0.hasPrefix("ready ") }) else {
      XCTFail("parity app did not start: '\(status(app))'")
      return
    }
    // "ready <seq> <frame>/<n> e<epoch> a<amount> ...": restored at the end.
    let initial = first.split(separator: " ").first(where: { $0.hasPrefix("a") }).flatMap { Double($0.dropFirst()) }
    var last = captureAll(app, after: 0, tag: "settings-initial") ?? 0
    let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
    for i in 0..<count {
      let position = Double(i) / Double(count - 1)
      guard let value = setSlider(settings, position) else {
        XCTFail("could not drive Settings at position \(position)")
        return
      }
      note("slider position \(position) reads \(value)")
      app.activate()
      if let next = captureAll(app, after: last, tag: "settings-p\(String(format: "%.3f", position))", firstTimeout: 20) {
        last = next
      } else {
        note("no new frames after position \(position): the amount did not change")
      }
    }
    if let initial {
      note("restoring the slider to \(initial): reads \(setSlider(settings, initial) ?? "?")")
    }
    app.terminate()
  }

  /// Keeps the session alive while someone moves the slider by hand; every
  /// time the app returns with a new amount, it captures all frames.
  func testWatch() throws {
    let minutes = Double(env["PARITY_WATCH_MINUTES"] ?? "20") ?? 20
    executionTimeAllowance = minutes * 60 + 120
    let app = launchParity(["--parity-settings"])
    var last = captureAll(app, after: 0, tag: "watch-initial") ?? 0
    let deadline = Date().addingTimeInterval(minutes * 60)
    while Date() < deadline {
      guard app.state == .runningForeground else {
        Thread.sleep(forTimeInterval: 1)
        continue
      }
      guard wait(app, 5, { $0.hasPrefix("ready ") && self.seq($0) > last }) != nil else { continue }
      if let next = captureAll(app, after: last, tag: "watch") { last = next }
    }
  }
}
