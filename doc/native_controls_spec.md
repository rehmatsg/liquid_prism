# Native switch, slider and segmented control

These components use the same inspection approach as the tab bar: query native
UIView/CALayer geometry and settings, intercept spring constructors, and sample
presentation layers during actual touches. Screenshots are a rendering check;
they do not supply the geometry or spring constants.

Reference: SwiftUI Toggle, Slider and segmented Picker on iPhone 17, iOS 27.0
runtime build 24A5370g, SDK build 24A430, 402 × 874 points at 3×. Light and dark
appearances, disabled controls, taps, held thumbs and continuous drags were
captured. The probe is isolated in tool/native_control_probe; it is never linked
into the Flutter package or example app. Private inspection belongs only there.

## Directly extracted values

| Property | Switch | Slider | Segmented control (300 points, 3 items) |
| --- | --- | --- | --- |
| Visible track | 63 × 28 | 300 × 6 | 300 × 32 |
| Resting pill | 37 × 24 | 37 × 24 | 96 × 28 |
| Held pill | 58 × 38⅓ | 57.35 × 37.2 | 120 × 44 |
| Resting inset | 2 | Thumb center: 18.5 + (width − 37) × value | 2 per slot |
| Selection/position spring, response / damping ratio | .3 s / 1 | .4 s / .8 | .4 s / .85 |
| Drag position constructor | .3 s / 1 | .4 s / 1 | .2 s / .85 |
| Lift spec, response / damping ratio | .27 s / .625 | .27 s / .625 | .25 s / 1 |
| Unlift spec, response / damping ratio | .5 s / .7 | .5 s / .7 | .25 s / 1 |

The switch's thumb centers are 20.5 and 42.5 points. The slider's held size is
exactly 1.55 times its resting size. Both use the small lens spec and preferred
flex variant 4 (small loupe). The segmented pill uses the large lens spec with
that same flex variant; its lifted bounds grow 24 horizontally and 16 vertically.
The probe records the settings object as well as constructors with their native
call sites; a constructor is not a complete description of the private scheduler.

The track colors come from native layer backgrounds or the native generated
UIImage's center pixel, not a composited screenshot. Small thumbs and the
segmented selection are opaque white at rest. The segmented track resolves to
tertiarySystemFill. Disabled native visual elements have alpha .5. The slider thumb has a native
layer shadow with opacity .14, radius 5 and offset (0, 1); the held lens adds
opacity .06, radius 3 and offset (0, 7). Its filter ring shadow has width 4,
radius 3, offset 8 and opacity .4 for small controls or .1 for the segmented pill. Slider tracks
resolve to black at .1 in light appearance and white at .1 in dark appearance.
Control fills use the shared GlassColors palette. The switch defaults to the
palette green and honors an explicit inherited tint, as does the slider. The resting fills, tracks,
clips, lens optics and shadows all use the same continuous capsule contour.
Segment labels use 13-point SF regular and medium, with native grade G3.

The native held-lens capture includes vibrant highlight matrices, inner
refraction inputs and face black/white/saturation inputs. Small native lenses
have no separate underlay warp at the captured hold; the segmented lens has
an underlay displacement of 9.
The JSON records the complete selected filter inputs, lens settings, switch
settings, fluid-slider settings, small-loupe flex settings, typography and source
SHA-256 hashes.

## Renderer limits and implementation choices

The geometry, source colors and specified springs above are measured. Flutter's
custom shader approximates Apple's private Core Animation glass/SDF operators.
The velocity-to-flex coupling, highlight compositing and shadow kernels remain
approximations; the native small-loupe .444 s / .56 scale spring is used with
an approximate velocity input. Flutter's system font does not expose grade G3.
This is a calibrated reproduction, not a claim that private native rendering is
bit-for-bit identical on every background or OS release.

All lifted handles and selections now use `ControlLens`: the same clear face,
continuous contour, size-relative rim/reflection inputs and exterior shadow.
The shadow paints after the optical pass, preventing its clipped mask from
appearing as a second capsule inside the selection. The held ambient blur and
ring blur scale with the current lens height; they replace the fixed, dense ring
approximation. Their Gaussian conversion and opacity remain renderer calibrations.

The shared broad underlay field minifies the switch, segmented track and tab
housing while the foreground stays sharp at its normal size. The slider opts out
of that broad field: **the knob still grows to 1.55× on hold, but the track seen
through it keeps its normal thickness**. Its rim refraction, clear face and shadow
still use the shared material. This matches the distinction in the isolated
small-lens capture without claiming to reproduce Apple's private operators.

The tab retains the earlier research's lens-speed stretch (0.018 points per
point/second), independent cross-axis compression, spring lag and recoil. Sharing
the optical widget does not replace those fitted motion curves. Small controls
now derive speed from timestamped finger samples rather than a position spring;
the slider follows the finger directly and therefore has no position-spring
velocity to drive flex. The captured .444/.56 scale spring and .032 retarget
impulse drive the small-control response. The spring-force interpretation of that
impulse, the 120 ms velocity decay window and the speed-to-target mapping remain
fits. The displacement-per-speed input uses the early tab motion research,
normalized to the held small lens; it is not recovered UIKit scheduling.

Touch targets have a 44-point height; the visible track retains its native height.
Slider values are reported continuously; switch and segmented drags commit on
release. Parents own values, including rejected changes and external updates.
The active-fill layer follows the thumb centre through the middle 96% of the
range. Across the first and last 2%, native blends that width with proportional
full-track progress. Direct layer samples at 21 values recover this mapping to
within .001 point (`native_slider_fill_spec.json`). The same continuous blend now
reaches empty/full at the endpoints; there is no endpoint-only fill shortcut.
During a slider drag, the thumb follows each contact sample directly; the
captured travel spring still animates taps and external changes. Intercepting a
drag spring constructor alone does not establish native per-sample scheduling.
A null callback disables pointers, keys and semantic actions. RTL reverses the
physical axis. Reduce Motion removes lift/stretch and settles position immediately.
The slider also supports discrete divisions and arbitrary numeric ranges; those
are package behavior, outside the captured continuous-slider reference.

Switch feedback defaults on for iOS (`haptics: false` opts out). The extracted
switch settings enable feedback with zero delay and impact intensity 1. The
renderer uses Flutter's native light-impact bridge, also used by CupertinoSwitch:
one pulse on a toggle, or at each on/off boundary crossed during a drag. Releasing
or canceling a drag adds no pulse; disabled controls and external value updates
are silent. Simulators cannot reproduce the physical vibration.

## Reproduce

Use Xcode with the reference runtime installed and xcodegen. From
tool/native_control_probe, generate the project, then build and run the four UI
tests on the chosen simulator (parallel testing disabled). The app writes
Documents/specs, Documents/extracted and Documents/motion in its simulator data
container. Copy them to a local raw directory as specs, layers and motion.

```sh
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project ControlSpecs.xcodeproj -scheme ControlSpecs \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_ID' \
  -derivedDataPath build -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
# From the repository root, after copying the three native output directories:
python3 tool/extract_controls_spec.py PATH_TO_RAW_DIRECTORY
```

The tracked example has a controls gallery and a standalone controls_main.dart.
For the recording fixture, run example/test_driver/controls.dart, then run
controls_video.dart against its VM service with PRISM_SIMULATOR_ID,
PRISM_CONTROLS_OUT and DART_VM_SERVICE_URL set. The recording shows taps, stationary
holds, slow drags both ways and releases for each component. Videos and raw native
captures stay in the ignored artifacts/research directories.
