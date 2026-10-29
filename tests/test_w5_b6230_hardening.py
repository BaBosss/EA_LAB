"""Adversarial RED->GREEN tests for W5 B6230 offline-only V4 comparator."""
import copy
import json
import math
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools' / 'w5_b6230_v4'))
from gate import assess_prospective, audit_manifest, load_json_strict

F = json.loads((ROOT/'tests'/'w5_b6230_SYNTHETIC_DO_NOT_USE_FOR_NATIVE.json').read_text())

class Hardening(unittest.TestCase):
    def deny(self, modify, expected):
        d=copy.deepcopy(F); modify(d)
        ans=assess_prospective(d)
        self.assertEqual(ans['classification'], 'BLOCKED', ans)
        self.assertIn(expected, ans['reasons'])
        self.assertIs(ans['native_acceptance'], False)

    def test_bad_iso_month(self):
        self.deny(lambda d: d['checkpoints'][1].update(asof_utc='2026-99-45T04:00:00Z'), 'CHECKPOINT_TIMESTAMP_INVALID')

    def test_all_zero_checkpoint_hash(self):
        self.deny(lambda d: d['checkpoints'][2].update(evidence_sha256='0'*64), 'CHECKPOINT_HASH_UNBOUND')

    def test_wrong_timestamp_zone(self):
        self.deny(lambda d: d['checkpoints'][1].update(asof_utc='2026-10-28T15:10:00+07:00'), 'CHECKPOINT_TIMESTAMP_INVALID')

    def test_byte_drift_pretend_signed_does_not_auto_clear(self):
        def f(d):
            m=d['mutable_artifacts']['symbols/selected-146237.dat']
            m.update(full_postimage_sha256='b'*64, causality='SIGNED_PROVEN_NO_EFFECT', independent_proof_sha256='a'*64)
        self.deny(f, 'UNCLASSIFIED_MUTATION_symbols/selected-146237.dat')

    def test_type_confusion_bool_vs_one(self):
        self.deny(lambda d: d['economics']['post']['account_configuration'].update(leverage=True), 'ACCOUNT_FIELD_INVALID_leverage')

    def test_nonfinite_values(self):
        self.deny(lambda d: d['economics']['post']['economics'].update(tick_value=float('inf')), 'BROKER_ECON_FIELD_INVALID_tick_value')

    def test_null_symmetric_values(self):
        def f(d):
            d['economics']['pre']['economics']['contract_size']=None
            d['economics']['post']['economics']['contract_size']=None
        self.deny(f, 'BROKER_ECON_FIELD_INVALID_contract_size')

    def test_empty_proof_capture(self):
        self.deny(lambda d: d['checkpoints'][1].update(capture=None), 'CHECKPOINT_CAPTURE_IDENTITY_MISSING')

    def test_duplicate_json_keys_refused(self):
        with self.assertRaisesRegex(ValueError, 'DUPLICATE_JSON_KEY'):
            load_json_strict('{"x":1,"x":2}')

    def test_json_nonfinite_refused(self):
        with self.assertRaisesRegex(ValueError, 'NONFINITE_JSON'):
            load_json_strict('{"x":NaN}')

    def test_malformed_packet_fails_closed(self):
        result=assess_prospective([])
        self.assertEqual(result['classification'],'BLOCKED')
        self.assertIn('PACKET_NOT_OBJECT',result['reasons'])

    def test_structural_control_no_native_acceptance(self):
        d=copy.deepcopy(F)
        for stage in d['checkpoints']:
            stage['capture']={'pid':1234,'created_utc':'2026-10-28T14:00:00Z','exe_sha256':'a'*64}
        r=assess_prospective(d)
        self.assertEqual(r['classification'],'OFFLINE_STRUCTURAL_READY_NOT_NATIVE_ACCEPTED',r)
        self.assertIs(r['native_acceptance'],False)

    def test_manifest_reads_real_bytes(self):
        with tempfile.TemporaryDirectory() as t:
            folder=Path(t)
            (folder/'payload.bin').write_bytes(b'abc')
            expected='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
            manifest={'files':[{'path':'payload.bin','bytes':3,'sha256':expected}]}
            result=audit_manifest(folder,manifest)
            self.assertTrue(result['all_match'], result)
            self.assertEqual(result['checked'],1)
            (folder/'payload.bin').write_bytes(b'abd')
            result=audit_manifest(folder,manifest)
            self.assertFalse(result['all_match'])
            self.assertIn('HASH_MISMATCH:payload.bin',result['reasons'])

    def test_manifest_rejects_traversal_and_duplicates(self):
        with tempfile.TemporaryDirectory() as t:
            root=Path(t)
            bad={'files':[{'path':'../file','bytes':0,'sha256':'a'*64}]}
            self.assertIn('UNSAFE_PATH:../file',audit_manifest(root,bad)['reasons'])
            dup={'files':[{'path':'ok','bytes':0,'sha256':'a'*64},{'path':'ok','bytes':0,'sha256':'a'*64}]}
            self.assertIn('DUPLICATE_PATH:ok',audit_manifest(root,dup)['reasons'])

    def test_manifest_rejects_symlink(self):
        with tempfile.TemporaryDirectory() as t:
            root=Path(t)
            target=root/'true'; target.write_bytes(b'xyz')
            alias=root/'alias'
            try: alias.symlink_to(target)
            except (OSError,NotImplementedError): self.skipTest('symlinks not permitted')
            r=audit_manifest(root,{'files':[{'path':'alias','bytes':3,'sha256':'a'*64}]})
            self.assertIn('SYMLINK_PATH:alias',r['reasons'])

    def test_manifest_requires_content_sha_not_only_flag(self):
        with tempfile.TemporaryDirectory() as t:
            root=Path(t); (root/'f').write_bytes(b'ab')
            r=audit_manifest(root,{'files':[{'path':'f','bytes':2,'sha256':'0'*64}]})
            self.assertIn('INVALID_SHA:f',r['reasons'])

if __name__=='__main__':unittest.main()

class HistoricalReceiptPins(unittest.TestCase):
    def test_receipt_hash_rewrite_rejected(self):
        from gate import assess_historical
        d=json.loads((ROOT/'tests'/'w5_b6230_historical_receipt_fixture.json').read_text())
        d['drifts'][2]['pre_sha256']='b'*64
        r=assess_historical(d)
        self.assertFalse(r['receipt_consistent'])
        self.assertIn('DRIFT_PINNED_SHA_MISMATCH_symbols/selected-146237.dat',r['reasons'])

    def test_mutated_same_source_year_pair_rejected(self):
        from gate import assess_historical
        d=json.loads((ROOT/'tests'/'w5_b6230_historical_receipt_fixture.json').read_text())
        d['source_years']['2024']={'pre_sha256':'a'*64,'post_sha256':'a'*64}
        r=assess_historical(d)
        self.assertFalse(r['receipt_consistent'])
        self.assertIn('M1_YEAR_PINNED_SHA_MISMATCH_2024',r['reasons'])

    def test_missing_origin_receipt_rejected(self):
        from gate import assess_historical
        d=json.loads((ROOT/'tests'/'w5_b6230_historical_receipt_fixture.json').read_text())
        d['provenance'].pop('audit_sha256')
        r=assess_historical(d)
        self.assertFalse(r['receipt_consistent'])
        self.assertIn('HISTORICAL_SOURCE_PIN_MISMATCH_audit_sha256',r['reasons'])
