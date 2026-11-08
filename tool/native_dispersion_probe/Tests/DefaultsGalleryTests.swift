import XCTest

final class DefaultsGalleryTests: XCTestCase {
    private let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("defaults-gallery")

    private func save(_ name: String) throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: output.appendingPathComponent("\(name)-native.png"))
    }

    func testStates() throws {
        continueAfterFailure = false
        for dark in [false, true] {
            for amount in [0.0, 0.25, 0.5, 0.75, 1.0] {
                for pattern in ["grouped", "grayx"] {
                    let run = "states-\(pattern)-\(dark ? "dark" : "light")-t\(String(format: "%g", amount))"
                    let app = XCUIApplication()
                    app.launchArguments = ["--scene", "defaults", "--pattern", pattern,
                        "--run-name", run, "--dump-delay", "0.7", "-UIViewGlassTintAmount", "\(amount)"]
                        + (dark ? [] : ["--light"])
                    app.launch()
                    XCTAssertTrue(app.sliders["slider"].waitForExistence(timeout: 10))
                    Thread.sleep(forTimeInterval: 1.8)
                    let targets: [(String, XCUIElement, Double)] = [
                        ("button", app.buttons["button"], 0.5),
                        ("prominent", app.buttons["prominent"], 0.5),
                        ("off", app.switches["off"], 0.2),
                        ("on", app.switches["on"], 0.8),
                        ("slider", app.sliders["slider"], 0.62),
                        ("segment", app.segmentedControls["segments"].buttons["First"], 0.5),
                        ("tab", app.tabBars.buttons["Home"], 0.5),
                    ]
                    for (name, element, fraction) in targets {
                        XCTAssertTrue(element.exists, "\(run): \(name)")
                        element.coordinate(withNormalizedOffset: CGVector(dx: fraction, dy: 0.5)).press(forDuration: 1.8)
                        Thread.sleep(forTimeInterval: 0.8)
                        try save("\(run)-\(name)-released")
                    }
                    app.terminate()
                }
            }
        }
    }
}
