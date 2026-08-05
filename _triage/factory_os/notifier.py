"""
notifier.py - ORDER-1180 (slice S12). The direct Telegram sender and the Morning Brief.

WHAT THIS IS
  The alert path, end to end, with ONE hard seam in the middle:

    LOCAL SIDE   observe() and plan(). Has the verified snapshot, the finding journal and the
                 internal finding ids. Computes the dedupe key - INCLUDING material_revision,
                 which is not on the SafeProjection and therefore cannot be computed from it.
                 Runs the KNOWN-SECRET scan, which only this side can run, because only this
                 side has the snapshot the secret list is derived from.

    SENDER SIDE  deliver(). Has AlertEvents and nothing else. Obtains the projection through
                 safe_projection.read_for_sender() - the one reader - and never sees the
                 snapshot. It cannot leak what it was never handed.

  design 7.3 rev 3 fixed the seam and this file is the seam made real:
  "Telegram and the online page read only the SafeProjection, and the sender has no path to the
  full snapshot at all."

THE PROHIBITION THAT DISARMS ITS OWN CHECK, AND WHERE IT LANDS HERE
  S11 found it the hard way: taking the snapshot away from the sender emptied the KNOWN_SECRET
  layer of scan_forbidden(), because that layer's input IS the snapshot. S11 answered on the
  sender side by checking the SHAPE against schemas.json. S12 answers on the OTHER side as well:
  the planner still has the snapshot, so assert_sendable() runs the full scan WITH the real
  secret list before an event is ever handed across the seam. The two halves check different
  things - shape on the far side, literals on the near side - and neither is a substitute.
  (memory: prohibition-disarms-its-own-check)

FOUR THINGS design 10 REQUIRES OF THIS SLICE, and where each one lives
  1. Alerts work with OpenClaw stopped        -> openclaw_state() MEASURES it and the ledger
                                                 records what was observed next to the receipt.
                                                 imports_of() proves the path cannot reach it.
  2. Dedupe on severity AND material_revision -> dedupe_key(), and observe() is what produces a
                                                 material_revision at all.
  3. A per-channel delivery ledger            -> Ledger, (dedupe_key, channel, outcome, receipt).
  4. One recovery, escalation never swallowed -> control_center.fold_finding, CALLED not copied.

WHAT THIS FILE REFUSES TO DO
  - It builds no second projection and opens no second snapshot reader. safe_projection owns both.
  - It computes NO drawdown, no percentage, no threshold. design 7.1: "the dashboard creates no
    competing threshold". Today every dd_pct_band reads UNKNOWN because no detector publishes
    one, and the Morning Brief says exactly that instead of deriving a number.
  - It never returns a benign default for an input it does not recognise. An unrouted severity,
    an unknown reason code and an unreadable process list are each a STATED failure. A sender
    that cannot send and reports nothing is indistinguishable from a quiet fleet.

USAGE   tools\\python312\\python.exe _triage/factory_os/notifier.py plan
        tools\\python312\\python.exe _triage/factory_os/notifier.py send --confirm
        tools\\python312\\python.exe _triage/factory_os/notifier.py probe --id X --channel EMERGENCY --confirm
TESTS   tools\\python312\\python.exe _triage/factory_os/run_s12_tests.py
"""
import hashlib
import io
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import control_center                         # noqa: E402  - fold_finding lives there, once
import safe_projection                        # noqa: E402  - the ONE projection + the ONE reader
import snapshot_validator                     # noqa: E402  - the ONE full-snapshot reader

ENTITY_EVENT = 'AlertEvent'
ENTITY_DELIVERY = 'AlertDelivery'

LEDGER_REL = 'ops/delivery_ledger.jsonl'
JOURNAL_REL = 'ops/finding_journal.jsonl'
CONFIG_REL = 'scripts/config.yaml'

# The token placeholder the committed example file carries. A config still holding it is NOT
# configured, and saying so is the whole point - mris_notify.ps1 treats the same string the
# same way and this module must not disagree with it.
PLACEHOLDER_TOKEN = 'PLACEHOLDER_TELEGRAM_BOT_TOKEN'


class NotifyRefusal(Exception):
    """An input this module will not act on. Never a silent no-send."""


def _refuse(msg):
    raise NotifyRefusal(msg)


# ---------------------------------------------------------------------------------------
# ROUTING. Owner decision 2026-08-02, taken as a costed table rather than guessed.
# ---------------------------------------------------------------------------------------
# The owner chose the design-literal split after being shown the measurement that makes the
# alternative look safer than it is: the whole REASON_SEVERITY table can produce CRITICAL (2
# codes), WARN (9) and INFO (2), and NOTHING can produce REAL_MONEY today. Routing only
# REAL_MONEY to the emergency bot would therefore have given that channel zero reachable
# events - `UNTESTED` by CLAUDE.md's own bar table - while a BLIND sensor on a real-money
# account went to the quiet channel, which is the S11 round-1 defect wearing a different hat.
#
# CLOSED. A severity that is not a key here REFUSES. It does not fall through to the quiet
# channel and it does not fall through to no channel at all: "an unhandled case must not render
# as the satisfied one", and a silently unrouted alert is the loudest version of that.
ROUTING = {
    'REAL_MONEY': 'EMERGENCY',
    'CRITICAL': 'EMERGENCY',
    'WARN': 'CONTROL_ROOM',
    'INFO': 'CONTROL_ROOM',
}
CHANNELS = ('EMERGENCY', 'CONTROL_ROOM')

# The Morning Brief is never an emergency. design 7.3 puts it on the Control Room bot by name.
BRIEF_CHANNEL = 'CONTROL_ROOM'

KINDS = ('ALERT', 'RECOVERY', 'MORNING_BRIEF', 'DELIVERY_PROBE')

# States that produce NO message at all. `RESOLVED` is handled separately because it is where a
# recovery is emitted from; this set is for states that are neither news nor a resolution.
# See plan() for why HEALTHY_1_OF_2 is here - it is the difference between meeting design 7.3's
# letter and meeting its point.
SILENT_STATES = ('HEALTHY_1_OF_2',)

# ORDER-1261 #1. The states that mean THE FINDING IS BACK -- i.e. the ones that end a recovery
# and start a new incident. Not a list of names someone liked: it is one half of a partition of
# every state `control_center.fold_finding` can emit, and `run_s12_tests.py` asserts the two
# halves cover that set exactly, so a FIFTH state is a decision someone takes rather than a
# silent default. The other half is "the finding is absent or was declared over"
# (`HEALTHY_1_OF_2`, `RESOLVED`), and neither of those reopens anything.
REOPENING_STATES = ('OPEN', 'FLAPPING')
NON_REOPENING_STATES = ('HEALTHY_1_OF_2', 'RESOLVED')
# ORDER-1261 #6 added UNCONFIGURED_REGRESSION and the first version of that repair did NOT add it
# here or to schemas.json's AlertDelivery enum -- so `deliver()` was appending a ledger row that
# its own module vocabulary and the wire contract both refused to declare, and every suite stayed
# green. Found by an independent review of the change. A new outcome is a change to a CONTRACT,
# not a new string literal.
OUTCOMES = ('DELIVERED', 'SUPPRESSED_DUPLICATE', 'UNCONFIGURED', 'UNCONFIGURED_REGRESSION',
            'FAILED')

