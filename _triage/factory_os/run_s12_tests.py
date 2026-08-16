"""
run_s12_tests.py - the cage for ORDER-1180 (slice S12), the direct Telegram sender.

THE SHAPE THIS SUITE IS BUILT IN, AND WHY
  design 10 leaves the fast tier ~8s of headroom, so the rule S10 and S11 both paid for applies:
  make the cage cheaper to DRIVE, not cheaper to CARE. Everything below runs in ONE process
  against fixtures, and exactly THREE subprocesses exist - for the one claim in-process code
  cannot honestly make: that the delivery ledger stops a second send ACROSS PROCESS BOUNDARIES,
  which is the only form of "not sent twice" that means anything to a scheduled job.

WHAT IS BEING CAGED, in the acceptance's own words (design 10, S12 row)
  1. alerts work with OpenClaw stopped        cases O01-O06
  2. dedupe includes severity AND material_revision   cases D01-D05, and ESCALATION is D02
  3. a per-channel delivery ledger            cases L01-L06
  4. one recovery, escalation never swallowed cases V01-V04 (+ D02)

THE NEGATIVES ARE THE PRODUCT
  Every leak case (S02-S08) plants something and watches it be caught. A scan that finds nothing
  on a clean document proves nothing, and a guard with zero fires is UNTESTED by CLAUDE.md's own
  bar table - which is how S11's PEM_BLOCK and UNC_PATH rules were caught having never fired.

TWO ROLL-UPS, NOT ONE
  COVERAGE   every routing target, every event kind, every delivery outcome and every scan layer
             was produced by a REAL case.
  REACHABILITY  every catalogued case ran.
  They are two claims, so they are two roll-ups (memory: completeness-rollup-measured-after-topup),
  and coverage prints WHICH case first hit each bucket - so a bucket whose only contributor is a
  case that exists for no other reason is visible in the output rather than hidden behind a tick.

RUN  tools\\python312\\python.exe _triage/factory_os/run_s12_tests.py
"""
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)

import control_center                                        # noqa: E402
import notifier                                              # noqa: E402
import run_schema_fixtures as schema_fixtures                # noqa: E402
import safe_projection                                       # noqa: E402
import snapshot_validator                                    # noqa: E402

PY = sys.executable

# `deliver()`'s `known_secrets` is a REQUIRED positional as of the ORDER-1261 review: an
# independent read of that repair measured that a default made the new scan inert for exactly the
# public caller it claimed to protect. Cases that are not ABOUT the literal layer declare the
# sentinel here rather than passing a list, which is the same statement they were making before
# by omission -- except that now it is a statement.
SENT = safe_projection.NO_KNOWN_SECRETS_AVAILABLE

# Pin this suite's own output, for the reason notifier._pin_utf8 documents at length: a child of
# the pre-commit hook gets an ANSI-codepage pipe, the first Thai character raises
# UnicodeEncodeError, and the wrapper reports `exit -1 SUITE THREW` with the cause invisible.
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding='utf-8', errors='replace')
    except (AttributeError, ValueError):
        pass

# The environment every subprocess in this suite inherits. Deliberately NOT os.environ verbatim:
# the point of case C01 is to launch the CLI into a codepage that BREAKS an unpinned python, so
# the encoding a child gets has to be something this suite decides, not something it inherits.
CHILD_ENV = dict(os.environ)
CHILD_ENV['PYTHONIOENCODING'] = 'utf-8'

CASES = []
FAILED = []
RAN = []

# COVERAGE buckets. Every one must be hit by a real case; the case that first hit it is recorded
# so the roll-up can PRINT its provenance instead of asserting a number nobody can trace.
COVERAGE = {
    'routing:EMERGENCY': None, 'routing:CONTROL_ROOM': None, 'routing:REFUSED': None,
    'kind:ALERT': None, 'kind:RECOVERY': None, 'kind:MORNING_BRIEF': None,
    'kind:DELIVERY_PROBE': None,
    'outcome:DELIVERED': None, 'outcome:SUPPRESSED_DUPLICATE': None,
    'outcome:UNCONFIGURED': None, 'outcome:FAILED': None,
    'scan:SHAPE': None, 'scan:KNOWN_SECRET': None, 'scan:WINDOWS_ABSOLUTE_PATH': None,
    'scan:TELEGRAM_BOT_TOKEN': None, 'scan:SHAPE_INTEGER': None,
    'openclaw:RUNNING': None, 'openclaw:NOT_RUNNING': None, 'openclaw:UNKNOWN': None,
}
_current = [None]


def hit(bucket):
    if bucket not in COVERAGE:
        raise AssertionError('unknown coverage bucket %r - the bucket list is closed so a typo '
                             'cannot silently create a bucket nothing ever checks' % bucket)
    if COVERAGE[bucket] is None:
        COVERAGE[bucket] = _current[0]


def case(cid, what):
    def deco(fn):
        CASES.append((cid, what, fn))
        return fn
    return deco


def run_all():
    for cid, what, fn in CASES:
        _current[0] = cid
        RAN.append(cid)
        try:
            fn()
            print('  ok   %-6s %s' % (cid, what))
        except Exception as exc:                             # noqa: BLE001 - the point of a cage
            FAILED.append((cid, what, exc))
            print('  FAIL %-6s %s\n         %s: %s' % (cid, what, type(exc).__name__, exc))


def eq(got, want, msg=''):
    if got != want:
        raise AssertionError('%s\n    got  %r\n    want %r' % (msg, got, want))


def refuses(fn, needle='', kinds=(notifier.NotifyRefusal, safe_projection.ProjectionRefusal,
                                  control_center.ShellRefusal)):
    try:
        fn()
    except kinds as exc:
        if needle and needle.lower() not in str(exc).lower():
            raise AssertionError('refused, but not for the reason under test: %r missing from %s'
                                 % (needle, exc))
        return str(exc)
    raise AssertionError('did NOT refuse, which means the unhandled case rendered as the '
                         'satisfied one - the shape all six S11 defects had')


# ---------------------------------------------------------------------------------------
# Fixtures. A finding record is what observe() produces; building them by hand here keeps the
# routing/dedupe cases independent of the snapshot's current contents.
# ---------------------------------------------------------------------------------------

def rec(severity='WARN', state='OPEN', revision=0, cls='RUNTIME', pid='FP-0123456789',
        recovery=False):
    return {'public_id': pid, 'severity': severity, 'state': state, 'class': cls,
            'material_revision': revision, 'recovery_emitted': recovery}


_SNAPSHOT = []


def real_snapshot():
    """
    The verified snapshot, loaded ONCE for the whole suite.

    load_verified() costs ~0.3s a call (it shells out to validate against schemas.json), and
    three cases want the same document. Caching it is the S10/S11 rule applied to this suite:
    make the cage cheaper to DRIVE, not cheaper to CARE - no case is dropped, the document is
    just not re-read three times. The subprocess cases still load it themselves, which is the
    point of them.
    """
    if not _SNAPSHOT:
        _SNAPSHOT.append(snapshot_validator.load_verified(
            os.path.join(ROOT, safe_projection.SNAPSHOT_REL)))
    return _SNAPSHOT[0]


PROJECTION = {
    'entity': 'SafeProjection', 'build_id': 'b-s12', 'generated_at': '2026-08-02T00:00:00',
    'accounts': [{'account_masked': '***454', 'sensor_state': 'FRESH', 'dd_pct_band': 'UNKNOWN'},
                 {'account_masked': '***881', 'sensor_state': 'STALE', 'dd_pct_band': 'UNKNOWN'}],
    'findings': [{'public_id': 'FP-0123456789', 'severity': 'WARN', 'state': 'OPEN'}],
}


# =======================================================================================
# ROUTING - the owner's table, and what happens to a severity that is not on it.
# =======================================================================================

@case('R01', 'REAL_MONEY routes to the emergency bot')
def _r01():
    ev = notifier.plan([rec(severity='REAL_MONEY')], PROJECTION)
    eq([e['channel'] for e in ev], ['EMERGENCY'], 'real money must wake somebody')
    hit('routing:EMERGENCY')
    hit('kind:ALERT')


@case('R02', 'CRITICAL routes to the emergency bot (the owner ratified the design-literal split)')
def _r02():
    ev = notifier.plan([rec(severity='CRITICAL')], PROJECTION)
    eq([e['channel'] for e in ev], ['EMERGENCY'], '')


@case('R03', 'WARN routes to the Control Room bot')
def _r03():
    ev = notifier.plan([rec(severity='WARN')], PROJECTION)
    eq([e['channel'] for e in ev], ['CONTROL_ROOM'], '')
    hit('routing:CONTROL_ROOM')


@case('R04', 'INFO routes to the Control Room bot')
def _r04():
    eq([e['channel'] for e in notifier.plan([rec(severity='INFO')], PROJECTION)],
       ['CONTROL_ROOM'], '')


@case('R05', 'a severity with no channel REFUSES; it is never dropped quietly')
def _r05():
    refuses(lambda: notifier.plan([rec(severity='NOISY')], PROJECTION), 'routing table')
    hit('routing:REFUSED')


@case('R06', 'REASON_SEVERITY and REASON_CLASS cover exactly the same reason codes')
def _r06():
    notifier.assert_reason_maps_agree()
    eq(set(notifier.REASON_CLASS), set(safe_projection.REASON_SEVERITY), '')


@case('R07', 'the maps-agree check can actually FAIL (a guard with zero fires is UNTESTED)')
def _r07():
    saved = dict(notifier.REASON_CLASS)
    try:
        notifier.REASON_CLASS.pop('DUPLICATES_PRESENT')
        refuses(notifier.assert_reason_maps_agree, 'disagree')
    finally:
        notifier.REASON_CLASS.clear()
        notifier.REASON_CLASS.update(saved)


@case('R08', 'a reason code with no class REFUSES rather than defaulting to the class that '
             'auto-closes')
def _r08():
    snap = {'entity': snapshot_validator.OUTPUT_ENTITY,
            'verdict': {'reasons': [{'code': 'A_BRAND_NEW_CODE', 'detail': 'x'}]}}
    refuses(lambda: notifier.findings_of(snap), 'REASON_CLASS')


# =======================================================================================
# DEDUPE - acceptance 2. D02 is the escalation the whole field exists for.
# =======================================================================================

@case('D01', 'the dedupe key is public_id + state + severity + material_revision')
def _d01():
    eq(notifier.dedupe_key('FP-0123456789', 'OPEN', 'WARN', 3),
       'FP-0123456789|OPEN|WARN|3', 'design 7.3 names all four')


