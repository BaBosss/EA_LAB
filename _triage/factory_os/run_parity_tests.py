# -*- coding: utf-8 -*-
"""run_parity_tests.py -- ORDER-1021 (S8). The cage for the 7-point parity comparator.

WHY THIS SUITE CAN EXIST AT ALL. `parity.py` is PURE -- it takes report text and log lines and
returns verdicts -- so every case below is a SYNTHETIC ARTIFACT PAIR built in memory. The cage
therefore costs milliseconds and needs no MT5 lane, while the thing it guards costs two tester runs
per case. That split is the whole reason the tester work lives in `scripts/parity_run.ps1`.

EVERY CRITERION APPEARS TWICE (`docs/GUARD_SHAPES.md` shape 5):
    ATTACK       a pair this criterion exists to refuse. It must be RED.
    SPECIFICITY  a pair it must accept. Asserted per case, not once globally, because parity's
                 failure mode is the OPPOSITE of most guards': the dangerous direction is a
                 comparator that says AGREE too easily, and a comparator that refused everything
                 would pass every attack below while being useless.

🔴 THE CASES THAT MATTER MOST ARE THE VACUITY ONES. Design 5.5 exists because a wrapper and its
parent can both do NOTHING and match. So the load-bearing assertions here are not "different trade
lists are caught" -- they are "two empty trade lists are NOT reported as agreement", and "a
must-trade case that traded nothing FAILS even though all seven points agree".

USAGE  tools\\python312\\python.exe _triage/factory_os/run_parity_tests.py
EXIT   0 = every case behaved as declared - 1 = one did not
"""
import os
import json
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import parity as P                                                        # noqa: E402

CFG = ('[CFG] input surface: build=LAB_ENTRY_14 keys=116 scope=surface+constants '
       'effective_config_hash=' + 'a' * 64)
CFG_OTHER = CFG.replace('a' * 64, 'b' * 64)
FATAL = '[INIT] FATAL: FirstLotMode=41 with _41_FixedLot=0.0000 - no lot to trade'
FATAL_OTHER = '[INIT] FATAL: FirstLotMode=42 (risk%) with _42_RiskPct <= 0 - nothing to size from'
RISK = '[RISK] acct-DD gate TRIP: DD 1.52% vs limit 0.30% (HWM 10007.41) - blocking new first-entries'


def _report(deal_rows=(), order_rows=(), inputs=()):
    """A minimal MT5-tester-report-shaped document. It carries the TOTALS row every real report
    ends with, because that row is what made the first version of `_table` unable to observe an
    empty list -- a fixture without it would not reproduce the defect it now guards."""
    def cells(row):
        return ''.join('<td>%s</td>' % c for c in row)
    head = ''.join(
        '<tr align="right"><td nowrap colspan="3"></td>'
        '<td nowrap colspan="10" align="left"><b>%s=%s</b></td></tr>' % kv for kv in inputs)
    body = ''
    for heading, rows in (('Orders', order_rows), ('Deals', deal_rows)):
        body += '<tr align="center"><th colspan="13"><div><b>%s</b></div></th></tr>' % heading
        body += '<tr align="center"><td nowrap><b>Open Time</b></td><td><b>Order</b></td></tr>'
        body += ''.join('<tr align=right>%s</tr>' % cells(r) for r in rows)
        body += '<tr align="right"><td nowrap colspan="8"></td><td nowrap><b>0.00</b></td></tr>'
    return '<html><body><table>%s%s</table></body></html>' % (head, body)


DEAL_A = ['2024.01.02 07:36:20', '2', 'XAUUSD', 'buy', 'in', '0.01', '2066.44', '2', '0.00',
          '0.00', '0.00', '10 000.00', '14_GridLog L0']
DEAL_B = ['2024.01.02 14:03:40', '3', 'XAUUSD', 'buy', 'in', '0.01', '2078.98', '3', '0.00',
          '0.00', '0.00', '10 000.00', '14_GridLog L1']
ORDER_A = ['2024.01.02 07:36:20', '2', 'XAUUSD', 'buy', '0.01 / 0.01', '0.00', '', '2083.48',
           '2024.01.02 07:36:20', 'filled', '14_GridLog L0']


def obs(label, deals=(), orders=(), log=(), inputs=()):
    return P.observe(label, report_html=_report(deals, orders, inputs), log_lines=list(log))


# --- attacks ---------------------------------------------------------------------------------------

