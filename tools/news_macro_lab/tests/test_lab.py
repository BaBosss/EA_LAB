"""Synthetic mechanics tests; no market, performance or historical OOS evidence."""
from __future__ import annotations
import json
import math
import shutil
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path
from tools.news_macro_lab.core import (ROOT, SELECTOR, Refused, sha256, stable_hash, parse_json,
    safe_read, utc, load_selector, select_asof, news_contact, macro_context, price_features)
from tools.news_macro_lab.planning import (GATES, experiment_preflight, global_readiness,
                                           validate_shadow_annotation)

RAW = b'SYNTHETIC_MECHANICS_ONLY - not market data'
H = sha256(b'fixture classifier')
D = '2025-03-04T12:00:00Z'


def event(**kwargs):
    row = {'record_id': 'SYN-EVENT', 'revision_id': 'v1', 'record_type': 'CALENDAR_EVENT',
           'state': 'SCHEDULED', 'available_at_utc': '2025-03-04T08:00:00Z',
           'scheduled_at_utc': D, 'currency': 'USD', 'importance': 'High'}
    row.update(kwargs)
    return row


def package(rows=None):
    return {'schema_version': 'ea_lab_offline_replay_package/1',
            'classification': 'SYNTHETIC_CONTRACT_TEST_ONLY', 'dataset_id': 'SYNTHETIC-LAB',
            'dataset_version': 'v1', 'source_snapshot_sha256': sha256(RAW),
            'decision_at_utc': D,
            'coverage': {'state': 'COMPLETE', 'start_utc': '2025-01-01T00:00:00Z',
                         'end_utc': '2025-12-31T23:59:59Z'},
            'clock_mapping': {'version': 'SYNTHETIC-v1', 'source_timezone': 'UTC',
                              'broker_timezone': 'SYNTHETIC_ONLY', 'mapping_basis': 'MECHANICS_ONLY'},
            'records': [event()] if rows is None else rows}


def news(p=None, decision=D, **overrides):
    opts = dict(currencies=['USD'], importance_levels=['High'],
                pre_minutes=30, post_minutes=15, synthetic=True)
    opts.update(overrides)
    return news_contact(p or package(), RAW, decision, **opts)


def regime(**kwargs):
    row = {'record_id': 'SYN-REGIME', 'revision_id': 'v1', 'record_type': 'REGIME_OBSERVATION',
           'state': 'PUBLISHED', 'available_at_utc': '2025-03-04T10:00:00Z',
           'effective_at_utc': '2025-03-04T10:00:00Z', 'source_observed_at_utc': '2025-03-04T09:00:00Z',
           'valid_until_utc': '2025-03-05T00:00:00Z', 'classifier_sha256': H,
           'series_id': 'SYN-MRIS', 'regime_state': 'RISK_OFF'}
    row.update(kwargs)
    return row


def macro(rows=None, decision=D, **overrides):
    opts = dict(series_id='SYN-MRIS', classifier_sha256=H, max_source_age_seconds=36000, synthetic=True)
    opts.update(overrides)
    return macro_context(package(rows if rows is not None else [regime()]), RAW, decision, **opts)


def close(day, value, **kwargs):
    row = {'record_id': f'SYN-PX-{day}', 'revision_id': 'v1', 'record_type': 'DAILY_CLOSE',
           'state': 'FINAL', 'effective_at_utc': f'2025-03-{day:02d}T10:00:00Z',
           'available_at_utc': f'2025-03-{day:02d}T10:01:00Z', 'instrument': 'SYN-INDEX',
           'currency': 'USD', 'price_basis': 'SYNTHETIC_PRICE_INDEX', 'value': value}
    row.update(kwargs)
    return row


def features(rows=None, **overrides):
    opts = dict(instrument='SYN-INDEX', currency='USD', price_basis='SYNTHETIC_PRICE_INDEX',
                closes=3, max_source_age_seconds=86400, synthetic=True)
    opts.update(overrides)
    return price_features(package(rows if rows is not None else [close(2,100),close(3,102),close(4,101)]), RAW, D, **opts)


def proposal():
    return json.loads((ROOT / 'tools/news_macro_lab/experiment_proposal.json').read_text('utf-8'))