@case('D02', 'ESCALATION: WARN -> REAL_MONEY with the state STILL OPEN is NOT swallowed')
def _d02():
    before = notifier.plan([rec(severity='WARN', state='OPEN', revision=4)], PROJECTION)[0]
    after = notifier.plan([rec(severity='REAL_MONEY', state='OPEN', revision=4)], PROJECTION)[0]
    if before['dedupe_key'] == after['dedupe_key']:
        raise AssertionError('rev 1 deduped on (id, state) and this pair produced ONE key, so '
                             'the escalation to real money was suppressed as a duplicate. That '
                             'is the exact defect design 7.3 names.')
    eq(before['channel'], 'CONTROL_ROOM', '')
    eq(after['channel'], 'EMERGENCY', 'the escalation must also change WHICH bot wakes')


@case('D03', 'a payload change with an unchanged severity bumps material_revision, so the key '
             'moves')
def _d03():
    f = [{'finding_id': 'FND-x', 'code': 'DUPLICATES_PRESENT', 'detail': 'one',
          'severity': 'INFO', 'class': 'AUDIT'}]
    r1, lines1 = notifier.observe([], f, at(0))
    f2 = [dict(f[0], detail='two')]
    r2, _ = notifier.observe(lines1, f2, at(1))
    eq(r1[0]['material_revision'], 0, '')
    eq(r2[0]['material_revision'], 1, 'a changed payload is a material revision')


@case('D04', 'an identical observation twice produces an identical key, so dedupe can dedupe')
def _d04():
    f = [{'finding_id': 'FND-x', 'code': 'DUPLICATES_PRESENT', 'detail': 'one',
          'severity': 'INFO', 'class': 'AUDIT'}]
    r1, lines1 = notifier.observe([], f, at(0))
    r2, _ = notifier.observe(lines1, f, at(1))
    eq(r1[0]['material_revision'], r2[0]['material_revision'], '')
    a = notifier.plan(r1, PROJECTION)[0]['dedupe_key']
    b = notifier.plan(r2, PROJECTION)[0]['dedupe_key']
    eq(a, b, 'the same finding, unchanged, must produce one key or nothing is ever deduped')


@case('D05', 'severity is NOT part of the payload digest, so D02 proves an INDEPENDENT field')
def _d05():
    a = notifier.payload_digest('C', 'd', 'RUNTIME')
    eq(a, notifier.payload_digest('C', 'd', 'RUNTIME'), 'stable')
    if a == notifier.payload_digest('C', 'd', 'AUDIT'):
        raise AssertionError('class must be material')
    # If severity were folded in here, D02 would pass for the wrong reason: the revision would
    # move and the severity field would never be tested at all.
    eq(notifier.payload_digest('C', 'd', 'RUNTIME'), a, '')


# =======================================================================================
# RECOVERY - acceptance 4, and the rule reused rather than restated.
# =======================================================================================

def at(hour=0, day=2):
    """A real journal timestamp. observe() REFUSES an unparseable one (case W03)."""
    return '2026-08-%02dT%02d:00:00' % (day, hour)


def _walk_states(present_flags, step_hours=1, day=2):
    """Drive observe() over a sequence of present/absent snapshots. -> list of records."""
    f = [{'finding_id': 'FND-r', 'code': 'MANDATORY_SOURCE_STALE', 'detail': 'src',
          'severity': 'WARN', 'class': 'RUNTIME'}]
    lines = []
    out = []
    for i, present in enumerate(present_flags):
        recs, new = notifier.observe(lines, f if present else [],
                                     at(i * step_hours, day))
        lines = lines + new
        out.append(recs[0])
    return out


@case('V01', 'OPEN -> HEALTHY_1_OF_2 -> OPEN emits NO recovery message, and NO message at all '
             'for the intermediate healthy check')
def _v01():
    states = _walk_states([True, False, True])
    eq([s['state'] for s in states], ['OPEN', 'HEALTHY_1_OF_2', 'OPEN'], '')
    eq([s['recovery_emitted'] for s in states], [False, False, False],
       'an intermediate healthy check is not a recovery; calling it one is the flapping spam '
       'the two-check rule exists to stop')
    # THIS ASSERTION USED TO READ ['ALERT'] FOR ALL THREE, and it was the implementation written
    # down rather than the requirement. Withholding the word RECOVERY while sending a message
    # that says HEALTHY_1_OF_2 is the same spam under a different label.
    kinds = [[e['kind'] for e in notifier.plan([s], PROJECTION)] for s in states]
    eq(kinds, [['ALERT'], [], ['ALERT']],
       'the middle observation must produce NO event; the OPEN alert is already in force and a '
       'brief absence is not news')


@case('V05', 'END TO END, a flickering finding sends TWO messages over five runs, not four')
def _v05():
    # The claim V01 makes case by case, made once against the whole path: observe -> plan ->
    # deliver, with a real ledger doing the deduping. This is the case that would have caught
    # the round-1 defect on its own, because it counts what LEAVES rather than what is planned.
    f = [{'finding_id': 'FND-flick', 'code': 'MANDATORY_SOURCE_STALE', 'detail': 's',
          'severity': 'WARN', 'class': 'RUNTIME'}]
    lines, delivered = [], set()
    t = notifier.RecordingTransport()
    seen = []
    for i, present in enumerate([True, False, True, False, True]):
        now = '2026-08-02T%02d:00:00' % i
        recs, new = notifier.observe(lines, f if present else [], now)
        lines += new
        out, _ = notifier.deliver(notifier.plan(recs, PROJECTION, now=now), delivered,
                                  {'CONTROL_ROOM': t}, now, SENT, 'NOT_RUNNING')
        seen.append(recs[0]['state'])
    eq(seen, ['OPEN', 'HEALTHY_1_OF_2', 'OPEN', 'HEALTHY_1_OF_2', 'FLAPPING'], '')
    eq(len(t.sent), 2,
       'exactly two messages: the OPEN alert, and the FLAPPING collapse. Every flicker in '
       'between is already covered by the alert in force')
    eq([s.splitlines()[0].rsplit('· ', 1)[-1] for _, s in t.sent], ['OPEN', 'FLAPPING'], '')


@case('V02', 'a genuine recovery emits EXACTLY ONE recovery message, and never a second')
def _v02():
    states = _walk_states([True, False, False, False])
    eq([s['state'] for s in states], ['OPEN', 'HEALTHY_1_OF_2', 'RESOLVED', 'RESOLVED'], '')
    eq([s['recovery_emitted'] for s in states], [False, False, True, False],
       'exactly one, and it is fold_finding that decides - not a second rule in the sender')
    kinds = [e['kind'] for s in states for e in notifier.plan([s], PROJECTION)]
    eq(kinds, ['ALERT', 'RECOVERY'],
       'four observations, TWO messages: the opening alert, silence on the intermediate healthy '
       'check, one recovery when the second healthy check confirms it, and nothing at all for '
       'the fourth, which is RESOLVED with the recovery already sent')
    hit('kind:RECOVERY')


@case('V03', 'a GOVERNANCE finding never auto-recovers, however healthy the checks are')
def _v03():
    f = [{'finding_id': 'FND-g', 'code': 'DUPLICATE_SOURCE_NAME', 'detail': 'd',
          'severity': 'WARN', 'class': 'GOVERNANCE'}]
    lines = []
    recs, new = notifier.observe(lines, f, at(0))
    lines += new
    for i in range(4):
        recs, new = notifier.observe(lines, [], at(i + 1))
        lines += new
    eq(recs[0]['state'], 'OPEN', 'design 7.1: only RUNTIME closes itself')
    eq(recs[0]['recovery_emitted'], False, '')


@case('V04', 'the lifecycle comes from control_center.fold_finding, not from a copy in here')
def _v04():
    saved = control_center.fold_finding
    calls = []

    def spy(finding):
        calls.append(finding['id'])
        return saved(finding)
    control_center.fold_finding = spy
    try:
        _walk_states([True, False])
    finally:
        control_center.fold_finding = saved
    if not calls:
        raise AssertionError('observe() did not call control_center.fold_finding, which means a '
                             'second copy of the recovery rule exists somewhere and the two will '
                             'drift')


# =======================================================================================
# FLAPPING and the RECURRENCE WINDOW. design 11 row 16 owes the bounded reminder to S12, and
# the first honest attempt at it found the counter underneath it was measuring the wrong thing.
# =======================================================================================

@case('W01', 'a CONTINUOUSLY open finding is NOT flapping, however often it is sampled')
def _w01():
    # FOUND BY THIS CASE. occurrences_24h counted every observation where the finding was
    # present, so an hourly collector turned a single persistent problem into
    # `FLAPPING - root cause required` before lunch - a different and wrong statement about it,
    # and one that collapses its alert into an incident nobody opened.
    states = _walk_states([True] * 6)
    eq([s['state'] for s in states], ['OPEN'] * 6,
       'continuously present is not recurring; a RECURRENCE is an appearance after an absence')


@case('W02', 'three genuine RECURRENCES inside 24h do collapse into FLAPPING')
def _w02():
    states = _walk_states([True, False, True, False, True])
    eq(states[-1]['occurrences_24h'], 3, '')
    eq(states[-1]['state'], 'FLAPPING', 'design 7.3: 3 recurrences in 24h is one incident')


@case('W03', 'an unparseable journal timestamp REFUSES; it is not skipped and not aged out')
def _w03():
    f = [{'finding_id': 'FND-r', 'code': 'MANDATORY_SOURCE_STALE', 'detail': 's',
          'severity': 'WARN', 'class': 'RUNTIME'}]
    refuses(lambda: notifier.observe([], f, 'yesterday'), 'not %Y'.lower())
    bad = [{'finding_id': 'FND-r', 'present': True, 'at': 'whenever'}]
    refuses(lambda: notifier.observe(bad, f, at(1)), 'recurrence window')


@case('W04', 'recurrences OUTSIDE the 24h window do not count, so an old scar is not FLAPPING')
def _w04():
    f = [{'finding_id': 'FND-r', 'code': 'MANDATORY_SOURCE_STALE', 'detail': 's',
          'severity': 'WARN', 'class': 'RUNTIME'}]
    lines = []
    for i, present in enumerate([True, False, True, False]):
        _, new = notifier.observe(lines, f if present else [], at(i, day=1))
        lines += new
    recs, _ = notifier.observe(lines, f, at(0, day=3))     # two days later
    eq(recs[0]['occurrences_24h'], 1, 'only this appearance is inside the window')
    eq(recs[0]['state'], 'OPEN', '')


@case('W05', 'FLAPPING gets a BOUNDED REMINDER: the same incident re-alerts once the next day')
def _w05():
    r = rec(state='FLAPPING', severity='WARN')
    d1 = notifier.plan([r], PROJECTION, now='2026-08-02T09:00:00')[0]['dedupe_key']
    d1b = notifier.plan([r], PROJECTION, now='2026-08-02T21:00:00')[0]['dedupe_key']
    d2 = notifier.plan([r], PROJECTION, now='2026-08-03T09:00:00')[0]['dedupe_key']
    eq(d1, d1b, 'twice in one day is one alert - a reminder is bounded, not chatty')
    if d1 == d2:
        raise AssertionError('a FLAPPING finding keeps one key forever, so after the first '
                             'alert it is permanently silent. design 7.3 forbids exactly that: '
                             '"a state that never changes cannot go unreported forever".')