def a_deals_differ():
    """The plain case: different trade lists."""
    return (obs('wrapper', deals=[DEAL_A], orders=[ORDER_A], log=[CFG]),
            obs('parent', deals=[DEAL_A, DEAL_B], orders=[ORDER_A], log=[CFG]),
            P.NEUTRAL, 'deals', P.DIFFER)


def a_cfg_differs():
    """Same trades, different effective_config_hash. Point 4 alone would call this parity."""
    return (obs('wrapper', deals=[DEAL_A], orders=[ORDER_A], log=[CFG]),
            obs('parent', deals=[DEAL_A], orders=[ORDER_A], log=[CFG_OTHER]),
            P.NEUTRAL, 'cfg', P.DIFFER)


def a_both_empty_is_not_agreement():
    """🔴 THE CASE THE WHOLE CONTRACT IS BUILT ON. Two runs that opened nothing. Every list
    matches, so trade-list identity would report parity -- and design 5.5 rev 1 did. An empty list
    is the easiest way to match, so this must be UNTESTED and never AGREE."""
    return (obs('wrapper', log=[CFG]), obs('parent', log=[CFG]),
            P.NEUTRAL, 'deals', P.UNTESTED)


def a_refusal_reasons_differ():
    """Both refused -- for DIFFERENT reasons. `refused` is not a single state, and two EAs dying
    of different causes is not agreement about anything."""
    return (obs('wrapper', log=[FATAL]), obs('parent', log=[FATAL_OTHER]),
            P.DELIBERATE_REFUSAL, 'init', P.DIFFER)


def a_one_refused_one_attached():
    """The asymmetric case, and the reason NOT_APPLICABLE carries a precondition: if this were
    allowed to downgrade the downstream points, a wrapper that failed OnInit on a wrong generated
    const would be compared against a parent that traded, and every vacuous point would be excused
    on the strength of the wrapper's own failure."""
    a, b = obs('wrapper', log=[FATAL]), obs('parent', deals=[DEAL_A], orders=[ORDER_A], log=[CFG])
    return (a, b, P.DELIBERATE_REFUSAL, 'init', P.DIFFER)


DEAL_EOT_A = ['2024.06.28 23:58:59', '59', 'XAUUSD', 'sell', 'out', '0.01', '2326.58', '59',
              '0.00', '-41.35', '-92.77', '10 140.38', 'end of test']
DEAL_EOT_B = ['2024.06.28 23:58:59', '60', 'XAUUSD', 'sell', 'out', '0.02', '2326.58', '60',
              '0.00', '-41.35', '-102.55', '9 996.48', 'end of test']


def a_end_state_differs():
    """🔴 ADDED BY THE FIRST AUDIT ROUND, which found point 5 could not fail. The old end_state
    read only non-terminal ORDERS -- impossible under B14-H01 (`_9_PendingMode` const 0) -- so it
    returned [] == [] in every case, reported AGREE, and the roll-up counted it as exercised
    three times over. The real observable is the `end of test` DEALS: the positions the window
    closed on. Here the sides end holding different volumes, and the point must see it."""
    return (obs('wrapper', deals=[DEAL_A, DEAL_EOT_A], orders=[ORDER_A], log=[CFG]),
            obs('parent', deals=[DEAL_A, DEAL_EOT_B], orders=[ORDER_A], log=[CFG]),
            P.NEUTRAL, 'end_state', P.DIFFER)


def a_end_state_both_empty():
    """The twin: both sides flat at end AND no deals at all -- must be UNTESTED, not AGREE.
    This is the exact state the refusal case produced when the old code said AGREE."""
    return (obs('wrapper', deals=[], orders=[], log=[CFG]),
            obs('parent', deals=[], orders=[], log=[CFG]),
            P.NEUTRAL, 'end_state', P.UNTESTED)


def a_alert_ignores_host_noise():
    """A terminal host message containing 'failed' lands in ONE side's slice on timing alone.
    The first _ALERT regex matched bare 'failed' and would have called this a parity DIFFER."""
    a = obs('wrapper', deals=[DEAL_A], orders=[ORDER_A],
            log=[CFG, 'network connection failed, retrying'])
    b = obs('parent', deals=[DEAL_A], orders=[ORDER_A], log=[CFG])
    got = dict((p.point, p.verdict) for p in P.compare(a, b))
    return (got['alerts'] != P.DIFFER,
            'host noise produced a DIFFER on alerts: %r' % got['alerts'])