# Reason code -> finding class, so control_center.fold_finding can apply design 7.1's lifecycle.
# Only RUNTIME auto-resolves, which is why the split matters: a stale mandatory source really
# does heal by itself and a coverage mismatch really does not.
#
# This map's key set is asserted EQUAL to safe_projection.REASON_SEVERITY's by
# assert_reason_maps_agree(). Two hand-maintained maps over one vocabulary is the drift shape
# this repo has paid for repeatedly; the equality is checked rather than intended.
REASON_CLASS = {
    'MANDATORY_SOURCE_MISSING': 'RUNTIME',
    'MANDATORY_SOURCE_UNREADABLE': 'RUNTIME',
    'MANDATORY_SOURCE_STALE': 'RUNTIME',
    'SOURCE_REGISTRY_MISMATCH': 'GOVERNANCE',
    'DUPLICATE_SOURCE_NAME': 'GOVERNANCE',
    'SOURCE_MANDATORY_FLAG_CONTRADICTS_REGISTRY': 'GOVERNANCE',
    'DISCOVERED_CATEGORIZED_MISMATCH': 'AUDIT',
    'CATEGORY_SUM_MISMATCH': 'AUDIT',
    'COVERAGE_SUM_MISMATCH': 'AUDIT',
    'DUPLICATES_PRESENT': 'AUDIT',
    'CONFLICTS_PRESENT': 'AUDIT',
    'UNCLASSIFIED_PRESENT': 'AUDIT',
    'ACTIONABLE_PRESENT': 'AUDIT',
}


def assert_reason_maps_agree():
    """
    The two maps over one vocabulary must have the SAME keys.

    A code with a severity and no class would raise inside fold_finding at 3am; a code with a
    class and no severity would refuse the whole projection build. Both are reachable only by
    someone editing one map and not the other, which is why this is a check and not a comment.
    """
    sev = set(safe_projection.REASON_SEVERITY)
    cls = set(REASON_CLASS)
    if sev != cls:
        _refuse('REASON_SEVERITY and REASON_CLASS disagree about the reason-code vocabulary: '
                'severity-only=%s class-only=%s. One code known to one map and not the other is '
                'a finding that either cannot be routed or cannot be folded.'
                % (sorted(sev - cls), sorted(cls - sev)))
    return True


# ---------------------------------------------------------------------------------------
# OPENCLAW. design 7.3: out of the alert path entirely. Two independent claims, because they
# are two different statements and one does not imply the other.
# ---------------------------------------------------------------------------------------

# Process names that mean the gateway is up. AGENTS.md names the agents; the gateway itself
# runs them.
OPENCLAW_PROCESS_NAMES = ('openclaw', 'oc-mgr', 'oc-dev', 'oc-btest', 'oc-qwen')

# Every module the alert path is permitted to pull in, INCLUDING what those pull in from this
# repo. Not a blacklist of gateway names: a blacklist of names has no end, and a text scan for
# "openclaw" cannot tell a call from the sentence in this docstring explaining that there is no
# call (memory: text-scan-cannot-tell-read-from-mention). An allowlist of imports is decidable,
# and an import node in the AST is unambiguously a READ.
ALLOWED_IMPORTS = frozenset((
    # standard library the path genuinely uses, across all four modules in the closure
    'ast', 'collections', 'copy', 'datetime', 'hashlib', 'io', 'json', 'os', 're',
    'subprocess', 'sys', 'tempfile',
    'urllib', 'urllib.request', 'urllib.error', 'urllib.parse',
    # this repo, and only the three modules that own a boundary
    'control_center', 'safe_projection', 'snapshot_validator',
))

# The closure the allowlist is checked over: this module and every repo module it reaches.
# Named here so the cage cannot quietly check a smaller set than the path actually uses.
IMPORT_CLOSURE = ('notifier', 'safe_projection', 'control_center', 'snapshot_validator')


def openclaw_state(lister=None):
    """
    -> 'RUNNING' | 'NOT_RUNNING' | 'UNKNOWN'. A MEASUREMENT, recorded beside the receipt.

    UNKNOWN is a real third answer and is NOT collapsed onto NOT_RUNNING, even though
    NOT_RUNNING is the answer this slice wants to hear. That collapse is precisely the shape
    this repo keeps paying for: the benign-looking value standing in for "could not tell".
    A ledger line claiming delivery happened with the gateway down, written by code that could
    not actually see the process list, would be a fabricated observation.
    (memory: unreadable-input-must-refuse-not-skip)

    `lister` is injectable so the cage can drive all three answers. Nothing in the alert path
    depends on the ANSWER - the path runs identically either way, which is the acceptance.
    """
    if lister is None:
        lister = _tasklist
    try:
        names = lister()
    except Exception as exc:                                # noqa: BLE001 - reported, not swallowed
        return 'UNKNOWN'
    if names is None:
        return 'UNKNOWN'
    low = [str(n).lower() for n in names]
    for want in OPENCLAW_PROCESS_NAMES:
        for name in low:
            if want in name:
                return 'RUNNING'
    return 'NOT_RUNNING'


def _tasklist():
    out = subprocess.check_output(['tasklist', '/fo', 'csv', '/nh'],
                                  stderr=subprocess.STDOUT)
    text = out.decode('utf-8', 'replace')
    return [line.split(',')[0].strip('" ') for line in text.splitlines() if line.strip()]


def imports_of(source, filename='<source>'):
    """
    Every module name `source` imports, from the AST. Not a text scan.

    Used by the cage against this file and the three repo modules it imports, crossed with
    ALLOWED_IMPORTS. That is how "OpenClaw is not in the alert path" becomes a checkable
    property of a closed declaration instead of a sentence in a handoff.
    """
    import ast
    names = set()
    tree = ast.parse(source, filename)
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                names.add(alias.name)
        elif isinstance(node, ast.ImportFrom):
            if node.level:
                continue
            if node.module:
                names.add(node.module)
    return names


# ---------------------------------------------------------------------------------------
# THE LOCAL SIDE. Has the snapshot; produces records that carry internal ids.
# ---------------------------------------------------------------------------------------

def payload_digest(code, detail, cls):
    """
    What "materially changed" MEANS, written down.

    SEVERITY IS DELIBERATELY NOT IN HERE. If it were, material_revision would bump on every
    severity change and the two dedupe-key fields would be redundant - and the bug design 7.3
    names (a WARN that escalates to REAL_MONEY while the state stays OPEN) would be caught
    twice by accident rather than once on purpose. Keeping them independent is what lets case
    ESC1 drive a severity change with an UNCHANGED payload and watch the key move anyway.
    """
    raw = '%s|%s|%s' % (code, detail, cls)
    return hashlib.sha256(raw.encode('utf-8')).hexdigest()[:16]


def internal_id(code, detail):
    """
    The internal finding id. It may embed an account, a magic or an EA name - that is exactly
    what schemas.json says about SystemFinding.finding_id - so it lives in ops/ and NOWHERE
    else. safe_projection.public_id() is the only thing derived from it that may travel, and
    this module calls that function rather than re-deriving the hash, so the public id on
    Telegram and the public id on the dashboard cannot drift apart.
    """
    return '%s|%s' % (code, detail)


def findings_of(snapshot):
    """The verdict's refusal reasons as local finding records. Refuses an unknown code."""
    assert_reason_maps_agree()
    out = []
    for reason in (snapshot.get('verdict') or {}).get('reasons', []) or []:
        code = reason.get('code')
        if code not in REASON_CLASS:
            _refuse('reason code %r has no class in REASON_CLASS, so its lifecycle cannot be '
                    'folded. Refusing rather than defaulting it to RUNTIME: RUNTIME is the only '
                    'class that auto-resolves, so the safe-looking default is the one that '
                    'closes a governance finding nobody reviewed.' % code)
        detail = reason.get('detail')
        out.append({
            'finding_id': internal_id(code, detail),
            'code': code,
            'detail': detail,
            'severity': safe_projection.REASON_SEVERITY[code],
            'class': REASON_CLASS[code],
        })
    return out


TIME_FORMAT = '%Y-%m-%dT%H:%M:%S'
RECURRENCE_WINDOW_HOURS = 24


def parse_at(value, where):
    """
    A journal timestamp, or a REFUSAL naming where it came from.

    An unparseable `at` is not skipped and is not treated as "long ago". Skipping it would make
    FLAPPING quietly unreachable - the state whose entire job is to stop a recurring incident
    being reported as N separate ones - and treating it as long ago would do the same thing more
    slowly. (memory: unreadable-input-must-refuse-not-skip)
    """
    import datetime
    try:
        return datetime.datetime.strptime(str(value)[:19], TIME_FORMAT)
    except (TypeError, ValueError):
        _refuse('the journal timestamp %r at %s is not %s, so the 24h recurrence window cannot '
                'be computed. Refusing rather than dropping the line: a dropped observation '
                'makes FLAPPING unreachable, and FLAPPING is the state that stops one recurring '
                'incident being alerted as five separate ones.' % (value, where, TIME_FORMAT))