def catalog():
    return json.loads((ROOT / 'tools/news_macro_lab/global_source_catalog.json').read_text('utf-8'))


class SelectionTests(unittest.TestCase):
    def test_loaded_dependency_exact_bytes(self):
        fn, digest = load_selector()
        self.assertEqual(digest, sha256((ROOT / SELECTOR).read_bytes()))
        self.assertTrue(callable(fn))

    def test_revision_not_visible_before_release(self):
        p = package([event(), event(revision_id='v2', available_at_utc='2025-03-04T13:00:00Z')])
        r = select_asof(p, RAW, D, synthetic=True)
        self.assertEqual(r['selection']['future_record_count'],1)
        self.assertEqual(r['selection']['selected_records'][0]['revision_id'],'v1')
        self.assertFalse(r['ea_replay_qualified'])

    def test_release_exact_boundary_visible(self):
        r = select_asof(package([event(available_at_utc=D)]), RAW, D, synthetic=True)
        self.assertEqual(r['selection']['selected_record_count'],1)

    def test_raw_hash_swap_refused(self):
        with self.assertRaisesRegex(Refused,'RAW_SOURCE_HASH_MISMATCH'):
            select_asof(package(), b'OTHER', D, synthetic=True)

    def test_future_clock_not_assumed_midnight(self):
        p = package([close(4,100,effective_at_utc='2025-03-04T00:00:00Z',available_at_utc='2025-03-04T16:00:00Z')])
        r=select_asof(p,RAW,D,synthetic=True)
        self.assertEqual(r['status'],'REFUSED')
        self.assertIn('REFUSE_SAME_DAY_CLOSE_AT_MIDNIGHT',r['selection']['reason_codes'])

    def test_duplicate_revision_conflict_refused(self):
        r=news(package([event(),event(currency='EUR')]))
        self.assertEqual(r['status'],'REFUSED')
        self.assertEqual(r['contact_status'],'UNKNOWN')

    def test_tied_distinct_revisions_refused(self):
        r=news(package([event(),event(revision_id='v2')]))
        self.assertEqual(r['status'],'REFUSED')

    def test_exact_duplicate_deduplicated(self):
        r=news(package([event(),event()]))
        self.assertEqual(r['selection']['exact_duplicate_count'],1)
        self.assertEqual(r['contact_event_ids'],['SYN-EVENT'])

    def test_no_events_requires_explicit_complete(self):
        p=package([])
        self.assertEqual(news(p)['status'],'REFUSED')
        p['coverage']['state']='COMPLETE_NO_EVENTS'
        r=news(p)
        self.assertEqual(r['contact_status'],'NO_CONTACT')
        self.assertFalse(r['can_execute'])

    def test_canonical_trade_field_refused(self):
        p=package();p['records'][0]['payload']={'block_new': True}
        self.assertEqual(news(p)['status'],'REFUSED')

    def test_dependency_tamper_refused_before_exec(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td); path=root/SELECTOR; path.parent.mkdir(parents=True)
            path.write_bytes((ROOT/SELECTOR).read_bytes()+b'\nraise RuntimeError("MUST_NOT_EXECUTE")\n')
            dest=root/'tools/news_macro_lab/dependency_pins.json';dest.parent.mkdir(parents=True)
            dest.write_bytes((ROOT/'tools/news_macro_lab/dependency_pins.json').read_bytes())
            with self.assertRaisesRegex(Refused,'CANONICAL_SELECTOR_CHANGED'):
                load_selector(root)

    def test_input_not_mutated(self):
        p=package();before=stable_hash(p);news(p,decision='2025-03-04T11:45:00Z')
        self.assertEqual(stable_hash(p),before)

    def test_unqualified_real_input_not_promoted(self):
        p=package();p['classification']='REAL_FULLY_ACCEPTED'  # deliberately untrusted label
        r=select_asof(p,RAW,D,synthetic=False)
        self.assertEqual(r['classification'],'UNQUALIFIED_SOURCE_PREPARATION')
        self.assertFalse(r['historical_dataset_qualified'])

    def test_outside_coverage_unknown(self):
        r=news(decision='2024-01-01T12:00:00Z')
        self.assertEqual(r['status'],'REFUSED')
        self.assertEqual(r['contact_status'],'UNKNOWN')


