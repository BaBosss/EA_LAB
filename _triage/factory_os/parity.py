# -*- coding: utf-8 -*-
"""parity.py -- ORDER-1021 (slice S8). The 7-point Parent-Variant parity contract, design 5.5.

WHAT PARITY IS. A Thin Wrapper is valid **iff**, on one lane, one data fingerprint, one window and
one model, the wrapper and the PARENT BOSS CONFIGURED WITH THE WRAPPER'S EFFECTIVE CONFIG agree on
all seven of: init result - `[CFG]` fingerprint - the full order request/result trace including
rejections - the trade list - end-of-run pendings and positions - terminal side effects - errors
and safety alerts. Parity runs BEFORE any evidence from that wrapper counts; evidence from an
unparified wrapper is void.

🔴 WHY NOT TRADE-LIST IDENTITY ALONE, WHICH IS WHAT REV 1 OF THE DESIGN SAID. A wrapper and its
parent can both open ZERO trades. The lists then match, parity "passes", and the wrapper actually
failed `OnInit` on a wrong generated `const`. **An empty list is the easiest way to match.** Every
design decision in this module falls out of that one sentence:

  * a point with NOTHING to compare on either side is `UNTESTED`, never `AGREE`. Seven points of
    which four are vacuous is not 7/7, and this module refuses to print it as one. The repo has
    been burned by the same shape three times (`ORDER-260`/`341`/`390`/`411`): the artifact kept
    being produced, it just stopped being true.
  * the case set must contain a MUST-TRADE case and a DELIBERATE-REFUSAL case, and
    `verdict_for_case` refuses to accept a case declared must-trade that opened nothing.
  * `refused` and `silent` are different init results and are never folded together.

🔴 WHAT THE SIDES ARE, AND THE ASYMMETRY THAT IS NOT A DEFECT. The wrapper exposes only the
inputs its revision leaves live (29 under B14-H01 as of the 2026-08-02 lock -- but the number is
`gen_wrapper.const_plan()`'s to state, not this docstring's: it moved 38->29 within HOURS of first
being written down, and a count copied into prose is stale the day after). The parent exposes the
build's full surface. That asymmetry is the POINT of the rollout -- but both sides' EFFECTIVE
CONFIGURATIONS are the same full-surface value set, which is why point 2 can demand an identical
`effective_config_hash`: `CFG_SurfacePreimage()` enumerates every name the build declares and
reads each as a SYMBOL, and a `const` symbol reads exactly like an `input` one.

CATEGORY (TIER_SNAPSHOT_DESIGN.md section 2/3.3): PURE. Text in, verdicts out. It opens nothing --
`scripts/parity_run.ps1` owns the tester runs and hands this module the bytes they produced. That
is what lets the cage drive it with synthetic artifact pairs instead of four tester runs.
"""
import re


RESULT_MANIFEST_REL = 'factory/parity/result_manifest.json'
RESULT_SCHEMA_VERSION = 1
RESULT_ENTITY = 'ParityResultManifest'
_HEX64 = re.compile(r'^[0-9a-f]{64}$')


class ManifestError(ValueError):
    """The committed parity result is present but cannot be trusted as evidence."""

# --- the seven points, in design 5.5's order ------------------------------------------------------
POINTS = (
    ('init', 'init result -- both attach, or both refuse for the SAME reason'),
    ('cfg', 'the [CFG] effective_config_hash, including locked constants'),
    ('orders', 'the full order request/result trace, INCLUDING rejections'),
    ('deals', 'the trade list -- count, times, volumes, prices'),
    ('end_state', 'pending orders and open positions at end of run'),
    ('side_effects', 'terminal side effects -- GlobalVariables, persistence keys, files'),
    ('alerts', 'errors and safety alerts raised'),
)

AGREE = 'AGREE'
DIFFER = 'DIFFER'
UNTESTED = 'UNTESTED'
# Distinct from UNTESTED on purpose, and ONLY reachable when point 1 has already established that
# BOTH sides refused at OnInit for the same reason. Nothing downstream of a refused attach runs on
# either side, so "no orders" is not a measurement that failed to happen -- it is the agreement.
# UNTESTED would under-report it and AGREE would over-report it; both were tried and both read
# wrong. The precondition is what keeps this from becoming an excuse: one side refusing and the
# other attaching makes point 1 DIFFER, and then nothing below is downgraded at all.
NOT_APPLICABLE = 'N/A-REFUSED'

_FP_LINE = re.compile(
    r'\[CFG\] input surface: build=(\S+) keys=(\d+) scope=(\S+) effective_config_hash=([0-9a-f]{64})')
_INIT_FATAL = re.compile(r'\[INIT\] FATAL: (.+?)\s*$')
# LabCore writes every persisted-state and cage transition through these prefixes. Matched as a
# CLOSED set rather than by a keyword sweep: "GlobalVariable" appears in comments and in unrelated
# terminal chatter, and a side-effect point that fires on prose is a point that cannot fail.
_SIDE_EFFECT = re.compile(r'\[(PERSIST|RISK|MG)\]\s*(.+?)\s*$')
# A CLOSED set, for the same reason _SIDE_EFFECT's comment gives one line up -- and the first
# version broke its neighbour's rule: it also matched bare `cannot ` and `failed`, which is a
# keyword sweep over a log the TERMINAL writes host messages into ("history sync failed",
# connection retries). Those land in one side's slice or the other on timing alone, so the sweep
# was a false DIFFER waiting for a bad network day. The set below is every alert-class prefix the
# EA itself prints: the safety module, the OnInit fail-closed seam, MQL5 Alert(), and MM's
# throttled "cannot size" line ([MM] first-lot sizing unavailable -- MoneyManagement.mqh).
_ALERT = re.compile(r'(\[SAFETY\]|\[INIT\] FATAL|\[MM\] first-lot sizing unavailable|Alert:)')

