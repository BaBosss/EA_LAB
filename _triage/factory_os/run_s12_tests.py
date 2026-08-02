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
import safe_projection                                       # noqa: E402
import snapshot_validator                                    # noqa: E402

PY = sys.executable

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


@case('V01', 'OPEN -> HEALTHY_1_OF_2 -> OPEN emits NO recovery message')
def _v01():
    states = _walk_states([True, False, True])
    eq([s['state'] for s in states], ['OPEN', 'HEALTHY_1_OF_2', 'OPEN'], '')
    eq([s['recovery_emitted'] for s in states], [False, False, False],
       'an intermediate healthy check is not a recovery; calling it one is the flapping spam '
       'the two-check rule exists to stop')
    for s in states:
        eq([e['kind'] for e in notifier.plan([s], PROJECTION)], ['ALERT'], '')


@case('V02', 'a genuine recovery emits EXACTLY ONE recovery message, and never a second')
def _v02():
    states = _walk_states([True, False, False, False])
    eq([s['state'] for s in states], ['OPEN', 'HEALTHY_1_OF_2', 'RESOLVED', 'RESOLVED'], '')
    eq([s['recovery_emitted'] for s in states], [False, False, True, False],
       'exactly one, and it is fold_finding that decides - not a second rule in the sender')
    kinds = [e['kind'] for s in states for e in notifier.plan([s], PROJECTION)]
    eq(kinds, ['ALERT', 'ALERT', 'RECOVERY'],
       'the fourth observation is RESOLVED with no recovery, so it produces NO event at all')
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
    def send(self, channel, text):
        raise RuntimeError('send rejected, request carried %s' % FAKE_TOKEN)


@case('L01', 'a first delivery is DELIVERED and carries a receipt')
def _l01():
    t = notifier.RecordingTransport()
    lines, problems = notifier.deliver(notifier.plan([rec(severity='WARN')], PROJECTION),
                                       set(), {'CONTROL_ROOM': t}, 't', 'NOT_RUNNING')
    eq([l['outcome'] for l in lines], ['DELIVERED'], '')
    eq(problems, 0, '')
    eq(len(t.sent), 1, '')
    if not lines[0]['receipt']:
        raise AssertionError('a DELIVERED line with no receipt cannot answer "did it arrive"')
    hit('outcome:DELIVERED')
    hit('openclaw:NOT_RUNNING')


@case('L02', 'a replay of an already-DELIVERED key sends NOTHING and says so')
def _l02():
    t = notifier.RecordingTransport()
    events = notifier.plan([rec(severity='WARN')], PROJECTION)
    delivered = set()
    notifier.deliver(events, delivered, {'CONTROL_ROOM': t}, 't', 'NOT_RUNNING')
    lines, problems = notifier.deliver(events, delivered, {'CONTROL_ROOM': t}, 't', 'NOT_RUNNING')
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
    notifier.deliver([ev], delivered, {'CONTROL_ROOM': t, 'EMERGENCY': t}, 't', 'NOT_RUNNING')
    lines, _ = notifier.deliver([other], delivered, {'CONTROL_ROOM': t, 'EMERGENCY': t},
                                't', 'NOT_RUNNING')
    eq([l['outcome'] for l in lines], ['DELIVERED'],
       'a per-channel ledger keyed only on the event would silence the second bot')


@case('L04', 'a FAILED attempt is RETRIED next run - dedupe reads DELIVERED and nothing else')
def _l04():
    ev = notifier.plan([rec(severity='WARN')], PROJECTION)
    delivered = set()
    lines, problems = notifier.deliver(ev, delivered, {'CONTROL_ROOM': Boom()}, 't', 'UNKNOWN')
    eq([l['outcome'] for l in lines], ['FAILED'], '')
    eq(problems, 1, 'a failure that does not raise the problem count is a silent no-send')
    t = notifier.RecordingTransport()
    lines2, _ = notifier.deliver(ev, delivered, {'CONTROL_ROOM': t}, 't', 'NOT_RUNNING')
    eq([l['outcome'] for l in lines2], ['DELIVERED'],
       'suppressing a retry after a failure loses the alert entirely')
    hit('outcome:FAILED')
    hit('openclaw:UNKNOWN')


