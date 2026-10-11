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
    func testLight() { run("controls-light",light:true) { $0.switches["switch"].tap() }}
}
