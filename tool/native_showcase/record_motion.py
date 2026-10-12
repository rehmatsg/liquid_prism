#!/usr/bin/env python3
"""Record genuine native gestures and copy presentation-layer measurements."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("simulator")
    parser.add_argument("output", type=Path)
    parser.add_argument(
        "--dark-tabs", action="store_true", help="Record only a dark-mode tab hold and drag"
    )
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    env = {**os.environ, "DEVELOPER_DIR": "/Applications/Xcode.app/Contents/Developer"}
    root = Path(__file__).resolve().parent
    tests = (
        ["-only-testing:NativeShowcaseTests/LensMotionTests/testTabsDark"]
        if args.dark_tabs else [
            "-only-testing:NativeShowcaseTests/LensMotionTests",
            "-skip-testing:NativeShowcaseTests/LensMotionTests/testTabsDark",
        ]
    )
    recording = subprocess.Popen([
        "xcrun", "simctl", "io", args.simulator, "recordVideo", "--codec=h264",
        str(args.output / "native-raw.mp4"),
    ], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    # simctl acknowledges when capture starts; use that wall clock to place the
    # test's epoch timestamps into the video. A frame or two of launch skew is
    # possible; presentation measurements retain their own display-link clock.
    while recording.poll() is None:
        line = recording.stderr.readline()
        if "Recording started" in line:
            break
    epoch = time.time()
    log = args.output / "native-motion-tests.log"
    try:
        with log.open("w") as stream:
            result = subprocess.run([
                "xcodebuild", "test-without-building", "-project", "NativeShowcase.xcodeproj",
                "-scheme", "NativeShowcase", "-destination", f"platform=iOS Simulator,id={args.simulator}",
                "-derivedDataPath", "build", "-parallel-testing-enabled", "NO",
                *tests,
                "-resultBundlePath", str(args.output / "native-motion.xcresult"), "CODE_SIGNING_ALLOWED=NO",
            ], cwd=root, env=env, stdout=stream, stderr=subprocess.STDOUT)
    finally:
        recording.send_signal(2)
        recording.wait(timeout=20)
    if result.returncode:
        raise SystemExit(f"Native motion tests failed: {log}")
    container = subprocess.check_output([
        "xcrun", "simctl", "get_app_container", args.simulator, "com.rehmat.glassshowcase.native", "data",
    ], env=env, text=True).strip()
    text = log.read_text()
    manifest = []
    for name, start, ax, ay, bx, by in re.findall(r"LENS_BEGIN (\w+) ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+)", text):
        end = re.search(rf"LENS_END {name} ([\d.]+)", text)
        if not end:
            raise SystemExit(f"Missing release for {name}")
        motion = Path(container) / "Documents" / f"motion-{name}.json"
        capture = json.loads(motion.read_text())
        if not any(frame["lenses"] for frame in capture["frames"]):
            raise SystemExit(f"No native lens measurements for {name}")
        shutil.copyfile(motion, args.output / f"{name}-native-motion.json")
        manifest.append({"name": name, "start": float(start) - epoch, "end": float(end[1]) - epoch,
                         "centerY": float(ay), "fromX": float(ax), "toX": float(bx)})
    if len(manifest) != (1 if args.dark_tabs else 4):
        raise SystemExit("Missing native gesture captures")
    (args.output / "native-manifest.json").write_text(json.dumps(manifest, indent=2))
    print("Captured native holds, slow drags and fast reversals.")


if __name__ == "__main__":
    main()
