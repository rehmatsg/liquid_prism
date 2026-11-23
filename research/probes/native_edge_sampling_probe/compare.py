# /// script
# requires-python = ">=3.11"
# dependencies = ["numpy", "pillow", "matplotlib"]
# ///
"""Compares a Flutter probe run against a native one, scene by scene.

b(y) = (W - S) / (W - B) per row, averaged over columns [x0, x1] pt, where W
and B are the same run's (and style's) all-white and all-black scenes. For
4 pt lines it reports the blur actually applied (FWHM of the line's profile,
its peak) and the halo (mean b 10-30 pt from the line, i.e. a wide, faint
component laid over the sharp content: a glow rather than a blur).

usage: uv run compare.py <native dir> <flutter dir> [x0 x1]
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

native, flutter = Path(sys.argv[1]), Path(sys.argv[2])
X0, X1 = (float(sys.argv[3]), float(sys.argv[4])) if len(sys.argv) > 4 else (20.0, 300.0)


class Run:
    def __init__(self, path):
        self.path = path
        self.meta = json.loads((path / "meta.json").read_text())
        self.cache = {}

    def lum(self, name):
        if name not in self.cache:
            img = np.asarray(Image.open(self.path / f"{name}.png").convert("RGB"), dtype=np.float64) / 255
            self.scale = img.shape[0] / float(self.meta["screen"].replace("{", "").replace("}", "").split(",")[-1])
            x0, x1 = int(X0 * self.scale), int(X1 * self.scale)
            self.cache[name] = img[:, x0:x1, :].mean(axis=(1, 2))
        return self.cache[name]

    def b(self, style, name):
        W, B, S = self.lum(f"{style}_white"), self.lum(f"{style}_black"), self.lum(f"{style}_{name}")
        den = W - B
        with np.errstate(divide="ignore", invalid="ignore"):
            return np.where(np.abs(den) > 0.02, (W - S) / den, np.nan)

    def has(self, scene):
        return (self.path / f"{scene}.png").exists()

    def pt(self, arr, y0, y1):
        return arr[int(y0 * self.scale): int(y1 * self.scale)]


N, F = Run(native), Run(flutter)


def line_stats(run, style, y):
    b = run.b(style, f"line{y}")
    ys = (np.arange(len(b)) + 0.5) / run.scale
    sel = (ys >= y - 20) & (ys <= y + 24)
    seg, yy = b[sel], ys[sel]
    peak = float(np.nanmax(seg))
    above = yy[seg >= peak / 2]
    fwhm = float(above.max() - above.min()) if len(above) else float("nan")
    halo_sel = ((ys >= y + 14) & (ys <= y + 34)) | ((ys >= y - 30) & (ys <= y - 10) & (ys >= 0))
    halo = float(np.nanmean(b[halo_sel]))
    return {"peak": round(peak, 3), "fwhm_pt": round(fwhm, 2), "halo": round(halo, 4)}


report = {"lines": {}, "rms_vs_native_0_120pt": {}, "edge_row": {}}
for y in (0, 8, 16, 32, 48, 64, 96):
    row = {"native": line_stats(N, "soft", y), "ours": line_stats(F, "soft", y)}
    if F.has(f"nohaze_line{y}"):
        row["ours_nohaze"] = line_stats(F, "nohaze", y)
    report["lines"][f"line{y}"] = row
for name in ("line0", "line8", "line16", "line32", "line48", "line64", "line96", "band2", "band8", "band24", "below150", "below160"):
    if not (N.has(f"soft_{name}") and F.has(f"soft_{name}")):
        continue
    bn = N.pt(N.b("soft", name), 0, 120)
    bf = F.pt(F.b("soft", name), 0, 120)
    n = min(len(bn), len(bf))
    report["rms_vs_native_0_120pt"][name] = round(float(np.sqrt(np.nanmean((bn[:n] - bf[:n]) ** 2))), 4)
    report["edge_row"][name] = {"native": round(float(np.nanmean(N.pt(N.b("soft", name), 0, 1))), 3),
                                "ours": round(float(np.nanmean(F.pt(F.b("soft", name), 0, 1))), 3)}
report["fade_black_scene_lum"] = {
    who: {y: round(float(run.lum(f"soft_black")[int(y * run.scale)]), 3) for y in (0, 10, 20, 40, 60, 80, 100, 120, 140)}
    for who, run in (("native", N), ("ours", F))
}
if F.has("off_line0"):
    off = F.b("off", "line0")
    report["simulator_leak_off_line0_rows_5_to_15pt"] = round(float(np.nanmean(F.pt(off, 5, 15))), 4)
    report["off_line16_peak_and_fwhm"] = line_stats(F, "off", 16)
(flutter / "compare.json").write_text(json.dumps(report, indent=1))
print(json.dumps(report, indent=1))

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

fig, axes = plt.subplots(2, 3, figsize=(15, 8))
for ax, y in zip(axes.flat, (0, 8, 16, 32, 48, 64)):
    for run, style, label, col in ((N, "soft", "native", "k"), (F, "soft", "ours", "r"), (F, "nohaze", "ours, haze 0", "b"), (F, "off", "ours off (sim leak)", "0.6")):
        if not run.has(f"{style}_line{y}"):
            continue
        b = run.b(style, f"line{y}")
        ys = (np.arange(len(b)) + 0.5) / run.scale
        sel = ys < 130
        ax.plot(ys[sel], b[sel], color=col, lw=2 if label == "native" else 1.2, label=label)
    ax.set_title(f"4 pt black line at {y} pt")
    ax.set_xlabel("pt from screen top")
    ax.set_ylabel("b(y)")
    ax.legend(fontsize=8)
fig.suptitle("Scroll edge, soft: native iOS 27.1 vs Liquid Prism (iPhone Duo simulator, light)")
fig.tight_layout()
fig.savefig(flutter / "compare_lines.png", dpi=110)

# Text crops: top 150 pt, x 0-320 pt, side by side.
crops = []
for run, scene in ((N, "soft_text"), (F, "soft_text"), (F, "nohaze_text"), (F, "off_text")):
    if run.has(scene):
        img = Image.open(run.path / f"{scene}.png").convert("RGB")
        s = img.height / float(run.meta["screen"].replace("{", "").replace("}", "").split(",")[-1])
        crops.append(img.crop((0, 0, int(320 * s), int(150 * s))))
if crops:
    w = sum(c.width for c in crops) + 20 * (len(crops) - 1)
    sheet = Image.new("RGB", (w, crops[0].height), "white")
    x = 0
    for c in crops:
        sheet.paste(c, (x, 0))
        x += c.width + 20
    sheet.save(flutter / "compare_text.png")