@case('L05', 'an UNCONFIGURED channel is a STATED failure with a non-zero problem count')
def _l05():
    ev = notifier.plan([rec(severity='WARN')], PROJECTION)
    lines, problems = notifier.deliver(ev, set(), {'CONTROL_ROOM': None}, 't', 'NOT_RUNNING')
    eq([l['outcome'] for l in lines], ['UNCONFIGURED'], '')
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
    lines, problems = notifier.deliver(ev, set(), {'CONTROL_ROOM': Boom()}, 't', 'NOT_RUNNING')
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
                                    't', 'NOT_RUNNING')
        ledger.append(path, lines)
        again = notifier.Ledger.load(path)
        eq(len(again.delivered()), 1, 'a ledger that does not survive a reload is a sent-set')
        lines2, _ = notifier.deliver(ev, again.delivered(),
                                     {'CONTROL_ROOM': notifier.RecordingTransport()},
                                     't', 'NOT_RUNNING')
        eq([l['outcome'] for l in lines2], ['SUPPRESSED_DUPLICATE'], '')
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
                                    at(0), 'NOT_RUNNING')
        eq([l['outcome'] for l in lines], ['FAILED'], '')
        ledger.append(path, lines)

        reloaded = notifier.Ledger.load(path)
        eq(reloaded.delivered(), set(),
           'a FAILED attempt recorded as delivered means the next run stays silent about an '
           'alert that never arrived')
        t = notifier.RecordingTransport()
        lines2, _ = notifier.deliver(ev, reloaded.delivered(), {'CONTROL_ROOM': t},
                                     at(1), 'NOT_RUNNING')
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
                                    at(0), 'NOT_RUNNING')
        ledger.append(path, lines)
        eq(notifier.Ledger.load(path).delivered(), set(),
           'the Control Room bot does not exist yet, so every alert to it is UNCONFIGURED - '
           'suppressing those would mean nothing is ever sent once the bot IS created')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


@case('S01', 'a sender is refused the FULL SNAPSHOT by path, before its bytes are opened')
def _s01():
    refuses(lambda: safe_projection.read_for_sender(
        os.path.join(ROOT, safe_projection.SNAPSHOT_REL), ROOT), 'may read only')


@case('S02', 'an event with an UNDECLARED field is refused for being undeclared')
def _s02():
    ev = notifier.plan([rec()], PROJECTION)
    ev[0]['finding_id'] = 'FND-sensor-159503454'
    refuses(lambda: notifier.assert_sendable(ev, (), ROOT), 'not declared')
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
    notifier.assert_sendable(ev, (), ROOT)
    hit('scan:KNOWN_SECRET')


@case('S04', 'a local filesystem path in the text is caught wherever it appears')
def _s04():
    ev = notifier.plan([rec()], PROJECTION)
    ev[0]['text'] = 'could not read D:\\EA_LAB\\portfolio\\control_room_snapshot.json'
    refuses(lambda: notifier.assert_sendable(ev, (), ROOT), 'WINDOWS_ABSOLUTE_PATH',
            kinds=(safe_projection.ProjectionLeak,))
    hit('scan:WINDOWS_ABSOLUTE_PATH')


@case('S05', 'a bot token pasted into a message is caught before it is sent')
def _s05():
    ev = notifier.plan([rec()], PROJECTION)
    ev[0]['text'] = 'using 1234567890:AAHfakefakefakefakefakefakefakefake12'
    refuses(lambda: notifier.assert_sendable(ev, (), ROOT), 'TELEGRAM_BOT_TOKEN',
            kinds=(safe_projection.ProjectionLeak,))
    hit('scan:TELEGRAM_BOT_TOKEN')


@case('S06', 'material_revision is CHECKED as an integer - the construct S11 refused rather '
             'than passed')
def _s06():
    ev = notifier.plan([rec()], PROJECTION)
    ev[0]['material_revision'] = '2'
    refuses(lambda: notifier.assert_sendable(ev, (), ROOT), 'must be integer')
    hit('scan:SHAPE_INTEGER')


@case('S07', 'a boolean does not satisfy type:integer, even though bool IS int in python')
def _s07():
    ev = notifier.plan([rec()], PROJECTION)
    ev[0]['material_revision'] = True
    refuses(lambda: notifier.assert_sendable(ev, (), ROOT), 'must be integer')


@case('S08', 'the declared `minimum` is enforced, not silently dropped along with the type')
def _s08():
    ev = notifier.plan([rec()], PROJECTION)
    ev[0]['material_revision'] = -1
    refuses(lambda: notifier.assert_sendable(ev, (), ROOT), 'must be >=')


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
        lines, problems = notifier.deliver(ev, set(), {'EMERGENCY': t}, 't', state)
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
    notifier.assert_sendable(ev, (), ROOT)
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
        eq(code, 1, 'an unconfigured channel must not exit 0:\n%s\n%s' % (text, cap.err.getvalue()))
        if 'UNCONFIGURED' not in text:
            raise AssertionError(text)
        rows = notifier.Ledger.load(os.path.join(tmp, notifier.LEDGER_REL)).rows
        if not rows:
            raise AssertionError('nothing was written to the ledger, so "did it arrive" is '
                                 'unanswerable for a run that really happened')
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