def _recurrences(history, present_now, now):
    """
    How many times this finding has RECURRED inside the window - not how many times it has been
    observed.

    The difference is the whole meaning of the state. A finding that is continuously open and
    sampled hourly would reach three "observations" before lunch and be collapsed into
    `FLAPPING - root cause required`, which is a different and wrong statement about it. A
    RECURRENCE is an observation where the finding is present and the observation before it was
    not - plus its very first appearance. That is what "3 recurrences in 24h" means in design 7.3.
    """
    cutoff = now - __import__('datetime').timedelta(hours=RECURRENCE_WINDOW_HOURS)
    count = 0
    was_present = None
    for line in history:
        at = parse_at(line.get('at'), 'journal line for %s' % line.get('finding_id'))
        appeared = bool(line.get('present')) and not was_present
        if appeared and at >= cutoff:
            count += 1
        was_present = bool(line.get('present'))
    if present_now and not was_present:
        count += 1
    return count


def observe(previous, current, now):
    """
    PURE. (journal lines so far, findings in THIS snapshot, timestamp) -> (records, new lines).

    This is where material_revision comes from, and it has to come from somewhere local:
    the SafeProjection carries public_id/severity/state and nothing else, so the dedupe key
    design 7.3 mandates CANNOT be computed from the projection alone. Naming that gap here,
    with the store that closes it, is the point.

    A finding present in this snapshot resets the healthy streak. A finding the journal has
    seen before and this snapshot does NOT carry is a healthy check - which is the only way
    healthy_streak ever grows, and therefore the only way a recovery is ever emitted.
    """
    now_dt = parse_at(now, 'the `now` handed to observe()')
    last = {}
    history = {}
    for line in previous:
        fid = line.get('finding_id')
        if not fid:
            continue
        last[fid] = line
        history.setdefault(fid, []).append(line)

    by_id = dict((f['finding_id'], f) for f in current)
    ids = list(by_id)
    for fid in last:
        if fid not in by_id:
            ids.append(fid)

    records = []
    lines = []
    for fid in ids:
        prev = last.get(fid)
        present = fid in by_id
        occ = _recurrences(history.get(fid, []), present, now_dt)
        if present:
            f = by_id[fid]
            digest = payload_digest(f['code'], f['detail'], f['class'])
            severity, cls = f['severity'], f['class']
            streak = 0
        else:
            # The journal is the only thing that still knows this finding exists. Its payload
            # cannot have changed - it is not being reported - so the digest and revision are
            # carried forward unchanged. A bump here would invent a revision out of absence.
            digest = prev.get('payload_digest')
            severity, cls = prev.get('severity'), prev.get('class')
            streak = (prev.get('healthy_streak') or 0) + 1

        if prev is None:
            revision = 0
        elif prev.get('payload_digest') != digest:
            revision = (prev.get('material_revision') or 0) + 1
        else:
            revision = prev.get('material_revision') or 0

        folded = control_center.fold_finding({
            'id': fid,
            'class': cls,
            'healthy_streak': streak,
            'occurrences_24h': occ,
            'previous_state': (prev or {}).get('state') or 'OPEN',
        })
        record = {
            'finding_id': fid,
            'public_id': safe_projection.public_id(fid),
            'severity': severity,
            'class': cls,
            'state': folded['state'],
            # ORDER-1261 #1: which incident this is, counted from the journal's own recovery
            # declarations. Computed here rather than in dedupe_key() because `history` is the
            # only place it exists, and the key function is pure over its arguments.
            'incident_seq': incident_seq(history.get(fid, []), folded['state']),
            'recovery_emitted': bool(folded.get('recovery_emitted')),
            'material_revision': revision,
            'healthy_streak': streak,
            'occurrences_24h': occ,
            'present': present,
            'payload_digest': digest,
        }
        records.append(record)
        line = dict(record)
        line['entity'] = 'FindingObservation'
        line['at'] = now
        del line['recovery_emitted']
        lines.append(line)
    return records, lines


def incident_seq(history, current_state):
    """How many times this finding has ALREADY recovered and come back. ORDER-1261 #1.

    THE DESIGN QUESTION THE ORDER REFUSES TO LET ANYONE SKIP: what is a DISTINCT INCIDENT? The
    row is explicit that a 24h window would only move the boundary, and it is right -- a window
    is a guess about how long an incident lasts, and this system already knows the answer to a
    better question.

    IT IS NOT A TIME WINDOW. It is the system's own recovery declaration. A finding that reaches
    `RESOLVED` has been declared over BY THIS MODULE -- a recovery message was emitted and the
    operator was told it was finished. When it comes back, that is a NEW incident by the system's
    own account, not a repeat of the one it just closed. Anything else asks the operator to
    believe both "this is over" and "this is the same one" about the same finding.

    Counted over the journal, which is the only thing that remembers: one increment per
    RESOLVED-then-reopened cycle. Deliberately NOT one per RESOLVED line -- `RESOLVED` persists
    for as long as the finding stays absent, and incrementing on each of those would give the two
    RESOLVED observations different keys and send the recovery message twice. Measured that way
    round before this was written.
    """
    seq = 0
    resolved = False
    for line in history:
        st = line.get('state')
        if st == 'RESOLVED':
            resolved = True
        elif resolved and st in REOPENING_STATES:
            seq += 1
            resolved = False
    if resolved and current_state in REOPENING_STATES:
        seq += 1
    # 🔴 IT MUST NEVER GO BACKWARDS, AND THE FIRST VERSION COULD.
    # An independent review of this change measured it: recomputing purely from the readable
    # transitions means a journal MISSING its `RESOLVED` line -- which is exactly what ORDER-1261
    # #5 now lets happen, since a torn line is tolerated rather than fatal -- recounts to 0,
    # rebuilds the ORIGINAL dedupe key, and suppresses the very reopen this function exists to
    # let through. The two repairs undid each other, and the suites were green because no case
    # drove a partial journal.
    # The count is already WRITTEN on every journal line, so the highest one the journal still
    # remembers is a floor the recomputation may raise and may not lower.
    stored = [line.get('incident_seq') for line in history
              if isinstance(line.get('incident_seq'), int)]
    return max([seq] + stored) if stored else seq


def dedupe_key(public_id, state, severity, material_revision, now=None, incident=0):
    """
    design 7.3, verbatim: `finding_id` + `state` + `severity` + `material_revision`.

    The public id stands in for the finding id, because the finding id may not travel and the
    public id is a stable, collision-resistant function of it (safe_projection.public_id) - so
    the key is as discriminating as the design's while carrying nothing it must not.

    Rev 1 deduped on (id, state). A finding going WARN -> REAL_MONEY with its state still OPEN
    produced the same pair and was suppressed as a duplicate. That is the escalation this key
    exists to let through, and case D02 drives exactly it.

    THE ONE ADDITION TO THE DESIGN'S FOUR FIELDS, and it closes design 11 row 16's other half.
    "One alert, then silence until the dedupe key changes" is correct for every state except
    the one whose definition is that it does not change: design 7.3 requires FLAPPING to get a
    "bounded reminder rather than permanent silence, so a state that never changes cannot go
    unreported forever". With the four fields alone a FLAPPING finding is alerted once and then
    silent for as long as it lasts, which is the failure that clause names. So a FLAPPING key -
    and ONLY a FLAPPING key - carries the calendar day, which re-opens it exactly once per day
    and no more.

    The cadence is a NOTIFICATION choice this module makes and says so; it is not a risk
    threshold and it is not derived from anything a detector owns (design 7.1: the dashboard
    creates no competing threshold).
    """
    key = '%s|%s|%s|%d' % (public_id, state, severity, int(material_revision))
    # ORDER-1261 #1. APPENDED ONLY WHEN IT IS NON-ZERO, and that is not cosmetic: every key
    # already in `factory/alert_ledger.jsonl` was written without it, so adding the component
    # unconditionally would fail to match every one of them and re-alert the whole open set once.
    # A first incident keeps the key it has always had. Same bargain the FLAPPING suffix strikes.
    if int(incident):
        key = '%s|I%d' % (key, int(incident))
    if state != 'FLAPPING':
        return key
    if not now:
        _refuse('a FLAPPING finding needs the current time to compute its bounded reminder '
                'window. Refusing rather than falling back to the plain key: the plain key is '
                'permanent silence, which is precisely what design 7.3 forbids for this state.')
    return '%s|D%s' % (key, str(now)[:10])


