"""
run_s11_tests.py - the cage for slice S11 (ORDER-1131). Control Center shell + SafeProjection.

WHAT IT DRIVES, AND WHY IT IS SHAPED LIKE THIS
  design 10's S11 row asks for "all 30 handoff acceptance scenarios" plus the SafeProjection
  DTO with "a recursive forbidden-key scan + synthetic secret/account fixtures".

  🔴 THE SOURCE OF THE THIRTY IS NOT IN THIS REPO. The design names it as an input --
  `EA_LAB_CONTROL_ROOM_HANDOFF_2026-07-29.md`, "22 sections + 30 acceptance scenarios" -- and
  that file was never committed (checked across every ref, and the owner confirmed on
  2026-08-02 that they no longer have it). So the catalog below is DERIVED from the clause of
  design 7.1 / 7.3 / 7.4 that each case tests, and every case names its clause. It is not a
  copy of the missing thirty and this file does not claim to be one. The COUNT is printed by
  this suite and is deliberately not restated anywhere in prose -- that rule was broken three
  times in this repo, most recently inside the session that wrote it down.

  Everything runs IN PROCESS. The S10 lesson, verbatim: when a cage is too slow, make it
  cheaper to DRIVE, not cheaper to CARE. Exactly two subprocess runs survive, and both make a
  claim the in-process cases cannot: WIRE-1 renders the shell from the REAL snapshot through
  the one reader, and WIRE-2 builds the projection from that same real document and validates
  it against schemas.json with ajv. The rest is arithmetic on fixtures.

THE ROLL-UPS ARE THE POINT
  Three of them, and each began red:
    R1  every placement rule id in control_center.BAND_RULES was fired by some case. A rule
        with a comment and no attack is a rule nobody has tested.
    R2  every scan layer (FORBIDDEN_KEY, KNOWN_SECRET, and each named value rule) fired at
        least once. A guard with zero fires is UNTESTED -- CLAUDE.md's bar table, not an
        opinion.
    R3  every case in the catalog ran. A case that quietly stops being called is the silent
        skip this repo has paid for three times in one slice.

USAGE  tools\\python312\\python.exe _triage/factory_os/run_s11_tests.py
       tools\\python312\\python.exe _triage/factory_os/run_s11_tests.py --list
"""
import copy
import io
import json
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
REPO = os.path.dirname(os.path.dirname(HERE))

import control_center as cc            # noqa: E402
import safe_projection as sp           # noqa: E402
import snapshot_validator as sv        # noqa: E402

CASES = []
FIRED_RULES = set()
FIRED_SCAN = set()


def case(cid, clause, title):
    def wrap(fn):
        CASES.append((cid, clause, title, fn))
        return fn
    return wrap


def fired(hits):
    """Record which scan layers a fixture actually made fire, for roll-up R2."""
    for _path, rule, _detail in hits:
        FIRED_SCAN.add(rule)
    return hits


# R1 measures the PLACEMENT TABLE'S coverage, so it has to see every placement the real
# scenarios make - not only the ones a test called by hand. control_center.build_today() reads
# `place` off its own module globals, so wrapping it here records every placement any case
# causes. (The wrapper is installed once, at import, and is removed by nothing: this module is
# the test process.)
_real_place = cc.place


def _recording_place(row):
    band, rule_id, why = _real_place(row)
    FIRED_RULES.add(rule_id)
    return band, rule_id, why


cc.place = _recording_place


def place(row):
    return _recording_place(cc.normalise_row(row))


# ---------------------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------------------
ACCOUNT_A = '159503454'
ACCOUNT_B = '463666728'
PLANTED_TOKEN = '7712345678:AAH9xQwErTyUiOpAsDfGhJkLzXcVbNm0987'
PLANTED_ACCOUNT = '900112233'


def snapshot(**over):
    """A minimal ControlRoomSnapshotV5-shaped document. Not ajv-valid on purpose: these cases
    drive the PROJECTION, and the real document is what WIRE-1/WIRE-2 validate."""
    doc = {
        'entity': 'ControlRoomSnapshotV5',
        'meta': {
            'build_id': 'b0000000000000ff', 'generated_at': '2026-08-02T00:00:00',
            'version': 5, 'stale_bar_hours': 30,
            'reconciliation': {'discovered': 0, 'categorized': 0,
                               'categories': {'actionable': 0, 'running': 0, 'waiting': 0,
                                              'review_audit': 0, 'completed': 0,
                                              'cancelled_by_user': 0},
                               'duplicates': 0, 'conflicts': 0, 'unclassified': 0,
                               'coverage': {'tested': 0, 'untested': 0, 'not_applicable': 0,
                                            'cells_in_universe': 0}},
            'sources': [],
        },
        'verdict': {'reconciliation_clear': True, 'reasons': []},
        'system_health': [{'account': ACCOUNT_A, 'state': 'FRESH', 'age_hours': 1.0,
                           'collector': 'MT5', 'latest_file': 'x.csv',
                           'governance_scope': 'LAB_MANAGED'}],
        'floating_risk': [{'account': ACCOUNT_A, 'state': 'FRESH', 'age_hours': 1.0,
                           'balance': 7761.56, 'equity': 7441.23, 'floating_pl': -320.33,
                           'margin_level': 4728.2,
                           'magics': [{'magic': '990101', 'open_lots': 0.05, 'pos_count': 5}]}],
        'deployments': {'rows': [], 'gaps': {'missing_kill': [], 'missing_judge': [],
                                             'unverified': []}},
        'unknown_magics': [], 'attestation': [], 'judge_readiness': [], 'judge_cohorts': [],
        'summary': {'accounts_total': 1, 'deployments_active': 0},
    }
    for k, v in over.items():
        doc[k] = v
    return doc


def read_ok(doc=None):
    return cc.SnapshotRead(cc.READ_OK, 'OK', '', doc if doc is not None else snapshot())


def rows_of(*specs):
    return [dict(s) for s in specs]


# =======================================================================================
# TODAY - snapshot health (design 7.1 row 1). The most dangerous cell in the product.
# =======================================================================================

@case('T01', '7.1 TODAY (1)', 'a clean snapshot with no LIVE exception renders ALL CLEAR')
def t01():
    pages = cc.project(read_ok())
    assert pages['today']['health']['headline'] == 'ALL CLEAR', pages['today']['health']


@case('T02', '7.1 TODAY (1)', 'reconciliation_clear=false renders ATTENTION and every reason code')
def t02():
    doc = snapshot(verdict={'reconciliation_clear': False,
                            'reasons': [{'code': 'DUPLICATES_PRESENT', 'detail': 'duplicates=6'},
                                        {'code': 'UNCLASSIFIED_PRESENT', 'detail': 'unclassified=28'}]})
    h = cc.project(read_ok(doc))['today']['health']
    assert h['headline'] == 'ATTENTION', h
    assert [r['code'] for r in h['reasons']] == ['DUPLICATES_PRESENT', 'UNCLASSIFIED_PRESENT'], h


