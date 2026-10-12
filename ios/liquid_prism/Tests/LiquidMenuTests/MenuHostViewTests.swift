import XCTest
@testable import liquid_prism

/// The overlay reports window resizes so a menu anchored in the old geometry
/// closes, as UIKit's own menus do on fold, rotation and Split View changes.
@MainActor
final class MenuHostViewTests: XCTestCase {
  func testReportsSizeChangesAfterFirstLayout() {
    let host = MenuHostView(frame: CGRect(x: 0, y: 0, width: 466, height: 678))
    var resizes = 0
    host.onResize = { resizes += 1 }

    host.layoutSubviews()
    XCTAssertEqual(resizes, 0, "the first layout is not a resize")

    host.layoutSubviews()
    XCTAssertEqual(resizes, 0, "relayout at the same size is not a resize")

    host.frame.size = CGSize(width: 669, height: 951)
    host.layoutSubviews()
    XCTAssertEqual(resizes, 1)
  }

  func testIgnoresGrowthFromZeroSize() {
    let host = MenuHostView(frame: .zero)
    var resizes = 0
    host.onResize = { resizes += 1 }
    host.layoutSubviews()
    host.frame.size = CGSize(width: 402, height: 874)
    host.layoutSubviews()
    XCTAssertEqual(resizes, 0)
  }
}
