# -*- coding: utf-8 -*-
"""ORDER-1100 (slice S10) -- the append-only Deployment attestation event log. design 4.7.

THE ACCEPTANCE THIS FILE OWNS (design 10, S10 row, verbatim)
  "no non-OBSERVED attestation event without a human authorization ref"
  CONTRACTS.md states the other half of the same rule: "no actor other than user/claude may append
  an event that CHANGES candidate_id or status; automation may append OBSERVED events only".

WHY THE SECOND HALF IS THE ONE WITH TEETH
  Read the first half alone and the rule is an enum check: refuse a non-OBSERVED event that has no
  `authorization_ref`. Automation then appends an `OBSERVED` event carrying a DIFFERENT
  `candidate_id`, the enum check passes, the fold moves the deployment onto a new candidate, and
  the human authorization the whole entity exists to require was never asked for. That is exactly
  the mutable `DeploymentAttestation` schemas.json's own Audit P1 replaced this entity to kill --
  reintroduced through the field the replacement left open.

  So `A6` refuses an OBSERVED event that MOVES the candidate. An observation may report what it
  saw -- `attest_state`, `core_revision`, the two fields automation exists to measure -- and may
  not decide what the deployment IS. Moving the candidate is `CANDIDATE_ASSIGNED` /
  `CANDIDATE_REASSIGNED`, which is non-OBSERVED, which needs the ref.

WHAT THIS FILE DOES NOT OWN
  Deployment STATE. `portfolio/DEPLOYMENTS.csv` owns it, one row per magic (PROJECT_STATE section
  0.5), and nothing here copies it. This log is the attestation HISTORY of a (account, magic)
  pair: which candidate it is attested to, and how well the attestation was verified.

  It also does not delete. There is no rewrite path in this module -- the append-only claim of a
  store is worth exactly as much as the absence of a function that could break it (scheduler.py's
  sentence, and it is the right one).

USAGE  tools\\python312\\python.exe _triage/factory_os/attestation.py <command> [args]
       commands: append | fold | verify | --self-test
EXIT   0 = ok  -  1 = a REFUSAL (the reasons are on stdout as JSON)  -  2 = unreadable input
"""

import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import candidate as C                                                      # noqa: E402
import scheduler as S                                                      # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
LOG_REL = 'factory/attestations.jsonl'

EVENT_FIELDS = ('entity', 'event_id', 'account', 'magic', 'event_type', 'at', 'actor',
                'deployment_ref')
OPTIONAL_FIELDS = ('authorization_ref', 'candidate_id', 'attest_state', 'core_revision')
EVENT_TYPES = ('OBSERVED', 'CANDIDATE_ASSIGNED', 'CANDIDATE_REASSIGNED', 'ATTEST_STATE_CHANGED',
               'FROZEN', 'RETIRED')
ACTORS = ('user', 'claude', 'automation')
ATTEST_STATES = ('HASHED', 'PARTIAL', 'FILE_MISSING', 'UNVERIFIED', None)

# The two actors that carry a human decision. `automation` is not one of them, and that is the
# whole entity.
HUMAN_ACTORS = ('user', 'claude')
# The only event type automation may write.
AUTOMATION_EVENT_TYPES = ('OBSERVED',)
# After this, the pair's history is closed.
TERMINAL_EVENT_TYPES = ('RETIRED',)

EVENT_ID_RE = re.compile(r'^ATT-[0-9]{8}-[0-9]{3,}$')


class Refused(Exception):
    """Raised by `append_event`. A TYPE for the reason `candidate.DigestMismatch` is one: a writer
    that returned a problem list is a writer whose caller can append anyway."""


# ---------------------------------------------------------------------------------------------
# THE FOLD -- the current attestation state of one (account, magic), derived, never written
# ---------------------------------------------------------------------------------------------
def pair_key(event):
    """(account, magic) as the log groups it. `magic` is normalized because JSON round-trips it
    through PowerShell, where `990103` and `990103.0` are the same number written twice -- the
    /scrutinize round 2 defect one entity along, and the reason the normalization is imported."""
    return (str(event.get('account')), S.normalize_numbers(event.get('magic')))


def fold(events):
    """{(account, magic): state}. State is what the LAST event that spoke about each field said,
    which is why a field absent from a later event must not erase it -- the same "last non-null"
    rule scheduler.fold's `_field` uses, for the same reason: one attempt, several lines."""
    out = {}
    for ev in events:
        key = pair_key(ev)
        st = out.setdefault(key, {'account': key[0], 'magic': key[1], 'candidate_id': None,
                                  'attest_state': None, 'core_revision': None,
                                  'retired': False, 'frozen': False, 'events': 0})
        st['events'] += 1
        for f in ('candidate_id', 'attest_state', 'core_revision'):
            if ev.get(f) is not None:
                st[f] = ev[f]
        if ev.get('event_type') == 'RETIRED':
            st['retired'] = True
        if ev.get('event_type') == 'FROZEN':
            st['frozen'] = True
    return out