@case('T03', '7.1 TODAY (1)', 'a REFUSED snapshot renders UNKNOWN about the DOCUMENT, never ALL CLEAR')
def t03():
    read = cc.SnapshotRead(cc.READ_REFUSED, 'VERDICT', 'the stored verdict is not the computed one', None)
    pages = cc.project(read)
    h = pages['today']['health']
    assert h['headline'] == 'UNKNOWN' and h['about'] == 'DOCUMENT', h
    assert h['numbers_suppressed'] is True, h


@case('T04', '7.1 TODAY (1)', 'a MALFORMED snapshot is UNKNOWN too, and says which code')
def t04():
    read = cc.SnapshotRead(cc.READ_REFUSED, 'MALFORMED', 'not parseable', None)
    h = cc.project(read)['today']['health']
    assert h['headline'] == 'UNKNOWN' and h['code'] == 'MALFORMED', h


@case('T05', '7.1 TODAY (1)', 'UNAVAILABLE is about the INSTRUMENT and is not collapsed into REFUSED')
def t05():
    a = cc.project(cc.SnapshotRead(cc.READ_UNAVAILABLE, 'MISSING', 'no snapshot', None))['today']['health']
    b = cc.project(cc.SnapshotRead(cc.READ_REFUSED, 'VERDICT', 'refused', None))['today']['health']
    assert a['about'] == 'INSTRUMENT' and b['about'] == 'DOCUMENT', (a, b)
    assert a['headline'] == b['headline'] == 'UNKNOWN', (a, b)


@case('T06', '7.1 TODAY (1)', 'when the snapshot cannot be read EVERY other band renders UNKNOWN, not zero')
def t06():
    pages = cc.project(cc.SnapshotRead(cc.READ_UNAVAILABLE, 'TOOL', 'no interpreter', None))
    for band in pages['today']['bands'][1:]:
        assert band.get('unknown') is True, band
        assert band['rows'] == [], band
    assert pages['work'].get('counts') is None and pages['work']['unknown'] is True
    assert pages['live']['unknown'] is True and pages['live']['exception_count'] == 0


@case('T07', '7.1 LIVE + audit-6', 'reconciliation_clear=true still renders ATTENTION when LIVE has an exception')
def t07():
    doc = snapshot(system_health=[{'account': ACCOUNT_A, 'state': 'STALE', 'age_hours': 99.0}])
    pages = cc.project(read_ok(doc))
    assert pages['live']['exception_count'] == 1, pages['live']
    assert pages['today']['health']['headline'] == 'ATTENTION', pages['today']['health']


# =======================================================================================
# TODAY - the ordering. design 7.1: "the order IS the product".
# =======================================================================================

@case('T16', 'round 1 · 7.1 LIVE', 'an account only ONE detector knows about is an exception, never a silent omission')
def t16():
    """
    ROUND-1 BLOCKER, reproduced before it was touched. `build_live` iterated system_health and
    joined floating_risk onto it, so an account with a risk row and NO health row contributed
    NOTHING: zero LIVE rows, exception_count 0, and therefore `ALL CLEAR` on TODAY over a
    detector that had never heard of the account. The probe used a BLIND sensor and 9.9 open
    lots to make the cost concrete.
    """
    doc = snapshot()
    doc['system_health'] = [{'account': ACCOUNT_A, 'state': 'FRESH'}]
    doc['floating_risk'] = [{'account': ACCOUNT_A, 'state': 'FRESH', 'magics': []},
                            {'account': ACCOUNT_B, 'state': 'BLIND',
                             'magics': [{'magic': '990101', 'open_lots': 9.9, 'pos_count': 2}]}]
    pages = cc.project(read_ok(doc))
    sensor = [b for b in pages['live']['bands'] if b['id'] == 'SENSOR'][0]
    accounts = [r.get('account') for r in sensor['rows']]
    assert ACCOUNT_B in accounts, 'the account only the risk detector knows was dropped: %s' % sensor
    assert pages['live']['exception_count'] >= 1, pages['live']['exception_count']
    assert pages['today']['health']['headline'] != 'ALL CLEAR', pages['today']['health']


@case('T17', 'round 1 · 7.1 TODAY (1)', 'a reader that says OK and hands back NO document REFUSES')
def t17():
    """
    ROUND-1: `_health_row` read the verdict off `read.document or {}`, so the contradiction
    OK-with-no-document rendered ATTENTION with zero reasons and numbers NOT suppressed - a
    headline manufactured out of nothing at all. The reader contract (snapshot_reader.ps1) is
    that Document is populated if and only if State is OK; a caller breaking it must not get a
    page.
    """
    try:
        cc.project(cc.SnapshotRead(cc.READ_OK, 'OK', '', None))
    except cc.ShellRefusal as exc:
        assert 'document' in str(exc).lower(), exc
        return
    raise AssertionError('a page was rendered from an OK read carrying no document')


@case('T08', '7.1 TODAY order', 'the eight bands render in the fixed order, always all eight')
def t08():
    ids = [b['id'] for b in cc.project(read_ok())['today']['bands']]
    assert ids == [b for b, _ in cc.TODAY_BANDS], ids
    assert ids[0] == 'SNAPSHOT_HEALTH', ids


@case('T09', '7.1 TODAY priority', 'a real-money incident sorts above a user decision inside its band')
def t09():
    rows = rows_of(
        {'id': 'O-2', 'state': 'READY', 'priority': 'BLOCKING_OTHER_WORK'},
        {'id': 'O-1', 'state': 'READY', 'priority': 'REAL_MONEY_INCIDENT'},
    )
    bands = dict((b['id'], b) for b in cc.project(read_ok(), rows)['today']['bands'])
    assert [r['id'] for r in bands['START_NOW']['rows']] == ['O-1', 'O-2'], bands['START_NOW']
    for r in rows:
        place(r)


@case('T10', '7.1 TODAY', 'every row renders WHY it is where it is, and the why names the rule')
def t10():
    rows = rows_of({'id': 'O-1', 'state': 'IN_PROGRESS', 'priority': 'READY'},
                   {'id': 'O-2', 'state': 'WAITING', 'priority': 'READY',
                    'waiting_for': 'user', 'wake_condition': 'reply'},
                   {'id': 'O-3', 'state': 'REVIEWED', 'priority': 'READY'})
    for band in cc.project(read_ok(), rows)['today']['bands']:
        for row in band['rows']:
            if 'headline' in row:
                continue
            assert row['why'].startswith('[B'), row
            assert row['rule'] in [r[0] for r in cc.BAND_RULES], row


@case('T11', '7.1 TODAY (2)', 'ควรเริ่มตอนนี้ is a SECTION - it holds the whole actionable top band')
def t11():
    rows = rows_of(*[{'id': 'O-%d' % i, 'state': 'READY', 'priority': 'DUE'} for i in range(9)])
    bands = dict((b['id'], b) for b in cc.project(read_ok(), rows)['today']['bands'])
    assert len(bands['START_NOW']['rows']) == 9, len(bands['START_NOW']['rows'])


