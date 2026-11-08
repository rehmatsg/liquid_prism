#!/usr/bin/env python3
"""Run real native holds while capturing the app's settled touch markers."""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--device", required=True)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    def sim(*parts):
        return subprocess.check_output(["xcrun", "simctl", *parts], text=True).strip()

    names = ["button", "prominent", "off", "on", "slider", "segment", "tab"]
    command = [
        "xcodebuild",
        "test-without-building",
        "-project",
        "tool/native_dispersion_probe/DispersionSpecs.xcodeproj",
        "-scheme",
        "DispersionSpecs",
        "-destination",
        f"platform=iOS Simulator,id={args.device}",
        "-derivedDataPath",
        str(args.build),
        "-parallel-testing-enabled",
        "NO",
        "-only-testing:DispersionSpecsTests/DefaultsGalleryTests/testStates",
        "CODE_SIGNING_ALLOWED=NO",
        "-quiet",
    ]
    with (args.out / "xctest.log").open("w") as log:
        started = time.time()
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        seen = set()
        manifest = []
        while process.poll() is None:
            root = (
                Path(
                    sim(
                        "get_app_container",
                        args.device,
                        "dev.prism.dispersionspec",
                        "data",
                    )
                )
                / "Documents/extracted"
            )
            for path in root.glob("states-*-touch*.json"):
                if path in seen or path.stat().st_mtime < started:
                    continue
                data = json.loads(path.read_text())
                state = names[int(data["state"].removeprefix("touch")) - 1]
                identifier = f"{data['run']}-{state}-held"
                sim(
                    "io",
                    args.device,
                    "screenshot",
                    str(args.out / f"{identifier}-native.png"),
                )
                shutil.copy2(path, args.out / f"{identifier}-native.json")
                seen.add(path)
                pieces = data["run"].split("-")
                manifest.append(
                    {
                        "id": identifier,
                        "pattern": pieces[1],
                        "dark": pieces[2] == "dark",
                        "tint": float(pieces[3][1:]),
                        "state": f"{state}-held",
                    }
                )
                (args.out / "manifest.json").write_text(json.dumps(manifest, indent=2))
                print(identifier, flush=True)
            time.sleep(0.1)
        if process.returncode:
            raise SystemExit(
                f"Native state tests failed: {process.returncode}; see {args.out}/xctest.log"
            )
    runner = (
        Path(
            sim(
                "get_app_container",
                args.device,
                "dev.prism.dispersionspec.tests.xctrunner",
                "data",
            )
        )
        / "Documents/defaults-gallery"
    )
    for path in runner.glob("*.png"):
        if path.stat().st_mtime >= started:
            shutil.copy2(path, args.out / path.name)
    print("Captured", len(seen), "native holds", flush=True)


if __name__ == "__main__":
    main()
