# Native tab bar: directly extracted spec

Extracted on 2026-10-11 from the **actual four-tab SwiftUI showcase** on an
iPhone 17 simulator: 402 × 874 pt, 3× scale, iOS 27.0 build **24A5370g**,
dark appearance, wallpaper 0. These values describe this build and fixture,
not a public Apple API or a universal layout contract.

[Machine-readable capture](native_tab_bar_spec.json) contains geometry,
fonts, symbol metadata, settings, all tab-bar optical passes, intercepted
spring constructor counts and representative live flex-property samples.
The full traces and extractor are in _research/tab_bar_specs/.
No screenshots, videos or image-based curve fitting were used.

## Extraction method

An Objective-C probe embedded in the real SwiftUI showcase reads UIView
geometry, UILabel fonts, UIImage symbol metadata, CALayer model and
presentation transforms, archived CAFilter input keys, CASDF effects, and
native lens/flex settings. Instrumentation installed before UI creation
intercepts UIViewSpringAnimationBehavior constructors, including arguments
and call stacks. A CADisplayLink records target value, presentation value and
velocity from live animatable flex properties.

XCUITest exercised a tap, a two-second hold on another tab and a slow held
drag to Settings. All three passed. A separate drag run captured 691 flex
frames. The older motion_extraction report used a narrower three-tab fixture
and fitted several curves; those fits are not exact four-tab specifications.

## Geometry and foreground

These are direct model-view reads unless labelled presentation.
Native tab items overlap; the layout is not an equal-width Row.

| Property | Native value |
| --- | --- |
| Housing | 360 × 62 pt, screen origin (21, 791) |
| Housing bottom margin | 21 pt |
| Resting lens | 95⅔ × 54 pt |
| Resting lens endpoint and vertical inset | 4 pt |
| Held lens model bounds | 111⅔ × 70 pt |
| Tab centre X coordinates on screen | 72⅚, 158.2777778, 243.7222222, 329⅙ pt |
| Centre spacing | 85.4444444 pt |
| Base label | SF Pro, 10 pt, **medium** |
| Selected portal label | SF Pro, 10 pt, **semibold** |
| Base label model height / top | 12 pt / 830 pt on screen |
| Held selected item source transform | **1.16×** in both axes |
| Held stationary housing presentation transform | **1.039272030651341×** in both axes |

Native keeps separate selected and unselected foreground copies. The selected
copy is viewed through a displaced portal. Recoloring one row cannot reproduce
its weight, scale and warping.

The housing **expands** on contact. Our earlier inverse scale was incorrect.
The 274 pt and 360 pt fixtures both have a stationary presentation width
increase of 14.1379310344828 pt. The formula
**1 + 14.1379310344828 / width** reproduces those two stationary observations.
It is **derived**, not recovered from UIKit's implementation. During a drag
the native housing's X and Y scale targets differ.

| Symbol | UIImage size (pt) | UIImageView bounds (pt) | View top (screen pt) |
| --- | --- | --- | --- |
| hand.draw | 21⅓ × 21⅓ | 29⅔ × 29⅓ | 800⅔ |
| list.bullet | 21 × 15 | 29⅓ × 21 | 804⅓ |
| square.grid.2x2 | 19⅓ × 18 | 27 × 25 | 802⅓ |
| slider.horizontal.3 | 21 × 17 | 29⅓ × 23⅔ | 803 |

UIImage size, view size and painted symbol ink are distinct. The JSON also
records baseline and alignment insets. These measurements do not make
CupertinoIcons identical to SF Symbols.

## Exact lens settings

The active tab lens uses UIKit._UILiquidLensViewLargeVariantSpec.

| Property | Value |
| --- | --- |
| liftSpring.response / dampingRatio | **0.25 s / 1** |
| unLiftSpring.response / dampingRatio | **0.25 s / 1** |
| lensHangTime | **0.22 s** |
| liftedDisplacement | **9 pt** |
| contentWrapperDisplacement | **−17.5 pt** |
| unliftedBlurRadius / unliftedDisplacement | 0 / 0 |
| innerShadowOffsetY / radius / opacity | 7 pt / 3 pt / 0.06 |
| warpsContentBelow | true |
| liftedContentMode | 1 |

Both springs have zero retarget impulse and disabled smoothing/projection.
Their tracking settings are response 0.15 s, damping ratio 0.86. These belong
to lens lift, not necessarily position tracking. The hang-time value is exact;
its private state-machine semantics have not been recovered.