@case('T12', '7.1 TODAY', 'no cap on actionable rows - all 9 red/orange rows survive the render')
def t12():
    rows = rows_of(*[{'id': 'O-%d' % i, 'state': 'READY', 'priority': 'REAL_MONEY_INCIDENT'}
                     for i in range(9)])
    bands = dict((b['id'], b) for b in cc.project(read_ok(), rows)['today']['bands'])
    assert bands['START_NOW']['hidden_count'] == 0, bands['START_NOW']
    assert len(bands['START_NOW']['rows']) == 9


@case('T13', '7.1 TODAY + 7.4', 'lower-priority ready work IS capped, with an explicit hidden count')
def t13():
    rows = rows_of(*[{'id': 'O-%02d' % i, 'state': 'READY', 'priority': 'READY'}
                     for i in range(10)])
    bands = dict((b['id'], b) for b in cc.project(read_ok(), rows)['today']['bands'])
    band = bands['READY']
    assert len(band['rows']) == cc.BAND_DISPLAY_CAP, len(band['rows'])
    assert band['hidden_count'] == 10 - cc.BAND_DISPLAY_CAP, band
    assert band['expand_all'] is True, band


@case('T14', '7.1 TODAY', 'an incomplete user-decision row renders the brief-not-ready label, not the question')
def t14():
    rows = rows_of({'id': 'O-1', 'state': 'READY', 'priority': 'USER_DECISION',
                    'decision': {'question': 'ควรลด lot ไหม'}})
    bands = dict((b['id'], b) for b in cc.project(read_ok(), rows)['today']['bands'])
    row = bands['NEEDS_YOU']['rows'][0]
    assert row['decision']['ready'] is False, row
    assert row['decision']['label'] == 'รอ Claude เตรียม decision brief', row
    assert set(row['decision']['missing']) == {'options', 'recommendation',
                                               'consequence_of_not_deciding'}, row


@case('T15', '7.1 TODAY', 'a COMPLETE user-decision row renders all four parts (the control for T14)')
def t15():
    rows = rows_of({'id': 'O-1', 'state': 'READY', 'priority': 'USER_DECISION',
                    'decision': {'question': 'q', 'options': ['a', 'b'],
                                 'recommendation': 'a', 'consequence_of_not_deciding': 'c'}})
    bands = dict((b['id'], b) for b in cc.project(read_ok(), rows)['today']['bands'])
    row = bands['NEEDS_YOU']['rows'][0]
    assert row['decision']['ready'] is True, row
    assert set(row['decision']['parts']) == set(cc.DECISION_PARTS), row


# =======================================================================================
# WORK
# =======================================================================================

@case('W01', '7.1 WORK', 'DONE is not closed - it normalises to DONE_PENDING_REVIEW and stays visible')
def w01():
    rows = rows_of({'id': 'O-1', 'state': 'DONE', 'priority': 'READY'})
    pages = cc.project(read_ok(), rows)
    assert len(pages['work']['by_state']['DONE_PENDING_REVIEW']) == 1, pages['work']['by_state']
    bands = dict((b['id'], b) for b in pages['today']['bands'])
    assert [r['id'] for r in bands['REVIEW_AUDIT']['rows']] == ['O-1'], bands['REVIEW_AUDIT']


@case('W02', '7.1 WORK', 'audit is a STAGE of the same row, never a second row')
def w02():
    rows = rows_of({'id': 'O-1', 'state': 'AUDIT_IN_PROGRESS', 'priority': 'READY',
                    'stage': 'AUDIT'})
    pages = cc.project(read_ok(), rows)
    rendered = [r for b in pages['today']['bands'] for r in b['rows'] if r.get('id') == 'O-1']
    assert len(rendered) == 1, rendered
    assert rendered[0]['stage']['label'] == 'AUDIT 2/2', rendered[0]


@case('W03', '7.1 WORK', 'rework escalates 1 -> same model, 2 -> stronger model, 3 -> REWORK LOOP')
def w03():
    got = []
    for cycles in (1, 2, 3):
        rows = rows_of({'id': 'O-1', 'state': 'REWORK', 'priority': 'READY',
                        'rework_cycles': cycles, 'repeated_defects': ['off-by-one']})
        row = [r for b in cc.project(read_ok(), rows)['today']['bands']
               for r in b['rows'] if r.get('id') == 'O-1'][0]
        got.append(row['rework']['route'])
    assert got == ['SAME_MODEL', 'STRONGER_MODEL', 'REWORK_LOOP'], got


@case('W04', '7.1 WORK', 'WAITING without a wake condition renders พักงานแบบไร้กำหนด')
def w04():
    rows = rows_of({'id': 'O-1', 'state': 'WAITING', 'priority': 'READY',
                    'waiting_for': 'the owner'})
    row = [r for b in cc.project(read_ok(), rows)['today']['bands']
           for r in b['rows'] if r.get('id') == 'O-1'][0]
    assert row['waiting']['ok'] is False, row
    assert row['waiting']['label'] == 'พักงานแบบไร้กำหนด — ต้องจัดการ', row


@case('W05', '7.1 WORK', 'WAITING WITH both fields renders normally (the control for W04)')
def w05():
    rows = rows_of({'id': 'O-1', 'state': 'WAITING', 'priority': 'READY',
                    'waiting_for': 'the owner', 'wake_condition': 'a reply on ORDER-1131'})
    row = [r for b in cc.project(read_ok(), rows)['today']['bands']
           for r in b['rows'] if r.get('id') == 'O-1'][0]
    assert row['waiting']['ok'] is True, row


@case('W06', '7.1 WORK', 'a claim with no heartbeat past 30 min is flagged - and is NOT cancelled or reassigned')
def w06():
    rows = rows_of({'id': 'O-1', 'state': 'IN_PROGRESS', 'priority': 'READY',
                    'heartbeat_age_min': cc.STALE_CLAIM_MINUTES + 1, 'claim_owner': 'codex'})
    pages = cc.project(read_ok(), rows)
    bands = dict((b['id'], b) for b in pages['today']['bands'])
    row = bands['STUCK']['rows'][0]
    assert row['id'] == 'O-1' and row['rule'] == 'B04', row
    # the row keeps its state and its owner: no auto-cancel, no reassign
    assert row['state'] == 'IN_PROGRESS', row
    assert len(pages['work']['by_state']['IN_PROGRESS']) == 1, pages['work']['by_state']
    assert len(pages['work']['by_state']['CANCELLED_BY_USER']) == 0


@case('W07', '7.1 WORK', 'a claim INSIDE 30 min is not flagged (the control for W06)')
def w07():
    rows = rows_of({'id': 'O-1', 'state': 'IN_PROGRESS', 'priority': 'READY',
                    'heartbeat_age_min': cc.STALE_CLAIM_MINUTES - 1})
    bands = dict((b['id'], b) for b in cc.project(read_ok(), rows)['today']['bands'])
    assert bands['STUCK']['rows'] == [], bands['STUCK']
    assert bands['START_NOW']['rows'][0]['rule'] == 'B11', bands['START_NOW']