_ROW = re.compile(r'<tr[^>]*>(.*?)</tr>', re.S | re.I)
_CELL = re.compile(r'<t[dh][^>]*>(.*?)</t[dh]>', re.S | re.I)
_TAGS = re.compile(r'<[^>]+>')
_INPUT_ROW = re.compile(r'<td nowrap colspan="10" align="left"><b>([^<]*)</b>')


def _text(cell):
    import html
    return re.sub(r'\s+', ' ', html.unescape(_TAGS.sub('', cell))).strip()


def report_inputs(report_html):
    """-> [(name, value)] exactly as the MT5 report's `Inputs:` block lists them.

    🔴 THIS IS THE ONE MEASUREMENT THAT READS THE INPUTS PAGE ITSELF. Every other statement about
    how many inputs a build exposes -- the registry's, the generator's const plan, this file --
    is derived from source. The report is derived from the BINARY, which is the artifact that
    actually attaches, and design 5.3's acceptance is about that page and not about a table.
    """
    out = []
    for raw in _INPUT_ROW.findall(report_html):
        if '=' not in raw or raw.startswith('==='):
            continue
        name, value = raw.split('=', 1)
        out.append((name.strip(), value.strip()))
    return out


_ROW_TIME = re.compile(r'^\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}$')


def _table(report_html, heading):
    """-> [ [cell, ...], ... ] for the `Orders` or `Deals` table -- REAL rows only.

    🔴 A ROW IS REAL WHEN ITS FIRST CELL IS A TIMESTAMP, and that rule is here because the first
    version did not have it. The tester report closes each table with an unlabelled TOTALS row
    (`['', '0.00', '0.00', '0.00', '0.00', '']`), which passed the "has any non-empty cell" filter.
    The Deals list was therefore NEVER empty -- not even for a run that refused at `OnInit` and
    opened nothing -- so `empty_is_untested` on point 4 could not fire, on either side, ever.

    That is the defect this whole module exists to refuse, occurring inside it: a criterion that
    reads as a check and cannot reach the state it checks for. It was caught by the
    deliberate-refusal case reporting `deals AGREE` for two runs that never attached -- which is
    the second reason design 5.5 demands that case, and the one nobody had written down.
    """
    anchor = re.search(r'<th[^>]*>.*?<b>%s</b>' % heading, report_html, re.S | re.I)
    if not anchor:
        return None
    tail = report_html[anchor.end():]
    stop = re.search(r'<th[^>]*>.*?<b>(?:Orders|Deals)</b>', tail, re.S | re.I)
    if stop:
        tail = tail[:stop.start()]
    rows = []
    for raw in _ROW.findall(tail):
        cells = [_text(c) for c in _CELL.findall(raw)]
        if not cells or not any(cells):
            continue
        if not _ROW_TIME.match(cells[0]):     # header row, spacer row, or the TOTALS row
            continue
        rows.append(cells)
    return rows


class Observation(object):
    """One side of a parity pair: everything the seven points are read from, and NOTHING derived.

    Each field is either a value or `None`. `None` means NOT OBSERVED -- the artifact did not
    carry it -- and it is deliberately distinct from an empty list, which means observed-and-empty.
    Conflating the two is how a point that could not be measured gets reported as a point that
    agreed.
    """

    __slots__ = ('label', 'expert', 'binary', 'cfg', 'init_fatal', 'orders', 'deals',
                 'side_effects', 'alerts', 'inputs')

    def __init__(self, label, expert=None, binary=None):
        self.label = label
        self.expert = expert
        self.binary = binary
        self.cfg = None
        self.init_fatal = None
        self.orders = None
        self.deals = None
        self.side_effects = None
        self.alerts = None
        self.inputs = None

    @property
    def init_result(self):
        if self.init_fatal is None:
            return None
        return ('REFUSED', self.init_fatal) if self.init_fatal else ('ATTACHED', '')

    @property
    def end_state(self):
        """-> what was still OPEN when the window ended: pendings, and open positions.

        🔴 REWRITTEN BY THE FIRST AUDIT ROUND, because the first version could not observe
        anything on this revision and nobody could see that. It read only the Orders table's
        non-terminal rows -- but pendings cannot exist under B14-H01 (`_9_PendingMode` is const 0,
        STACK_PYRAMID locked out), and an open position at end of run does not appear as a
        non-terminal order at all: the tester force-closes it and writes a DEAL whose comment is
        `end of test`. So the property returned `[] == []` in every case, `AGREE` was reported,
        and the roll-up counted point 5 as "exercised" three times over -- a point that could not
        fail, wearing the uniform of one that had passed. The two real observables are:

          * orders not in a terminal state  = pendings still resting (none possible here today,
            but real the day a STACK_PYRAMID hypothesis is registered);
          * deals whose comment is `end of test` = the positions the window closed on, with
            their volumes and forced-close prices.

        The must-trade run has THREE of the latter on each side, so the point is now exercised by
        a real observation, and `compare()` treats empty-on-both-sides as UNTESTED like every
        other list-valued point.
        """
        if self.orders is None or self.deals is None:
            return None
        pending = [r for r in self.orders
                   if len(r) > 9 and r[-2].lower() not in ('filled', 'canceled')]
        open_at_end = [d for d in self.deals if d and d[-1].strip() == 'end of test']
        return pending + open_at_end