def _routed(severity):
    if severity not in ROUTING:
        _refuse('severity %r is not in the routing table, so there is no channel to send it to. '
                'Refusing rather than dropping it: a finding nobody routed and nobody reported '
                'is indistinguishable from a fleet with nothing wrong. Add it to ROUTING with '
                'the owner\'s decision, which is what that table records.' % severity)
    return ROUTING[severity]


def render_alert(record):
    """
    The message body. Public id, severity, class, state, revision - and NOTHING else.

    There is no detail line and that is deliberate, not an omission: design 7.3 pins Telegram
    and the dashboard to the same ids precisely so the wire can stay this thin. `class` is safe
    to send because it is a four-value closed enum with no identity in it; `detail` is not,
    because a detail like `attestation_map` is fine and a detail carrying an account is not,
    and the wire is not the place to start telling those apart.
    """
    return ('[EA LAB] %s · %s · %s\n'
            'finding %s · revision %d\n'
            'รายละเอียดอยู่บนแดชบอร์ดในเครื่อง (public_id ตรงกัน)'
            % (record['severity'], record['class'], record['state'],
               record['public_id'], record['material_revision']))


def render_recovery(record):
    return ('[EA LAB] RECOVERY · %s · %s\n'
            'finding %s · revision %d\n'
            'ตรวจสุขภาพดีติดกันครบตามกติกา design 7.1 — ปิดเอง'
            % (record['class'], record['severity'],
               record['public_id'], record['material_revision']))


def render_morning_brief(projection, headline, live_exceptions, work_unknown):
    """
    A RENDERING of what already exists, not a second computation.

    Content comes from the SafeProjection - the document the sender is allowed to read - plus
    exactly three scalars lifted out of control_center.project(): the headline word, the LIVE
    exception count and the WORK unknown flag. Three scalars and no rows, on purpose: a row
    from the page model carries a raw `account`, and the cheapest way not to leak one is not to
    touch one.

    NO DRAWDOWN IS COMPUTED. The band is printed exactly as the projection carries it, and when
    that is UNKNOWN the brief says why in one sentence instead of deriving a percentage from
    equity and balance. design 7.1: the dashboard creates no competing threshold, and a
    notifier is not a better place to break that rule than a dashboard.
    """
    accounts = projection.get('accounts') or []
    sensors = {}
    bands = {}
    for a in accounts:
        sensors[a['sensor_state']] = sensors.get(a['sensor_state'], 0) + 1
        bands[a['dd_pct_band']] = bands.get(a['dd_pct_band'], 0) + 1
    sev = {}
    for f in projection.get('findings') or []:
        sev[f['severity']] = sev.get(f['severity'], 0) + 1

    def fmt(d):
        return ' · '.join('%s %d' % (k, d[k]) for k in sorted(d)) or 'ไม่มี'

    dd_note = ''
    if list(bands) == ['UNKNOWN']:
        dd_note = ('\nDD band อ่านว่า UNKNOWN ทุกบัญชี เพราะยังไม่มี detector ตัวไหนประกาศ band '
                   '— หน้านี้ไม่คำนวณ DD เอง')
    return ('[EA LAB] Morning Brief · build %s · %s\n'
            'สถานะรวม: %s\n'
            'บัญชี %d — sensor: %s\n'
            'DD band: %s%s\n'
            'finding: %s\n'
            'LIVE exception: %d\n'
            'WORK: %s'
            % (projection.get('build_id'), projection.get('generated_at'),
               headline, len(accounts), fmt(sensors), fmt(bands), dd_note,
               fmt(sev), live_exceptions,
               'UNKNOWN (รายละเอียดบนแดชบอร์ด)' if work_unknown else 'ครบ'))


def plan(records, projection=None, brief=None, probe=None, now=None):
    """
    PURE. records -> AlertEvents. The ONLY producer of anything that crosses the seam.

    `brief` is (headline, live_exceptions, work_unknown) or None; `probe` is (id, channel) or
    None. Both are here rather than in three sibling functions because every event that reaches
    a channel must pass through one assert_sendable(), and three producers would be three places
    for a fourth one to be added quietly.
    """
    events = []
    for r in records:
        channel = _routed(r['severity'])
        if r.get('recovery_emitted'):
            events.append(_event('RECOVERY', channel, r, render_recovery(r), projection, now))
        elif r['state'] in SILENT_STATES:
            # FOUND BY ROUND 1, and it is the acceptance being met in letter and broken in
            # spirit. design 7.3 says `OPEN -> HEALTHY_1_OF_2 -> OPEN` must not emit a RECOVERY
            # message, "and treating it as one produces exactly the flapping spam the two-check
            # rule exists to stop". The first version dutifully withheld the recovery LABEL and
            # then sent an ALERT saying `HEALTHY_1_OF_2` instead - a message per flicker, which
            # is the same spam under a different word. Traced on a five-run flicker: OPEN,
            # HEALTHY_1_OF_2, OPEN, HEALTHY_1_OF_2, FLAPPING delivered THREE messages, the
            # middle one announcing that a problem had been briefly absent.
            #
            # An intermediate healthy check is not news. The OPEN alert already went out and is
            # still in force; if the health holds, RESOLVED emits exactly one recovery. So this
            # state emits NOTHING - which is a decision about what an operator is told, and is
            # therefore written here as a named set rather than as a condition inside an if.
            continue
        elif r['state'] != 'RESOLVED':
            events.append(_event('ALERT', channel, r, render_alert(r), projection, now))
    if brief is not None:
        headline, live_exceptions, work_unknown = brief
        text = render_morning_brief(projection, headline, live_exceptions, work_unknown)
        events.append({
            'entity': ENTITY_EVENT, 'kind': 'MORNING_BRIEF', 'channel': BRIEF_CHANNEL,
            'public_id': 'FP-0000000000', 'severity': 'INFO', 'state': 'OPEN',
            'class': 'AUDIT', 'material_revision': 0,
            'dedupe_key': 'BRIEF|%s' % (projection or {}).get('build_id', ''),
            'build_id': str((projection or {}).get('build_id', '')),
            'text': text,
        })
    if probe is not None:
        probe_id, channel = probe
        if channel not in CHANNELS:
            _refuse('probe channel %r is not one of %s' % (channel, ', '.join(CHANNELS)))
        # 🔴 ORDER-1310 #2: THE PROBE ID IS CALLER-CHOSEN TEXT ON THE ONE PATH THAT CANNOT SCAN IT.
        # `--id` is whatever the operator typed, it went into the message VERBATIM, and the probe
        # branch declares NO_KNOWN_SECRETS_AVAILABLE by design -- a probe exists to run when the
        # snapshot is broken, so there is no document to derive recognizers from. The independent
        # review sent `probe --id 159503454` and got `[EA LAB] delivery probe 159503454 →
        # EMERGENCY` past `assert_sendable`. An operator reaching for their account number as a
        # convenient unique id would have posted it to Telegram. (NOT a regression: the branch
        # passed an empty tuple before, which scanned nothing either.)
        #
        # FILTERING IT WOULD BE THE WRONG REPAIR -- a blacklist of value shapes has no end, which
        # is the argument `safe_projection._check_shape` already makes for field names. The
        # channel is removed instead: the WIRE carries an opaque token derived from the id, and
        # the raw id stays in `dedupe_key`, which is local (the ledger lives under gitignored
        # `ops/`) and never sent. Correlation is preserved -- `public_id` is stable across runs --
        # and `main()` prints the mapping locally so the operator can still match what they typed
        # to what arrived.
        events.append({
            'entity': ENTITY_EVENT, 'kind': 'DELIVERY_PROBE', 'channel': channel,
            'public_id': 'FP-0000000000', 'severity': 'INFO', 'state': 'OPEN',
            'class': 'AUDIT', 'material_revision': 0,
            'dedupe_key': 'PROBE|%s|%s' % (channel, probe_id),
            'build_id': str((projection or {}).get('build_id', '')),
            'text': ('[EA LAB] delivery probe %s → %s\n'
                     'พิสูจน์เส้นทางแจ้งเตือนตรง (ไม่ผ่าน OpenClaw) — ไม่ใช่เหตุการณ์ของฟลีต'
                     % (safe_projection.public_id(probe_id), channel)),
        })
    return events