@case('W08', '7.1 WORK', 'AGING/NEGLECTED do not exist - an input carrying one REFUSES, it is not bucketed')
def w08():
    assert 'AGING' not in cc.WORK_STATES and 'NEGLECTED' not in cc.WORK_STATES
    for bad in ('AGING', 'NEGLECTED'):
        try:
            cc.normalise_row({'id': 'O-1', 'state': bad})
        except cc.ShellRefusal:
            continue
        raise AssertionError('state %s was accepted' % bad)


@case('W13', 'round 2 · 7.1 WORK', 'a claim with NO heartbeat data does not render as one that HAS a heartbeat')
def w13():
    """
    ROUND-2: rule B11's text was 'กำลังทำอยู่อยู่และยังมี heartbeat', asserted from the ABSENCE of a
    heartbeat field. design 7.1's stuck label is for a claim with no heartbeat FOR >30 MIN; no
    data at all is a third thing, and it is the one this repo has paid for repeatedly.
    """
    rows = rows_of({'id': 'O-1', 'state': 'IN_PROGRESS', 'priority': 'READY'})
    row = [r for b in cc.project(read_ok(), rows)['today']['bands']
           for r in b['rows'] if r.get('id') == 'O-1'][0]
    assert 'heartbeat' not in row['why'], row['why']
    assert row['heartbeat']['known'] is False, row
    # control: a row that DOES carry a heartbeat says so, with the number
    rows = rows_of({'id': 'O-2', 'state': 'IN_PROGRESS', 'priority': 'READY',
                    'heartbeat_age_min': 5})
    row = [r for b in cc.project(read_ok(), rows)['today']['bands']
           for r in b['rows'] if r.get('id') == 'O-2'][0]
    assert row['heartbeat']['known'] is True and row['heartbeat']['age_min'] == 5, row


@case('W14', 'round 2 · blind audit F4', 'a PARTIAL row list beside a large count is UNKNOWN too, with both numbers')
def w14():
    """
    ROUND-2: W09 closed the zero-rows case and left the partial one open. One rendered row
    beside `discovered=334` produced unknown=False and an empty `why` - a page that looks like
    a queue of one. The gap is what must be visible, not the emptiness.
    """
    doc = snapshot()
    doc['meta']['reconciliation']['discovered'] = 334
    doc['meta']['reconciliation']['categorized'] = 306
    page = cc.project(read_ok(doc), rows_of({'id': 'O-1', 'state': 'READY',
                                             'priority': 'READY'}))['work']
    assert page['unknown'] is True, page
    assert '334' in page['why'] and '333' in page['why'], page['why']
    # control: rows that DO account for the count are not flagged
    doc2 = snapshot()
    doc2['meta']['reconciliation']['discovered'] = 1
    ok = cc.project(read_ok(doc2), rows_of({'id': 'O-1', 'state': 'READY',
                                            'priority': 'READY'}))['work']
    assert ok['unknown'] is False, ok


@case('W15', 'round 2 · 7.1 WORK', 'STATE_CONFLICT goes to ต้องการคุณ - a human decides, the page does not pick')
def w15():
    rows = rows_of({'id': 'O-1', 'state': 'STATE_CONFLICT', 'priority': 'READY'})
    bands = dict((b['id'], b) for b in cc.project(read_ok(), rows)['today']['bands'])
    assert [r['id'] for r in bands['NEEDS_YOU']['rows']] == ['O-1'], bands['NEEDS_YOU']
    assert bands['NEEDS_YOU']['rows'][0]['rule'] == 'B02', bands['NEEDS_YOU']['rows'][0]


@case('W16', 'round 2 · 7.1 WORK', 'BLOCKED and STARTED_BUT_STUCK both land in ติดขัด, by their own rules')
def w16():
    rows = rows_of({'id': 'O-1', 'state': 'BLOCKED', 'priority': 'READY'},
                   {'id': 'O-2', 'state': 'READY', 'priority': 'STARTED_BUT_STUCK'})
    bands = dict((b['id'], b) for b in cc.project(read_ok(), rows)['today']['bands'])
    got = dict((r['id'], r['rule']) for r in bands['STUCK']['rows'])
    assert got == {'O-1': 'B06', 'O-2': 'B05'}, got


@case('W09', 'blind audit F4', 'zero rows + a non-zero reconciliation renders UNKNOWN, never an empty queue')
def w09():
    doc = snapshot()
    doc['meta']['reconciliation']['discovered'] = 334
    doc['meta']['reconciliation']['categorized'] = 306
    page = cc.project(read_ok(doc))['work']
    assert page['unknown'] is True, page
    assert '334' in page['why'], page['why']
    assert page['counts']['discovered'] == 334


@case('W10', '7.1 WORK', 'unclassified and duplicate orders render as their own band, not swallowed')
def w10():
    doc = snapshot()
    doc['meta']['reconciliation']['unclassified'] = 28
    doc['meta']['reconciliation']['duplicates'] = 6
    band = cc.project(read_ok(doc))['work']['unclassified_band']
    assert band['shown'] is True and band['unclassified'] == 28 and band['duplicates'] == 6, band


@case('W11', '7.1 WORK', 'the lifecycle vocabulary is exactly design 7.1\'s 13 states')
def w11():
    expected = {'CAPTURED', 'READY', 'IN_PROGRESS', 'WAITING', 'BLOCKED', 'HANDOFF',
                'DONE_PENDING_REVIEW', 'AUDIT_REQUIRED', 'AUDIT_IN_PROGRESS', 'REWORK',
                'REVIEWED', 'CANCELLED_BY_USER', 'STATE_CONFLICT'}
    assert set(cc.WORK_STATES) == expected, set(cc.WORK_STATES) ^ expected


@case('W12', '7.1 WORK', 'a row no placement rule matches REFUSES - it is not hidden at the bottom')
def w12():
    saved = cc.BAND_RULES
    try:
        cc.BAND_RULES = tuple(r for r in saved if r[0] != 'B12')
        try:
            cc.project(read_ok(), rows_of({'id': 'O-1', 'state': 'READY', 'priority': 'READY'}))
        except cc.ShellRefusal as exc:
            assert 'matched no placement rule' in str(exc), exc
            return
        raise AssertionError('an unplaceable row was rendered instead of refused')
    finally:
        cc.BAND_RULES = saved


# =======================================================================================
# LIVE
# =======================================================================================

@case('L01', '7.1 LIVE', 'the LIVE bands are exception-first, with positions last')
def l01():
    ids = [b['id'] for b in cc.project(read_ok())['live']['bands']]
    assert ids == [b for b, _ in cc.LIVE_BANDS], ids
    assert ids[0] == 'RISK' and ids[-1] == 'POSITIONS', ids
    assert ids.index('NORMAL') > ids.index('GOVERNANCE'), ids