def observe(label, report_html=None, log_lines=None, expert=None, binary=None):
    """-> Observation. Anything absent stays `None`; nothing is defaulted to empty."""
    obs = Observation(label, expert=expert, binary=binary)
    if log_lines is not None:
        fatal = ''
        for line in log_lines:
            m = _FP_LINE.search(line)
            if m:
                obs.cfg = {'build': m.group(1), 'keys': int(m.group(2)),
                           'scope': m.group(3), 'hash': m.group(4)}
            m = _INIT_FATAL.search(line)
            if m and not fatal:
                fatal = m.group(1)
        obs.init_fatal = fatal
        obs.side_effects = sorted(set('%s %s' % m for m in
                                      (mm.groups() for mm in
                                       (_SIDE_EFFECT.search(l) for l in log_lines) if mm)))
        obs.alerts = sorted(set(_normalise_alert(l) for l in log_lines if _ALERT.search(l)))
    if report_html is not None:
        obs.orders = _table(report_html, 'Orders')
        obs.deals = _table(report_html, 'Deals')
        obs.inputs = report_inputs(report_html)
    return obs


def observation_to_record(obs):
    """Return only the observed fields needed to replay the seven-point comparison."""
    return {
        'init_fatal': obs.init_fatal,
        'cfg': obs.cfg,
        'orders': obs.orders,
        'deals': obs.deals,
        'side_effects': obs.side_effects,
        'alerts': obs.alerts,
    }


def observation_from_record(record, label):
    """Rehydrate an Observation without reading the tester report or agent log."""
    obs = Observation(label)
    obs.init_fatal = record['init_fatal']
    obs.cfg = record['cfg']
    obs.orders = record['orders']
    obs.deals = record['deals']
    obs.side_effects = record['side_effects']
    obs.alerts = record['alerts']
    return obs


_TS = re.compile(r'^\s*[\d:. ]*\s*')


def _normalise_alert(line):
    """Strip the agent-log prefix so two sides' identical messages compare equal.

    The prefix carries a wall-clock time and the EXPERT NAME -- and the expert name differs
    between the wrapper and its parent BY CONSTRUCTION. Comparing raw lines would therefore make
    every alert differ, i.e. point 7 could never pass, which is a point that cannot fail in the
    useless direction.
    """
    body = line.split('\t')[-1]
    return _TS.sub('', body).strip()


class PointVerdict(object):
    __slots__ = ('point', 'title', 'verdict', 'detail')

    def __init__(self, point, title, verdict, detail):
        self.point = point
        self.title = title
        self.verdict = verdict
        self.detail = detail


def _cmp(point, title, a, b, empty_is_untested, render=repr):
    if a is None or b is None:
        which = ' and '.join(s for s, v in (('A', a), ('B', b)) if v is None)
        return PointVerdict(point, title, UNTESTED,
                            'not observed on side %s -- the artifact did not carry it' % which)
    if empty_is_untested and not a and not b:
        return PointVerdict(point, title, UNTESTED,
                            'BOTH sides observed ZERO of these. Matching nothing is not '
                            'agreement -- an empty list is the easiest way to match.')
    if a == b:
        n = len(a) if isinstance(a, (list, tuple)) else 1
        return PointVerdict(point, title, AGREE, '%d item(s) identical' % n)
    if isinstance(a, list) and isinstance(b, list):
        first = next((i for i in range(max(len(a), len(b)))
                      if i >= len(a) or i >= len(b) or a[i] != b[i]), 0)
        return PointVerdict(point, title, DIFFER,
                            'A has %d, B has %d; first difference at index %d: %s vs %s'
                            % (len(a), len(b), first,
                               render(a[first]) if first < len(a) else '<absent>',
                               render(b[first]) if first < len(b) else '<absent>'))
    return PointVerdict(point, title, DIFFER, '%s vs %s' % (render(a), render(b)))


def both_refused_identically(a, b):
    """-> True when point 1 has established a SHARED refusal at OnInit.

    The precondition for downgrading anything to NOT_APPLICABLE, and it is deliberately strict:
    both sides must have an observed init result, both must be REFUSED, and the REASON strings
    must be equal. One side refusing and the other attaching is a parity failure, not a licence to
    stop comparing.
    """
    ra, rb = a.init_result, b.init_result
    return bool(ra and rb and ra[0] == 'REFUSED' and ra == rb)


def compare(a, b):
    """-> [PointVerdict] for all seven points of design 5.5, in order."""
    titles = dict(POINTS)
    out = [
        _cmp('init', titles['init'], a.init_result, b.init_result, False),
        _cmp('cfg', titles['cfg'], a.cfg, b.cfg, False),
        # An order/deal trace of length zero on BOTH sides is the counter-example design 5.5 is
        # built around, so these three carry `empty_is_untested`.
        _cmp('orders', titles['orders'], a.orders, b.orders, True),
        _cmp('deals', titles['deals'], a.deals, b.deals, True),
        _cmp('end_state', titles['end_state'], a.end_state, b.end_state, True),
        _cmp('side_effects', titles['side_effects'], a.side_effects, b.side_effects, True),
        _cmp('alerts', titles['alerts'], a.alerts, b.alerts, True),
    ]
    if both_refused_identically(a, b):
        for p in out[1:]:
            if p.verdict == UNTESTED:
                p.verdict = NOT_APPLICABLE
                p.detail = ('both sides refused at OnInit for the same reason, so nothing '
                            'downstream executed on either -- this is the agreement, not a '
                            'measurement that did not happen')
    return out


# --- case-level judgement --------------------------------------------------------------------------

MUST_TRADE = 'must-trade'
DELIBERATE_REFUSAL = 'deliberate-refusal'
NEUTRAL = 'neutral'


