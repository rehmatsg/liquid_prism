#!/usr/bin/env python3
"""GPU cost of glass, measured on this Mac (see README.md).

  research/probes/gpu_bench/run.py                  build and measure the working tree
  research/probes/gpu_bench/run.py --compare main   also measure a git ref, side by side
  research/probes/gpu_bench/run.py --scenes free7,chrome --frames 600 --no-build

Runs research/benchmarks/gpu_bench_main.dart as a macOS profile build of the
research app. Each scenario is rendered offscreen in a tight loop, so the GPU
is saturated and the time per frame is its cost: no vsync, no thermal state,
no device needed.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BENCH = "benchmarks/gpu_bench_main.dart"
APP = "build/macos/Build/Products/Profile/liquid_prism_research.app/Contents/MacOS/liquid_prism_research"


def measure(research: Path, args, build: bool) -> dict[str, float]:
    if not (research / "macos").exists():
        sys.exit(f"{research}/macos is missing: copy research/macos from a current checkout")
    if build:
        # Edits to included .glsl files do not invalidate the shader build.
        shutil.rmtree(research / ".dart_tool" / "flutter_build", ignore_errors=True)
        subprocess.run(["flutter", "build", "macos", "--profile", "-t", BENCH],
                       cwd=research, check=True, capture_output=True)
    env = {**os.environ, "GPU_BENCH_FRAMES": str(args.frames)}
    if args.scenes:
        env["GPU_BENCH_SCENES"] = args.scenes
    out = subprocess.run([str(research / APP)], env=env, capture_output=True, text=True).stdout
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
    runs = {"working tree": measure(ROOT / "research", args, build=not args.no_build)}
    if args.compare:
        # Flutter resolves the package by its folder name.
        with tempfile.TemporaryDirectory() as tmp:
            tree = Path(tmp) / "liquid_prism"
            subprocess.run(["git", "worktree", "add", "--detach", str(tree), args.compare],
                           cwd=ROOT, check=True, capture_output=True)
            try:
                # The ref's package must already have the 1.0 Prism API; refs
                # older than the research app get its pubspec and runner.
                source, target = ROOT / "research", tree / "research"
                shutil.copy(source / BENCH, target / BENCH)
                if not (target / "pubspec.yaml").exists():
                    shutil.copy(source / "pubspec.yaml", target / "pubspec.yaml")
                if not (target / "macos").exists():
                    shutil.copytree(source / "macos", target / "macos")
                runs[args.compare] = measure(target, args, build=True)
            finally:
                subprocess.run(["git", "worktree", "remove", "--force", str(tree)], cwd=ROOT)
    names = list(runs)
    print(f"{'ms per frame':<14}" + "".join(f"{n:>16}" for n in names))
    for scene in runs[names[0]]:
        print(f"{scene:<14}" + "".join(f"{runs[n].get(scene, float('nan')):>16.2f}" for n in names))
    print("\nSubtract the matching `none` row for the cost of the glass alone.")


if __name__ == "__main__":
    main()