@case('L02', '7.1 LIVE', 'two detectors disagreeing on one account render CONFLICT, not a chosen side')
def l02():
    doc = snapshot()
    doc['system_health'] = [{'account': ACCOUNT_A, 'state': 'FRESH', 'age_hours': 1.0}]
    doc['floating_risk'] = [{'account': ACCOUNT_A, 'state': 'BLIND', 'magics': []}]
    band = [b for b in cc.project(read_ok(doc))['live']['bands'] if b['id'] == 'SENSOR'][0]
    assert band['rows'][0]['state'] == 'CONFLICT', band


@case('L03', '7.1 LIVE', 'an unrecognised sensor state REFUSES - it is never assumed healthy')
def l03():
    doc = snapshot(system_health=[{'account': ACCOUNT_A, 'state': 'PROBABLY_FINE'}])
    try:
        cc.project(read_ok(doc))
    except cc.ShellRefusal as exc:
        assert 'PROBABLY_FINE' in str(exc), exc
        return
    raise AssertionError('an unknown sensor state was rendered')


@case('L04', '7.1 LIVE', 'this page computes no drawdown: a detector-supplied band travels, absence is UNKNOWN')
def l04():
    doc = snapshot()
    doc['floating_risk'][0]['dd_band'] = 'BREACH'
    band = [b for b in cc.project(read_ok(doc))['live']['bands'] if b['id'] == 'RISK'][0]
    assert band['rows'][0]['state'] == 'BREACH', band
    # control: the same account with equity and balance present but NO band produces no risk row
    plain = [b for b in cc.project(read_ok())['live']['bands'] if b['id'] == 'RISK'][0]
    assert plain['rows'] == [], plain


@case('L05', '7.1 LIVE', 'positions are collapsed by default and carry a count only')
def l05():
    band = [b for b in cc.project(read_ok())['live']['bands'] if b['id'] == 'POSITIONS'][0]
    assert band['rows'][0]['collapsed'] is True and band['rows'][0]['count'] == 5, band


@case('L06', '7.1 LIVE', 'an active unknown magic and a governance gap are exceptions, and are counted')
def l06():
    doc = snapshot()
    doc['unknown_magics'] = [{'account': ACCOUNT_A, 'magic': '511', 'age_class': 'ACTIVE'},
                             {'account': ACCOUNT_A, 'magic': '512', 'age_class': 'HISTORICAL'}]
    doc['deployments']['gaps']['missing_judge'] = ['a', 'b']
    live = cc.project(read_ok(doc))['live']
    drift = [b for b in live['bands'] if b['id'] == 'DRIFT'][0]
    gov = [b for b in live['bands'] if b['id'] == 'GOVERNANCE'][0]
    assert len(drift['rows']) == 1, drift          # HISTORICAL is not an exception
    assert gov['rows'][0]['count'] == 2, gov
    assert live['exception_count'] == 2, live['exception_count']


# =======================================================================================
# SYSTEM
# =======================================================================================

@case('S01', '7.1 SYSTEM', 'one healthy check is HEALTHY_1_OF_2, not RESOLVED')
def s01():
    got = cc.fold_finding({'id': 'F1', 'class': 'RUNTIME', 'healthy_streak': 1})
    assert got['state'] == 'HEALTHY_1_OF_2', got


@case('S02', '7.1 SYSTEM', 'two consecutive healthy checks resolve a RUNTIME finding')
def s02():
    got = cc.fold_finding({'id': 'F1', 'class': 'RUNTIME', 'healthy_streak': 2,
                           'previous_state': 'OPEN'})
    assert got['state'] == 'RESOLVED' and got['recovery_emitted'] is True, got


@case('S03', '7.1 SYSTEM', 'a governance finding does NOT auto-resolve even after two healthy checks')
def s03():
    got = cc.fold_finding({'id': 'F1', 'class': 'GOVERNANCE', 'healthy_streak': 2})
    assert got['state'] == 'OPEN' and got['needs_explicit_review'] is True, got


@case('S04', '7.1 SYSTEM', '3 recurrences in 24h collapse into ONE FLAPPING - root cause required')
def s04():
    got = cc.fold_finding({'id': 'F1', 'class': 'RUNTIME', 'occurrences_24h': 3,
                           'healthy_streak': 0})
    assert got['state'] == 'FLAPPING', got
    assert got['label'] == 'FLAPPING — root cause required', got
    assert got['collapsed_from'] == 3, got


@case('S05', '7.3 notifications', 'OPEN -> HEALTHY_1_OF_2 -> OPEN emits NO recovery message')
def s05():
    mid = cc.fold_finding({'id': 'F1', 'class': 'RUNTIME', 'healthy_streak': 1,
                           'previous_state': 'OPEN'})
    back = cc.fold_finding({'id': 'F1', 'class': 'RUNTIME', 'healthy_streak': 0,
                            'previous_state': 'HEALTHY_1_OF_2'})
    assert mid['recovery_emitted'] is False and back['recovery_emitted'] is False, (mid, back)
    assert back['state'] == 'OPEN', back


@case('S06', '7.1 SYSTEM', 'an unrecognised finding class REFUSES')
def s06():
    try:
        cc.fold_finding({'id': 'F1', 'class': 'SOMETHING_NEW'})
    except cc.ShellRefusal:
        return
    raise AssertionError('an unknown finding class was folded')


# =======================================================================================
# Prohibitions (design 10, S11 row)
# =======================================================================================

@case('P01', '10 S11 prohibition', 'the shell exposes no dispatch, claim or closure verb')
def p01():
    # Every public CALLABLE the shell offers - a verb is a callable, and the prohibition is
    # about verbs. Imported modules are excluded; the closed constants above are data, and
    # each is asserted by its own case (W11, T08, L01).
    public = set(n for n in dir(cc) if not n.startswith('_')
                 and callable(getattr(cc, n))
                 and not isinstance(getattr(cc, n), type(cc)))
    declared = set(cc.PUBLIC_API)
    assert public == declared, 'undeclared public names: %s' % sorted(public ^ declared)
    for name in declared:
        for verb in cc.FORBIDDEN_VERBS:
            assert verb not in name.lower(), '%s contains the forbidden verb %s' % (name, verb)


@case('P02', '10 S11 prohibition', 'project() writes nothing - it refuses to work if the filesystem is taken away')
def p02():
    import builtins
    real_open, real_io_open = builtins.open, io.open

    def boom(*a, **k):
        raise AssertionError('project() touched the filesystem')
    builtins.open = boom
    io.open = boom
    try:
        cc.project(read_ok(), rows_of({'id': 'O-1', 'state': 'READY', 'priority': 'READY'}))
    finally:
        builtins.open, io.open = real_open, real_io_open


# =======================================================================================
# SafeProjection - the NEGATIVE acceptance. Fixtures first, then the control.
# =======================================================================================