def verdict_for_case(kind, a, b, points):
    """-> (passed, [reason]). The case's DIRECTION is checked before its agreement.

    design 5.5 requires both directions in the case set precisely because agreement alone is
    cheap: a must-trade case that opened nothing agrees with a parent that opened nothing, and a
    refusal case that attached cleanly proves the harness cannot tell refused from silent. So the
    direction is asserted about the OBSERVATION, not about the comparison, and a case that fails
    its own direction fails even when all seven points agree.
    """
    reasons = direction_reasons(kind, a, b)
    for p in points:
        if p.verdict == DIFFER:
            reasons.append('point %s DIFFERS: %s' % (p.point, p.detail))
        elif p.verdict == UNTESTED:
            reasons.append('point %s is UNTESTED: %s' % (p.point, p.detail))
        # NOT_APPLICABLE is NOT appended: it is only reachable behind
        # `both_refused_identically`, i.e. point 1 has already asserted the agreement this
        # point would otherwise restate. Every other non-AGREE verdict fails the case.
    return (not reasons, reasons)


def direction_reasons(kind, a, b):
    """Return only the case-direction failures, shared by the live and replayed readers."""
    reasons = []
    if kind == MUST_TRADE:
        for side in (a, b):
            if side.deals is None:
                reasons.append('%s: no Deals table was observed, so "it traded" is unverified'
                               % side.label)
            elif not side.deals:
                reasons.append('%s: declared MUST-TRADE and opened NOTHING. The whole point of '
                               'this direction is that an empty run cannot pass.' % side.label)
        for side in (a, b):
            if side.init_result and side.init_result[0] == 'REFUSED':
                reasons.append('%s: declared MUST-TRADE but refused at OnInit: %s'
                               % (side.label, side.init_result[1]))
    elif kind == DELIBERATE_REFUSAL:
        for side in (a, b):
            if side.init_result is None:
                reasons.append('%s: the init result was not observed, so "it refused" is '
                               'unverified' % side.label)
            elif side.init_result[0] != 'REFUSED':
                reasons.append('%s: declared DELIBERATE-REFUSAL and ATTACHED. Parity would then '
                               'be proving that two silent runs are silent.' % side.label)
    elif kind != NEUTRAL:
        raise ValueError('unknown parity case kind %r' % kind)
    return reasons


# --- CLI -------------------------------------------------------------------------------------------
# The runner writes one JSON manifest per side and calls this. Manifest keys:
#   label, expert, binary, binary_mtime, report (path), log (path to the SLICE of the agent log
#   this run appended), kind (must-trade / deliberate-refusal / neutral), lane, symbol, period,
#   from, to, model, set (path)
#
# 🔴 THE BINARY IT MEASURED IS THE BINARY IT BUILT (ORDER-371). The manifest carries the `.ex5`
# path and its mtime, and `main` REFUSES a pair whose binaries were not both written before the
# runs and after the last source change. `tpl_regression` was compiling into lane 1 and measuring
# lane 5c as recently as 2026-07-30, and a parity harness that inherited that would be comparing
# two binaries neither of which is the one on trial.

def _load(path):
    # utf-8-SIG, not utf-8: PowerShell's `Set-Content -Encoding UTF8` writes a BOM on 5.1, and
    # json.loads refuses one. Same class as the UTF-16LE agent logs -- the instrument has to be
    # able to read the file before anything it says about the contents means anything
    # (memory prove-the-instrument-can-see-the-file).
    import io
    import json
    return json.loads(io.open(path, encoding='utf-8-sig').read())


def _read_report(path):
    import io
    return io.open(path, encoding='utf-16', errors='replace').read()


def _read_log(path):
    import io
    return io.open(path, encoding='utf-8', errors='replace').read().split('\n')


def observe_manifest(man):
    return observe(man['label'],
                   report_html=_read_report(man['report']) if man.get('report') else None,
                   log_lines=_read_log(man['log']) if man.get('log') else None,
                   expert=man.get('expert'), binary=man.get('binary'))


def anchor_reasons(man, obs):
    """-> reasons the side disagrees with the COMPILER -- the third corner of point 2.

    🔴 ADDED BY THE SECOND AUDIT ROUND, which found `expected_hash` written into every manifest
    and read by NOTHING. Point 2 compared wrapper against parent only, and the failure that slips
    through a two-sided comparison is exactly the one this repo has already paid for: MT5's
    `[TesterInputs]` fills every UNLISTED input from the per-terminal cache, and a `.set` that
    silently fails to apply does so for BOTH runs of a pair -- identical (wrong) hashes, point 2
    `AGREE`, parity "holds" while measuring some other configuration entirely
    (`mt5-tester-cache-nondeterminism`, `proving-a-set-was-loaded-on-a-chart`, ORDER-165's 8/8
    false drift). The comparison has to be TRIANGULAR: wrapper == parent == compiler.

    Skipped only when the side printed no `[CFG]` line at all -- a refused attach never reaches
    the emitter, and point 1 owns that agreement. A side that printed a hash is held to it.
    """
    expected = man.get('expected_hash')
    if not expected or obs.cfg is None:
        return []
    if obs.cfg.get('hash') != expected:
        return ['%s: the EA hashed %s but the COMPILER expected %s for this .set. The two sides '
                'may still agree with each other -- that is how a .set that silently failed to '
                'apply passes a two-sided comparison -- so this case is judged against the '
                'compiler as the third corner, and it does not hold.'
                % (obs.label, obs.cfg.get('hash', '?')[:16], expected[:16])]
    return []


