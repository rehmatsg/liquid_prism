import QuartzCore
import Metal
import XCTest
@testable import liquid_prism

@MainActor
final class GlassDisplayTests: XCTestCase {
  // The simulator rejects XR drawable formats. Test layer ownership with a
  // recording layer; tool/hdr_probe covers the actual Metal path on device.
  private final class RecordingLayer: CAMetalLayer {
    private var format: MTLPixelFormat = .bgra8Unorm
    private var space: CGColorSpace?
    private var edr = false
    override var pixelFormat: MTLPixelFormat {
      get { format }
      set { format = newValue }
    }
    override var colorspace: CGColorSpace? {
      get { space }
      set { space = newValue }
    }
    @available(iOS 16.0, *)
    override var wantsExtendedDynamicRangeContent: Bool {
      get { edr }
      set { edr = newValue }
    }
  }
  private final class MetalView: UIView {
    override class var layerClass: AnyClass { RecordingLayer.self }
  }

  func testEnablesExistingXRSurfaceAndRestoresRequest() throws {
    guard #available(iOS 16.0, *) else { throw XCTSkip("EDR requires iOS 16") }
    let view = MetalView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let layer = view.layer as! CAMetalLayer
    layer.pixelFormat = .bgra10_xr
    layer.colorspace = CGColorSpace(name: CGColorSpace.extendedSRGB)
    let observer = GlassDisplayObserver()
    observer.attach(to: view, enabled: true)
    XCTAssertTrue(layer.wantsExtendedDynamicRangeContent)
    XCTAssertEqual(layer.pixelFormat, .bgra10_xr)
    XCTAssertEqual(layer.colorspace?.name, CGColorSpace.extendedSRGB)
    observer.detach()
    XCTAssertFalse(layer.wantsExtendedDynamicRangeContent)
  }

  func testUnsupportedSurfaceIsNotReconfigured() throws {
    guard #available(iOS 16.0, *) else { throw XCTSkip("EDR requires iOS 16") }
    let view = MetalView()
    let layer = view.layer as! CAMetalLayer
    layer.pixelFormat = .bgra8Unorm
    layer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
    let observer = GlassDisplayObserver()
    var values: [Double] = []
    observer.onChange = { values.append($0) }
    observer.attach(to: view, enabled: true)
    XCTAssertFalse(layer.wantsExtendedDynamicRangeContent)
    XCTAssertEqual(layer.pixelFormat, .bgra8Unorm)
    XCTAssertEqual(layer.colorspace?.name, CGColorSpace.sRGB)
    XCTAssertEqual(values, [1])
    observer.detach()
  }

  func testOptOutPreservesAnExistingHostEDRRequest() throws {
    guard #available(iOS 16.0, *) else { throw XCTSkip("EDR requires iOS 16") }
    let view = MetalView()
    let layer = view.layer as! CAMetalLayer
    layer.pixelFormat = .bgra10_xr
    layer.colorspace = CGColorSpace(name: CGColorSpace.extendedSRGB)
    layer.wantsExtendedDynamicRangeContent = true
    let observer = GlassDisplayObserver()
    var values: [Double] = []
    observer.onChange = { values.append($0) }
    observer.attach(to: view, enabled: false)
    XCTAssertTrue(layer.wantsExtendedDynamicRangeContent)
    XCTAssertEqual(values, [1])
    observer.detach()
    XCTAssertTrue(layer.wantsExtendedDynamicRangeContent)
  }
}
