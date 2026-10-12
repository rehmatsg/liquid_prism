import XCTest

final class LensMotionTests: XCTestCase {
    private func exercise(_ name: String) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--inspect", "--motion", name, "--screen", name == "tabs" ? "explore" : name]
        app.launch()
        XCTAssertTrue(app.buttons["Toggle appearance"].waitForExistence(timeout: 10))
        let a: XCUICoordinate, b: XCUICoordinate
        switch name {
        case "switches":
            let control = app.switches["Let it glow"]
            a = control.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.5))
            b = control.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        case "sliders":
            let control = app.sliders["Intensity"]
            a = control.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.5))
            b = control.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
        case "segments":
            let control = app.segmentedControls.firstMatch
            a = control.buttons["Day"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            b = control.buttons["Night"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        default:
            a = app.tabBars.buttons["Explore"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            b = app.tabBars.buttons["Library"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        }
        print("LENS_BEGIN \(name) \(Date().timeIntervalSince1970) \(a.screenPoint.x) \(a.screenPoint.y) \(b.screenPoint.x) \(b.screenPoint.y)")
        let distance = abs(b.screenPoint.x - a.screenPoint.x)
        a.press(forDuration: 1.2, thenDragTo: b, withVelocity: XCUIGestureVelocity(distance / 2), thenHoldForDuration: 1)
        Thread.sleep(forTimeInterval: 1)
        b.press(forDuration: 1.2, thenDragTo: a, withVelocity: XCUIGestureVelocity(distance / 0.3), thenHoldForDuration: 1)
        Thread.sleep(forTimeInterval: 1)
        print("LENS_END \(name) \(Date().timeIntervalSince1970)")
        app.terminate()
    }
    func testSwitch() { exercise("switches") }
    func testSlider() { exercise("sliders") }
    func testSegments() { exercise("segments") }
    func testTabs() { exercise("tabs") }
}