def a_anchor_catches_cache_poison():
    """🔴 ADDED BY THE SECOND AUDIT ROUND. `expected_hash` was written into every manifest and
    read by NOTHING -- point 2 compared wrapper against parent only. The failure that slips
    through a two-sided comparison: MT5 fills every unlisted input from the per-terminal cache,
    so a .set that silently fails to apply does so for BOTH runs -- identical wrong hashes,
    point 2 AGREE, parity holds while measuring some other configuration (ORDER-165's 8/8 false
    drift, memory mt5-tester-cache-nondeterminism). The anchor makes point 2 TRIANGULAR:
    wrapper == parent == compiler. Both directions asserted: a matching side produces no reason,
    a mismatched side produces exactly one that names both hashes."""
    o = obs('wrapper', deals=[DEAL_A], orders=[ORDER_A], log=[CFG])
    fired = P.anchor_reasons({'expected_hash': 'f' * 64}, o)
    quiet = P.anchor_reasons({'expected_hash': 'a' * 64}, o)     # CFG's hash is 'a'*64
    refused = P.anchor_reasons({'expected_hash': 'f' * 64}, obs('wrapper', log=[FATAL]))
    return (len(fired) == 1 and quiet == [] and refused == [],
            'fired=%d (want 1), quiet=%d (want 0), refused-side=%d (want 0 -- no [CFG] printed)'
            % (len(fired), len(quiet), len(refused)))


def a_side_effects_differ():
    """Identical trades; only the wrapper trips the account-DD cage. Points 1-5 all agree."""
    return (obs('wrapper', deals=[DEAL_A], orders=[ORDER_A], log=[CFG, RISK]),
            obs('parent', deals=[DEAL_A], orders=[ORDER_A], log=[CFG]),
            P.NEUTRAL, 'side_effects', P.DIFFER)


def a_totals_row_is_not_a_deal():
    """🔴 A REGRESSION CAGE FOR A DEFECT THAT WAS REAL. `_table` used to accept any row with a
    non-empty cell, so the report's unlabelled TOTALS row counted as a deal and the Deals list was
    never empty -- which made the vacuity check above unreachable on real reports while passing on
    synthetic ones. The fixture builds a report with NO deals and asserts the extractor sees zero,
    not one."""
    o = obs('wrapper', log=[CFG])
    return o.deals == [], 'the TOTALS row was counted as a deal: %r' % (o.deals,)


def a_report_inputs_counted():
    """The Inputs-page count is read from the REPORT, i.e. from the binary, and the section
    heading row (`=== Mode selectors ===`) must not be counted as an input."""
    o = obs('wrapper', log=[CFG], inputs=[('=== Mode selectors ', '=='), ('SLMode', '30'),
                                          ('_41_FixedLot', '0.01')])
    return (len(o.inputs) == 2,
            'expected 2 real inputs, got %r' % (o.inputs,))


# --- direction attacks (verdict_for_case) ----------------------------------------------------------

def d_must_trade_that_traded_nothing():
    """🔴 ALL SEVEN POINTS AGREE AND THE CASE MUST STILL FAIL. Two runs that opened nothing agree
    perfectly. design 5.5 demands a must-trade direction precisely so that agreement cannot be
    bought with silence, and the direction is checked against the OBSERVATION, not the comparison."""
    a, b = obs('wrapper', log=[CFG]), obs('parent', log=[CFG])
    passed, reasons = P.verdict_for_case(P.MUST_TRADE, a, b, P.compare(a, b))
    return (not passed and any('opened NOTHING' in r for r in reasons),
            'a must-trade case that traded nothing was accepted: %r' % (reasons,))


def d_refusal_that_attached():
    """A refusal case where both sides happily attached. Parity would then be proving that two
    silent runs are silent."""
    a = obs('wrapper', deals=[DEAL_A], orders=[ORDER_A], log=[CFG])
    b = obs('parent', deals=[DEAL_A], orders=[ORDER_A], log=[CFG])
    passed, reasons = P.verdict_for_case(P.DELIBERATE_REFUSAL, a, b, P.compare(a, b))
    return (not passed and any('ATTACHED' in r for r in reasons),
            'a deliberate-refusal case that attached was accepted: %r' % (reasons,))


def d_rollup_needs_every_point_exercised():
    """The roll-up must refuse a set in which a point was never once measured -- which is the
    shape a set of only-clean cases has (nothing ever raises an alert)."""
    a, b = obs('wrapper', deals=[DEAL_A], orders=[ORDER_A], log=[CFG]), None
    b = obs('parent', deals=[DEAL_A], orders=[ORDER_A], log=[CFG])
    pts = P.compare(a, b)
    ok, lines = P.rollup([('must-trade', P.MUST_TRADE, pts)])
    return (not ok and any('never exercised' in l for l in lines)
            and any('no deliberate-refusal case' in l for l in lines),
            'the roll-up accepted a set with an unexercised point: %r' % (lines,))


