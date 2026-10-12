import XCTest

final class ShowcaseTests: XCTestCase {
    private func launch(_ screen: String = "explore", dark: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--inspect", "--screen", screen] + (dark ? ["--dark"] : [])
        app.launch()
        XCTAssertTrue(app.buttons["Toggle appearance"].waitForExistence(timeout: 10))
        return app
    }
    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testTabsAndEveryComponentRoute() {
        let app = launch()
        snapshot("explore-light")
        app.tabBars.buttons["Studio"].tap()
        XCTAssertTrue(app.staticTexts["Find your feel."].exists)
        snapshot("studio-light")
        app.tabBars.buttons["Library"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("slider")
        XCTAssertTrue(app.buttons["Explore Sliders"].waitForExistence(timeout: 5))
        app.buttons["Explore Sliders"].tap()
        XCTAssertTrue(app.sliders["Intensity"].waitForExistence(timeout: 5))
        app.sliders["Intensity"].adjust(toNormalizedSliderPosition: 0.8)
        snapshot("slider-changed")
        app.buttons["Back to showcase"].tap()
        app.terminate()
        for screen in ["surfaces", "buttons", "switches", "sliders", "segments", "tabs", "toolbar", "menus", "search"] {
            let page = launch(screen)
            XCTAssertTrue(page.buttons["Back to showcase"].exists)
            snapshot("\(screen)-light")
            page.terminate()
        }
    }
    func testNativeControlsAndMenus() {
        var app = launch("switches")
        let toggle = app.switches["Let it glow"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        XCTAssertTrue(app.staticTexts["A moment of quiet."].waitForExistence(timeout: 5))
        app.terminate()
        app = launch("segments")
        app.segmentedControls.buttons["Dusk"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Take the scenic route."].waitForExistence(timeout: 5))
        app.terminate()
        app = launch("menus")
        app.buttons["Open native menu"].tap()
        let action = app.buttons["A new idea"]
        XCTAssertTrue(action.waitForExistence(timeout: 5))
        snapshot("native-popup")
        action.tap()
        XCTAssertTrue(app.staticTexts["Selected: A new idea"].waitForExistence(timeout: 5))
        app.terminate()
    }
}
