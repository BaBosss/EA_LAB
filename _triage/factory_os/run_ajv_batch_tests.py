"""Regression cage for schema fixture transport, not a substitute for real AJV cases."""
import json
import os
from pathlib import Path
import tempfile
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_schema_fixtures as subject


class BatchTransportTests(unittest.TestCase):
    def test_large_batch_visits_each_input_with_one_bounded_command(self):
        cases = [{'name': 'fixture-%d' % i, 'instance': i} for i in range(450)]
        calls = []

        def run(cmd, **kwargs):
            calls.append(cmd)
            cwd = Path(kwargs.get('cwd', os.getcwd()))
            files = []
            for index, arg in enumerate(cmd):
                if arg == '-d':
                    target = cmd[index + 1]
                    files.extend(cwd.glob(target) if not os.path.isabs(target)
                                 else [Path(target)])
            lines = []
            for path in files:
                value = json.loads(path.read_text())
                self.assertEqual(path.name, 'case_%03d.json' % value)
                lines.append('%s valid' % path)
            return SimpleNamespace(returncode=0, stdout='\n'.join(lines), stderr='')

        with patch.object(subject.subprocess, 'run', side_effect=run):
            got = subject.run_batch('relative-schema.json', cases)
        self.assertEqual(len(got), len(cases))
        self.assertTrue(all(v[0] == subject.VALID for v in got.values()))
        self.assertEqual(len(calls), 1, 'schema compile/startup repeated for one batch')
        self.assertLess(sum(len(x) + 3 for x in calls[0]), 7000)
        self.assertEqual(calls[0][calls[0].index('-s') + 1],
                         os.path.abspath('relative-schema.json'))

    def test_missing_output_never_satisfies_negative_case(self):
        cases = [{'name': 'seen', 'instance': 1}, {'name': 'unseen', 'instance': -1}]
        reply = SimpleNamespace(returncode=2, stdout='case_000.json valid', stderr='validator failed')
        with patch.object(subject.subprocess, 'run', return_value=reply):
            got = subject.run_batch('schema.json', cases)
        self.assertEqual(got['seen'][0], subject.VALID)
        self.assertEqual(got['unseen'][0], subject.ERROR)

    def test_empty_batch_starts_no_validator(self):
        with patch.object(subject.subprocess, 'run') as run:
            self.assertEqual(subject.run_batch('schema.json', []), {})
            run.assert_not_called()

    def test_real_ajv_all_cases_spaces_brackets_and_error_attribution(self):
        # The absolute parent has glob metacharacters; only the fixed relative pattern
        # may be interpreted by AJV. Every positive/negative still gets its own verdict.
        with tempfile.TemporaryDirectory(prefix='ajv_batch_') as tmp:
            schema = Path(tmp) / 'schema with spaces.json'
            schema.write_text(json.dumps({'type': 'integer', 'minimum': 0}))
            data_dir = Path(tmp) / 'data [batch] directory'
            data_dir.mkdir()
            cases = [{'name': 'positive', 'instance': 0}, {'name': 'negative', 'instance': -1}]
            old_tempdir = subject.tempfile.tempdir
            try:
                subject.tempfile.tempdir = str(data_dir)
                got = subject.run_batch(str(schema), cases)
            finally:
                subject.tempfile.tempdir = old_tempdir
            self.assertEqual(got['positive'][0], subject.VALID)
            self.assertEqual(got['negative'][0], subject.INVALID)
            self.assertIn('minimum', got['negative'][1])
            schema.write_text('{invalid json')
            failed = subject.run_batch(str(schema), cases)
            self.assertTrue(all(v[0] == subject.ERROR for v in failed.values()))


if __name__ == '__main__':
    # The PowerShell cage treats native stderr under EAP=Stop as a launcher failure.
    # Preserve unittest's exit status, but put its ordinary progress on stdout.
    unittest.main(testRunner=unittest.TextTestRunner(stream=sys.stdout))