# --- committed result-manifest replay -----------------------------------------------------------

def _result_side(label, observation):
    return {
        'label': label,
        'expert': 'EALabTpl\\%s' % label,
        'binary': 'lane\\%s.ex5' % label,
        'binary_mtime': '2026-08-16 00:00:00',
        'expected_hash': 'a' * 64,
        'source_manifest': 'factory/parity/fixture/%s.json' % label,
        'observation': P.observation_to_record(observation),
    }


def _result_case(name, kind, a, b, included=True):
    points = P.compare(a, b)
    passed, _reasons = P.verdict_for_case(kind, a, b, points)
    case = {
        'case': name,
        'kind': kind,
        'included': included,
        'sides': {'wrapper': _result_side('wrapper', a),
                  'parent': _result_side('parent', b)},
        'point_verdicts': [{'point': p.point, 'verdict': p.verdict} for p in points],
        'case_passed': passed,
    }
    if not included:
        case['exclusion_reason'] = 'EXPECTED_DIFFERENCE'
    return case


def _valid_result_manifest():
    must_a = obs('wrapper', deals=[DEAL_A, DEAL_EOT_A], orders=[ORDER_A], log=[CFG, RISK])
    must_b = obs('parent', deals=[DEAL_A, DEAL_EOT_A], orders=[ORDER_A], log=[CFG, RISK])
    refusal_a = obs('wrapper', log=[FATAL])
    refusal_b = obs('parent', log=[FATAL])
    locked_a = obs('wrapper', deals=[DEAL_A], orders=[ORDER_A], log=[CFG])
    locked_b = obs('parent', deals=[DEAL_A, DEAL_B], orders=[ORDER_A], log=[CFG])
    return {
        'schema_version': 1,
        'entity': 'ParityResultManifest',
        'run_identity': {'lane': 'D:\\Meta 5\\terminal64.exe', 'symbol': 'XAUUSD',
                         'period': 'H1', 'from': '2024.01.01', 'to': '2024.07.01',
                         'model': 1},
        'cases': [_result_case('must-trade', P.MUST_TRADE, must_a, must_b),
                  _result_case('deliberate-refusal', P.DELIBERATE_REFUSAL, refusal_a, refusal_b),
                  _result_case('locked-absent', P.NEUTRAL, locked_a, locked_b, included=False)],
    }


def a_result_manifest_valid_replays():
    manifest = _valid_result_manifest()
    parsed = P.read_result_manifest(json.dumps(manifest), 'fixture')
    summary = P.evaluate_result_manifest(parsed)
    return (summary['replay_ok'] and summary['rollup_ok']
            and summary['directions'][P.MUST_TRADE]
            and summary['directions'][P.DELIBERATE_REFUSAL],
            'valid committed result was rejected: %r' % summary)


def a_result_manifest_missing_observation_is_rejected():
    manifest = _valid_result_manifest()
    del manifest['cases'][0]['sides']['wrapper']['observation']['alerts']
    try:
        P.read_result_manifest(json.dumps(manifest), 'fixture')
    except P.ManifestError as exc:
        return 'alerts' in str(exc), 'missing observation rejected without naming alerts: %s' % exc
    return False, 'incomplete observation was accepted'


def a_result_manifest_tampered_verdict_is_rejected():
    manifest = _valid_result_manifest()
    manifest['cases'][0]['point_verdicts'][0]['verdict'] = P.DIFFER
    parsed = P.read_result_manifest(json.dumps(manifest), 'fixture')
    summary = P.evaluate_result_manifest(parsed)
    return (not summary['replay_ok'] and any('recorded point verdicts' in p
                                             for p in summary['replay_problems']),
            'tampered recorded verdict was not detected: %r' % summary)


def a_result_manifest_tampered_identity_is_rejected():
    manifest = _valid_result_manifest()
    manifest['cases'][0]['sides']['wrapper']['expected_hash'] = 'f' * 64
    parsed = P.read_result_manifest(json.dumps(manifest), 'fixture')
    summary = P.evaluate_result_manifest(parsed)
    return (not summary['replay_ok'] and any('compiler-anchor' in p
                                             for p in summary['replay_problems']),
            'compiler identity mismatch was not detected: %r' % summary)