def _rollup_main(dirs):
    """--rollup <caseDir> ... -- judge the CASE SET, which is the level design 5.5 is satisfied at."""
    import os
    import sys
    cases = []
    for d in dirs:
        a = _load(os.path.join(d, 'wrapper.json'))
        b = _load(os.path.join(d, 'parent.json'))
        obs_a, obs_b = observe_manifest(a), observe_manifest(b)
        points = compare(obs_a, obs_b)
        name = a.get('case', os.path.basename(d))
        kind = a.get('kind', NEUTRAL)
        # `locked-absent` is declared NEUTRAL and is EXPECTED to differ -- it exists to prove a
        # const is APPLIED, and its disagreement is the evidence. Folding that into the roll-up
        # would report the harness working as the harness failing, so it contributes its
        # observations to the record and not its verdicts to the contract.
        if name == 'locked-absent':
            sys.stdout.write('  case %-20s EXCLUDED from the contract -- it is expected to '
                             'DIFFER (it proves a const is applied)\n' % name)
            continue
        passed, _reasons = verdict_for_case(kind, obs_a, obs_b, points)
        anchors = anchor_reasons(a, obs_a) + anchor_reasons(b, obs_b)
        if anchors:
            passed = False
            for r in anchors:
                sys.stdout.write('  ANCHOR: %s\n' % r)
        cases.append((name, kind, points))
        # THREE labels, not two, and the missing one was actively misleading. A case with an
        # UNTESTED point is not a FAILURE -- no case can exercise all seven, so calling it one
        # printed `FAIL` next to a roll-up that said the set was satisfied, which is the kind of
        # artifact somebody quotes six weeks later without the paragraph that explains it. Only a
        # DIFFER is a case-level failure; a vacuous point is the set's problem to resolve.
        differ = sum(1 for p in points if p.verdict == DIFFER)
        vacuous = sum(1 for p in points if p.verdict == UNTESTED)
        label = ('FAIL (%d point(s) DIFFER)' % differ if differ
                 else 'PASS' if passed
                 else 'PARTIAL (%d point(s) vacuous here -- for the set to resolve)' % vacuous)
        sys.stdout.write('  case %-20s kind=%-19s %s\n' % (name, kind, label))
    ok, lines = rollup(cases)
    sys.stdout.write('\n')
    for line in lines:
        sys.stdout.write(line + '\n')
    sys.stdout.write('\n=== %s ===\n'
                     % ('THE CASE SET SATISFIES design 5.5: every point exercised by a real '
                        'observation in at least one case, and none differs' if ok else
                        'THE CASE SET DOES NOT SATISFY design 5.5 -- evidence from this wrapper '
                        'is VOID'))
    return 0 if ok else 1


def main(argv):
    import sys
    if argv and argv[0] == '--write-result':
        if len(argv) < 3:
            sys.stderr.write('usage: parity.py --write-result <output.json> <caseDir> ...\n')
            return 2
        try:
            write_result_manifest(argv[2:], argv[1])
        except (IOError, OSError, KeyError, ValueError, ManifestError) as exc:
            sys.stderr.write('REFUSED: cannot write parity result manifest: %s\n' % exc)
            return 2
        sys.stdout.write('wrote %s\n' % argv[1])
        return 0
    if argv and argv[0] == '--rollup':
        return _rollup_main(argv[1:])
    if len(argv) < 2:
        sys.stderr.write('usage: parity.py <manifestA.json> <manifestB.json>\n'
                         '       parity.py --rollup <caseDir> ...\n')
        return 2
    manA, manB = _load(argv[0]), _load(argv[1])
    if manA.get('lane') != manB.get('lane'):
        sys.stdout.write('REFUSED: the two sides ran on different lanes (%s vs %s). ORDER-371: '
                         'numbers do not transfer across installs, so a difference found here '
                         'would be unattributable.\n' % (manA.get('lane'), manB.get('lane')))
        return 2
    for key in ('symbol', 'period', 'from', 'to', 'model'):
        if manA.get(key) != manB.get(key):
            sys.stdout.write('REFUSED: the two sides ran different %s (%r vs %r). design 5.5 is '
                             'ONE data fingerprint, ONE window, ONE model.\n'
                             % (key, manA.get(key), manB.get(key)))
            return 2

    a, b = observe_manifest(manA), observe_manifest(manB)
    kind = manA.get('kind', NEUTRAL)
    points = compare(a, b)
    passed, reasons = verdict_for_case(kind, a, b, points)
    anchors = anchor_reasons(manA, a) + anchor_reasons(manB, b)
    if anchors:
        passed = False
        reasons = anchors + reasons

    sys.stdout.write('=== ORDER-1021 parity, design 5.5 -- %s ===\n' % manA.get('case', kind))
    sys.stdout.write('  lane   : %s\n' % manA.get('lane'))
    sys.stdout.write('  window : %s %s %s..%s model %s\n'
                     % (manA.get('symbol'), manA.get('period'), manA.get('from'),
                        manA.get('to'), manA.get('model')))
    for man, obs in ((manA, a), (manB, b)):
        sys.stdout.write('  %-8s %s\n             binary %s (built %s)\n'
                         % (obs.label + ':', man.get('expert'), man.get('binary'),
                            man.get('binary_mtime')))
        if obs.inputs is not None:
            sys.stdout.write('             Inputs page as the REPORT lists it: %d\n'
                             % len(obs.inputs))
    sys.stdout.write('\n')
    width = max(len(p) for p, _t in POINTS)
    for i, p in enumerate(points, start=1):
        sys.stdout.write('  %d. %-*s %-8s %s\n' % (i, width, p.point, p.verdict, p.title))
        if p.verdict != AGREE:
            sys.stdout.write('     %s\n' % p.detail)
    agree = sum(1 for p in points if p.verdict == AGREE)
    sys.stdout.write('\n  %d/7 AGREE - %d DIFFER - %d UNTESTED\n'
                     % (agree, sum(1 for p in points if p.verdict == DIFFER),
                        sum(1 for p in points if p.verdict == UNTESTED)))
    if passed:
        sys.stdout.write('=== PARITY HOLDS (%s) ===\n' % kind)
        return 0
    for r in reasons:
        sys.stdout.write('  - %s\n' % r)
    sys.stdout.write('=== PARITY DOES NOT HOLD -- evidence from this wrapper is VOID ===\n')
    return 1




