import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools' / 'ea_lab_harness'))
from test_harness import _packet
from harness import sha256_value
spec = importlib.util.spec_from_file_location('resume_work', ROOT / 'scripts/execution_reliability/resume_work.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class ResumeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ealab-resume-fixture-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.job = self.root / 'job-1'
        self.job.mkdir()
        (self.job / 'logs').mkdir()
        (self.job / 'logs/stdout.log').write_text('completed fixture execution')
        self.request = {'job_id': 'job-1', 'base_sha': 'a'*40, 'postcondition_file_path': 'checker.exe'}
        self.state = {'job_id': 'job-1', 'state': 'COMPLETE'}
        self.result = {'job_id': 'job-1', 'state': 'COMPLETE', 'exit_code': 0, 'postcondition_exit_code': 0}
        self.write()

    def write(self):
        for name in ('request', 'state', 'result'):
            filename = 'job' if name == 'request' else name
            (self.job / (filename + '.json')).write_text(json.dumps(getattr(self, name)))

    def observe(self):
        return m.observe_job(self.job, 'a'*40)

    def test_complete_is_not_accepted_and_never_retried(self):
        result = self.observe()
        self.assertEqual(result['status'], 'EXECUTION_COMPLETE_UNACCEPTED')
        self.assertFalse(result['automatic_retry_allowed'])
        self.assertFalse(result['authority_granted'])

    def test_checker_error_boolean_null_and_missing_rejected(self):
        for code in (-1, 1, None, False, '0'):
            with self.subTest(code=code):
                self.result['postcondition_exit_code'] = code
                self.write()
                self.assertEqual(self.observe()['status'], 'UNKNOWN')

    def test_interruption_refuses_blind_retry(self):
        for phase in ('RUNNING', 'STARTING', 'POSTCONDITION_RUNNING', 'LOST_PROCESS', 'FAILED', 'TIMED_OUT', 'CANCELLED'):
            self.state['state'] = phase
            self.write()
            result = self.observe()
            self.assertNotEqual(result['status'], 'EXECUTION_COMPLETE_UNACCEPTED')
            self.assertFalse(result['automatic_retry_allowed'])

    def test_moved_source_and_job_identity(self):
        self.assertEqual(m.observe_job(self.job, 'b'*40)['status'], 'SOURCE_MISMATCH')
        self.result['job_id'] = 'other-job'
        self.write()
        self.assertEqual(self.observe()['status'], 'UNKNOWN')

    def test_missing_and_malformed_records(self):
        (self.job/'result.json').write_text('[]')
        self.assertEqual(self.observe()['status'], 'UNKNOWN')
        (self.job/'result.json').unlink()
        self.assertEqual(self.observe()['status'], 'UNKNOWN')

    def packet(self):
        packet, _ = _packet()
        packet['contract']['execution_binding'] = m.execution_binding(self.job, 'a'*40)
        file = self.root / 'evidence.txt'
        file.write_text('fixture evidence')
        packet['artifacts'] = [{'path': 'evidence.txt', 'sha256': hashlib.sha256(file.read_bytes()).hexdigest()}]
        self.seal(packet)
        review = packet['review']
        admission = {'schema_version': 'ea-lab-job-admission/v1', 'job_id': 'job-1',
                     'assurance_contract': copy.deepcopy(packet['contract']),
                     'review_policy': {'independent_required': True, 'different_family_required': True,
                                       'qualified_reviewers': [{k: review[k] for k in ('reviewer_id','reviewer_family','reviewer_model')}]}}
        return packet, admission

    @staticmethod
    def seal(packet):
        packet.pop('packet_id', None)
        packet['packet_id'] = sha256_value(packet)

    def test_existing_harness_is_actual_acceptance_consumer(self):
        packet, admission = self.packet()
        result = self.qualify(packet, admission)
        self.assertTrue(result['valid'])
        self.assertFalse(result['authority_granted'])

    def test_refused_review_and_moved_head(self):
        packet, admission = self.packet()
        with self.assertRaises(ValueError):
            m.qualify_assurance(packet, admission, self.root, 'c'*40, self.job)
        packet['review']['approved'] = False
        self.seal(packet)
        with self.assertRaises(ValueError):
            self.qualify(packet, admission)

    def test_review_requirement_cannot_be_self_downgraded(self):
        packet, admission = self.packet()
        packet['review']['different_family_required'] = False
        self.seal(packet)
        with self.assertRaisesRegex(ValueError, 'policy'):
            self.qualify(packet, admission)

    def test_missing_modified_traversal_and_duplicate_artifacts(self):
        for path in ('missing.txt', '../outside.txt', 'C:/outside.txt'):
            packet, admission = self.packet()
            packet['artifacts'][0]['path'] = path
            self.seal(packet)
            with self.assertRaises((ValueError, OSError)):
                self.qualify(packet, admission)
        packet, admission = self.packet()
        (self.root/'evidence.txt').write_text('changed')
        with self.assertRaises(ValueError):
            self.qualify(packet, admission)
        packet, admission = self.packet()
        packet['artifacts'].append(dict(packet['artifacts'][0]))
        self.seal(packet)
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            self.qualify(packet, admission)

    def qualify(self, packet, admission):
        return m.qualify_assurance(packet, admission, self.root, 'b'*40, self.job)

    def test_missing_author_identity_refused(self):
        for key in ('author_id', 'author_family'):
            for value in (None, '', '  '):
                packet, admission = self.packet()
                packet['contract'][key] = value
                admission['assurance_contract'] = copy.deepcopy(packet['contract'])
                self.seal(packet)
                with self.assertRaisesRegex(ValueError, 'author identity'):
                    self.qualify(packet, admission)

    def test_packet_from_another_completed_attempt_refused(self):
        packet, admission = self.packet()
        admission['job_id'] = 'job-2'
        other = self.root / 'job-2'
        other.mkdir()
        (other / 'logs').mkdir()
        (other / 'logs/stdout.log').write_text('other execution')
        for name, record in (('job', self.request), ('state', self.state), ('result', self.result)):
            (other / (name + '.json')).write_text(json.dumps({**record, 'job_id': 'job-2'}))
        self.assertEqual(m.observe_job(other, 'a'*40)['status'], 'EXECUTION_COMPLETE_UNACCEPTED')
        with self.assertRaisesRegex(ValueError, 'execution binding'):
            m.qualify_assurance(packet, admission, self.root, 'b'*40, other)

    def test_missing_or_changed_execution_binding_refused(self):
        packet, admission = self.packet()
        del packet['contract']['execution_binding']
        admission['assurance_contract'] = copy.deepcopy(packet['contract'])
        self.seal(packet)
        with self.assertRaisesRegex(ValueError, 'execution binding'):
            self.qualify(packet, admission)
        for path in ('job.json', 'state.json', 'result.json', 'logs/stdout.log'):
            packet, admission = self.packet()
            # Whitespace preserves JSON semantics but changes the reviewed bytes.
            with (self.job/path).open('a') as stream:
                stream.write(' ')
            with self.assertRaisesRegex(ValueError, 'execution binding'):
                self.qualify(packet, admission)


if __name__ == '__main__':
    unittest.main()
