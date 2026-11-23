# Native showcase comparison — 2026-10-11

The standalone reference app in `tool/native_showcase` mirrors Explore, Studio,
Library and all nine component routes, using native SwiftUI components and UIKit
inline chrome. Both release apps were installed on the connected iPhone. The
reference's captions use the system font; the earlier invalid named-font fallback
was corrected before the final device installation.

Measurements and recordings use the same iPhone 17 simulator, 402 × 874 points
at 3×, iOS 27.0 (24A5370g). The original 34-state capture includes the subsequently removed sheet route.
The current comparison fixture covers 32 states across nine routes and four
scrolled panels in light and dark appearances. Flutter render-box transforms and
native UIKit/SwiftUI geometry are saved alongside the images. Native lens motion
is sampled from presentation layers during genuine XCTest touch gestures.

The component geometry agrees at rest: switch 63 × 28 with a 37 × 24 thumb,
slider track 6 points high with a 37 × 24 thumb, and a 32-point segmented track.
At the detail preview's 306-point width, both sliders and segmented controls have
the same 306 × 44 touch region. Native held sizes remain in
`native_controls_spec.json` and are checked by the geometry regression tests.

The final slider recording measures a stationary held knob at 57.35 × 37.2
points and a fast-reversal peak at approximately 63.86 × 32.98. The native
recording reaches approximately 63.34 × 33.29. These are measured presentation
bounds, not extracted target settings, and the gesture paths/timing differ
slightly. The motion regression also checks a brief 48 ms flick followed by a
stationary hold, ensuring flex remains visible after short input bursts.

The final slider retains its 1.55× hold enlargement and opts out of broad underlay
minification. Its six-point track keeps its thickness through the lens. The 100%
recording verifies value 1 while held; the active fill reaches the end. Twenty-one native active-fill layer samples
recover the first/last 2% blend, preventing an endpoint snap. Regression tests
compare the full near-endpoint curve in both directions. All four controls share
the clear face, continuous contour and size-relative shadow. Tab deformation
retains the early motion research's independent axes, tracking lag and recoil.

There are still differences in the reference/app layout and renderer. The earlier 354-point Flutter navigation housing has been corrected: both
showcase implementations now use a compact 274 × 62-point three-tab housing.
Additional native width probes are recorded in `native_tab_layout_spec.json`. Some system-font metrics, symbol glyphs, button padding,
gradient compositing and resulting panel heights differ. Public native glass
does not expose Flutter's frost/refraction parameters, and an inline UISearchBar
has a different presentation context from navigation `.searchable`. Flutter's
optical operators and motion coupling remain calibrated approximations; this
comparison does not establish bit-identical rendering of the entire app.

Validation: 116 package tests, eight showcase tests, two extraction-tool tests,
two native showcase UI tests and four native lens gesture tests passed. Flutter
analysis and the running fixture's runtime error check were clean. Both app releases were installed and launched on the iPhone. The final smooth
fill release was built; its device update awaits the iPhone reconnecting.

Local evidence is generated under the ignored `artifacts/native-showcase` folder:
`final` contains the 34 state pairs; `lenses` contains native presentation traces
and test results; `lenses-final-delivery` contains the final Flutter traces, held and
100% captures, cropped native clips and `unified-controls.mp4`. See the reference
app README for reproduction instructions.
