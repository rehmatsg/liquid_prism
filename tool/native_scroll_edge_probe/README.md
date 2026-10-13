# Native scroll edge probe

Dumps the layers, filters, mask images and gradients of iOS's scroll edge
effect (the softening of content scrolled under a bar) and screenshots it
over a calibration pattern, for the measurements in
`doc/native_scroll_edge_spec.md`. Research only; nothing here ships.

```sh
tool/native_scroll_edge_probe/run.sh <simulator-udid> _research/scroll_edge [testSoftLight testHardLight ...]
python3 _research/scroll_edge/analyze.py _research/scroll_edge soft-light
python3 _research/scroll_edge/fit_curve.py _research/scroll_edge/images/<mask>.png
```

The fixture is a SwiftUI `NavigationStack` with an inline title, glass bar
buttons and a `ScrollView` of 2-point black/white stripes then flat colour
bands, with `.scrollEdgeEffectStyle` from the launch arguments (`--hard`,
`--auto`, `--light`). It scrolls itself and writes `Documents/extracted/
<state>-<style>-<mode>.json` plus the images it finds; the runner screenshots
the simulator when each extraction marker appears and copies everything out.

The extractor walks every window's layers and records class, window frame,
model and presentation opacity, `CAFilter` inputs (mask images and layer
contents are saved as PNG and sampled down their centre column), gradient
colors and locations, and UIKit view properties of edge-effect classes. KVC
on SwiftUI views trips Swift assertions, so only UIKit classes are inspected.