def _event(kind, channel, record, text, projection, now=None):
    return {
        'entity': ENTITY_EVENT,
        'kind': kind,
        'channel': channel,
        'public_id': record['public_id'],
        'severity': record['severity'],
        'state': record['state'],
        'class': record['class'],
        'material_revision': record['material_revision'],
        'dedupe_key': dedupe_key(record['public_id'], record['state'], record['severity'],
                                 record['material_revision'], now,
                                 record.get('incident_seq') or 0),
        'build_id': str((projection or {}).get('build_id', '')),
        'text': text,
    }


def assert_sendable(events, known_secrets=(), repo_root='.'):
    """
    THE SEAM. Nothing crosses it without passing here, and it checks BOTH halves:

      SHAPE     against schemas.json's AlertEvent declaration, via the S11 checker - which
                refuses an undeclared field AND refuses a schema construct it cannot verify.
      LITERALS  safe_projection.scan_forbidden with the REAL secret list from the snapshot.
                This is the layer the sender structurally cannot run, and running it here is
                how the prohibition stops disarming it.

    `text` is the field that makes this necessary. Everything else on an AlertEvent is an enum
    or a hashed id; `text` is free-form, which makes it the one place a careless renderer can
    write an account number onto the wire. Case LEAK2 drives exactly that.
    """
    schema = safe_projection._schema_of(ENTITY_EVENT, repo_root)
    for i, ev in enumerate(events):
        hits = []
        safe_projection._check_shape(ev, schema, '$[%d]' % i, hits)
        if hits:
            _refuse('event %d is not the declared %s shape: %s'
                    % (i, ENTITY_EVENT, '; '.join('%s [%s] %s' % h for h in hits)))
    hits = safe_projection.scan_forbidden(events, known_secrets)
    if hits:
        raise safe_projection.ProjectionLeak(
            'the planned alerts carry %d forbidden item(s): %s'
            % (len(hits), '; '.join('%s [%s] %s' % h for h in hits)))
    return events


# ---------------------------------------------------------------------------------------
# THE SENDER SIDE. AlertEvents in, receipts out. No snapshot anywhere in this section.
# ---------------------------------------------------------------------------------------

def scrub(text, token):
    """Every string that leaves this module passes through here. Tokens never enter a log."""
    if not token:
        return text
    return str(text).replace(str(token), '***REDACTED***')


class Credentials(object):
    """A token and its chat ids. __repr__ redacts, because reprs end up in tracebacks."""

    def __init__(self, token, chat_ids):
        self.token = token
        self.chat_ids = list(chat_ids)

    def __repr__(self):
        return '<Credentials chat_ids=%d token=***REDACTED***>' % len(self.chat_ids)


def parse_config(path):
    """
    The same line-based reader scripts/mris/mris_notify.ps1 and scripts/telegram_bot.py use.

    Read as utf-8-sig, because Set-Content -Encoding UTF8 writes a BOM and a BOM at the head of
    the first key makes that key silently unfindable - which would present as "telegram is not
    configured" rather than as an encoding fault.
    """
    cfg = {}
    current = None
    if not os.path.exists(path):
        return cfg
    with io.open(path, 'r', encoding='utf-8-sig') as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith('#'):
                continue
            if line.startswith('- ') and current:
                cfg.setdefault(current, []).append(line[2:].strip().strip('"').strip("'"))
                continue
            if ':' not in line:
                continue
            key, value = line.split(':', 1)
            key, value = key.strip(), value.strip()
            current = None
            if not value:
                cfg[key] = []
                current = key
                continue
            cfg[key] = value.strip('"').strip("'")
    return cfg


# channel -> (token key, chat-id list key). CLOSED, and the reason the Control Room bot needs
# its own pair rather than borrowing the emergency bot's: design 7.3 names two bots on one
# event system, and one token posting to two chats would make "which bot woke me" a property
# of a chat id in a config file instead of a property of the routing table.
CHANNEL_CONFIG_KEYS = {
    'EMERGENCY': ('telegram_bot_token', 'telegram_allowed_user_ids'),
    'CONTROL_ROOM': ('telegram_control_room_bot_token', 'telegram_control_room_chat_ids'),
}


def resolve_channels(cfg):
    """
    -> {channel: Credentials or None}. `None` means UNCONFIGURED, which is an OUTCOME that gets
    written to the ledger and makes the CLI exit non-zero - never a quiet skip. An operator who
    has not yet made the Control Room bot must learn that from a failed run, not from silence.
    """
    out = {}
    for channel in CHANNELS:
        token_key, ids_key = CHANNEL_CONFIG_KEYS[channel]
        token = cfg.get(token_key)
        ids = cfg.get(ids_key) or []
        if isinstance(ids, str):
            ids = [ids]
        ids = [str(i).strip() for i in ids if str(i).strip()]
        if not token or token == PLACEHOLDER_TOKEN or not ids:
            out[channel] = None
        else:
            out[channel] = Credentials(token, ids)
    return out


class RecordingTransport(object):
    """
    Records instead of sending. A FIRST-CLASS transport, declared here rather than improvised
    in the cage, because the subprocess claim "a message really is not sent twice" has to drive
    the same CLI a human drives - and a CLI with a test-only code path is not that CLI.
    """

    def __init__(self, path=None):
        self.sent = []
        self.path = path

    def send(self, channel, text):
        self.sent.append((channel, text))
        if self.path:
            with io.open(self.path, 'a', encoding='utf-8', newline='\n') as fh:
                fh.write(json.dumps({'channel': channel, 'text': text}, ensure_ascii=False) + '\n')
        return 'REC-%d' % len(self.sent)


class TelegramTransport(object):
    """
    The real Bot API leg. OpenClaw is not reachable from here - there is one host in this
    class and it is api.telegram.org.
    """

    API = 'https://api.telegram.org/bot%s/sendMessage'

    def __init__(self, credentials):
        self.credentials = credentials

    def send(self, channel, text):
        import urllib.error
        import urllib.parse
        import urllib.request
        token = self.credentials.token
        url = self.API % token
        receipts = []
        for chat_id in self.credentials.chat_ids:
            data = urllib.parse.urlencode({'chat_id': chat_id, 'text': text}).encode('utf-8')
            try:
                with urllib.request.urlopen(url, data=data, timeout=20) as resp:
                    body = json.loads(resp.read().decode('utf-8', 'replace'))
            except Exception as exc:                        # noqa: BLE001 - scrubbed, then raised
                raise NotifyRefusal(scrub('%s: %s' % (type(exc).__name__, exc), token))
            if not body.get('ok'):
                raise NotifyRefusal(scrub('telegram did not report ok: %s' % body, token))
            receipts.append(str((body.get('result') or {}).get('message_id')))
        return ','.join(receipts)


