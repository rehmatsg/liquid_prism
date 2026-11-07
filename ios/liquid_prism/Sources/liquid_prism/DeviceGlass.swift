import Darwin
import Foundation
import UIKit

/// The device's Liquid Glass setting (Settings > Appearance > Liquid Glass on
/// iOS 27), which iOS keeps as UIKit's glass tint amount and applies only to
/// glass it draws itself. There is no public API, so the private getter and its
/// change notification are looked up at runtime. Their names are assembled
/// from reversed fragments, as NotchMyProblem does, so no private symbol
/// appears as a literal; where either is missing the setting reads as nil and
/// glass keeps its defaults.
enum DeviceGlass {
  private typealias Getter = @convention(c) () -> CGFloat

  /// `RTLD_DEFAULT`: search every image loaded in the process.
  private static let everyImage = UnsafeMutableRawPointer(bitPattern: -2)

  private static func symbol(_ reversedParts: [String]) -> UnsafeMutableRawPointer? {
    dlsym(everyImage, reversedParts.reversed().joined())
  }

  private static let getter: Getter? = symbol(
    ["Amount", "Tint", "Get", "Glass", "View", "UI"]
  ).map { unsafeBitCast($0, to: Getter.self) }

  /// The raw tint amount (measured range not yet recorded), or nil where the
  /// system has no such setting.
  static var tintAmount: Double? {
    guard let getter else { return nil }
    let value = Double(getter())
    return value.isFinite ? value : nil
  }

  /// Posted by UIKit when the setting changes.
  static let didChange: Notification.Name? = {
    guard
      let pointer = symbol(
        ["Notification", "Change", "Did", "Amount", "Tint", "Glass", "View", "UI"]
      )
    else { return nil }
    // The symbol is an `NSString * const`.
    let name = pointer.assumingMemoryBound(to: Unmanaged<NSString>?.self).pointee
    return name.map { Notification.Name($0.takeUnretainedValue() as String) }
  }()
}