# ---------------------------------------------------------------------------------------------
# THE VALIDATOR. A1-A7, so the cage can be checked for naming each one.
# ---------------------------------------------------------------------------------------------
def validate_event(event, prior_events):
    """Every problem with appending `event` after `prior_events`. Empty list = allowed."""
    problems = []
    if not isinstance(event, dict):
        return ['A1 a DeploymentAttestationEvent must be an object, got %s'
                % type(event).__name__]

    # -- A1 shape.
    missing = [f for f in EVENT_FIELDS if f not in event]
    extra = [f for f in event if f not in EVENT_FIELDS + OPTIONAL_FIELDS]
    if missing or extra:
        problems.append('A1 event missing %s / unknown %s' % (sorted(missing), sorted(extra)))
        return problems
    if event['entity'] != 'DeploymentAttestationEvent':
        problems.append('A1 entity must be DeploymentAttestationEvent, got %r' % event['entity'])
    if not EVENT_ID_RE.match(str(event['event_id'])):
        problems.append('A1 event_id %r does not match %s' % (event['event_id'], EVENT_ID_RE.pattern))
    if event['event_type'] not in EVENT_TYPES:
        problems.append('A1 event_type %r is not one of %s'
                        % (event['event_type'], list(EVENT_TYPES)))
    if event['actor'] not in ACTORS:
        problems.append('A1 actor %r is not one of %s' % (event['actor'], list(ACTORS)))
    if not S.TS_RE.match(str(event['at'])):
        problems.append('A1 at %r is not the one timestamp format %s'
                        % (event['at'], S.TS_RE.pattern))
    magic = S.normalize_numbers(event['magic'])
    if not isinstance(magic, int) or isinstance(magic, bool) or magic < 1:
        problems.append('A1 magic %r is not an integer >= 1' % (event['magic'],))
    if not str(event['account'] or '').strip():
        problems.append('A1 account is required -- an attestation with no account attests nothing')
    if event.get('attest_state') not in ATTEST_STATES:
        problems.append('A1 attest_state %r is not one of %s'
                        % (event.get('attest_state'), list(ATTEST_STATES)))
    if event.get('candidate_id') is not None \
            and not C.CAND_ID_RE.match(str(event['candidate_id'])):
        problems.append('A1 candidate_id %r does not match %s'
                        % (event['candidate_id'], C.CAND_ID_RE.pattern))
    problems.extend('A1 %s' % p
                    for p in C.owner_ref_problems(event['deployment_ref'], 'deployment_ref'))
    if problems:
        # Everything below reads event_type and actor. Judging authorization against an event
        # whose type is not even in the enum produces a second, misleading finding.
        return problems

    # -- A2 the id is unique. An append-only log whose ids repeat cannot be cited: two events
    #    answer to one name and the later reader gets whichever it found first.
    if any(str(p.get('event_id')) == str(event['event_id']) for p in prior_events):
        problems.append('A2 event_id %s is already in the log' % event['event_id'])

    # -- A3 THE ACCEPTANCE. A non-OBSERVED event carries a human authorization ref.
    if event['event_type'] != 'OBSERVED':
        ref = event.get('authorization_ref')
        if not ref:
            problems.append('A3 %s without an authorization_ref -- design 10 permits automation to '
                            'append OBSERVED events and nothing else; every other event type is a '
                            'human decision and must name the record that carries it'
                            % event['event_type'])
        else:
            problems.extend('A3 %s' % p for p in C.owner_ref_problems(ref, 'authorization_ref'))
        if event['actor'] not in HUMAN_ACTORS:
            problems.append('A3 actor %r may not append a %s event (only %s may)'
                            % (event['actor'], event['event_type'], list(HUMAN_ACTORS)))

    # -- A4 the same rule from the actor's side. Stated separately because A3 keys on the EVENT
    #    TYPE and this keys on the ACTOR, and a single rule written once would be satisfied by
    #    either half -- the shape memory `gate-specificity-not-just-sensitivity` is about.
    if event['actor'] == 'automation' and event['event_type'] not in AUTOMATION_EVENT_TYPES:
        problems.append('A4 automation may append %s and nothing else, got %s'
                        % (list(AUTOMATION_EVENT_TYPES), event['event_type']))

    # -- A5 ordering. Append-only means the file order IS the history, so a line timestamped
    #    before the line above it makes the fold depend on which one you believe.
    if prior_events:
        last_at = str(prior_events[-1].get('at') or '')
        if S.TS_RE.match(last_at) and str(event['at']) < last_at:
            problems.append('A5 at %s precedes the last event in the log (%s) -- in an append-only '
                            'store the order of the file is the order of history'
                            % (event['at'], last_at))

    state = fold(prior_events).get(pair_key(event))

    # -- A6 AN OBSERVATION MAY NOT MOVE THE CANDIDATE. See the module docstring: without this,
    #    A3 is an enum check and automation reassigns deployments through the field the entity was
    #    rewritten to protect.
    if event['event_type'] == 'OBSERVED' and event.get('candidate_id') is not None:
        current = (state or {}).get('candidate_id')
        if current is not None and event['candidate_id'] != current:
            problems.append('A6 an OBSERVED event may not move %s|%s from %s to %s -- changing '
                            'which candidate a magic is attested to is CANDIDATE_REASSIGNED, and '
                            'that needs a human authorization_ref'
                            % (event['account'], magic, current, event['candidate_id']))
        elif current is None and event['actor'] == 'automation':
            problems.append('A6 an automation OBSERVED event may not be the first thing to name a '
                            'candidate for %s|%s -- the FIRST assignment is CANDIDATE_ASSIGNED, '
                            'and an unauthorized first write is an unauthorized write'
                            % (event['account'], magic))

    # -- A7 RETIRED closes the pair. A magic is never re-issued once retired (design 4.6: a reused
    #    magic silently re-attributes historical deals), so an attestation after it is either a
    #    mistake or the re-issue the allocator refuses.
    if state and state.get('retired'):
        problems.append('A7 %s|%s was RETIRED -- its attestation history is closed and a magic is '
                        'never re-issued' % (event['account'], magic))
    return problems


