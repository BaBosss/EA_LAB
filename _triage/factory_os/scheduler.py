# -*- coding: utf-8 -*-
"""ORDER-1080 (slice S9) -- the recoverable, idempotent scheduler. design 6.5 / 3.3 (= 20.8 Contract B).

WHAT THIS IS, AND WHAT IT DELIBERATELY IS NOT
  A WRAPPER around the existing runner, never a replacement. `scripts/mt5_run.ps1` already owns
  lane-guarding (its own abort when an instance of this install is alive), the 1:N leverage
  assertion, the input-cache warning, the D3 stale-report clear and the truncation sidecar. None
  of that is re-implemented here. What this module adds is the one thing the runner has no way to
  own: MEMORY ACROSS ITS OWN DEATH.

  Every DECISION in this file is pure: nothing below reads a clock (`obs['now']` is the only one),
  spawns a process, or touches a terminal. The disk section near the bottom is the one exception
  and it is deliberately thin -- it reads and appends the manifest and does nothing else, so that
  the planner and the validator can be driven with no filesystem at all. (/scrutinize round 3
  corrected this paragraph: it used to say "everything in this file is PURE", full stop, which was
  a claim the reader could disprove by scrolling.)
  It folds an append-only manifest, judges a proposed transition, and answers ONE question:
  "given this manifest and these observations, what is the single next action?" The tester work
  lives in `scripts/scheduler_run.ps1`, which observes, dispatches, and records. That split is the
  parity harness's pattern (`parity.py` judges, `parity_run.ps1` runs) and it is what makes the
  kill-at-every-state matrix cost milliseconds and need no MT5 lane.

WHY THE DRIVER HOLDS NO DECISIONS
  A resume loop split across two languages is a resume loop with two state machines, and the
  second one is always the one nobody tests. `plan()` returns a closed-set ACTION; the PowerShell
  side is a switch with no branch of its own. `run_scheduler_tests.py` asserts that the switch
  handles exactly the action set this module can emit, so the day a tenth action is added the
  dispatcher's silence is a failed cage rather than a run that stalls.

THE STORE
  `factory/runs/<run_id>.jsonl`, ONE `RunTransition` per line, append-only, never rewritten
  (schemas.json's own SELF-REVIEW FIX: a journal object holding an attempts array cannot be
  appended to without rewriting it, so the crash-safety claim was unsupported by its own storage
  contract). `RunJournal` is DERIVED by folding those lines and is never written. Attempt k+1
  inherits the Run id and every attempt is kept (decision 65).

THE FOUR ACCEPTANCE CRITERIA, AND WHERE EACH ONE LIVES
  1. kill at EVERY state resumes correctly     -> plan(), and the enumerated matrix in the cage
  2. COMPLETED refused without a fresh report  -> validate_transition S6 + classify_outcome()
  3. identical (config, lane, fingerprint) re-run refused, cached evidence returned
                                               -> execution_key_digest() + find_cached()
  4. cross-lane comparison refused; LEASED refused without a free lane lease
                                               -> refuse_cross_lane() + plan()'s lease reconcile

USAGE  tools\\python312\\python.exe _triage/factory_os/scheduler.py <command> [args]
       commands: queue | plan | append | journal | compare | --self-test
EXIT   0 = the command succeeded  -  1 = a REFUSAL (the reason is on stdout as JSON)
       2 = the scheduler could not read its own inputs
"""

import hashlib
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
RUNS_DIR_REL = 'factory/runs'
LEASE_DIR_REL = 'factory/leases'

# ---------------------------------------------------------------------------------------------
# THE VOCABULARY. All three tuples are the schema's, not this module's -- if they drift from
# `schemas.json` the contract and the writer disagree, so `assert_vocabulary_matches_schema()`
# re-reads the schema and the cage calls it. A writer that invented its own enum member would
# produce a manifest the validator rejects at exactly the moment it is needed most.
TRANSITIONS = ('QUEUED', 'LEASED', 'LAUNCH_INTENT', 'PROCESS_OBSERVED', 'RUNNING',
               'COMPLETED', 'FAILED', 'ABANDONED', 'EVIDENCE_REGISTERED')
FAILURE_CLASSES = ('NONE', 'TESTER_ERROR', 'TERMINAL_ERROR', 'TIMEOUT', 'LEASE_LOST',
                   'KILLED', 'CONFIG_REJECTED')
EXECUTION_KEY_FIELDS = ('expert', 'symbol', 'tf', 'from_date', 'to_date', 'model', 'deposit',
                        'currency', 'leverage', 'set_hash', 'ini_hash', 'ex5_hash',
                        'effective_config_hash', 'data_fingerprint', 'lane')

# TWO GATES, NOT ONE, and conflating them was this module's first real defect.
#
# decision 18 governs QUEUEING A NEW RUN with an identical ExecutionKey: "refuse except after an
# execution or tester error". That is `RETRYABLE_FOR_NEW_RUN`, and it is exactly the decision's
# two classes.
#
# Resuming an EXISTING run's next attempt is a different act. A machine that died mid-run is the
# case a recoverable scheduler exists for, so KILLED and TIMEOUT retry INSIDE the run -- bounded
# by MAX_ATTEMPTS and visible in the manifest, which is what separates a retry from a loop. What
# does NOT retry either way is CONFIG_REJECTED: the configuration was not honoured, and running
# the identical configuration again is the definition of expecting a different answer.
# 🔴 decision 18 NAMES TWO CATEGORIES, NOT TWO ENUM MEMBERS: "except after an execution or tester
# error". The seven failure classes map onto those categories, and the mapping is written out here
# because the first version guessed it -- it read the decision as the literal pair
# (TESTER_ERROR, TERMINAL_ERROR), and the first wiring run on a real lane immediately showed what
# that costs: the machine died mid-run, the configuration went to FAILED(KILLED) with no evidence
# at all, and re-queueing it was refused FOREVER. A slice whose entire purpose is recovery had
# made a crashed configuration permanently unrunnable.
#
# The decision's own remedy is the tell. It reads "...otherwise: return the cached evidence". A
# refusal that has no cached evidence to return is not the rule being enforced, it is the rule
# being misapplied -- so the refusal belongs to runs that HOLD an answer, and the categories
# below decide the rest.
#
#   tester error      TESTER_ERROR
#   execution error   TERMINAL_ERROR, TIMEOUT, KILLED, LEASE_LOST
#   neither           CONFIG_REJECTED -- the configuration was not honoured, which is a fact ABOUT
#                     the configuration; running the identical one again is expecting a different
#                     answer, and a human should look first.
#
# This is an INTERPRETATION of a user-owned decision, not a change to it, and it is flagged as
# such in the handoff so the owner can overrule the mapping without touching the code around it.
RETRYABLE_FOR_NEW_RUN = ('TESTER_ERROR', 'TERMINAL_ERROR', 'TIMEOUT', 'KILLED', 'LEASE_LOST')
# The in-run gate is narrower by one: LEASE_LOST leads to ABANDONED rather than FAILED, so it can
# never be the class a resume is deciding a retry against.
RETRYABLE_IN_RUN = ('TESTER_ERROR', 'TERMINAL_ERROR', 'TIMEOUT', 'KILLED')

