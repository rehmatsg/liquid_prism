# Native edge sampling probe

Measures how the native scroll edge effect fills its blur where the kernel
reaches past the screen edge, and how wide its blurs are, then compares
Liquid Prism against it. Findings: `doc/native_scroll_edge_spec.md`,
"Edge sampling and width".

Each scene paints black and white bands fixed in screen coordinates under a
scroll view with `.scrollEdgeEffectStyle(.soft)`, so captures do not depend on
the scroll offset. The apps also dump the effect's layer tree (`CAFilter`
inputs such as `inputNormalizeEdges`, backdrop `scale` and `marginWidth`).

- `run.sh [out]`: macOS SwiftUI app; window captures need Screen Recording
  permission for the terminal. `PROBE_STYLE=hard` measures `.hard`.
- `SIM=<udid> DISPLAY_ARG=--display=1 run_ios.sh [out]`: iOS app on a
  simulator (the iOS 27.1 runtime supports only the iPhone Duo; display 1 is
  folded).
- `SIM=<udid> DISPLAY_ARG=--display=1 run_flutter_ios.sh [out]`: the Flutter
  twin, `example/lib/edge_probe_main.dart`, on the same simulator.
- `uv run analyze.py <run> [style] [x0 x1 strip_pt fit_end_pt]`: fits
  clamp, mirror and renormalised edges to one run.
- `uv run compare.py <native run> <flutter run> [x0 x1]`: line width, halo,
  edge row and RMS per scene, plus side-by-side plots and text crops.

Runs default to `_research/edge_sampling/` (local evidence, not committed).
