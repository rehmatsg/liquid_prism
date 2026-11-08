import XCTest

final class NavigationTests: XCTestCase {
  func testRestorationAtEdge() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "--scene", "navigation", "--light", "--title-mode", "inline", "--minimization",
      "onScrollDown", "--restore-at-edge",
    ]
    app.launch()
    let scroll = app.scrollViews["navigation-scroll"]
    XCTAssertTrue(scroll.waitForExistence(timeout: 10))
    scroll.swipeUp(velocity: .slow)
    Thread.sleep(forTimeInterval: 0.5)
    for _ in 0..<3 {
      scroll.swipeDown(velocity: .slow)
      Thread.sleep(forTimeInterval: 0.5)
    }
    Thread.sleep(forTimeInterval: 1)
    app.terminate()
  }

  func testTitleTiming() throws {
    let app = XCUIApplication()
    for mode in ["large", "inlineLarge"] {
      app.launchArguments = [
        "--scene", "navigation", "--light", "--title-mode", mode, "--minimization", "never",
      ]
      app.launch()
      let scroll = app.scrollViews["navigation-scroll"]
      XCTAssertTrue(scroll.waitForExistence(timeout: 10))
      let top = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
      let bottom = top.withOffset(CGVector(dx: 0, dy: -80))
      Thread.sleep(forTimeInterval: 0.5)
      for _ in 0..<2 {
        top.press(
          forDuration: 0.05, thenDragTo: bottom, withVelocity: .slow, thenHoldForDuration: 0.15)
        Thread.sleep(forTimeInterval: 1)
        bottom.press(
          forDuration: 0.05, thenDragTo: top, withVelocity: .slow, thenHoldForDuration: 0.15)
        Thread.sleep(forTimeInterval: 1)
      }
      top.press(forDuration: 0.05, thenDragTo: bottom, withVelocity: .fast, thenHoldForDuration: 0)
      bottom.press(forDuration: 0.05, thenDragTo: top, withVelocity: .fast, thenHoldForDuration: 0)
      Thread.sleep(forTimeInterval: 1)
      app.terminate()
    }
  }

  func testNavigationModes() throws {
    let app = XCUIApplication()
    var samples: [[String: Any]] = []
    let cases = [
      ["large", "never", "automatic"],
      ["inline", "never", "automatic"],
      ["inlineLarge", "never", "automatic"],
      ["inline", "onScrollDown", "automatic"],
      ["inline", "onScrollDown", "atScrollEdge"],
      ["inline", "onScrollUp", "automatic"],
      ["large", "onScrollDown", "automatic"],
    ]
    for appearance in ["light", "dark"] {
      for args in cases {
        app.launchArguments = [
          "--scene", "navigation", "--" + appearance, "--title-mode", args[0], "--minimization",
          args[1],
        ]
        if args[2] == "atScrollEdge" { app.launchArguments.append("--restore-at-edge") }
        app.launch()
        let scroll = app.scrollViews["navigation-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        func frame(_ element: XCUIElement) -> [Double] {
          guard element.exists else { return [] }
          let rect = element.frame
          return [rect.minX, rect.minY, rect.width, rect.height]
        }
        func sample(_ phase: String) {
          Thread.sleep(forTimeInterval: 0.7)
          let attachment = XCTAttachment(screenshot: app.screenshot())
          attachment.name = appearance + "-" + args.joined(separator: "-") + "-" + phase
          attachment.lifetime = .keepAlways
          add(attachment)
          let back = app.buttons["navigation-back"]
          samples.append([
            "appearance": appearance, "mode": args[0], "minimization": args[1],
            "restoration": args[2], "phase": phase,
            "bar": frame(app.navigationBars.firstMatch), "back": frame(back),
            "backHittable": back.exists && back.isHittable,
            "title": frame(app.staticTexts["Library"].firstMatch),
            "row0": frame(app.staticTexts["navigation-row-0"]),
            "row10": frame(app.staticTexts["navigation-row-10"]),
          ])
        }
        sample("rest")
        scroll.swipeUp(velocity: .slow)
        sample("down")
        let a = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        let b = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        a.press(forDuration: 0.05, thenDragTo: b)
        sample("up")
        app.terminate()
      }
    }
    let data = try JSONSerialization.data(
      withJSONObject: samples, options: [.prettyPrinted, .sortedKeys])
    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
    attachment.name = "navigation-measurements"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