def leaky_projection():
    """What a careless future author builds: shaped like a projection, three levels deep."""
    return {
        'entity': 'SafeProjection',
        'build_id': 'b0000000000000ff',
        'generated_at': '2026-08-02T00:00:00',
        'accounts': [{'account_masked': '***454', 'sensor_state': 'FRESH',
                      'dd_pct_band': 'UNKNOWN',
                      'detail': {'sensor': {'source_account': PLANTED_ACCOUNT}}}],
        'findings': [{'public_id': 'FP-0123456789', 'severity': 'WARN', 'state': 'OPEN'}],
    }


@case('SP01', 'S11 acceptance', 'the scan CATCHES an account number nested three levels down')
def sp01():
    hits = fired(sp.scan_forbidden(leaky_projection(), known_secrets=[PLANTED_ACCOUNT]))
    assert hits, 'the planted account was not found'
    paths = [h[0] for h in hits]
    assert any(p.count('.') >= 3 for p in paths), paths
    assert any(h[1] == 'KNOWN_SECRET' for h in hits), hits


@case('SP02', 'S11 acceptance', 'a TOP-LEVEL-ONLY scan misses that same fixture - which is why it is recursive')
def sp02():
    doc = leaky_projection()
    shallow = [k for k in doc if k in sp.FORBIDDEN_KEYS
               or (isinstance(doc[k], str) and PLANTED_ACCOUNT in doc[k])]
    assert shallow == [], shallow
    assert sp.scan_forbidden(doc, known_secrets=[PLANTED_ACCOUNT]), 'the recursive scan found nothing'


@case('SP03', 'S11 acceptance', 'a forbidden KEY inside a list of objects is caught at any depth')
def sp03():
    doc = leaky_projection()
    doc['accounts'][0]['balance'] = 7761.56
    hits = fired(sp.scan_forbidden(doc))
    assert any(h[1] == 'FORBIDDEN_KEY' and 'balance' in h[2] for h in hits), hits


@case('SP04', 'S11 acceptance', 'a planted Telegram bot token is caught by shape, wherever it sits')
def sp04():
    doc = leaky_projection()
    doc['findings'][0]['state'] = 'OPEN ' + PLANTED_TOKEN
    hits = fired(sp.scan_forbidden(doc))
    assert any(h[1] == 'TELEGRAM_BOT_TOKEN' for h in hits), hits


@case('SP05', 'S11 acceptance', 'every declared value rule fires on a planted value of its own shape')
def sp05():
    doc = leaky_projection()
    doc['accounts'][0]['note'] = r'D:\EA_LAB\portfolio\control_room_snapshot.json'
    doc['accounts'][0]['share'] = r'\\vps-01\deploy\Boss_14.ex5'
    doc['findings'][0]['hint'] = 'api_key: abc123'
    doc['findings'][0]['cert'] = '-----BEGIN RSA PRIVATE KEY-----\nMIIE...'
    hits = fired(sp.scan_forbidden(doc))
    kinds = set(h[1] for h in hits)
    # Named one by one on purpose: "the scan found something" is what lets a fixture get
    # credited to a rule it never reached.
    for rule in ('WINDOWS_ABSOLUTE_PATH', 'UNC_PATH', 'CREDENTIAL_ASSIGNMENT', 'PEM_BLOCK'):
        assert rule in kinds, '%s did not fire: %s' % (rule, kinds)


@case('SP06', 'S11 acceptance', 'the raw finding_id may not travel - the key is forbidden by name')
def sp06():
    doc = leaky_projection()
    doc['findings'][0]['finding_id'] = 'DD-159503454-990101'
    hits = fired(sp.scan_forbidden(doc))
    assert any(h[1] == 'FORBIDDEN_KEY' and 'finding_id' in h[2] for h in hits), hits


@case('SP07', 'S11 acceptance', 'assert_safe RAISES and names every hit, rather than returning a flag')
def sp07():
    doc = leaky_projection()
    doc['accounts'][0]['balance'] = 1.0
    try:
        sp.assert_safe(doc, known_secrets=[PLANTED_ACCOUNT])
    except sp.ProjectionLeak as exc:
        assert 'balance' in str(exc) and PLANTED_ACCOUNT in str(exc), exc
        return
    raise AssertionError('a leaking document was accepted')


@case('SP08', 'S11 control', 'the projection BUILT from a poisoned snapshot carries none of it')
def sp08():
    doc = snapshot()
    doc['system_health'][0]['latest_file'] = r'D:\EA_LAB\deals_%s.csv' % ACCOUNT_A
    doc['floating_risk'][0]['note'] = PLANTED_TOKEN
    doc['deployments']['rows'] = [{'account': ACCOUNT_A, 'ea_name': 'Boss_14_GridLog',
                                   'magic': '990101', 'symbol': 'XAUUSD'}]
    projection = sp.build(doc)
    blob = json.dumps(projection)
    for secret in (ACCOUNT_A, PLANTED_TOKEN, 'Boss_14_GridLog', '990101', 'XAUUSD', '7761.56'):
        assert secret not in blob, secret
    assert sp.scan_forbidden(projection, sp.secrets_of(doc)) == []


@case('SP09', 'S11 control', 'the scan is silent on the real projection - it is not always-red')
def sp09():
    projection = sp.build(snapshot())
    assert sp.scan_forbidden(projection, sp.secrets_of(snapshot())) == []


@case('SP10', 'schemas.json', 'an account that cannot be masked REFUSES rather than being dropped')
def sp10():
    for bad in (None, '12', ''):
        doc = snapshot(system_health=[{'account': bad, 'state': 'FRESH'}])
        try:
            sp.build(doc)
        except sp.ProjectionRefusal:
            continue
        raise AssertionError('account %r produced a projection' % bad)
    assert sp.mask_account('159503454') == '***454'


@case('SP11', 'S11 rule 1', 'an unrecognised sensor state or reason code REFUSES the build')
def sp11():
    try:
        sp.build(snapshot(system_health=[{'account': ACCOUNT_A, 'state': 'PROBABLY_FINE'}]))
        raise AssertionError('an unknown sensor state was projected')
    except sp.ProjectionRefusal:
        pass
    doc = snapshot(verdict={'reconciliation_clear': False,
                            'reasons': [{'code': 'A_NEW_CODE', 'detail': 'x'}]})
    try:
        sp.build(doc)
    except sp.ProjectionRefusal:
        return
    raise AssertionError('an unknown reason code was projected as some severity')


@case('SP12', '7.1 LIVE', 'a detector-supplied dd band travels; with none, the band is UNKNOWN')
def sp12():
    doc = snapshot()
    doc['floating_risk'][0]['dd_band'] = 'WATCH'
    assert sp.build(doc)['accounts'][0]['dd_pct_band'] == 'WATCH'
    assert sp.build(snapshot())['accounts'][0]['dd_pct_band'] == 'UNKNOWN'


