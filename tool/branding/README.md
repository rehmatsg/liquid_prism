# Glass wordmark

Render the reference artwork's style with code:

```sh
bash tool/branding/render.sh
```

The default output is `artifacts/branding/liquid-prism-coded.png`, a 1920 × 1080
sRGB PNG. The renderer uses local SF Pro Display Semibold outlines from CoreText,
a Euclidean distance field, rounded contours, and Metal kernels for the bevel,
rim lighting, subtle pastel reflections, and two Gaussian shadow layers. It renders
at 2× resolution before resolving to the final size. No image generation or
reference-image pixels enter the render.

Requires macOS, the Xcode command-line tools, a Metal GPU, and installed SF Pro
fonts. The font is not bundled or redistributed.

```sh
bash tool/branding/render.sh --text "Liquid Glass" --output artifacts/branding/reference-fit.png
bash tool/branding/render.sh --scale 4 --output artifacts/branding/liquid-prism-fine.png
bash tool/branding/render.sh --4k --output assets/liquid-prism-4k.png
bash tool/branding/render.sh --help
```

`--font`, `--font-size`, `--tracking`, `--bevel`, `--face-strength`, and
`--shadow-strength` allow further fitting. `--scale` changes supersampling, not
the output dimensions. `--4k` renders 3840 × 2160 directly from the font outlines
and shader, preserving the reference proportions and lighting. These are fitted
artwork values, not captured native material parameters. This standalone shader
does not change Liquid Prism's runtime shader assets or public API.
