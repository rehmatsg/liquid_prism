# /// script
# requires-python = ">=3.11"
# dependencies = ["numpy", "pillow", "matplotlib"]
# ///
"""Reads a probe run and reports how the native scroll edge fills its blur
past the window edge.

For every scene the mean luminance of each pixel row across the window's
middle columns is normalised per row against the white and black scenes:
b(y) = (W - S) / (W - B) is the black fraction the effect leaves at row y,
with the fade and tint removed. Edge models (clamp = repeat the edge row,
mirror = reflect content, normalize = drop missing taps and reweight) are
fitted to every line/band scene at once as a two-Gaussian mix.

usage: uv run analyze.py <run dir> [style] [x0 x1 strip_pt fit_end_pt]
"""
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

run = Path(sys.argv[1])
style = sys.argv[2] if len(sys.argv) > 2 else "soft"
meta = json.loads((run / "meta.json").read_text())
scenes = {s["name"]: s for s in meta["scenes"] if s.get("style", "soft") == style}
box = meta.get("contentBounds") or meta["screen"]
H = float(box.strip("{}").replace("{", "").replace("}", "").split(",")[-1])
X0, X1 = (float(sys.argv[3]), float(sys.argv[4])) if len(sys.argv) > 4 else (130.0, 470.0)
STRIP = float(sys.argv[5]) if len(sys.argv) > 5 else 52.0
FIT_END = float(sys.argv[6]) if len(sys.argv) > 6 else STRIP


def profile(name):
    img = np.asarray(Image.open(run / f"{name}.png").convert("RGB"), dtype=np.float64) / 255
    scale = img.shape[0] / H
    x0, x1 = int(X0 * scale), int(X1 * scale)
    lum = img[:, x0:x1, :].mean(axis=(1, 2))
    return lum, scale


W, scale = profile(f"{style}_white")
B, _ = profile(f"{style}_black")
G, _ = profile(f"{style}_gray")
rows = len(W)
y_pt = (np.arange(rows) + 0.5) / scale

