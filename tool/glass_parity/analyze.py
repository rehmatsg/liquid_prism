# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy", "pillow"]
# ///
"""Native-vs-Flutter error numbers from parity screenshots (see README.md).

  uv run tool/glass_parity/analyze.py <dir-or-png>... [--out <dir>]

Every screenshot is decoded on its own through the code strip painted by
example/lib/parity_main.dart; folders are searched recursively for *.png and
for filters-*.json dumps. Writes cases.csv, summary.csv, report.json,
report.html and crops/ to --out (default: <first input>/report).
"""

from __future__ import annotations

import argparse
import csv
import html
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
# Strip pattern index -> name, as parity_main.dart's _definitions (and each
# run's geometry.json). Patterns without a dedicated metric get the generic
# interior error only.
PATTERNS = [
    "grouped", "white", "black", "gray50", "vedge", "hedge", "lines_white", "lines_black",
    "ramp", "grating8", "grating32", "grating64", "patches", "photo",
    "out8", "out24", "out48", "out8_inv", "out24_inv", "out48_inv", "in24", "in24_inv",
    "dot", "dot_inv", "bar_h", "bar_h_inv", "bar_v", "bar_v_inv",
    "vedge_mid", "vedge_rg", "vedge_by", "vedge_rc", "gray25", "gray75", "red", "green", "blue",
    "out2", "out4", "out12", "out16", "out20", "out28", "out32", "out40",
]
FLATS = ("grouped", "white", "black", "gray50")
# Mirrors parity_main.dart's layouts by strip id: shapes in a column's local
# points (name, x, y, w, h, corner radius) and the row used to read the
# unfiltered input. Each run also writes the exact numbers to geometry.json.
_LADDER = []
_top = 90
for _h in (48, 64, 80, 104, 130, 170):
    _LADDER.append((f"h{_h}", 25, _top, 150, _h, min(28, _h / 2)))
    _top += _h + 18
LAYOUTS = {
    1: {
        "name": "default",
        "shapes": [("capsule", 25, 120, 150, 48, 24), ("rect", 25, 220, 150, 96, 28),
                   ("square", 15, 370, 170, 170, 34)],
        "ref_y": 600,
    },
    2: {"name": "ladder", "shapes": _LADDER, "ref_y": 60},
}
STRIP = (8, 40, 5)
INSET = 12  # points; the face interior excludes the rim and refraction band


# --------------------------------------------------------------------------
# Decoding


def decode(img: np.ndarray) -> dict | None:
    """Reads the 16 x 8 bit strip, trying each plausible device scale."""
    h, w = img.shape[:2]
    gray = img[..., :3].mean(-1)
    left, bottom, cell = STRIP
    for dpr in (3, 2, 1):
        c = cell * dpr
        top = h - (bottom + 8 * cell) * dpr
        if top < 0 or (left + 16 * cell) * dpr > w:
            continue
        data = []
        for row in range(8):
            for half in range(2):
                value = 0
                for bit in range(8):
                    x0 = int((left * dpr) + (half * 8 + bit) * c + c * .3)
                    y0 = int(top + row * c + c * .3)
                    patch = gray[y0:y0 + max(1, int(c * .4)), x0:x0 + max(1, int(c * .4))]
                    value = (value << 1) | int(patch.mean() > 128)
                data.append(value)
        if data[:2] != [0xA7, 0x5C] or sum(data[:14]) & 0xFF != data[14] or data[8] != dpr * 10:
            continue

        def amount(hi, lo):
            v = (hi << 8) | lo
            return None if v == 0xFFFF else v / 10000

        flags = data[6]
        return {
            "native": amount(data[2], data[3]), "flutter": amount(data[4], data[5]),
            "dark": bool(flags & 1), "live": bool(flags & 2), "settings": bool(flags & 4),
            "native_glass": bool(flags & 8), "ready": bool(flags & 16),
            "pattern": PATTERNS[data[7]] if data[7] < len(PATTERNS) else f"#{data[7]}",
            "dpr": data[8] / 10, "colPx": (data[9] << 8) | data[10], "layout": data[11],
            "epoch": data[12], "seq": data[13],
        }
    return None


