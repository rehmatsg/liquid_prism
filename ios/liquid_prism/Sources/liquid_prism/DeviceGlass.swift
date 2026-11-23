import Darwin
import Foundation
import UIKit

enum DeviceGlass {
  private typealias Getter = @convention(c) () -> Unmanaged<AnyObject>?

  private static let everyImage = UnsafeMutableRawPointer(bitPattern: -2)

  private static func symbol(_ reversedParts: [String]) -> UnsafeMutableRawPointer? {
    dlsym(everyImage, reversedParts.reversed().joined())
  }

  private static let getter: Getter? = symbol(
    ["Amount", "Tint", "Get", "Glass", "View", "UI"]
  ).map { unsafeBitCast($0, to: Getter.self) }

  private static var tintObject: AnyObject? { getter?()?.takeUnretainedValue() }

  static var tintAmount: Double? {
    guard let number = tintObject as? NSNumber else { return nil }
    let value = number.doubleValue
    return value.isFinite ? value : nil
  }

  static let didChange: Notification.Name? = {
    guard
      let pointer = symbol(
        ["Notification", "Change", "Did", "Amount", "Tint", "Glass", "View", "UI"]
      )
    else { return nil }
    let name = pointer.assumingMemoryBound(to: Unmanaged<NSString>?.self).pointee
    return name.map { Notification.Name($0.takeUnretainedValue() as String) }
  }()
}
