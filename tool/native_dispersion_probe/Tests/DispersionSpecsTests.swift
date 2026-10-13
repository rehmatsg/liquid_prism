import XCTest
/// Each test launches one scene and holds elements one after another; the app
/// dumps filters 1.0 s into every touch and writes touchN.done, on which the
/// runner screenshots. Keep the hold order in step with run.sh's labels.
final class DispersionSpecsTests: XCTestCase {
    func launch(_ args: [String]) -> XCUIApplication {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments = args
        app.launch()
        Thread.sleep(forTimeInterval: 3)
        return app
    }
    func hold(_ e: XCUIElement, dx: Double = 0.5) {
        e.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: 0.5)).press(forDuration: 2.5)
        Thread.sleep(forTimeInterval: 1.5)
    }
    func controls(_ args: [String]) {
        let app = launch(["--scene", "controls"] + args)
        hold(app.switches["switch"])                        // touch1
        hold(app.sliders["slider"], dx: 0.41)               // touch2
        hold(app.segmentedControls["segments"].buttons["First"]) // touch3
        hold(app.buttons["glassButton"])                    // touch4
        hold(app.buttons["prominentButton"])                // touch5
        hold(app.staticTexts["Regular"])                    // touch6
        hold(app.staticTexts["Clear"])                      // touch7
        hold(app.staticTexts["Large"])                      // touch8
        Thread.sleep(forTimeInterval: 1)
        app.terminate()
    }
    func tabbar(_ args: [String]) {
        let app = launch(["--scene", "tabbar"] + args)
        hold(app.tabBars.buttons["Home"])                   // touch1 (selected)
        hold(app.tabBars.buttons["Search"])                 // touch2 (unselected)
        Thread.sleep(forTimeInterval: 1)
        app.terminate()
    }
    func toolbar(_ args: [String]) {
        let app = launch(["--scene", "toolbar"] + args)
        hold(app.buttons["favorite"])                       // touch1
        hold(app.buttons["share"])                          // touch2
        Thread.sleep(forTimeInterval: 1)
        app.terminate()
    }
    func testControlsVDark() { controls(["--pattern", "v"]) }
    func testControlsVLight() { controls(["--pattern", "v", "--light"]) }
    func testControlsHDark() { controls(["--pattern", "h"]) }
    func testControlsHLight() { controls(["--pattern", "h", "--light"]) }
    func testTabsVDark() { tabbar(["--pattern", "v"]) }
    func testTabsVLight() { tabbar(["--pattern", "v", "--light"]) }
    func testTabsHDark() { tabbar(["--pattern", "h"]) }
    func testToolbarVDark() { toolbar(["--pattern", "v"]) }
    func testToolbarVLight() { toolbar(["--pattern", "v", "--light"]) }
}
