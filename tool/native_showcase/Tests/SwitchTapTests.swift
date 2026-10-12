import XCTest

final class SwitchTapTests: XCTestCase {
    func testQuickTaps() {
        let app = XCUIApplication()
        app.launchArguments = ["--inspect", "--motion", "switch-taps", "--screen", "switches"]
        app.launch()
        let control = app.switches["Let it glow"]
        XCTAssertTrue(control.waitForExistence(timeout: 10))
        // Warm the native lens before measuring either toggle direction.
        control.tap()
        Thread.sleep(forTimeInterval: 1)
        for direction in ["on", "off"] {
            print("SWITCH_TAP \(direction) \(Date().timeIntervalSince1970)")
            control.tap()
            Thread.sleep(forTimeInterval: 1)
        }
        app.terminate()
    }
}
