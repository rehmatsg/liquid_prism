#!/usr/bin/env python3
"""Capture native defaults; launch arguments override UIKit's setting per process."""

import argparse
import itertools
import json
from pathlib import Path
import subprocess
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--device", required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--patterns", default="grouped,cell,white,grayx,grayy")
    parser.add_argument("--amounts", default="0,0.25,0.5,0.75,1")
    parser.add_argument("--period", type=int, default=32)
    parser.add_argument("--display")
    parser.add_argument("--disabled", action="store_true")
    parser.add_argument("--selections", action="store_true")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    bundle = "dev.prism.dispersionspec"

    def sim(*command):
        return subprocess.check_output(["xcrun", "simctl", *command], text=True).strip()

    documents = (
        Path(sim("get_app_container", args.device, bundle, "data"))
        / "Documents/extracted"
    )
    variants = (
        [
            ("slider-min-selected", {"slider": 0}),
            ("slider-max-selected", {"slider": 1}),
            ("segment-second-selected", {"segment": 1}),
            ("segment-third-selected", {"segment": 2}),
            ("tab-search-selected", {"tab": 1}),
            ("tab-profile-selected", {"tab": 2}),
        ]
        if args.selections
        else [("", {})]
    )
    scenarios = []
    for dark, tint, pattern, (selection, values) in itertools.product(
        [False, True],
        map(float, args.amounts.split(",")),
        args.patterns.split(","),
        variants,
    ):
        identifier = f"{pattern}-{'dark' if dark else 'light'}-t{tint:g}"
        if args.period != 32:
            identifier += f"-p{args.period}"
        if args.disabled:
            identifier += "-disabled"
        if selection:
            identifier += f"-{selection}"
        record = {
            "id": identifier,
            "dark": dark,
            "tint": tint,
            "pattern": pattern,
            "period": args.period,
            "disabled": args.disabled,
            "state": selection or ("disabled" if args.disabled else "rest"),
            **values,
        }
        path = documents / f"{identifier}-rest.json"
        path.unlink(missing_ok=True)
        started = time.time()
        sim(
            "launch",
            "--terminate-running-process",
            args.device,
            bundle,
            "--scene",
            "defaults",
            "--pattern",
            pattern,
            "--run-name",
            identifier,
            "--period",
            str(args.period),
            *[
                part
                for key, value in values.items()
                for part in (f"--{key}", str(value))
            ],
            *(["--disabled"] if args.disabled else []),
            *([] if dark else ["--light"]),
            "-UIViewGlassTintAmount",
            str(tint),
        )
        while not path.exists():
            if time.time() - started > 20:
                raise TimeoutError(identifier)
            time.sleep(0.1)
        data = json.loads(path.read_text())
        if abs(data["tintAmount"] - tint) > 1e-6:
            raise ValueError(f"UIKit setting mismatch: {data['tintAmount']} != {tint}")
        time.sleep(0.25)
        sim(
            "io",
            args.device,
            "screenshot",
            *([f"--display={args.display}"] if args.display else []),
            str(args.out / f"{identifier}-native.png"),
        )
        (args.out / f"{identifier}-native.json").write_text(json.dumps(data, indent=2))
        scenarios.append(record)
        (args.out / "manifest.json").write_text(json.dumps(scenarios, indent=2))
        print(identifier, flush=True)


if __name__ == "__main__":
    main()
