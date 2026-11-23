"""Run the HDR probe using the example's iOS host and a temporary shader asset.

python3 tool/hdr_probe/run.py --device <id> [--cycle] [--standard] [--mode debug]
The original example pubspec is restored when flutter exits.
"""
import argparse
from pathlib import Path
import re
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--device", required=True)
parser.add_argument("--mode", choices=["debug", "profile", "release"], default="profile")
parser.add_argument("--cycle", action="store_true")
parser.add_argument("--standard", action="store_true")
parser.add_argument("--build-only", action="store_true")
parser.add_argument("--ungrouped", action="store_true", help="standalone Prism surfaces instead of a group")
parser.add_argument("--stress", action="store_true", help="cycle backdrops behind unlabelled glass")
args = parser.parse_args()
example = Path(__file__).resolve().parents[2] / "example"
pubspec = example / "pubspec.yaml"
original = pubspec.read_text()
asset = "    - ../tool/hdr_probe/probe.frag\n"
if asset.strip() in original:
    raise SystemExit("Probe asset is already declared; remove the temporary entry first.")
section = re.search(r"^flutter:\s*$", original, re.MULTILINE)
if section:
    end = re.search(r"^\S", original[section.end():], re.MULTILINE)
    stop = section.end() + end.start() if end else len(original)
    shaders = re.search(r"^  shaders:\s*$", original[section.end():stop], re.MULTILINE)
    at = section.end() + shaders.end() if shaders else section.end()
    addition = "\n" + ("" if shaders else "  shaders:\n") + asset.rstrip()
    patched = original[:at] + addition + original[at:]
else:
    patched = original.rstrip() + "\n\nflutter:\n  shaders:\n" + asset
pubspec.write_text(patched)
command = (["flutter", "build", "ios", "--" + args.mode] if args.build_only else
           ["flutter", "run", "--" + args.mode, "-d", args.device])
command += ["-t", "../tool/hdr_probe/main.dart"]
if args.cycle:
    command.append("--dart-define=PRISM_HDR_CYCLE=true")
if args.stress:
    command.append("--dart-define=PRISM_STRESS=true")
if args.ungrouped:
    command.append("--dart-define=PRISM_UNGROUPED=true")
if args.standard:
    command.append("--dart-define=PRISM_HDR=false")
try:
    result = subprocess.call(command, cwd=example)
finally:
    if pubspec.read_text() == patched:
        pubspec.write_text(original)
    else:
        print("pubspec changed concurrently; preserved it. Remove the probe shader entry manually.")
raise SystemExit(result)
