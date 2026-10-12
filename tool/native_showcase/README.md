# Native showcase reference

A standalone native iOS app mirroring the Flutter showcase's Explore, Studio,
Library, ten component routes, artwork, palette, settings and interactive flows.
Toggle, Slider, segmented Picker, Button/Menu, TabView and sheet use native
components. Inline toolbar/search/tab previews wrap their UIKit counterparts.
There is no recreated native glass shader or popup renderer in this app.

Generate the project with `xcodegen generate`, then build/run the NativeShowcase
scheme in Xcode. Deployment target is iOS 26. Device builds require your own
development signing team; the project defaults to unsigned simulator builds.
The configured bundle identifier updates the existing Prism Native reference app.

`ShowcaseTests` exercises navigation, every route, filtering, native switch/slider/
segmented actions, popup selection and sheet expansion/results. `LensMotionTests`
performs real holds, two-second glides and fast reversals on all four controls.

Development inspection is opt-in: `--inspect` writes UIKit geometry, layer settings
and SwiftUI layout preferences to Documents. `--screen sliders`, `--dark`,
`--accent green` and `--scroll optics` select reference states. `--motion sliders`
records presentation-layer lens bounds/transforms at up to 60 Hz. None of these
options change native component rendering. They are not linked into Flutter.

The Flutter comparison entry point is `example/test_driver/showcase.dart`.
Run `native_showcase_compare.dart` with `PRISM_SIMULATOR_ID`, `PRISM_COMPARE_OUT`
and `DART_VM_SERVICE_URL` after installing this app and launching that fixture.
It captures matching light/dark states and rejects missing native snapshots.
`unified_lens_video.dart` uses those same environment variables plus
`PRISM_LENS_OUT` to record Flutter hold/glide/reversal clips and geometry samples.

After building the UI test bundle, `record_motion.py SIMULATOR OUTPUT_DIRECTORY`
records the native lens tests and copies their measured presentation bounds.
It needs Xcode at `/Applications/Xcode.app`, the matching simulator, and Python 3.
Recordings, generated projects and builds are ignored by Git.

Public native glass has no equivalent parameters for the Flutter shader's frost
and refraction controls. Those settings retain their app state in this reference
but do not retune Apple's renderer. UIKit inline search also has contextual
differences from SwiftUI's full navigation `.searchable` presentation. Fonts,
SF Symbols, adaptive tab sizing and the two rendering engines can produce layout
and pixel differences; this app provides a native reference, not proof of
bit-identical rendering.
