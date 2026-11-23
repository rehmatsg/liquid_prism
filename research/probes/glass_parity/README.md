# Glass parity harness

One app shows Liquid Prism's regular glass and SwiftUI `glassEffect(.regular)`
side by side over the same Flutter-painted backdrop. Every screenshot carries a
code strip, so any screenshot can be analyzed on its own. This is research
tooling: nothing here ships.

- `example/lib/parity_main.dart`: the app. The screen is split into two
  columns of `floor(physical width / 2)` pixels; the right column's backdrop is
  the left one translated by exactly one column. Left: the layout's `LiquidPrism`
  surfaces at package defaults (no glass, optics, blur or tint arguments, so
  they follow the device amount). Right: nothing from Flutter except the backdrop.
- `ParityChannel` in `example/ios/Runner/AppDelegate.swift`: puts a
  non-interactive `UIHostingController` over the Flutter view with
  `Color.clear.glassEffect(.regular, in:)` at the same local rects, reads
  `UIViewGlassGetTintAmount`, forwards `UIViewGlassTintAmountDidChangeNotification`
  / `didBecomeActive`, dumps the glass layers' filter inputs, and exposes a
  `parity-status` accessibility element for UI tests.
- `tool/native_dispersion_probe/Tests/ParityTests.swift`: device (or simulator)
  XCUITest driver: launch-argument sweep, Settings-slider sweep and watch mode.
- `capture.py`: runs captures. `analyze.py`: turns screenshots into numbers.

Layouts (column-local points, every shape centred on x = 100), chosen with
`--layout` / `--parity-layout` and recorded in the strip's layout byte:

- `default` (1): capsule 150×48 at y 120, rect 150×96 r28 at y 220, rect
  170×170 r34 at y 370. Unfiltered input row y = 600.
- `ladder` (2): six rects 150 wide, heights 48, 64, 80, 104, 130, 170, radius
  min(28, h/2), from y = 90 with 18-pt gaps. Unfiltered input row y = 60.

Patterns (index = strip byte): `grouped white black gray50 vedge hedge
lines_white lines_black ramp grating8 grating32 grating64 patches photo`, then
the kernel probes `out8 out24 out48 out8_inv out24_inv out48_inv in24 in24_inv
dot dot_inv bar_h bar_h_inv bar_v bar_v_inv vedge_mid vedge_rg vedge_by vedge_rc
gray25 gray75 red green blue out2 out4 out12 out16 out20 out28 out32 out40`.
`outN`/`inN` grow/shrink the union of the layout's exact outlines with a
round-join stroke, without anti-aliasing.

Each run writes `geometry.json` (DPR, column width, every layout's shapes in
physical pixels with radius and kind, the input row, and each pattern's exact
definition) next to `shots/`.

## Build

```sh
cd example
flutter build ios --simulator -t lib/parity_main.dart     # simulator (debug)
flutter build ios --release -t lib/parity_main.dart       # iPhone
```

After shader include edits, `rm -rf example/.dart_tool/flutter_build` first.

## Capture

Run from the repository root. Output goes to `artifacts/glass-parity/<kind>-<time>/`
(`shots/`, `dumps/` with filter dumps and logs, `notes.txt`) unless `--out` is given.

```sh
# Simulator: simctl launch + screenshot, one launch per amount, both appearances.
python3 tool/glass_parity/capture.py sim --udid <sim> --install \
  --amounts 0,0.25,0.5,0.75,1          # or --step 0.05; add --build to rebuild

# iPhone: XCUITest launch-argument sweep (installs with --build/--install).
python3 tool/glass_parity/capture.py device --udid <phone> --install --step 0.05

# iPhone: the real Settings slider, driven by the UI test
# (Settings > Appearance > Liquid Glass, 11 positions, then restored).
python3 tool/glass_parity/capture.py device --udid <phone> --mode settings --positions 11

# Fallback: keep a session open for 20 min while someone moves the slider by
# hand; each return to the app with a new amount is captured automatically.
python3 tool/glass_parity/capture.py device --udid <phone> --mode watch --minutes 20

# Settings-driven run on a simulator.
python3 tool/glass_parity/capture.py xcuitest --udid <sim> --mode settings

# Live: launch without an amount, follow the slider, tap to change pattern.
python3 tool/glass_parity/capture.py live --udid <sim-or-phone>
```