# Marker check: the red 2 pt line at 380 pt.
img = np.asarray(Image.open(run / f"{style}_white.png").convert("RGB"), dtype=np.float64)
red = np.where((img[:, img.shape[1] // 2, 0] > 200) & (img[:, img.shape[1] // 2, 1] < 80))[0]
report = {"scale": scale, "marker_rows": [int(red.min()), int(red.max())] if len(red) else None,
          "marker_expected_rows": [int(380 * scale), int(382 * scale) - 1]}


def black_fraction(name):
    S, _ = profile(name)
    den = W - B
    with np.errstate(divide="ignore", invalid="ignore"):
        return np.where(np.abs(den) > 0.02, (W - S) / den, np.nan)


def content(scene, top=True):
    """Black coverage (1 = black) of the scene's content per row, in window space."""
    c = np.zeros(rows)
    for band in scene["bands"]:
        if band.get("red"):
            continue
        if band.get("fromBottom"):
            y0, y1 = H - band["y1"], H - band["y0"]
        else:
            y0, y1 = band["y0"], band["y1"]
        lo, hi = y_pt - 0.5 / scale, y_pt + 0.5 / scale
        c += np.clip((np.minimum(hi, y1) - np.maximum(lo, y0)) * scale, 0, 1) * (1 - band.get("gray", 0))
    if scene["background"] < 0.5:
        c = 1 - c
    return np.clip(c, 0, 1)


def blur(c, sigma_pt, mode, strip):
    """Gaussian blur of c over window rows with the given edge handling.
    strip = (start, end) rows the capture covers; normalize also drops taps
    beyond the strip, as a backdrop captured at its own bounds would."""
    s = sigma_pt * scale
    r = int(math.ceil(3 * s))
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / s) ** 2)
    out = np.empty(rows)
    a, b = strip
    for i in range(a, b):
        idx = np.arange(i - r, i + r + 1)
        if mode == "clamp":
            v = c[np.clip(idx, 0, rows - 1)]
            out[i] = (v * k).sum() / k.sum()
        elif mode == "mirror":
            j = np.abs(idx)
            j = np.where(j >= rows, 2 * rows - 2 - j, j)
            out[i] = (c[j] * k).sum() / k.sum()
        else:  # normalize within the strip
            m = (idx >= a) & (idx < b)
            out[i] = (c[idx[m]] * k[m]).sum() / k[m].sum()
    return out


top_rows = (0, int(STRIP * scale))
fit_rows = (0, int(FIT_END * scale))
fit_names = [n for n in scenes if any(t in n for t in ("band", "line", "below")) and "_b" not in n]
data = {n: black_fraction(n) for n in fit_names}
cont = {n: content(scenes[n]) for n in fit_names}
a, b = fit_rows
results = {}
for mode in ("clamp", "mirror", "normalize"):
    best = None
    for s1 in (8, 12, 16, 20, 24, 30, 36, 42, 50, 60):
        for s2 in (0.5, 1, 1.5, 2, 3, 4):
            cols, ys = [], []
            for n in fit_names:
                c = cont[n]
                b1 = blur(c, s1, mode, top_rows)[a:b]
                b2 = blur(c, s2, mode, top_rows)[a:b]
                cols.append(np.stack([b1, b2], 1))
                ys.append(data[n][a:b])
            X = np.concatenate(cols)
            Y = np.concatenate(ys)
            ok = np.isfinite(Y)
            w, *_ = np.linalg.lstsq(X[ok], Y[ok], rcond=None)
            rms = float(np.sqrt(np.mean((X[ok] @ w - Y[ok]) ** 2)))
            if best is None or rms < best["rms"]:
                best = {"rms": rms, "sigma_heavy": s1, "sigma_light": s2, "weights": w.round(3).tolist()}
    results[mode] = best
report[f"fit_rows_0_{FIT_END:g}pt_strip_{STRIP:g}pt"] = results

# Model-free signals.
def at(name, y):
    v = data.get(name)
    if v is None:
        v = black_fraction(name)
    return float(np.nanmean(v[int(y * scale):int((y + 1) * scale)]))

report["edge_row_black_fraction"] = {n: round(at(n, 0), 3) for n in sorted(data)}
report["band8_vs_band8x_max_diff"] = float(np.nanmax(np.abs(black_fraction(f"{style}_band8") - black_fraction(f"{style}_band8x"))[a:b])) \
    if f"{style}_band8x" in scenes else None
report["white_scene_lum_by_pt"] = {y: round(float(W[int(y * scale)]), 3) for y in (0, 4, 10, 20, 30, 40, 48, 52, 56, 70, 100)}
report["black_scene_lum_by_pt"] = {y: round(float(B[int(y * scale)]), 3) for y in (0, 4, 10, 20, 30, 40, 48, 52, 56, 70, 100)}

# Per-scene profiles for the report.
prof = {n: [None if not np.isfinite(v) else round(float(v), 4) for v in data[n][: int(80 * scale): int(scale)]] for n in sorted(data)}
(run / f"analysis_{style}.json").write_text(json.dumps({"report": report, "profiles_pt_0_80": prof}, indent=1))
print(json.dumps(report, indent=1))

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

fig, axes = plt.subplots(2, 2, figsize=(13, 9))
ys = y_pt[: int(80 * scale)]
for ax, group in zip(axes.flat, (("line",), ("band",), ("below",), ("line0", "band2"))):
    names = [n for n in sorted(data) if any(n.endswith(g) or g + "" in n.split("_", 1)[1][: len(g)] for g in group)]
    for n in names:
        ax.plot(ys, data[n][: len(ys)], label=n.split("_", 1)[1])
    ax.axvline(STRIP, color="k", lw=0.5, ls=":")
    ax.set_xlabel("pt from window top")
    ax.set_ylabel("black fraction b(y)")
    ax.legend(fontsize=7)
ax = axes.flat[3]
ax.cla()
n = f"{style}_line0"
if n in data:
    ax.plot(ys, data[n][: len(ys)], "k", lw=2, label="native line0")
    for mode, col in (("clamp", "r"), ("mirror", "g"), ("normalize", "b")):
        r = results[mode]
        c = cont[n]
        pred = r["weights"][0] * blur(c, r["sigma_heavy"], mode, top_rows) + r["weights"][1] * blur(c, r["sigma_light"], mode, top_rows)
        ax.plot(ys[: b], pred[: b], col, label=f"{mode} fit (rms {r['rms']:.3f})")
    ax.axvline(52, color="k", lw=0.5, ls=":")
    ax.set_title("4 pt black line touching the top edge")
    ax.legend(fontsize=8)
fig.suptitle(f"Native scroll edge ({style}), top strip; b(y) = (white - scene)/(white - black)")
fig.tight_layout()
fig.savefig(run / f"analysis_{style}.png", dpi=110)
