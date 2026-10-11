# Native glass shadows

The iOS 27.0 Simulator was inspected using an owned SwiftUI app, rather than
estimating shadow settings from screenshots. The app rendered regular and clear
`glassEffect` surfaces at the showcase's actual sizes. Runtime KVC inspection
recorded the `glassBackground` filter's inputs and the model CALayers. The glass
shadows live inside this private filter; ordinary CALayer shadow properties were
zero. No private API is used by the Flutter package.

Portable records, including raw capture hashes, are in
`test/fixtures/native_shadows.json`. The local research archive is
`_research/shadow_extraction/`; it includes native screenshots and full layer
dumps. Original probe sources are under `_research/tint_extraction/Sources/`.

## Recovered regular-glass inputs

All dimensions below are logical points. Opacity and color alpha are distinct
native inputs; the effective black shadow alpha is their product.

| Shape / size | Shadow radius | Shadow opacity, light | Shadow opacity, dark | Offset |
|---|---:|---:|---:|---|
| Card, 260 × 160, continuous radius 32 | 24 | 0.4000000059604645 | 0.6000000238418579 | (0, 8) |
| Capsule, 180 × 60 | 4 | 0.03999999910593033 | 0.03999999910593033 | (0, 8) |
| Circle, 96 × 96 | 10.666666666666666 | 0.1599999964237213 | 0.226666659116745 | (0, 8) |

Shadow color: extended sRGB `(0, 0, 0, 0.30000001192092896)`.

Regular glass additionally has:

| Input | Exact extracted value |
|---|---:|
| Ring stroke width | 4 |
| Ring blur radius | 5 |
| Ring offset | 8 |
| Ring opacity | 0.05999999865889549 |
| Ring mask | 1 |
| Negative key/fill height | 0.5333333333333333 |
| Negative key/fill effect offset | -0.5333333333333333 |
| Negative key/fill color bias | -0.3 |
| Negative key/fill amount | 0.4 |
| Negative key/fill angle | 1.5707963267948966 |
| Negative key/fill spread, light | 1.6755160819145565 |
| Negative key/fill SDR spread, light | 1.8500490071139892 |
| Negative key/fill spread and SDR spread, dark | 1.3089969389957472 |

Angles are radians. Clear glass's shadow opacity/radius and all ring-shadow
inputs are zero in the captured fixtures. It retains its optical edge lighting.

A sweep at heights 32, 44, 64, 72, 80, 88, 96, 100, 120, 140, 160 and 200
establishes the light-mode size rule:

```
t = clamp((shortestSide - 64) / 96, 0, 1)
radius = 4 + 20*t
opacity = 0.04 + (0.40 - 0.04)*t
```

The dark-mode circle/card/control captures agree with a 0.60 endpoint. Production
retains the extracted float32 endpoint values. Intermediate opacity inputs differ
by ordinary float32 rounding; the test compares them within 4e-8. This is an
empirically verified rule for these fixtures, not recovered Apple source code.

## Flutter implementation and limits

Regular material retains the exterior shadow from before this extraction pass,
as requested after the live native shadow proved unreliable in screenshots.
The recovered size-dependent native shadow rule remains reference data; it does
not replace the established Flutter exterior shadow. Standalone surfaces use half exterior-shadow and inner-ring opacity in Regular
compared with Clear, as requested. Buttons and tab bars instead use the captured
control profile described below. Their strength remains independent of blur. This 0.5 factor
is a user-requested visual adjustment, not an extracted Apple parameter. The optical edge highlight still follows the material. The ring is painted above the optical face and below foreground content.
All passes follow the same continuous/circular contour and press transform.

The native inputs above are extracted values. The compositor implementation is
not recovered. The initial implementation used sigma = native radius × 2/3. That empirical
kernel conversion was reverted along with the exterior-shadow change; it was
**not an extracted Apple constant**.
The ring uses sigma 5. The negative color bias is represented by a black exterior
coverage band; that reproduces a white-background edge but is not Apple's full
backdrop-aware color operation. The package still has its own refraction,
reflection, face grading, antialiasing and blur-fill composition. An exact match
on arbitrary backgrounds, every size, every display mode or another OS build is
not established.

The earlier, now-reverted exterior-shadow implementation was checked using
controlled actual-Impeller captures with identical empty shapes and positions,
with native and Flutter screenshots both at 1206 × 2622. The local comparison
samples three profiles per shape: 24 points inward from the top, 30 points
outside the left edge, and five points across the left rim. Per-channel errors
on these samples are:

| Shape | Outer shadow mean / maximum | Inner top mean / maximum | Left rim mean / maximum |
|---|---|---|---|
| Card | 0.30 / 1 | 1.21 / 3 | 0.47 / 2 |
| Capsule | 0.00 / 0 | 1.69 / 3 | 0.60 / 1 |
| Circle | 0.07 / 1 | 1.40 / 3 | 0.80 / 1 |

Units are 8-bit channel steps. These historical screenshot profiles do not validate the live native shadow
reported as missing from screenshots. They are not a full-image
pixel-equivalence test or a similarity percentage. Native pixels supplied the
validation reference, not the shadow opacity, radius, offsets or color inputs.

Reproduce extraction by building `TintProbe.xcodeproj`, installing it in the iOS
27 Simulator, and launching `--scene shadows --mode light --background white
--run shadows-light-white`. JSON snapshots appear in the app's Documents/extracted
folder. `--scene shadow-size --width 260 --height N --radius 10000` selects a size
sweep fixture. `--scene clear-shadows` selects clear material.

## Capture follow-up

A follow-up probe sampled 61 live model/presentation frames around three
Simulator screenshots. For all three shapes, shadow/ring inputs were stable
and model and presentation values agreed. This does not explain or disprove a
shadow disappearing from physical-device screenshots: render-server/display
composition is not exposed by these app-layer properties. The prior exterior
Flutter shadow was restored rather than treating screenshot profiles as proof
that it should be reduced. Research is in
`_research/shadow_extraction/capture-investigation/`.

## Component shadow profiles

Buttons and tab bars call the same glass renderer as surfaces; they were never
excluded. The earlier global Regular multiplier nevertheless weakened their
ring, and a generic short-side formula replaced their native control profile.
They now select a separate captured control profile by `GlassRole.button` or
`GlassRole.tabBar`: radius 4, offset (0, 8), opacity
0.03999999910593033, black color alpha 0.30000001192092896, and ring opacity
0.05999999865889549 with width 4 and blur radius 5. Control inputs are independent
of frost. The default native button/tab-bar material is Regular; changing the
showcase's surface material does not change the SwiftUI button/tab-bar material.

The half-strength Regular rule now applies only to standalone surfaces. Controls
use their captured Regular profile without that extra multiplier. Explicit Clear
controls retain this shadow as requested for mode-independent control shadows;
that is app policy rather than an extracted native Clear-button profile. The
radius-to-sigma conversion still has the compositor limitation described above.

Portable per-component evidence is in `test/fixtures/native_control_shadows.json`:

| Captured component | glassBackground shadow / ring inputs present |
|---|---|
| Glass button | Yes |
| Glass prominent button | Yes |
| Floating tab bar | Yes |
| Toolbar glass | Yes (three regions in this fixture) |
| Tab bar with Search tab | Yes |
| Slider, toggle, segmented picker | No glassBackground filter in these captured fixtures |

The last row does not establish that these controls have no native shadows;
their rendering paths differ. Selected tab pills also have their own material
path; the captured exterior profile belongs to the tab-bar housing. No universal
shadow recipe is claimed for every SwiftUI control or presentation.