def read_jsonl(path):
    """-> (rows, torn). ORDER-1261 #5, and the shape of the answer is the whole finding.

    WHAT IT WAS. Both runtime readers called `json.loads` unguarded, so ONE torn line raised
    before any delivery decision was taken -- nothing planned, nothing sent, and nothing recorded
    about why. Measured at HEAD: a ledger whose last line is cut mid-string raised
    `JSONDecodeError` out of `Ledger.load`, i.e. the alerting system stops because its own log is
    incomplete. These are append-only files written by a scheduled job on a workstation that
    hibernates, so a half-written last line is an ordinary Tuesday.

    WHY NOT JUST SKIP IT. Because that is the failure this repo has paid for repeatedly: an
    unreadable input that reads as an empty one. A torn LEDGER line means a delivery nobody can
    see, which can cause a re-alert; a torn JOURNAL line means lost history, which can reset an
    incident count. Neither may be silent.

    So: the readable rows are returned, the torn ones are returned SEPARATELY AND COUNTED, and
    `main()` turns them into a problem that shows up in the exit code. Continuing is what keeps
    an alert flowing on the morning it matters; the count is what stops that being a shrug.
    """
    rows, torn = [], []
    if not os.path.exists(path):
        return rows, torn
    with io.open(path, 'r', encoding='utf-8-sig') as fh:
        for n, line in enumerate(fh, 1):
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except ValueError as exc:
                torn.append('%s line %d is not JSON (%s) -- the line is NOT skipped silently: '
                            'it is counted here and reported by the CLI, because a delivery '
                            'nobody can read is a delivery nobody can dedupe against'
                            % (path, n, exc))
                continue
            # ...and PARSING is not the same as READABLE. `null`, `[]` and `3` are all valid JSON
            # and none of them is a record. The first version of this reader counted only the
            # JSONDecodeError, so a `null` line was reported CLEAN and then took `.get` with it
            # into `Ledger.delivered()` -- an unreadable input that read as a readable one, which
            # is the exact failure this function was written to stop, one type down. Found by an
            # independent review of this change.
            if not isinstance(row, dict):
                torn.append('%s line %d parses as %s, not an object -- valid JSON is not the '
                            'same as a record, and a non-object here reaches every consumer '
                            'that expects one' % (path, n, type(row).__name__))
                continue
            rows.append(row)
    return rows, torn


class Ledger(object):
    """
    (dedupe_key, channel, outcome, receipt). Append-only.

    Dedupe is keyed on DELIVERED and on nothing else, which is the whole reason design 7.3
    asks for a ledger rather than a sent-set: without it "we deduped" is a claim about SENDING.
    A FAILED or UNCONFIGURED attempt must be retried on the next run, and a replay after an
    outage must not re-alert what already landed. Those are the same rule read from both ends.
    """

    def __init__(self, rows=()):
        self.rows = list(rows)
        self.torn = []

    @classmethod
    def load(cls, path):
        rows, torn = read_jsonl(path)
        led = cls(rows)
        led.torn = torn
        return led

    def delivered(self):
        return set((r.get('dedupe_key'), r.get('channel'))
                   for r in self.rows if r.get('outcome') == 'DELIVERED')

    def append(self, path, lines):
        d = os.path.dirname(path)
        if d and not os.path.isdir(d):
            os.makedirs(d)
        with io.open(path, 'a', encoding='utf-8', newline='\n') as fh:
            for line in lines:
                fh.write(json.dumps(line, ensure_ascii=False, sort_keys=True) + '\n')
        self.rows.extend(lines)


def safe_detail(text, known_secrets=safe_projection.NO_KNOWN_SECRETS_AVAILABLE):
    """
    A failure detail, scanned before it is written down.

    FOUND BY THE CAGE (case L06). `deliver()` used to write `'%s: %s' % (type(exc), exc)` into
    the ledger verbatim, so "a token never enters a log" rested entirely on every transport
    scrubbing its own exception before raising. TelegramTransport does; a transport written
    later, or one wrapping a library that puts the URL in its message, would not - and the URL
    of a Telegram send request CONTAINS THE TOKEN. The guarantee has to hold at the boundary
    that writes the file, not at each of the places that might raise.

    So the detail passes through the same value-shape rules the projection uses, and a hit
    REPLACES the text with a line naming the rule. Naming the rule matters: an operator who
    sees `TELEGRAM_BOT_TOKEN` knows both what was withheld and why, which a bare `[redacted]`
    does not tell them.
    """
    # ORDER-1267 #1: DECLARED, so "I have nothing to derive recognizers from" and "I forgot" stop
    # sharing a return value.
    #
    # 🔴 ORDER-1261 #3 -- AND THE DECLARATION WAS DOING THE PROHIBITION'S WORK. The sentinel was
    # passed UNCONDITIONALLY, so the KNOWN_SECRET layer never ran at the one boundary that writes
    # the ledger file. Measured at HEAD: `safe_detail('connect failed for account <a real account
    # number>')` returned the string UNCHANGED, while the token control was caught -- so the
    # value-shape layer was live and the literal layer had simply been switched off by the
    # argument. That is `prohibition-disarms-its-own-check`: a declaration that a layer cannot run
    # became the reason it did not.
    #
    # The secrets DO exist -- `main()` reads them out of the verified snapshot for
    # `assert_sendable` -- so they are threaded to here through `deliver()`. The sentinel stays as
    # the DEFAULT, because a caller that genuinely has none must still say so out loud.
    hits = safe_projection.scan_forbidden([str(text)], known_secrets)
    if not hits:
        return str(text)
    rules = sorted(set(h[1] for h in hits))
    return ('ข้อความ error ถูกตัดทิ้งก่อนบันทึกเพราะเข้าข่าย %s — เนื้อความเต็มไม่ถูกเขียนลงไฟล์ '
            'ดูได้จากเครื่องที่รัน' % ', '.join(rules))


