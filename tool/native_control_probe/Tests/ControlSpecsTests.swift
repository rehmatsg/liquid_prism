import XCTest
final class ControlSpecsTests: XCTestCase {
    func run(_ name: String, light: Bool = false, action: (XCUIApplication) -> Void) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--run",name] + (light ? ["--light"] : [])
        app.launch()
        XCTAssertTrue(app.switches["switch"].waitForExistence(timeout:10))
        Thread.sleep(forTimeInterval:2)
        action(app)
        Thread.sleep(forTimeInterval:14)
        app.terminate()
    }
    func testSwitch() { run("switch-dark") { app in
        app.switches["switch"].tap()
        Thread.sleep(forTimeInterval:1.5)
        let a = app.switches["switch"].coordinate(withNormalizedOffset:CGVector(dx:0.78,dy:0.5))
        let b = app.switches["switch"].coordinate(withNormalizedOffset:CGVector(dx:0.2,dy:0.5))
        a.press(forDuration:1.5,thenDragTo:b,withVelocity:XCUIGestureVelocity(60),thenHoldForDuration:1)
    }}
    func testSlider() { run("slider-dark") { app in
        let a = app.sliders["slider"].coordinate(withNormalizedOffset:CGVector(dx:0.42,dy:0.5))
        let b = app.sliders["slider"].coordinate(withNormalizedOffset:CGVector(dx:0.9,dy:0.5))
        a.press(forDuration:1.5,thenDragTo:b,withVelocity:XCUIGestureVelocity(120),thenHoldForDuration:1)
    }}
    func testSegments() { run("segments-dark") { app in
        app.segmentedControls["segments"].buttons["Second"].tap()
        Thread.sleep(forTimeInterval:1.5)
        let a = app.segmentedControls["segments"].buttons["Second"].coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        let b = app.segmentedControls["segments"].buttons["Third"].coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        a.press(forDuration:1.5,thenDragTo:b,withVelocity:XCUIGestureVelocity(100),thenHoldForDuration:1)
    }}
    // Holds the selected segment still, then partway between segments, for
    // screenshots of the labels under the lifted selection.
    func testSegmentsSelectedHold() { run("segments-hold-light", light: true) { app in
        let seg = app.segmentedControls["segments"]
        let a = seg.buttons["First"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let b = seg.buttons["First"].coordinate(withNormalizedOffset: CGVector(dx: 1.0, dy: 0.5))
        a.press(forDuration: 3, thenDragTo: b, withVelocity: XCUIGestureVelocity(40), thenHoldForDuration: 3)
    }}
    func testLight() { run("controls-light",light:true) { $0.switches["switch"].tap() }}
}

/// Gesture ownership probes: touches that begin away from the thumb or on an
/// unselected segment, off-axis drags, flicks, and drags inside a ScrollView.
/// Each run's motion log samples the thumb/selection layers frame by frame.
final class ControlGestureTests: XCTestCase {
    func run(_ name: String, scroll: Bool = false, action: (XCUIApplication) -> Void) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--run", name] + (scroll ? ["--scroll"] : [])
        app.launch()
        XCTAssertTrue(app.switches["switch"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 2)
        action(app)
        Thread.sleep(forTimeInterval: 7)
        app.terminate()
    }
    func at(_ e: XCUIElement, _ x: Double) -> XCUICoordinate {
        e.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.5))
    }
    // The slider starts at 0.4: its thumb centre is at x 0.412 of the 300 pt frame.
    func testSliderTrackHold() { run("gesture-slider-track-hold") { app in
        self.at(app.sliders["slider"], 0.9).press(forDuration: 1.5)
    }}
    func testSliderTrackDrag() { run("gesture-slider-track-drag") { app in
        let s = app.sliders["slider"]
        self.at(s, 0.9).press(forDuration: 0.8, thenDragTo: self.at(s, 0.6), withVelocity: XCUIGestureVelocity(120), thenHoldForDuration: 0.5)
    }}
    func testSliderTrackTap() { run("gesture-slider-track-tap") { app in
        self.at(app.sliders["slider"], 0.9).tap()
    }}
    func testSliderFlick() { run("gesture-slider-flick") { app in
        let s = app.sliders["slider"]
        self.at(s, 0.412).press(forDuration: 0.05, thenDragTo: self.at(s, 0.412).withOffset(CGVector(dx: 90, dy: 0)), withVelocity: XCUIGestureVelocity(1500), thenHoldForDuration: 0)
    }}
    func testSliderDiagonal30InScroll() { run("gesture-slider-diag30-scroll", scroll: true) { app in
        let s = app.sliders["slider"]
        self.at(s, 0.412).press(forDuration: 0.05, thenDragTo: self.at(s, 0.412).withOffset(CGVector(dx: 87, dy: 50)), withVelocity: XCUIGestureVelocity(400), thenHoldForDuration: 0.3)
    }}
    func testSliderDiagonal60InScroll() { run("gesture-slider-diag60-scroll", scroll: true) { app in
        let s = app.sliders["slider"]
        self.at(s, 0.412).press(forDuration: 0.05, thenDragTo: self.at(s, 0.412).withOffset(CGVector(dx: 50, dy: 87)), withVelocity: XCUIGestureVelocity(400), thenHoldForDuration: 0.3)
    }}
    func testSliderVerticalInScroll() { run("gesture-slider-vertical-scroll", scroll: true) { app in
        let s = app.sliders["slider"]
        self.at(s, 0.412).press(forDuration: 0.05, thenDragTo: self.at(s, 0.412).withOffset(CGVector(dx: 0, dy: 150)), withVelocity: XCUIGestureVelocity(400), thenHoldForDuration: 0.3)
    }}
    func testSliderTrackVerticalInScroll() { run("gesture-slider-track-vertical-scroll", scroll: true) { app in
        let s = app.sliders["slider"]
        self.at(s, 0.9).press(forDuration: 0.05, thenDragTo: self.at(s, 0.9).withOffset(CGVector(dx: 0, dy: 150)), withVelocity: XCUIGestureVelocity(400), thenHoldForDuration: 0.3)
    }}
    func testSegmentsUnselectedHold() { run("gesture-segments-unselected-hold") { app in
        app.segmentedControls["segments"].buttons["Third"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.5)
    }}
    func testSegmentsUnselectedDrag() { run("gesture-segments-unselected-drag") { app in
        let seg = app.segmentedControls["segments"]
        seg.buttons["Third"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.8, thenDragTo: seg.buttons["Second"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)), withVelocity: XCUIGestureVelocity(100), thenHoldForDuration: 0.5)
    }}
    func testSegmentsSelectedDiagonal60InScroll() { run("gesture-segments-diag60-scroll", scroll: true) { app in
        let seg = app.segmentedControls["segments"]
        let a = seg.buttons["First"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        a.press(forDuration: 0.05, thenDragTo: a.withOffset(CGVector(dx: 115, dy: 200)), withVelocity: XCUIGestureVelocity(500), thenHoldForDuration: 0.3)
    }}
    func testSegmentsUnselectedVerticalInScroll() { run("gesture-segments-unselected-vertical-scroll", scroll: true) { app in
        let a = app.segmentedControls["segments"].buttons["Third"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        a.press(forDuration: 0.05, thenDragTo: a.withOffset(CGVector(dx: 0, dy: 150)), withVelocity: XCUIGestureVelocity(400), thenHoldForDuration: 0.3)
    }}
}