class NewsTests(unittest.TestCase):
    def test_before_window(self):
        self.assertEqual(news(decision='2025-03-04T11:29:59Z')['contact_status'],'NO_CONTACT')
    def test_start_inclusive(self):
        self.assertEqual(news(decision='2025-03-04T11:30:00Z')['contact_status'],'CONTACT')
    def test_inside_window(self):
        self.assertEqual(news(decision='2025-03-04T12:14:59Z')['contact_status'],'CONTACT')
    def test_end_exclusive(self):
        self.assertEqual(news(decision='2025-03-04T12:15:00Z')['contact_status'],'NO_CONTACT')
    def test_relevance_explicit_no_universal_usd(self):
        self.assertEqual(news(currencies=['EUR'])['contact_status'],'NO_CONTACT')
    def test_non_high_not_contact(self):
        self.assertEqual(news(package([event(importance='Low')]))['contact_status'],'NO_CONTACT')
    def test_importance_is_explicit_input(self):
        r=news(package([event(importance='Low')]),importance_levels=['Low'])
        self.assertEqual(r['contact_status'],'CONTACT')
        self.assertEqual(r['contact_filter']['importance_levels'],['Low'])
    def test_reschedule_does_not_retroactively_move_old_window(self):
        p=package([event(),event(revision_id='v2',available_at_utc='2025-03-04T11:50:00Z',scheduled_at_utc='2025-03-04T14:00:00Z')])
        self.assertEqual(news(p,decision='2025-03-04T11:45:00Z')['contact_status'],'CONTACT')
        self.assertEqual(news(p)['contact_status'],'NO_CONTACT')
    def test_cancel_before_event(self):
        p=package([event(),event(revision_id='v2',state='CANCELLED',available_at_utc='2025-03-04T11:00:00Z')])
        self.assertEqual(news(p)['contact_status'],'NO_CONTACT')
    def test_future_cancel_not_yet_known(self):
        p=package([event(),event(revision_id='v2',state='CANCELLED',available_at_utc='2025-03-04T12:10:00Z')])
        self.assertEqual(news(p)['contact_status'],'CONTACT')
    def test_tentative_unknown_not_no_news(self):
        p=package([event(state='TENTATIVE',scheduled_at_utc=None)])
        self.assertEqual(news(p)['contact_status'],'UNKNOWN')
    def test_actual_in_schedule_refused(self):
        with self.assertRaisesRegex(Refused,'CALENDAR_SCHEMA_OR_PAYLOAD_LEAK'):
            news(package([event(payload={'actual':999})]))
    def test_no_runtime_action(self):
        r=news(); self.assertEqual(r['ea_actions'],[])
        self.assertEqual(r['policy_parity'],'NOT_CERTIFIED')
    def test_empty_interval_refused(self):
        with self.assertRaisesRegex(Refused,'EMPTY_CONTACT_WINDOW'): news(pre_minutes=0,post_minutes=0)
    def test_no_default_window(self):
        with self.assertRaises(Refused): news(pre_minutes=None)


