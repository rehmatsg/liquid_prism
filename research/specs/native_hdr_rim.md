# HDR rim measurements

On 2026-11-10, the supplied Reddit screenshot `IMG_7523.heic` was decoded with
Core Image's HDR expansion into floating-point extended linear sRGB. ImageIO
reports 10-bit Display P3 and content headroom 1.2. Its SHA-256 is
`94d839fb94eac702d39a82406b638d93bbb3c2d1eaf2c9d3804adfbf9d622406`.
The two supplied JPEGs are 8-bit Display P3 with headroom 1. Capture settings
are supplied by the user; the exact source app/OS build is not embedded.

At x = 114, across the native circle's upper rim (source pixel coordinates):

| y | HDR linear neutral value |
| --- | --- |
| 184 | .9424 |
| 185 | .9078 |
| 186 | 1.1988 |
| 187 | 1.2015 |
| 188 | 1.1738 |
| 190 | 1.0996 |
| 196 | 1.0625 |
| 204 | 1.0394 |

The white page measures 1.0012; values close to it include encoding error.
The native circle's lower rim also peaks at 1.2015. This establishes a
brighter-than-SDR rim in this capture, not a universal 1.2 native constant or
Apple's lighting algorithm. JPEG output clips that brightness distinction and
also changes the dark contour. Reproduce with `tool/hdr_probe/analyze.swift`.

## Renderer fit

Light glass uses up to 1.3 linear headroom on supported iOS surfaces. A
same-capture comparison at 8× capture headroom (44 pt circle, capsule, white
page) measured native regular at about 1.30 on the poles and flat edges, 1.17
at 25°, 1.10 at 50° and 1.04 at the sides, over a face of 1.07 that dips to
1.03 toward the sides and under the top rim. The earlier 1.20 peak came from a
capture reporting only 1.2× headroom.

- The face follows the unclamped linear face matrix with headroom: white is
  1.03 encoded (about 1.07 linear) for regular and 1.08 (about 1.19) for
  clear, the same matrix whites the SDR path clamps to 1. The regular inset
  ring stays on and produces the dip.
- `hdrRim` adds linear radiance in the first point inside the contour, fading
  between .5 and 1 pt, then encodes to nonlinear extended sRGB. Light regular
  uses `.01 + .09 n² + .12 n³²` (n is the vertical normal component), light
  clear `.025 n⁸`, and dark clear a one-pixel `.15 n³²` glint. Dark regular
  already matched over black and is unchanged.
- The reference's 1–2 pt inner shoulder under the rim (about .03–.04) is not
  treated as additive emission: that read as an inner glow.

After these changes all four material/appearance pairs matched native within
about .02 on the rim and .01 on the face in the same capture. These are
rounded renderer curves checked against measurements over plain white and
black, not a recovered Apple operator. Coloured backdrops, larger sizes and
the SDR rendition of the dark clear glint were not measured. Custom optics and
lifted lenses retain their existing lighting.

Two recipe changes came from the same comparison. The native regular and clear
recipes draw no reflection band, since nearby labels showed as streaks native
does not have. Plain clear surfaces cast no material shadow.

The HDR regular surface shadow uses the captured native size profile and
8 pt drop, without the older synthetic contact/ambient additions. The
radius-to-sigma factor 2/3 and 1/3 pt drop correction are renderer fits.
The HDR dark contour's width and
vertical strength are calibrated separately from the exterior shadow.
Captured native inputs themselves are unchanged.

## Output and verification

Flutter 3.47.4 on the connected iPhone (iOS 27.2, 3x) presents BGRA10_XR
(Metal format 552) in extended sRGB. Enabling the public CAMetalLayer EDR flag
raised reported headroom from 1 to 8. The plugin caps its lighting budget at
1.3 and leaves the engine's pixel format/color space alone. Brightness, active
state, headroom observations and layout refresh that budget. The system's HDR
usage-limit trait is ignored: native glass keeps its HDR rendition under
Control Center, and following the trait made Prism's rim drop there;
startup rechecks are bounded, with no permanent display link or timer.

The probe preserved encoded values `[.5, 1, 1.04, 1.0832683]` in Float32.
Default XR snapshots quantized the last two to 1.0392158 and 1.082353.
Standalone and grouped glass reached 1.082353 with HDR lighting enabled and
1.0 when disabled, while ordinary white stayed 1.0. Blur preserved the HDR
patch. These are GPU readback measurements, not photometer measurements.

Native overlays and Liquid Prism are compared in the same device capture at
identical geometry. A devicectl PNG is useful for the dark contour/shadow but
clips HDR. The narrow highlight profile still needs HDR-preserving capture
comparison; display headroom plus GPU readback do not establish pixel parity
with the native HDR compositor. Local captures remain under `artifacts/hdr-rim/`.

In paired 44 pt circle and 150 × 44 pt capsule captures, mean absolute error
across the two contour pixels fell from 4.5 to 0 eight-bit levels at the sides,
from 3.5–4 to 1.5–2 at the top, and from 6–6.5 to 2–2.5 at the bottom.
These numbers cover only the sampled contour, not whole-image similarity.

## Circle thickness and angular extent

The fitted 3x contour is centred at (114,252), radius 66 px. Bilinear sampling
and four-quadrant aggregation reduce pixel-phase/compression noise. Relative
to page white, the peak is approximately 1.20. The bright core (at least 90%
of the peak HDR excess) is about 2 px / .6 pt thick and spans roughly ±25°
around each vertical pole (about 50° total). At half the HDR excess, the
radial width is about 4 px / 1.4 pt and the angular span is about ±50°.
These thresholds describe visibility; there is no hard 90° endpoint. A faint
tail remains near 1.04 at the side midpoints. Screenshot geometry and compression
limit precision; these are rounded measurements, not exact native constants.

Reproduce using `analyze.swift --raw` and `tool/hdr_probe/measure.py`. Keep raw
float buffers and charts in `artifacts/`. The comparison app has a light
column on white and a dark column on black. Each has grouped Prism regular,
native regular, grouped Prism clear and native clear rows, with a labelled
44 pt circle and 120 × 44 pt capsule. SwiftUI `Glass` and UIKit
`UIGlassEffect` have no public intrinsic-shadow switch; native clear reports
zero shadow inputs by itself.