`--appearances light,dark` and `--patterns all|name,...` narrow any run. The
phone must be unlocked with Auto-Lock off for UI tests. The machine has no
Xcode account, so device UI tests reuse the existing team profiles: the test
bundle is built as `dev.prism.nativeShowcase.tests` (`--tests-bundle-id`).

App launch arguments, for manual use: `--parity-appearances`,
`--parity-patterns`, `--parity-layout`, `--parity-ack` (simulator file
handshake), `--parity-dwell <s>` (auto-advance), `--parity-live`,
`--parity-settings` (restart frames on an amount change), `--parity-no-native`,
`--parity-clean` (empty `Documents/parity/` at launch; sweeps pass it on their
first launch), `-UIViewGlassTintAmount <v>`. A tap advances. Files land in the
app's `Documents/parity/`. Filter dumps are named
`filters-<appearance>-t<amount>-<mode>-<layout>-<pattern>.json`: one per
amount, appearance and layout, plus, on the default layout, one while each of
`white`, `black` and `vedge` shows.

When UI automation cannot be enabled on the phone ("Timed out while enabling
automation mode"), capture without XCTest: the app advances by itself and
`devicectl` takes the screenshots.

```sh
uv run tool/glass_parity/capture_devicectl.py --udid <phone> --out <dir> \
  --install example/build/ios/iphoneos/Runner.app --amounts 0,0.5,1
```

## Analyze

```sh
uv run tool/glass_parity/analyze.py artifacts/glass-parity/<run> [more runs or PNGs] [--out DIR]
```

Writes `cases.csv` (per shape), `summary.csv` (per source × layout × mode ×
appearance × amount), `report.json` (with edge profiles and tone curves) and `report.html`
(summary, launch-argument vs slider table, native filter inputs vs
`doc/native_defaults_spec.json`, worst cases with native | Flutter | diff×8
crops). Errors are 8-bit RGB, Flutter minus native, over the face interior:
the shape inset by 12 pt with its original corner radius (corner exclusion).

- Edge spread: 10–90 % width (px) of the step along the row (vedge) or column
  (hedge) through the shape centre, inside the face, averaged over ±2 pt.
- Grating contrast: least-squares sine amplitude at the known period on the
  centre row, divided by the same fit on the layout's unfiltered row.
- Tone transfer (ramp): face centre row vs the unfiltered row at the same x,
  binned by input gray in 16 steps.
- Launch argument vs slider: matching amount, appearance and pattern compared
  pixel by pixel over the shape boxes.

## Code strip

16 × 8 cells of 5 pt, 8 pt from the left and 40 pt above the bottom; two bytes
per row, MSB first, white = 1: `A7 5C`, native amount ×10000 (2 bytes, FFFF =
none, read from the native getter just before the frame was announced),
Flutter's `LiquidPrismSystemChrome.deviceGlassTintAmount` ×10000 (2), flags
(1 dark, 2 live, 4 settings, 8 native glass shown, 16 ready), pattern index,
DPR ×10, column width px (2), layout id, epoch (amount changes), seq,
checksum (sum of the 14 previous bytes), 0. The analyzer tries scales 3, 2, 1.

## Limits

- The left column's left neighbour and the right column's right neighbour are
  off-screen, so the outer 15–25 pt of each shape see different surroundings;
  the interior inset keeps most of that out, not all of it for wide blurs.
- Simulator builds are debug (JIT); the phone runs release. Compare like with like.
- Screenshot values are the display's 8-bit output; both sides go through the
  same path, so differences are comparable but not absolute colour values.