class MacroTests(unittest.TestCase):
    def test_asof_regime_not_probability(self):
        r=macro();self.assertEqual(r['macro_state'],'RISK_OFF');self.assertIsNone(r['probability'])
    def test_no_visible_regime_unknown(self):
        self.assertEqual(macro([regime(available_at_utc='2025-03-04T13:00:00Z')])['macro_state'],'UNKNOWN')
    def test_future_effective_withheld(self):
        self.assertEqual(macro([regime(effective_at_utc='2025-03-04T13:00:00Z')])['macro_state'],'UNKNOWN')
    def test_stale_source_unknown(self):
        self.assertEqual(macro(max_source_age_seconds=60)['macro_state'],'UNKNOWN')
    def test_expiry_not_rolled_forward(self):
        self.assertEqual(macro([regime(valid_until_utc=D)])['macro_state'],'UNKNOWN')
    def test_classifier_changed_refused(self):
        with self.assertRaisesRegex(Refused,'CLASSIFIER_LINEAGE_MISMATCH'):
            macro([regime(classifier_sha256='a'*64)])
    def test_wrong_clock_order_refused(self):
        with self.assertRaisesRegex(Refused,'REGIME_CLOCK_ORDER_INVALID'):
            macro([regime(source_observed_at_utc='2025-03-04T11:00:00Z')])
    def test_duplicate_state_time_refused(self):
        with self.assertRaisesRegex(Refused,'AMBIGUOUS_REGIME'):
            macro([regime(),regime(record_id='SYN-OTHER')])
    def test_newest_stale_does_not_fall_back_to_old_valid(self):
        rows=[regime(effective_at_utc='2025-03-04T09:00:00Z'),
              regime(record_id='SYN-NEW',valid_until_utc='2025-03-04T11:00:00Z')]
        self.assertEqual(macro(rows)['macro_state'],'UNKNOWN')
    def test_unknown_vocab_refused(self):
        with self.assertRaisesRegex(Refused,'UNKNOWN_REGIME'):macro([regime(regime_state='BULL_99PCT')])


class FeatureTests(unittest.TestCase):
    def test_realized_features_no_annualization(self):
        r=features(); self.assertAlmostEqual(r['features']['window_return'],.01)
        self.assertAlmostEqual(r['features']['price_vs_mean'],0)
        self.assertEqual(r['regime'],'UNKNOWN')
    def test_future_close_has_no_influence(self):
        a=features();b=features([close(2,100),close(3,102),close(4,101),close(5,9999)])
        self.assertEqual(a['features'],b['features'])
    def test_warmup_insufficient(self):
        self.assertEqual(features([close(4,100)])['feature_state'],'UNKNOWN')
    def test_stale_features(self):
        self.assertEqual(features(max_source_age_seconds=30)['feature_state'],'UNKNOWN')
    def test_two_prices_do_not_fabricate_volatility(self):
        self.assertIsNone(features(closes=2)['features']['log_return_sample_std'])
    def test_lookback_changes_are_explicit(self):
        self.assertEqual(features(closes=2)['features']['close_count'],2)
    def test_basis_mix_refused(self):
        with self.assertRaisesRegex(Refused,'PRICE_CURRENCY_OR_BASIS_MISMATCH'):
            features([close(2,100,price_basis='TOTAL_RETURN'),close(3,102),close(4,101)])
    def test_duplicate_bar_identities_refused(self):
        with self.assertRaisesRegex(Refused,'DUPLICATE_CLOSE_IDENTITY'):
            features([close(2,100),close(3,102),close(4,101),close(4,101,record_id='OTHER')])
    def test_revised_close_only_changes_after_revision(self):
        rows=[close(2,100),close(3,102),close(4,101),close(2,10,revision_id='v2',available_at_utc='2025-03-04T13:00:00Z')]
        self.assertAlmostEqual(features(rows)['features']['window_return'],.01)
    def test_close_available_before_close_refused(self):
        with self.assertRaisesRegex(Refused,'CLOSE_AVAILABLE_BEFORE_CLOSE'):
            features([close(2,100),close(3,102),close(4,101,available_at_utc='2025-03-04T09:00:00Z')])
    def test_extreme_derived_feature_refused(self):
        with self.assertRaisesRegex(Refused,'DERIVED_FEATURE_NOT_FINITE'):
            features([close(2,1e-308),close(3,1),close(4,1e308)])


