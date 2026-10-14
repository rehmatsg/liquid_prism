import XCTest
final class PackageFeaturesSpecsTests: XCTestCase {
    // Screenshots are taken by the test itself so they line up with the swipe
    // phases; run.sh passes the output directory as TEST_RUNNER_PROBE_OUT.
    var shotPrefix = ""
    func shot(_ state: String) {
        guard let dir = ProcessInfo.processInfo.environment["PROBE_OUT"] else { return }
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(shotPrefix)-\(state).png"))
    }
    func capture(_ dark: Bool, toolbar: Bool = false, tabs: Int = 3) {
        let app = XCUIApplication()
        app.launchArguments = (dark ? ["--dark"] : []) + (toolbar ? ["--toolbar"] : []) + ["--tabs", String(tabs)]
        app.launch()
        sleep(3)
        shot("rest")
        if toolbar { sleep(6); app.terminate(); return }
        app.scrollViews.firstMatch.swipeUp(velocity: .slow)
        sleep(3)
        shot("slow-up")
        app.scrollViews.firstMatch.swipeDown(velocity: .slow)
        sleep(3)
        shot("slow-down")
        app.scrollViews.firstMatch.swipeUp(velocity: .fast)
        sleep(4)
        shot("fast-up")
        app.terminate()
    }
    func testLight() { shotPrefix = "Light"; capture(false) }
    func testDark() { shotPrefix = "Dark"; capture(true) }
    func testToolbarLight() { shotPrefix = "ToolbarLight"; capture(false, toolbar: true) }
    func testToolbarDark() { shotPrefix = "ToolbarDark"; capture(true, toolbar: true) }
    // Slow press-drag with holds to separate scroll-scrubbed from time-driven
    // title changes: drag 40 pt steps at 20 pt/s and hold 1.5 s after each step.
    func testScrub() {
        shotPrefix = "Scrub"
        let app = XCUIApplication()
        app.launchArguments = ["--tabs", "3"]
        app.launch()
        sleep(3)
        shot("rest")
        let window = app.windows.firstMatch
        let origin = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
        for step in 0..<4 {
            let start = origin.withOffset(CGVector(dx: 0, dy: 600))
            let end = origin.withOffset(CGVector(dx: 0, dy: 560))
            start.press(forDuration: 0.3, thenDragTo: end, withVelocity: 20, thenHoldForDuration: 1.5)
            shot("step\(step + 1)")
        }
        for step in 0..<4 {
            let start = origin.withOffset(CGVector(dx: 0, dy: 560))
            let end = origin.withOffset(CGVector(dx: 0, dy: 600))
            start.press(forDuration: 0.3, thenDragTo: end, withVelocity: 20, thenHoldForDuration: 1.5)
            shot("down\(step + 1)")
        }
        sleep(2)
        app.terminate()
    }
    func testTabs4() { shotPrefix = "Tabs4"; capture(false, tabs: 4) }
    func testTabs5() { shotPrefix = "Tabs5"; capture(false, tabs: 5) }
    // Navigation subtitle / sheet bar fixtures. Rest, slow up (scrolled, collapse),
    // slow down (back to rest). Sheets present 0.4 s after launch.
    func nav(_ mode: String, dark: Bool = false) {
        shotPrefix = "\(mode)\(dark ? "Dark" : "Light")"
        let app = XCUIApplication()
        app.launchArguments = ["--nav", mode] + (dark ? ["--dark"] : [])
        app.launch()
        sleep(4)
        shot("rest")
        let scroll = app.scrollViews.firstMatch
        scroll.swipeUp(velocity: .slow)
        sleep(3)
        shot("slow-up")
        scroll.swipeDown(velocity: .slow)
        sleep(3)
        shot("slow-down")
        sleep(1)
        app.terminate()
    }
    func testSubtitleInline() { nav("subtitleInline") }
    func testSubtitleInlineDark() { nav("subtitleInline", dark: true) }
    func testSubtitleLarge() { nav("subtitleLarge") }
    func testSubtitleLargeDark() { nav("subtitleLarge", dark: true) }
    func testSubtitleLong() { nav("subtitleLong") }
    func testSheetLarge() { nav("sheetLarge") }
    func testSheetLargeIndicator() { nav("sheetLargeIndicator") }
    func testSheetMedium() { nav("sheetMedium") }
    func testSheetMediumIndicator() { nav("sheetMediumIndicator") }
    func testSheetLargeTitle() { nav("sheetLargeTitle") }
    func testSheetMediumLargeTitle() { nav("sheetMediumLargeTitle") }
    // Slow scrub of the large title + subtitle collapse (20 pt/s steps, 1.5 s holds).
    func testSubtitleScrub() {
        shotPrefix = "SubtitleScrub"
        let app = XCUIApplication()
        app.launchArguments = ["--nav", "subtitleLarge"]
        app.launch()
        sleep(3)
        shot("rest")
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
        for step in 0..<4 {
            origin.withOffset(CGVector(dx: 0, dy: 600)).press(forDuration: 0.3, thenDragTo: origin.withOffset(CGVector(dx: 0, dy: 560)), withVelocity: 20, thenHoldForDuration: 1.5)
            shot("step\(step + 1)")
        }
        sleep(2)
        app.terminate()
    }
}
