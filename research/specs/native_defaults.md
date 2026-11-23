# Native defaults calibration

The November 2026 sweep compares SwiftUI and Liquid Prism on the same iPhone 17
Pro simulator: iOS 27.0 (24A434), 402 × 874 points at 3×. A secondary iPhone Duo
probe checks semantic colors and face inputs on iOS 27.1 (24A94232). The inputs
and renderer fits are separate in [the measurement packet](native_defaults_spec.json).

The comparison covers light/dark appearance, tint amounts 0, .25, .5, .75 and 1,
and grouped, cell, white and two textured backgrounds. Native controls use real
XCTest touches. Held and released captures cover ordinary/prominent buttons,
on/off switches, a slider, a segmented selection and a tab selection. The gallery
manifest lists individual cases. The focused state sweep also covers both slider
endpoints and every tab/segment selection at the standard setting. The full
showcase pages are paired separately. Captures are evidence, not package assets.

## Material defaults

Regular glass was re-measured in November 2026 on an iPhone 16 Pro (iOS 27.0.1)
with native `glassEffect(.regular)` laid over the same Flutter backdrop as
Liquid Prism's glass, at 21 device amounts and with the real Settings slider.
Native filter inputs were identical for the launch argument and the slider, and
did not change with backdrop content. The inputs, by device amount `t`:

| Input | Value |
| --- | --- |
| Base / fill blur radius | 5 / 8 |
| Lighten (light) or darken (dark) opacity | .675 + .45 t up to .5, then .9 |
| Normal fill opacity | t |
| Light face fill | white at .4 t up to .5, then .2 + .6 (t − .5) |
| Base blur share (`inputBlurOpacity0`) | (side − 64) / 120 for a shortest side of 64–150 points |
| Bleed blur radius | .35 × side, none up to 64 points |

Direct measurements of how native composes them, which the renderer follows:

- The backdrop stays sharp under the fill. The fill is lighten-blended (darken
  in dark appearance) at the directional opacity, then mixed normally.
- A blur radius is half the Gaussian sigma: the fill is sigma 16.
- The base blur's radius, not its opacity, scales with the base share and
  halves toward the rim. Surfaces up to 64 points have none.

Fitted renderer behaviour, not recovered Apple algorithms:

- Impeller's blur needs 1.16× the sigma to match a true Gaussian.
- Dark bleed: sigma .9 × the bleed radius, gain 1.6 saturating at white,
  graded from .125 to .365 and lighten-blended at .716 of the base share.
  The renderer has no blur that wide: it averages the fill (sigma 16) at four
  points a ring apart, kept inside the face. Beside bright content a
  170-point dark surface is up to about 4 levels (of 255) further from native
  than a true wide blur was.
- Light face tone `.4 + v (.627 − .035 v)`, measured on surfaces without depth
  terms, with a contrast gain about the black point of 1 + .087 × base share.
- Regular rim: an additive highlight of .18 at the contour over 1.31 points
  under the existing diffuse lobe; exterior line at .6 alpha in dark
  appearance (.75 and slightly wider on large surfaces), and the backdrop
  lowered by .3 on the sides in light appearance.

Explicit app blur/optics still bypass the device-setting curve. Clear glass
keeps its previous curve.

Surroundings, measured with white content at set distances outside the
surface:

- Native reads its backdrop up to `inputOuterRefractionAmount` outside the
  contour (16 points, or a quarter of the shortest side up to 37.5) and
  nothing farther. The renderer's fill blur is not clipped to that margin.
- The outermost point of the face mirrors the surroundings from about that
  distance outside, at .6 opacity on the contour falling to nothing one point
  in, graded like a small surface. This is why rims brighten next to other
  glass or bright content.
- A plain surface keeps its lens down to small sizes: the renderer fades it
  out only between 16 and 10 points on the shortest side
  (`NativeGlassDepth.lens`). An earlier revision removed it at 48 points and
  below. A same-capture comparison of 44 pt circles and capsules over checker,
  stripe and text backdrops showed native bending its backdrop there; with
  the lens on, the mean edge error over seven backdrops fell from 13.9 to 9.6
  levels in light appearance and 18.2 to 13.0 in dark, while the face error
  rose by 1.3 to 1.8. Tab bars, toolbars, buttons and search fields keep
  their lens at every size; an explicit `refraction` is used as given.
  Native's band is still wider than the renderer's.

Known differences: native renders saturated colours beyond sRGB and limits
bright primaries differently in dark appearance; native has an EDR rendition
of light glass (face white 1.03), which this renderer follows only when HDR is
enabled and the display has headroom ([HDR measurements](native_hdr_rim.md)).

Dark regular glass also needs its native gray face fill and SDR luma limit. Small
capsules report a .6 limit. The 150 × 96 surface reports .48/.44/.4 at amounts
0/.25/.5 and stays at .4 above that. The larger levels probe reports
.45/.4/.35. The renderer interpolates these inputs by size and uses a fitted
quadratic tone rolloff. The gray fill above .5 is applied separately. Clear and
lifted control lenses bypass this regular-glass treatment.

Standalone regular surfaces use the native exterior-shadow and inner-ring
strengths. The earlier half-strength adjustment is removed. The rim refraction,
chromatic fringe, continuous contours and motion equations are unchanged.

Regular glass uses the measured quiet highlight matrix in both appearances; the
stronger dark matrix had exaggerated cyan rims on tinted surfaces. Clear and
control-lens highlight matrices are unchanged.

The native selected-tab blur remains 2 points and is unchanged. Native grouped
page/cell backgrounds match the existing palette on both checked OS versions.
The showcase separator now uses the measured source alpha: .12 in light and .5
in dark. Text buttons use the native large-button regular label and 15-point
vertical padding. Ordinary-button text uses the semantic tint directly; selected
tab accents match the native grouped background at rest and while held. Native tab vibrancy still
adapts to other backgrounds, which the fixed foreground palette approximates.
Explicit appearance overrides retain precedence.

Disabled prominent buttons use the native neutral tint matrix instead of the
enabled accent. Dark segmented selections use a translucent (235, 235, 245) fill at .3 alpha
over the track and white text. This matches native over grouped, cell and white
backgrounds; disabled controls apply .5 alpha to the same composition. Explicit material/selection
color overrides retain precedence.

## Validation

The gallery contains 384 native/Flutter pairs: 50 resting material cases, 140
holds, 140 releases, 10 disabled cases, 12 endpoint/selection cases and 32 showcase
views. Resting cases cover all five backgrounds; holds/releases use grouped and
vertical-texture backgrounds at all five amounts. Disabled cases use grouped
pages; endpoints/selections and showcase views use the standard amount. The
before revision covers 50 material cases and eight showcase views.


At the standard .5 setting, mean absolute RGB error in a text-free regular-face
patch over the 32-point vertical texture drops from 16.94 to 3.78 levels in light
appearance and from 48.44 to 3.94 in dark (8-bit channels). The packet records the
exact region and all five settings. This measures that material patch, not the
whole app or animation parity. Native glyphs, text metrics, some control geometry
and backdrop-adaptive tab foregrounds still differ. A single Gaussian also
cannot reproduce native blur-fill behavior at every texture frequency.

## Reproduce

See [the calibration tools](../tool/native_defaults/README.md). Use the same
simulator for each pair and retain the setting reported by the native getter in
its JSON. Launch arguments override that process's UIKit preference; they do not
change the user's system setting. The core optical shader still owns refraction,
sampling and lighting; the changes are material grading and configuration.