class PlanningTests(unittest.TestCase):
    def test_map_is_not_market_regime(self):
        r=global_readiness(catalog());self.assertEqual(len(r['cells']),56)
        self.assertTrue(all(c['regime']=='UNKNOWN' for c in r['cells']))
        self.assertIsNone(r['probability'])
    def test_source_duplicate_refused(self):
        x=catalog();x['sources'].append(deepcopy(x['sources'][0]))
        with self.assertRaisesRegex(Refused,'DUPLICATE_SOURCE_ID'): global_readiness(x)
    def test_source_plan_cannot_self_qualify(self):
        x=catalog();x['sources'][0]['historical_qualified']=True
        with self.assertRaisesRegex(Refused,'CANNOT_SELF_QUALIFY'): global_readiness(x)
    def test_source_plan_cannot_supply_price(self):
        x=catalog();x['sources'][0]['value']=999
        with self.assertRaisesRegex(Refused,'MUST_NOT_CONTAIN_MARKET'): global_readiness(x)
    def test_empty_source_plan_remains_unknown(self):
        x=catalog();x['sources']=[]
        self.assertEqual(global_readiness(x)['world_regime'],'UNKNOWN')
    def test_empty_proposal_does_not_run(self):
        r=experiment_preflight(proposal());self.assertFalse(r['can_execute'])
        self.assertEqual(r['status'],'BLOCKED_CONTRACT_INCOMPLETE')
        self.assertIn('broker_clock',r['missing_gates'])
    def test_all_declared_receipts_still_not_acceptance(self):
        p=proposal();p['gate_receipt_sha256']={x:'a'*64 for x in GATES}
        p['windows']={'MAIN':{'start_utc':'2023-01-01T00:00:00Z','end_utc':'2026-01-01T00:00:00Z'},
                      'BWD':{'start_utc':'2020-01-01T00:00:00Z','end_utc':'2023-01-01T00:00:00Z'}}
        p['placebo_seeds']=[1,2];p['evaluation_unit']='BASKET_EPISODE'
        r=experiment_preflight(p);self.assertEqual(r['status'],'DECLARED_FIELDS_COMPLETE_REVIEW_REQUIRED')
        self.assertFalse(r['can_execute'])
    def test_overlap_refused(self):
        p=proposal();w={'start_utc':'2023-01-01T00:00:00Z','end_utc':'2026-01-01T00:00:00Z'}
        p['windows']={'MAIN':w,'BWD':w}
        with self.assertRaisesRegex(Refused,'MAIN_BWD_OVERLAP'):experiment_preflight(p)
    def test_placebo_duplicate_refused(self):
        p=proposal();p['placebo_seeds']=[1,1]
        with self.assertRaisesRegex(Refused,'UNIQUE_PLACEBO'):experiment_preflight(p)
    def test_unapproved_two_changes_refused(self):
        p=proposal();p['changed_dimensions']=['NEWS_FIXED_WINDOW','MACRO_FROZEN_RULES']
        with self.assertRaisesRegex(Refused,'ONE_LOGICAL_CHANGE'):experiment_preflight(p)
    def test_missing_gate_cannot_disappear(self):
        p=proposal();del p['gate_receipt_sha256']['broker_clock']
        with self.assertRaisesRegex(Refused,'EXACT_GATE_SET'):experiment_preflight(p)


class ShadowTests(unittest.TestCase):
    def annotation(self, **changes):
        a={'schema_version':'news_text_annotation/1','decision_at_utc':D,'input_sha256':sha256(RAW),
           'model_sha256':H,'prompt_sha256':H,'label_spec_sha256':H,
           'abstain':False,'scores':{'HAWKISH':.6,'DOVISH':.4}}
        a.update(changes);return a
    def call(self, a):
        return validate_shadow_annotation(a,labels=('HAWKISH','DOVISH'),source_available_at_utc=D,
            input_raw=RAW,model_sha256=H,prompt_sha256=H,label_spec_sha256=H)
    def test_typed_scores_not_calibrated(self):
        r=self.call(self.annotation());self.assertFalse(r['calibrated']);self.assertFalse(r['provider_invoked'])
    def test_abstain_null(self):
        self.assertFalse(self.call(self.annotation(abstain=True,scores=None))['can_execute'])
    def test_input_swap_refused(self):
        with self.assertRaisesRegex(Refused,'SHADOW_INPUT_HASH_MISMATCH'):
            self.call(self.annotation(input_sha256='a'*64))
    def test_model_swap_refused(self):
        with self.assertRaisesRegex(Refused,'BINDING_MISMATCH'):
            self.call(self.annotation(model_sha256='a'*64))
    def test_future_source_refused(self):
        with self.assertRaisesRegex(Refused,'PRECEDES_SOURCE'):
            self.call(self.annotation(decision_at_utc='2025-03-04T11:59:59Z'))
    def test_action_field_refused(self):
        with self.assertRaisesRegex(Refused,'SHADOW_SCHEMA_MISMATCH'):
            self.call(self.annotation(buy=True))
    def test_untrusted_label_refused(self):
        with self.assertRaisesRegex(Refused,'LABEL_SET_MISMATCH'):
            self.call(self.annotation(scores={'BUY':1}))
    def test_bad_sum_refused(self):
        with self.assertRaisesRegex(Refused,'SIMPLEX_INVALID'):
            self.call(self.annotation(scores={'HAWKISH':.6,'DOVISH':.5}))
    def test_abstention_cannot_keep_scores(self):
        with self.assertRaisesRegex(Refused,'NULL_SCORES'):
            self.call(self.annotation(abstain=True))


