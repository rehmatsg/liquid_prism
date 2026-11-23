import Flutter
import UIKit

/// A Flutter view controller with a vertical bar preference configurable from Dart.
@objc(LiquidPrismViewController)
open class LiquidPrismViewController: FlutterViewController {
  /// Hides the vertical bar and restores horizontal bars and status bar placement.
  @objc public var verticalBarDisabled = false {
    didSet {
      guard verticalBarDisabled != oldValue else { return }
      #if canImport(UIKit, _version: 9127.0.85)
      if #available(iOS 27.1, *) { setNeedsUpdateOfVerticalBarConfiguration() }
      #endif
    }
  }

  #if canImport(UIKit, _version: 9127.0.85)
  @available(iOS 27.1, *)
  open override var preferredVerticalBarBehavior: UIVerticalBarBehavior {
    verticalBarDisabled ? .disabled : .automatic
  }
  #endif
}