def deliver(events, delivered, transports, now, known_secrets, openclaw='UNKNOWN',
            previously_delivered=()):
    """
    -> (ledger lines, problems). Every event produces EXACTLY ONE line, whatever happened.

    There is no path through this function that sends nothing and says nothing. An
    unconfigured channel, an unreachable API and an already-delivered key are three different
    stated outcomes, and two of them are problems that make the CLI exit non-zero. "A sender
    that cannot send and reports nothing is indistinguishable from a quiet fleet."

    🔴 ORDER-1261 #4 -- THE SEAM WAS A CALL-ORDER CONVENTION AND THIS FUNCTION IS PUBLIC.
    `assert_sendable` is documented as THE seam, and it is -- for callers that call it. This
    function is in `PUBLIC_API`, called neither of the two guards, and put `ev['text']` on the
    wire directly. Measured at HEAD by structure and by driving it: a caller that skips the seam
    sends whatever text it was handed. `imports_of()` cannot notice, because `io`, `os`,
    `subprocess` and `snapshot_validator` are all already allowed to it.
    So the LITERAL half of the seam is re-run HERE, at the boundary that actually sends. Not the
    shape half: that is a schema read, it is genuinely expensive per event, and `assert_sendable`
    is where an event is BUILT wrong. What this stops is the one thing a second caller can get
    wrong on its own -- putting a literal from the snapshot onto the wire.

    🔴 `known_secrets` HAS NO DEFAULT, AND THE FIRST VERSION OF THIS REPAIR GAVE IT ONE.
    An independent review of this very change measured the consequence: with the argument
    defaulted to the sentinel, a public caller that omitted it got a scan whose KNOWN_SECRET layer
    could not fire, so `deliver()` delivered the literal -- on exactly the path the repair claimed
    to close. The cage did not catch it because the case I wrote PASSED the list, i.e. it drove
    the repaired path and never the defaulted one (`falsifier-satisfied-by-unexercised-mechanism`).
    A required argument is the fix that has no such hole: a caller cannot reach the wire without
    answering the question, and `NO_KNOWN_SECRETS_AVAILABLE` remains the honest answer for a
    caller that genuinely has nothing -- it just has to be given on purpose.

    `previously_delivered` is the set of channels the ledger has EVER delivered on. ORDER-1261 #6:
    it is what separates "not provisioned yet" from "the credential that was working is gone".
    """
    lines = []
    problems = 0
    for ev in events:
        # The literal half of the seam, structurally, for every event this function sends.
        leak = safe_projection.scan_forbidden([ev.get('text', '')], known_secrets)
        if leak:
            raise safe_projection.ProjectionLeak(
                'deliver() was handed an event whose text carries %d forbidden item(s): %s -- '
                'the seam is enforced HERE as well as in assert_sendable, because this function '
                'is public and a caller that skips the seam would otherwise send it'
                % (len(leak), '; '.join('%s [%s] %s' % h for h in leak)))
        key = (ev['dedupe_key'], ev['channel'])
        base = {'entity': ENTITY_DELIVERY, 'dedupe_key': ev['dedupe_key'],
                'channel': ev['channel'], 'kind': ev['kind'], 'at': now,
                'openclaw': openclaw}
        if key in delivered:
            base.update({'outcome': 'SUPPRESSED_DUPLICATE', 'receipt': None,
                         'detail': 'ส่งไปแล้วบนช่องนี้ ตาม ledger — ไม่ส่งซ้ำ'})
            lines.append(base)
            continue
        transport = transports.get(ev['channel'])
        if transport is None:
            # 🔴 ORDER-1261 #6: ONE OUTCOME WAS CARRYING TWO SITUATIONS. "The owner has not made
            # the bot yet" and "the credential that was delivering yesterday is gone" both came
            # out as UNCONFIGURED -> exit 4, and exit 4 is deliberately MUTED in the daily chain
            # (ORDER-219: a report that goes red every morning gets muted within a week). So the
            # second one -- a real regression on a channel that includes EMERGENCY -- was being
            # muted by a rationale written for the first.
            #
            # The ledger already knows which is which, and it needs no new field to say so: a
            # channel that has EVER delivered was configured. Measured at HEAD: a channel with a
            # past DELIVERED row, now absent from `transports`, produced the identical outcome
            # and the identical detail as one that never existed.
            regression = ev['channel'] in set(previously_delivered)
            base.update({
                'outcome': 'UNCONFIGURED_REGRESSION' if regression else 'UNCONFIGURED',
                'receipt': None,
                'detail': ('ช่อง %s เคยส่งสำเร็จมาแล้วตาม ledger แต่ตอนนี้ไม่มี credential ใน %s — '
                           'นี่คือของที่เคยใช้ได้แล้วหายไป ไม่ใช่ของที่ยังไม่ได้ตั้ง'
                           % (ev['channel'], CONFIG_REL)) if regression else
                          ('ช่อง %s ยังไม่มี credential ใน %s — นี่คือความล้มเหลวที่ประกาศ '
                           'ไม่ใช่การข้ามเงียบๆ' % (ev['channel'], CONFIG_REL))})
            lines.append(base)
            problems += 1
            continue
        try:
            receipt = transport.send(ev['channel'], ev['text'])
        except Exception as exc:                            # noqa: BLE001 - reported, not swallowed
            base.update({'outcome': 'FAILED', 'receipt': None,
                         'detail': safe_detail('%s: %s' % (type(exc).__name__, exc),
                                               known_secrets)})
            lines.append(base)
            problems += 1
            continue
        base.update({'outcome': 'DELIVERED', 'receipt': str(receipt), 'detail': ''})
        lines.append(base)
        delivered.add(key)
    return lines, problems


# ---------------------------------------------------------------------------------------
# THE ENTRY POINT A HUMAN ACTUALLY RUNS. Four of six S11 defects lived in code no case drove,
# two of them in a CLI that was declared public and called by nothing. Cases CLI1-CLI4 run this.
# ---------------------------------------------------------------------------------------

def _now():
    import datetime
    return datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S')


def load_local(repo_root):
    """
    The LOCAL side's inputs, in one place so the seam is visible in the call graph:
    the verified snapshot (records + secrets) and the projection read through the ONE reader.
    """
    snapshot = snapshot_validator.load_verified(
        os.path.join(repo_root, safe_projection.SNAPSHOT_REL))
    projection = safe_projection.read_for_sender(
        os.path.join(repo_root, safe_projection.PROJECTION_REL), repo_root)
    return snapshot, projection


def _brief_scalars(repo_root, snapshot):
    """The three scalars, and only the three. See render_morning_brief for why only three."""
    read = control_center.SnapshotRead(control_center.READ_OK, 'OK', '', snapshot)
    rows, source = control_center.read_work_rows(repo_root)
    pages = control_center.project(read, rows, [], source)
    return (pages['today']['health']['headline'],
            pages['live']['exception_count'],
            bool(pages['work'].get('unknown')))


def _pin_utf8():
    """
    Make this process's stdout/stderr carry Thai, whatever console it was launched into.

    FOUND BY THE PRE-COMMIT HOOK, and it is a latent defect S11 shipped with rather than one this
    slice introduced. Every message and every `why` in this repo is written in Thai, and python
    picks its stdout encoding from the console codepage: run interactively it is UTF-8, but a
    child of the hook gets a pipe under the ANSI codepage, where the FIRST Thai character raises
    UnicodeEncodeError. That traceback goes to stderr, and the PowerShell wrapper's `2>&1` under
    $ErrorActionPreference='Stop' turns any stderr line into a terminating error -- so the suite
    reports `exit -1  SUITE THREW` and the reason is invisible.

    Pinned HERE, in the entry point, rather than only in the wrapper: the wrapper is one of the
    ways this CLI gets launched, and a scheduled task will be another.
    """
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding='utf-8', errors='replace')
        except (AttributeError, ValueError):
            pass


