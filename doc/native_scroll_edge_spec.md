# Native scroll edge effect

Direct measurements of iOS's scroll edge effect, the softening of content
scrolled under a bar, taken with `tool/native_scroll_edge_probe` on the iPhone
17 simulator (iOS 27.0, build 24A434, 3x) in light appearance. The fixture is
a SwiftUI `NavigationStack` with an inline title, one leading and two trailing
glass bar buttons, and a `ScrollView` with `.scrollEdgeEffectStyle(.soft)` or
`.hard` for its top edge. The navigation bar frame is 62–116 pt (status bar 62,
bar 54); its 44 pt capsules sit at 62–106 pt.

Layer values come from the view hierarchy (`CAFilter` inputs, gradient
layers, mask images). Pixel profiles come from screenshots over 2 pt
black/white stripes: the local mean gives the fade toward the background and
the local amplitude the attenuation of the blur. 2 pt stripes cannot resolve
a blur wider than about 1 pt, so the heavy blur's radius is the layer value.

## Composition

Both variants draw the effect with three things:

| Part | Soft | Hard |
| --- | --- | --- |
| Heavy blur: `CABackdropLayer`, `gaussianBlur` radius 16, captured at scale 0.25, composited at **opacity 0.5** | Masked by an axial gradient with alpha 1 at **34%** of the strip falling **linearly** to 0 at its end | Unmasked: constant to the bar's edge |
| Light variable blur: `CABackdropLayer`, filter `blur` with `inputMaskImage` (1 × 384), `inputFade`, and a "blur fill" (radius 16, lighten 0.6, darken 0.4, normal 0.25) | `inputRadius` **1.5**; mask full to **37%**, zero from **96%**; `inputFade` true | `inputRadius` **2**; mask full to **56%**, falling to a **0.247** floor at the end; `inputFade` false |
| Edge | Reaches **40 pt below the bar frame** (156 pt total; 50 pt below the capsules) | Ends at the bar frame (116 pt) with a **1/3 pt hairline**, black at **10%** |

The container is 402 × 156 pt (soft) or 116 pt (hard). The effect's layers
do not change between rest and scrolled: content simply scrolls beneath them.
A `captureOnly` backdrop in the content hierarchy shares its capture group
with the effect's blur.

## Dark appearance

The same fixture in dark appearance (black background) keeps the structure
and changes the weights: the heavy blur composites at **opacity 0.6** (0.5 in
light) and the blur fill swaps its sides, darken 0.6, lighten 0.4, normal 0.
The masks, radii, extents and hairline are unchanged. Measured over the
stripes, the fade toward black is 0.57–0.59 at the top of the soft strip,
0.50 at 79 pt, 0.34 at 100 pt and 0.19 at 109 pt; the hard strip holds 0.54
to its edge. Liquid Prism keeps one default of 0.5 for the fade and the haze
in both appearances, half a step under native dark; `GlassScrollEdgeStyle`
raises either.

## Mask curve

The variable blur's mask ramp, read from the dumped mask image, fits
smoothstep (3t² − 2t³) with an RMS error of 0.013 over the soft ramp
(cubic-bezier(.33, 0, .67, 1) 0.013, cosine 0.016, smootherstep 0.040,
linear 0.066). The hard ramp onto its 0.25 floor fits cosine or smoothstep at
0.021–0.022. `GlassFadeCurve` is smoothstep.

| t | soft mask | hard mask |
| --- | --- | --- |
| 0 | 1.00 | 1.00 |
| 0.25 | 0.85 | 0.87 |
| 0.5 | 0.52 | 0.59 |
| 0.75 | 0.17 | 0.33 |
| 1 | 0.01 | 0.25 |

## Pixel profile (light, white background)

| y (pt) | soft fade | soft blur | hard fade | hard blur |
| --- | --- | --- | --- | --- |
| 0–24 | 0.50–0.55 | full (2 pt stripes gone) | 0.57–0.61 | full |
| 40–60 | 0.47–0.49 | full | 0.56 | full |
| 80 | 0.41 | full | 0.56 | full |
| 100 | 0.30 | attenuation 0.04 | 0.57 | attenuation 0.06 |
| 110 | 0.19 | 0.19 (σ ≈ 0.4 pt) | 0.56 | 0.14 (σ ≈ 0.45 pt) |
| 114 | 0.15 | 0.27 | 0.54 | 0.19 (σ ≈ 0.4 pt) |
| 116 | — | — | 0 (hairline) | none |
| 124 | 0.20 | 0.56 | — | — |
| 132 | 0.18 | 0.80 | — | — |
| 140 | ≈0 | ≈1 | — | — |

Rows 26–38 are contaminated by the status bar's time and are omitted. The
soft fade's 0.50 at the top and its half-value near 106 pt match a 0.5
opacity following the smoothstep mask; the hard fade is flat to the edge. The
hard blur's attenuation at the edge, 0.19, is what a 0.5 pt sigma leaves of
2 pt stripes: a quarter of the 2 pt radius, the mask's floor.

## What Liquid Prism takes from this

`GlassScrollEdgeStyle` defaults: variable blur sigma 1.5 (hard 2), falloff 98
pt of a 156 pt strip (hard 51 of 116), reach 50 pt past the bar (hard 0), fade
opacity 0.5, haze 16 at 0.5 masked linearly from 34% (hard constant), hard
floor 0.25 with the fade held flat and a one-pixel 10% black hairline. The
blur-fill opacities (lighten 0.6, darken 0.4, normal 0.25 in light; darken
0.6, lighten 0.4, normal 0 in dark) are reproduced only as the measured net
fade toward the background. The `.automatic` style was not measured; the
reveal over the first points of scroll is this package's, not native.

Not verified: whether the native glass bar buttons sample the content before
or after the effect. Over the stripes both read as frosted grey, and the
colour-band capture landed before the scroll settled. Liquid Prism gives its
glass the content before the effect by design; a flat colour under a native
capsule would settle it.

Raw dumps, mask images and screenshots are under `_research/scroll_edge/`
(local evidence, not shipped).
