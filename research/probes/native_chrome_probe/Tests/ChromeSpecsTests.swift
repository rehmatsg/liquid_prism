import XCTest
final class ChromeSpecsTests: XCTestCase {
    func capture(light: Bool, search: Bool) {
        let app = XCUIApplication()
        app.launchArguments = (light ? ["--light"] : []) + (search ? ["--search"] : [])
        app.launch()
        Thread.sleep(forTimeInterval: 4)
        if search {
            let field = app.searchFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 10))
            field.tap()
            Thread.sleep(forTimeInterval: 4)
            field.typeText("Prism")
        } else {
            XCTAssertTrue(app.buttons["favorite"].waitForExistence(timeout: 10))
            app.buttons["favorite"].press(forDuration: 1)
            app.buttons["back"].press(forDuration: 1)
            app.buttons["compose"].press(forDuration: 1)
        }
        Thread.sleep(forTimeInterval: 13)
        app.terminate()
    }
    func testToolbarDark() { capture(light:false,search:false) }
    func testToolbarLight() { capture(light:true,search:false) }
    func testSearchDark() { capture(light:false,search:true) }
    func testSearchLight() { capture(light:true,search:true) }
}
