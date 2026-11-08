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

The negative key/fill draws the thin dark line outside regular glass. Over
white in light appearance (iOS 27.0 simulator tab bar) it darkens the
rounded ends by 40 and 79 levels across its two device pixels and the top
and bottom by 14–28, about 30% of the ends; dark appearance shows no dark
line. How the spread angles produce that falloff is not recovered: the
renderer holds the light-mode line at a fitted floor of 30% of its side
strength (`glass_core.glsl`), which reproduces the top (241, 232 against
native 241, 231) and the ends (−45, −73 against −40, −79).

Clear glass has no top or bottom line (same probe, white, #F2F2F7 and #C7C7CC
backgrounds): its rounded ends darken by 76–85 levels, about as regular's do,
and the darkening falls to nothing by about 80° around the arc, where regular
glass keeps about 30%. Its `inputKeyFillHighlightSpread` is 1.309 (75°)
against regular's 1.676 (96°), which matches that falloff; the algorithm is
not recovered. The renderer's clear glass therefore keeps its ends-only line.

### The rim over white on iOS 27.2

Measured on an iPhone Duo (iOS 27.2, 3x, light, white page) from the native
probe (`--scene tint`, captured at tint 0.25) and a native app, and compared
with Liquid Prism rendered at a 3x raster (macOS Impeller with the frame
scaled 1.5 on a 2x display; both builds were also captured on the iPhone
through the Flutter driver and agree with macOS to a level):

| Profile (device pixels, outside → inside) | Native | Before | After |
| --- | --- | --- | --- |
| Regular, side of a 48 pt circle or 38 pt button | 254 \| 215, 175 \| 248, 249 | 255 \| 211, 178 \| 248, 250 | 255 \| 211, 178 \| 248, 251 |
| Regular, top centre | 241, 231 \| 255 for 2.7 pt, then down to 248 by 9 pt | 242, 232 \| 254, 254, 253, then down to 250 | 242, 232 \| 255 for 4 pt, then down to 251 by 8 pt |
| Regular, bottom centre | 236, 228 \| 255 × 10, then 254, 253 | 239, 229 \| 253, 254, 254, 255 | 239, 229 \| 255 throughout |
| Clear, side | 255 \| 217, 179 \| 255 | 251 \| 204, 135, 224 \| 250 | 251 \| 220, 175, 233 \| 251 |

The dark exterior line already matched for regular glass. What made native
rims read on white was the full-white band just inside the line at the top
(2.7 pt) and bottom (3.3 pt) against a slightly grey face: Liquid Prism had
none, because the inner ring was painted over the face up to the edge (253
right inside the line) and regular glass used a 1-point diagonal highlight
that no capture supports. Changes:

- Regular glass now draws the vertical key/fill lobes of clear glass (the
  dumps show identical `CASDFKeyFillHighlightEffect` inputs for both) with the
  matrix the iOS 27.2 dumps show for regular highlights in light appearance
  (`1.1202 −0.1894 −0.0190 / −0.0563 0.9871 −0.0191 / −0.0563 −0.1893 1.1574`,
  bias 0.1471, the lens matrix). On the prominent button the green channel
  above the face now reads about +25, +10, +8, +7, +6 from 1 to 3 points
  deep against native's +22, +9, +6, +4, +3 (aligned at the dark line, ±1
  device pixel; before: +37, then nothing past 1 point); the first point stays
  dimmer (+40 against +65). Dark appearance
  keeps its previous matrix: no dark capture exists for 27.2.
- The inner ring moved from a canvas stroke into the optical shader, under the
  key/fill, where native layers it. It is the same stroke (width 4, moved 8
  down, sigma 5, opacity 0.06 × the shadow strength) as a one-dimensional
  blurred band across the moved contour's distance, which is exact along
  straight edges. It is kept out of a band 2.67 pt under the top and 3.3 pt
  above the bottom, fading back by 8 pt and from 20° to 60° off vertical: a fit
  to the profiles above, not Apple's ring operator.
- Clear glass's line uses the measured −0.3 colour bias as regular's does
  (0.46 before, which darkened its ends by 120 levels against native's 76).

Remaining differences on white: the native face is 2–5 levels greyer inside
the band (its ring dip reaches 248, ours 251, and its button centres sit at
249–250 where ours stay at 253–255). No measured input explains that level,
so it is unchanged. The line on dark and colourful backdrops keeps the black
coverage band: no capture separates an additive −0.3 bias from it there.

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

Standalone Regular surfaces use the captured exterior-shadow and inner-ring
strengths, matching Clear at a given size. Buttons and tab bars use the separate
captured control profile described below. Strength is independent of frost. The
optical shader draws the ring under the key/fill highlight and below foreground
content (`u_face.y` carries its opacity).
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

Controls use their captured Regular profile. Explicit Clear
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
