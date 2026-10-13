"""Version bookkeeping for releases, against a throwaway checkout."""

import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('release', SOURCE / 'tool/release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='liquid-prism-release-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        (self.root / 'ios').mkdir()
        self.write('pubspec.yaml', 'name: liquid_prism\nversion: 0.1.0\n')
        self.write('ios/liquid_prism.podspec',
                   "Pod::Spec.new do |s|\n  s.version          = '0.1.0'\nend\n")
        self.write('CHANGELOG.md', '# Changelog\n\n## Unreleased\n\n- New thing.\n'
                   '\n## 0.1.0\n\n- First.\n')

    def write(self, name, text):
        (self.root / name).write_text(text)

    def read(self, name):
        return (self.root / name).read_text()

    def run_main(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = release.main(list(argv), root=self.root)
        return code, out.getvalue().strip(), err.getvalue().strip()

    def test_check_accepts_agreeing_versions_and_matching_tag(self):
        self.assertEqual(self.run_main('check', '--tag', 'v0.1.0'), (0, '0.1.0', ''))

    def test_check_rejects_drift(self):
        self.write('ios/liquid_prism.podspec', "  s.version = '0.0.9'\n")
        code, _, err = self.run_main('check')
        self.assertEqual(code, 1)
        self.assertIn('podspec version 0.0.9', err)

    def test_check_rejects_missing_changelog_section_and_wrong_tag(self):
        self.write('CHANGELOG.md', '# Changelog\n\n## Unreleased\n')
        self.assertIn('no "## 0.1.0"', self.run_main('check')[2])
        self.write('CHANGELOG.md', '## 0.1.0\n')
        self.assertIn('tag v0.2.0', self.run_main('check', '--tag', 'v0.2.0')[2])

    def test_bump_moves_unreleased_notes_and_both_versions(self):
        self.assertEqual(self.run_main('bump', '0.2.0'), (0, '0.2.0', ''))
        self.assertIn('version: 0.2.0', self.read('pubspec.yaml'))
        self.assertIn("s.version          = '0.2.0'", self.read('ios/liquid_prism.podspec'))
        self.assertTrue(self.read('CHANGELOG.md').startswith(
            '# Changelog\n\n## Unreleased\n\n## 0.2.0\n\n- New thing.\n\n## 0.1.0'))
        self.assertEqual(self.run_main('notes', '0.2.0'), (0, '- New thing.', ''))

    def test_bump_refuses_old_versions_and_empty_notes(self):
        self.assertIn('not after', self.run_main('bump', '0.1.0')[2])
        self.assertIn('not after', self.run_main('bump', '0.1.0-beta.1')[2])
        self.assertIn('not a semantic version', self.run_main('bump', '2')[2])
        self.write('CHANGELOG.md', '## Unreleased\n\n## 0.1.0\n')
        self.assertIn('no notes', self.run_main('bump', '0.2.0')[2])
        self.assertIn('version: 0.1.0', self.read('pubspec.yaml'))


if __name__ == '__main__':
    unittest.main()
