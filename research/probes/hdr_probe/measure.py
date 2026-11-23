# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy", "matplotlib"]
# ///
"""Measure HDR circle highlights from a decoded RGBA Float32 capture.

uv run tool/hdr_probe/measure.py RAW --width W --height H --circle CX CY R --out PREFIX
Use analyze.swift --raw RAW IMAGE.heic first. Coordinates are pixel edges;
samples are bilinear at pixel centres. Radius is a fitted contour, not a
recovered native layout value. SDR white is sampled at (200,120).
"""
import argparse
import json
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

p = argparse.ArgumentParser(description=__doc__)
p.add_argument("raw")
p.add_argument("--width", type=int, required=True)
p.add_argument("--height", type=int, required=True)
p.add_argument("--circle", type=float, nargs=3, required=True)
p.add_argument("--encoding", choices=["linear", "srgb"], default="linear")
p.add_argument("--scale", type=float, default=3)
p.add_argument("--out", required=True)
args = p.parse_args()
image = np.fromfile(args.raw, dtype=np.float32).reshape(args.height, args.width, 4)[:, :, :3]
if args.encoding == "srgb":
    image = np.where(image <= .04045, image/12.92, ((image+.055)/1.055)**2.4)
luma = image @ np.array([.2126, .7152, .0722])
white = float(luma[120, 200])
luma /= white

def sample(x, y):
    x, y = x-.5, y-.5
    ix, iy = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = x-ix, y-iy
    return sum(luma[iy+dy, ix+dx]*((fx if dx else 1-fx)*(fy if dy else 1-fy))
               for dx in [0, 1] for dy in [0, 1])

cx, cy, radius = args.circle
degrees = np.arange(0, 360, .25)
depth = np.arange(-2, 24, .0625)
angle = degrees[:, None]*np.pi/180
r = radius-depth[None, :]
values = sample(cx+r*np.sin(angle), cy-r*np.cos(angle))
peaks = values.max(axis=1)
quadrant = np.arange(0, 90.25, .25)
symmetry = np.stack([peaks[(np.rint(a*4).astype(int)) % len(peaks)]
                     for a in [quadrant, -quadrant, 180+quadrant, 180-quadrant]])
median = np.median(symmetry, axis=0)
# Small angular bins reduce compression/subpixel phase noise, without
# treating the fitted geometry as a directly extracted native constant.
smoothed = np.convolve(np.pad(median, 4, mode="edge"), np.ones(9)/9, mode="valid")
peak = float(np.median(smoothed[:12]))

def crossing(threshold):
    below = np.flatnonzero(smoothed < threshold)
    if not len(below):
        return None
    i = below[0]
    if i == 0:
        return 0.0
    return float(np.interp(threshold, [smoothed[i], smoothed[i-1]], [quadrant[i], quadrant[i-1]]))

widths = {}
top = np.mean(values[[0, 720]], axis=0)  # top and bottom centres
for fraction in [.9, .75, .5, .25, .1]:
    threshold = 1+(peak-1)*fraction
    active = np.flatnonzero(top >= threshold)
    widths[str(fraction)] = {
        "linearThreshold": threshold,
        "radialWidthPixels": float(depth[active[-1]]-depth[active[0]]) if len(active) else 0,
        "radialWidthCensored": bool(len(active) and active[-1] == len(depth)-1),
        "arcHalfAngleDegrees": crossing(threshold),
    }
report = {
    "source": str(args.raw), "fittedCircle": args.circle,
    "sourceWhite": white, "normalizedPeak": peak, "deviceScale": args.scale,
    "widths": widths,
    "angularSamples": [{"degreesFromTop": float(d), "medianPeak": float(smoothed[int(d*4)]),
                        "minPeak": float(symmetry[:, int(d*4)].min()),
                        "maxPeak": float(symmetry[:, int(d*4)].max())}
                       for d in range(0, 91, 5)],
}
Path(args.out+".json").write_text(json.dumps(report, indent=2)+"\n")
fig, axes = plt.subplots(1, 2, figsize=(10, 3.8), layout="constrained")
axes[0].plot(quadrant, smoothed, color="#2c5fab")
axes[0].fill_between(quadrant, symmetry.min(axis=0), symmetry.max(axis=0), alpha=.15)
axes[0].set(xlabel="Angle from top/bottom (degrees)", ylabel="Peak linear luminance / page white",
            xlim=(0, 90), ylim=(.99, 1.22), title="Angular fade (four quadrants)")
axes[1].plot(depth/args.scale, top, color="#2c5fab")
axes[1].set(xlabel="Depth inside fitted contour (pt)", ylabel="Linear luminance / page white",
            xlim=(-.7, 8), ylim=(.7, 1.22), title="Top/bottom radial profile")
for ax in axes:
    ax.axhline(1, color="gray", linewidth=.7)
    ax.grid(alpha=.2)
fig.suptitle("HDR rim measurements — "+Path(args.raw).stem)
fig.savefig(args.out+".png", dpi=180)
print(json.dumps({"peak": peak, "thresholdWidths": widths}, indent=2))