# --------------------------------------------------------------------------
# Measurements


def interior_mask(w_pt, h_pt, radius, dpr, shape):
    hh, ww = shape
    ys = (np.arange(hh) + .5) / dpr
    xs = (np.arange(ww) + .5) / dpr
    x, y = np.meshgrid(xs, ys)
    half_w, half_h = w_pt / 2 - INSET, h_pt / 2 - INSET
    r = min(radius, half_w, half_h)
    qx = np.abs(x - w_pt / 2) - (half_w - r)
    qy = np.abs(y - h_pt / 2) - (half_h - r)
    outside = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r
    return outside <= 0


def luma(a):
    return a[..., 0] * .2126 + a[..., 1] * .7152 + a[..., 2] * .0722


def spread(p):
    """10-90 % width (px) of the step nearest the profile's centre."""
    lo, hi = float(p.min()), float(p.max())
    if hi - lo < 8:
        return None
    half = len(p) // 2
    q = p if p[:half].mean() < p[half:].mean() else p[::-1]
    t10, t90 = lo + .1 * (hi - lo), lo + .9 * (hi - lo)
    above = np.nonzero(q >= t90)[0]
    if not len(above) or above[0] == 0:
        return None
    i90 = int(above[0])
    below = np.nonzero(q[:i90] <= t10)[0]
    if not len(below):
        return None
    i10 = int(below[-1])

    def cross(i, t):
        d = q[i + 1] - q[i]
        return i + (t - q[i]) / d if d else float(i)

    return float(cross(i90 - 1, t90) - cross(i10, t10))


def sine_amplitude(p, period_px):
    x = np.arange(len(p))
    w = 2 * math.pi / period_px
    basis = np.stack([np.sin(w * x), np.cos(w * x), np.ones_like(x, dtype=float)], 1)
    coef, *_ = np.linalg.lstsq(basis, p, rcond=None)
    return float(math.hypot(coef[0], coef[1]))