# A cap, because two of the seven failure classes are retryable and an unrecognised runner exit
# is classified into one of them. Without a cap, a systematically broken config retries forever
# and the manifest -- the thing that exists to make failure VISIBLE -- fills with noise.
MAX_ATTEMPTS = 3

# The state machine of design 3.3, written as what may FOLLOW what. `None` is "the file does not
# exist yet". COMPLETED is reachable from all three in-flight states on purpose: a resume that
# finds a finished run must be able to record what happened without inventing the intermediate
# observations it was dead for. Skipping forward is honest; skipping BACKWARD is S2.
SUCCESSORS = {
    None: ('QUEUED',),
    'QUEUED': ('LEASED', 'ABANDONED'),
    'LEASED': ('LAUNCH_INTENT', 'FAILED', 'ABANDONED'),
    'LAUNCH_INTENT': ('PROCESS_OBSERVED', 'COMPLETED', 'FAILED', 'ABANDONED'),
    'PROCESS_OBSERVED': ('RUNNING', 'COMPLETED', 'FAILED', 'ABANDONED'),
    'RUNNING': ('COMPLETED', 'FAILED', 'ABANDONED'),
    'COMPLETED': ('EVIDENCE_REGISTERED',),
    'FAILED': ('LEASED', 'ABANDONED'),
    'ABANDONED': (),
    'EVIDENCE_REGISTERED': (),
}

# The closed action set. `plan()` returns exactly one of these and nothing else; the PowerShell
# dispatcher must handle exactly this set (asserted by the cage, not by review).
ACTIONS = ('ACQUIRE_LEASE', 'ADOPT_LEASE', 'RENEW_LEASE', 'DECLARE_LAUNCH_INTENT', 'LAUNCH',
           'ADOPT_PROCESS', 'OBSERVE_RUNNING', 'WAIT', 'RECORD_COMPLETED', 'RECORD_FAILED',
           'RECONCILE_ORPHAN', 'REGISTER_EVIDENCE', 'ADOPT_EVIDENCE', 'RELEASE_LEASE', 'ABANDON',
           'DONE', 'REFUSE')

# How long before expiry a live run renews its own lease. /scrutinize round 2: nothing renewed it
# and no in-flight state re-read it, so the lane lease was enforced at ACQUISITION and then
# decorative for the whole duration of the run -- which is the entire duration that matters. The
# default lease is 4 hours and a Model-4 multi-year run outlives that comfortably, at which point
# the lane is free while a tester is still on it.
RENEW_MARGIN_SEC = 1800

# The closed refusal set. Every one of these is an acceptance criterion wearing a machine-readable
# name; the cage asserts that each is named by a test, which is the L2 idea applied to a module L2
# does not reach (it globs `check_*.py`).
REFUSAL_CODES = ('LANE_BUSY', 'IDENTICAL_RERUN', 'CROSS_LANE', 'RUN_DEAD', 'ATTEMPTS_EXHAUSTED',
                 'MALFORMED_KEY', 'UNKNOWN_RUN')

