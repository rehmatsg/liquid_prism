# Title spring reference

Run `xcrun swift tool/title_motion_probe/main.swift` on macOS 14 or later.
The probe prints public SwiftUI `Spring` parameters, positions and velocities.
It does not capture a system navigation-title animation.

The title uses the equivalent of `.snappy(duration: 0.30, extraBounce: 0.07)`.
This is a contextual tuning choice: 300 ms perceptual duration and 0.22 bounce.
The previous 450 ms / 0.30 configuration reached 75.7% at 150 ms and overshot
by about 4.6%; the new configuration reaches 93.4% and overshoots about 2.0%.
The package regression test compares its simulated trajectory with native samples.

Apple explains perceptual versus settling duration, velocity-preserving
interruptions, and tuning preset springs in
[Animate with springs](https://developer.apple.com/videos/play/wwdc2023/10158/).
The [snappy API](https://developer.apple.com/documentation/swiftui/animation/snappy(duration:extrabounce:))
defines a base bounce of 0.15. We add 0.07 for a restrained visible rebound.