def fwhm(p, white):
    q = p if white else -p
    base = np.median(q)
    centre = len(q) // 2
    window = q[max(0, centre - len(q) // 8):centre + len(q) // 8]
    k = int(np.argmax(window)) + max(0, centre - len(q) // 8)
    peak = q[k] - base
    if peak <= 4:
        return float(peak), None
    half = base + peak / 2
    l = k
    while l > 0 and q[l] > half:
        l -= 1
    r = k
    while r < len(q) - 1 and q[r] > half:
        r += 1
    return float(peak), float(r - l)


def measure(img, meta):
    layout = LAYOUTS[meta["layout"]]
    dpr, col = meta["dpr"], meta["colPx"]
    pattern = meta["pattern"]
    ref_y = int(layout["ref_y"] * dpr)
    band = int(2 * dpr)
    shapes = []
    for name, x, y, w, h, radius in layout["shapes"]:
        X, Y, W, H = (round(v * dpr) for v in (x, y, w, h))
        F = img[Y:Y + H, X:X + W, :3].astype(np.float64)
        N = img[Y:Y + H, X + col:X + col + W, :3].astype(np.float64)
        mask = interior_mask(w, h, radius, dpr, F.shape[:2])
        d = (F - N)[mask]
        a = np.abs(d)
        s = {
            "shape": name, "pixels": int(mask.sum()),
            "mean_abs": float(a.mean()), "max_abs": float(a.max()),
            "p99_abs": float(np.percentile(a, 99)),
            "signed": [float(v) for v in d.mean(0)],
            "native_mean": [float(v) for v in N[mask].mean(0)],
            "flutter_mean": [float(v) for v in F[mask].mean(0)],
        }
        i0, i1 = int(INSET * dpr), int((w - INSET) * dpr)
        j0, j1 = int(INSET * dpr), int((h - INSET) * dpr)
        cy, cx = H // 2, W // 2
        row = lambda A, b=band: luma(A[cy - b:cy + b, i0:i1]).mean(0)
        ref = lambda dx: luma(img[ref_y - band:ref_y + band, X + dx + i0:X + dx + i1, :3].astype(float)).mean(0)
        if pattern in ("vedge", "hedge"):
            if pattern == "vedge":
                pn, pf = row(N), row(F)
            else:
                pn = luma(N[j0:j1, cx - band:cx + band]).mean(1)
                pf = luma(F[j0:j1, cx - band:cx + band]).mean(1)
            s["spread_native_px"], s["spread_flutter_px"] = spread(pn), spread(pf)
            s["profile_native"] = [round(float(v), 1) for v in pn]
            s["profile_flutter"] = [round(float(v), 1) for v in pf]
        elif pattern.startswith("grating"):
            period = int(pattern[7:]) * dpr
            an, af = sine_amplitude(row(N), period), sine_amplitude(row(F), period)
            rn, rf = sine_amplitude(ref(col), period), sine_amplitude(ref(0), period)
            s["amp_in_native"], s["amp_in_flutter"] = rn, rf
            s["contrast_native"] = an / rn if rn else None
            s["contrast_flutter"] = af / rf if rf else None
        elif pattern == "ramp":
            b = int(4 * dpr)
            s["tone"] = {
                "in_native": ref(col).tolist(), "out_native": row(N, b).tolist(),
                "in_flutter": ref(0).tolist(), "out_flutter": row(F, b).tolist(),
            }
        elif pattern.startswith("lines"):
            white = pattern == "lines_white"
            s["line_peak_native"], s["line_fwhm_native_px"] = fwhm(row(N), white)
            s["line_peak_flutter"], s["line_fwhm_flutter_px"] = fwhm(row(F), white)
        shapes.append(s)
    return shapes


def tone_curve(shapes, side):
    xs = np.concatenate([np.array(s["tone"][f"in_{side}"]) for s in shapes])
    ys = np.concatenate([np.array(s["tone"][f"out_{side}"]) for s in shapes])
    curve = []
    for lo in range(0, 256, 16):
        sel = (xs >= lo) & (xs < lo + 16)
        curve.append(round(float(ys[sel].mean()), 2) if sel.sum() > 3 else None)
    return curve


# --------------------------------------------------------------------------
# Crops


def crop_sheet(img, meta, diff_gain=8):
    """Rows: shapes; columns: native | Flutter | diff x8 (128 = equal), at 1x."""
    layout = LAYOUTS[meta["layout"]]
    dpr, col = meta["dpr"], meta["colPx"]
    tiles = []
    for _, x, y, w, h, _ in layout["shapes"]:
        X, Y, W, H = (round(v * dpr) for v in (x, y, w, h))
        F = img[Y:Y + H, X:X + W, :3].astype(np.float64)
        N = img[Y:Y + H, X + col:X + col + W, :3].astype(np.float64)
        D = np.clip(128 + (F - N) * diff_gain, 0, 255)
        tiles.append([Image.fromarray(a.astype(np.uint8)).resize((w, h), Image.BOX) for a in (N, F, D)])
    gap = 4
    cw = max(t[0].width for t in tiles)
    height = sum(t[0].height for t in tiles) + gap * (len(tiles) - 1)
    sheet = Image.new("RGB", (3 * cw + 2 * gap, height), (90, 90, 90))
    y = 0
    for row in tiles:
        for i, t in enumerate(row):
            sheet.paste(t, (i * (cw + gap), y))
        y += row[0].height + gap
    return sheet


# --------------------------------------------------------------------------
# Filter dumps


SPEC_KEYS = [
    "inputBlurRadius", "inputBlurFillBlurRadius", "inputBlurFillLightenOpacity",
    "inputBlurFillDarkenOpacity", "inputBlurFillNormalOpacity", "inputFaceColorMatrixBlack",
    "inputFaceColorMatrixWhite", "inputFaceColorMatrixSaturation", "inputFaceColorMatrixMaxLumaSDR",
]


def filter_rows(paths):
    spec = json.loads((ROOT / "doc" / "native_defaults_spec.json").read_text())["measured"]
    rows = []
    for path in sorted(paths):
        d = json.loads(path.read_text())
        tint = d.get("tintAmount")
        style = d.get("style")
        for layer in d.get("layers", []):
            for f in layer["filters"]:
                if f.get("name") != "glassBackground":
                    continue
                inputs = f["inputs"]
                size = tuple(round(v) for v in layer["win"][2:])
                entry = next((e for e in spec.get(style, []) if tint is not None
                              and abs(e["tint"] - tint) < 1e-6), None)
                ref = None
                if entry:
                    regular = [m for m in entry["materials"] if m["bounds"][0] == 30]
                    ref = next((m for m in regular if tuple(m["bounds"][2:]) == size), regular[0] if regular else None)
                mismatches = None
                if ref:
                    # Some inputs depend on size; name the spec shape compared.
                    same = tuple(ref["bounds"][2:]) == size
                    mismatches = [k if same else f"{k} (vs spec {ref['bounds'][2]}x{ref['bounds'][3]})"
                                  for k in SPEC_KEYS if k in ref["inputs"]
                                  and abs(inputs.get(k, math.nan) - ref["inputs"][k]) > 1e-6]
                rows.append({
                    "file": str(path), "tint": tint, "style": style, "size": size,
                    "os": d.get("os"),
                    "inputs": {k: inputs.get(k) for k in SPEC_KEYS + [
                        "inputFaceColorMatrixFillColor", "inputBlurOpacity0", "inputBlurOpacity1",
                        "inputBlurDistance0"]},
                    "spec_match": None if mismatches is None else not mismatches,
                    "spec_mismatches": mismatches,
                })
    return rows


# --------------------------------------------------------------------------


def largest(case):
    return max(case["shapes"], key=lambda s: s["pixels"])


def fmt(v, digits=1):
    if v is None:
        return "–"
    if isinstance(v, float):
        return f"{v:.{digits}f}"
    return str(v)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inputs", nargs="+")
    ap.add_argument("--out")
    ap.add_argument("--no-crops", action="store_true")
    args = ap.parse_args()
    inputs = [Path(p).resolve() for p in args.inputs]
    out = Path(args.out).resolve() if args.out else (inputs[0] if inputs[0].is_dir() else inputs[0].parent) / "report"
    (out / "crops").mkdir(parents=True, exist_ok=True)
    pngs, dumps = [], []
    for p in inputs:
        if p.is_dir():
            pngs += [q for q in sorted(p.rglob("*.png")) if out not in q.parents
                     and "xcresult" not in str(q) and "crops" not in q.parts]
            dumps += [q for q in sorted(p.rglob("filters-*.json")) if "xcresult" not in str(q)]
        elif p.suffix == ".png":
            pngs.append(p)
    cases, undecoded = [], []
    for i, path in enumerate(pngs):
        img = np.asarray(Image.open(path).convert("RGB"))
        meta = decode(img)
        if meta is None or meta["layout"] not in LAYOUTS:
            undecoded.append(str(path))
            continue
        source = next((q.name for q in path.parents if q.name != "shots"), "")
        shapes = measure(img, meta)
        weight = sum(s["pixels"] for s in shapes)
        case = {
            "id": f"c{i:04d}", "file": str(path), "source": source,
            "mode": "slider" if (meta["settings"] or meta["live"]) else "arg", **meta,
            "appearance": "dark" if meta["dark"] else "light",
            "mean_abs": sum(s["mean_abs"] * s["pixels"] for s in shapes) / weight,
            "max_abs": max(s["max_abs"] for s in shapes),
            "p99_abs": max(s["p99_abs"] for s in shapes),
            "signed": [sum(s["signed"][c] * s["pixels"] for s in shapes) / weight for c in range(3)],
            "shapes": shapes,
        }
        if meta["pattern"] == "ramp":
            case["tone_native"] = tone_curve(shapes, "native")
            case["tone_flutter"] = tone_curve(shapes, "flutter")
            pairs = [(a, b) for a, b in zip(case["tone_native"], case["tone_flutter"]) if a is not None and b is not None]
            case["tone_mean_abs"] = sum(abs(a - b) for a, b in pairs) / len(pairs) if pairs else None
        if not args.no_crops:
            crop_sheet(img, meta).save(out / "crops" / f"{case['id']}.png", optimize=True)
        cases.append(case)
        print(f"{path.name}: {case['appearance']} n={meta['native']} f={meta['flutter']} "
              f"{meta['pattern']} mean {case['mean_abs']:.2f} max {case['max_abs']:.0f}")

    def amount_key(c):
        return round(c["native"], 3) if c["native"] is not None else -1

    # Summary: source x layout x mode x appearance x amount.
    groups = {}
    for c in cases:
        groups.setdefault((c["source"], c["layout"], c["mode"], c["appearance"], amount_key(c)), {})[c["pattern"]] = c
    summary = []
    for (source, layout, mode, appearance, amount), by in sorted(groups.items()):
        def sq(pattern, key):
            # Metric on the largest shape (the default layout's square).
            c = by.get(pattern)
            return largest(c).get(key) if c else None

        flats = [by[p] for p in FLATS if p in by]
        row = {
            "source": source, "layout": LAYOUTS[layout]["name"], "mode": mode,
            "appearance": appearance, "amount": amount,
            "flutter_amount": next(iter(by.values()))["flutter"],
            "flat_mean": sum(c["mean_abs"] for c in flats) / len(flats) if flats else None,
            "flat_max": max((c["max_abs"] for c in flats), default=None),
        }
        for p in ("ramp", "grating32", "photo", "patches", "vedge", "hedge"):
            row[f"{p}_mean"] = by[p]["mean_abs"] if p in by else None
            row[f"{p}_max"] = by[p]["max_abs"] if p in by else None
        row["tone_mean_abs"] = by["ramp"].get("tone_mean_abs") if "ramp" in by else None
        for p in ("vedge", "hedge"):
            row[f"{p}_spread_native"] = sq(p, "spread_native_px")
            row[f"{p}_spread_flutter"] = sq(p, "spread_flutter_px")
        for p in ("grating8", "grating32", "grating64"):
            row[f"{p}_contrast_native"] = sq(p, "contrast_native")
            row[f"{p}_contrast_flutter"] = sq(p, "contrast_flutter")
        summary.append(row)

    # Launch argument vs real slider, matching amount/appearance/pattern.
    by_key = {}
    for c in cases:
        by_key.setdefault((c["layout"], c["appearance"], c["pattern"], amount_key(c)), {}).setdefault(
            c["mode"], []).append(c)
    versus = []
    for (_, appearance, pattern, amount), modes in sorted(by_key.items()):
        if "arg" not in modes or "slider" not in modes:
            continue
        a, b = modes["arg"][0], modes["slider"][0]
        ia = np.asarray(Image.open(a["file"]).convert("RGB")).astype(np.int16)
        ib = np.asarray(Image.open(b["file"]).convert("RGB")).astype(np.int16)
        rec = {"appearance": appearance, "pattern": pattern, "amount": amount,
               "arg_file": a["file"], "slider_file": b["file"]}
        for side, dx in (("native", a["colPx"]), ("flutter", 0)):
            diffs = []
            for _, x, y, w, h, _ in LAYOUTS[a["layout"]]["shapes"]:
                X, Y, W, H = (round(v * a["dpr"]) for v in (x, y, w, h))
                diffs.append(np.abs(ia[Y:Y + H, X + dx:X + dx + W] - ib[Y:Y + H, X + dx:X + dx + W]).ravel())
            d = np.concatenate(diffs)
            rec[f"{side}_mean_abs"] = float(d.mean())
            rec[f"{side}_max_abs"] = int(d.max())
            rec[f"{side}_identical_fraction"] = float((d == 0).mean())
        versus.append(rec)

    filters = filter_rows(dumps)

    fields = ["source", "mode", "appearance", "native", "flutter", "pattern", "shape", "mean_abs", "max_abs",
              "p99_abs", "signed_r", "signed_g", "signed_b", "native_r", "native_g", "native_b", "flutter_r",
              "flutter_g", "flutter_b", "spread_native_px", "spread_flutter_px", "contrast_native",
              "contrast_flutter", "line_peak_native", "line_peak_flutter", "ready", "seq", "file"]
    with open(out / "cases.csv", "w", newline="") as fh:
        wr = csv.DictWriter(fh, fields)
        wr.writeheader()
        for c in cases:
            for s in c["shapes"]:
                wr.writerow({
                    "source": c["source"], "mode": c["mode"], "appearance": c["appearance"],
                    "native": c["native"], "flutter": c["flutter"], "pattern": c["pattern"],
                    "shape": s["shape"], "mean_abs": round(s["mean_abs"], 3), "max_abs": s["max_abs"],
                    "p99_abs": round(s["p99_abs"], 2),
                    **{f"signed_{k}": round(s["signed"][i], 3) for i, k in enumerate("rgb")},
                    **{f"native_{k}": round(s["native_mean"][i], 2) for i, k in enumerate("rgb")},
                    **{f"flutter_{k}": round(s["flutter_mean"][i], 2) for i, k in enumerate("rgb")},
                    **{k: s.get(k) for k in ("spread_native_px", "spread_flutter_px", "contrast_native",
                                             "contrast_flutter", "line_peak_native", "line_peak_flutter")},
                    "ready": c["ready"], "seq": c["seq"], "file": c["file"],
                })
    with open(out / "summary.csv", "w", newline="") as fh:
        if summary:
            wr = csv.DictWriter(fh, list(summary[0]))
            wr.writeheader()
            wr.writerows(summary)
    report = {"inputs": [str(p) for p in inputs], "undecoded": undecoded, "summary": summary,
              "arg_vs_slider": versus, "filters": filters, "cases": cases}
    (out / "report.json").write_text(json.dumps(report, indent=1))
    write_html(out, report)
    print(f"{len(cases)} cases, {len(undecoded)} undecoded -> {out / 'report.html'}")


def write_html(out, report):
    cases, summary = report["cases"], report["summary"]
    e = html.escape
    parts = ["""<!doctype html><html><head><meta charset="utf-8"><title>Glass parity</title>
<style>
:root{--bg:#fff;--fg:#111;--muted:#666;--line:#ddd;--bad:#c62828;--warn:#b26a00}
@media (prefers-color-scheme: dark){:root{--bg:#111;--fg:#eee;--muted:#999;--line:#333;--bad:#ef9a9a;--warn:#ffcc80}}
body{background:var(--bg);color:var(--fg);font:13px -apple-system,system-ui,sans-serif;margin:16px}
table{border-collapse:collapse;margin:8px 0 24px}td,th{border-bottom:1px solid var(--line);padding:3px 7px;text-align:right;white-space:nowrap}
th{position:sticky;top:0;background:var(--bg)}td.l,th.l{text-align:left}.bad{color:var(--bad);font-weight:600}.warn{color:var(--warn)}
img{image-rendering:pixelated;max-width:100%}small{color:var(--muted)}
</style></head><body><h1>Glass parity</h1>"""]
    parts.append(f"<p><small>{len(cases)} cases from {', '.join(e(p) for p in report['inputs'])}. "
                 f"Errors are 8-bit RGB, Flutter minus native, over each face interior (inset {INSET} pt). "
                 f"Undecoded screenshots: {len(report['undecoded'])}.</small></p>")
    if any(not c["ready"] for c in cases):
        parts.append(f"<p class=warn>{sum(not c['ready'] for c in cases)} screenshots were taken before "
                     "their frame was ready.</p>")

    def cls(v, warn, bad):
        return "bad" if v is not None and v >= bad else ("warn" if v is not None and v >= warn else "")

    parts.append("<h2>Summary</h2><p><small>flat = mean over grouped/white/black/gray50 (max of max). "
                 "Spread = 10–90 % width of the step on the square, px. Contrast = output/input sine "
                 "amplitude on the square. tone = mean |Δ| between tone curves.</small></p><table><tr>"
                 + "".join(f"<th>{h}</th>" for h in [
                     "source", "mode", "appear.", "amount", "flutter amt", "flat mean/max", "ramp", "tone",
                     "grating32", "photo", "patches", "vedge spread N/F", "hedge spread N/F",
                     "g8 contrast N/F", "g32 contrast N/F", "g64 contrast N/F"]) + "</tr>")
    for r in summary:
        def mm(p):
            m, x = r.get(f"{p}_mean"), r.get(f"{p}_max")
            return f"<td class={cls(m, 2, 5)}>{fmt(m, 2)} / {fmt(x, 0)}</td>"

        def nf(a, b, d=1):
            return f"<td>{fmt(r.get(a), d)} / {fmt(r.get(b), d)}</td>"
        parts.append(
            f"<tr><td class=l>{e(r['source'])} {r['layout']}</td><td class=l>{r['mode']}</td><td class=l>{r['appearance']}</td>"
            f"<td>{fmt(r['amount'], 3)}</td><td>{fmt(r['flutter_amount'], 3)}</td>"
            f"<td class={cls(r['flat_mean'], 2, 5)}>{fmt(r['flat_mean'], 2)} / {fmt(r['flat_max'], 0)}</td>"
            + mm("ramp") + f"<td>{fmt(r['tone_mean_abs'], 2)}</td>" + mm("grating32") + mm("photo") + mm("patches")
            + nf("vedge_spread_native", "vedge_spread_flutter") + nf("hedge_spread_native", "hedge_spread_flutter")
            + nf("grating8_contrast_native", "grating8_contrast_flutter", 3)
            + nf("grating32_contrast_native", "grating32_contrast_flutter", 3)
            + nf("grating64_contrast_native", "grating64_contrast_flutter", 3) + "</tr>")
    parts.append("</table>")

    if report["arg_vs_slider"]:
        parts.append("<h2>Launch argument vs Settings slider</h2><p><small>Same amount, appearance and "
                     "pattern; |Δ| over the shape boxes.</small></p><table><tr><th>appear.</th>"
                     "<th>amount</th><th class=l>pattern</th><th>native mean/max</th><th>native identical</th>"
                     "<th>Flutter mean/max</th><th>Flutter identical</th></tr>")
        for v in report["arg_vs_slider"]:
            parts.append(f"<tr><td>{v['appearance']}</td><td>{fmt(v['amount'], 3)}</td><td class=l>{v['pattern']}</td>"
                         f"<td>{fmt(v['native_mean_abs'], 3)} / {v['native_max_abs']}</td>"
                         f"<td>{v['native_identical_fraction']:.1%}</td>"
                         f"<td>{fmt(v['flutter_mean_abs'], 3)} / {v['flutter_max_abs']}</td>"
                         f"<td>{v['flutter_identical_fraction']:.1%}</td></tr>")
        parts.append("</table>")

    if report["filters"]:
        keys = SPEC_KEYS + ["inputFaceColorMatrixFillColor"]
        short = [k.replace("inputBlurFill", "fill").replace("inputFaceColorMatrix", "face").replace("input", "")
                 for k in keys]
        parts.append("<h2>Native glassBackground inputs</h2><p><small>One row per dump and shape size; "
                     "spec = doc/native_defaults_spec.json measured (only at 0, .25, .5, .75, 1).</small></p><table><tr>"
                     "<th>style</th><th>tint</th><th>size</th>" + "".join(f"<th>{e(s)}</th>" for s in short)
                     + "<th>spec</th><th class=l>file</th></tr>")
        seen = set()
        for f in report["filters"]:
            key = (f["style"], f["tint"], tuple(f["size"]), json.dumps(f["inputs"], sort_keys=True))
            if key in seen:
                continue
            seen.add(key)
            vals = "".join(f"<td>{fmt(v, 4) if not isinstance(v, list) else ', '.join(fmt(x, 3) for x in v)}</td>"
                           for v in (f["inputs"].get(k) for k in keys))
            if f["spec_match"] is None:
                match = "–"
            elif f["spec_match"]:
                match = "match"
            else:
                match = "<span class=bad>" + e(", ".join(f["spec_mismatches"])) + "</span>"
            parts.append(f"<tr><td>{f['style']}</td><td>{fmt(f['tint'], 4)}</td><td>{f['size'][0]}×{f['size'][1]}</td>"
                         f"{vals}<td>{match}</td><td class=l><small>{e(Path(f['file']).name)}</small></td></tr>")
        parts.append("</table>")

    parts.append("<h2>Cases, worst first</h2><p><small>Crops: native | Flutter | (Flutter − native) × 8 "
                 "around mid-gray, at 1×.</small></p><table><tr><th class=l>case</th><th>mean</th><th>max</th>"
                 "<th>p99</th><th>signed R/G/B</th><th>native RGB</th><th>Flutter RGB</th><th class=l>crops</th></tr>")
    for c in sorted(cases, key=lambda c: -c["mean_abs"]):
        sq = largest(c)
        extra = ""
        if "spread_native_px" in sq:
            extra = f"<br>spread N {fmt(sq['spread_native_px'])} / F {fmt(sq['spread_flutter_px'])} px"
        if "contrast_native" in sq:
            extra = f"<br>contrast N {fmt(sq['contrast_native'], 3)} / F {fmt(sq['contrast_flutter'], 3)}"
        if c.get("tone_native"):
            extra = (f"<br>tone N {', '.join(fmt(v, 0) for v in c['tone_native'])}"
                     f"<br>tone F {', '.join(fmt(v, 0) for v in c['tone_flutter'])}")
        crop = Path("crops") / f"{c['id']}.png"
        img = f"<img loading=lazy src='{crop}'>" if (out / crop).exists() else ""
        parts.append(
            f"<tr><td class=l><b>{c['appearance']} {fmt(c['native'], 3)} {c['pattern']}</b><br>"
            f"<small>{e(c['source'])} · {c['mode']} · flutter {fmt(c['flutter'], 3)} · seq {c['seq']}"
            f"{'' if c['ready'] else ' · NOT READY'}</small>{extra}</td>"
            f"<td class={cls(c['mean_abs'], 2, 5)}>{c['mean_abs']:.2f}</td><td>{c['max_abs']:.0f}</td>"
            f"<td>{c['p99_abs']:.0f}</td><td>{' / '.join(f'{v:+.2f}' for v in c['signed'])}</td>"
            f"<td>{' '.join(f'{v:.0f}' for v in sq['native_mean'])}</td>"
            f"<td>{' '.join(f'{v:.0f}' for v in sq['flutter_mean'])}</td><td class=l>{img}</td></tr>")
    parts.append("</table></body></html>")
    (out / "report.html").write_text("\n".join(parts))


if __name__ == "__main__":
    main()
