#!/usr/bin/env python3
"""Build a portable side-by-side gallery from the comparison manifests."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
from PIL import Image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--native", type=Path, required=True)
    parser.add_argument("--flutter", type=Path, required=True)
    parser.add_argument("--states-native", type=Path)
    parser.add_argument("--states-flutter", type=Path)
    parser.add_argument("--before", type=Path)
    parser.add_argument("--disabled-native", type=Path)
    parser.add_argument("--disabled-flutter", type=Path)
    parser.add_argument("--selections-native", type=Path)
    parser.add_argument("--selections-flutter", type=Path)
    parser.add_argument("--showcase", type=Path)
    parser.add_argument("--showcase-before", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    assets = args.out / "captures"
    assets.mkdir(exist_ok=True)

    def asset(source, name=None):
        destination = assets / ((name or source.stem) + ".webp")
        if (
            not destination.exists()
            or destination.stat().st_mtime < source.stat().st_mtime
        ):
            with Image.open(source) as image:
                image.convert("RGB").save(destination, "WEBP", lossless=True, method=1)
        return f"captures/{destination.name}"

    def pair(job):
        case, native, flutter, previous_root = job
        identifier = case["id"]
        left = native / f"{identifier}-native.png"
        right = flutter / f"{identifier}-flutter.png"
        with Image.open(left) as l, Image.open(right) as r:
            if l.size != r.size:
                raise ValueError(f"Mismatched image sizes: {identifier}")
        record = {**case, "native": asset(left), "flutter": asset(right)}
        if previous_root:
            previous = previous_root / f"{identifier}-flutter.png"
            if previous.exists():
                record["before"] = asset(previous, f"{identifier}-before")
        return record

    sources = [(args.native, args.flutter)]
    if args.disabled_native and args.disabled_flutter:
        sources.append((args.disabled_native, args.disabled_flutter))
    if args.states_native and args.states_flutter:
        sources.append((args.states_native, args.states_flutter))
    if args.selections_native and args.selections_flutter:
        sources.append((args.selections_native, args.selections_flutter))
    if args.showcase:
        sources.append((args.showcase, args.showcase))
    jobs = []
    for native, flutter in sources:
        manifest = json.loads((native / "manifest.json").read_text())
        if native == args.states_native:
            manifest += [
                {
                    **case,
                    "id": case["id"].replace("-held", "-released"),
                    "state": case["state"].replace("-held", "-released"),
                }
                for case in manifest
            ]
        if native == args.showcase:
            manifest = [
                {
                    **case,
                    "suite": "showcase",
                    "tint": 0.5,
                    "pattern": "grouped",
                    "state": "rest",
                }
                for case in manifest
            ]
        previous = args.showcase_before if native == args.showcase else args.before
        jobs.extend((case, native, flutter, previous) for case in manifest)
    with ThreadPoolExecutor(max_workers=4) as pool:
        cases = list(pool.map(pair, jobs))
    (args.out / "cases.json").write_text(json.dumps(cases, indent=2))
    template = Path(__file__).with_name("gallery.html").read_text()
    (args.out / "index.html").write_text(
        template.replace("__CASES__", json.dumps(cases))
    )
    print(f"Built {len(cases)} comparison pairs in {args.out}")


if __name__ == "__main__":
    main()