RUN_ID_RE = re.compile(r'^RUN-[0-9]{8}-[0-9]{3,}$')
# One timestamp format everywhere, so ordering and expiry are STRING comparisons and therefore
# have no timezone or locale to be wrong about. A value that does not match is refused rather
# than parsed leniently -- `report written 2026-08-02 07:00` sorting after `2026-08-02T18:00Z`
# because one of them is a different shape is the kind of bug that only shows up on the recovery
# path, which is the one path nobody re-runs by hand.
TS_RE = re.compile(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$')


# ---------------------------------------------------------------------------------------------
# CANONICAL SERIALIZATION AND THE EXECUTION KEY
# ---------------------------------------------------------------------------------------------
def ts_plus(ts, seconds):
    """`ts` shifted by `seconds`, in the one format. PURE -- it parses the caller's string and
    reads no clock, which is what keeps every planner branch reproducible in the cage."""
    import datetime as _dt
    if not TS_RE.match(str(ts)):
        raise ValueError('%r is not the one timestamp format %s' % (ts, TS_RE.pattern))
    base = _dt.datetime.strptime(ts, '%Y-%m-%dT%H:%M:%SZ')
    return (base + _dt.timedelta(seconds=seconds)).strftime('%Y-%m-%dT%H:%M:%SZ')


def canonical(obj):
    """The one serialization. Sorted keys, no spaces, no ASCII escaping, no trailing newline.

    design 4.5 records that `candidate_digest`'s canonical form is still owed, and names the cost:
    two serializers that disagree produce two digests for one object. This module defines its own
    rather than inheriting that debt -- and refuses any field it was not told about, so a key that
    grows a sixteenth field cannot silently keep its old digest.
    """
    return json.dumps(obj, sort_keys=True, separators=(',', ':'), ensure_ascii=False)


def execution_key_digest(key):
    """sha256 over the canonical form of the 15 required ExecutionKey fields. Raises on any other
    shape.

    WHY IT IS SO WIDE (design 4.5): rev 1 omitted deposit, currency and leverage, so a
    10,000/1:100 run and a 100,000/1:200 run had identical keys and the scheduler would have
    served the wrong cached evidence to criterion 3. Every field below is load-bearing for that
    one sentence.
    """
    missing = [f for f in EXECUTION_KEY_FIELDS if f not in key]
    extra = [f for f in key if f not in EXECUTION_KEY_FIELDS]
    if missing or extra:
        raise ValueError('ExecutionKey missing %s / unknown %s -- a digest over a key whose shape '
                         'is not the contract is a digest of something else'
                         % (sorted(missing), sorted(extra)))
    # 🔴 NUMERIC NORMALIZATION, /scrutinize round 2. `10000` and `10000.0` are the same deposit and
    # serialized to different bytes, so ONE configuration had TWO digests -- exactly the failure
    # design 4.5 warns about for `candidate_digest` ("two serializers that disagree produce two
    # digests for one candidate"), in the function whose docstring claims not to inherit it.
    # Reachable without anyone doing anything strange: PowerShell's ConvertTo-Json emits whichever
    # the caller's variable happened to hold.
    # STATED LIMIT: string fields are compared as written, so `D:\Meta 5` and `D:/Meta 5` are two
    # lanes. Normalising paths would be guessing at an identity the repo has not defined; the
    # lane id is expected to be pasted from the ledger, not typed.
    trimmed = {}
    for f in EXECUTION_KEY_FIELDS:
        v = key[f]
        if isinstance(v, float) and v.is_integer():
            v = int(v)
        trimmed[f] = v
    return hashlib.sha256(canonical(trimmed).encode('utf-8')).hexdigest()


# ---------------------------------------------------------------------------------------------
# THE FOLD -- RunJournal is derived, never written (schemas.json x-derived)
# ---------------------------------------------------------------------------------------------
def fold(lines):
    """Fold RunTransition lines into the derived RunJournal read-model.

    `attempts` is one record per (attempt, transition) line, in file order. The fold never
    collapses or de-duplicates: a manifest that somehow holds a duplicate must SHOW it, because
    the validator's job is to refuse the next one and a fold that quietly merged them would hide
    the evidence that it happened.
    """
    if not lines:
        return None
    first = lines[0]
    journal = {
        'entity': 'RunJournal',
        'run_id': first.get('run_id'),
        'cell_id': first.get('cell_id'),
        'execution_key': first.get('execution_key'),
        'attempts': [],
    }
    for ln in lines:
        rec = dict(ln.get('record') or {})
        rec['attempt'] = ln.get('attempt')
        rec['transition'] = ln.get('transition')
        rec['at'] = ln.get('at')
        journal['attempts'].append(rec)
        if ln.get('execution_key') and not journal['execution_key']:
            journal['execution_key'] = ln['execution_key']
    return journal


def tail(journal):
    """The last transition, or None for a run that does not exist yet."""
    if not journal or not journal['attempts']:
        return None
    return journal['attempts'][-1]['transition']


def current_attempt(journal):
    if not journal or not journal['attempts']:
        return 0
    return journal['attempts'][-1]['attempt']


def attempt_records(journal, attempt):
    return [a for a in journal['attempts'] if a['attempt'] == attempt]


def _field(journal, attempt, name):
    """The most recent non-null value of `name` inside one attempt.

    The attempt is spread across several append-only lines, so `launch_intent_at` is written on
    the LAUNCH_INTENT line and has to be readable from the RUNNING line's point of view. Reading
    the last non-null rather than the last value is deliberate: a later line that simply does not
    carry the field must not erase it.
    """
    val = None
    for rec in attempt_records(journal, attempt):
        if rec.get(name) is not None:
            val = rec[name]
    return val


# ---------------------------------------------------------------------------------------------
# THE MONOTONIC TRANSITION VALIDATOR (CONTRACTS.md: "enforced by scheduler")
# ---------------------------------------------------------------------------------------------
def validate_transition(journal, line):
    """Return a list of problems with appending `line` to `journal`. Empty list = allowed.

    Criterion ids are S1-S9 so the cage can be checked for naming each one (the L2 idea; this
    module does not match `check_*.py` and so L2 would never reach it on its own).
    """
    problems = []

    # -- S1 shape. Checked here rather than trusting the schema, because the schema is validated
    #    by ajv in a suite that does not run on the recovery path, and a malformed line written
    #    during recovery is the one nobody would see until the next crash.
    if line.get('entity') != 'RunTransition':
        problems.append('S1 entity must be RunTransition, got %r' % line.get('entity'))
    if not RUN_ID_RE.match(str(line.get('run_id', ''))):
        problems.append('S1 run_id %r does not match %s' % (line.get('run_id'), RUN_ID_RE.pattern))
    if line.get('transition') not in TRANSITIONS:
        problems.append('S1 transition %r is not one of %s' % (line.get('transition'), list(TRANSITIONS)))
    if not isinstance(line.get('attempt'), int) or isinstance(line.get('attempt'), bool) \
            or line.get('attempt', 0) < 1:
        problems.append('S1 attempt must be an integer >= 1, got %r' % (line.get('attempt'),))
    if not TS_RE.match(str(line.get('at', ''))):
        problems.append('S1 at %r is not the one timestamp format %s'
                        % (line.get('at'), TS_RE.pattern))
    if not line.get('cell_id'):
        problems.append('S1 cell_id is required')
    if problems:
        # Everything below reads these fields. Judging ordering against a line whose transition is
        # not even a member of the enum produces a second, misleading finding.
        return problems

    prev = tail(journal)
    trans = line['transition']

    # -- S9 identity: a line belongs to the run whose file it is appended to.
    if journal:
        if line['run_id'] != journal['run_id']:
            problems.append('S9 run_id %s does not belong to journal %s'
                            % (line['run_id'], journal['run_id']))
        if line['cell_id'] != journal['cell_id']:
            problems.append('S9 cell_id %s contradicts the journal cell_id %s'
                            % (line['cell_id'], journal['cell_id']))

    # -- S2 ordering. This is the whole "monotonic transition validator".
    allowed = SUCCESSORS.get(prev, ())
    if trans not in allowed:
        problems.append('S2 %s may not follow %s (allowed: %s)'
                        % (trans, prev, list(allowed) or 'nothing -- the run is terminal'))

    # -- S3 attempt numbering. Attempt k+1 inherits the Run id (decision 65) and may begin ONLY
    #    after a FAILED. Anything else is either a lost line or two drivers writing at once, and
    #    both are worse to discover later.
    cur = current_attempt(journal)
    if journal:
        if line['attempt'] == cur:
            pass
        elif line['attempt'] == cur + 1:
            if prev != 'FAILED':
                problems.append('S3 attempt %d opens after a %s line -- a new attempt may only '
                                'follow FAILED' % (line['attempt'], prev))
            if line['attempt'] > MAX_ATTEMPTS:
                problems.append('S3 attempt %d exceeds MAX_ATTEMPTS=%d'
                                % (line['attempt'], MAX_ATTEMPTS))
        else:
            problems.append('S3 attempt %d is neither the current attempt %d nor its successor'
                            % (line['attempt'], cur))
    elif line['attempt'] != 1:
        problems.append('S3 the first line of a run must be attempt 1, got %d' % line['attempt'])

    # -- S4 duplication. The append-only store's own anti-duplication rule: one (attempt,
    #    transition) pair may be written once. This is what makes "duplicates no event" checkable
    #    at the manifest layer as well as at the event-store layer.
    if journal:
        for rec in attempt_records(journal, line['attempt']):
            if rec['transition'] == trans:
                problems.append('S4 attempt %d already recorded %s at %s -- appending it again '
                                'would make the resume double-count it'
                                % (line['attempt'], trans, rec['at']))
                break

    # -- S5 the ExecutionKey is written ONCE, on the QUEUED line, and never contradicted.
    if trans == 'QUEUED':
        if not line.get('execution_key'):
            problems.append('S5 the QUEUED line must carry the ExecutionKey -- it is the only '
                            'line that does, and criterion 3 has nothing to compare without it')
        else:
            try:
                execution_key_digest(line['execution_key'])
            except ValueError as exc:
                problems.append('S5 %s' % exc)
    elif line.get('execution_key') and journal and journal.get('execution_key') \
            and line['execution_key'] != journal['execution_key']:
        problems.append('S5 this line carries an ExecutionKey that contradicts the QUEUED line')

    # -- S6 COMPLETED is REFUSED without a fresh report. This is acceptance criterion 2, and it is
    #    a refusal in the validator rather than a check in the driver so that no future caller can
    #    write COMPLETED by any other route. The proof shape is the shared guard's own two halves:
    #    an accepted runner exit AND a mtime at or after the moment the run started.
    if trans == 'COMPLETED':
        proof = (line.get('record') or {}).get('report_fresh_proof')
        if not proof:
            problems.append('S6 COMPLETED without report_fresh_proof -- "the .htm exists" is not '
                            'evidence that this attempt produced it (scripts/lib/report_freshness.ps1)')
        else:
            if proof.get('fresh') is not True:
                problems.append('S6 COMPLETED whose report_fresh_proof.fresh is %r'
                                % proof.get('fresh'))
            if proof.get('runner_exit') not in (0, 3):
                problems.append('S6 COMPLETED with runner exit %r -- only 0 and 3 mean a report '
                                'was written by THIS run' % proof.get('runner_exit'))
            if not proof.get('report_path'):
                problems.append('S6 report_fresh_proof names no report path')
            if not TS_RE.match(str(proof.get('report_mtime', ''))) \
                    or not TS_RE.match(str(proof.get('run_start', ''))):
                problems.append('S6 report_fresh_proof needs run_start and report_mtime in the '
                                'one timestamp format, got %r / %r'
                                % (proof.get('run_start'), proof.get('report_mtime')))
            elif proof['report_mtime'] < proof['run_start']:
                problems.append('S6 report_fresh_proof claims fresh but the report (%s) predates '
                                'the run start (%s)' % (proof['report_mtime'], proof['run_start']))

    # -- S7 a failure must say WHICH failure. An unclassified FAILED cannot be routed by decision
    #    18, so it would default to whatever the reader assumed.
    if trans == 'FAILED':
        fc = (line.get('record') or {}).get('failure_class')
        if fc not in FAILURE_CLASSES or fc == 'NONE':
            problems.append('S7 FAILED needs a failure_class from %s (NONE is not a failure), '
                            'got %r' % (list(FAILURE_CLASSES[1:]), fc))

    # -- S8 EVIDENCE_REGISTERED must carry the event id the store returned. Without it a crash
    #    between the store append and this line has nothing to reconcile against, which is the
    #    exact hole schemas.json added the field to close.
    if trans == 'EVIDENCE_REGISTERED':
        if not (line.get('record') or {}).get('event_id'):
            problems.append('S8 EVIDENCE_REGISTERED without event_id -- a resume could not tell '
                            'an event that landed from one that did not, and would append a second')

    return problems


# ---------------------------------------------------------------------------------------------
# THE PLANNER -- one manifest plus one observation set gives exactly one action
# ---------------------------------------------------------------------------------------------
def _refuse(code, why, **extra):
    if code not in REFUSAL_CODES:
        raise ValueError('refusal code %r is not in the closed set %s' % (code, list(REFUSAL_CODES)))
    out = {'action': 'REFUSE', 'code': code, 'why': why}
    out.update(extra)
    return out


def _act(action, why, **extra):
    if action not in ACTIONS:
        raise ValueError('action %r is not in the closed set %s' % (action, list(ACTIONS)))
    out = {'action': action, 'why': why}
    out.update(extra)
    return out


def lease_is_free(lease, run_id, now):
    """(free_for_us, ours) for one lane's lease record.

    An expired lease is free. Without an expiry a machine that died holding a lease keeps the lane
    forever -- schemas.json says so on the field itself, and this is the line that makes it true.
    """
    if not lease:
        return True, False
    ours = lease.get('owner') == run_id
    expired = str(lease.get('expires_at', '')) <= now
    return (ours or expired), ours


def classify_outcome(exit_record, report_fresh):
    """Pure classification of one finished runner invocation -> (transition, failure_class).

    The mapping is the runner's own documented contract (`scripts/mt5_run.ps1`, and
    `Get-RunnerExitMeaning` in the freshness library), stated once, here, where the cage can
    enumerate it -- rather than as a switch inside a PowerShell loop nobody re-runs.

    exit 2 is TERMINAL_ERROR and NOT a tester failure on purpose: it is the runner refusing to
    start because an instance of this install is already alive. That is the SECOND cage against a
    double launch (the first is this module's reconcile), and misfiling it as a tester error would
    have the scheduler retry into the same busy lane.
    """
    code = exit_record.get('exit_code')
    out = str(exit_record.get('stdout_tail') or '')
    if code == 2:
        return 'FAILED', 'TERMINAL_ERROR'
    if code == 1:
        if 'TIMEOUT after' in out:
            return 'FAILED', 'TIMEOUT'
        return 'FAILED', 'TESTER_ERROR'
    if code == 3:
        # The report is real but ran at a leverage the run did not ask for, so its numbers are not
        # comparable to anything -- the freshness guard refuses it unless a caller explicitly opts
        # in, and a scheduler that opted in on the caller's behalf would be laundering it.
        return 'FAILED', 'CONFIG_REJECTED'
    if code == 0:
        if report_fresh is True:
            return 'COMPLETED', 'NONE'
        return 'FAILED', 'TESTER_ERROR'
    # WHITELIST, not blacklist -- the lesson report_freshness.ps1 paid for. An unrecognised code
    # is a failure, never a success, and it is retryable only because MAX_ATTEMPTS bounds it.
    return 'FAILED', 'TERMINAL_ERROR'


def plan(journal, obs):
    """The single next action, with the lane handed back when this run is finished with it.

    🔴 THE LANE WAS NEVER RELEASED, and the first wiring run on a real lane is what said so: run
    001 ended ATTEMPTS_EXHAUSTED still holding the lease, and run 002 -- a different run of the
    same cell -- was refused LANE_BUSY for the four hours until the lease expired. The expiry is
    there so a DEAD machine cannot hold a lane forever (schemas.json says exactly that on the
    field); it was never meant to be how a LIVE, finished run gives one back.

    The release is a planner decision and not a dispatcher one, which is why it is here rather
    than in a `finally` on the PowerShell side: "am I finished, and is this lease mine" is exactly
    the kind of question that grows a second state machine when it is answered in the driver.
    """
    inner = _plan_inner(journal, obs)
    if journal is None:
        return inner
    finished = inner['action'] == 'DONE' or (
        inner['action'] == 'REFUSE' and inner.get('code') in ('RUN_DEAD', 'ATTEMPTS_EXHAUSTED'))
    if finished:
        lease = obs.get('lease')
        if lease and lease.get('owner') == journal['run_id'] \
                and str(lease.get('expires_at', '')) > obs['now']:
            return _act('RELEASE_LEASE',
                        'this run is finished (%s) and still holds lane %s -- handing it back '
                        'now rather than leaving the next run to wait out the expiry'
                        % (inner.get('code') or inner['action'],
                           (journal.get('execution_key') or {}).get('lane')),
                        attempt=current_attempt(journal), next_action=inner['action'])
    return inner


def _plan_inner(journal, obs):
    """The single next action. PURE: `obs['now']` is the only clock.

    Observation contract (the driver gathers all of it every iteration, unconditionally -- a
    driver that decided WHICH observations to take would be making the decision this function
    exists to own):
        now             one timestamp, TS_RE format
        lease           the lane's lease record, or None
        child_running   the worker process that owns this attempt is alive
        tester_running  a terminal64 of THIS install is alive
        exit_record     {exit_code, at, stdout_tail} written by the worker, or None
        report_fresh    Test-ReportIsFresh's verdict, or None when there is nothing to judge
        report_path / report_mtime   the proof material for S6
        spawn_marker    THIS attempt's spawn marker exists on disk (see the LAUNCH_INTENT branch)
        evidence        {event_id, evidence_id} already present in the event store, or None

    Everything keyed to an attempt -- exit_record, report_fresh, report_mtime, spawn_marker -- is
    the CURRENT attempt's and nothing else. A driver that handed over attempt 1's exit record
    while attempt 2 was starting would have the planner declare attempt 2 finished before it ran.
    """
    now = obs['now']
    if journal is None:
        return _refuse('UNKNOWN_RUN', 'no manifest for this run -- `queue` it first')

    state = tail(journal)
    attempt = current_attempt(journal)

    # --- terminal states ---------------------------------------------------------------------
    if state == 'EVIDENCE_REGISTERED':
        return _act('DONE', 'the run is complete and its evidence is registered')
    if state == 'ABANDONED':
        return _refuse('RUN_DEAD', 'this run was ABANDONED; queue a new one rather than reviving it')

    # --- COMPLETED -> evidence, with the store reconciled BEFORE any append -------------------
    if state == 'COMPLETED':
        if obs.get('evidence'):
            # THE ANTI-DUPLICATION BRANCH. A crash between the event-store append and the
            # EVIDENCE_REGISTERED line loses the id but not the event; appending a second one
            # would duplicate the occurrence in a store that is the owner of the experiment
            # timeline. Reconcile the store first, adopt what is there.
            # THE MESSAGE SAYS WHAT WAS MEASURED. /scrutinize round 3: it read "the event store
            # already holds THIS RUN'S evidence", and the observation behind it is content-
            # addressed -- it holds evidence for this ARTIFACT'S exact bytes, whoever registered
            # them. Those coincide for every real case (criterion 3 refuses a second run of the
            # same configuration, and two different configurations producing byte-identical
            # reports would be a coincidence), but the claim was still wider than the check, and
            # a probe reached it by handing one run another run's report.
            return _act('ADOPT_EVIDENCE', 'the event store already holds evidence for this '
                                          'artifact\'s exact content; adopting that id rather '
                                          'than appending a second event for the same bytes',
                        attempt=attempt, event_id=obs['evidence']['event_id'],
                        evidence_id=obs['evidence'].get('evidence_id'))
        return _act('REGISTER_EVIDENCE', 'the attempt completed and no event exists yet',
                    attempt=attempt)

    # --- FAILED -> retry, but only where decision 18 allows it -------------------------------
    if state == 'FAILED':
        fc = _field(journal, attempt, 'failure_class')
        if fc not in RETRYABLE_IN_RUN:
            return _refuse('RUN_DEAD', 'the last attempt failed with %s, which is not one of the '
                                       'classes a resume may retry inside a run (%s)'
                           % (fc, list(RETRYABLE_IN_RUN)))
        if attempt >= MAX_ATTEMPTS:
            return _refuse('ATTEMPTS_EXHAUSTED',
                           'attempt %d of %d failed with %s; a further retry would be the '
                           'scheduler hiding a systematic failure behind repetition'
                           % (attempt, MAX_ATTEMPTS, fc))
        free, ours = lease_is_free(obs.get('lease'), journal['run_id'], now)
        if not free:
            return _refuse('LANE_BUSY', 'lane %s is leased by %s until %s'
                           % (journal['execution_key']['lane'], obs['lease'].get('owner'),
                              obs['lease'].get('expires_at')))
        return _act('ADOPT_LEASE' if ours else 'ACQUIRE_LEASE',
                    'retry after %s -- opening attempt %d' % (fc, attempt + 1),
                    attempt=attempt + 1)

    # --- QUEUED -> the lane lease. design 3.3: REFUSE LEASED without a free lane lease -------
    if state == 'QUEUED':
        free, ours = lease_is_free(obs.get('lease'), journal['run_id'], now)
        if not free:
            return _refuse('LANE_BUSY',
                           'lane %s is leased by %s until %s -- design 3.3 refuses LEASED without '
                           'a free lease for that specific install, and ORDER-371 is why: numbers '
                           'do not transfer across installs, so borrowing a busy lane does not '
                           'merely risk a collision, it produces a result that means nothing'
                           % (journal['execution_key']['lane'], obs['lease'].get('owner'),
                              obs['lease'].get('expires_at')))
        return _act('ADOPT_LEASE' if ours else 'ACQUIRE_LEASE',
                    'the lane is free (or already ours)', attempt=attempt)

    # --- LEASED -> declare the intent to launch, but only while the lease still holds ---------
    if state == 'LEASED':
        free, ours = lease_is_free(obs.get('lease'), journal['run_id'], now)
        if not ours:
            return _act('ABANDON', 'the lane lease is no longer held by this run -- a run whose '
                                   'lane was taken cannot claim its numbers came from that lane',
                        attempt=attempt, failure_class='LEASE_LOST')
        return _act('DECLARE_LAUNCH_INTENT',
                    'record the intent BEFORE the spawn, so a crash around it is decidable',
                    attempt=attempt)

    # --- the three in-flight states share ONE reconcile, in a fixed order ---------------------
    # The order is the point. Cheapest-and-most-decisive first: a finished worker left an exit
    # record, so nothing needs to be inferred; then a live process, which forbids a second launch;
    # only when BOTH are absent is the state genuinely unknown, and only then does the answer
    # depend on which state we were in.
    if state in ('LAUNCH_INTENT', 'PROCESS_OBSERVED', 'RUNNING'):
        exit_rec = obs.get('exit_record')

        # 🔴 THE LANE LEASE IS RE-READ WHILE IN FLIGHT, /scrutinize round 2. It used to be checked
        # at acquisition and never again, so a run whose lease expired mid-flight -- the default is
        # 4 hours and a Model-4 multi-year run outlives that -- kept going on a lane the store
        # said was free. Probed: with the lease EXPIRED five hours earlier, and again with the lane
        # visibly TAKEN by another run, the planner answered WAIT both times.
        #
        # THE ORDER IS THE ARGUMENT. A finished attempt is judged FIRST, because losing the lease
        # does not invalidate a report that already exists: `mt5_run.ps1` refuses to start while an
        # instance of this install is alive, so the other run either waited or aborted with exit 2
        # -- it cannot have run a tester concurrently with ours. What losing the lease DOES
        # invalidate is the right to keep occupying the lane, so an unfinished attempt abandons.
        if not exit_rec:
            lease = obs.get('lease')
            _free, ours = lease_is_free(lease, journal['run_id'], now)
            if not ours:
                return _act('ABANDON', 'the lane lease is no longer held by this run and this '
                                       'attempt has produced nothing -- continuing would occupy a '
                                       'lane the store has already given away',
                            attempt=attempt, failure_class='LEASE_LOST')
            if str(lease.get('expires_at', '')) <= ts_plus(now, RENEW_MARGIN_SEC):
                return _act('RENEW_LEASE',
                            'this attempt is still in flight and its lease expires at %s -- '
                            'renewing, because an expiry is for a machine that DIED, not for one '
                            'that is still working' % lease.get('expires_at'),
                            attempt=attempt, expires_at=ts_plus(now, 2 * RENEW_MARGIN_SEC))

        if exit_rec:
            trans, fc = classify_outcome(exit_rec, obs.get('report_fresh'))
            if trans == 'COMPLETED':
                return _act('RECORD_COMPLETED', 'the worker finished and its report is fresh',
                            attempt=attempt, exit_code=exit_rec.get('exit_code'),
                            proof={'fresh': True,
                                   'runner_exit': exit_rec.get('exit_code'),
                                   'report_path': obs.get('report_path'),
                                   'report_mtime': obs.get('report_mtime'),
                                   'run_start': _field(journal, attempt, 'launch_intent_at')})
            return _act('RECORD_FAILED', 'the worker finished without usable evidence',
                        attempt=attempt, exit_code=exit_rec.get('exit_code'), failure_class=fc)

        if obs.get('child_running') or obs.get('tester_running'):
            if state == 'LAUNCH_INTENT':
                # RECONCILED, NOT RELAUNCHED. This is the branch acceptance criterion 1 is really
                # about: `launch_intent_at` with no `process_observed` means the crash happened
                # around the spawn, and the only safe question is "is an MT5 already running on
                # this lane?" -- schemas.json says exactly that on the field.
                return _act('ADOPT_PROCESS', 'a process for this lane is alive -- adopting it '
                                             'rather than launching a second one', attempt=attempt)
            if state == 'PROCESS_OBSERVED' and obs.get('tester_running'):
                return _act('OBSERVE_RUNNING', 'the tester itself is alive, so the runner got '
                                               'past its own abort guard', attempt=attempt)
            return _act('WAIT', 'the attempt is in flight', attempt=attempt)

        # Nothing running, nothing finished.
        if state == 'LAUNCH_INTENT':
            # 🔴 THE DEFECT THE ENUMERATED MATRIX FOUND, and neither of the two states this
            # branch was written from could see it. `LAUNCH_INTENT` + nothing running + no exit
            # record has TWO causes: the spawn never happened, or it happened and the worker was
            # killed hard enough to write nothing. The first wants a launch; the second wants a
            # FAILED line. Answering both with LAUNCH re-launched a dead attempt IN PLACE --
            # invisible in the manifest, and therefore not bounded by MAX_ATTEMPTS either. The
            # cage caught it as `2 launches for 1 attempt(s)` in the killed-worker scenario.
            #
            # The spawn marker is what makes the pair decidable, and it is the same two-record
            # trick schemas.json used one level up for launch_intent/process_observed: the driver
            # writes a per-attempt marker at spawn time, so its ABSENCE is proof no spawn
            # occurred. The residual window -- marker written, spawn refused -- fails SAFE: it
            # yields FAILED(KILLED) and a fresh attempt, never a silent relaunch. That direction
            # is chosen, not incidental.
            if obs.get('spawn_marker'):
                return _act('RECONCILE_ORPHAN',
                            'this attempt was spawned and is now gone with no exit record; a '
                            'relaunch here would hide a dead attempt inside a live one',
                            attempt=attempt, failure_class='KILLED')
            # Safe by construction: the reconcile above just proved no process for this lane is
            # alive and that this attempt was never spawned at all.
            return _act('LAUNCH', 'intent is recorded, nothing is running, and this attempt has '
                                  'no spawn marker -- it was never started', attempt=attempt)
        return _act('RECONCILE_ORPHAN',
                    'the attempt was observed running and is now gone with no exit record -- it '
                    'was killed; recording that is what stops the resume from calling it complete',
                    attempt=attempt, failure_class='KILLED')

    raise AssertionError('unreachable: state %r has no plan branch' % state)


# ---------------------------------------------------------------------------------------------
# CRITERION 3 -- idempotency. IDENTICAL means identical, and the answer is the cached evidence.
# ---------------------------------------------------------------------------------------------
# The dispositions a prior run with the same ExecutionKey can hold, MOST BLOCKING FIRST. Only the
# last one lets a new run through, which is decision 18 read strictly: "except after an execution
# or tester error" is a whitelist of two classes, not "anything that is not a success".
DISPOSITIONS = ('EVIDENCE', 'COMPLETED', 'IN_FLIGHT', 'DEAD', 'RETRYABLE')
BLOCKING = DISPOSITIONS[:-1]


def run_disposition(journal):
    """How a prior run with this ExecutionKey bears on a new one."""
    states = [a['transition'] for a in journal['attempts']]
    if 'EVIDENCE_REGISTERED' in states:
        return 'EVIDENCE'
    if 'COMPLETED' in states:
        return 'COMPLETED'
    last = tail(journal)
    if last in ('FAILED', 'ABANDONED'):
        # ABANDONED is judged by its class for the same reason FAILED is: a run abandoned because
        # another lane took its lease holds no evidence and says nothing about the configuration.
        fc = _field(journal, current_attempt(journal), 'failure_class')
        return 'RETRYABLE' if fc in RETRYABLE_FOR_NEW_RUN else 'DEAD'
    # Neither finished nor failed: this configuration is ON A LANE RIGHT NOW. Queueing a duplicate
    # would spend the lane twice for one answer, which is the same waste criterion 3 exists to
    # prevent -- it just has not produced its evidence yet.
    return 'IN_FLIGHT'


def find_cached(all_runs, key_digest, exclude_run=None):
    """The most blocking prior run for this ExecutionKey digest -> (run_id, journal, disposition),
    or None when this configuration has never been run.

    `exclude_run` exists because the caller is often itself in the store, and a run that refused
    itself would be the idempotency check making the system unable to make progress -- which is
    how a gate gets disabled.
    """
    best = None
    for run_id, journal in sorted(all_runs.items()):
        if run_id == exclude_run or not journal or not journal.get('execution_key'):
            continue
        try:
            digest = execution_key_digest(journal['execution_key'])
        except ValueError:
            # A stored key that is not the contract cannot be compared. Skipping it is the only
            # honest option, and it is safe in the blocking direction: an uncomparable run never
            # licenses a re-run, it just fails to block one.
            continue
        if digest != key_digest:
            continue
        disp = run_disposition(journal)
        if best is None or DISPOSITIONS.index(disp) < DISPOSITIONS.index(best[2]):
            best = (run_id, journal, disp)
    return best


def queue_decision(all_runs, key, cell_id, now, run_id):
    """Decide whether a new run may be queued for this ExecutionKey. Criterion 3."""
    try:
        digest = execution_key_digest(key)
    except ValueError as exc:
        return _refuse('MALFORMED_KEY', str(exc))
    hit = find_cached(all_runs, digest, exclude_run=run_id)
    if hit and hit[2] in BLOCKING:
        prior, journal, why = hit
        return _refuse('IDENTICAL_RERUN',
                       'run %s already holds this exact (config, lane, data fingerprint) and is '
                       '%s. decision 18 permits a re-run only after an execution or tester '
                       'error, so the cached evidence is returned instead of spending the lane '
                       'again.' % (prior, why),
                       cached_run=prior, cached_state=why,
                       cached_event_id=_field(journal, current_attempt(journal), 'event_id'),
                       execution_key_digest=digest)
    line = {
        'entity': 'RunTransition', 'run_id': run_id, 'cell_id': cell_id,
        'execution_key': dict((f, key[f]) for f in EXECUTION_KEY_FIELDS),
        'attempt': 1, 'transition': 'QUEUED', 'at': now,
    }
    return {'action': 'QUEUED', 'line': line, 'execution_key_digest': digest}


# ---------------------------------------------------------------------------------------------
# CRITERION 4 -- cross-lane comparison is a rejected job, not a rule people remember
# ---------------------------------------------------------------------------------------------
def refuse_cross_lane(journals):
    """Refuse a comparison whose members do not all hold the same lane id (design 6.4, decision 43).

    Measured, not asserted: AGENTS.md section 3.2 records a 14x tick-count difference between two
    installs on an identical EA, set and window. A comparison across that is not a weak result, it
    is a number about nothing.
    """
    lanes = {}
    for run_id, journal in journals.items():
        key = (journal or {}).get('execution_key') or {}
        lanes.setdefault(key.get('lane'), []).append(run_id)
    # 🔴 /scrutinize round 2: a run with NO lane recorded used to collapse into the single bucket
    # `None`, so two runs whose lane nobody knows compared as "the same lane" -- the answer that
    # requires the MOST evidence returned by the branch that has the LEAST. An unknown lane is
    # refused, and the message says which runs are unknown rather than implying they differ.
    unknown = lanes.pop(None, []) + lanes.pop('', [])
    if unknown:
        return _refuse('CROSS_LANE',
                       'these runs record no lane at all: %s. A comparison cannot be licensed by '
                       'the absence of the fact it depends on.' % sorted(unknown))
    if len(lanes) > 1:
        detail = '; '.join('%s: %s' % (lane, sorted(runs)) for lane, runs in sorted(
            lanes.items(), key=lambda kv: str(kv[0])))
        return _refuse('CROSS_LANE',
                       'these runs hold %d different lane ids (%s). ORDER-371: numbers do not '
                       'transfer across installs, so this comparison is refused rather than '
                       'annotated.' % (len(lanes), detail))
    return None


# ---------------------------------------------------------------------------------------------
# DISK I/O. Kept at the edge and thin, so that everything above stays testable without a
# filesystem -- and so the cage's stub store is the same shape as the real one.
# ---------------------------------------------------------------------------------------------
def runs_dir(root=None):
    return os.path.join(root or ROOT, RUNS_DIR_REL.replace('/', os.sep))


def manifest_path(run_id, root=None):
    return os.path.join(runs_dir(root), run_id + '.jsonl')


def read_manifest(path):
    """Read one manifest. utf-8-sig, because PowerShell's `Set-Content -Encoding UTF8` writes a
    BOM that `json.loads` refuses -- a trap this repo has already paid for twice."""
    if not os.path.exists(path):
        return []
    out = []
    with io.open(path, 'r', encoding='utf-8-sig') as fh:
        for n, raw in enumerate(fh, 1):
            raw = raw.strip()
            if not raw:
                continue
            try:
                out.append(json.loads(raw))
            except ValueError as exc:
                raise ValueError('%s line %d is not JSON: %s' % (path, n, exc))
    return out


def append_manifest(path, line):
    """Append ONE line. No rewrite path exists in this module, deliberately: the store's
    append-only claim is worth exactly as much as the absence of a function that could break it."""
    d = os.path.dirname(path)
    if d and not os.path.isdir(d):
        os.makedirs(d)
    with io.open(path, 'a', encoding='utf-8', newline='\n') as fh:
        fh.write(canonical(line) + '\n')


def load_all_runs(root=None):
    out = {}
    d = runs_dir(root)
    if not os.path.isdir(d):
        return out
    for name in sorted(os.listdir(d)):
        if not name.endswith('.jsonl'):
            continue
        run_id = name[:-len('.jsonl')]
        out[run_id] = fold(read_manifest(os.path.join(d, name)))
    return out


# ---------------------------------------------------------------------------------------------
# The vocabulary must be the SCHEMA's. A writer with a private enum is a writer that produces a
# manifest its own validator rejects.
# ---------------------------------------------------------------------------------------------
def assert_vocabulary_matches_schema(root=None):
    path = os.path.join(root or ROOT, '_triage', 'factory_os', 'schemas.json')
    with io.open(path, 'r', encoding='utf-8-sig') as fh:
        schema = json.load(fh)
    defs = schema['$defs']
    problems = []
    got = tuple(defs['RunTransition']['properties']['transition']['enum'])
    if got != TRANSITIONS:
        problems.append('TRANSITIONS %s != schema %s' % (list(TRANSITIONS), list(got)))
    got = tuple(defs['RunAttempt']['properties']['failure_class']['enum'])
    if got != FAILURE_CLASSES:
        problems.append('FAILURE_CLASSES %s != schema %s' % (list(FAILURE_CLASSES), list(got)))
    got = tuple(defs['ExecutionKey']['required'])
    if tuple(sorted(got)) != tuple(sorted(EXECUTION_KEY_FIELDS)):
        problems.append('EXECUTION_KEY_FIELDS %s != schema required %s'
                        % (sorted(EXECUTION_KEY_FIELDS), sorted(got)))
    return problems


# ---------------------------------------------------------------------------------------------
# CLI -- the only surface `scripts/scheduler_run.ps1` uses. Every command prints ONE json object.
# ---------------------------------------------------------------------------------------------
def _emit(obj, code=0):
    sys.stdout.write(canonical(obj) + '\n')
    return code


def main(argv):
    if not argv or argv[0] in ('-h', '--help'):
        sys.stdout.write(__doc__)
        return 0
    cmd = argv[0]
    args = {}
    for a in argv[1:]:
        if a.startswith('--') and '=' in a:
            k, v = a[2:].split('=', 1)
            args[k.replace('-', '_')] = v
    # JSON arrives by FILE, not on the command line. PowerShell 5.1 re-parses a quoted argument
    # on its way to a native process, so a `--obs={"a":"b"}` that survives one shape of quoting
    # loses its quotes in another -- and the failure is a JSON parse error blamed on the caller
    # that wrote the object correctly.
    for name in ('obs', 'line', 'key'):
        path = args.pop(name + '_file', None)
        if path:
            with io.open(path, 'r', encoding='utf-8-sig') as fh:
                args[name] = fh.read()
    root = args.get('root') or ROOT

    if cmd == '--self-test':
        return _selftest()

    if cmd == 'queue':
        key = json.loads(args['key'])
        dec = queue_decision(load_all_runs(root), key, args['cell'], args['now'], args['run'])
        if dec['action'] == 'REFUSE':
            return _emit(dec, 1)
        # 🔴 VALIDATED AGAINST THE RUN'S OWN JOURNAL, /scrutinize round 2. This passed `None`, so
        # the one command that CREATES a manifest was the one command that never looked at the
        # manifest: queueing the same run id twice appended a SECOND `QUEUED` line, and the
        # duplicate-refusal (S4) and the ordering rule (S2) both sat there unable to see it.
        # Reproduced -- two calls, two lines, both exit 0.
        existing = fold(read_manifest(manifest_path(args['run'], root)))
        problems = validate_transition(existing, dec['line'])
        if problems:
            return _emit({'action': 'REFUSE', 'code': 'MALFORMED_KEY', 'why': problems}, 1)
        append_manifest(manifest_path(args['run'], root), dec['line'])
        return _emit(dec)

    if cmd == 'plan':
        journal = fold(read_manifest(manifest_path(args['run'], root)))
        obs = json.loads(args['obs'])
        out = plan(journal, obs)
        return _emit(out, 1 if out['action'] == 'REFUSE' else 0)

    if cmd == 'append':
        path = manifest_path(args['run'], root)
        journal = fold(read_manifest(path))
        line = json.loads(args['line'])
        problems = validate_transition(journal, line)
        if problems:
            return _emit({'action': 'REFUSE', 'code': 'RUN_DEAD', 'why': problems}, 1)
        append_manifest(path, line)
        return _emit({'action': 'APPENDED', 'transition': line['transition'],
                      'attempt': line['attempt']})

    if cmd == 'journal':
        return _emit(fold(read_manifest(manifest_path(args['run'], root))) or {})

    if cmd == 'compare':
        wanted = [r for r in args['runs'].split(',') if r]
        allr = load_all_runs(root)
        missing = [r for r in wanted if r not in allr]
        if missing:
            return _emit(_refuse('UNKNOWN_RUN', 'no manifest for %s' % missing), 1)
        ref = refuse_cross_lane(dict((r, allr[r]) for r in wanted))
        if ref:
            return _emit(ref, 1)
        return _emit({'action': 'COMPARABLE', 'runs': wanted,
                      'lane': allr[wanted[0]]['execution_key']['lane']})

    sys.stderr.write('unknown command %r\n' % cmd)
    return 2


def _selftest():
    """Proves the two claims this file makes about ITSELF: the vocabulary is the schema's, and
    every action/refusal code the planner can return is inside its own closed set. Both are the
    shape that rots silently, which is why they are executable rather than written down."""
    problems = assert_vocabulary_matches_schema()
    for action in ACTIONS:
        if action == 'REFUSE':
            continue
        try:
            _act(action, 'self-test')
        except ValueError as exc:
            problems.append(str(exc))
    for code in REFUSAL_CODES:
        try:
            _refuse(code, 'self-test')
        except ValueError as exc:
            problems.append(str(exc))
    try:
        _act('NOT_AN_ACTION', 'x')
        problems.append('the closed action set accepted an invented member')
    except ValueError:
        pass
    for p in problems:
        sys.stdout.write('  [FAIL] %s\n' % p)
    sys.stdout.write('scheduler self-test: %s\n' % ('FAILED' if problems else 'ok'))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
