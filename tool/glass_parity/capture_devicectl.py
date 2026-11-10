# /// script
# requires-python = ">=3.10"
# dependencies = ["numpy", "pillow"]
# ///
"""Device capture without XCTest: devicectl launch + devicectl screenshots.

  uv run tool/glass_parity/capture_devicectl.py --udid <phone> --out <dir> \
      [--amounts 0,0.5,1] [--patterns vedge,black] [--appearances light,dark] \
      [--layout default|ladder] [--dwell 2.5] [--install <Runner.app>]

The app advances by itself (--parity-dwell); every screenshot is decoded
through its code strip and kept once per (amount, appearance, pattern) when
its ready flag is set. Use this when UI automation cannot be enabled.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from analyze import decode  # noqa: E402

BUNDLE = "dev.rehmatsg.liquidPrismExample"


def shot(udid: str, path: Path) -> dict | None:
    done = subprocess.run(
        ["xcrun", "devicectl", "device", "capture", "screenshot", "--device", udid,
         "--destination", str(path), "--quiet"], capture_output=True, text=True)
    if done.returncode != 0 or not path.exists():
        return None
    return decode(np.asarray(Image.open(path).convert("RGB")))


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--udid", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--amounts", default="0,0.25,0.5,0.75,1")
    p.add_argument("--patterns", default="all")
    p.add_argument("--appearances", default="light,dark")
    p.add_argument("--layout", default="default")
    p.add_argument("--dwell", type=float, default=2.5)
    p.add_argument("--install")
    args = p.parse_args()
    shots = Path(args.out) / "shots"
    shots.mkdir(parents=True, exist_ok=True)
    tmp = Path(args.out) / "tmp.png"
    if args.install:
        subprocess.run(["xcrun", "devicectl", "device", "install", "app", "--device",
                        args.udid, args.install], check=True, capture_output=True)
    missing = []
    for amount in args.amounts.split(","):
        launch = ["xcrun", "devicectl", "device", "process", "launch", "--device", args.udid,
                  "--terminate-existing", "--", BUNDLE, "-UIViewGlassTintAmount", amount,
                  "--parity-appearances", args.appearances, "--parity-patterns", args.patterns,
                  "--parity-layout", args.layout, "--parity-dwell", str(args.dwell)]
        subprocess.run(launch, check=True, capture_output=True)
        seen: set[tuple] = set()
        idle = time.time()
        first = None
        while time.time() - idle < max(12.0, args.dwell * 4):
            meta = shot(args.udid, tmp)
            if not meta or not meta["ready"] or meta["native"] is None:
                continue
            if abs(meta["native"] - float(amount)) > 1e-3:
                continue
            key = ("dark" if meta["dark"] else "light", meta["pattern"])
            if first is None:
                first = key
            elif key == first and len(seen) > 1 and key in seen:
                break  # wrapped around
            if key not in seen:
                seen.add(key)
                idle = time.time()
                tmp.replace(shots / f"dc_a{meta['native']:.4f}_{key[0]}_{key[1]}.png")
        print(f"amount {amount}: {len(seen)} frames", flush=True)
        if not seen:
            missing.append(amount)
    tmp.unlink(missing_ok=True)
    if missing:
        sys.exit(f"no frames for amounts {missing}")


if __name__ == "__main__":
    main()