# --- the per-revision roll-up ----------------------------------------------------------------------
# 🔴 DESIGN 5.5's "AGREE ON ALL SEVEN" IS NOT SATISFIABLE BY ONE RUN, and that is a property of the
# points rather than a gap in the harness. A clean run raises no errors, so point 7 has nothing to
# compare; a run that refuses at OnInit places no orders, so points 2-6 have nothing to compare.
# The two directions design 5.5 mandates are therefore not merely good practice -- they are the
# only way the seven points can ALL be exercised, and neither direction can do it alone.
#
# So the contract is satisfied by the CASE SET, and this is what checks it:
#   * no point DIFFERS in any case                                    (agreement)
#   * every point is NON-VACUOUS in at least one case                 (it was actually measured)
#   * both mandatory directions are present                           (must-trade + deliberate-refusal)
# A roll-up that only summed per-case verdicts would report seven green points while some of them
# had never once been compared against a real observation.

def rollup(cases):
    """cases: [(name, kind, [PointVerdict])] -> (passed, lines).

    `lines` is the human report; `passed` is the contract above. Nothing here re-judges a case --
    the per-case verdicts are the input, so a case that failed cannot be rescued by the roll-up.
    """
    lines = []
    names = [p for p, _t in POINTS]
    exercised = dict((p, []) for p in names)
    differed = dict((p, []) for p in names)
    for case_name, _kind, points in cases:
        for p in points:
            if p.verdict == AGREE:
                exercised[p.point].append(case_name)
            elif p.verdict == DIFFER:
                differed[p.point].append(case_name)

    kinds = set(k for _n, k, _p in cases)
    missing_dirs = [d for d in (MUST_TRADE, DELIBERATE_REFUSAL) if d not in kinds]

    width = max(len(p) for p in names)
    lines.append('  point                exercised in            differs in')
    for p in names:
        lines.append('  %-*s  %-22s  %s'
                     % (width, p, ', '.join(exercised[p]) or 'NOTHING -- never measured',
                        ', '.join(differed[p]) or '-'))

    problems = []
    for p in names:
        if differed[p]:
            problems.append('point %s DIFFERS in: %s' % (p, ', '.join(differed[p])))
        elif not exercised[p]:
            problems.append(
                'point %s was never exercised with a real observation in any case. It is '
                'UNTESTED across the whole set, not passed -- add a case that produces one.' % p)
    for d in missing_dirs:
        problems.append('the case set has no %s case. design 5.5 requires both directions, and '
                        'without it some points cannot be exercised at all.' % d)
    return (not problems, lines + ([''] + ['  - ' + p for p in problems] if problems else []))


# --- committed result manifest ---------------------------------------------------------------

_RESULT_TOP_KEYS = frozenset(('schema_version', 'entity', 'run_identity', 'cases'))
_RESULT_IDENTITY_KEYS = frozenset(('lane', 'symbol', 'period', 'from', 'to', 'model'))
_RESULT_CASE_KEYS = frozenset(('case', 'kind', 'included', 'sides', 'point_verdicts',
                               'case_passed'))
_RESULT_SIDE_KEYS = frozenset(('label', 'expert', 'binary', 'binary_mtime', 'expected_hash',
                               'source_manifest', 'observation'))
_RESULT_OBSERVATION_KEYS = frozenset(('init_fatal', 'cfg', 'orders', 'deals', 'side_effects',
                                      'alerts'))
_RESULT_POINT_KEYS = frozenset(('point', 'verdict'))


def _manifest_object(value, where):
    if not isinstance(value, dict):
        raise ManifestError('%s must be an object' % where)
    return value


def _manifest_keys(value, required, where, optional=()):
    actual = set(value)
    required = set(required)
    optional = set(optional)
    missing = sorted(required - actual)
    extra = sorted(actual - required - optional)
    if missing:
        raise ManifestError('%s is missing %s' % (where, ', '.join(missing)))
    if extra:
        raise ManifestError('%s has undeclared field(s): %s' % (where, ', '.join(extra)))


def _manifest_string(value, where, nonempty=True):
    if not isinstance(value, str) or (nonempty and not value):
        raise ManifestError('%s must be a non-empty string' % where)


def _manifest_bool(value, where):
    if not isinstance(value, bool):
        raise ManifestError('%s must be boolean' % where)


def _manifest_hex(value, where):
    _manifest_string(value, where)
    if not _HEX64.match(value):
        raise ManifestError('%s must be a lowercase SHA-256 hex digest' % where)


def _validate_observation(record, where):
    _manifest_object(record, where)
    _manifest_keys(record, _RESULT_OBSERVATION_KEYS, where)
    if record['init_fatal'] is not None and not isinstance(record['init_fatal'], str):
        raise ManifestError('%s.init_fatal must be a string or null' % where)

    cfg = record['cfg']
    if cfg is not None:
        _manifest_object(cfg, where + '.cfg')
        _manifest_keys(cfg, ('build', 'keys', 'scope', 'hash'), where + '.cfg')
        _manifest_string(cfg['build'], where + '.cfg.build')
        if not isinstance(cfg['keys'], int) or isinstance(cfg['keys'], bool) or cfg['keys'] < 0:
            raise ManifestError('%s.cfg.keys must be a non-negative integer' % where)
        _manifest_string(cfg['scope'], where + '.cfg.scope')
        _manifest_hex(cfg['hash'], where + '.cfg.hash')

    for key in ('orders', 'deals'):
        rows = record[key]
        if not isinstance(rows, list):
            raise ManifestError('%s.%s must be an array' % (where, key))
        for i, row in enumerate(rows):
            if not isinstance(row, list) or not all(isinstance(cell, str) for cell in row):
                raise ManifestError('%s.%s[%d] must be an array of strings' % (where, key, i))
    for key in ('side_effects', 'alerts'):
        values = record[key]
        if not isinstance(values, list) or not all(isinstance(v, str) for v in values):
            raise ManifestError('%s.%s must be an array of strings' % (where, key))


