import SwiftUI

// Run with `swift tool/title_motion_probe/main.swift` on macOS 14 or later.
// These are public Spring samples, not measurements of a system title transition.
let candidates: [(String, Spring)] = [
    ("current", Spring(duration: 0.45, bounce: 0.3)),
    ("snappy-default", .snappy),
    ("snappy-compact", .snappy(duration: 0.30, extraBounce: 0.07)),
]
for (name, spring) in candidates {
    print("\(name): mass=\(spring.mass) stiffness=\(spring.stiffness) damping=\(spring.damping)")
    for time in stride(from: 0.0, through: 0.6, by: 0.025) {
        print(String(format: "%.3f,%.8f,%.8f", time, spring.value(target: 1.0, time: time), spring.velocity(target: 1.0, time: time)))
    }
}
