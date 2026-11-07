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
    // Held shadows over plain white.
    func testControlsWhiteLight() { controls(["--pattern", "white", "--light"]) }
    func testTabsVDark() { tabbar(["--pattern", "v"]) }
    func testTabsVLight() { tabbar(["--pattern", "v", "--light"]) }
    func testTabsHDark() { tabbar(["--pattern", "h"]) }
    func testToolbarVDark() { toolbar(["--pattern", "v"]) }
    func testToolbarVLight() { toolbar(["--pattern", "v", "--light"]) }

    // Lens displacement field over position-encoded backdrops (EncodedBackdrop).
    func testRampControlsLight() { controls(["--pattern", "ramp", "--light"]) }
    func testRampControlsDark() { controls(["--pattern", "ramp"]) }
    func testPhaseXControlsLight() { controls(["--pattern", "phasex", "--light"]) }
    func testPhaseYControlsLight() { controls(["--pattern", "phasey", "--light"]) }
    func testPhaseXControlsDark() { controls(["--pattern", "phasex"]) }
    func testPhaseYControlsDark() { controls(["--pattern", "phasey"]) }
    func testRampTabsLight() { tabbar(["--pattern", "ramp", "--light"]) }
    func testPhaseXTabsLight() { tabbar(["--pattern", "phasex", "--light"]) }
    func testPhaseYTabsLight() { tabbar(["--pattern", "phasey", "--light"]) }
    func testPhaseX64TabsLight() { tabbar(["--pattern", "phasex", "--period", "64", "--light"]) }
    func testPhaseY64TabsLight() { tabbar(["--pattern", "phasey", "--period", "64", "--light"]) }
    // 3-step grey phase shifting (see EncodedBackdrop): three shifts per axis.
    func testGrayX32s0TabsLight() { tabbar(["--pattern", "grayx", "--period", "32", "--shift", "0", "--light"]) }
    func testGrayX32s1TabsLight() { tabbar(["--pattern", "grayx", "--period", "32", "--shift", "1", "--light"]) }
    func testGrayX32s2TabsLight() { tabbar(["--pattern", "grayx", "--period", "32", "--shift", "2", "--light"]) }
    func testGrayX64s0TabsLight() { tabbar(["--pattern", "grayx", "--period", "64", "--shift", "0", "--light"]) }
    func testGrayX64s1TabsLight() { tabbar(["--pattern", "grayx", "--period", "64", "--shift", "1", "--light"]) }
    func testGrayX64s2TabsLight() { tabbar(["--pattern", "grayx", "--period", "64", "--shift", "2", "--light"]) }
    func testGrayY32s0TabsLight() { tabbar(["--pattern", "grayy", "--period", "32", "--shift", "0", "--light"]) }
    func testGrayY32s1TabsLight() { tabbar(["--pattern", "grayy", "--period", "32", "--shift", "1", "--light"]) }
    func testGrayY32s2TabsLight() { tabbar(["--pattern", "grayy", "--period", "32", "--shift", "2", "--light"]) }
    func testGrayY64s0TabsLight() { tabbar(["--pattern", "grayy", "--period", "64", "--shift", "0", "--light"]) }
    func testGrayY64s1TabsLight() { tabbar(["--pattern", "grayy", "--period", "64", "--shift", "1", "--light"]) }
    func testGrayY64s2TabsLight() { tabbar(["--pattern", "grayy", "--period", "64", "--shift", "2", "--light"]) }
    func testGrayX32s0ControlsLight() { controls(["--pattern", "grayx", "--period", "32", "--shift", "0", "--light"]) }
    func testGrayY32s0ControlsLight() { controls(["--pattern", "grayy", "--period", "32", "--shift", "0", "--light"]) }
    func testGrayX32s1ControlsLight() { controls(["--pattern", "grayx", "--period", "32", "--shift", "1", "--light"]) }
    func testGrayY32s1ControlsLight() { controls(["--pattern", "grayy", "--period", "32", "--shift", "1", "--light"]) }
    func testGrayX32s2ControlsLight() { controls(["--pattern", "grayx", "--period", "32", "--shift", "2", "--light"]) }
    func testGrayY32s2ControlsLight() { controls(["--pattern", "grayy", "--period", "32", "--shift", "2", "--light"]) }

    /// One gesture per launch so every case starts with Home selected. The dump
    /// (and screenshot) lands --dump-delay 2 s after touch-down: after the drag.
    ///   hold: hold Home; mid: drag Home → midpoint of Home/Search and hold;
    ///   search: drag Home → Search and hold.
    func tabDrag(_ args: [String], to target: String) {
        let app = launch(["--scene", "tabbar", "--pattern", "white", "--light", "--dump-delay", "2"] + args)
        let home = app.tabBars.buttons["Home"], search = app.tabBars.buttons["Search"]
        let start = home.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        switch target {
        case "hold":
            start.press(forDuration: 3.5)                   // touch1
        default:
            let h = home.frame, s = search.frame
            let x = target == "mid" ? (h.midX + s.midX) / 2 : s.midX
            let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: h.midY))
            start.press(forDuration: 0.6, thenDragTo: end, withVelocity: 150, thenHoldForDuration: 3.0) // touch1
        }
        Thread.sleep(forTimeInterval: 1.5)
        app.terminate()
    }
    func testOutlineWhiteHold() { tabDrag(["--outline"], to: "hold") }
    func testOutlineWhiteMid() { tabDrag(["--outline"], to: "mid") }
    func testOutlineWhiteSearch() { tabDrag(["--outline"], to: "search") }
    func testNoFillWhiteHold() { tabDrag(["--no-fill"], to: "hold") }
    func testNoFillWhiteMid() { tabDrag(["--no-fill"], to: "mid") }
    func testNoFillWhiteSearch() { tabDrag(["--no-fill"], to: "search") }
    func testMonoWhiteHold() { tabDrag(["--outline", "--mono"], to: "hold") }
    func testMonoWhiteMid() { tabDrag(["--outline", "--mono"], to: "mid") }
    func testMonoWhiteSearch() { tabDrag(["--outline", "--mono"], to: "search") }
    func testFillWhiteHold() { tabDrag([], to: "hold") }
    func testFillWhiteMid() { tabDrag([], to: "mid") }
    func testFillWhiteSearch() { tabDrag([], to: "search") }
}