POINT_ATTACKS = (
    ('deals', 'two different trade lists', a_deals_differ),
    ('cfg', 'same trades, different effective_config_hash -- point 4 alone calls this parity',
     a_cfg_differs),
    ('deals', 'BOTH sides opened nothing -- the counter-example design 5.5 is built on',
     a_both_empty_is_not_agreement),
    ('init', 'both refused, for DIFFERENT reasons', a_refusal_reasons_differ),
    ('init', 'one refused and one attached -- NOT_APPLICABLE must not excuse the rest',
     a_one_refused_one_attached),
    ('side_effects', 'identical trades, only one side trips the account-DD cage',
     a_side_effects_differ),
    ('end_state', 'the sides end the window holding different open volumes', a_end_state_differs),
    ('end_state', 'both flat with no deals -- UNTESTED, not the AGREE the first version printed',
     a_end_state_both_empty),
)

PLAIN_ATTACKS = (
    ('extractor', 'the report TOTALS row must not count as a deal', a_totals_row_is_not_a_deal),
    ('extractor', 'the Inputs section heading must not count as an input', a_report_inputs_counted),
    ('direction', 'a must-trade case that traded nothing -- all seven points agree and it FAILS',
     d_must_trade_that_traded_nothing),
    ('direction', 'a deliberate-refusal case that attached', d_refusal_that_attached),
    ('rollup', 'a case set in which a point was never once exercised',
     d_rollup_needs_every_point_exercised),
    ('alerts', 'a host log line containing "failed" on one side only must NOT differ',
     a_alert_ignores_host_noise),
    ('anchor', 'both sides cache-poisoned to the SAME wrong hash -- only the compiler corner sees it',
     a_anchor_catches_cache_poison),
    ('manifest', 'a valid committed result replays and satisfies the case-set contract',
     a_result_manifest_valid_replays),
    ('manifest', 'incomplete observation fields are rejected deterministically',
     a_result_manifest_missing_observation_is_rejected),
    ('manifest', 'tampered recorded point verdicts are rejected by replay',
     a_result_manifest_tampered_verdict_is_rejected),
    ('manifest', 'tampered compiler identity is rejected by replay',
     a_result_manifest_tampered_identity_is_rejected),
)


def main(argv):
    bad = 0
    sys.stdout.write('=== ORDER-1021 parity comparator: %d point attack(s) + %d structural, each '
                     'with its specificity half ===\n'
                     % (len(POINT_ATTACKS), len(PLAIN_ATTACKS)))

    # SPECIFICITY, asserted FIRST and gating everything: a pair that genuinely agrees must come
    # back AGREE on every point it can observe. Without this a comparator that returned DIFFER
    # unconditionally would pass every attack above.
    a = obs('wrapper', deals=[DEAL_A], orders=[ORDER_A], log=[CFG, RISK])
    b = obs('parent', deals=[DEAL_A], orders=[ORDER_A], log=[CFG, RISK])
    same = P.compare(a, b)
    disagreeing = [p.point for p in same if p.verdict == P.DIFFER]
    if disagreeing:
        sys.stdout.write('  [BAD] specificity an IDENTICAL pair was reported as differing on %s\n'
                         % ', '.join(disagreeing))
        bad += 1
    else:
        sys.stdout.write('  [OK ] specificity an identical pair agrees on every observable point '
                         '(%d AGREE)\n' % sum(1 for p in same if p.verdict == P.AGREE))

    for point, title, fn in POINT_ATTACKS:
        oa, ob, kind, expect_point, expect_verdict = fn()
        del kind
        got = dict((p.point, p.verdict) for p in P.compare(oa, ob))
        if got.get(expect_point) == expect_verdict:
            sys.stdout.write('  [OK ] %-13s attack %s\n' % (point, title))
        else:
            bad += 1
            sys.stdout.write('  [BAD] %-13s attack %s\n        -> point %s came back %s, expected '
                             '%s\n' % (point, title, expect_point, got.get(expect_point),
                                       expect_verdict))

    for point, title, fn in PLAIN_ATTACKS:
        ok, why = fn()
        if ok:
            sys.stdout.write('  [OK ] %-13s attack %s\n' % (point, title))
        else:
            bad += 1
            sys.stdout.write('  [BAD] %-13s attack %s\n        -> %s\n' % (point, title, why))

    if bad:
        sys.stdout.write('\n=== %d CASE(S) DID NOT BEHAVE AS DECLARED ===\n' % bad)
        return 1
    sys.stdout.write('\n=== every criterion refused its attack, and an identical pair still '
                     'agreed ===\n')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