@case('W06', 'only FLAPPING carries the reminder window - an OPEN finding is not re-alerted daily')
def _w06():
    r = rec(state='OPEN', severity='WARN')
    a = notifier.plan([r], PROJECTION, now='2026-08-02T09:00:00')[0]['dedupe_key']
    b = notifier.plan([r], PROJECTION, now='2026-08-09T09:00:00')[0]['dedupe_key']
    eq(a, b, 'daily re-alerting of every open finding is the spam the dedupe key exists to stop')


@case('W07', 'a FLAPPING key without a clock REFUSES rather than falling back to permanent '
             'silence')
def _w07():
    refuses(lambda: notifier.dedupe_key('FP-0123456789', 'FLAPPING', 'WARN', 0, None),
            'permanent silence')


# =======================================================================================
# THE LEDGER - acceptance 3. "Was this delivered" has to be answerable.
# =======================================================================================

# A REAL-SHAPED token, so the rule under test is the one that fires. The first version of this
# fixture used `bot12345:SECRETTOKENVALUE`, which is not a Telegram token shape at all - it was
# redacted anyway, by WINDOWS_ABSOLUTE_PATH matching the `s:/` inside `https://`. The case went
# red saying the redaction did not NAME the token rule, which is the case doing its job: a
# fixture redacted for an unrelated reason proves nothing about the reason it claims to test.
FAKE_TOKEN = '7788990011:AAHSECRETTOKENVALUEfakefakefakefake12'


class Boom(object):
    transport_kind = 'TELEGRAM'

    def send(self, channel, text):
        raise RuntimeError('send rejected, request carried %s' % FAKE_TOKEN)


class DeclaredTelegram(object):
    transport_kind = 'TELEGRAM'

    def send(self, channel, text):
        return 'telegram-receipt'


@case('L01', 'a first delivery is DELIVERED and carries a receipt')
def _l01():
    t = notifier.RecordingTransport()
    lines, problems = notifier.deliver(notifier.plan([rec(severity='WARN')], PROJECTION),
                                       set(), {'CONTROL_ROOM': t}, 't', SENT, 'NOT_RUNNING')
    eq([l['outcome'] for l in lines], ['DELIVERED'], '')
    eq(problems, 0, '')
    eq(len(t.sent), 1, '')
    if not lines[0]['receipt']:
        raise AssertionError('a DELIVERED line with no receipt cannot answer "did it arrive"')
    eq(lines[0]['transport_kind'], 'RECORDING',
       'newly emitted recording evidence must identify its transport')
    hit('outcome:DELIVERED')
    hit('openclaw:NOT_RUNNING')


@case('L12', 'new delivery rows identify TELEGRAM or RECORDING, and a missing field is caught')
def _l12():
    ev = notifier.plan([rec(severity='WARN')], PROJECTION)
    telegram, problems = notifier.deliver(ev, set(), {'CONTROL_ROOM': DeclaredTelegram()},
                                          't', SENT, 'NOT_RUNNING')
    eq(problems, 0, 'the declared Telegram transport should deliver')
    eq(telegram[0]['transport_kind'], 'TELEGRAM',
       'newly emitted Telegram evidence must identify its transport')
    eq(schema_fixtures.check_new_alert_delivery_row(telegram[0], 'telegram'), [],
       'the canonical producer checker should accept a complete new row')
    missing = dict(telegram[0])
    del missing['transport_kind']
    if not schema_fixtures.check_new_alert_delivery_row(missing, 'synthetic-missing'):
        raise AssertionError('a newly emitted row missing transport_kind passed the checker')


@case('L02', 'a replay of an already-DELIVERED key sends NOTHING and says so')
def _l02():
    t = notifier.RecordingTransport()
    events = notifier.plan([rec(severity='WARN')], PROJECTION)
    delivered = set()
    notifier.deliver(events, delivered, {'CONTROL_ROOM': t}, 't', SENT, 'NOT_RUNNING')
    lines, problems = notifier.deliver(events, delivered, {'CONTROL_ROOM': t}, 't', SENT, 'NOT_RUNNING')
    eq([l['outcome'] for l in lines], ['SUPPRESSED_DUPLICATE'], '')
    eq(len(t.sent), 1, 'the transport must not have been touched a second time')
    eq(problems, 0, 'a correctly suppressed duplicate is not a problem')
    hit('outcome:SUPPRESSED_DUPLICATE')


@case('L03', 'the ledger is PER CHANNEL: the same key on the other bot is not suppressed')
def _l03():
    ev = notifier.plan([rec(severity='WARN')], PROJECTION)[0]
    other = dict(ev, channel='EMERGENCY')
    t = notifier.RecordingTransport()
    delivered = set()
    notifier.deliver([ev], delivered, {'CONTROL_ROOM': t, 'EMERGENCY': t}, 't', SENT, 'NOT_RUNNING')
    lines, _ = notifier.deliver([other], delivered, {'CONTROL_ROOM': t, 'EMERGENCY': t},
                                't', SENT, 'NOT_RUNNING')
    eq([l['outcome'] for l in lines], ['DELIVERED'],
       'a per-channel ledger keyed only on the event would silence the second bot')


@case('L04', 'a FAILED attempt is RETRIED next run - dedupe reads DELIVERED and nothing else')
def _l04():
    ev = notifier.plan([rec(severity='WARN')], PROJECTION)
    delivered = set()
    lines, problems = notifier.deliver(ev, delivered, {'CONTROL_ROOM': Boom()}, 't', SENT, 'UNKNOWN')
    eq([l['outcome'] for l in lines], ['FAILED'], '')
    eq(problems, 1, 'a failure that does not raise the problem count is a silent no-send')
    t = notifier.RecordingTransport()
    lines2, _ = notifier.deliver(ev, delivered, {'CONTROL_ROOM': t}, 't', SENT, 'NOT_RUNNING')
    eq([l['outcome'] for l in lines2], ['DELIVERED'],
       'suppressing a retry after a failure loses the alert entirely')
    hit('outcome:FAILED')
    hit('openclaw:UNKNOWN')


@case('L05', 'an UNCONFIGURED channel is a STATED failure with a non-zero problem count')
def _l05():
    ev = notifier.plan([rec(severity='WARN')], PROJECTION)
    lines, problems = notifier.deliver(ev, set(), {'CONTROL_ROOM': None}, 't', SENT, 'NOT_RUNNING')
    eq([l['outcome'] for l in lines], ['UNCONFIGURED'], '')
    eq(lines[0]['transport_kind'], 'UNKNOWN',
       'an unconfigured new row must carry conservative UNKNOWN')
    eq(problems, 1, '')
    if not lines[0]['detail']:
        raise AssertionError('an unconfigured channel that says nothing is indistinguishable '
                             'from a quiet fleet')
    hit('outcome:UNCONFIGURED')


@case('L06', 'a transport that raises an UNSCRUBBED token does not get it into the ledger')
def _l06():
    # FOUND BY THIS CASE, red on its first honest run: deliver() wrote the exception text
    # verbatim, so the no-token-in-logs guarantee rested on every transport scrubbing itself.
    # The URL of a Telegram send request CONTAINS the token, so a transport wrapping any
    # library that reports the URL would have written it to disk. Boom() is that transport.
    ev = notifier.plan([rec(severity='WARN')], PROJECTION)
    lines, problems = notifier.deliver(ev, set(), {'CONTROL_ROOM': Boom()}, 't', SENT, 'NOT_RUNNING')
    blob = json.dumps(lines, ensure_ascii=False)
    eq(problems, 1, 'a redacted failure is still a failure')
    if FAKE_TOKEN in blob:
        raise AssertionError('the ledger carries the token from an unscrubbed transport '
                             'exception:\n%s' % blob)
    if 'TELEGRAM_BOT_TOKEN' not in blob:
        raise AssertionError('the line must NAME the rule that withheld the text - an operator '
                             'seeing a bare redaction learns nothing about what was withheld, '
                             'and a redaction fired by an UNRELATED rule proves nothing about '
                             'the rule this case names. blob=%s' % blob)
    eq(notifier.scrub('x %s y' % FAKE_TOKEN, FAKE_TOKEN), 'x ***REDACTED*** y',
       'scrub itself must work')


@case('L08', 'safe_detail passes an ORDINARY failure through untouched (it is not a blanket '
             'redactor)')
def _l08():
    eq(notifier.safe_detail('ConnectionError: timed out after 20s'),
       'ConnectionError: timed out after 20s',
       'redacting everything is the same as reporting nothing')


@case('L09', 'MEASURED COST, stated rather than discovered later: any URL in a failure detail '
             'is redacted, because WINDOWS_ABSOLUTE_PATH matches the `s:/` inside `https://`')
def _l09():
    out = notifier.safe_detail('HTTPError: 429 Too Many Requests from https://api.telegram.org')
    if 'WINDOWS_ABSOLUTE_PATH' not in out:
        raise AssertionError('the shared rule stopped matching URLs, so this documented cost is '
                             'stale and the note in ORDER-1180 should be removed:\n%s' % out)
    if '429' in out:
        raise AssertionError('half-redaction is worse than either: %s' % out)
    # This is FAIL-CLOSED and therefore acceptable, but it is a real cost: the operator loses
    # the HTTP status. Widening the rule is a change to a LEAK guard shared with the projection,
    # which is not a change to make as a side effect of a notifier - so it is measured here and
    # carried as an owed item instead of being loosened quietly.


@case('L07', 'the ledger round-trips through a file and dedupe survives it')
def _l07():
    tmp = tempfile.mkdtemp(prefix='s12-ledger-')
    try:
        path = os.path.join(tmp, 'ops', 'delivery_ledger.jsonl')
        ledger = notifier.Ledger.load(path)
        ev = notifier.plan([rec(severity='WARN')], PROJECTION)
        lines, _ = notifier.deliver(ev, ledger.delivered(),
                                    {'CONTROL_ROOM': notifier.RecordingTransport()},
                                    't', SENT, 'NOT_RUNNING')
        ledger.append(path, lines)
        again = notifier.Ledger.load(path)
        eq(len(again.delivered()), 1, 'a ledger that does not survive a reload is a sent-set')
        lines2, _ = notifier.deliver(ev, again.delivered(),
                                     {'CONTROL_ROOM': notifier.RecordingTransport()},
                                     't', SENT, 'NOT_RUNNING')
        eq([l['outcome'] for l in lines2], ['SUPPRESSED_DUPLICATE'], '')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


