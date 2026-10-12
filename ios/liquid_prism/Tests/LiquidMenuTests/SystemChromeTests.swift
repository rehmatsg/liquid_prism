import XCTest
@testable import liquid_prism

/// The channel payload Dart parses in `lib/src/system_chrome.dart`.
final class SystemChromeTests: XCTestCase {
  func testEncodesEdgeRegionsAndMargins() {
    let chrome = SystemChrome(
      supported: true,
      verticalBarEdge: .right,
      occlusions: [CGRect(x: 867, y: 0, width: 84, height: 120)],
      divisions: [
        .init(
          frame: CGRect(x: 455.5, y: 0, width: 40, height: 669),
          margins: UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20))
      ])
    let map = chrome.map
    XCTAssertEqual(map["supported"] as? Bool, true)
    XCTAssertEqual(map["verticalBarEdge"] as? String, "right")
    XCTAssertEqual(map["occlusions"] as? [[Double]], [[867, 0, 84, 120]])
    XCTAssertEqual(map["divisions"] as? [[Double]], [[455.5, 0, 40, 669, 20, 0, 20, 0]])
  }

  func testHorizontalBarsEncodeNoEdge() {
    let map = SystemChrome(
      supported: true, verticalBarEdge: nil, occlusions: [], divisions: []
    ).map
    XCTAssertTrue(map["verticalBarEdge"] is NSNull)
    XCTAssertEqual(SystemChrome.unsupported.map["supported"] as? Bool, false)
  }
}
