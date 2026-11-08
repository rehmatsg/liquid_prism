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

Regular glass uses fitted Gaussian frost equivalents in logical pixels:

| Device amount | 0 | .25 | .5 | .75 | 1 |
| --- | --- | --- | --- | --- | --- |
| Light | 5.20 | 6.76 | 8.32 | 10.11 | 12 |
| Dark | 2.98 | 5.07 | 7.12 | 9.62 | 12 |

These replace the earlier 3.3-point frost and the unsupported `lighten`/`darken`
backdrop blends. Impeller's backdrop layers require supported pipeline blend
modes; the equivalents use an opaque `srcOver` blur. They approximate native's
asymmetric blur-fill composition rather than reproduce its kernel. Explicit app
blur/optics still bypass the device-setting fit. Clear glass keeps its light base
blur; its additional blur fill reaches 12 points at the highest setting.

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
enabled accent. Disabled dark segmented controls use the native subdued pill and
label contrast, fitted over the grouped background. Explicit material/selection
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
