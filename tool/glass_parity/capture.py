#!/usr/bin/env python3
"""Captures example/lib/parity_main.dart screenshots (see README.md).

  capture.py sim      --udid <sim> [--amounts 0,0.25,0.5,0.75,1] [--build]
  capture.py device   --udid <phone> [--mode sweep|settings|watch] [--build]
  capture.py xcuitest --udid <sim> --mode settings     (Settings-driven, simulator)
  capture.py live     --udid <sim-or-phone>

Every screenshot carries its own code strip, so the output folder can be fed
straight to analyze.py. Output defaults to artifacts/glass-parity/<kind>-<time>.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXAMPLE = ROOT / "example"
PROBE = ROOT / "tool" / "native_dispersion_probe"
BUNDLE = "dev.rehmatsg.liquidPrismExample"
TEAM = "9C3Z7YY9BP"


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    print("+", " ".join(cmd), flush=True)
    return subprocess.run(cmd, check=True, text=True, **kw)


def out_dir(args, kind: str) -> Path:
    out = Path(args.out).resolve() if args.out else ROOT / "artifacts" / "glass-parity" / (
        f"{kind}-{datetime.now():%Y%m%d-%H%M%S}"
    )
    (out / "shots").mkdir(parents=True, exist_ok=True)
    (out / "dumps").mkdir(parents=True, exist_ok=True)
    return out


def amounts(args) -> list[str]:
    if args.step:
        n = round(1 / args.step)
        return [f"{i * args.step:.4g}" for i in range(n + 1)]
    return args.amounts.split(",")


def build(kind: str) -> Path:
    if kind == "sim":
        run(["flutter", "build", "ios", "--simulator", "-t", "lib/parity_main.dart"], cwd=EXAMPLE)
        return EXAMPLE / "build/ios/iphonesimulator/Runner.app"
    run(["flutter", "build", "ios", "--release", "-t", "lib/parity_main.dart"], cwd=EXAMPLE)
    return EXAMPLE / "build/ios/iphoneos/Runner.app"


# --------------------------------------------------------------------------
# Simulator: simctl launch + screenshot, lock-stepped through files.


def sim_container(udid: str) -> Path:
    out = subprocess.run(
        ["xcrun", "simctl", "get_app_container", udid, BUNDLE, "data"],
        check=True, text=True, capture_output=True,
    ).stdout.strip()
    return Path(out) / "Documents" / "parity"


def wait_for(path: Path, timeout: float) -> bool:
    end = time.time() + timeout
    while time.time() < end:
        if path.exists():
            return True
        time.sleep(0.05)
    return False


def capture_sim(args) -> Path:
    out = out_dir(args, "sim")
    udid = args.udid
    if args.build or args.install:
        app = build("sim") if args.build else EXAMPLE / "build/ios/iphonesimulator/Runner.app"
        run(["xcrun", "simctl", "install", udid, str(app)])
    first = True
    for appearance in args.appearances.split(",") if args.per_appearance else [args.appearances]:
        for amount in amounts(args):
            subprocess.run(["xcrun", "simctl", "terminate", udid, BUNDLE], capture_output=True)
            # A previous launch's handshake files would be read as this one's.
            for stale in [*sim_container(udid).glob("ready-*"), *sim_container(udid).glob("ack-*")]:
                stale.unlink()
            launch = ["xcrun", "simctl", "launch", udid, BUNDLE, "--parity-ack",
                      "--parity-appearances", appearance, "--parity-patterns", args.patterns,
                      "--parity-layout", args.layout] + (["--parity-clean"] if first else [])
            first = False
            if amount != "none":
                launch += ["-UIViewGlassTintAmount", amount]
            run(launch, capture_output=True)
            time.sleep(1)
            docs = sim_container(udid)
            seq, frames = 1, None
            while frames is None or seq <= frames:
                ready = docs / f"ready-{seq}.json"
                if not wait_for(ready, 60):
                    sys.exit(f"timed out waiting for {ready}")
                time.sleep(0.05)
                record = json.loads(ready.read_text())
                frames = record["frames"]
                name = (f"arg-t{amount}-{record['appearance']}-{record['pattern']}"
                        f"-n{record['nativeAmount']}.png")
                run(["xcrun", "simctl", "io", udid, "screenshot", "--type=png",
                     str(out / "shots" / name)], capture_output=True)
                (docs / f"ack-{seq}").write_text("")
                seq += 1
            for f in docs.glob("filters-*.json"):
                shutil.copy(f, out / "dumps" / f.name)
            shutil.copy(docs / "log.jsonl", out / "dumps" / f"log-t{amount}.jsonl")
            shutil.copy(docs / "geometry.json", out / "geometry.json")
    subprocess.run(["xcrun", "simctl", "terminate", udid, BUNDLE], capture_output=True)
    return out


# --------------------------------------------------------------------------
# XCUITest (device, or the simulator for Settings-driven runs).


def export_attachments(result: Path, out: Path) -> None:
    raw = out / "xcresult-attachments"
    if raw.exists():
        shutil.rmtree(raw)
    run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
         "--output-path", str(raw)], capture_output=True)
    manifest = json.loads((raw / "manifest.json").read_text())
    notes = []
    for test in manifest:
        for item in test["attachments"]:
            src = raw / item["exportedFileName"]
            name = re.sub(r"_\d+_[0-9A-F-]{36}(\.\w+)$", r"\1", item["suggestedHumanReadableName"])
            if src.suffix == ".png":
                safe = re.sub(r"[^A-Za-z0-9._-]+", "_", name)
                shutil.copy(src, out / "shots" / safe)
            else:
                notes.append(src.read_text(errors="replace"))
    (out / "notes.txt").write_text("\n\n".join(notes))
    shutil.rmtree(raw)  # the .xcresult keeps the originals
    print(f"{len(list((out / 'shots').glob('*.png')))} screenshots in {out / 'shots'}")


def xcuitest(args, kind: str, device: bool) -> Path:
    out = out_dir(args, kind)
    udid = args.udid
    if device and (args.build or args.install):
        app = build("device") if args.build else EXAMPLE / "build/ios/iphoneos/Runner.app"
        run(["xcrun", "devicectl", "device", "install", "app", "--device", udid, str(app)])
    run(["xcodegen", "generate", "--spec", "project.yml"], cwd=PROBE, capture_output=True)
    test = {"sweep": "testSweep", "settings": "testSettings", "watch": "testWatch"}[args.mode]
    env = {
        "TEST_RUNNER_PARITY_AMOUNTS": ",".join(amounts(args)),
        "TEST_RUNNER_PARITY_APPEARANCES": args.appearances,
        "TEST_RUNNER_PARITY_PATTERNS": args.patterns,
        "TEST_RUNNER_PARITY_LAYOUT": args.layout,
        "TEST_RUNNER_PARITY_POSITIONS": str(args.positions),
        "TEST_RUNNER_PARITY_WATCH_MINUTES": str(args.minutes),
    }
    result = out / f"{test}.xcresult"
    if result.exists():
        shutil.rmtree(result)
    platform = "iOS" if device else "iOS Simulator"
    cmd = ["xcodebuild", "test", "-project", "DispersionSpecs.xcodeproj", "-scheme", "DispersionSpecs",
           "-destination", f"platform={platform},id={udid}",
           "-derivedDataPath", "build-device" if device else "build",
           "-resultBundlePath", str(result),
           f"-only-testing:DispersionSpecsTests/ParityTests/{test}"]
    if device:
        # No Xcode account here: reuse the team profiles that already exist
        # locally (dev.prism.dispersionspec and the native showcase's runner).
        cmd += ["-allowProvisioningUpdates", "CODE_SIGNING_ALLOWED=YES", "CODE_SIGN_STYLE=Automatic",
                f"DEVELOPMENT_TEAM={TEAM}", f"PARITY_TESTS_BUNDLE_ID={args.tests_bundle_id}"]
    else:
        cmd += ["CODE_SIGNING_ALLOWED=NO"]
    status = subprocess.run(cmd, cwd=PROBE, env={**os.environ, **env}, text=True)
    print(f"xcodebuild exited {status.returncode}")
    if result.exists():
        export_attachments(result, out)
    if device:
        subprocess.run(["xcrun", "devicectl", "device", "copy", "from", "--device", udid,
                        "--domain-type", "appDataContainer", "--domain-identifier", BUNDLE,
                        "--source", "Documents/parity", "--destination", str(out / "dumps")])
        if (out / "dumps" / "geometry.json").exists():
            shutil.copy(out / "dumps" / "geometry.json", out / "geometry.json")
    else:
        docs = sim_container(udid)
        for f in docs.glob("*.json*"):
            if not f.name.startswith(("ready-", "ack-")):
                shutil.copy(f, out / "dumps" / f.name)
    return out


# --------------------------------------------------------------------------


def live(args) -> None:
    sim = subprocess.run(["xcrun", "simctl", "list", "devices"], capture_output=True, text=True)
    if args.udid in sim.stdout:
        out = out_dir(args, "live")
        subprocess.run(["xcrun", "simctl", "terminate", args.udid, BUNDLE], capture_output=True)
        run(["xcrun", "simctl", "launch", args.udid, BUNDLE, "--parity-live",
             "--parity-appearances", args.appearances, "--parity-patterns", args.patterns])
        print("Move Settings > Appearance > Liquid Glass, return to the app, tap to change "
              "patterns. Enter = screenshot, q = quit.")
        i = 0
        while input().strip() != "q":
            i += 1
            run(["xcrun", "simctl", "io", args.udid, "screenshot", "--type=png",
                 str(out / "shots" / f"live-{i:03d}.png")], capture_output=True)
        print(out)
    else:
        run(["xcrun", "devicectl", "device", "process", "launch", "--device", args.udid,
             "--terminate-existing", BUNDLE, "--parity-live", "--parity-appearances",
             args.appearances, "--parity-patterns", args.patterns])
        print("Launched on the device. For automatic captures use `capture.py device "
              "--mode settings` (or --mode watch).")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("kind", choices=["sim", "device", "xcuitest", "live"])
    p.add_argument("--udid", required=True)
    p.add_argument("--out")
    p.add_argument("--amounts", default="0,0.25,0.5,0.75,1",
                   help="comma list; 'none' launches without -UIViewGlassTintAmount")
    p.add_argument("--step", type=float, help="amount step from 0 to 1 (overrides --amounts)")
    p.add_argument("--appearances", default="light,dark")
    p.add_argument("--per-appearance", action="store_true",
                   help="sim: one launch per appearance instead of cycling both")
    p.add_argument("--patterns", default="all")
    p.add_argument("--layout", default="default", choices=["default", "ladder"])
    p.add_argument("--mode", default="sweep", choices=["sweep", "settings", "watch"])
    p.add_argument("--positions", type=int, default=11, help="settings mode: slider positions")
    p.add_argument("--minutes", type=float, default=20, help="watch mode duration")
    p.add_argument("--tests-bundle-id", default="dev.prism.nativeShowcase.tests",
                   help="device: UI-test bundle id with an existing .xctrunner profile")
    p.add_argument("--build", action="store_true", help="flutter build (and install) first")
    p.add_argument("--install", action="store_true", help="install the existing build first")
    args = p.parse_args()
    if args.kind == "sim":
        print(capture_sim(args))
    elif args.kind == "device":
        print(xcuitest(args, f"device-{args.mode}", device=True))
    elif args.kind == "xcuitest":
        print(xcuitest(args, f"sim-{args.mode}", device=False))
    else:
        live(args)


if __name__ == "__main__":
    main()
