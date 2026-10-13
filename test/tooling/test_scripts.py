"""Exercise developer entry points without launching Flutter or native builds."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2]
FAKE_TOOL = r'''
import json
import os
from pathlib import Path
import sys

log = Path(os.environ["LIQUID_TEST_TRACE"])
calls = log.read_text().splitlines() if log.exists() else []
with log.open("a") as stream:
    stream.write(json.dumps({
        "tool": Path(sys.argv[0]).name,
        "args": sys.argv[1:],
        "cwd": str(Path.cwd()),
    }) + "\n")
if len(calls) + 1 == int(os.environ.get("LIQUID_TEST_FAIL_AT", "0")):
    sys.exit(37)
'''


class DeveloperScriptsTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="liquid-prism-scripts-")
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name).resolve()
        self.checkout = self.base / "checkout with spaces"
        self.example = self.checkout / "example"
        self.example.mkdir(parents=True)
        scripts = self.checkout / "tool"
        scripts.mkdir()
        for name in ["check.sh", "run_example.sh"]:
            shutil.copy2(SOURCE / "tool" / name, scripts / name)
        self.bin = self.base / "fake bin"
        self.bin.mkdir()
        for name in ["flutter", "dart", "python3"]:
            executable = self.bin / name
            executable.write_text(f"#!{sys.executable}\n" + FAKE_TOOL)
            executable.chmod(0o755)
        self.invocations = 0

    def run_script(self, name, arguments=(), fail_at=0):
        self.invocations += 1
        log = self.base / f"trace-{self.invocations}.jsonl"
        environment = dict(os.environ)
        environment.update({
            "PATH": str(self.bin) + os.pathsep + environment["PATH"],
            "LIQUID_TEST_TRACE": str(log),
            "LIQUID_TEST_FAIL_AT": str(fail_at),
        })
        result = subprocess.run(
            ["bash", str(self.checkout / "tool" / name), *arguments],
            cwd=self.base,
            env=environment,
            capture_output=True,
            text=True,
            timeout=10,
        )
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        return result, calls

    def test_example_launch_uses_consumer_cwd_preserves_device_and_exit(self):
        for device in [None, "iPhone 17 device id"]:
            for failure in [False, True]:
                with self.subTest(device=device, failure=failure):
                    result, calls = self.run_script(
                        "run_example.sh",
                        [] if device is None else [device],
                        fail_at=1 if failure else 0,
                    )
                    self.assertEqual(result.returncode, 37 if failure else 0,
                                     result.stderr)
                    arguments = ["run", "--debug", "--target", "lib/main.dart"]
                    if device is not None:
                        arguments += ["-d", device]
                    self.assertEqual(calls, [{
                        "tool": "flutter",
                        "args": arguments,
                        "cwd": str(self.example),
                    }])

    def test_check_resolves_dependencies_checks_both_projects_and_stops_on_failure(self):
        result, success = self.run_script("check.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(success[0], {
            "tool": "flutter", "args": ["pub", "get"],
            "cwd": str(self.checkout),
        })
        # Flutter pub get defaults to --example; it resolves both manifests.
        formatting = [call for call in success if call["tool"] == "dart"]
        self.assertEqual(len(formatting), 1)
        self.assertEqual(formatting[0]["cwd"], str(self.checkout))
        self.assertEqual(formatting[0]["args"][:3],
                         ["format", "--output=none", "--set-exit-if-changed"])
        self.assertEqual(set(formatting[0]["args"][3:]),
                         {"lib", "test", "example/lib", "example/test"})
        analysis = [call for call in success if call["args"] == ["analyze"]]
        self.assertEqual(analysis, [{
            "tool": "flutter", "args": ["analyze"],
            "cwd": str(self.checkout),
        }])
        tests = [call for call in success if call["tool"] == "flutter"
                 and call["args"][0] == "test"]
        self.assertEqual([call["cwd"] for call in tests],
                         [str(self.checkout), str(self.example)])
        for call in tests:
            self.assertIn("--timeout=30s", call["args"])
        tooling = [call for call in success if call["tool"] == "python3"]
        self.assertEqual(tooling, [{
            "tool": "python3",
            "args": ["-m", "unittest", "discover", "-s", "test/tooling", "-p", "test_*.py"],
            "cwd": str(self.checkout),
        }, {
            # Versions in pubspec, podspec and changelog agree.
            "tool": "python3",
            "args": ["tool/release.py", "check"],
            "cwd": str(self.checkout),
        }])
        self.assertLess(success.index(formatting[0]), success.index(analysis[0]))
        self.assertLess(success.index(analysis[0]), success.index(tests[0]))
        for stage in range(1, len(success) + 1):
            with self.subTest(failed_stage=stage):
                result, calls = self.run_script("check.sh", fail_at=stage)
                self.assertEqual(result.returncode, 37, result.stderr)
                self.assertEqual(calls, success[:stage],
                                 "No later validation may run after a failure")


if __name__ == "__main__":
    unittest.main()