def _validate_result_manifest(manifest):
    _manifest_object(manifest, 'result manifest')
    _manifest_keys(manifest, _RESULT_TOP_KEYS, 'result manifest')
    if manifest['schema_version'] != RESULT_SCHEMA_VERSION:
        raise ManifestError('result manifest schema_version must be %d' % RESULT_SCHEMA_VERSION)
    if manifest['entity'] != RESULT_ENTITY:
        raise ManifestError('result manifest entity must be %s' % RESULT_ENTITY)

    identity = _manifest_object(manifest['run_identity'], 'result manifest.run_identity')
    _manifest_keys(identity, _RESULT_IDENTITY_KEYS, 'result manifest.run_identity')
    for key in ('lane', 'symbol', 'period', 'from', 'to'):
        _manifest_string(identity[key], 'result manifest.run_identity.%s' % key)
    if (not isinstance(identity['model'], int) or isinstance(identity['model'], bool)
            or identity['model'] not in (1, 2, 4)):
        raise ManifestError('result manifest.run_identity.model must be 1, 2, or 4')

    cases = manifest['cases']
    if not isinstance(cases, list) or not cases:
        raise ManifestError('result manifest.cases must be a non-empty array')
    names = set()
    for i, case in enumerate(cases):
        where = 'result manifest.cases[%d]' % i
        _manifest_object(case, where)
        _manifest_keys(case, _RESULT_CASE_KEYS, where, optional=('exclusion_reason',))
        _manifest_string(case['case'], where + '.case')
        if case['case'] in names:
            raise ManifestError('duplicate case %r in result manifest' % case['case'])
        names.add(case['case'])
        if case['kind'] not in (MUST_TRADE, DELIBERATE_REFUSAL, NEUTRAL):
            raise ManifestError('%s.kind is not a parity case kind' % where)
        _manifest_bool(case['included'], where + '.included')
        _manifest_bool(case['case_passed'], where + '.case_passed')
        if case['included']:
            if 'exclusion_reason' in case:
                raise ManifestError('%s included case cannot carry exclusion_reason' % where)
        else:
            if case['case'] != 'locked-absent' or case.get('exclusion_reason') != 'EXPECTED_DIFFERENCE':
                raise ManifestError('%s only locked-absent may be excluded, with reason '
                                    'EXPECTED_DIFFERENCE' % where)

        sides = _manifest_object(case['sides'], where + '.sides')
        if set(sides) != {'wrapper', 'parent'}:
            raise ManifestError('%s.sides must contain exactly wrapper and parent' % where)
        for side_name in ('wrapper', 'parent'):
            side = _manifest_object(sides[side_name], where + '.sides.' + side_name)
            _manifest_keys(side, _RESULT_SIDE_KEYS, where + '.sides.' + side_name)
            if side['label'] != side_name:
                raise ManifestError('%s.label must be %s' % (where, side_name))
            for key in ('expert', 'binary', 'binary_mtime', 'source_manifest'):
                _manifest_string(side[key], where + '.sides.%s.%s' % (side_name, key))
            _manifest_hex(side['expected_hash'], where + '.sides.%s.expected_hash' % side_name)
            if ':' in side['source_manifest'] or side['source_manifest'].startswith(('\\', '/')):
                raise ManifestError('%s.source_manifest must be repository-relative' % where)
            _validate_observation(side['observation'],
                                  where + '.sides.%s.observation' % side_name)

        points = case['point_verdicts']
        if not isinstance(points, list) or len(points) != len(POINTS):
            raise ManifestError('%s.point_verdicts must contain exactly seven points' % where)
        for point, (expected, _title) in zip(points, POINTS):
            _manifest_object(point, where + '.point_verdicts')
            _manifest_keys(point, _RESULT_POINT_KEYS, where + '.point_verdicts')
            if point['point'] != expected:
                raise ManifestError('%s.point_verdicts must be in canonical order' % where)
            if point['verdict'] not in (AGREE, DIFFER, UNTESTED, NOT_APPLICABLE):
                raise ManifestError('%s.point_verdicts[%s].verdict is unknown' % (where, expected))


def read_result_manifest(text, source=RESULT_MANIFEST_REL):
    """Parse one committed result manifest; never substitute raw tester files."""
    import json
    if not isinstance(text, str):
        raise ManifestError('%s is not text' % source)
    try:
        manifest = json.loads(text)
    except (TypeError, ValueError) as exc:
        raise ManifestError('%s is not valid JSON: %s' % (source, exc))
    try:
        _validate_result_manifest(manifest)
    except ManifestError as exc:
        raise ManifestError('%s is invalid: %s' % (source, exc))
    return manifest


def _recorded_points(points):
    return [{'point': p.point, 'verdict': p.verdict} for p in points]


