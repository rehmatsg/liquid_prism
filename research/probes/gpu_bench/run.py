#!/usr/bin/env python3
"""GPU cost of glass, measured on this Mac (see README.md).

  tool/gpu_bench/run.py                      build and measure the working tree
  tool/gpu_bench/run.py --compare main       also measure a git ref, side by side
  tool/gpu_bench/run.py --scenes free7,chrome --frames 600 --no-build

Runs example/lib/gpu_bench_main.dart as a macOS profile build. Each scenario
is rendered offscreen in a tight loop, so the GPU is saturated and the time
per frame is its cost: no vsync, no thermal state, no device needed.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BENCH = "lib/gpu_bench_main.dart"
APP = "build/macos/Build/Products/Profile/liquid_prism_example.app/Contents/MacOS/liquid_prism_example"


def measure(example: Path, args, build: bool) -> dict[str, float]:
    if not (example / "macos").exists():
        sys.exit(f"{example}/macos is missing: run `flutter create --platforms=macos .` "
                 "in example/ and set FLTEnableImpeller in macos/Runner/Info.plist")
    if build:
        # Edits to included .glsl files do not invalidate the shader build.
        shutil.rmtree(example / ".dart_tool" / "flutter_build", ignore_errors=True)
        subprocess.run(["flutter", "build", "macos", "--profile", "-t", BENCH],
                       cwd=example, check=True, capture_output=True)
    env = {**os.environ, "GPU_BENCH_FRAMES": str(args.frames)}
    if args.scenes:
        env["GPU_BENCH_SCENES"] = args.scenes
    out = subprocess.run([str(example / APP)], env=env, capture_output=True, text=True).stdout
    result = {}
    for line in out.splitlines():
        if line.startswith("GPU_BENCH "):
            _, name, *fields = line.split()
            result[name] = float(dict(f.split("=") for f in fields)["frame_ms"])
    if not result:
        sys.exit("the benchmark printed no results:\n" + out[-2000:])
    return result


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--scenes", help="comma list; default all")
    p.add_argument("--frames", type=int, default=300)
    p.add_argument("--no-build", action="store_true")
    p.add_argument("--compare", metavar="REF", help="git ref to measure beside the working tree")
    args = p.parse_args()
    runs = {"working tree": measure(ROOT / "example", args, build=not args.no_build)}
    if args.compare:
        # Flutter resolves the package by its folder name.
        with tempfile.TemporaryDirectory() as tmp:
            tree = Path(tmp) / "liquid_prism"
            subprocess.run(["git", "worktree", "add", "--detach", str(tree), args.compare],
                           cwd=ROOT, check=True, capture_output=True)
            try:
                shutil.copy(ROOT / "example" / BENCH, tree / "example" / BENCH)
                if not (tree / "example" / "macos").exists():
                    shutil.copytree(ROOT / "example" / "macos", tree / "example" / "macos")
                runs[args.compare] = measure(tree / "example", args, build=True)
            finally:
                subprocess.run(["git", "worktree", "remove", "--force", str(tree)], cwd=ROOT)
    names = list(runs)
    print(f"{'ms per frame':<14}" + "".join(f"{n:>16}" for n in names))
    for scene in runs[names[0]]:
        print(f"{scene:<14}" + "".join(f"{runs[n].get(scene, float('nan')):>16.2f}" for n in names))
    print("\nSubtract the matching `none` row for the cost of the glass alone.")


if __name__ == "__main__":
    main()
