"""Isolated synthetic negative/positive checks for stage and agent cache policy."""
import sys
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'/'w5_b6230_v4'))
from provenance import compare_stage_data, compare_agent_cache

A={'sha256':'a'*64,'bytes':4}
B={'sha256':'b'*64,'bytes':4}
POLICY={'mode':'EMPTY','expected_created':['2023.hcs'],'preregistered_contract_sha256':'c'*64}

class StageDiff(unittest.TestCase):
    def baseline(self):
        return {k:{'history/XAUUSD/2023.hcc':dict(A)} for k in ('S0','S1','S2','S3')}
    def test_identical_stages_structural_only(self):
        r=compare_stage_data(self.baseline(),expected_count=1)
        self.assertEqual(r['classification'],'STRUCTURAL_IDENTICAL_NO_NATIVE_ACCEPTANCE')
        self.assertIs(r['native_acceptance'],False)
    def test_preprobe_mutation_attributed_to_phase_not_source(self):
        s=self.baseline()
        for k in ('S1','S2','S3'):s[k]['history/XAUUSD/2023.hcc']=dict(B)
        r=compare_stage_data(s, expected_count=1)
        self.assertEqual(r['classification'],'BLOCKED')
        self.assertIn('UNCLASSIFIED_PREPROBE_DATA_CHANGE:history/XAUUSD/2023.hcc',r['reasons'])
        self.assertEqual(r['deltas']['TESTER'],[])
    def test_tester_mutation_detected(self):
        s=self.baseline()
        for k in ('S2','S3'):s[k]['history/XAUUSD/2023.hcc']=dict(B)
        r=compare_stage_data(s, expected_count=1)
        self.assertIn('UNCLASSIFIED_TESTER_DATA_CHANGE:history/XAUUSD/2023.hcc',r['reasons'])
    def test_postprobe_mutation_detected(self):
        s=self.baseline();s['S3']['history/XAUUSD/2023.hcc']=dict(B)
        r=compare_stage_data(s, expected_count=1)
        self.assertIn('UNCLASSIFIED_POSTPROBE_DATA_CHANGE:history/XAUUSD/2023.hcc',r['reasons'])
    def test_default_requires_106_files_per_stage(self):
        r=compare_stage_data(self.baseline())
        self.assertIn('STAGE_FILE_COUNT_MISMATCH:S0',r['reasons'])

    def test_missing_s1_blocked(self):
        s=self.baseline();s.pop('S1')
        self.assertIn('S0_S1_S2_S3_MISSING',compare_stage_data(s, expected_count=1)['reasons'])
    def test_added_extra_file_blocked(self):
        s=self.baseline();s['S2']['symbols/selected-146237.dat']=dict(A)
        self.assertIn('UNCLASSIFIED_TESTER_DATA_CHANGE:symbols/selected-146237.dat',compare_stage_data(s, expected_count=1)['reasons'])

class AgentTransitions(unittest.TestCase):
    def test_empty_to_expected_created_structural_only(self):
        r=compare_agent_cache({}, {'2023.hcs':A}, POLICY)
        self.assertEqual(r['classification'],'AGENT_STRUCTURAL_MATCH_NOT_CONSUMPTION_PROOF')
        self.assertIs(r['native_acceptance'],False)
    def test_empty_to_undocumented_extra_blocked(self):
        r=compare_agent_cache({}, {'2023.hcs':A,'2024.hcs':B}, POLICY)
        self.assertIn('AGENT_CREATED_SET_MISMATCH',r['reasons'])
    def test_pinned_byte_change_blocked(self):
        p={'mode':'PINNED_NONEMPTY','expected_created':[],'preregistered_contract_sha256':'c'*64}
        r=compare_agent_cache({'2023.hcs':A},{'2023.hcs':B},p)
        self.assertIn('AGENT_PINNED_CACHE_CHANGED',r['reasons'])
    def test_pinned_unchanged_only_structural(self):
        p={'mode':'PINNED_NONEMPTY','expected_created':[],'preregistered_contract_sha256':'c'*64}
        r=compare_agent_cache({'2023.hcs':A},{'2023.hcs':A},p)
        self.assertEqual(r['classification'],'AGENT_STRUCTURAL_MATCH_NOT_CONSUMPTION_PROOF')
    def test_bad_create_allowlist_rejected_without_crash(self):
        p=dict(POLICY);p['expected_created']=[{'not':'hashable'}]
        self.assertIn('AGENT_CREATE_ALLOWLIST_INVALID',compare_agent_cache({}, {'2023.hcs':A},p)['reasons'])

    def test_unbound_policy_rejected(self):
        p=dict(POLICY);p.pop('preregistered_contract_sha256')
        self.assertIn('AGENT_POLICY_NOT_PREREG_HASH_BOUND',compare_agent_cache({}, {'2023.hcs':A},p)['reasons'])
    def test_wrong_mode_rejected(self):
        p=dict(POLICY);p['mode']='AUTO'
        self.assertIn('AGENT_MODE_UNDECLARED',compare_agent_cache({}, {'2023.hcs':A},p)['reasons'])

if __name__=='__main__':unittest.main()
