"""Verify version consistency checker against throwaway checkouts."""

import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    'check_versions',
    SOURCE / 'tool/check_versions.py',
)
check_versions = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(check_versions)


class VersionCheckTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='liquid-prism-ver-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        (self.root / 'ios').mkdir()
        self.write('pubspec.yaml', 'name: liquid_prism\nversion: 1.0.0\n')
        self.write(
            'ios/liquid_prism.podspec',
            "Pod::Spec.new do |s|\n  s.version          = '1.0.0' # x-release-please-version\nend\n",
        )
        self.write('.release-please-manifest.json', '{".": "1.0.0"}\n')
        self.write('README.md', '```yaml\n      ref: v1.0.0 # x-release-please-version\n```\n')

    def write(self, name, text):
        (self.root / name).write_text(text)

    def run_main(self):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = check_versions.main(root=self.root)
        return code, out.getvalue().strip(), err.getvalue().strip()

    def test_accepts_consistent_versions(self):
        self.assertEqual(self.run_main(), (0, '1.0.0', ''))

    def test_rejects_podspec_drift(self):
        self.write('ios/liquid_prism.podspec', "  s.version = '0.9.0'\n")
        code, _, err = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn('podspec version 0.9.0', err)

    def test_rejects_manifest_drift(self):
        self.write('.release-please-manifest.json', '{".": "1.1.0"}\n')
        code, _, err = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn('.release-please-manifest.json', err)

    def test_rejects_readme_drift(self):
        self.write('README.md', '      ref: v0.20.1\n')
        code, _, err = self.run_main()
        self.assertEqual(code, 1)
        self.assertIn('README.md ref v0.20.1', err)


if __name__ == '__main__':
    unittest.main()
