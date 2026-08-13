# -*- coding: utf-8 -*-
"""ORDER-1080 (slice S9) -- the cage for the recoverable, idempotent scheduler.

THE ACCEPTANCE THIS FILE OWNS (design section 10, S9 row, verbatim):
  1. kill at EVERY state in design 3.3 => resume re-runs zero completed attempts, double-launches
     nothing, duplicates no event
  2. COMPLETED is refused without a fresh report
  3. re-running an identical (config, lane, data fingerprint) is refused except after an
     execution/tester error -- cached evidence is returned instead
  4. cross-lane comparison is refused, and LEASED is refused without a free lane lease

WHY THE MATRIX IS ENUMERATED AND NOT SAMPLED
  `dda6783a` (W9, the wrapper-gen suite) is the model: a brute-force sweep over every assignment,
  not two hand-picked ones. A kill test that samples two of five states is a claim about the other
  three wearing a pass. So PART 1 kills at EVERY (action, phase) the driver can be in -- both
  before the side effect and after it but before its line is appended -- crossed with two resume
  delays, and then REFUSES TO PASS unless the roll-up shows all nine transitions of design 3.3 had
  a kill OBSERVED on both sides of their own append. A state the scenarios never reached is a hole
  the roll-up must name, not a number that quietly stayed at zero.

WHY THE KILLS ARE OBSERVED RATHER THAN ASSERTED
  The stub world counts what actually happened: `launches`, `max_live` (peak concurrent workers),
  `event_appends`. "Double-launches nothing" is `max_live <= 1` measured by the thing that would
  have been launched twice, not by reading the planner's intent back to itself.

  STATED LIMIT, because a cage that oversells itself is GUARD_SHAPES shape 3 wearing a badge: this
  proves the STATE MACHINE, not the wiring. `plan()` is driven here by a stub; that the real
  PowerShell dispatcher performs each action correctly is proven ONCE by a real tester run, and
  the only mechanical link between them is PART 3, which asserts the dispatcher handles exactly
  the action set `plan()` can emit.

USAGE  tools\\python312\\python.exe _triage/factory_os/run_scheduler_tests.py
EXIT   0 = every criterion refused its attack and the matrix is complete  -  1 = a failure
"""

import calendar
import io
import json
import os
import re
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scheduler as S                                                      # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
DISPATCHER_REL = 'scripts/scheduler_run.ps1'

FAILS = []
NAMED = set()          # every criterion id / action / refusal code this suite names


def check(label, ok, detail=''):
    if ok:
        sys.stdout.write('  [OK ] %s\n' % label)
    else:
        FAILS.append(label)
        sys.stdout.write('  [FAIL] %s\n' % label)
        if detail:
            sys.stdout.write('        -> %s\n' % detail)
    return ok


def refuses(label, problems, expect_id):
    """A refusal must be refused FOR THE STATED REASON. Matching only on 'the list is non-empty'
    is how a test passes on an unrelated defect and then stops noticing the one it was written
    for -- the S1 shape check would otherwise satisfy every case below."""
    NAMED.add(expect_id)
    hit = [p for p in problems if p.startswith(expect_id + ' ')]
    return check('%-4s %s' % (expect_id, label), bool(hit),
                 'expected a %s finding, got %s' % (expect_id, problems or 'nothing'))


# =============================================================================================
# THE STUB WORLD -- everything the real driver observes, and nothing it does not
# =============================================================================================
BASE_KEY = {
    'expert': 'EALabTpl\\generated\\B14_H01_r1', 'symbol': 'XAUUSD', 'tf': 'H1',
    'from_date': '2024.01.01', 'to_date': '2024.01.15', 'model': 1, 'deposit': 10000,
    'currency': 'USD', 'account_unit': 'USD', 'leverage': 100, 'terminal_build': 6090,
    # NO `ini_hash`: it moved to `RunAttempt.ini_sha256` (owner decision 2026-08-02, item 6). The
    # shape refusal in `execution_key_digest` is what makes this a real change rather than a
    # convention -- a key still carrying it is now an UNKNOWN field and is refused.
    'set_hash': 'a' * 64, 'ex5_hash': 'c' * 64,
    'effective_config_hash': 'd' * 64,
    'data_fingerprint': 'lane1|XAUUSD|H1|2024.01.01|2024.01.15|1', 'lane': 'lane1',
}
RUN = 'RUN-20260802-001'
CELL = 'B14-H01-r1/XAUUSD/H1/MAIN'


class Killed(Exception):
    pass


class World(object):
    """The observable universe of one lane. Survives the driver's death, exactly as a real lane
    does -- which is the whole reason a resume can be wrong."""

    def __init__(self, scenario):
        self.lines = []
        self.lease = None
        self.evidence = None
        self.scenario = scenario
        # the worker: 'idle' -> 'starting' -> 'testing' -> 'done' | 'dead'
        self.worker = 'idle'
        self.worker_attempt = None
        # EVERYTHING BELOW IS KEYED BY ATTEMPT, and that is not tidiness. The first version held
        # one exit record for the whole run, so attempt 2 opened while attempt 1's exit record was
        # still observable and the planner declared attempt 2 finished before it had launched. The
        # real driver has the same shape for the same reason: the sidecar path carries the attempt.
        self.spawn_markers = set()
        self.exit_records = {}
        self.report_fresh = {}
        self.report_mtime = {}
        self.clock = 0
        self.testing_ticks = 0
        # OBSERVED COUNTERS -- the acceptance is read off these, not off the planner's opinion
        self.launches = 0
        self.live = 0
        self.max_live = 0
        self.event_appends = 0
        self.releases = 0
        self.renewals = 0

    # -- time ---------------------------------------------------------------------------------
    def now(self):
        h, rem = divmod(self.clock, 3600)
        m, s = divmod(rem, 60)
        return '2026-08-02T%02d:%02d:%02dZ' % (h, m, s)

    def later(self, seconds):
        c = self.clock + seconds
        h, rem = divmod(c, 3600)
        m, s = divmod(rem, 60)
        return '2026-08-02T%02d:%02d:%02dZ' % (h, m, s)

    def tick(self, n=1):
        for _ in range(n):
            self.clock += 30
            self.scenario.advance(self)

    # -- effects ------------------------------------------------------------------------------
    def launch(self, attempt):
        self.launches += 1
        self.live += 1
        self.max_live = max(self.max_live, self.live)
        self.worker = 'starting'
        self.worker_attempt = attempt
        self.spawn_markers.add(attempt)

    def finish(self, exit_code, fresh, stdout_tail=''):
        a = self.worker_attempt
        if self.live > 0:
            self.live -= 1
        self.worker = 'done'
        self.exit_records[a] = {'exit_code': exit_code, 'at': self.now(),
                                'stdout_tail': stdout_tail}
        self.report_fresh[a] = fresh
        self.report_mtime[a] = self.now()

    def die_silently(self):
        """A hard kill of the worker: no exit record is ever written. This is the state
        RECONCILE_ORPHAN exists for, and it is the one a resume could mistake for success."""
        if self.live > 0:
            self.live -= 1
        self.worker = 'dead'

    def observe(self):
        j = self.journal
        a = S.current_attempt(j) if j else 0
        return {
            'now': self.now(),
            'lease': self.lease,
            'child_running': self.worker in ('starting', 'testing'),
            'tester_running': self.worker == 'testing',
            'spawn_marker': a in self.spawn_markers,
            'exit_record': self.exit_records.get(a),
            'report_fresh': self.report_fresh.get(a),
            'report_path': '_mt5_auto/reports/%s.htm' % RUN,
            'report_mtime': self.report_mtime.get(a),
            'evidence': self.evidence,
        }

    @property
    def journal(self):
        return S.fold(self.lines)

    def append(self, line):
        problems = S.validate_transition(self.journal, line)
        if problems:
            raise AssertionError('the driver produced an INVALID line %s: %s'
                                 % (line.get('transition'), problems))
        self.lines.append(line)


class Scenario(object):
    """How the worker behaves once launched. One object per way a run can end.

    `lease_seconds` is here rather than fixed in the driver because a lease long enough to outlast
    every scenario makes `RENEW_LEASE` unreachable -- and an action the matrix can never reach is
    an action the matrix says nothing about, however green it prints.
    """

    def __init__(self, name, on_advance, lease_seconds=3600):
        self.name = name
        self._advance = on_advance
        self.lease_seconds = lease_seconds

    def advance(self, world):
        self._advance(world)


def _adv_ok(w):
    if w.worker == 'starting':
        w.worker = 'testing'
    elif w.worker == 'testing':
        w.finish(0, True)


def _adv_exit1(w):
    if w.worker == 'starting':
        w.worker = 'testing'
    elif w.worker == 'testing':
        w.finish(1, None)


def _adv_silent_death(w):
    if w.worker == 'starting':
        w.worker = 'testing'
    elif w.worker == 'testing':
        w.die_silently()


def _adv_slow(w):
    """A worker that is actually SLOW, which is what a tester run is.

    🔴 /scrutinize round 1 added this scenario because the corrected roll-up immediately failed on
    `RUNNING`: in every fast scenario the worker went starting -> testing -> done inside two ticks,
    so by the time the driver held a PROCESS_OBSERVED line the exit record already existed and
    `OBSERVE_RUNNING` was NEVER the action being killed. The old roll-up passed anyway, because it
    counted a point REACHED in one cell as covering the cell that was supposed to kill there. So
    the claim "all nine transitions killed on both sides" was not merely unmeasured -- it was
    FALSE for RUNNING, and the measurement bug is what hid it. A real backtest takes minutes; this
    scenario is the realistic one and the two-tick ones are the degenerate boundary.
    """
    if w.worker == 'starting':
        w.worker = 'testing'
        w.testing_ticks = 0
    elif w.worker == 'testing':
        w.testing_ticks += 1
        if w.testing_ticks >= 3:
            w.finish(0, True)