Selection/layout call stacks construct springs at **0.4 s and 0.6 s**,
both with damping ratio **0.85**. Drag call stacks also construct **0.2 s
and 0.3 s** springs with damping ratio **0.85**. Those arguments are directly
intercepted. Mapping each behavior to a particular position/deformation
property remains unresolved. Flutter now uses the 0.4 s travel candidate,
replacing its 0.38 s fit.

## Flex settings and live targets

Housing preferredVariant is **0**; lens preferredVariant is **4**.
The numeric enum-to-variant mapping is unrecovered, so these root settings
are not asserted to be the active settings for either view.

| Root variant | liftScalePoints | movementScalePts | normalization | Normal response / damping |
| --- | ---: | ---: | ---: | --- |
| small | 16 | 10 | 10000 | 0.4 s / 0.375 |
| large | 4 | 5 | 10000 | 0.36 s / 0.6 |
| loupe | 0 | 100 | 2500 | 0.5 s / 1 |
| smallLoupe | 0 | 10 | 2000 | 0.444 s / 0.56 |

Full tracking settings, clamps, glow and pulse settings are in the JSON.
The live trace directly reads targets rather than reconstructing them from
visible bounds. In this drag, lens X targets span approximately 0.6167–1.2227
and Y targets 0.6474–1.2833. Presentation values differ as the animation engine
integrates. A single fixed area-preserving stretch does not express this
behavior. Target generation, the velocity integrator and retarget impulse
application remain unrecovered.

## Optical pipeline: exact inputs, unrecovered operators

The native pipeline contains multiple backdrop, SDF and portal passes.
These values belong to distinct passes; combining them in one refraction or
edge-width uniform loses information.

| Pass | Direct input |
| --- | --- |
| Below-content displacementMap | amount **9** |
| Underlay displacement SDF | height **36**, curvature **1** |
| Content-wrapper displacementMap | amount **−17.5** |
| Lifted displacement SDF | height **11.2**, curvature **1** |
| Lifted displacementMap | amount **−14** |
| Lens glassBackground | inner amount/height **−10.5 / 7**, blur **0**, outer amount/height **0 / 0** |
| Housing glassBackground | inner amount/height **−31 / 15.5**, outer **16 / 16**, blur **5** |
| Housing refraction opacity | approximately **0.6**, float32 |
| Lens highlight SDF | curvature **0.75**, key/fill amount **0.5 / 0.5**, angles **0 / π**, spreads **80° / 80°** |
| Lens diffuse highlight | amount scale **0.15**, height scale **8**, spread scale **0.65** |

Lens highlight vibrant matrix, rounded below; JSON retains float32 values:

    1.1202  -0.1894  -0.0190   0   0.1471
   -0.0563   0.9871  -0.0191   0   0.1471
   -0.0563  -0.1893   1.1574   0   0.1471
    0        0        0       1   0

CAFilter/SDF inputs do not expose QuartzCore's displacement, highlight,
compositing, color-space or portal implementations. Those operators remain
approximated in our shader. This capture does not establish pixel-perfect
rendering.

## Applied and remaining differences

Applied to Flutter: 250 ms critical lift/release springs, 220 ms hang-time
parameter, 400 ms travel candidate, correct housing expansion direction and
width-dependent stationary scale. The showcase has native 21 pt horizontal
and bottom margins. The lifted lens now includes broad underlay minification
using the captured 9 pt displacement and 36 pt SDF height. Its profile is
implemented with the package's existing circular optical approximation;
it does not claim to reproduce the private QuartzCore operator exactly.

Still approximate: adaptive overlapping layout, selected portal weight/scale/
warping, SF Symbols, position tracking, two-axis flex target generation,
housing spring timing, glow and optical operators. The existing sampled
launch deformation remains a fit. Further changes should use property-linked
instrumentation and the captured pipeline without labelling fits exact.


The shared held-lens renderer now supplies the tab, switch, slider and segmented
selection's clear face, continuous rim and size-relative shadow. The tab retains
the researched motion above: its own lens velocity drives independent stretch
and compression, including recoil as tracking settles. The slider alone opts out
of broad underlay minification; its held bounds still grow by 1.55×. See
`native_controls_spec.md` for the shared material's calibrated rendering limits.
