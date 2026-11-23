"""Run the HDR probe in the research app's iOS host.

python3 research/probes/hdr_probe/run.py --device <id> [--cycle] [--standard] [--mode debug]
The probe shader is declared in research/pubspec.yaml.
"""
import argparse
from pathlib import Path
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
research = Path(__file__).resolve().parents[2]
command = (["flutter", "build", "ios", "--" + args.mode] if args.build_only else
           ["flutter", "run", "--" + args.mode, "-d", args.device])
command += ["-t", "probes/hdr_probe/main.dart"]
if args.cycle:
    command.append("--dart-define=PRISM_HDR_CYCLE=true")
if args.stress:
    command.append("--dart-define=PRISM_STRESS=true")
if args.ungrouped:
    command.append("--dart-define=PRISM_UNGROUPED=true")
if args.standard:
    command.append("--dart-define=PRISM_HDR=false")
raise SystemExit(subprocess.call(command, cwd=research))