@case('SP14', 'round 1 · S11 acceptance', 'the projection lists EVERY account either detector knows, never the intersection')
def sp14():
    """
    ROUND-1, the same blocker on the projection side: `accounts` was built by walking
    system_health alone, so an account the health detector has never seen was absent from the
    masked list entirely. A list that omits an account is worse than one that says UNKNOWN,
    because the reader counts it.
    """
    doc = snapshot()
    doc['system_health'] = [{'account': ACCOUNT_A, 'state': 'FRESH'}]
    doc['floating_risk'] = [{'account': ACCOUNT_A, 'state': 'FRESH', 'magics': []},
                            {'account': ACCOUNT_B, 'state': 'BLIND', 'magics': []}]
    projection = sp.build(doc)
    masked = dict((a['account_masked'], a) for a in projection['accounts'])
    assert sp.mask_account(ACCOUNT_B) in masked, masked
    # and its sensor state is UNKNOWN, not defaulted to something healthy-looking
    assert masked[sp.mask_account(ACCOUNT_B)]['sensor_state'] == 'UNKNOWN', masked
    assert masked[sp.mask_account(ACCOUNT_A)]['sensor_state'] == 'FRESH', masked


@case('SP15', 'round 1 · drift', 'REASON_SEVERITY covers the closed reason-code enum EXACTLY, both ways')
def sp15():
    """
    build() refuses an unmapped reason code, which is the right direction - but it means a code
    ADDED to schemas.json turns every real snapshot carrying it into a refusal, discovered in
    production rather than here. snapshot_validator asserts its own predicate set against this
    same enum for the same reason.
    """
    with io.open(os.path.join(REPO, sv.SCHEMA_PATH), encoding='utf-8-sig') as fh:
        schema = json.load(fh)
    enum = set(schema['$defs']['SnapshotVerdict']['properties']['reasons']['items']
               ['properties']['code']['enum'])
    mine = set(sp.REASON_SEVERITY)
    assert enum == mine, 'schema-only=%s  map-only=%s' % (sorted(enum - mine), sorted(mine - enum))


@case('SP13', '7.3 dedupe', 'public ids are opaque, stable across builds, and differ per finding')
def sp13():
    a = sp.public_id('MANDATORY_SOURCE_STALE|attestation_map')
    b = sp.public_id('MANDATORY_SOURCE_STALE|attestation_map')
    c = sp.public_id('MANDATORY_SOURCE_STALE|live_dashboard')
    assert a == b and a != c, (a, b, c)
    assert a.startswith('FP-') and len(a) == 13, a
    assert 'attestation_map' not in a


# =======================================================================================
# The sender boundary - "Telegram must not be able to read the full snapshot"
# =======================================================================================

@case('SB01', '10 S11 prohibition', 'the sender is REFUSED the full snapshot, by path')
def sb01():
    try:
        sp.read_for_sender(os.path.join(REPO, sp.SNAPSHOT_REL), repo_root=REPO)
    except sp.ProjectionRefusal as exc:
        assert 'may read only' in str(exc), exc
        return
    raise AssertionError('the sender read the full snapshot')


def sandbox(document, with_schema=True):
    """A throwaway repo root holding just the projection (and, unless told not to, the schema
    the shape check reads). Returns (root, projection_path); the caller removes the root."""
    root = tempfile.mkdtemp(prefix='s11_')
    out = os.path.join(root, sp.PROJECTION_REL.replace('/', os.sep))
    os.makedirs(os.path.dirname(out))
    with io.open(out, 'w', encoding='utf-8') as fh:
        fh.write(json.dumps(document))
    if with_schema:
        dest = os.path.join(root, sv.SCHEMA_PATH.replace('/', os.sep))
        os.makedirs(os.path.dirname(dest))
        shutil.copyfile(os.path.join(REPO, sv.SCHEMA_PATH), dest)
    return root, out


@case('SB02', '10 S11 prohibition', 'the sender reads the projection at the pinned path (the control)')
def sb02():
    root, out = sandbox(sp.build(snapshot()))
    try:
        doc = sp.read_for_sender(out, repo_root=root)
        assert doc['entity'] == 'SafeProjection', doc
    finally:
        shutil.rmtree(root, ignore_errors=True)


@case('SB03', '10 S11 prohibition', 'a leaking document AT the pinned path is still refused - the sender checks the SHAPE')
def sb03():
    """
    RED ON THE FIRST RUN, and the finding is recorded in safe_projection._check_shape: the
    sender's scan cannot see a raw account number, because the sender has no snapshot to
    derive the known-secret list from. The prohibition disarms the check. An allowlist on the
    SHAPE is what closes it; a longer list of forbidden field names never would.
    """
    # This fixture carries the planted account THREE LEVELS DOWN, inside a field nobody
    # blacklisted, and it is refused for being undeclared rather than for being recognised.
    root, out = sandbox(leaky_projection())
    try:
        try:
            sp.read_for_sender(out, repo_root=root)
        except sp.ProjectionLeak as exc:
            assert 'is not declared' in str(exc), exc
            return
        raise AssertionError('the sender handed over a leaking document because of its path')
    finally:
        shutil.rmtree(root, ignore_errors=True)


@case('SB05', 'schemas.json', 'the shape check is READ from schemas.json, and the real build passes it')
def sb05():
    # The allowlist is not a hand-copied mirror: it is the schema's own declaration, so the
    # two cannot drift. If schemas.json cannot be read, the sender REFUSES rather than waving
    # the document through.
    sp.assert_shape(sp.build(snapshot()), repo_root=REPO)
    for bad, why in (({'entity': 'SafeProjection', 'build_id': 'b', 'generated_at': 'g',
                       'accounts': [], 'findings': [], 'extra': 1}, 'an undeclared top-level key'),
                     ({'entity': 'SafeProjection', 'build_id': 'b', 'generated_at': 'g',
                       'accounts': [{'account_masked': '159503454', 'sensor_state': 'FRESH',
                                     'dd_pct_band': 'OK'}], 'findings': []},
                      'an unmasked account in a declared field'),
                     ({'entity': 'SafeProjection', 'build_id': 'b', 'generated_at': 'g',
                       'accounts': [], 'findings': [{'public_id': 'DD-159503454',
                                                     'severity': 'WARN', 'state': 'OPEN'}]},
                      'a raw finding id where the FP- pattern is required')):
        try:
            sp.assert_shape(bad, repo_root=REPO)
        except sp.ProjectionLeak:
            continue
        raise AssertionError('%s was accepted' % why)


@case('SB06', 'S11 rule 1', 'a sender that cannot read the shape REFUSES - it does not send unchecked')
def sb06():
    # Same document, same path, same everything - EXCEPT that the shape cannot be read.
    # The control is SB02, which is this call with the schema present.
    root, out = sandbox(sp.build(snapshot()), with_schema=False)
    try:
        try:
            sp.read_for_sender(out, repo_root=root)
        except sp.ProjectionRefusal as exc:
            assert 'could not be read' in str(exc), exc
            return
        raise AssertionError('a document was released without its shape being checked')
    finally:
        shutil.rmtree(root, ignore_errors=True)