def main(argv):
    _pin_utf8()
    verbs = ('plan', 'send', 'probe')
    if len(argv) < 2 or argv[1] not in verbs:
        sys.stderr.write('usage: notifier.py %s [--repo-root DIR] [--brief] [--confirm]\n'
                         '                   [--record PATH] [--id ID] [--channel %s]\n'
                         % ('|'.join(verbs), '|'.join(CHANNELS)))
        return 2
    verb = argv[1]

    def opt(name, default=None):
        return argv[argv.index(name) + 1] if name in argv else default

    repo_root = opt('--repo-root', '.')
    confirm = '--confirm' in argv
    record_path = opt('--record')
    now = _now()

    if verb == 'send' and not confirm:
        sys.stderr.write('REFUSED: `send` delivers real messages, so it requires --confirm. '
                         'Use `plan` to see what would go out. This is a stated refusal and an '
                         'exit code, not a quiet no-send.\n')
        return 2
    if verb == 'probe' and not confirm:
        sys.stderr.write('REFUSED: `probe` delivers a real message, so it requires --confirm.\n')
        return 2
    # Usage errors are settled BEFORE any document is opened. Verifying a snapshot costs ~0.3s,
    # and spending it to then reject the command line is both slower and worse: the operator
    # waits, and a document failure would be reported for a run that was never going to happen.
    probe_id = opt('--id')
    probe_channel = opt('--channel', 'EMERGENCY')
    if verb == 'probe' and not probe_id:
        sys.stderr.write('REFUSED: probe needs --id, so a second probe is a second ledger entry '
                         'rather than a suppressed duplicate forever.\n')
        return 2

    # A DELIVERY PROBE READS NOTHING. It carries no finding, no account and no build, so it needs
    # neither the snapshot nor the projection - and requiring them would be backwards: the moment
    # you most want to prove the alert path still works is when the snapshot is broken. It also
    # takes two verifications (~0.6s) off the cage, which is the fast tier's scarcest resource.
    snapshot, projection = None, None
    if verb != 'probe':
        try:
            snapshot, projection = load_local(repo_root)
        except Exception as exc:                            # noqa: BLE001 - reported, not swallowed
            sys.stderr.write('the local inputs could not be read, so nothing was planned and '
                             'nothing was sent: %s: %s\n' % (type(exc).__name__, exc))
            return 3

    journal_path = os.path.join(repo_root, JOURNAL_REL)
    ledger_path = os.path.join(repo_root, LEDGER_REL)
    # ORDER-1261 #5: the second of the two unguarded readers. A torn journal line used to raise
    # here, before a single delivery decision was taken.
    previous, torn = read_jsonl(journal_path)

    try:
        if verb == 'probe':
            records, journal_lines, brief = [], [], None
            probe = (probe_id, probe_channel)
            # ORDER-1267 #1: DECLARED, and this branch is the reason the sentinel is a sentinel
            # rather than a lint. A probe exists to prove the alert path still runs WHEN THE
            # SNAPSHOT IS BROKEN -- so there is no document to derive recognizers from, by design,
            # on exactly the run you most want to succeed. `()` said that and also said "I
            # forgot", with the same result. Saying which one it is costs nothing and is the whole
            # repair. (S12 C06 and C07 are the cases that drive this branch.)
            secrets = safe_projection.NO_KNOWN_SECRETS_AVAILABLE
            # ORDER-1310 #2: the wire carries an opaque token, so the operator is told LOCALLY
            # which token their id became. Printed here rather than sent, which is the whole
            # point of the change.
            print('notifier: probe id %r travels as %s (the raw id stays local, in the ledger '
                  'key only)' % (probe_id, safe_projection.public_id(probe_id)))
        else:
            records, journal_lines = observe(previous, findings_of(snapshot), now)
            brief = _brief_scalars(repo_root, snapshot) if '--brief' in argv else None
            probe = None
            secrets = safe_projection.secrets_of(snapshot)
        events = plan(records, projection, brief, probe, now)
        assert_sendable(events, secrets, repo_root)
    except Exception as exc:                                # noqa: BLE001 - reported, not swallowed
        sys.stderr.write('REFUSED before anything was sent: %s: %s\n'
                         % (type(exc).__name__, exc))
        return 1

    ledger = Ledger.load(ledger_path)
    delivered = ledger.delivered()

    if verb == 'plan':
        for ev in events:
            mark = 'already-delivered' if (ev['dedupe_key'], ev['channel']) in delivered else 'new'
            print('%-13s %-14s %-8s %-4s %s [%s]'
                  % (ev['channel'], ev['kind'], ev['severity'], ev['state'], ev['dedupe_key'],
                     mark))
        # ORDER-1261 #5, second half, found by an independent review: this branch returned before
        # the torn-line report below, so `plan` over a partial journal or ledger exited 0 in
        # silence -- and `plan` is the verb a human runs to ask "what is about to happen". The
        # count belongs to every verb that READ those files, not only to the one that sends.
        plan_torn = list(torn) + list(getattr(ledger, 'torn', []))
        for t in plan_torn:
            print('TORN LINE: %s' % t)
        print('notifier: %d event(s) planned, %d torn line(s), nothing sent (`plan` never sends)'
              % (len(events), len(plan_torn)))
        return 1 if plan_torn else 0

    if record_path:
        transport = RecordingTransport(record_path)
        transports = dict((c, transport) for c in CHANNELS)
    else:
        transports = {}
        for channel, creds in resolve_channels(
                parse_config(os.path.join(repo_root, CONFIG_REL))).items():
            transports[channel] = TelegramTransport(creds) if creds else None

    oc = openclaw_state()
    # ORDER-1261 #3 + #4 + #6: the real secret list reaches the boundary that WRITES the ledger
    # and the one that SENDS, and the set of channels the ledger has ever delivered on reaches
    # the branch that has to tell "never provisioned" from "the credential is gone".
    lines, problems = deliver(events, delivered, transports, now, secrets, oc,
                              previously_delivered=set(c for (_k, c) in delivered))
    ledger.append(ledger_path, lines)
    if journal_lines:
        d = os.path.dirname(journal_path)
        if d and not os.path.isdir(d):
            os.makedirs(d)
        with io.open(journal_path, 'a', encoding='utf-8', newline='\n') as fh:
            for line in journal_lines:
                fh.write(json.dumps(line, ensure_ascii=False, sort_keys=True) + '\n')

    for line in lines:
        print('%-13s %-20s receipt=%s %s'
              % (line['channel'], line['outcome'], line['receipt'], line['detail']))

    # TWO KINDS OF PROBLEM, TWO EXIT CODES, and the split exists because of a lesson already
    # written into scripts\daily_monitor.ps1 by ORDER-219: "a report that turns the chain red
    # every single morning is a report that gets muted inside a week".
    #
    #   FAILED        a channel that IS configured did not deliver. Something is wrong NOW.  -> 1
    #   UNCONFIGURED  a channel has no credentials yet. Expected, stated, and true every day
    #                 until the owner creates the bot -- so it must be LOUD IN THE LOG and must
    #                 NOT mark the daily chain unhealthy.                                    -> 4
    #
    # Exit 4 is still non-zero: nothing here treats "not configured" as success. It is a
    # DIFFERENT non-zero, so a caller can tell "you have not set this up" from "it broke".
    failed = len([l for l in lines if l['outcome'] == 'FAILED'])
    unconfigured = len([l for l in lines if l['outcome'] == 'UNCONFIGURED'])
    # ORDER-1261 #6: a channel that WAS delivering and now has no credential is not "not set up
    # yet". It joins `failed` on purpose, so it exits 1 and turns the daily chain red -- ORDER-219
    # muted exit 4 for a situation that is true every day until the owner acts, and this is the
    # opposite: something that was working stopped.
    regressed = [l for l in lines if l['outcome'] == 'UNCONFIGURED_REGRESSION']
    # ORDER-1261 #5: torn lines are counted, not swallowed. `problems` already makes them visible
    # in the exit code via `failed`; they are printed by name so the operator can find the file.
    torn_all = list(torn) + list(getattr(ledger, 'torn', []))
    for t in torn_all:
        print('TORN LINE: %s' % t)
    print('notifier: %d event(s), %d failed, %d unconfigured, %d regressed, %d torn line(s), '
          'OpenClaw=%s' % (len(lines), failed, unconfigured, len(regressed), len(torn_all), oc))
    if failed or regressed or torn_all:
        for l in regressed:
            print('REGRESSION: %s' % l['detail'])
        return 1
    if unconfigured:
        # STDOUT, not stderr, and that is not cosmetic. A caller that redirects a native
        # command's stderr in PowerShell gets every line wrapped in a NativeCommandError, which
        # buries a plain status message inside what reads as a crash. This IS a status - "you
        # have not set this channel up yet" - and the machine-readable half of it is the exit
        # code, which is where a caller should be reading it from anyway.
        print('NOT CONFIGURED: %d event(s) had no channel credentials. This is a stated outcome, '
              'not a silent skip, and it is recorded in %s. It stays true until the bot exists.'
              % (unconfigured, LEDGER_REL))
        return 4
    return 0


# The CLOSED declaration of this module's public surface, checked by the cage. Unlike S11's
# shadow-mode shell this module DOES send, so a verb blacklist would be theatre; what is
# checked instead is that the surface is exactly this and that every name on it is driven.
PUBLIC_API = (
    'NotifyRefusal', 'Credentials', 'Ledger', 'RecordingTransport', 'TelegramTransport',
    'assert_reason_maps_agree', 'assert_sendable', 'dedupe_key', 'deliver', 'findings_of',
    # ORDER-1261. Both are public because a case has to be able to drive them directly:
    # `incident_seq` answers "what is a distinct incident" from the journal and is the whole of
    # #1's design decision, and `read_jsonl` is the ONE reader both runtime stores now go
    # through, so a second unguarded `json.loads` would be visible as a second reader rather
    # than as a line. P01 caught both the moment they appeared, which is the cage working.
    'incident_seq', 'read_jsonl',
    'imports_of', 'internal_id', 'load_local', 'main', 'observe', 'openclaw_state',
    'parse_at', 'parse_config', 'payload_digest', 'plan', 'render_alert',
    'render_morning_brief', 'render_recovery', 'resolve_channels', 'safe_detail', 'scrub',
)


if __name__ == '__main__':
    sys.exit(main(sys.argv))