def _adv_lease_stolen(w):
    """Another lane user takes the lease out from under this run. This is the ONLY scenario that
    reaches ABANDONED, and it exists because the roll-up refused to pass without it: the first
    matrix covered eight of the nine transitions and reported nothing about the ninth."""
    if w.lease and w.lease.get('owner') == RUN:
        w.lease = {'lease_id': 'L-OTHER', 'owner': 'RUN-20260801-099',
                   'expires_at': w.later(7200)}
    _adv_ok(w)


SCEN_OK = Scenario('completes', _adv_ok)
SCEN_SLOW = Scenario('completes slowly, like a real tester run', _adv_slow)
SCEN_EXIT1 = Scenario('tester error then retry', _adv_exit1)
SCEN_KILLED = Scenario('worker killed with no exit record', _adv_silent_death)
SCEN_LEASE = Scenario('lane lease stolen mid-run', _adv_lease_stolen)
# A lease SHORTER than the renewal margin, so a run that is still working must renew it. This is
# the realistic shape for a Model-4 multi-year run against the dispatcher's 4-hour default.
SCEN_RENEW = Scenario('slow worker on a short lease', _adv_slow,
                      lease_seconds=S.RENEW_MARGIN_SEC // 2)


# =============================================================================================
# THE DRIVER -- plan / perform / append, and nothing else. Every decision is in scheduler.plan().
# =============================================================================================
# What each action APPENDS, so the kill matrix can be keyed by state as well as by action. None
# means "this action has a side effect but writes no line" -- LAUNCH is the important one.
ACTION_WRITES = {
    'ACQUIRE_LEASE': 'LEASED', 'ADOPT_LEASE': 'LEASED', 'RENEW_LEASE': None,
    'DECLARE_LAUNCH_INTENT': 'LAUNCH_INTENT', 'LAUNCH': None,
    'ADOPT_PROCESS': 'PROCESS_OBSERVED', 'OBSERVE_RUNNING': 'RUNNING', 'WAIT': None,
    'RECORD_COMPLETED': 'COMPLETED', 'RECORD_FAILED': 'FAILED', 'RECONCILE_ORPHAN': 'FAILED',
    'REGISTER_EVIDENCE': 'EVIDENCE_REGISTERED', 'ADOPT_EVIDENCE': 'EVIDENCE_REGISTERED',
    'RELEASE_LEASE': None, 'ABANDON': 'ABANDONED', 'DONE': None, 'REFUSE': None,
}
assert set(ACTION_WRITES) == set(S.ACTIONS), 'the driver does not cover the closed action set'


def drive(world, kill_at=None, budget=60, killed=None, relaunch_bug=False):
    """Run the loop until DONE/REFUSE, or until `kill_at` = (action, phase) is reached.

    `phase` is 'before' (the side effect has not happened) or 'after' (it has, and the line has
    not been written). Those are the only two crash windows a step has, which is why enumerating
    them is enumeration rather than sampling.

    🔴 /scrutinize round 1: `killed` records ONLY the points where a kill actually fired. The
    first version recorded every point the driver REACHED and the roll-up then printed "every
    transition had a kill observed" over it. Reaching and being killed at are different facts, and
    the set was shared across all 256 cells, so a point reached in one cell satisfied the roll-up
    for every other. The conclusion happened to be true; the measurement did not establish it,
    which is GUARD_SHAPES shape 4 -- a claim stated without measuring it in the same breath.
    """
    for _ in range(budget):
        journal = world.journal
        act = S.plan(journal, world.observe())
        name = act['action']
        if relaunch_bug and name == 'ADOPT_PROCESS':
            # THE DELIBERATE DEFECT, used to prove the matrix can go RED. A resume that relaunches
            # instead of adopting is precisely the bug acceptance criterion 1 exists to forbid.
            name = 'LAUNCH'
            act = {'action': 'LAUNCH', 'attempt': act['attempt'], 'why': 'injected defect'}
        if kill_at == (name, 'before'):
            if killed is not None:
                killed.add((name, 'before'))
            raise Killed()

        line = _perform(world, act, name)

        if kill_at == (name, 'after'):
            if killed is not None:
                killed.add((name, 'after'))
            raise Killed()

        if line is not None:
            world.append(line)
        if name in ('DONE', 'REFUSE'):
            return act
        world.tick()
    raise AssertionError('the driver did not converge within %d steps' % budget)


def _perform(world, act, name):
    """The dumb half. Performs the side effect and returns the line to append, or None."""
    now = world.now()
    attempt = act.get('attempt')
    base = {'entity': 'RunTransition', 'run_id': RUN, 'cell_id': CELL, 'attempt': attempt,
            'at': now}

    if name in ('DONE', 'REFUSE'):
        return None
    if name == 'WAIT':
        return None
    if name == 'ACQUIRE_LEASE':
        world.lease = {'lease_id': 'L-%s-%d' % (RUN, attempt), 'owner': RUN,
                       'expires_at': world.later(world.scenario.lease_seconds)}
        base['transition'] = 'LEASED'
        base['record'] = {'attempt': attempt, 'transition': 'LEASED', 'at': now,
                          'lease': dict(world.lease)}
        return base
    if name == 'ADOPT_LEASE':
        base['transition'] = 'LEASED'
        base['record'] = {'attempt': attempt, 'transition': 'LEASED', 'at': now,
                          'lease': dict(world.lease)}
        return base
    if name == 'DECLARE_LAUNCH_INTENT':
        base['transition'] = 'LAUNCH_INTENT'
        base['record'] = {'attempt': attempt, 'transition': 'LAUNCH_INTENT', 'at': now,
                          'launch_intent_at': now}
        return base
    if name == 'LAUNCH':
        world.launch(attempt)
        return None
    if name == 'ADOPT_PROCESS':
        base['transition'] = 'PROCESS_OBSERVED'
        base['record'] = {'attempt': attempt, 'transition': 'PROCESS_OBSERVED', 'at': now,
                          'process_observed': {'pid': 4242, 'observed_at': now,
                                               'process_fingerprint': 'lane1'}}
        return base
    if name == 'OBSERVE_RUNNING':
        base['transition'] = 'RUNNING'
        return base
    if name == 'RECORD_COMPLETED':
        base['transition'] = 'COMPLETED'
        base['record'] = {'attempt': attempt, 'transition': 'COMPLETED', 'at': now,
                          'exit_code': act['exit_code'], 'failure_class': 'NONE',
                          'report_fresh_proof': act['proof']}
        return base
    if name in ('RECORD_FAILED', 'RECONCILE_ORPHAN'):
        base['transition'] = 'FAILED'
        base['record'] = {'attempt': attempt, 'transition': 'FAILED', 'at': now,
                          'exit_code': act.get('exit_code'),
                          'failure_class': act['failure_class']}
        return base
    if name == 'REGISTER_EVIDENCE':
        world.event_appends += 1
        world.evidence = {'event_id': 'evt-0001', 'evidence_id': 'evd_sha256_' + 'e' * 64}
        base['transition'] = 'EVIDENCE_REGISTERED'
        base['record'] = {'attempt': attempt, 'transition': 'EVIDENCE_REGISTERED', 'at': now,
                          'event_id': world.evidence['event_id']}
        return base
    if name == 'ADOPT_EVIDENCE':
        base['transition'] = 'EVIDENCE_REGISTERED'
        base['record'] = {'attempt': attempt, 'transition': 'EVIDENCE_REGISTERED', 'at': now,
                          'event_id': act['event_id']}
        return base
    if name == 'RENEW_LEASE':
        world.lease = {'lease_id': world.lease['lease_id'], 'owner': world.lease['owner'],
                       'expires_at': act['expires_at']}
        world.renewals += 1
        return None
    if name == 'RELEASE_LEASE':
        world.lease = {'lease_id': world.lease['lease_id'], 'owner': world.lease['owner'],
                       'expires_at': now}
        world.releases += 1
        return None
    if name == 'ABANDON':
        base['transition'] = 'ABANDONED'
        base['record'] = {'attempt': attempt, 'transition': 'ABANDONED', 'at': now,
                          'failure_class': act['failure_class']}
        return base
    raise AssertionError('the driver has no branch for action %r' % name)


def queue(world):
    dec = S.queue_decision({}, BASE_KEY, CELL, world.now(), RUN)
    assert dec['action'] == 'QUEUED', dec
    world.append(dec['line'])


def run_to_end(world, kills=(), delays=(), killed=None, relaunch_bug=False):
    """Queue, then drive; on each kill, resume after `delay` ticks of the worker's own life.

    Returns ('killed', final_action) when the kill fired and the resume converged, or
    ('never-reached', final_action) when this scenario simply never reaches that point -- a
    distinction the caller MUST keep, because a cell that was never killed is not a recovery and
    must not be counted as one.
    """
    queue(world)
    fired = False
    for kill, delay in zip(kills, delays):
        try:
            act = drive(world, kill_at=kill, killed=killed, relaunch_bug=relaunch_bug)
            return 'never-reached', act
        except Killed:
            fired = True
            world.tick(delay)
    act = drive(world, killed=killed, relaunch_bug=relaunch_bug)
    return ('killed' if fired else 'never-reached'), act


# =============================================================================================
sys.stdout.write('=== ORDER-1080 scheduler cage (slice S9) ===\n\n')
sys.stdout.write('PART 1 - the kill matrix, ENUMERATED over every (action, phase) x resume delay\n')

# The no-kill control first. Without it every invariant below could be true because nothing ran.
ctl = World(SCEN_OK)
run_to_end(ctl)
check('CONTROL an unkilled run reaches EVIDENCE_REGISTERED with exactly one launch and one event',
      S.tail(ctl.journal) == 'EVIDENCE_REGISTERED' and ctl.launches == 1
      and ctl.event_appends == 1 and ctl.max_live == 1,
      'tail=%s launches=%d events=%d max_live=%d'
      % (S.tail(ctl.journal), ctl.launches, ctl.event_appends, ctl.max_live))
check('CONTROL and it HANDS THE LANE BACK before it exits -- the lease expiry is for a dead '
      'machine, not for a live run that has finished (found by the first real wiring run, where '
      'run 001 held the lane for four hours after it was done)',
      ctl.releases == 1 and ctl.lease['expires_at'] <= ctl.now(),
      'releases=%d lease=%s' % (ctl.releases, ctl.lease))

SCENARIOS = [
    ('completes', SCEN_OK, 'EVIDENCE_REGISTERED', 1),
    ('completes-slowly', SCEN_SLOW, 'EVIDENCE_REGISTERED', 1),
    ('tester-error-then-retry', SCEN_EXIT1, None, 2),
    ('worker-killed-silently', SCEN_KILLED, None, 2),
    ('lane-lease-stolen', SCEN_LEASE, None, 0),
    ('slow-on-a-short-lease', SCEN_RENEW, 'EVIDENCE_REGISTERED', 1),
]
DELAYS = (0, 9)          # 0 = the worker is exactly where the kill left it; 9 = it ran on and finished

killed_points = set()
matrix_cells = 0
matrix_kills = 0
matrix_bad = []
for scen_name, scen, expect_tail, _ in SCENARIOS:
    for action in S.ACTIONS:
        for phase in ('before', 'after'):
            for delay in DELAYS:
                w = World(scen)
                try:
                    outcome, _final = run_to_end(w, kills=[(action, phase)], delays=[delay],
                                                 killed=killed_points)
                except Killed:
                    matrix_bad.append('%s/%s/%s/%d: a second kill fired' % (scen_name, action, phase, delay))
                    continue
                except AssertionError as exc:
                    matrix_bad.append('%s/%s/%s/%d: %s' % (scen_name, action, phase, delay, exc))
                    continue
                matrix_cells += 1
                if outcome == 'killed':
                    matrix_kills += 1
                    # I6 RECOVERY CONVERGES. A resume that survives every invariant below and
                    # still lands somewhere else than the unkilled control has not recovered, it
                    # has taken a different path to a different answer -- and nothing else here
                    # would say so. Only asserted for scenarios with ONE possible ending; the
                    # retry and lease-theft scenarios legitimately end in several places.
                    if expect_tail and S.tail(w.journal) != expect_tail:
                        matrix_bad.append('%s/%s/%s/%d: killed run ended at %s, control ends at %s'
                                          % (scen_name, action, phase, delay,
                                             S.tail(w.journal), expect_tail))
                # I1 nothing was ever launched twice at once -- MEASURED by the stub, not asserted
                if w.max_live > 1:
                    matrix_bad.append('%s/%s/%s/%d: max_live=%d (a DOUBLE LAUNCH)'
                                      % (scen_name, action, phase, delay, w.max_live))
                # I2 no completed attempt was re-run: a launch per attempt, never more
                attempts = max(a['attempt'] for a in w.journal['attempts'])
                if w.launches > attempts:
                    matrix_bad.append('%s/%s/%s/%d: %d launches for %d attempt(s)'
                                      % (scen_name, action, phase, delay, w.launches, attempts))
                # I3 the event store was never appended to twice
                if w.event_appends > 1:
                    matrix_bad.append('%s/%s/%s/%d: %d event appends'
                                      % (scen_name, action, phase, delay, w.event_appends))
                # I4 the manifest holds no duplicate (attempt, transition) pair
                seen = set()
                for a in w.journal['attempts']:
                    pair = (a['attempt'], a['transition'])
                    if pair in seen:
                        matrix_bad.append('%s/%s/%s/%d: duplicate line %s'
                                          % (scen_name, action, phase, delay, pair))
                    seen.add(pair)
                # I5 a completed attempt stays completed
                if 'COMPLETED' in [a['transition'] for a in w.journal['attempts']] \
                        and S.tail(w.journal) not in ('COMPLETED', 'EVIDENCE_REGISTERED'):
                    matrix_bad.append('%s/%s/%s/%d: a COMPLETED attempt ended at %s'
                                      % (scen_name, action, phase, delay, S.tail(w.journal)))

check('the matrix ran every (scenario x action x phase x delay) cell without an invalid line',
      not matrix_bad, '; '.join(matrix_bad[:6]))
# TWO NUMBERS, because they are two different facts. /scrutinize round 1: the headline said
# "256 resumes" and 256 was the CELL count -- most of a scenario's action list is unreachable in
# it (SCEN_OK never abandons), so those cells converged without any kill and were counted as
# recoveries anyway. The cell count says the sweep was complete; the kill count says how much of
# it was a recovery. Reporting only the larger one is how a sweep flatters itself.
check('matrix swept %d cells (%d scenarios x %d actions x 2 phases x 2 delays) of which %d were '
      'a real kill-and-resume' % (matrix_cells, len(SCENARIOS), len(S.ACTIONS), matrix_kills),
      matrix_cells >= len(SCENARIOS) * len(S.ACTIONS) and matrix_kills > 0)

# --- THE ROLL-UP. A state the scenarios never reached is a hole, and it must FAIL here rather
#     than leave a zero nobody reads. This is the parity harness's round-1 lesson made mechanical.
killed_states = {}
for (action, phase) in killed_points:
    writes = ACTION_WRITES[action]
    if writes:
        killed_states.setdefault(writes, set()).add(phase)
missing = []
for t in S.TRANSITIONS:
    if t == 'QUEUED':
        continue          # written by `queue`, before any driver exists -- see the dedicated case below
    got = killed_states.get(t, set())
    if got != {'before', 'after'}:
        missing.append('%s (%s)' % (t, sorted(got) or 'never reached'))
check('ROLL-UP every design 3.3 transition had a kill observed on BOTH sides of its own append',
      not missing, 'not exercised: ' + ', '.join(missing))

# QUEUED's own crash window: the manifest does not exist yet, so the crash is "the file was never
# written". Its resume is `queue` again, and criterion 3's own gate is what must not double it.
w = World(SCEN_OK)
before_state = S.plan(None, w.observe())
check('QUEUED kill: a resume with no manifest at all REFUSES with UNKNOWN_RUN rather than guessing',
      before_state['action'] == 'REFUSE' and before_state['code'] == 'UNKNOWN_RUN',
      str(before_state))
NAMED.add('UNKNOWN_RUN')

# --- RED FIRST. The matrix is only worth its runtime if it can fail; prove it with the exact
#     defect criterion 1 forbids -- a resume that relaunches instead of adopting a live process.
red_caught = False
for phase in ('before', 'after'):
    w = World(SCEN_OK)
    try:
        run_to_end(w, kills=[('LAUNCH', phase)], delays=[0], relaunch_bug=True)
    except (Killed, AssertionError):
        # THE COUNTERS ARE READ EVEN WHEN THE DEFECTIVE DRIVE THROWS, and that correction is the
        # point: the injected defect makes the loop stop converging, the first version caught the
        # AssertionError and `continue`d past the check, and the RED probe reported that a
        # deliberate double launch went unnoticed. A probe whose evidence is discarded on the
        # exact path the defect produces is not a probe.
        pass
    if w.max_live > 1 or w.launches > 1:
        red_caught = True
check('RED a resume that RELAUNCHES instead of adopting a live process is caught by max_live/launches',
      red_caught, 'the injected double-launch defect went unnoticed - the matrix proves nothing')

# --- and the counters must be able to move at all (a stub that never counts passes everything)
check('RED the stub actually counts: the control run recorded launches=1, events=1, max_live=1',
      (ctl.launches, ctl.event_appends, ctl.max_live) == (1, 1, 1))

sys.stdout.write('\nPART 2 - the monotonic transition validator, one attack per criterion\n')


def L(transition, attempt=1, at='2026-08-02T00:01:00Z', **rec):
    line = {'entity': 'RunTransition', 'run_id': RUN, 'cell_id': CELL, 'attempt': attempt,
            'transition': transition, 'at': at}
    if rec:
        rec.setdefault('attempt', attempt)
        rec.setdefault('transition', transition)
        rec.setdefault('at', at)
        line['record'] = rec
    return line


def J(*lines):
    return S.fold(list(lines))


QUEUED_LINE = dict(L('QUEUED', at='2026-08-02T00:00:00Z'), execution_key=dict(BASE_KEY))
GOOD_PROOF = {'runner_exit': 0, 'report_path': '_mt5_auto/reports/RUN_20260802_001.htm',
              'report_mtime': '2026-08-02T00:05:00Z', 'run_start': '2026-08-02T00:02:00Z'}
SPINE = [QUEUED_LINE,
         L('LEASED', lease={'lease_id': 'L1', 'owner': RUN, 'expires_at': '2026-08-02T01:00:00Z'}),
         L('LAUNCH_INTENT', at='2026-08-02T00:02:00Z', launch_intent_at='2026-08-02T00:02:00Z',
           report_path=GOOD_PROOF['report_path']),
         L('PROCESS_OBSERVED', at='2026-08-02T00:03:00Z',
           process_observed={'pid': 1, 'observed_at': '2026-08-02T00:03:00Z'}),
         L('RUNNING', at='2026-08-02T00:04:00Z')]

refuses('a transition that is not in the schema enum', S.validate_transition(None, L('MOVING')), 'S1')
refuses('a run_id that is not RUN-YYYYMMDD-NNN',
        S.validate_transition(None, dict(QUEUED_LINE, run_id='run-1')), 'S1')
refuses('a timestamp in a second format',
        S.validate_transition(None, dict(QUEUED_LINE, at='2026-08-02 00:00:00')), 'S1')
refuses('LAUNCH_INTENT before anything was leased',
        S.validate_transition(J(QUEUED_LINE), L('LAUNCH_INTENT')), 'S2')
refuses('a transition appended AFTER the run was abandoned',
        S.validate_transition(J(QUEUED_LINE, L('ABANDONED', failure_class='LEASE_LOST')),
                              L('LEASED')), 'S2')
refuses('a new attempt opened after something other than FAILED',
        S.validate_transition(J(*SPINE), L('LEASED', attempt=2)), 'S3')
refuses('an attempt number that skips',
        S.validate_transition(J(QUEUED_LINE), L('LEASED', attempt=7)), 'S3')
refuses('the same (attempt, transition) written twice',
        S.validate_transition(J(QUEUED_LINE, L('LEASED')), L('LEASED')), 'S4')
refuses('a QUEUED line with no ExecutionKey',
        S.validate_transition(None, L('QUEUED', at='2026-08-02T00:00:00Z')), 'S5')
refuses('a QUEUED line whose ExecutionKey is missing a field',
        S.validate_transition(None, dict(L('QUEUED', at='2026-08-02T00:00:00Z'),
                                         execution_key=dict((k, v) for k, v in BASE_KEY.items()
                                                            if k != 'leverage'))), 'S5')
refuses('a later line that contradicts the QUEUED ExecutionKey',
        S.validate_transition(J(QUEUED_LINE),
                              dict(L('LEASED'), execution_key=dict(BASE_KEY, lane='lane2'))), 'S5')

# --- ACCEPTANCE CRITERION 2, four ways ---------------------------------------------------------
refuses('CRITERION 2  COMPLETED with no freshness proof at all',
        S.validate_transition(J(*SPINE), L('COMPLETED', at='2026-08-02T00:05:00Z')), 'S6')
refuses('CRITERION 2  COMPLETED carrying the caller-owned fresh claim',
        S.validate_transition(J(*SPINE), L('COMPLETED', at='2026-08-02T00:05:00Z',
                                           report_fresh_proof=dict(GOOD_PROOF, fresh=True))), 'S6')
refuses('CRITERION 2  COMPLETED on runner exit 1 (= NO REPORT, whatever is on disk)',
        S.validate_transition(J(*SPINE), L('COMPLETED', at='2026-08-02T00:05:00Z',
                                           report_fresh_proof=dict(GOOD_PROOF, runner_exit=1))), 'S6')
refuses('CRITERION 2  COMPLETED whose report predates the run that claims to have written it',
        S.validate_transition(J(*SPINE),
                              L('COMPLETED', at='2026-08-02T00:05:00Z',
                                report_fresh_proof=dict(GOOD_PROOF,
                                                        report_mtime='2026-08-02T00:01:00Z'))), 'S6')
check('S6   CONTROL a COMPLETED carrying a real proof is ACCEPTED',
      not S.validate_transition(J(*SPINE), L('COMPLETED', at='2026-08-02T00:05:00Z',
                                             report_fresh_proof=dict(GOOD_PROOF))),
      str(S.validate_transition(J(*SPINE), L('COMPLETED', at='2026-08-02T00:05:00Z',
                                             report_fresh_proof=dict(GOOD_PROOF)))))

_proof_root = tempfile.mkdtemp()
try:
    _report_abs = os.path.join(_proof_root, GOOD_PROOF['report_path'].replace('/', os.sep))
    os.makedirs(os.path.dirname(_report_abs))
    with io.open(_report_abs, 'w', encoding='utf-8') as _fh:
        _fh.write('authoritative report')
    _mtime_epoch = calendar.timegm((2026, 8, 2, 0, 5, 0))
    os.utime(_report_abs, (_mtime_epoch, _mtime_epoch))
    _sidecar_dir = os.path.join(_proof_root, 'factory', 'runs')
    os.makedirs(_sidecar_dir)
    with io.open(os.path.join(_sidecar_dir, RUN + '.a1.exit.json'), 'w', encoding='utf-8') as _fh:
        json.dump({'run_id': RUN, 'attempt': 1, 'exit_code': 0}, _fh)
    _source_journal = J(*SPINE)
    _completed_line = L('COMPLETED', at='2026-08-02T00:06:00Z',
                        report_fresh_proof=dict(GOOD_PROOF))
    check('S6 AUTHORITY  normal completion binds intent, current sidecar and filesystem report',
          not S.authoritative_completion_problems(_source_journal, _completed_line, _proof_root),
          str(S.authoritative_completion_problems(_source_journal, _completed_line, _proof_root)))
    _report_b = os.path.join(_proof_root, '_mt5_auto', 'reports', 'other.htm')
    with io.open(_report_b, 'w', encoding='utf-8') as _fh:
        _fh.write('other report')
    os.utime(_report_b, (_mtime_epoch, _mtime_epoch))
    _later_override_journal = J(*(SPINE + [
        L('RUNNING', at='2026-08-02T00:04:30Z',
          launch_intent_at='2026-08-02T00:03:00Z', report_path='_mt5_auto/reports/other.htm')
    ]))
    check('S6 AUTHORITY  later launch_intent_at override is refused',
          bool(S.authoritative_completion_problems(
              _later_override_journal, L('COMPLETED', at='2026-08-02T00:06:00Z',
                                         report_fresh_proof=dict(GOOD_PROOF,
                                                                 run_start='2026-08-02T00:03:00Z')),
              _proof_root)),
          'later transition supplied the apparent run_start authority')
    check('S6 AUTHORITY  later report_path override is refused',
          bool(S.authoritative_completion_problems(
              _later_override_journal, L('COMPLETED', at='2026-08-02T00:06:00Z',
                                         report_fresh_proof=dict(GOOD_PROOF,
                                                                 report_path='_mt5_auto/reports/other.htm',
                                                                 report_mtime='2026-08-02T00:05:00Z')),
              _proof_root)),
          'later transition supplied the apparent report identity')
    check('S6 AUTHORITY  later run_start/report_path overrides consistently are refused',
          bool(S.authoritative_completion_problems(
              _later_override_journal, L('COMPLETED', at='2026-08-02T00:06:00Z',
                                         report_fresh_proof=dict(GOOD_PROOF,
                                                                 run_start='2026-08-02T00:03:00Z',
                                                                 report_path='_mt5_auto/reports/other.htm')),
              _proof_root)),
          'internally consistent forged later fields must not become S6 authority')
    check('S6 AUTHORITY  missing LAUNCH_INTENT fails closed',
          bool(S.authoritative_completion_problems(
              J(QUEUED_LINE, L('LEASED')),
              L('COMPLETED', at='2026-08-02T00:06:00Z', report_fresh_proof=dict(GOOD_PROOF)),
              _proof_root)),
          'no current-attempt LAUNCH_INTENT was present')
    _ambiguous_journal = J(*(SPINE + [
        L('LAUNCH_INTENT', at='2026-08-02T00:04:30Z',
          launch_intent_at='2026-08-02T00:02:00Z', report_path=GOOD_PROOF['report_path'])
    ]))
    check('S6 AUTHORITY  multiple LAUNCH_INTENT records fail closed',
          bool(S.authoritative_completion_problems(
              _ambiguous_journal, _completed_line, _proof_root)),
          'multiple launch-intent records were silently collapsed')
    for field, value in (('runner_exit', 3), ('report_path', '_mt5_auto/reports/other.htm'),
                         ('report_mtime', '2026-08-02T00:06:00Z'),
                         ('run_start', '2026-08-02T00:01:00Z')):
        forged = L('COMPLETED', at='2026-08-02T00:06:00Z',
                   report_fresh_proof=dict(GOOD_PROOF, **{field: value}))
        check('S6 AUTHORITY  forged %-12s is refused against authoritative sources' % field,
              bool(S.authoritative_completion_problems(_source_journal, forged, _proof_root)),
              str(S.authoritative_completion_problems(_source_journal, forged, _proof_root)))
    with io.open(os.path.join(_sidecar_dir, RUN + '.a1.exit.json'), 'w', encoding='utf-8') as _fh:
        json.dump({'run_id': RUN, 'attempt': 2, 'exit_code': 0}, _fh)
    check('S6 AUTHORITY  an exit sidecar from another attempt is refused',
          bool(S.authoritative_completion_problems(_source_journal, _completed_line, _proof_root)),
          str(S.authoritative_completion_problems(_source_journal, _completed_line, _proof_root)))
    with io.open(os.path.join(_sidecar_dir, RUN + '.a1.exit.json'), 'w', encoding='utf-8') as _fh:
        json.dump({'run_id': RUN, 'attempt': 1, 'exit_code': 0}, _fh)
    _prestart_epoch = calendar.timegm((2026, 8, 2, 0, 1, 0))
    os.utime(_report_abs, (_prestart_epoch, _prestart_epoch))
    _prestart_line = L('COMPLETED', at='2026-08-02T00:06:00Z',
                       report_fresh_proof=dict(GOOD_PROOF, report_mtime='2026-08-02T00:01:00Z'))
    check('S6 AUTHORITY  a real pre-start report is refused',
          bool(S.authoritative_completion_problems(_source_journal, _prestart_line, _proof_root)),
          str(S.authoritative_completion_problems(_source_journal, _prestart_line, _proof_root)))
    os.remove(_report_abs)
    check('S6 AUTHORITY  a missing report is refused',
          bool(S.authoritative_completion_problems(_source_journal, _completed_line, _proof_root)),
          str(S.authoritative_completion_problems(_source_journal, _completed_line, _proof_root)))
finally:
    import shutil
    shutil.rmtree(_proof_root, ignore_errors=True)

# --- DISPATCH BOUNDARY: the persisted key owns identity, not the mutable KeyFile ----------------
NAMED.add('DISPATCH_KEY')
_dispatch_key = dict(BASE_KEY, terminal_build=6091)
_dispatch_journal = J(dict(L('QUEUED', at='2026-08-02T00:00:00Z'),
                           execution_key=_dispatch_key))
check('DISPATCH_KEY R1 KeyFile build mismatch is refused before launch',
      bool(S.dispatch_key_problems(_dispatch_journal, dict(_dispatch_key, terminal_build=6090),
                                   resolved_terminal_build=6090)),
      'external terminal_build matched the executable but not the persisted key')
check('DISPATCH_KEY R2 non-build KeyFile mutation is refused before launch',
      bool(S.dispatch_key_problems(_dispatch_journal, dict(_dispatch_key, symbol='EURUSD'),
                                   resolved_terminal_build=6091)),
      'only terminal_build equality would have missed the mutation')
check('DISPATCH_KEY R3 exact KeyFile and persisted key with matching build are accepted',
      not S.dispatch_key_problems(_dispatch_journal, dict(_dispatch_key),
                                  resolved_terminal_build=6091),
      'the normal dispatch gate refused an exact match')
check('DISPATCH_KEY R4 actual executable build mismatch is refused against persisted key',
      bool(S.dispatch_key_problems(_dispatch_journal, dict(_dispatch_key),
                                   resolved_terminal_build=6090)),
      'the executable fact disagreed with the persisted terminal_build')

refuses('FAILED with no failure_class',
        S.validate_transition(J(*SPINE), L('FAILED', at='2026-08-02T00:05:00Z')), 'S7')
refuses('FAILED whose class is NONE (which is not a failure)',
        S.validate_transition(J(*SPINE), L('FAILED', at='2026-08-02T00:05:00Z',
                                           failure_class='NONE')), 'S7')
COMPLETED_J = J(*(SPINE + [L('COMPLETED', at='2026-08-02T00:05:00Z',
                             report_fresh_proof=dict(GOOD_PROOF))]))
refuses('EVIDENCE_REGISTERED with no event_id to reconcile against',
        S.validate_transition(COMPLETED_J, L('EVIDENCE_REGISTERED', at='2026-08-02T00:06:00Z')),
        'S8')
refuses('a line belonging to a different cell',
        S.validate_transition(J(QUEUED_LINE), dict(L('LEASED'), cell_id='other/cell')), 'S9')

sys.stdout.write('\nPART 3 - the acceptance gates outside the validator\n')

# --- CRITERION 3: idempotency ------------------------------------------------------------------
def _journal_for(key, states, run_id):
    lines = [dict(L('QUEUED', at='2026-08-02T00:00:00Z'), run_id=run_id, execution_key=dict(key))]
    at = 1
    for st in states:
        rec = {}
        if st == 'COMPLETED':
            rec = {'report_fresh_proof': dict(GOOD_PROOF)}
        if st == 'FAILED':
            rec = {'failure_class': 'TESTER_ERROR'}
        if st == 'EVIDENCE_REGISTERED':
            rec = {'event_id': 'evt-%s' % run_id}
        lines.append(dict(L(st, at='2026-08-02T00:%02d:00Z' % at, **rec), run_id=run_id))
        at += 1
    return S.fold(lines)


prior_done = {'RUN-20260801-001': _journal_for(BASE_KEY, ['COMPLETED', 'EVIDENCE_REGISTERED'],
                                               'RUN-20260801-001')}
dec = S.queue_decision(prior_done, BASE_KEY, CELL, '2026-08-02T00:00:00Z', RUN)
NAMED.add('IDENTICAL_RERUN')
check('IDENTICAL_RERUN  CRITERION 3  an identical (config, lane, fingerprint) is REFUSED',
      dec['action'] == 'REFUSE' and dec['code'] == 'IDENTICAL_RERUN', str(dec))
check('IDENTICAL_RERUN  CRITERION 3  and the CACHED EVIDENCE is returned in its place',
      dec.get('cached_run') == 'RUN-20260801-001' and dec.get('cached_event_id'), str(dec))

# --- /scrutinize round 1 over S10 (2026-08-02): CRITERION 3 HAD FAILED OPEN ON THE REAL STORE ---
# Reproduced against the committed manifests before anything was changed: after the ORDER-1100
# step-0 decision took `ini_hash` out of the key, all three stored keys became unreadable,
# `find_cached` answered that with `continue`, and re-queueing the exact configuration of
# RUN-20260802-002 -- which holds EVIDENCE, and whose refusal the S9 ledger records returning
# `evd_sha256_90c1f032...` -- returned QUEUED. Four cases, because the obvious fix (count them and
# say so) passes three of them while leaving the lane just as spendable.
LEGACY_KEY = dict((k, v) for k, v in BASE_KEY.items()
                  if k not in ('account_unit', 'terminal_build'))
LEGACY_KEY['ini_hash'] = 'b' * 64                       # the exact historical persisted shape
prior_legacy = {'RUN-20260801-003': _journal_for(LEGACY_KEY,
                                                 ['COMPLETED', 'EVIDENCE_REGISTERED'],
                                                 'RUN-20260801-003')}

# (1) Historical rows remain readable, but their unit/build are unknown. They must never block a
#     new USD/CENT-aware key or hand historical evidence to it.
dec_l = S.queue_decision(prior_legacy, BASE_KEY, CELL, '2026-08-02T00:00:00Z', RUN)
check('LEGACY KEY  a prior unit/build-unknown row remains readable but cannot satisfy a new key',
      dec_l['action'] == 'QUEUED' and not dec_l.get('cached_run'),
      str(dec_l))
check('LEGACY KEY  the established ini_hash migration remains observable while reading history -- a '
      'migration that fires invisibly is one nobody can audit',
      dec_l.get('migrated_prior') == ['RUN-20260801-003:ini_hash'], str(dec_l))

# (2) THE MIGRATION IS CLOSED. An unknown field OUTSIDE the declared tuple must not be laundered
#     as a migration -- otherwise every future key-shape drift quietly becomes one.
prior_alien = {'RUN-20260801-004': _journal_for(dict(BASE_KEY, some_new_field='x'),
                                                ['COMPLETED', 'EVIDENCE_REGISTERED'],
                                                'RUN-20260801-004')}
dec_a = S.queue_decision(prior_alien, BASE_KEY, CELL, '2026-08-02T00:00:00Z', RUN)
NAMED.add('UNCOMPARABLE_PRIOR')
check('UNCOMPARABLE_PRIOR  CRITERION 3  an unreadable prior key REFUSES the queue -- it does not '
      'annotate a QUEUED, because the dispatcher branches on action and not on prose',
      dec_a['action'] == 'REFUSE' and dec_a.get('code') == 'UNCOMPARABLE_PRIOR'
      and dec_a.get('uncomparable_prior') == ['RUN-20260801-004'], str(dec_a))

# (3) ...and a key MISSING a required field is uncomparable too, not silently narrowed.
prior_short = {'RUN-20260801-005': _journal_for(dict((k, v) for k, v in BASE_KEY.items()
                                                     if k != 'data_fingerprint'),
                                                ['COMPLETED', 'EVIDENCE_REGISTERED'],
                                                'RUN-20260801-005')}
dec_s = S.queue_decision(prior_short, BASE_KEY, CELL, '2026-08-02T00:00:00Z', RUN)
check('UNCOMPARABLE_PRIOR  CRITERION 3  a stored key missing a required field is uncomparable, '
      'not narrowed to the fields it happens to have',
      dec_s['action'] == 'REFUSE' and dec_s.get('code') == 'UNCOMPARABLE_PRIOR', str(dec_s))

# (4) CONTROL. A different new configuration also queues with readable history present.
dec_c = S.queue_decision(prior_legacy, dict(BASE_KEY, symbol='EURUSD'), CELL,
                         '2026-08-02T00:00:00Z', RUN)
check('CRITERION 3  CONTROL a different configuration still QUEUES with a legacy-shaped run in '
      'the store -- the migration reads it, it does not poison the store',
      dec_c['action'] == 'QUEUED', str(dec_c))

# (5) the closed tuple is the SCHEMA's business too: `ini_hash` must be gone from ExecutionKey and
#     present on RunAttempt, or the migration is dropping a field the contract still requires.
_sch = S.assert_vocabulary_matches_schema()
check('CRITERION 3  the field the migration drops is genuinely off the contract '
      '(vocabulary re-read from schemas.json)', not _sch, _sch)

prior_failed = {'RUN-20260801-002': _journal_for(BASE_KEY, ['FAILED'], 'RUN-20260801-002')}
dec2 = S.queue_decision(prior_failed, BASE_KEY, CELL, '2026-08-02T00:00:00Z', RUN)
check('CRITERION 3  a re-run after a TESTER_ERROR is ALLOWED (decision 18\'s one exception)',
      dec2['action'] == 'QUEUED', str(dec2))

# Every new ExecutionKey dimension is made a test rather than a comment: omission would let the cache
# serve the wrong evidence.
for field, other in (('deposit', 100000), ('leverage', 200), ('account_unit', 'CENT'),
                     ('terminal_build', 6091),
                     ('data_fingerprint', 'lane1|XAUUSD|H1|2020.01.01|2020.06.01|1'),
                     ('lane', 'lane2'), ('effective_config_hash', 'f' * 64)):
    d = S.queue_decision(prior_done, dict(BASE_KEY, **{field: other}), CELL,
                         '2026-08-02T00:00:00Z', RUN)
    check('CRITERION 3  a run differing only in %-22s is NOT served the cached evidence' % field,
          d['action'] == 'QUEUED', str(d))
prior_cent = {'RUN-20260801-008': _journal_for(dict(BASE_KEY, account_unit='CENT'),
                                                ['COMPLETED', 'EVIDENCE_REGISTERED'],
                                                'RUN-20260801-008')}
d = S.queue_decision(prior_cent, BASE_KEY, CELL, '2026-08-02T00:00:00Z', RUN)
check('ACCOUNT UNIT  USD lookup cannot reuse otherwise-identical CENT evidence',
      d['action'] == 'QUEUED', str(d))

# The two dispositions that are NOT "this already succeeded" and still must block, because
# decision 18's exception is a whitelist of two failure classes and not "anything that is not a
# success". Both were wrong in the first version, which refused only EVIDENCE and COMPLETED.
prior_inflight = {'RUN-20260801-006': _journal_for(BASE_KEY, ['LEASED', 'LAUNCH_INTENT'],
                                                   'RUN-20260801-006')}
d = S.queue_decision(prior_inflight, BASE_KEY, CELL, '2026-08-02T00:00:00Z', RUN)
check('CRITERION 3  a duplicate of a run that is ON A LANE RIGHT NOW is REFUSED (it would spend '
      'the lane twice for one answer)',
      d['action'] == 'REFUSE' and d['cached_state'] == 'IN_FLIGHT', str(d))
prior_dead = {'RUN-20260801-007': S.fold(
    [dict(L('QUEUED', at='2026-08-02T00:00:00Z'), run_id='RUN-20260801-007',
          execution_key=dict(BASE_KEY)),
     dict(L('LEASED', at='2026-08-02T00:01:00Z'), run_id='RUN-20260801-007'),
     dict(L('FAILED', at='2026-08-02T00:02:00Z', failure_class='CONFIG_REJECTED'),
          run_id='RUN-20260801-007')])}
d = S.queue_decision(prior_dead, BASE_KEY, CELL, '2026-08-02T00:00:00Z', RUN)
check('CRITERION 3  a duplicate of a run that died CONFIG_REJECTED is REFUSED -- decision 18 '
      'permits a re-run after an execution or tester error, and a rejected configuration is '
      'neither', d['action'] == 'REFUSE' and d['cached_state'] == 'DEAD', str(d))

# 🔴 THE MAPPING THE FIRST REAL WIRING RUN FORCED. Every class in the execution-error category
# must re-queue, and the one that is a fact about the configuration must not. Enumerated rather
# than spot-checked, because the first version got exactly one of these five wrong and the cost
# was a configuration that could never be run again after a machine crash.
for fc, want_queue in (('TESTER_ERROR', True), ('TERMINAL_ERROR', True), ('TIMEOUT', True),
                       ('KILLED', True), ('LEASE_LOST', True), ('CONFIG_REJECTED', False)):
    term = 'ABANDONED' if fc == 'LEASE_LOST' else 'FAILED'
    prior = {'RUN-20260801-00X': S.fold(
        [dict(L('QUEUED', at='2026-08-02T00:00:00Z'), run_id='RUN-20260801-00X',
              execution_key=dict(BASE_KEY)),
         dict(L('LEASED', at='2026-08-02T00:01:00Z'), run_id='RUN-20260801-00X'),
         dict(L(term, at='2026-08-02T00:02:00Z', failure_class=fc), run_id='RUN-20260801-00X')])}
    d = S.queue_decision(prior, BASE_KEY, CELL, '2026-08-02T00:00:00Z', RUN)
    check('CRITERION 3  after %-15s a fresh run is %s'
          % (fc, 'ALLOWED (an execution/tester error, holding no evidence)' if want_queue
             else 'REFUSED'),
          (d['action'] == 'QUEUED') == want_queue, str(d))

NAMED.add('MALFORMED_KEY')
d = S.queue_decision({}, dict((k, v) for k, v in BASE_KEY.items() if k != 'lane'), CELL,
                     '2026-08-02T00:00:00Z', RUN)
check('MALFORMED_KEY    a key that is not the contract is refused rather than digested',
      d['action'] == 'REFUSE' and d['code'] == 'MALFORMED_KEY', str(d))
for field, value in (('currency', 'EUR'), ('account_unit', 'MILLI'), ('terminal_build', '6090')):
    d = S.queue_decision({}, dict(BASE_KEY, **{field: value}), CELL, '2026-08-02T00:00:00Z', RUN)
    check('MALFORMED_KEY    invalid %-14s is refused before it can queue or launch' % field,
          d['action'] == 'REFUSE' and d['code'] == 'MALFORMED_KEY', str(d))
for field in ('account_unit', 'terminal_build'):
    d = S.queue_decision({}, dict((k, v) for k, v in BASE_KEY.items() if k != field), CELL,
                         '2026-08-02T00:00:00Z', RUN)
    check('MALFORMED_KEY    missing new %-10s is refused' % field,
          d['action'] == 'REFUSE' and d['code'] == 'MALFORMED_KEY', str(d))

# --- CRITERION 4: cross-lane, and the lane lease ------------------------------------------------
NAMED.add('CROSS_LANE')
mixed = {'A': _journal_for(BASE_KEY, ['COMPLETED'], 'RUN-20260801-003'),
         'B': _journal_for(dict(BASE_KEY, lane='lane2'), ['COMPLETED'], 'RUN-20260801-004')}
ref = S.refuse_cross_lane(mixed)
check('CROSS_LANE       CRITERION 4  a comparison whose members hold different lanes is REFUSED',
      ref is not None and ref['code'] == 'CROSS_LANE', str(ref))
same = {'A': _journal_for(BASE_KEY, ['COMPLETED'], 'RUN-20260801-003'),
        'B': _journal_for(BASE_KEY, ['COMPLETED'], 'RUN-20260801-005')}
check('CROSS_LANE       CONTROL two runs on ONE lane compare fine',
      S.refuse_cross_lane(same) is None)

NAMED.add('LANE_BUSY')
qj = S.fold([QUEUED_LINE])
busy = {'now': '2026-08-02T00:00:00Z',
        'lease': {'lease_id': 'L9', 'owner': 'RUN-20260801-009',
                  'expires_at': '2026-08-02T02:00:00Z'},
        'child_running': False, 'tester_running': False, 'exit_record': None,
        'report_fresh': None, 'report_path': 'r.htm', 'report_mtime': None, 'evidence': None}
p = S.plan(qj, busy)
check('LANE_BUSY        CRITERION 4  LEASED is REFUSED while another run holds the lane lease',
      p['action'] == 'REFUSE' and p['code'] == 'LANE_BUSY', str(p))
p = S.plan(qj, dict(busy, lease=dict(busy['lease'], expires_at='2026-08-01T00:00:00Z')))
check('LANE_BUSY        CONTROL an EXPIRED lease frees the lane (a dead machine must not hold it '
      'forever)', p['action'] == 'ACQUIRE_LEASE', str(p))
p = S.plan(qj, dict(busy, lease=dict(busy['lease'], owner=RUN)))
check('LANE_BUSY        CONTROL our own live lease is ADOPTED, not acquired twice',
      p['action'] == 'ADOPT_LEASE', str(p))

# A lease that goes away mid-run must ABANDON, not carry on and claim the lane's numbers.
leased_j = S.fold([QUEUED_LINE, L('LEASED', at='2026-08-02T00:01:00Z',
                                  lease={'lease_id': 'L1', 'owner': RUN,
                                         'expires_at': '2026-08-02T01:00:00Z'})])
p = S.plan(leased_j, dict(busy, lease={'lease_id': 'L9', 'owner': 'RUN-20260801-009',
                                       'expires_at': '2026-08-02T02:00:00Z'}))
check('ABANDON          a run whose lane lease was taken ABANDONS instead of launching into it',
      p['action'] == 'ABANDON' and p['failure_class'] == 'LEASE_LOST', str(p))

# --- decision 18's other half, and the attempt cap ---------------------------------------------
NAMED.add('RUN_DEAD')
dead = S.fold([QUEUED_LINE, L('LEASED'), L('LAUNCH_INTENT', at='2026-08-02T00:02:00Z'),
               L('FAILED', at='2026-08-02T00:03:00Z', failure_class='CONFIG_REJECTED')])
p = S.plan(dead, busy)
check('RUN_DEAD         a failure class decision 18 does not permit a re-run after is REFUSED',
      p['action'] == 'REFUSE' and p['code'] == 'RUN_DEAD', str(p))

NAMED.add('ATTEMPTS_EXHAUSTED')
lines = [QUEUED_LINE]
for k in (1, 2, 3):
    lines.append(L('LEASED', attempt=k, at='2026-08-02T0%d:01:00Z' % k))
    lines.append(L('FAILED', attempt=k, at='2026-08-02T0%d:02:00Z' % k,
                   failure_class='TESTER_ERROR'))
p = S.plan(S.fold(lines), dict(busy, lease=None))
check('ATTEMPTS_EXHAUSTED  a fourth attempt is REFUSED rather than hiding a systematic failure '
      'behind repetition', p['action'] == 'REFUSE' and p['code'] == 'ATTEMPTS_EXHAUSTED', str(p))

# --- the exit-code classification, enumerated ---------------------------------------------------
CASES = [
    ({'exit_code': 0}, True, ('COMPLETED', 'NONE')),
    ({'exit_code': 0}, False, ('FAILED', 'TESTER_ERROR')),
    ({'exit_code': 0}, None, ('FAILED', 'TESTER_ERROR')),
    ({'exit_code': 1}, None, ('FAILED', 'TESTER_ERROR')),
    ({'exit_code': 1, 'stdout_tail': 'TIMEOUT after 1800s - killing'}, None, ('FAILED', 'TIMEOUT')),
    ({'exit_code': 2}, None, ('FAILED', 'TERMINAL_ERROR')),
    ({'exit_code': 3}, True, ('FAILED', 'CONFIG_REJECTED')),
    ({'exit_code': 99}, True, ('FAILED', 'TERMINAL_ERROR')),
]
bad = [(c, f, S.classify_outcome(c, f)) for c, f, want in CASES if S.classify_outcome(c, f) != want]
check('classify_outcome covers every runner exit the runner documents, including exit 3 = the '
      'report is real but its numbers are not comparable', not bad, str(bad))
check('classify_outcome  exit 2 is TERMINAL_ERROR, never a tester failure -- it is the runner '
      'refusing to start into a busy lane, which is the SECOND cage against a double launch',
      S.classify_outcome({'exit_code': 2}, None)[1] == 'TERMINAL_ERROR')

# --- the spawn-marker window, stated explicitly because the matrix cannot reach it -------------
# The matrix's kill points are (action, phase), so it cannot stop the driver BETWEEN writing the
# marker and the spawn succeeding. That window is where the fix chooses its direction, so it is
# asserted here rather than left as a sentence in a comment.
intent_j = S.fold([QUEUED_LINE, L('LEASED', at='2026-08-02T00:01:00Z'),
                   L('LAUNCH_INTENT', at='2026-08-02T00:02:00Z',
                     launch_intent_at='2026-08-02T00:02:00Z')])
quiet = {'now': '2026-08-02T00:10:00Z',
         'lease': {'lease_id': 'L1', 'owner': RUN, 'expires_at': '2026-08-02T01:00:00Z'},
         'child_running': False, 'tester_running': False, 'exit_record': None,
         'report_fresh': None, 'report_path': 'r.htm', 'report_mtime': None, 'evidence': None}
p = S.plan(intent_j, dict(quiet, spawn_marker=False))
check('SPAWN MARKER  absent + nothing running => LAUNCH (this attempt was never started)',
      p['action'] == 'LAUNCH', str(p))
p = S.plan(intent_j, dict(quiet, spawn_marker=True))
check('SPAWN MARKER  present + nothing running + no exit record => RECONCILE_ORPHAN, not a '
      'relaunch. THIS IS THE DEFECT THE ENUMERATED MATRIX FOUND: without the marker both states '
      'answered LAUNCH, and a dead attempt was relaunched in place',
      p['action'] == 'RECONCILE_ORPHAN' and p['failure_class'] == 'KILLED', str(p))
p = S.plan(intent_j, dict(quiet, spawn_marker=True, tester_running=True))
check('SPAWN MARKER  present + a live tester => ADOPT_PROCESS (the reconcile beats the marker)',
      p['action'] == 'ADOPT_PROCESS', str(p))

# --- /scrutinize round 2: four holes, each REPRODUCED before it was fixed -----------------------
inflight = S.fold([QUEUED_LINE, L('LEASED', at='2026-08-02T00:01:00Z'),
                   L('LAUNCH_INTENT', at='2026-08-02T00:02:00Z',
                     launch_intent_at='2026-08-02T00:02:00Z'),
                   L('PROCESS_OBSERVED', at='2026-08-02T00:03:00Z'),
                   L('RUNNING', at='2026-08-02T00:04:00Z')])
flying = {'now': '2026-08-02T09:00:00Z', 'child_running': True, 'tester_running': True,
          'spawn_marker': True, 'exit_record': None, 'report_fresh': None,
          'report_path': 'r.htm', 'report_mtime': None, 'evidence': None}
NAMED.add('RENEW_LEASE')
p = S.plan(inflight, dict(flying, lease={'lease_id': 'L1', 'owner': RUN,
                                         'expires_at': '2026-08-02T04:00:00Z'}))
check('LEASE IN FLIGHT  an EXPIRED own lease is RENEWED, not ignored. Probed before the fix: the '
      'planner said WAIT with the lease five hours dead -- the lane was enforced at acquisition '
      'and decorative for the whole run, which is the only part that matters',
      p['action'] == 'RENEW_LEASE', str(p))
p = S.plan(inflight, dict(flying, lease={'lease_id': 'L9', 'owner': 'RUN-20260801-099',
                                         'expires_at': '2026-08-02T20:00:00Z'}))
check('LEASE IN FLIGHT  a lane TAKEN by another run mid-flight ABANDONS. Probed before the fix: '
      'the planner said WAIT',
      p['action'] == 'ABANDON' and p['failure_class'] == 'LEASE_LOST', str(p))
p = S.plan(inflight, dict(flying, lease={'lease_id': 'L1', 'owner': RUN,
                                         'expires_at': '2026-08-02T23:00:00Z'}))
check('LEASE IN FLIGHT  CONTROL a healthy lease is left alone -- a renewal every poll would be a '
      'write loop wearing the shape of a heartbeat', p['action'] == 'WAIT', str(p))
p = S.plan(inflight, dict(flying, lease={'lease_id': 'L9', 'owner': 'RUN-20260801-099',
                                         'expires_at': '2026-08-02T20:00:00Z'},
                          exit_record={'exit_code': 0}, report_fresh=True,
                          report_mtime='2026-08-02T08:00:00Z'))
check('LEASE IN FLIGHT  a FINISHED attempt is still recorded even though the lease was lost -- '
      'mt5_run refuses to start while an instance of this install is alive, so the other run '
      'either waited or aborted; it cannot have run concurrently, and the report is ours',
      p['action'] == 'RECORD_COMPLETED', str(p))

check('CROSS_LANE  two runs that record NO lane are REFUSED, not called comparable. Probed before '
      'the fix: they collapsed into one `None` bucket and returned COMPARABLE -- the answer '
      'needing the most evidence produced by the branch holding the least',
      (S.refuse_cross_lane({'A': _journal_for({}, [], 'RUN-20260801-021'),
                            'B': _journal_for({}, [], 'RUN-20260801-022')}) or {}).get('code')
      == 'CROSS_LANE')

check('EXECUTION KEY  a deposit of 10000 and 10000.0 give ONE digest. Probed before the fix: two '
      'digests for one configuration, which is the exact failure design §4.5 warns about and '
      'which PowerShell produces by itself depending on what the caller\'s variable held',
      S.execution_key_digest(BASE_KEY)
      == S.execution_key_digest(dict(BASE_KEY, deposit=10000.0)))
check('EXECUTION KEY  CONTROL a genuinely different deposit still gives a different digest',
      S.execution_key_digest(BASE_KEY)
      != S.execution_key_digest(dict(BASE_KEY, deposit=10001)))

# The `queue` CLI path, driven end to end through a temp root. Probed before the fix: queueing one
# run id TWICE appended a second QUEUED line and both calls exited 0, because the one command that
# CREATES a manifest was the one command that validated against `None` instead of against the
# manifest -- so S2 (ordering) and S4 (duplicates) were both sitting there unable to see it.
import shutil                                                              # noqa: E402
import tempfile                                                            # noqa: E402
_root = tempfile.mkdtemp()
try:
    os.makedirs(os.path.join(_root, 'factory', 'runs'))
    codes = [S.main(['queue', '--run=RUN-20260802-777', '--cell=' + CELL,
                     '--now=2026-08-02T00:0%d:00Z' % i,
                     '--key=' + __import__('json').dumps(BASE_KEY), '--root=' + _root])
             for i in (1, 2)]
    _lines = S.read_manifest(S.manifest_path('RUN-20260802-777', _root))
    check('QUEUE CLI  queueing one run id twice is REFUSED by the run\'s own journal, and the '
          'manifest keeps exactly one QUEUED line',
          codes == [0, 1] and len(_lines) == 1, 'exits=%s lines=%d' % (codes, len(_lines)))
finally:
    shutil.rmtree(_root, ignore_errors=True)

# RENEW_LEASE must actually be REACHED by the matrix, not merely handled. An action no scenario
# reaches is an action the 408 cells say nothing about, however green they print.
_w = World(SCEN_RENEW)
run_to_end(_w)
check('LEASE IN FLIGHT  the matrix has a scenario that genuinely renews (%d renewal(s) on a lease '
      'shorter than the margin), so RENEW_LEASE is exercised rather than merely dispatched'
      % _w.renewals, _w.renewals > 0)

sys.stdout.write('\nPART 4 - the dispatcher and the vocabulary\n')

disp_path = os.path.join(ROOT, DISPATCHER_REL.replace('/', os.sep))
if not os.path.exists(disp_path):
    check('the PowerShell dispatcher exists at %s' % DISPATCHER_REL, False, 'not found')
else:
    with io.open(disp_path, 'r', encoding='utf-8-sig') as fh:
        disp = fh.read()
    # The switch's own labels. Read from the source rather than from a list here, because a list
    # here would be a second hand-maintained cache of the same fact -- the defect L0 exists for.
    handled = set(re.findall(r"^\s*'([A-Z_]+)'\s*\{", disp, re.M))
    check('PART 3 the dispatcher handles EXACTLY the closed action set plan() can emit',
          handled == set(S.ACTIONS),
          'missing %s / unknown %s' % (sorted(set(S.ACTIONS) - handled), sorted(handled - set(S.ACTIONS))))
    # RED: prove that assertion can fail, by removing one label from the parsed set.
    check('RED the dispatcher-coverage check fails when one action is unhandled',
          (handled - {'ADOPT_PROCESS'}) != set(S.ACTIONS))
    check('the dispatcher gates its report read through the shared freshness guard',
          'Test-ReportIsFresh' in disp)
    check('TERMINAL BUILD  FileVersion 5.0.0.6090 normalizes to numeric build 6090',
          re.match(r'^\d+\.\d+\.\d+\.(\d+)$', '5.0.0.6090').group(1) == '6090'
          and 'Get-TerminalBuildFromFileVersion' in disp
          and 'FileVersionInfo]::GetVersionInfo' in disp)
    check('TERMINAL BUILD  missing or malformed FileVersion fails closed before dispatch',
          "if ($FileVersion -notmatch '^\\d+\\.\\d+\\.\\d+\\.(\\d+)$')" in disp)
    check('DISPATCH KEY  dispatcher validates KeyFile against persisted journal identity',
          'dispatch-key' in disp and 'dispatch key is not authoritative' in disp
          and '$key = $dispatch.execution_key' in disp)
    check('TERMINAL BUILD  dispatcher checks the resolved executable against persisted identity',
          'terminal-build=$resolvedTerminalBuild' in disp
          and '$dispatch.execution_key' in disp)
    check('CURRENCY  dispatcher and mt5 runner use the named frozen USD contract',
          "$FrozenTesterCurrency = 'USD'" in disp
          and 'Currency=$FrozenTesterCurrency' in io.open(os.path.join(ROOT, 'scripts', 'mt5_run.ps1'),
                                                           encoding='utf-8-sig').read())
    check('S6 AUTHORITY  completion proof is rebuilt from current intent, sidecar and report before append',
          'Get-AuthoritativeCompletionProof' in disp
          and 'planner completion proof $name disagrees with authoritative observation' in disp
          and 'run_id = $Run; attempt = $Attempt; exit_code = $code' in disp)
    # 🔴 /scrutinize round 1. Two dispatcher-only defects the pure cage CANNOT see, because it
    # models the design rather than the PowerShell: the observation layer is not driven by
    # scheduler.py, so a permissive default inside it is invisible to all 256 recoveries.
    #
    #   (a) `RunStart` fell back to the epoch when the spawn marker was missing, which makes
    #       Test-ReportIsFresh's mtime half accept ANY report on disk -- the guard's own defeat,
    #       reintroduced by its caller, on the crash path.
    #   (b) The spawn marker was written AFTER Start-Process, under a comment stating it was
    #       written first. The crash window between them left no marker, so the resume read
    #       "never spawned" and launched a second time.
    #
    # Both are greps, and both are stated as what the code must NOT contain plus what it MUST.
    code_only_early = re.sub(r'#.*$', '', re.sub(r'(?s)<#.*?#>', '', disp), flags=re.M)
    check('the freshness RunStart has no epoch/default fallback -- an undated report is refused, '
          'not accepted', not re.search(r"1970-01-01|\[datetime\]::MinValue", code_only_early),
          'a default run-start makes the mtime half of the freshness gate unfalsifiable')
    check('the run start is read from the MANIFEST (launch_intent_at), which is the only '
          'append-only record of when the attempt began',
          'launch_intent_at' in code_only_early and 'intentAt' in code_only_early)
    # 🔴 /scrutinize round 3. The evidence id written into the manifest was hashed from $htm while
    # the artifact registered was $rel (-EvidencePath). Two different files => the manifest names
    # an event that does not exist, and the reconcile (which also hashes $htm) looks for that same
    # wrong id and registers a SECOND time. Both halves are checked: the two must be compared, and
    # the recorded id must come from the utility's own record rather than a recomputation.
    check('the registered artifact is proven byte-identical to the report this run produced, so '
          'the evidence id cannot name a different file',
          re.search(r'\$relSha\s+-ne\s+\$htmSha', code_only_early) is not None)
    check('the recorded event id is read from the utility\'s returned record, not recomputed',
          'details.evidence_id' in code_only_early)
    # /scrutinize round 4, two seams the pure cage cannot reach for the same reason as round 1's:
    # they are properties of the PowerShell entry point, not of the state machine.
    check('the report name defaults to the run id, so two runs on one lane cannot be handed the '
          'same name and delete each other\'s report (mt5_run.ps1 clears <ReportName>* on launch, '
          'and the ExecutionKey does not contain the report name)',
          re.search(r"ReportName\s*=\s*\(\$Run\s+-replace", code_only_early) is not None)
    check('a duplicate-line refusal (S4) is reported as ANOTHER DRIVER, not as a dispatcher bug -- '
          'a second driver of the same run is what S4 exists to catch, and calling it "[BUG]" '
          'sends the reader hunting for a code fault instead of for the other process',
          '"S4 ' in code_only_early)
    spawn_write = code_only_early.find('Spawn-Marker $a')
    spawn_launch = code_only_early.find('Start-Process')
    check('the spawn marker is written BEFORE Start-Process, so its ABSENCE proves no spawn '
          'happened (the comment said so; the code did the opposite)',
          spawn_write != -1 and spawn_launch != -1 and spawn_write < spawn_launch,
          'first Spawn-Marker write at %d, Start-Process at %d' % (spawn_write, spawn_launch))
    # design section 10, verbatim: "no process kill, no -Force, no tester-safety change". The
    # first version of this check grepped for `-Force` anywhere and fired on
    # `New-Item -ItemType Directory -Force`, which is neither a kill nor a safety bypass -- a
    # finding that is noise is a finding people route around (Decision log 2026-07-30). The rule
    # is now three specific ones, and the dispatcher was rewritten to hold none of them rather
    # than to be exempted from one.
    # 🔴 COMMENTS ARE STRIPPED FIRST, and the ORDER matters -- both halves are corrections this
    # check earned on its own first run. It fired on a file that contains none of the three,
    # because the file EXPLAINS that it contains none of the three: "no Stop-Process", "there is
    # no -Force anywhere in this script". A guard that reads prose as code is the same defect
    # run_report_freshness_tests PART 5 documents, where the runners self-matched on the usage
    # examples in their own headers. And the block comment must go BEFORE the line comments: the
    # `^#` pass would otherwise delete the `#>` terminator, after which `<#.*?#>` matches nothing
    # and the whole header survives as "code".
    # STATED LIMIT: a `#` inside a string literal would be treated as a comment. None exists in
    # this dispatcher; the only thing that finds one is counting this pass's findings against a
    # hand count, which is how the false positive above was found in the first place.
    code_only = re.sub(r'(?s)<#.*?#>', '', disp)
    code_only = re.sub(r'#.*$', '', code_only, flags=re.M)
    prohibited = []
    if re.search(r'\bStop-Process\b|\.Kill\(\)|\btaskkill\b', code_only):
        prohibited.append('a process kill')
    if re.search(r'mt5_(run|optimize)\.ps1[^\n]*-Force', code_only):
        prohibited.append('-Force passed to the runner (that switch bypasses its lane guard)')
    if re.search(r'\bRemove-Item\b', code_only):
        prohibited.append('Remove-Item (a scheduler that deletes can lose the evidence it protects)')
    if re.search(r'-Force\b', code_only):
        prohibited.append('-Force at all')
    check('the comment-stripper leaves real code behind (a stripper that emptied the file would '
          'make every prohibition pass)', 'Start-Process' in code_only and 'switch' in code_only)
    check('the dispatcher contains no process kill, no -Force and no delete (design section 10)',
          not prohibited, '; '.join(prohibited))
    # RED: the prohibition check must be able to fire, or it is three regexes nobody has run
    # against a positive.
    check('RED the prohibition check fires on a synthetic kill',
          bool(re.search(r'\bStop-Process\b|\.Kill\(\)|\btaskkill\b',
                         code_only + '\nStop-Process -Id 1')))
    check('RED and it does NOT fire on the same words inside a comment',
          not re.search(r'\bStop-Process\b',
                        re.sub(r'#.*$', '',
                               re.sub(r'(?s)<#.*?#>', '', '# Stop-Process is forbidden here\n$x=1'),
                               flags=re.M)))

vocab = S.assert_vocabulary_matches_schema(ROOT)
check('the transition / failure-class / ExecutionKey vocabulary IS schemas.json\'s, re-read from '
      'the file', not vocab, str(vocab))

# --- the suite's own roll-up: every action and every refusal code must be NAMED here ------------
src = io.open(os.path.abspath(__file__), 'r', encoding='utf-8-sig').read()
unnamed_codes = [c for c in S.REFUSAL_CODES if c not in NAMED]
check('ROLL-UP every refusal code the scheduler can emit is named by a case in this suite',
      not unnamed_codes, 'never named: %s' % unnamed_codes)
unnamed_actions = [a for a in S.ACTIONS if ("'%s'" % a) not in src]
check('ROLL-UP every action the planner can emit appears in this suite',
      not unnamed_actions, 'never named: %s' % unnamed_actions)

sys.stdout.write('\n')
if FAILS:
    sys.stdout.write('RESULT: %d failure(s)\n' % len(FAILS))
    for f in FAILS:
        sys.stdout.write('  - %s\n' % f)
    sys.exit(1)
sys.stdout.write('=== every criterion refused its attack, and the kill matrix is COMPLETE: '
                 '%d cells swept, %d of them a real kill-and-resume, all nine transitions '
                 'killed on both sides ===\n' % (matrix_cells, matrix_kills))
sys.exit(0)