# ---------------------------------------------------------------------------------------------
# DISK. Thin, at the edge, append-only -- and with no rewrite path, deliberately.
# ---------------------------------------------------------------------------------------------
def log_path(root=None):
    return os.path.join(root or ROOT, LOG_REL.replace('/', os.sep))


def read_log(path):
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


def append_event(path, event):
    """Validate against the log AS IT IS ON DISK, then append one line.

    Re-reading rather than trusting a list the caller passed in is the point: the caller's copy is
    a snapshot, and A2's uniqueness and A5's ordering are both claims about the file.
    """
    prior = read_log(path)
    problems = validate_event(event, prior)
    if problems:
        raise Refused('; '.join(problems))
    d = os.path.dirname(path)
    if d and not os.path.isdir(d):
        os.makedirs(d)
    with io.open(path, 'a', encoding='utf-8', newline='\n') as fh:
        fh.write(S.canonical(event) + '\n')
    return event['event_id']


def verify_log(events):
    """Re-drive the whole log through the validator, one event at a time, exactly as it was
    written. A store that was appended to correctly re-validates; one that was EDITED does not.

    This is the log's answer to `candidate.read_manifest`: the integrity of an append-only file is
    not a property of any single line, so it is checked by replay rather than by inspection.
    """
    problems = []
    for i, ev in enumerate(events):
        for p in validate_event(ev, events[:i]):
            problems.append('line %d: %s' % (i + 1, p))
    return problems


# ---------------------------------------------------------------------------------------------
# The vocabulary must be the SCHEMA's.
# ---------------------------------------------------------------------------------------------
def assert_vocabulary_matches_schema(root=None):
    path = os.path.join(root or ROOT, '_triage', 'factory_os', 'schemas.json')
    with io.open(path, 'r', encoding='utf-8-sig') as fh:
        schema = json.load(fh)
    d = schema['$defs']['DeploymentAttestationEvent']
    problems = []
    if tuple(sorted(EVENT_FIELDS)) != tuple(sorted(d['required'])):
        problems.append('EVENT_FIELDS %s != schema required %s'
                        % (sorted(EVENT_FIELDS), sorted(d['required'])))
    known = tuple(sorted(EVENT_FIELDS + OPTIONAL_FIELDS))
    if known != tuple(sorted(d['properties'])):
        problems.append('the known field set %s != schema properties %s'
                        % (list(known), sorted(d['properties'])))
    for name, mine, theirs in (('EVENT_TYPES', EVENT_TYPES, d['properties']['event_type']['enum']),
                               ('ACTORS', ACTORS, d['properties']['actor']['enum']),
                               ('ATTEST_STATES', ATTEST_STATES,
                                d['properties']['attest_state']['enum'])):
        if tuple(mine) != tuple(theirs):
            problems.append('%s %s != schema %s' % (name, list(mine), list(theirs)))
    return problems


# ---------------------------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------------------------
def _emit(obj, code=0):
    sys.stdout.write(S.canonical(obj) + '\n')
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
    path = args.get('log') or log_path(args.get('root'))

    if cmd == '--self-test':
        return _selftest()

    if cmd == 'append':
        with io.open(args['event_file'], 'r', encoding='utf-8-sig') as fh:
            event = json.load(fh)
        try:
            eid = append_event(path, event)
        except Refused as exc:
            return _emit({'action': 'REFUSE', 'why': str(exc)}, 1)
        return _emit({'action': 'APPENDED', 'event_id': eid})

    if cmd == 'fold':
        state = fold(read_log(path))
        return _emit({'action': 'FOLD',
                      'pairs': [state[k] for k in sorted(state, key=lambda t: (t[0], str(t[1])))]})

    if cmd == 'verify':
        problems = verify_log(read_log(path))
        if problems:
            return _emit({'action': 'REFUSE', 'why': problems}, 1)
        return _emit({'action': 'VERIFIED', 'events': len(read_log(path))})

    sys.stderr.write('unknown command %r\n' % cmd)
    return 2


def _selftest():
    problems = assert_vocabulary_matches_schema()
    for p in problems:
        sys.stdout.write('  [FAIL] %s\n' % p)
    sys.stdout.write('attestation self-test: %s\n' % ('FAILED' if problems else 'ok'))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