@case('L13', 'a legacy delivery row without transport_kind remains readable and unchanged')
def _l13():
    tmp = tempfile.mkdtemp(prefix='s12-legacy-delivery-')
    try:
        path = os.path.join(tmp, 'legacy.jsonl')
        legacy = {'entity': 'AlertDelivery', 'dedupe_key': 'legacy', 'channel': 'EMERGENCY',
                  'kind': 'ALERT', 'outcome': 'DELIVERED', 'receipt': 'old-receipt',
                  'at': '2026-08-01T00:00:00', 'openclaw': 'UNKNOWN', 'detail': ''}
        raw = json.dumps(legacy, sort_keys=True) + '\n'
        with io.open(path, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(raw)
        before = io.open(path, 'rb').read()
        rows, torn = notifier.read_jsonl(path)
        eq(torn, [], 'a legacy row is readable, not torn')
        eq(rows, [legacy], 'the legacy row was not rewritten or backfilled in memory')
        after = io.open(path, 'rb').read()
        eq(after, before, 'reading legacy evidence must not rewrite historical bytes')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


# =======================================================================================
# THE SEAM. The negatives, which are the product.
# =======================================================================================

@case('L10', 'a FAILED line in the LEDGER FILE does not suppress the retry on the next run')
def _l10():
    # FOUND BY A MUTATION SWEEP, not by this suite as first written. L04 proved the retry
    # against the in-memory set `deliver()` mutates, so a Ledger.delivered() that counted
    # FAILED as delivered survived every case - and that mutant is a real scheduled job losing
    # an alert permanently the first time the API blips. The claim has to be made against the
    # FILE, because the file is what the next run reads.
    tmp = tempfile.mkdtemp(prefix='s12-retry-')
    try:
        path = os.path.join(tmp, 'ops', 'delivery_ledger.jsonl')
        ev = notifier.plan([rec(severity='WARN')], PROJECTION)
        ledger = notifier.Ledger.load(path)
        lines, _ = notifier.deliver(ev, ledger.delivered(), {'CONTROL_ROOM': Boom()},
                                    at(0), SENT, 'NOT_RUNNING')
        eq([l['outcome'] for l in lines], ['FAILED'], '')
        ledger.append(path, lines)

        reloaded = notifier.Ledger.load(path)
        eq(reloaded.delivered(), set(),
           'a FAILED attempt recorded as delivered means the next run stays silent about an '
           'alert that never arrived')
        t = notifier.RecordingTransport()
        lines2, _ = notifier.deliver(ev, reloaded.delivered(), {'CONTROL_ROOM': t},
                                     at(1), SENT, 'NOT_RUNNING')
        eq([l['outcome'] for l in lines2], ['DELIVERED'], '')
        eq(len(t.sent), 1, '')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


@case('L11', 'an UNCONFIGURED line in the LEDGER FILE does not suppress the retry either')
def _l11():
    tmp = tempfile.mkdtemp(prefix='s12-retry2-')
    try:
        path = os.path.join(tmp, 'ops', 'delivery_ledger.jsonl')
        ev = notifier.plan([rec(severity='WARN')], PROJECTION)
        ledger = notifier.Ledger.load(path)
        lines, _ = notifier.deliver(ev, ledger.delivered(), {'CONTROL_ROOM': None},
                                    at(0), SENT, 'NOT_RUNNING')
        ledger.append(path, lines)
        eq(notifier.Ledger.load(path).delivered(), set(),
           'the Control Room bot does not exist yet, so every alert to it is UNCONFIGURED - '
           'suppressing those would mean nothing is ever sent once the bot IS created')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


@case('P01', 'PUBLIC_API is the module\'s ACTUAL public surface, not a list nobody reads')
def _p01():
    # FOUND BY ROUND 3: notifier.PUBLIC_API was declared and NOTHING read it. A declaration no
    # check consumes is worse than none - it reads as governance while being decoration, which
    # is the shape memory `declared-as-trigger-but-never-read` is about. It matters here
    # specifically because this module SENDS: a new public writer arriving unnoticed is the one
    # thing a closed surface exists to prevent.
    actual = set(n for n in dir(notifier)
                 if not n.startswith('_')
                 and getattr(getattr(notifier, n), '__module__', 'notifier') == 'notifier'
                 and (callable(getattr(notifier, n)) or isinstance(getattr(notifier, n), type)))
    declared = set(notifier.PUBLIC_API)
    eq(sorted(actual - declared), [],
       'these public callables are NOT in PUBLIC_API, so the surface grew without review')
    eq(sorted(declared - actual), [],
       'PUBLIC_API names things that do not exist, so it is stale')


@case('S01', 'a sender is refused the FULL SNAPSHOT by path, before its bytes are opened')
def _s01():
    refuses(lambda: safe_projection.read_for_sender(
        os.path.join(ROOT, safe_projection.SNAPSHOT_REL), ROOT), 'may read only')


@case('S02', 'an event with an UNDECLARED field is refused for being undeclared')
def _s02():
    ev = notifier.plan([rec()], PROJECTION)
    ev[0]['finding_id'] = 'FND-sensor-159503454'
    refuses(lambda: notifier.assert_sendable(ev, safe_projection.NO_KNOWN_SECRETS_AVAILABLE, ROOT), 'not declared')
    hit('scan:SHAPE')


@case('S03', 'a literal FROM THE SNAPSHOT inside the free-form text is caught - the layer only '
             'the local side can run')
def _s03():
    ev = notifier.plan([rec()], PROJECTION)
    ev[0]['text'] = 'sensor down on account 159503454'
    refuses(lambda: notifier.assert_sendable(ev, ('159503454',), ROOT), 'KNOWN_SECRET'.lower(),
            kinds=(safe_projection.ProjectionLeak,))
    # and the control: the SAME event with no secret list would sail through, which is exactly
    # why this check lives on the planner and not on the sender.
    notifier.assert_sendable(ev, safe_projection.NO_KNOWN_SECRETS_AVAILABLE, ROOT)
    hit('scan:KNOWN_SECRET')


@case('S12', 'ORDER-1310 #2 a caller-chosen probe id does NOT travel in the message text')
def _s12():
    """
    THE ONE PATH THAT CANNOT SCAN ITS OWN TEXT, carrying text the caller typed. `--id` went into
    the message verbatim while the probe branch declares NO_KNOWN_SECRETS_AVAILABLE -- by design,
    because a probe exists to run when the snapshot is broken and there is nothing to derive
    recognizers from. The independent review sent `probe --id 159503454` and got
    `[EA LAB] delivery probe 159503454 → EMERGENCY` past assert_sendable. An operator reaching
    for their account number as a convenient unique id would have posted it to Telegram.

    Filtering it would be the wrong repair -- a blacklist of value shapes has no end. The channel
    is removed: an opaque derived token goes on the wire and the raw id stays in the LOCAL ledger
    key. So this case asserts BOTH halves, or "the id does not travel" would also be satisfied by
    a probe that stopped being unique.
    """
    account_shaped = '159503454'
    ev = notifier.plan([], None, None, (account_shaped, 'EMERGENCY'))
    probes = [e for e in ev if e['kind'] == 'DELIVERY_PROBE']
    eq(len(probes), 1, 'CONTROL: the probe event is no longer planned at all: %s' % ev)
    text = probes[0]['text']
    if account_shaped in text:
        raise AssertionError('the caller-chosen probe id travels in the message text: %r' % text)
    # ...and it is still CORRELATABLE: a stable opaque token derived from the id.
    if safe_projection.public_id(account_shaped) not in text:
        raise AssertionError('the probe text carries no token for the id, so an operator cannot '
                             'match what they typed to what arrived: %r' % text)
    # The raw id is kept exactly where it must be -- the dedupe key, which lives in the LOCAL
    # ledger under gitignored ops/ and is never sent. Without it a second probe is a suppressed
    # duplicate forever, which is what --id exists to prevent.
    if account_shaped not in probes[0]['dedupe_key']:
        raise AssertionError('the raw id was dropped from the ledger key too: %s' % probes[0])
    # SPECIFICITY: two different ids must still produce two different messages.
    other = [e for e in notifier.plan([], None, None, ('S12-OTHER', 'EMERGENCY'))
             if e['kind'] == 'DELIVERY_PROBE']
    if other[0]['text'] == text:
        raise AssertionError('two different probe ids produce the same message text')
    # ...and the whole event still crosses the boundary on the path that cannot scan it.
    notifier.assert_sendable(ev, safe_projection.NO_KNOWN_SECRETS_AVAILABLE, ROOT)
    hit('kind:DELIVERY_PROBE')


@case('S04', 'a local filesystem path in the text is caught wherever it appears')
def _s04():
    ev = notifier.plan([rec()], PROJECTION)
    ev[0]['text'] = 'could not read D:\\EA_LAB\\portfolio\\control_room_snapshot.json'
    refuses(lambda: notifier.assert_sendable(ev, safe_projection.NO_KNOWN_SECRETS_AVAILABLE, ROOT), 'WINDOWS_ABSOLUTE_PATH',
            kinds=(safe_projection.ProjectionLeak,))
    hit('scan:WINDOWS_ABSOLUTE_PATH')


@case('S05', 'a bot token pasted into a message is caught before it is sent')
def _s05():
    ev = notifier.plan([rec()], PROJECTION)
    ev[0]['text'] = 'using 1234567890:AAHfakefakefakefakefakefakefakefake12'
    refuses(lambda: notifier.assert_sendable(ev, safe_projection.NO_KNOWN_SECRETS_AVAILABLE, ROOT), 'TELEGRAM_BOT_TOKEN',
            kinds=(safe_projection.ProjectionLeak,))
    hit('scan:TELEGRAM_BOT_TOKEN')


@case('S06', 'material_revision is CHECKED as an integer - the construct S11 refused rather '
             'than passed')
def _s06():
    ev = notifier.plan([rec()], PROJECTION)
    ev[0]['material_revision'] = '2'
    refuses(lambda: notifier.assert_sendable(ev, safe_projection.NO_KNOWN_SECRETS_AVAILABLE, ROOT), 'must be integer')
    hit('scan:SHAPE_INTEGER')


@case('S07', 'a boolean does not satisfy type:integer, even though bool IS int in python')
def _s07():
    ev = notifier.plan([rec()], PROJECTION)
    ev[0]['material_revision'] = True
    refuses(lambda: notifier.assert_sendable(ev, safe_projection.NO_KNOWN_SECRETS_AVAILABLE, ROOT), 'must be integer')


@case('S08', 'the declared `minimum` is enforced, not silently dropped along with the type')
def _s08():
    ev = notifier.plan([rec()], PROJECTION)
    ev[0]['material_revision'] = -1
    refuses(lambda: notifier.assert_sendable(ev, safe_projection.NO_KNOWN_SECRETS_AVAILABLE, ROOT), 'must be >=')


@case('S09', 'the shape checker still REFUSES a construct it does not implement (S11 SB07 is '
             'kept alive across the new branches)')
def _s09():
    hits = []
    safe_projection._check_shape({'a': 1}, {'oneOf': [{'type': 'object'}]}, '$', hits)
    if not hits or hits[0][1] != 'SHAPE_UNCHECKED':
        raise AssertionError('adding integer/boolean/list-type support must not have re-opened '
                             'the silent-acceptance hole underneath them: got %r' % (hits,))


@case('S10', 'a type UNION (`string | null`) is checked on both branches, not waved through')
def _s10():
    hits = []
    schema = {'type': ['string', 'null'], 'pattern': '^R'}
    safe_projection._check_shape(None, schema, '$', hits)
    safe_projection._check_shape('REC-1', schema, '$', hits)
    eq(hits, [], 'both legal shapes must pass')
    safe_projection._check_shape(7, schema, '$', hits)
    if not hits:
        raise AssertionError('an integer satisfied `string | null`')


@case('S11', 'NO internal finding id and NO detail reaches any planned event or its text')
def _s11():
    snap = real_snapshot()
    findings = notifier.findings_of(snap)
    if not findings:
        raise AssertionError('the real snapshot carries no findings, so this case is measuring '
                             'nothing - it must be driven against a document that has some')
    records, _ = notifier.observe([], findings, at(0))
    events = notifier.plan(records, PROJECTION)
    blob = json.dumps(events, ensure_ascii=False)
    for f in findings:
        if f['finding_id'] in blob:
            raise AssertionError('the internal id %r travelled' % f['finding_id'])
        if f['detail'] and str(f['detail']) in blob:
            raise AssertionError('the detail %r travelled' % f['detail'])
    notifier.assert_sendable(events, safe_projection.secrets_of(snap), ROOT)


# =======================================================================================
# OPENCLAW - acceptance 1. Two independent claims: it is not RUNNING, and it is not REACHABLE.
# =======================================================================================

@case('O01', 'openclaw_state reports RUNNING when the gateway is in the process list')
def _o01():
    eq(notifier.openclaw_state(lambda: ['svchost.exe', 'openclaw.exe']), 'RUNNING', '')
    hit('openclaw:RUNNING')


@case('O02', 'and NOT_RUNNING when it is not')
def _o02():
    eq(notifier.openclaw_state(lambda: ['svchost.exe', 'terminal64.exe']), 'NOT_RUNNING', '')


@case('O03', 'an unreadable process list is UNKNOWN, never collapsed onto NOT_RUNNING')
def _o03():
    def broken():
        raise OSError('tasklist is not on PATH')
    eq(notifier.openclaw_state(broken), 'UNKNOWN',
       'the benign-looking value standing in for "could not tell" would fabricate the very '
       'observation this acceptance rests on')
    eq(notifier.openclaw_state(lambda: None), 'UNKNOWN', '')


@case('O04', 'the alert path plans and delivers IDENTICALLY whether the gateway is up or down')
def _o04():
    ev = notifier.plan([rec(severity='CRITICAL')], PROJECTION)
    out = []
    for state in ('RUNNING', 'NOT_RUNNING', 'UNKNOWN'):
        t = notifier.RecordingTransport()
        lines, problems = notifier.deliver(ev, set(), {'EMERGENCY': t}, 't', SENT, state)
        out.append(([l['outcome'] for l in lines], problems, list(t.sent)))
        eq(lines[0]['openclaw'], state, 'the OBSERVED state is recorded beside the receipt')
    eq(out[0], out[1], 'delivery must not depend on the gateway being down...')
    eq(out[1], out[2], '...nor on knowing whether it is')


@case('O05', 'every import the alert path makes is on the closed allowlist - OpenClaw is not '
             'reachable, as a property rather than a sentence')
def _o05():
    seen = set()
    for name in notifier.IMPORT_CLOSURE:
        src = io.open(os.path.join(HERE, name + '.py'), encoding='utf-8').read()
        seen |= notifier.imports_of(src, name)
    extra = seen - notifier.ALLOWED_IMPORTS
    eq(sorted(extra), [], 'the alert path reaches modules nobody declared')
    if len(seen) < 10:
        raise AssertionError('the closure came out suspiciously small (%d) - a checker that '
                             'parses nothing passes everything' % len(seen))


@case('O06', 'the import allowlist can FIRE (a guard with zero fires is UNTESTED)')
def _o06():
    planted = 'import os\nfrom openclaw.gateway import dispatch\n'
    found = notifier.imports_of(planted, '<planted>')
    if 'openclaw.gateway' not in found:
        raise AssertionError('an AST import of the gateway was not seen: %r' % (found,))
    if not (found - notifier.ALLOWED_IMPORTS):
        raise AssertionError('the allowlist accepted a gateway import, so O05 proves nothing')


# =======================================================================================
# THE MORNING BRIEF - a rendering, and the DD rule.
# =======================================================================================

@case('B01', 'the Morning Brief renders the projection it was handed, and routes to Control Room')
def _b01():
    ev = notifier.plan([], PROJECTION, brief=('ATTENTION', 6, True))
    eq(len(ev), 1, '')
    eq(ev[0]['kind'], 'MORNING_BRIEF', '')
    eq(ev[0]['channel'], 'CONTROL_ROOM', 'a brief is never an emergency')
    text = ev[0]['text']
    for want in ('ATTENTION', 'FRESH 1', 'STALE 1', 'LIVE exception: 6', 'UNKNOWN'):
        if want not in text:
            raise AssertionError('the brief did not render %r:\n%s' % (want, text))
    notifier.assert_sendable(ev, safe_projection.NO_KNOWN_SECRETS_AVAILABLE, ROOT)
    hit('kind:MORNING_BRIEF')


@case('B02', 'the brief computes NO drawdown: an all-UNKNOWN fleet says why, it does not derive')
def _b02():
    text = notifier.render_morning_brief(PROJECTION, 'ATTENTION', 0, False)
    if 'ไม่คำนวณ DD เอง' not in text:
        raise AssertionError('an all-UNKNOWN band must state that no detector publishes one')
    for forbidden in ('%', 'equity', 'balance'):
        if forbidden in text:
            raise AssertionError('the brief leaked a computed risk figure: %r' % forbidden)


@case('B03', 'a detector-supplied band TRAVELS, so the UNKNOWN above is a measurement')
def _b03():
    proj = json.loads(json.dumps(PROJECTION))
    proj['accounts'][0]['dd_pct_band'] = 'BREACH'
    text = notifier.render_morning_brief(proj, 'ATTENTION', 1, False)
    if 'BREACH 1' not in text:
        raise AssertionError('a band supplied by a detector did not reach the brief, so the '
                             'UNKNOWN in B02 is a hardcoded constant:\n%s' % text)
    if 'ไม่คำนวณ DD เอง' in text:
        raise AssertionError('the "nobody publishes a band" note fired while a band was present')


@case('B04', 'the brief is built from the SafeProjection, so it cannot carry a raw account')
def _b04():
    proj = json.loads(json.dumps(PROJECTION))
    text = notifier.render_morning_brief(proj, 'ALL CLEAR', 0, False)
    if '159503454' in text or '***454' not in text.replace('***454', '***454'):
        pass
    # The masked form is what the projection carries; the raw form is structurally absent
    # because build() never wrote it. Assert the negative directly against a real secret list.
    snap = real_snapshot()
    ev = notifier.plan([], safe_projection.build(snap), brief=('ALL CLEAR', 0, False))
    notifier.assert_sendable(ev, safe_projection.secrets_of(snap), ROOT)


# =======================================================================================
# THE ENTRY POINT A HUMAN RUNS. In-process where a process boundary proves nothing; three
# subprocesses for the one claim that needs one.
# =======================================================================================

class _Captured(object):
    def __init__(self):
        self.out = io.StringIO()
        self.err = io.StringIO()

    def __enter__(self):
        self._o, self._e = sys.stdout, sys.stderr
        sys.stdout, sys.stderr = self.out, self.err
        return self

    def __exit__(self, *a):
        sys.stdout, sys.stderr = self._o, self._e
        return False


def fixture_repo():
    """
    A minimal repo the CLI can be driven against: the three documents it reads, and nothing else.
    No scripts/config.yaml, deliberately - so CONTROL_ROOM resolves UNCONFIGURED, which is a
    STATED outcome and the thing case C05 measures.
    """
    tmp = tempfile.mkdtemp(prefix='s12-repo-')
    for rel in (safe_projection.SNAPSHOT_REL, safe_projection.PROJECTION_REL,
                snapshot_validator.SCHEMA_PATH):
        dst = os.path.join(tmp, rel.replace('/', os.sep))
        d = os.path.dirname(dst)
        if not os.path.isdir(d):
            os.makedirs(d)
        shutil.copyfile(os.path.join(ROOT, rel.replace('/', os.sep)), dst)
    return tmp


@case('C01', '`plan` runs end to end against the REAL repo, sends nothing, and SURVIVES AN ANSI '
             'CONSOLE (the hook launches it into one)')
def _c01():
    # This case carries two claims because the second one costs nothing on top of the first.
    # PYTHONIOENCODING is forced to a codepage that CANNOT represent Thai - which is what a child
    # of the pre-commit hook gets - so an unpinned interpreter dies on its first output line with
    # UnicodeEncodeError. That is not hypothetical: it is how this suite and S11's failed inside
    # a real commit while passing every interactive run, and the failure surfaced as
    # `exit -1 SUITE THREW` with the cause swallowed by PowerShell's stderr handling.
    hostile = dict(CHILD_ENV)
    hostile['PYTHONIOENCODING'] = 'cp1252'
    out = subprocess.run([PY, os.path.join(HERE, 'notifier.py'), 'plan', '--repo-root', ROOT,
                          '--brief'], capture_output=True, cwd=ROOT, env=hostile)
    text = (out.stdout or b'').decode('utf-8', 'replace')
    if out.returncode != 0:
        raise AssertionError('plan exited %d under a cp1252 console\n%s\n%s'
                             % (out.returncode, text,
                                (out.stderr or b'').decode('utf-8', 'replace')))
    if 'nothing sent' not in text:
        raise AssertionError('plan did not state that it sent nothing:\n%s' % text)
    if 'MORNING_BRIEF' not in text:
        raise AssertionError('--brief planned no brief:\n%s' % text)


@case('C02', '`send` without --confirm REFUSES with an exit code, not a quiet no-send')
def _c02():
    with _Captured() as cap:
        code = notifier.main(['notifier.py', 'send', '--repo-root', ROOT])
    eq(code, 2, '')
    if 'REFUSED' not in cap.err.getvalue():
        raise AssertionError('a refusal nobody can read is a silent skip')


@case('C03', '`probe` without --id refuses rather than reusing one key forever')
def _c03():
    with _Captured() as cap:
        code = notifier.main(['notifier.py', 'probe', '--confirm', '--repo-root', ROOT])
    eq(code, 2, '')
    if 'needs --id' not in cap.err.getvalue():
        raise AssertionError(cap.err.getvalue())


@case('C07', 'a probe works when the SNAPSHOT IS BROKEN - the moment you most want to prove the '
             'alert path still runs')
def _c07():
    # A probe carries no finding, no account and no build, so requiring a verified snapshot to
    # send one would be backwards: a broken snapshot is exactly the situation in which an
    # operator needs to know whether alerts can still leave the machine. Driven against a repo
    # that has NO snapshot and NO projection at all.
    #
    # `schemas.json` IS still required, and that is not an inconsistency: it is the declaration
    # the outgoing event's shape is checked against, so a probe that skipped it would be the one
    # message on this path that nothing verified. The first version of this case gave the fixture
    # NEITHER file and went red naming exactly that -- which is the distinction worth keeping.
    tmp = tempfile.mkdtemp(prefix='s12-nosnap-')
    try:
        dst = os.path.join(tmp, snapshot_validator.SCHEMA_PATH.replace('/', os.sep))
        os.makedirs(os.path.dirname(dst))
        shutil.copyfile(os.path.join(ROOT, snapshot_validator.SCHEMA_PATH.replace('/', os.sep)),
                        dst)
        rec_path = os.path.join(tmp, 'sent.jsonl')
        with _Captured() as cap:
            code = notifier.main(['notifier.py', 'probe', '--id', 'NOSNAP', '--channel',
                                  'CONTROL_ROOM', '--confirm', '--record', rec_path,
                                  '--repo-root', tmp])
        eq(code, 0, 'a probe must not depend on a document it does not read:\n%s\n%s'
                    % (cap.out.getvalue(), cap.err.getvalue()))
        if 'DELIVERED' not in cap.out.getvalue():
            raise AssertionError(cap.out.getvalue())
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


@case('C04', 'an unreadable local input stops the run before anything is planned or sent')
def _c04():
    tmp = tempfile.mkdtemp(prefix='s12-empty-')
    try:
        with _Captured() as cap:
            code = notifier.main(['notifier.py', 'plan', '--repo-root', tmp])
        eq(code, 3, '')
        if 'nothing was sent' not in cap.err.getvalue():
            raise AssertionError(cap.err.getvalue())
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


@case('C05', 'a real `send --confirm` into a repo with no credentials reports UNCONFIGURED and '
             'exits non-zero')
def _c05():
    tmp = fixture_repo()
    try:
        with _Captured() as cap:
            code = notifier.main(['notifier.py', 'send', '--confirm', '--repo-root', tmp])
        text = cap.out.getvalue()
        # EXIT 4, NOT 1, AND NOT 0. `daily_monitor.ps1` runs this every morning, and until the
        # owner creates the Control Room bot every WARN/INFO alert is UNCONFIGURED - so exiting
        # 1 would turn the daily chain red every single day, which is how a report gets muted
        # within a week (the ORDER-219 lesson, written in that same file). Exiting 0 would be a
        # silent skip. A distinct non-zero says "you have not set this up" without saying
        # "something broke".
        eq(code, 4, 'an unconfigured channel needs its OWN non-zero code:\n%s\n%s'
                    % (text, cap.err.getvalue()))
        if 'UNCONFIGURED' not in text:
            raise AssertionError(text)
        # On STDOUT: a status routed to stderr gets wrapped in a NativeCommandError by any
        # PowerShell caller that redirects, which buries it inside what reads as a crash.
        if 'NOT CONFIGURED' not in text:
            raise AssertionError('exit 4 must say what it means, on stdout: %s' % text)
        if 'NOT CONFIGURED' in cap.err.getvalue():
            raise AssertionError('the status went to stderr as well as stdout')
        rows = notifier.Ledger.load(os.path.join(tmp, notifier.LEDGER_REL)).rows
        if not rows:
            raise AssertionError('nothing was written to the ledger, so "did it arrive" is '
                                 'unanswerable for a run that really happened')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


@case('C08', 'a REAL delivery failure exits 1, so the daily chain does go red when it should')
def _c08():
    # The other half of C05. The exit-code split is only worth anything if the FAILED side still
    # marks the chain unhealthy - a scheme that never goes red is the muted report by a longer
    # route. Driven by making the configured transport raise.
    tmp = fixture_repo()
    saved = notifier.resolve_channels
    try:
        notifier.resolve_channels = lambda cfg: {'EMERGENCY': notifier.Credentials('t', ['1']),
                                                 'CONTROL_ROOM': notifier.Credentials('t', ['1'])}
        saved_transport = notifier.TelegramTransport
        notifier.TelegramTransport = lambda creds: Boom()
        try:
            with _Captured() as cap:
                code = notifier.main(['notifier.py', 'send', '--confirm', '--repo-root', tmp])
        finally:
            notifier.TelegramTransport = saved_transport
        eq(code, 1, 'a configured channel that could not deliver must fail the chain:\n%s'
                    % cap.out.getvalue())
        if 'FAILED' not in cap.out.getvalue():
            raise AssertionError(cap.out.getvalue())
    finally:
        notifier.resolve_channels = saved
        shutil.rmtree(tmp, ignore_errors=True)


# =======================================================================================
# ORDER-1261. Five defects on the alerting path, each REPRODUCED at HEAD before it was
# repaired, each repair carrying the control that a rule which simply refuses more would fail.
# #2 of the six is NOT here: it was measured at HEAD and found ALREADY CLOSED by ORDER-1267's
# `_secret_detail` work -- the leak message names the rule and the length and does not restate
# the value. Recorded as closed-by rather than as a fix, because nothing was written for it.
# =======================================================================================

@case('N01', 'ORDER-1261 #1 a finding that RECOVERED and came BACK is alerted again, not silenced')
def _n01():
    """
    Measured at HEAD: OPEN -> RESOLVED (recovery delivered) -> OPEN at unchanged severity and
    revision produced SUPPRESSED_DUPLICATE with problems=0, so the recurrence was invisible in
    the ledger AND in the exit code. `Ledger.delivered()` is the whole history with no bound.

    The repair is NOT a time window -- the order forbids that explicitly and it is right, a
    window is a guess about how long an incident lasts. It is the system's OWN recovery
    declaration: a finding it told the operator was over, that comes back, is a new incident.
    """
    ALL = dict((c, notifier.RecordingTransport()) for c in set(notifier.ROUTING.values()))
    recs = _walk_states([True, False, False, False, True, True])
    eq([r['state'] for r in recs],
       ['OPEN', 'HEALTHY_1_OF_2', 'RESOLVED', 'RESOLVED', 'OPEN', 'OPEN'],
       'the fixture no longer walks a recovery-then-recurrence')
    delivered, seen = set(), []
    for i, r in enumerate(recs):
        evs = notifier.plan([r], projection=None, now=at(i, 2))
        lines, _ = notifier.deliver(evs, delivered, ALL, at(i, 2), SENT)
        for l in lines:
            seen.append((r['state'], l['kind'], l['outcome']))
        delivered |= set((l['dedupe_key'], l['channel'])
                         for l in lines if l['outcome'] == 'DELIVERED')
    # THE DEFECT: the third message -- the recurrence -- used to be SUPPRESSED_DUPLICATE.
    eq(seen[2], ('OPEN', 'ALERT', 'DELIVERED'),
       'the recurrence after a delivered recovery was silenced: %s' % (seen,))
    # CONTROL 1: the REPEAT of that same incident is still suppressed. Without this, the repair
    # is satisfied by a key that never dedupes anything, which is alert spam wearing a fix.
    eq(seen[3], ('OPEN', 'ALERT', 'SUPPRESSED_DUPLICATE'),
       'the same incident now re-alerts on every run: %s' % (seen,))
    # CONTROL 2: the recovery itself is sent ONCE, across both RESOLVED observations. RESOLVED
    # persists while the finding stays absent, so a counter that incremented per RESOLVED line
    # would send two recovery messages -- measured that way round before the counter was written.
    eq(len([s for s in seen if s[1] == 'RECOVERY']), 1,
       'the recovery was emitted more than once: %s' % (seen,))


@case('N02', 'ORDER-1261 #1 the incident counter is derived from recovery, not from a clock')
def _n02():
    # The unit under the case above, driven directly so the boundary is attributable.
    hist = lambda states: [{'state': s} for s in states]
    eq(notifier.incident_seq(hist([]), 'OPEN'), 0, 'a first OPEN is incident 0')
    eq(notifier.incident_seq(hist(['OPEN', 'HEALTHY_1_OF_2']), 'RESOLVED'), 0,
       'reaching RESOLVED does not itself start a new incident')
    eq(notifier.incident_seq(hist(['OPEN', 'RESOLVED']), 'RESOLVED'), 0,
       'a SECOND RESOLVED observation is the same recovery, not a new incident')
    eq(notifier.incident_seq(hist(['OPEN', 'RESOLVED']), 'OPEN'), 1, 'coming back is incident 1')
    eq(notifier.incident_seq(hist(['OPEN', 'RESOLVED', 'OPEN']), 'OPEN'), 1,
       'staying open is still the same incident')
    eq(notifier.incident_seq(hist(['OPEN', 'RESOLVED', 'OPEN', 'RESOLVED']), 'OPEN'), 2,
       'a second recovery-and-return is incident 2')
    # BACKWARD COMPATIBILITY, and it is the reason the component is conditional: every key
    # already in the live ledger was written without it. Incident 0 must keep the key it has.
    k0 = notifier.dedupe_key('FP-x', 'OPEN', 'WARN', 0)
    eq(notifier.dedupe_key('FP-x', 'OPEN', 'WARN', 0, None, 0), k0,
       'incident 0 changed the key, which would re-alert every open finding once')
    if notifier.dedupe_key('FP-x', 'OPEN', 'WARN', 0, None, 1) == k0:
        raise AssertionError('incident 1 shares a key with incident 0')
    # ...and the state vocabulary is PARTITIONED, so a fifth state is a decision someone takes.
    states = set(notifier.REOPENING_STATES) | set(notifier.NON_REOPENING_STATES)
    produced = set()
    for streak in (0, 1, 2, 3):
        for occ in (0, 9):
            produced.add(control_center.fold_finding(
                {'id': 'F', 'class': 'RUNTIME', 'healthy_streak': streak,
                 'occurrences_24h': occ, 'previous_state': 'OPEN'})['state'])
    if not produced <= states:
        raise AssertionError('fold_finding can emit %s, which this module classifies as neither '
                             'reopening nor non-reopening' % sorted(produced - states))
    if set(notifier.REOPENING_STATES) & set(notifier.NON_REOPENING_STATES):
        raise AssertionError('a state is in both halves of the partition')


@case('N03', 'ORDER-1261 #3 the literal layer RUNS at the boundary that writes the ledger file')
def _n03():
    """
    Measured at HEAD: `safe_detail` passed `NO_KNOWN_SECRETS_AVAILABLE` unconditionally, so a
    bare account number in an error string was written to the ledger verbatim while the token
    control was caught. The declaration meant to make a missing input HONEST had become the
    reason the layer never ran -- `prohibition-disarms-its-own-check`.
    """
    secret = '900112233'
    err = 'connect failed for account %s' % secret
    # THE DEFECT: with the real list, as deliver() now passes it, the literal does not survive.
    out = notifier.safe_detail(err, [secret])
    if secret in out:
        raise AssertionError('the literal is still written into the ledger detail: %r' % out)
    if 'KNOWN_SECRET' not in out:
        raise AssertionError('the detail does not name the rule that withheld it: %r' % out)
    # CONTROL 1: the value-shape layer, which never needed a list, still fires on its own.
    if 'TELEGRAM_BOT_TOKEN' not in notifier.safe_detail(
            'bot token 7712345678:AAH9xQwErTyUiOpAsDfGhJkLzXcVbNm0'):
        raise AssertionError('the value-shape layer stopped firing')
    # CONTROL 2: safe_detail is NOT a blanket redactor -- an ordinary failure is untouched.
    eq(notifier.safe_detail('connection reset by peer', [secret]), 'connection reset by peer', '')
    # CONTROL 3: the DEFAULT still declares rather than pretending. A caller with nothing to
    # derive from must not silently get a scan that cannot run.
    eq(notifier.safe_detail(err), err, 'the default stopped being the declared no-op')
    # END TO END through deliver(), which is the boundary that actually writes the line.
    class Boom2(object):
        transport_kind = 'TELEGRAM'

        def send(self, channel, text):
            raise RuntimeError('socket to account %s died' % secret)
    evs = notifier.plan([rec(severity='CRITICAL', state='OPEN', pid='FP-1111111111')],
                        projection=None, now=at(1, 2))
    lines, _ = notifier.deliver(evs, set(), {'EMERGENCY': Boom2()}, at(1, 2),
                                known_secrets=[secret])
    if secret in json.dumps(lines[0], ensure_ascii=False):
        raise AssertionError('the ledger LINE carries the literal: %s' % lines[0])


@case('N04', 'ORDER-1261 #4 the seam is enforced by deliver() itself, not by call order')
def _n04():
    """
    Measured at HEAD: `deliver()` is in PUBLIC_API, called neither `assert_sendable` nor
    `scan_forbidden`, and put `ev['text']` on the wire directly. `imports_of()` cannot cover it,
    because everything it would need is already allowed to it.
    """
    secret = '900112233'
    ev = notifier.plan([rec(severity='CRITICAL', state='OPEN', pid='FP-3333333333')],
                       projection=None, now=at(1, 2))[0]
    ev['text'] = 'account %s is unwell' % secret
    try:
        notifier.deliver([ev], set(), {ev['channel']: notifier.RecordingTransport()}, at(1, 2),
                         known_secrets=[secret])
        raise AssertionError('a caller that skipped assert_sendable still delivered a literal')
    except safe_projection.ProjectionLeak as exc:
        if secret in str(exc):
            raise AssertionError('the refusal restates the value it caught: %s' % exc)
    # CONTROL: a clean event still goes through. A seam that refuses everything is an outage.
    clean = notifier.plan([rec(severity='CRITICAL', state='OPEN', pid='FP-4444444444')],
                          projection=None, now=at(1, 2))
    lines, _ = notifier.deliver(clean, set(), {'EMERGENCY': notifier.RecordingTransport()},
                                at(1, 2), known_secrets=[secret])
    eq(lines[0]['outcome'], 'DELIVERED', 'the seam refused a clean event')


@case('N05', 'ORDER-1261 #5 one torn line does not stop every later alert, and is not silent')
def _n05():
    """
    Measured at HEAD: an unguarded `json.loads` in both runtime readers raised BEFORE any
    delivery decision, so nothing was planned, sent, or recorded about why. These are
    append-only files written by a scheduled job on a machine that hibernates.
    """
    tmp = tempfile.mkdtemp(prefix='s12_torn_')
    try:
        p = os.path.join(tmp, 'alert_ledger.jsonl')
        io.open(p, 'w', encoding='utf-8').write(
            '{"entity":"AlertDelivery","dedupe_key":"a","channel":"EMERGENCY",'
            '"outcome":"DELIVERED"}\n'
            '{"entity":"AlertDelivery","dedupe_key":"b","chan\n')
        led = notifier.Ledger.load(p)
        # THE DEFECT: this used to raise JSONDecodeError.
        eq(len(led.rows), 1, 'the readable row was lost with the torn one')
        # ...and the torn line is COUNTED, never skipped in silence. `unreadable-input-must-
        # refuse-not-skip` is satisfied by REPORTING, not by stopping the alert path.
        eq(len(led.torn), 1, 'the torn line was skipped silently, which is the other failure')
        if 'line 2' not in led.torn[0]:
            raise AssertionError('the report does not say WHICH line: %s' % led.torn[0])
        # ...and the delivery it could still see is still deduped against.
        eq(led.delivered(), set([('a', 'EMERGENCY')]), 'the readable delivery was not usable')
        # CONTROL: a clean file reports nothing torn.
        io.open(p, 'w', encoding='utf-8').write(
            '{"entity":"AlertDelivery","dedupe_key":"a","channel":"EMERGENCY",'
            '"outcome":"DELIVERED"}\n')
        clean = notifier.Ledger.load(p)
        eq((len(clean.rows), len(clean.torn)), (1, 0), 'a clean file reported a torn line')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


@case('N06', 'ORDER-1261 #6 a credential that WAS working and is gone stops sharing a code with '
             '"not set up yet"')
def _n06():
    """
    Measured at HEAD: a channel with a past DELIVERED row, now absent from `transports`,
    produced the IDENTICAL outcome and the IDENTICAL detail as a channel that never existed --
    and that outcome routes to exit 4, which ORDER-219 deliberately mutes in the daily chain.
    The muting rationale is real and stays; what could not stay is the two situations sharing it.
    """
    led = notifier.Ledger([{'entity': 'AlertDelivery', 'dedupe_key': 'old|OPEN|CRITICAL|0',
                            'channel': 'EMERGENCY', 'outcome': 'DELIVERED', 'receipt': '1',
                            'transport_kind': 'TELEGRAM'}])
    evs = notifier.plan([rec(severity='REAL_MONEY', state='OPEN', pid='FP-9999999999')],
                        projection=None, now=at(1, 2))
    prev = led.credentialed_channels()
    lines, _ = notifier.deliver(evs, led.delivered(), {}, at(1, 2), SENT,
                                previously_configured=prev)
    eq(lines[0]['outcome'], 'UNCONFIGURED_REGRESSION',
       'a channel that was delivering yesterday still reads as never-provisioned')
    # CONTROL: the never-provisioned case is UNCHANGED, because ORDER-219's rationale still holds
    # for it -- it is true every day until the owner makes the bot, and it must not go red daily.
    lines2, _ = notifier.deliver(evs, set(), {}, at(1, 2), SENT,
                                 previously_configured=set())
    eq(lines2[0]['outcome'], 'UNCONFIGURED', 'the expected case stopped being the expected case')
    # ...and the two say different things to a human, not just to a switch statement.
    if lines[0]['detail'] == lines2[0]['detail']:
        raise AssertionError('the two situations still print the same sentence')


@case('N11', 'ORDER-1380 transport_kind prevents test delivery from creating credential history')
def _n11_transport_kind():
    evs = notifier.plan([rec(severity='REAL_MONEY', state='OPEN', pid='FP-8888888888')],
                        projection=None, now=at(1, 2))
    recording = notifier.RecordingTransport()
    lines, _ = notifier.deliver(evs, set(), {'EMERGENCY': recording}, at(1, 2), SENT)
    eq(lines[0]['outcome'], 'DELIVERED', 'recording transport did not produce delivery evidence')
    eq(lines[0]['transport_kind'], 'RECORDING', 'recording delivery was not labelled')
    ledger = notifier.Ledger(lines)
    eq(ledger.credentialed_channels(), set(),
       'RecordingTransport was incorrectly treated as credentialed history')

    missing, _ = notifier.deliver(evs, set(), {}, at(1, 2), SENT,
                                  previously_configured=ledger.credentialed_channels())
    eq(missing[0]['outcome'], 'UNCONFIGURED',
       'recording history incorrectly created UNCONFIGURED_REGRESSION')
    eq(missing[0]['transport_kind'], 'UNKNOWN', 'missing transport was not conservative UNKNOWN')

    # Legacy DELIVERED rows have no transport_kind and are therefore also conservative.
    legacy = notifier.Ledger([{'entity': 'AlertDelivery', 'dedupe_key': 'legacy',
                               'channel': 'EMERGENCY', 'outcome': 'DELIVERED', 'receipt': '1'}])
    eq(legacy.credentialed_channels(), set(),
       'legacy no-kind evidence was treated as proof of configured history')

    malformed = notifier.Ledger([{'entity': 'AlertDelivery', 'dedupe_key': 'bad',
                                  'channel': 'EMERGENCY', 'outcome': 'DELIVERED',
                                  'receipt': '1', 'transport_kind': 'FAKE'}])
    # Constructed rows are retained for callers that already have them; file reads refuse the
    # malformed wire value below. This keeps the in-memory model from silently laundering it.
    eq(malformed.credentialed_channels(), set(),
       'malformed in-memory kind was treated as credentialed history')
    tmp = tempfile.mkdtemp(prefix='s12_transport_kind_')
    try:
        path = os.path.join(tmp, 'ledger.jsonl')
        io.open(path, 'w', encoding='utf-8').write(
            '{"entity":"AlertDelivery","dedupe_key":"bad","channel":"EMERGENCY",'
            '"outcome":"DELIVERED","receipt":"1","transport_kind":"FAKE"}\n')
        loaded = notifier.Ledger.load(path)
        eq(len(loaded.rows), 0, 'malformed transport_kind was accepted from the wire')
        eq(len(loaded.torn), 1, 'malformed transport_kind was not reported as unreadable')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    class UnknownTransport(object):
        def send(self, channel, text):
            return 'x'
    bad_lines, bad_problems = notifier.deliver(
        evs, set(), {'EMERGENCY': UnknownTransport()}, at(1, 2), SENT)
    eq(bad_problems, 1, 'an unregistered transport did not refuse')
    eq(bad_lines[0]['outcome'], 'FAILED', 'an unregistered transport was treated as delivered')
    if 'malformed transport_kind' not in bad_lines[0]['detail']:
        raise AssertionError('malformed transport refusal did not name the contract failure')


# =======================================================================================
# The independent review of ORDER-1261's own repairs. Every case below is a defect that WAS
# IN THE REPAIR, reproduced before it was fixed. Three of the four are the same shape: a
# guard whose new argument, new value or new tolerance was not carried through to the place
# that consumes it.
# =======================================================================================

@case('N07', 'REVIEW deliver() cannot be called without answering the known_secrets question')
def _n07():
    """
    THE REPAIR HAD A HOLE AND MY OWN CASE WALKED AROUND IT. `deliver()` gained the literal scan
    for ORDER-1261 #4, with `known_secrets` DEFAULTED to the sentinel -- so a public caller that
    omitted it got a scan whose KNOWN_SECRET layer could not fire and the literal went out.
    Measured: `deliver()` with no list DELIVERED `account 900112233 is unwell`. N04 passed the
    list, i.e. it drove the repaired path and never the defaulted one
    (`falsifier-satisfied-by-unexercised-mechanism`).
    """
    secret = '900112233'
    ev = notifier.plan([rec(severity='CRITICAL', state='OPEN', pid='FP-bbbbbbbbbb')],
                       projection=None, now=at(1, 2))[0]
    ev['text'] = 'account %s is unwell' % secret
    # THE DEFECT: this call is now impossible to write. A missing argument is a TypeError, which
    # is the strongest form of "you may not reach the wire without deciding".
    try:
        notifier.deliver([ev], set(), {ev['channel']: notifier.RecordingTransport()}, at(1, 2))
        raise AssertionError('deliver() still has a default for known_secrets, so a caller can '
                             'reach the wire without answering the question')
    except TypeError:
        pass
    # CONTROL: the sentinel is still a legal answer -- declaring is not the same as forgetting.
    lines, _ = notifier.deliver(
        notifier.plan([rec(severity='CRITICAL', state='OPEN', pid='FP-cccccccccc')],
                      projection=None, now=at(1, 2)),
        set(), {'EMERGENCY': notifier.RecordingTransport()}, at(1, 2), SENT)
    eq(lines[0]['outcome'], 'DELIVERED', 'the sentinel stopped being a legal declaration')
    # ...and a BARE STRING that is not the sentinel is refused rather than iterated per character,
    # which is what a misplaced positional argument would otherwise become.
    refuses(lambda: safe_projection.scan_forbidden(['x'], 'NOT_RUNNING'), 'per CHARACTER')


@case('N08', 'REVIEW a torn journal may not lower the incident counter')
def _n08():
    """
    ORDER-1261 #5 made a torn line survivable; #1 recomputed the incident count from the readable
    lines. TOGETHER they undid each other: a journal missing its RESOLVED line recounts to 0,
    rebuilds the ORIGINAL dedupe key, and suppresses the reopen #1 exists to let through.
    Measured on the pre-repair revision: seq 1 with the line present, seq 0 with it torn.
    """
    full = [{'state': 'OPEN', 'incident_seq': 0}, {'state': 'RESOLVED', 'incident_seq': 0}]
    eq(notifier.incident_seq(full, 'OPEN'), 1, 'the baseline stopped counting')
    # THE DEFECT: the RESOLVED line is gone, but the count it produced was written down.
    torn_journal = [{'state': 'OPEN', 'incident_seq': 0}, {'state': 'OPEN', 'incident_seq': 1}]
    eq(notifier.incident_seq(torn_journal, 'OPEN'), 1,
       'a torn RESOLVED line reset the counter and re-suppressed the reopen')
    eq(notifier.incident_seq([{'state': 'OPEN', 'incident_seq': 5}], 'OPEN'), 5,
       'a stored count higher than the recomputed one was ignored')
    # CONTROL 1: it is a FLOOR, not a replacement -- a genuine second cycle still increments past
    # whatever was stored.
    two = [{'state': 'OPEN', 'incident_seq': 0}, {'state': 'RESOLVED', 'incident_seq': 0},
           {'state': 'OPEN', 'incident_seq': 1}, {'state': 'RESOLVED', 'incident_seq': 1}]
    eq(notifier.incident_seq(two, 'OPEN'), 2, 'the recomputation can no longer raise the floor')
    # CONTROL 2: a first incident is still 0, so the key of every open finding is unchanged.
    eq(notifier.incident_seq([], 'OPEN'), 0, 'a first OPEN stopped being incident 0')
    eq(notifier.incident_seq([{'state': 'OPEN'}], 'OPEN'), 0, 'a journal with no count moved')


@case('N09', 'REVIEW UNCONFIGURED_REGRESSION is in the closed vocabulary AND in the wire contract')
def _n09():
    """
    ORDER-1261 #6 invented an outcome and told neither the module's own closed tuple nor
    schemas.json's AlertDelivery enum. `deliver()` was appending a ledger row that both contracts
    refused to declare, and all 73 cases stayed green -- nothing crossed the two.
    """
    if 'UNCONFIGURED_REGRESSION' not in notifier.OUTCOMES:
        raise AssertionError('the module vocabulary does not declare it: %s'
                             % (notifier.OUTCOMES,))
    with io.open(os.path.join(ROOT, '_triage/factory_os/schemas.json'),
                 encoding='utf-8-sig') as fh:
        enum = json.load(fh)['$defs']['AlertDelivery']['properties']['outcome']['enum']
    eq(tuple(notifier.OUTCOMES), tuple(enum),
       'the module tuple and the wire enum disagree, which is how one of them goes stale')
    # ...and every outcome the module can actually WRITE is in it. Derived from the source, so a
    # seventh invented string is caught by this case rather than by a reader.
    import re as _re
    body = io.open(os.path.join(ROOT, '_triage/factory_os/notifier.py'),
                   encoding='utf-8').read().split('def deliver(')[1].split('\ndef ')[0]
    written = set(_re.findall(r"'outcome': '([A-Z_]+)'", body))
    if not written <= set(notifier.OUTCOMES):
        raise AssertionError('deliver() writes %s, which OUTCOMES does not declare'
                             % sorted(written - set(notifier.OUTCOMES)))


@case('N10', 'REVIEW valid JSON that is not a record is torn, not clean')
def _n10():
    """
    `read_jsonl` counted only the JSONDecodeError, so a `null` line PARSED, was reported clean,
    and took `.get` with it into `Ledger.delivered()`. An unreadable input that read as a
    readable one -- the exact failure the function was written to stop, one type down.
    """
    tmp = tempfile.mkdtemp(prefix='s12_null_')
    try:
        p = os.path.join(tmp, 'alert_ledger.jsonl')
        for bad, what in (('null', 'NoneType'), ('[1,2]', 'list'), ('3', 'int'),
                          ('"a string"', 'str')):
            io.open(p, 'w', encoding='utf-8').write(bad + '\n')
            led = notifier.Ledger.load(p)
            eq((len(led.rows), len(led.torn)), (0, 1), 'a %s line was accepted as a record' % what)
            led.delivered()          # must not raise
        # CONTROL: a real record still loads and is still usable for dedupe.
        io.open(p, 'w', encoding='utf-8').write(
            '{"entity":"AlertDelivery","dedupe_key":"a","channel":"EMERGENCY",'
            '"outcome":"DELIVERED"}\n')
        good = notifier.Ledger.load(p)
        eq((len(good.rows), len(good.torn)), (1, 0), 'a real record was called torn')
        eq(good.delivered(), set([('a', 'EMERGENCY')]), '')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


@case('C06', 'ACROSS TWO PROCESSES a probe is delivered ONCE and suppressed the second time')
def _c06():
    tmp = fixture_repo()
    try:
        rec_path = os.path.join(tmp, 'sent.jsonl')
        args = [PY, os.path.join(HERE, 'notifier.py'), 'probe', '--id', 'S12CAGE',
                '--channel', 'EMERGENCY', '--confirm', '--record', rec_path,
                '--repo-root', tmp]
        first = subprocess.run(args, capture_output=True, cwd=ROOT, env=CHILD_ENV)
        second = subprocess.run(args, capture_output=True, cwd=ROOT, env=CHILD_ENV)
        t1 = (first.stdout or b'').decode('utf-8', 'replace')
        t2 = (second.stdout or b'').decode('utf-8', 'replace')
        if 'DELIVERED' not in t1:
            raise AssertionError('first run did not deliver:\n%s\n%s'
                                 % (t1, (first.stderr or b'').decode('utf-8', 'replace')))
        if 'SUPPRESSED_DUPLICATE' not in t2:
            ledger = os.path.join(tmp, notifier.LEDGER_REL)
            on_disk = (io.open(ledger, encoding='utf-8-sig').read()
                       if os.path.exists(ledger) else '<<the ledger file does not exist>>')
            raise AssertionError(
                'the SECOND PROCESS re-sent a message the ledger already had. In-process dedupe '
                'would have hidden this.\n  run1 stdout: %s\n  run1 stderr: %s\n  run2 stdout: %s'
                '\n  run2 stderr: %s\n  ledger on disk: %s'
                % (t1.strip(), (first.stderr or b'').decode('utf-8', 'replace').strip(),
                   t2.strip(), (second.stderr or b'').decode('utf-8', 'replace').strip(),
                   on_disk.strip()))
        sent = [l for l in io.open(rec_path, encoding='utf-8').read().splitlines() if l.strip()]
        eq(len(sent), 1, 'exactly one message really left the process, across two runs')
        hit('kind:DELIVERY_PROBE')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


# =======================================================================================
# ROLL-UPS. Two, because they are two claims.
# =======================================================================================

def rollups(cases_at_start):
    problems = []
    print('\n--- ROLL-UP 1 / COVERAGE: which case first produced each behaviour ---')
    for bucket in sorted(COVERAGE):
        who = COVERAGE[bucket]
        print('    %-34s %s' % (bucket, who or 'NOBODY'))
        if who is None:
            problems.append('nothing in this suite ever produced `%s`, so the branch that '
                            'handles it is UNTESTED (CLAUDE.md bar table)' % bucket)
    print('\n--- ROLL-UP 2 / REACHABILITY: every catalogued case ran ---')
    catalogued = [c[0] for c in CASES]
    missing = [c for c in catalogued if c not in RAN]
    print('    catalogued %d · ran %d · counted BEFORE any fixture could top it up (%d at the '
          'moment the catalogue closed)' % (len(catalogued), len(RAN), cases_at_start))
    if missing:
        problems.append('catalogued but never ran: %s' % ', '.join(missing))
    if len(catalogued) != cases_at_start:
        problems.append('the catalogue grew after it was measured (%d -> %d), so the coverage '
                        'roll-up above was read against a different set of cases than ran'
                        % (cases_at_start, len(catalogued)))
    dupes = sorted(set(c for c in catalogued if catalogued.count(c) > 1))
    if dupes:
        problems.append('duplicate case id(s): %s - two cases under one id means one of them is '
                        'invisible in both roll-ups' % ', '.join(dupes))
    return problems


def main():
    # The counter is read HERE, before a single case has run and before any fixture exists that
    # could top it up. memory: completeness-rollup-measured-after-topup - a roll-up measured
    # after the top-up is green forever and hides exactly what it claims to check.
    cases_at_start = len(CASES)
    print('[s12] %d catalogued case(s)' % cases_at_start)
    run_all()
    problems = rollups(cases_at_start)
    for p in problems:
        print('  ROLL-UP PROBLEM: %s' % p)
    print('\n[s12] %d scenario(s), %d failed, %d roll-up problem(s)'
          % (len(RAN), len(FAILED), len(problems)))
    return 1 if (FAILED or problems) else 0


if __name__ == '__main__':
    if '--list' in sys.argv:
        for cid, what, _ in CASES:
            print('%-6s %s' % (cid, what))
        print('%d case(s)' % len(CASES))
        sys.exit(0)
    sys.exit(main())
