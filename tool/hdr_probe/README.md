# HDR rim probe

Run from the repository root with an unlocked, connected iPhone:

```sh
python3 tool/hdr_probe/run.py --device <id>
```

This uses the example's iOS host. It temporarily declares the research shader
in the example pubspec and restores the original file when Flutter exits.
After included GLSL changes, remove `example/.dart_tool/flutter_build` before
building; hot restart cannot replace a cached shader program.

The screen has a light column on white and a dark column on black. Each has
four labelled rows: grouped Liquid Prism regular, native SwiftUI regular,
grouped Liquid Prism clear and native SwiftUI clear. Each row has a 44 pt
circle and a 120 × 44 pt capsule with a text label. `shadowInfo` reports each
native slot's material.
Brightness test patches are measured offscreen, leaving the comparison clear.
`--cycle` measures enabled, disabled, then enabled HDR rim lighting, leaving
the last enabled state visible. `--standard` starts with SDR rim lighting.

Logs report the actual Metal format, color space, display headroom, patch
readback, and peaks within the grouped glass. Encoded sRGB 1.0832683
is 1.20 in linear light. Float32 snapshots distinguish shader values from the
XR snapshot's quantization. Readback verifies the GPU path; it does not measure
physical display luminance. Native overlays are absent from Flutter readback.
The probe also writes raw extended-sRGB Float32 buffers, metadata and its log
under the example app's `tmp/prism-hdr-*` files. Copy them with devicectl's
`appDataContainer` domain. `--build-only` builds and restores the pubspec without
starting a Flutter run session.

Inspect original HDR images without an SDR conversion:

```sh
swift tool/hdr_probe/analyze.swift --x 114 --y 175 --count 160 IMAGE.heic
swift tool/hdr_probe/analyze.swift --horizontal --x 40 --y 252 --count 24 IMAGE.heic
swift tool/hdr_probe/analyze.swift --raw RAW.rgba32f IMAGE.heic
uv run tool/hdr_probe/measure.py RAW.rgba32f --width 1206 --height 371 \
  --circle 114 252 66 --out REPORT
```

The output is extended **linear** sRGB, with source metadata and pixel profiles.
For the probe's raw GPU buffers pass `--encoding srgb` to `measure.py` and use
the dimensions and circle coordinates from its metadata JSON. The circle
measurement reports threshold-dependent radial widths and angular spans rather
than assuming a hard visibility cutoff.
Keep captures and reports in ignored `artifacts/`, not in git.

For the dark contour only, capture the device using `devicectl device capture
screenshot` and compare its SDR PNG using geometry printed by the matching run:

```sh
uv run tool/hdr_probe/compare.py CAPTURE.png --log RUN.log
```

Its two-pixel contour error excludes the separate exterior shadow. The PNG
cannot establish HDR highlight parity. Use direct viewing or an HDR-preserving
capture for the bright rim. The source, fitted behavior and validation limits
are recorded in [HDR rim measurements](../../doc/native_hdr_rim.md).
