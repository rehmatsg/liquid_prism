import Flutter
import UIKit

/// A `FlutterViewController` whose vertical bar preference Dart can set with
/// `LiquidPrismSystemChrome.setVerticalBarBehavior`.
///
/// UIKit reads `preferredVerticalBarBehavior` from the root view controller,
/// which a plugin cannot override on `FlutterViewController` itself. Use this
/// class for your Flutter view controller (in `Main.storyboard`, set the
/// custom class to `LiquidPrismViewController`) only if your app needs to opt
/// out of the iPhone Duo vertical bar, such as for a full-screen video player.
@objc(LiquidPrismViewController)
open class LiquidPrismViewController: FlutterViewController {
  /// Hide the vertical bar: bars fall back to the horizontal top and bottom
  /// positions and the status bar returns to the horizontal axis.
  @objc public var verticalBarDisabled = false {
    didSet {
      guard verticalBarDisabled != oldValue else { return }
      if #available(iOS 27.1, *) { setNeedsUpdateOfVerticalBarConfiguration() }
    }
  }

  @available(iOS 27.1, *)
  open override var preferredVerticalBarBehavior: UIVerticalBarBehavior {
    verticalBarDisabled ? .disabled : .automatic
  }
}
