# Regular rim contrast regression

Use the native/defaults fixture and Flutter counterpart described in
[the capture guide](../native_defaults/README.md). Capture `white,grouped` at
amounts `0,0.5,1` on the same simulator, with identical geometry. Stop and clean
rebuild Flutter after changing included GLSL files: an incremental app rebuild
can retain a compiled shader whose root `.frag` file has not changed.

Run the profile gate with Pillow available:

```sh
uv run --with pillow python tool/rim_contrast/compare.py \
  artifacts/rim-contrast/native artifacts/rim-contrast/after
```

The gate compares the top-centre rim and adjacent face of the first regular
capsule, avoiding its text. Its default tolerance is one eight-bit channel level
of mean absolute error. The captured baseline fails (1.469); the corrected
renderer passes (0.654). It does not assess entire-image parity. The measured
runtime, fixture and fit are recorded in [native shadows](../../doc/native_shadows.md).
Raw captures stay outside git. Inspect other controls and compare clear/dark
fixtures separately when changing the shared shader.