@case('SB04', '10 S11 prohibition', 'the allowed-path list is a CLOSED declaration of exactly one path')
def sb04():
    assert sp.SENDER_ALLOWED_PATHS == (sp.PROJECTION_REL,), sp.SENDER_ALLOWED_PATHS
    for near_miss in ('build/safe_projection.json.bak', 'build/../portfolio/control_room_snapshot.json',
                      'portfolio/control_room_snapshot.json'):
        try:
            sp.read_for_sender(os.path.join(REPO, near_miss), repo_root=REPO)
        except sp.ProjectionRefusal:
            continue
        raise AssertionError('%s was allowed' % near_miss)


# =======================================================================================
# The two runs that make a claim the in-process cases cannot.
# =======================================================================================

@case('WIRE1', 'S11 wiring', 'the shell renders from the REAL snapshot through the ONE reader')
def wire1():
    path = os.path.join(REPO, sp.SNAPSHOT_REL)
    doc = sv.load_verified(path)                       # raises if the real document is refused
    read = cc.SnapshotRead(cc.READ_OK, 'OK', '', doc)
    pages = cc.project(read, [], [])
    html = cc.render_html(pages)
    assert 'SHADOW MODE' in html, 'the shell did not render its mode'
    for tab in ('TODAY', 'WORK', 'LIVE', 'SYSTEM'):
        assert '>%s<' % tab in html, tab
    assert pages['today']['health']['headline'] in ('ALL CLEAR', 'ATTENTION'), pages['today']['health']
    # ROUND-2 FIX: this used to assert `work.unknown is True`, which pins TODAY'S emptiness of
    # factory/work_receipts.jsonl. The day S14 imports one receipt it would go red for a reason
    # that is not a defect. Assert the RULE against the same document instead - it holds
    # whatever the store contains, and it still fails if the rule stops being applied.
    rendered = sum(len(v) for v in pages['work']['by_state'].values())
    discovered = pages['work']['counts']['discovered'] or 0
    assert pages['work']['unknown'] == (rendered < discovered), (rendered, discovered,
                                                                 pages['work']['unknown'])


@case('WIRE2', 'S11 wiring', 'the projection built from the real snapshot validates against schemas.json')
def wire2():
    doc = sv.load_verified(os.path.join(REPO, sp.SNAPSHOT_REL))
    projection = sp.build(doc)
    sv.ajv_schema_validator(projection, sp.ENTITY)     # raises if ajv refuses it
    assert sp.scan_forbidden(projection, sp.secrets_of(doc)) == [], 'the REAL projection leaks'


# ---------------------------------------------------------------------------------------
# Roll-ups
# ---------------------------------------------------------------------------------------

def rollups(ran, by_cases, by_probe):
    """
    ROUND-2 FIX, and the finding is about this function. R1 used to be computed AFTER main()
    appended thirteen purpose-built rows that fire every placement rule, so it was green no
    matter which scenarios existed -- a roll-up that could not fail, guarding against rules
    that have a comment and no attack. It was hiding exactly that: THREE rules (B02, B05, B06)
    were reached by no catalogued case at all.

    The two claims are now separated, because they are different claims:
      R1  every rule is fired BY A CATALOGUED SCENARIO  -- coverage, and it can go red.
      R4  every rule is reachable at all                -- a dead rule, weaker and still worth
                                                           having, driven by the probe rows.
    (memory: pf5th-bar-cannot-fail-under-current-mc)
    """
    problems = []
    declared = set(r[0] for r in cc.BAND_RULES)
    if declared - by_cases:
        problems.append('R1 placement rules no CATALOGUED SCENARIO fires: %s'
                        % ', '.join(sorted(declared - by_cases)))
    if declared - by_probe:
        problems.append('R4 placement rules that are unreachable even by a purpose-built row '
                        '(a dead rule): %s' % ', '.join(sorted(declared - by_probe)))
    layers = set(['FORBIDDEN_KEY', 'KNOWN_SECRET'] + [r[0] for r in sp.FORBIDDEN_VALUE_RULES])
    if layers - FIRED_SCAN:
        problems.append('R2 scan layers with ZERO fires (a guard with zero fires is UNTESTED): %s'
                        % ', '.join(sorted(layers - FIRED_SCAN)))
    declared_cases = set(c[0] for c in CASES)
    if declared_cases - ran:
        problems.append('R3 catalog cases that did not run: %s'
                        % ', '.join(sorted(declared_cases - ran)))
    return problems


def main(argv):
    if '--list' in argv:
        for cid, clause, title, _fn in CASES:
            print('%-6s %-22s %s' % (cid, clause, title))
        print('%d scenario(s) in the catalog' % len(CASES))
        return 0
    failed = []
    ran = set()
    for cid, clause, title, fn in CASES:
        try:
            fn()
            ran.add(cid)
            print('  ok   %-6s %s' % (cid, title))
        except Exception as exc:                        # noqa: BLE001 - a failure is the output
            ran.add(cid)
            failed.append((cid, title, '%s: %s' % (type(exc).__name__, exc)))
            print('  FAIL %-6s %s\n         %s: %s' % (cid, title, type(exc).__name__, exc))

    # Snapshot what the CATALOGUED SCENARIOS fired, BEFORE the probe rows below add to it.
    # Taking this line out is what made R1 unfalsifiable for a whole slice.
    by_cases = set(FIRED_RULES)

    # Purpose-built rows, one per placement rule. These feed R4 (is the rule reachable at all)
    # and deliberately NOT R1 (does a scenario exercise it).
    for row in (
        {'id': 'X1', 'state': 'STATE_CONFLICT', 'priority': 'READY'},
        {'id': 'X2', 'state': 'READY', 'priority': 'USER_DECISION'},
        {'id': 'X3', 'state': 'READY', 'priority': 'STARTED_BUT_STUCK'},
        {'id': 'X4', 'state': 'BLOCKED', 'priority': 'READY'},
        {'id': 'X5', 'state': 'HANDOFF', 'priority': 'READY'},
        {'id': 'X6', 'state': 'WAITING', 'priority': 'READY'},
        {'id': 'X7', 'state': 'CAPTURED', 'priority': 'READY'},
        {'id': 'X8', 'state': 'REVIEWED', 'priority': 'READY'},
        {'id': 'X9', 'state': 'IN_PROGRESS', 'priority': 'READY'},
        {'id': 'XA', 'state': 'READY', 'priority': 'REAL_MONEY_INCIDENT'},
        {'id': 'XB', 'state': 'READY', 'priority': 'BLOCKING_OTHER_WORK'},
        {'id': 'XC', 'state': 'READY', 'priority': 'DUE'},
        {'id': 'XD', 'state': 'IN_PROGRESS', 'priority': 'READY',
         'heartbeat_age_min': cc.STALE_CLAIM_MINUTES + 1},
    ):
        place(row)

    problems = rollups(ran, by_cases, set(FIRED_RULES))
    for p in problems:
        print('  FAIL %s' % p)
    total = len(CASES)
    print('[s11] %d scenario(s), %d failed, %d roll-up problem(s)'
          % (total, len(failed), len(problems)))
    return 1 if (failed or problems) else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