def evaluate_result_manifest(manifest):
    """Replay every recorded case and return machine-readable acceptance facts."""
    _validate_result_manifest(manifest)
    replay_problems = []
    included_cases = []
    direction_state = {MUST_TRADE: [], DELIBERATE_REFUSAL: []}
    for case in manifest['cases']:
        sides = case['sides']
        a = observation_from_record(sides['wrapper']['observation'], 'wrapper')
        b = observation_from_record(sides['parent']['observation'], 'parent')
        points = compare(a, b)
        recorded = case['point_verdicts']
        actual_points = _recorded_points(points)
        if recorded != actual_points:
            replay_problems.append('%s recorded point verdicts do not match parity.py replay'
                                   % case['case'])
        passed, _reasons = verdict_for_case(case['kind'], a, b, points)
        anchors = anchor_reasons(sides['wrapper'], a) + anchor_reasons(sides['parent'], b)
        if anchors and case['included']:
            replay_problems.append('%s has compiler-anchor mismatch' % case['case'])
        if anchors:
            passed = False
        if case['case_passed'] != passed:
            replay_problems.append('%s recorded case result does not match parity.py replay'
                                   % case['case'])
        if case['included']:
            included_cases.append((case['case'], case['kind'], points))
            if case['kind'] in direction_state:
                direction_state[case['kind']].append(not direction_reasons(case['kind'], a, b))

    rollup_ok, rollup_lines = rollup(included_cases)
    directions = {
        MUST_TRADE: any(direction_state[MUST_TRADE]),
        DELIBERATE_REFUSAL: any(direction_state[DELIBERATE_REFUSAL]),
    }
    direction_failures = {
        kind: bool(values) and not any(values)
        for kind, values in direction_state.items()
    }
    return {
        'replay_ok': not replay_problems,
        'replay_problems': replay_problems,
        'rollup_ok': rollup_ok,
        'rollup_lines': rollup_lines,
        'directions': directions,
        'direction_failures': direction_failures,
    }


def _case_result(name, kind, wrapper, parent, included=True, exclusion_reason=None,
                 source_wrapper='', source_parent=''):
    """Build the committed, report-free representation for one raw parity case."""
    points = compare(wrapper['observation'], parent['observation'])
    passed, _reasons = verdict_for_case(kind, wrapper['observation'], parent['observation'], points)
    anchors = anchor_reasons(wrapper, wrapper['observation']) + anchor_reasons(parent,
                                                                                parent['observation'])
    if anchors:
        passed = False
    def side_result(raw, obs, source):
        return {
            'label': raw['label'],
            'expert': raw['expert'],
            'binary': raw['binary'],
            'binary_mtime': raw['binary_mtime'],
            'expected_hash': raw['expected_hash'],
            'source_manifest': source,
            'observation': observation_to_record(obs),
        }

    out = {
        'case': name,
        'kind': kind,
        'included': included,
        'sides': {
            'wrapper': side_result(wrapper, wrapper['observation'], source_wrapper),
            'parent': side_result(parent, parent['observation'], source_parent),
        },
        'point_verdicts': _recorded_points(points),
        'case_passed': passed,
    }
    if not included:
        out['exclusion_reason'] = exclusion_reason
    return out


def write_result_manifest(case_dirs, output_path):
    """Materialize committed evidence from the raw side manifests and their current artifacts."""
    import json
    import os
    if not case_dirs:
        raise ManifestError('at least one parity case directory is required')
    result_cases = []
    identity = None
    for case_dir in case_dirs:
        case_dir = os.path.abspath(case_dir)
        wrapper_path = os.path.join(case_dir, 'wrapper.json')
        parent_path = os.path.join(case_dir, 'parent.json')
        wrapper = _load(wrapper_path)
        parent = _load(parent_path)
        if wrapper.get('label') != 'wrapper' or parent.get('label') != 'parent':
            raise ManifestError('%s must contain wrapper and parent side labels' % case_dir)
        for key in ('case', 'kind', 'lane', 'symbol', 'period', 'from', 'to', 'model'):
            if wrapper.get(key) != parent.get(key):
                raise ManifestError('%s side identity mismatch at %s' % (case_dir, key))
        case_identity = {key: wrapper[key] for key in
                         ('lane', 'symbol', 'period', 'from', 'to', 'model')}
        if identity is None:
            identity = case_identity
        elif identity != case_identity:
            raise ManifestError('%s does not share the result-set identity' % case_dir)
        wrapper_obs = observe_manifest(wrapper)
        parent_obs = observe_manifest(parent)
        wrapper_record = dict(wrapper)
        parent_record = dict(parent)
        wrapper_record['observation'] = wrapper_obs
        parent_record['observation'] = parent_obs
        rel_wrapper = os.path.relpath(wrapper_path, os.path.dirname(os.path.abspath(output_path)))
        rel_parent = os.path.relpath(parent_path, os.path.dirname(os.path.abspath(output_path)))
        rel_wrapper = rel_wrapper.replace(os.sep, '/')
        rel_parent = rel_parent.replace(os.sep, '/')
        result_cases.append(_case_result(
            wrapper.get('case'), wrapper.get('kind'), wrapper_record, parent_record,
            included=wrapper.get('case') != 'locked-absent',
            exclusion_reason='EXPECTED_DIFFERENCE' if wrapper.get('case') == 'locked-absent' else None,
            source_wrapper=rel_wrapper, source_parent=rel_parent))

    manifest = {
        'schema_version': RESULT_SCHEMA_VERSION,
        'entity': RESULT_ENTITY,
        'run_identity': identity,
        'cases': result_cases,
    }
    _validate_result_manifest(manifest)
    out_dir = os.path.dirname(os.path.abspath(output_path))
    if out_dir and not os.path.isdir(out_dir):
        os.makedirs(out_dir)
    with open(output_path, 'w', encoding='utf-8', newline='\n') as fh:
        json.dump(manifest, fh, ensure_ascii=False, indent=2, sort_keys=False)
        fh.write('\n')
    return manifest


if __name__ == '__main__':
    import sys as _sys
    _sys.exit(main(_sys.argv[1:]))