class InputTests(unittest.TestCase):
    def test_duplicate_json_key(self):
        with self.assertRaisesRegex(Refused,'DUPLICATE_JSON_KEY'):parse_json(b'{"a":1,"a":2}')
    def test_nested_duplicate_key(self):
        with self.assertRaisesRegex(Refused,'DUPLICATE_JSON_KEY'):parse_json(b'{"a":{"b":1,"b":2}}')
    def test_outside_root_refused(self):
        with tempfile.TemporaryDirectory() as td:
            with self.assertRaisesRegex(Refused,'OUTSIDE_ROOT'):
                safe_read(Path(td).parent/'outside',Path(td))
    def test_oversized_file_refused(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'x';p.write_bytes(b'1234')
            with self.assertRaisesRegex(Refused,'INPUT_SIZE'):safe_read(p,Path(td),maximum=3)
    def test_bom_json(self):
        self.assertEqual(parse_json(b'\xef\xbb\xbf{"a":1}'),{'a':1})


def add_case(cls, name, fn):
    setattr(cls, 'test_' + name, fn)

for i, value in enumerate([None, '', '2025-03-04', '2025-03-04T12:00:00',
                           '2025-03-04T12:00:00+07:00', '2025-02-30T12:00:00Z', 123]):
    def bad_time(self, value=value):
        with self.assertRaises(Refused):utc(value)
    add_case(InputTests,f'bad_utc_{i}',bad_time)
for i, value in enumerate([b'NaN',b'Infinity',b'-Infinity']):
    def bad_json(self, value=value):
        with self.assertRaises(Refused):parse_json(value)
    add_case(InputTests,f'nonfinite_json_{i}',bad_json)
for i, value in enumerate([True, -1, 1.1, '30']):
    def bad_window(self, value=value):
        with self.assertRaises(Refused):news(pre_minutes=value)
    add_case(NewsTests,f'bad_window_{i}',bad_window)
for i, value in enumerate([[], ['USD','USD'], ['usd'], 'USD']):
    def bad_ccy(self, value=value):
        with self.assertRaises(Refused):news(currencies=value)
    add_case(NewsTests,f'bad_currencies_{i}',bad_ccy)
for i, value in enumerate([[], ['High','High'], ['HIGH'], 'High']):
    def bad_importance(self, value=value):
        with self.assertRaises(Refused):news(importance_levels=value)
    add_case(NewsTests,f'bad_importance_{i}',bad_importance)
for i, state in enumerate(['UNKNOWN','PARTIAL','MISSING']):
    def coverage(self, state=state):
        p=package();p['coverage']['state']=state
        self.assertEqual(news(p)['contact_status'],'UNKNOWN')
    add_case(SelectionTests,f'coverage_{i}',coverage)
for i, value in enumerate([True, float('nan'), float('inf'), '100', 0, -1]):
    def bad_price(self, value=value):
        with self.assertRaises((Refused,ValueError)):
            features([close(2,100),close(3,102),close(4,value)])
    add_case(FeatureTests,f'bad_price_{i}',bad_price)
for key, value in [('can_execute',True),('optimization','GRID'),('bwd_role','TUNING'),('holdout_policy','USE_NOW')]:
    def denied(self,key=key,value=value):
        p=proposal();p[key]=value
        with self.assertRaises(Refused):experiment_preflight(p)
    add_case(PlanningTests,'forbidden_'+key,denied)

if __name__=='__main__':unittest.main()
