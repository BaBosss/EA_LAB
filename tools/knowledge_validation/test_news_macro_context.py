"""Twelve frozen synthetic cases, with bounded adversarial subcases."""
from __future__ import annotations

import copy
import hashlib
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.knowledge_validation.news_macro_context import (  # noqa: E402
    LABELS, PINS, SYMBOL_METADATA, broker_clock, build_context, symbol_metadata,
)
from tools.knowledge_validation.offline_replay_validator import qualify_replay_package, stable_hash

OUT = ROOT / 'factory/runs/news_macro_context_v1_20261004'
FIXTURE_BYTES = (OUT / 'FROZEN_12_FIXTURES.json').read_bytes()
FIXTURES = json.loads(FIXTURE_BYTES)['cases']
CONTRACT = json.loads((OUT / 'FROZEN_CONTRACT.json').read_text(encoding='utf-8'))


def factor(result, country='US', axis='employment'):
    return next(x for x in result['factors'] if x['country'] == country and x['factor_id'] == axis)


class FrozenContextCases(unittest.TestCase):
    def case(self, index):
        row = copy.deepcopy(FIXTURES[index - 1])
        return row['request'], row['raw_source_utf8'].encode('utf-8')

    def run_case(self, index):
        return build_context(*self.case(index))

    def test_01_available_at_selection(self):
        request, raw = self.case(1)
        before = copy.deepcopy(request)
        result = build_context(request, raw)
        us = factor(result)
        self.assertEqual(us['state'], 'FIXTURE_SELECTED')
        self.assertEqual(us['value'], 123)
        self.assertEqual(us['revision']['revision_id'], 'SYN-r1')
        self.assertEqual(us['fetched_at_utc'], '2025-03-01T00:00:00Z')
        self.assertEqual(us['freshness_basis'], 'available_at_utc')
        self.assertEqual(result['selection'], qualify_replay_package(request['package']))
        self.assertEqual(request, before)
        request['package']['decision_at_utc'] = '2025-02-07T13:30:00Z'
        self.assertEqual(factor(build_context(request, raw))['value'], 123)
        request['package']['decision_at_utc'] = '2025-02-07T13:29:59Z'
        self.assertIsNone(factor(build_context(request, raw))['value'])

    def test_02_future_revision_exclusion(self):
        request, raw = self.case(2)
        result = build_context(request, raw)
        self.assertEqual(factor(result)['revision']['revision_id'], 'SYN-r1')
        self.assertEqual(result['selection']['future_record_count'], 1)
        request['package']['decision_at_utc'] = '2025-03-07T13:31:00Z'
        result = build_context(request, raw)
        self.assertEqual(factor(result)['value'], 999)
        self.assertEqual(factor(result)['revision']['revision_id'], 'SYN-r2')

    def test_03_missing_source_clock_hash(self):
        edits = [
            ('source', lambda r: r['package']['records'][0].pop('source'), 'MISSING_SOURCE_IDENTITY'),
            ('release_clock', lambda r: r['package']['records'][0].pop('release_clock'), 'MISSING_OR_INVALID_RELEASE_CLOCK_PROOF'),
            ('clock', lambda r: r['package'].pop('clock_mapping'), 'MISSING_OR_INVALID_RELEASE_CLOCK_PROOF'),
            ('hash', lambda r: r['package'].pop('source_snapshot_sha256'), 'SOURCE_HASH_MISMATCH'),
            ('vintage', lambda r: r['package']['records'][0].pop('vintage_id'), 'MISSING_VINTAGE_REVISION_PROOF'),
            ('period', lambda r: r['package']['records'][0].pop('observed_period'), 'MISSING_OBSERVED_PERIOD'),
            ('availability', lambda r: r['package']['records'][0].pop('available_at_utc'), 'MISSING_OR_INVALID_RELEASE_CLOCK_PROOF'),
        ]
        for name, edit, reason in edits:
            with self.subTest(name=name):
                request, raw = self.case(3); edit(request)
                result = build_context(request, raw)
                self.assertIn(reason, result['reason_codes'])
                self.assertIsNone(factor(result)['value'])
        request, raw = self.case(3)
        self.assertIn('MISSING_RAW_SOURCE', build_context(request, None)['reason_codes'])
        self.assertIn('SOURCE_HASH_MISMATCH', build_context(request, raw + b'tamper')['reason_codes'])
        for axis in ('vintage_id', 'source_revision_id'):
            request, raw = self.case(3); request['package']['records'][0][axis] = 'UNKNOWN'
            self.assertIn('MISSING_VINTAGE_REVISION_PROOF', build_context(request, raw)['reason_codes'])
        request, raw = self.case(3); request['package']['records'][0]['release_clock']['evidence_id'] = 'UNKNOWN'
        self.assertIn('MISSING_OR_INVALID_RELEASE_CLOCK_PROOF', build_context(request, raw)['reason_codes'])

    def test_04_conflicting_revisions(self):
        result = self.run_case(4)
        self.assertIn('REFUSE_CONFLICTING_DUPLICATE', result['selection']['reason_codes'])
        self.assertIsNone(factor(result)['value'])
        request, raw = self.case(1)
        second = copy.deepcopy(request['package']['records'][0]); second['revision_id'] = 'SYN-other'
        request['package']['records'].append(second)
        self.assertIn('REFUSE_AMBIGUOUS_SAME_AVAILABLE_AT', build_context(request, raw)['reason_codes'])
        request, raw = self.case(1)
        request['package']['records'].append(copy.deepcopy(request['package']['records'][0]))
        result = build_context(request, raw)
        self.assertEqual(result['selection']['exact_duplicate_count'], 1)
        self.assertEqual(factor(result)['state'], 'FIXTURE_SELECTED')

    def test_05_unknown_freshness(self):
        result = self.run_case(5)
        self.assertIn('UNKNOWN_FRESHNESS', factor(result)['reason_codes'])
        self.assertIsNone(factor(result)['value'])
        for config in ({'basis': 'fetched_at_utc', 'max_age_seconds': 3600},
                       {'basis': 'available_at_utc', 'max_age_seconds': True},
                       {'basis': 'available_at_utc', 'max_age_seconds': 0},
                       {'basis': 'available_at_utc', 'max_age_seconds': 2.0}):
            with self.subTest(config=config):
                request, raw = self.case(5); request['freshness'] = config
                self.assertIn('UNKNOWN_FRESHNESS', factor(build_context(request, raw))['reason_codes'])
        request, raw = self.case(1); request['freshness']['max_age_seconds'] = 59
        self.assertIn('STALE_FACTOR_WITHHELD', factor(build_context(request, raw))['reason_codes'])
        request['freshness']['max_age_seconds'] = 60
        self.assertEqual(factor(build_context(request, raw))['state'], 'FIXTURE_SELECTED')

    def test_06_unknown_coverage(self):
        request, raw = self.case(6)
        for state in ('UNKNOWN', 'PARTIAL', 'MISSING'):
            with self.subTest(state=state):
                request['package']['coverage']['state'] = state
                result = build_context(request, raw)
                self.assertIn('REFUSE_' + state + '_COVERAGE', result['reason_codes'])
                self.assertIsNone(factor(result)['value'])
                self.assertEqual(factor(result)['coverage']['state'], state)

    def test_07_current_only_refusal(self):
        result = self.run_case(7)
        self.assertIn('CURRENT_ONLY_NOT_REPLAYABLE', result['reason_codes'])
        self.assertIsNone(factor(result)['value'])
        self.assertFalse(result['historical_dataset_qualified'])
        self.assertFalse(result['ea_replay_qualified'])
        request, raw = self.case(7)
        request['source_mode'] = 'VINTAGE_WITH_RELEASE_CLOCK'
        self.assertIn('MISSING_VINTAGE_REVISION_PROOF', build_context(request, raw)['reason_codes'])

    def test_08_japan_unknown_preservation(self):
        result = self.run_case(8)
        japan = [x for x in result['factors'] if x['country'] == 'JP']
        self.assertEqual(len(japan), 4)
        for slot in japan:
            self.assertEqual(slot['state'], 'UNKNOWN')
            self.assertIsNone(slot['value']); self.assertIsNone(slot['source'])
            self.assertEqual(slot['source_qualification'], 'UNQUALIFIED')
            self.assertIn('JAPAN_SOURCE_PACKAGE_UNQUALIFIED', slot['reason_codes'])
        request, raw = self.case(8)
        request['package']['records'][0].update(country='JP', currency='JPY', factor_id='yield_10y')
        self.assertIn('INPUT_FOR_UNQUALIFIED_SLOT', build_context(request, raw)['reason_codes'])

    def test_09_explicit_symbol_mapping(self):
        self.assertEqual(SYMBOL_METADATA, CONTRACT['symbol_metadata'])
        self.assertEqual(symbol_metadata('USDJPY')['base'], 'USD')
        self.assertEqual(symbol_metadata('USDJPY')['quote'], 'JPY')
        self.assertEqual(symbol_metadata('USDJPY')['countries'], ['US', 'JP'])
        for symbol in ('EURGBP', 'EURUSD', 'GBP', 'JPYUSD', 'USDJPY.a', 'usdjpy', 'XAUUSD', 'BTCUSD', None, []):
            with self.subTest(symbol=symbol):
                self.assertEqual(symbol_metadata(symbol)['support'], 'NOTSUPPORTED')
                self.assertEqual(symbol_metadata(symbol)['countries'], [])
                request, raw = self.case(9); request['symbol'] = symbol
                self.assertIsNone(factor(build_context(request, raw))['value'])
        mutated = symbol_metadata('USDJPY'); mutated['countries'].append('INVENTED')
        self.assertEqual(symbol_metadata('USDJPY')['countries'], ['US', 'JP'])

    def test_10_proxy_country_separation(self):
        result = self.run_case(10)
        proxy = result['proxy_references'][0]
        self.assertEqual(proxy['identity'], 'US10Y_JP10Y')
        self.assertEqual(proxy['observed_leg'], 'US')
        self.assertFalse(proxy['qualified_japan_series']); self.assertFalse(proxy['country_factor_input'])
        self.assertIsNone(factor(result, 'JP', 'yield_10y')['value'])
        self.assertIsNone(factor(result, 'US', 'yield_10y')['value'])

    def test_11_deterministic_repeat_hash(self):
        self.assertEqual(len(FIXTURES), 12)
        self.assertEqual(PINS, CONTRACT['source_pins'])
        self.assertEqual(hashlib.sha256(FIXTURE_BYTES).hexdigest(), CONTRACT['fixtures_sha256'])
        self.assertEqual([x['case_id'] for x in FIXTURES], CONTRACT['fixture_ids'])
        for name, digest in CONTRACT['source_pins'].items():
            self.assertEqual(hashlib.sha256((ROOT / name).read_bytes()).hexdigest(), digest, name)
        for index in range(1, 13):
            self.assertEqual(stable_hash(self.run_case(index)), stable_hash(self.run_case(index)))
        first = self.run_case(11)
        request, raw = self.case(11); request['package']['records'][0]['value'] = 321
        self.assertNotEqual(stable_hash(first), stable_hash(build_context(request, raw)))
        request, raw = self.case(11); evidence = build_context(request, raw)
        old_hash = stable_hash(evidence); request['package']['records'][0]['source']['source_id'] = 'MUTATED'
        self.assertEqual(stable_hash(evidence), old_hash)

    def test_12_clock_global_authority_boundaries(self):
        result = self.run_case(12)
        self.assertEqual(list(LABELS), CONTRACT['global_mris_labels'])
        self.assertEqual(result['global_mris_reference']['labels'], list(LABELS))
        self.assertFalse(result['global_mris_reference']['state_computed'])
        self.assertIsNone(result['automatic_policy_output'])
        self.assertEqual(result['capabilities'], 'PARTIAL')
        self.assertEqual(result['evidence_label'], 'SYNTHETIC/FIXTURE_ONLY')
        binding = {'server_lineage': 'ThinkMarkets-Live', 'server_time': '2025.02.07 15:31:00',
                   'mapping_version': 'THINKMARKETS_LIVE_US_DST_QUARANTINE_V1'}
        self.assertEqual(broker_clock(binding, '2025-02-07T13:31:00Z')['state'], 'REFERENCE_MAPPING_ONLY')
        for stamp, reason in [('2026.02.07 15:31:00', 'OUTSIDE_ACCEPTED_SERVER_INTERVAL'),
                              ('2019.02.28 15:31:00', 'OUTSIDE_ACCEPTED_SERVER_INTERVAL'),
                              ('2025.03.09 15:31:00', 'UNKNOWN_DST_TRANSITION')]:
            binding['server_time'] = stamp
            self.assertEqual(broker_clock(binding, '2025-02-07T13:31:00Z')['reason'], reason)
        binding.update(server_time='2025.02.07 15:31:00', server_lineage='OTHER')
        self.assertEqual(broker_clock(binding, '2025-02-07T13:31:00Z')['reason'], 'UNQUALIFIED_BROKER_LINEAGE')
        for key in ('trade_action', 'policy_choice', 'factor_weights', 'aggregate_country_score', 'BUY'):
            request, raw = self.case(12); request['package']['records'][0][key] = 'INVENTED'
            self.assertIn('FORBIDDEN_POLICY_OR_AGGREGATION_FIELD', build_context(request, raw)['reason_codes'])
        for state in ('CANCELLED', 'TENTATIVE'):
            request, raw = self.case(12); request['package']['records'][0]['state'] = state
            self.assertIsNone(factor(build_context(request, raw))['value'])
        request, raw = self.case(12); request['fixture_only'] = False
        self.assertIn('REAL_SOURCE_SELECTION_NOT_AUTHORIZED', build_context(request, raw)['reason_codes'])
        for bad in (None, [], {}, 7):
            self.assertEqual(build_context(bad, b'')['selection']['status'], 'REFUSED')

    def test_13_enum_correction_negative_inputs(self):
        negative = json.loads((OUT / 'enum_correction1' / 'FROZEN_NEGATIVE_INPUTS.json').read_bytes())
        _, raw = self.case(1)
        for case in negative['cases']:
            with self.subTest(case_id=case['case_id']):
                result = build_context(case['request'], raw)
                expected_error = 'INVALID_COVERAGE_STATE_TYPE' if case['field'] == 'coverage' else 'INVALID_RECORD_STATE_TYPE'
                self.assertIn(expected_error, result['reason_codes'])
                for slot in result['factors']:
                    self.assertEqual(slot['state'], 'UNKNOWN')
                    self.assertIsNone(slot['value'])

        for val in (None, True, False, 123, 12.3):
            with self.subTest(control=val):
                request, _ = self.case(1)
                request['package']['coverage']['state'] = val
                result = build_context(request, raw)
                self.assertIn('INVALID_COVERAGE_STATE_TYPE', result['reason_codes'])

                request, _ = self.case(1)
                if val is None:
                    del request['package']['records'][0]['state']
                else:
                    request['package']['records'][0]['state'] = val
                result = build_context(request, raw)
                self.assertIn('INVALID_RECORD_STATE_TYPE', result['reason_codes'])

        request, _ = self.case(1)
        del request['package']['coverage']['state']
        self.assertIn('INVALID_COVERAGE_STATE_TYPE', build_context(request, raw)['reason_codes'])

        request, _ = self.case(1)
        request['package']['coverage']['state'] = []
        request['package']['records'][0]['state'] = {}
        result = build_context(request, raw)
        self.assertIn('INVALID_COVERAGE_STATE_TYPE', result['reason_codes'])
        self.assertIn('INVALID_RECORD_STATE_TYPE', result['reason_codes'])
        for slot in result['factors']:
            self.assertEqual(slot['state'], 'UNKNOWN')

        request, _ = self.case(2)
        request['package']['records'][1]['state'] = []
        result = build_context(request, raw)
        self.assertIn('INVALID_RECORD_STATE_TYPE', result['reason_codes'])
        for slot in result['factors']:
            self.assertEqual(slot['state'], 'UNKNOWN')
            self.assertIsNone(slot['value'])

        request, _ = self.case(1)
        request['package']['coverage']['state'] = 'PARTIAL'
        result = build_context(request, raw)
        self.assertNotIn('INVALID_COVERAGE_STATE_TYPE', result['reason_codes'])
        self.assertIn('REFUSE_PARTIAL_COVERAGE', result['reason_codes'])

        request, _ = self.case(1)
        request['package']['coverage']['state'] = []
        result1 = build_context(request, raw)
        result2 = build_context(request, raw)
        self.assertEqual(stable_hash(result1), stable_hash(result2))
        self.assertEqual(request['package']['coverage']['state'], [])

        import tempfile
        from unittest.mock import patch
        import tools.knowledge_validation.news_macro_context as nmc
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            req_file = tmp / 'req.json'
            raw_file = tmp / 'raw.txt'
            req_file.write_text(json.dumps(negative['cases'][0]['request']), encoding='utf-8')
            raw_file.write_bytes(raw)

            with patch.object(sys, 'argv', ['nmc', '--input', str(req_file), '--raw-source', str(raw_file)]):
                with patch('sys.stdout'):
                    ret = nmc.main()
                    self.assertEqual(ret, 2)

if __name__ == '__main__':
    unittest.main(verbosity=2)
