import XCTest

/// Drives the installed Flutter showcase and the real UIKit menu window.
/// Build/install the example before running this fixture.
final class NativeMenuUITests: XCTestCase {
  private func openShowcase() -> XCUIApplication {
    let app = XCUIApplication(bundleIdentifier: "dev.rehmatsg.liquidPrismExample")
    app.launch()
    XCTAssertTrue(app.buttons["Library"].waitForExistence(timeout: 15))
    app.buttons["Library"].tap()
    let row = app.buttons["Explore Popup menus"]
    for _ in 0..<5 {
      if row.exists && row.isHittable && row.frame.maxY < app.frame.height * 0.72 { break }
      let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.68))
      let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.32))
      start.press(forDuration: 0.1, thenDragTo: end)
      Thread.sleep(forTimeInterval: 0.7)
    }
    XCTAssertTrue(row.exists)
    row.tap()
    XCTAssertTrue(app.buttons["Open native menu"].waitForExistence(timeout: 5))
    return app
  }
  private func element(_ label: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
  }
  private func snapshot(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  func testButtonMenuSelectsNativeAction() {
    let app = openShowcase()
    app.buttons["Open native menu"].tap()
    let action = element("A new idea", in: app)
    XCTAssertTrue(action.waitForExistence(timeout: 5))
    XCTAssertTrue(element("0 ideas so far", in: app).waitForExistence(timeout: 5))
    snapshot("native-button-menu")
    action.tap()
    XCTAssertTrue(element("Selected: A new idea", in: app).waitForExistence(timeout: 5))
    snapshot("native-button-selection")
    app.terminate()
  }
  func testToolbarMenuSubmenuAndAppearance() {
    let app = openShowcase()
    app.buttons["Toggle appearance"].tap()
    app.buttons["Open toolbar menu"].tap()
    let artwork = element("Artwork", in: app)
    XCTAssertTrue(artwork.waitForExistence(timeout: 5))
    snapshot("native-dark-toolbar-menu")
    artwork.tap()
    let dusk = element("Dusk", in: app)
    XCTAssertTrue(dusk.waitForExistence(timeout: 5))
    snapshot("native-submenu")
    dusk.tap()
    XCTAssertTrue(element("Selected: Dusk", in: app).waitForExistence(timeout: 5))
    app.terminate()
  }
  func testLongPressPresentsContextMenu() {
    let app = openShowcase()
    element("Hold here for a context menu", in: app).press(forDuration: 1)
    let favorite = element("Add to favorites", in: app)
    XCTAssertTrue(favorite.waitForExistence(timeout: 5))
    snapshot("native-context-menu")
    favorite.tap()
    XCTAssertTrue(element("Selected: Favorite", in: app).waitForExistence(timeout: 5))
    app.buttons["Open native menu"].tap()
    XCTAssertTrue(element("Remove favorite", in: app).waitForExistence(timeout: 5))
    snapshot("native-checkmark")
    app.terminate()
  }
}
