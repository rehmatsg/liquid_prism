import XCTest
final class ScrollEdgeSpecsTests: XCTestCase {
    func capture(_ args: [String]) {
        let app = XCUIApplication()
        app.launchArguments = args
        app.launch()
        // The app extracts at rest (1.2 s), scrolled onto colour bands (3.7 s)
        // and scrolled onto stripes (10.2 s); the runner screenshots meanwhile.
        Thread.sleep(forTimeInterval: 13)
        app.terminate()
    }
    func testSoftLight() { capture(["--light"]) }
    func testSoftDark() { capture([]) }
    func testHardLight() { capture(["--light", "--hard"]) }
    func testAutoLight() { capture(["--light", "--auto"]) }
}
