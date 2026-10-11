import XCTest
final class SheetSpecsTests: XCTestCase {
    func capture(light:Bool,large:Bool) {
        let app=XCUIApplication();app.launchArguments = (light ? ["--light"] : []) + (large ? ["--large"] : []);app.launch()
        XCTAssertTrue(app.buttons["open"].waitForExistence(timeout:10));app.buttons["open"].tap()
        XCTAssertTrue(app.staticTexts["sheet-title"].waitForExistence(timeout:10));Thread.sleep(forTimeInterval:3)
        if !large {
            let from=app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.52));let to=app.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.13))
            from.press(forDuration:0.2,thenDragTo:to,withVelocity:XCUIGestureVelocity(300),thenHoldForDuration:0.5)
        }
        Thread.sleep(forTimeInterval:15);app.terminate()
    }
    func testMediumDark(){capture(light:false,large:false)}
    func testMediumLight(){capture(light:true,large:false)}
    func testLargeDark(){capture(light:false,large:true)}
    func testLargeLight(){capture(light:true,large:true)}
}
