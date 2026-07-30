"""
check_s2a_signoff.py - ORDER-602 A + D: the sign-off half of ORDER-600, kept OUT of the proposal.

THE DEADLOCK THIS REMOVES  (Codex audit 7 MAJOR 2)
  `signoff_state` used to live on each D1 row, and `check_s2a_migration.py` C2 REFUSES `APPROVED`
  outright -- a guard written to stop the proposal's own author self-approving. But that made approval
  impossible for the owner too: `SIGNOFF_STATES` had to be relaxed, and because `run_s2a_gate.py`
  step 1 requires D1 to byte-match its generator, the generator emitting `PROPOSED` had to be edited
  as well, and D1 and D2 regenerated. Recording a "yes" therefore meant changing **the evidence, the
  acceptance rule and the generator in one commit** -- after which nothing could distinguish
  "the owner approved" from "the proposal author weakened the guard".

  The fix is not a looser guard, it is a different SHAPE: the proposal stays immutable and decisions
  go in their own append-only log, keyed by the digest of the proposal being signed. The owner appends
  one line. No guard is touched, and C2 can keep refusing `APPROVED` inside D1 forever.

WHAT IT ASSERTS
  S1  every line is well-formed and carries the required fields
  S2  `proposal_sha256` matches the CURRENT D1 -- a decision is bound to the bytes it was made on,
      so editing the proposal after a signature invalidates that signature rather than inheriting it
  S3  exactly one CURRENT decision per distinct `current_owner` (append-only: the last line wins,
      earlier ones stay visible) -- this is the owner-level rule C6 was named for and never had
  S4  every `current_owner` in the log is a real owner in D1
  S5  `REFUSED` carries a non-empty reason
  S6  ORDER-602 D: at the sign-off boundary, pin vintage BLOCKS. A decision may not be recorded
      against a proposal whose cited owner blobs have moved, unless that row explicitly acknowledges
      the stale pin. Advisory while drafting, blocking when signing -- the two are different moments
      and this is the one where a rotted citation actually costs something.

USAGE  tools\\python312\\python.exe _triage/factory_os/check_s2a_signoff.py [--template]
EXIT   0 = the log is valid (it may legitimately be empty) - 1 = a decision is malformed or stale
"""
import hashlib
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_s2a_migration as chk  # noqa: E402

SIGNOFF_PATH = '_triage/factory_os/s2a_signoff.jsonl'
DECISIONS = ('APPROVED', 'REFUSED')
REQUIRED = ('proposal_sha256', 'current_owner', 'decision', 'signer', 'decided_at', 'reason')


def proposal_digest():
    """sha256 of D1's bytes -- what a signature is bound to."""
    with io.open(chk.MIGRATION_PATH, 'rb') as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def load_signoffs():
    rows, problems = [], []
    if not os.path.exists(SIGNOFF_PATH):
        return rows, problems
    for n, line in enumerate(io.open(SIGNOFF_PATH, encoding='utf-8'), 1):
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except ValueError as exc:
            problems.append('%s:%d is not valid JSON: %s' % (SIGNOFF_PATH, n, exc))
            continue
        if '_comment' in obj and len(obj) == 1:
            continue                       # the header note, not a decision
        obj['_line'] = n
        rows.append(obj)
    return rows, problems


def check(rows, problems, digest, d1_owners, vintage_notes):
    # /scrutinize ORDER-602 H4: this used to be `if owner in note` over the note PROSE, so a note about
    # `docs/MASTER_BACKLOG.md.bak` would have blocked signing `MASTER_BACKLOG.md`. Notes are structured
    # now and this matches on the pinned PATH exactly.
    stale_owners = {n['path'] for n in vintage_notes if isinstance(n, dict) and n.get('path')}

    current = {}
    for r in rows:
        n = r.get('_line')
        missing = [f for f in REQUIRED if not str(r.get(f) or '').strip()]
        if missing:
            problems.append('S1 line %s is missing %s' % (n, missing))
            continue
        if r['decision'] not in DECISIONS:
            problems.append('S1 line %s has decision=%r, not one of %s'
                            % (n, r['decision'], list(DECISIONS)))
            continue
        if r['proposal_sha256'] != digest:
            problems.append('S2 line %s signs proposal %s but D1 is now %s -- the proposal changed '
                            'after this decision, so the decision does not carry over. Re-sign the '
                            'current bytes.' % (n, r['proposal_sha256'][:12], digest[:12]))
            continue
        if r['current_owner'] not in d1_owners:
            problems.append('S4 line %s decides for %r, which is not a current_owner in D1'
                            % (n, r['current_owner']))
            continue
        # /scrutinize ORDER-602 H3: an `EMBEDDED:<Parent>` pseudo-owner was accepted as signable
        # because it IS a current_owner value in D1. But an embedded fact owns no file and moves if
        # and only if its parent moves, so a decision recorded against it is not a decision anyone
        # can act on -- and it would show as "signed" in the tally, overstating how much is settled.
        if r['current_owner'].startswith('EMBEDDED:'):
            problems.append('S4 line %s decides for %r, but an EMBEDDED fact owns no file -- it '
                            'follows its parent. Record the decision against the parent\'s owner '
                            'instead.' % (n, r['current_owner']))
            continue
        if r['decision'] == 'REFUSED' and not str(r.get('reason') or '').strip():
            problems.append('S5 line %s is REFUSED with no reason' % n)
        # ORDER-602 D -- blocking here, advisory during drafting.
        if r['current_owner'] in stale_owners and not r.get('stale_pin_acknowledged'):
            problems.append('S6 line %s signs for %r while that owner\'s pin is STALE. During '
                            'drafting a moved pin is an advisory; at the sign-off boundary it is not '
                            '-- the row\'s cited evidence no longer describes the file being signed '
                            'about. Re-pin (a plain gen_s2a_migration.py run), or set '
                            '"stale_pin_acknowledged": true to record that you signed anyway.'
                            % (n, r['current_owner']))
        current[r['current_owner']] = r
    return current


def main(argv):
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)
    if not os.path.exists(chk.MIGRATION_PATH):
        print('[ABORT] %s does not exist; there is no proposal to sign.' % chk.MIGRATION_PATH)
        return 2
    digest = proposal_digest()
    d1 = [json.loads(l) for l in io.open(chk.MIGRATION_PATH, encoding='utf-8') if l.strip()]
    d1_owners = sorted({r['current_owner'] for r in d1})

    if '--template' in argv:
        print('# Append ONE line like this to %s. Nothing else changes -- no guard, no generator.' % SIGNOFF_PATH)
        print(json.dumps({
            'proposal_sha256': digest,
            'current_owner': 'MASTER_BACKLOG.md',
            'decision': 'APPROVED',
            'signer': 'user (Boss)',
            'decided_at': '<YYYY-MM-DDTHH:MM>',
            'reason': '<why - required for REFUSED, good practice for APPROVED>',
        }, sort_keys=True))
        return 0

    print('=== ORDER-602 A: S2a sign-off log ===')
    print('proposal : %s' % chk.MIGRATION_PATH)
    print('digest   : %s' % digest)
    print('log      : %s\n' % SIGNOFF_PATH)

    rows, problems = load_signoffs()
    vintage = chk.pin_vintage_notes(d1)
    current = check(rows, problems, digest, d1_owners, vintage)

    undecided = [o for o in d1_owners if o not in current]
    for owner in d1_owners:
        r = current.get(owner)
        print('  [%s] %-46s %s' % ('SIGNED ' if r else 'pending', owner,
                                   ('%s by %s (line %s)' % (r['decision'], r['signer'], r['_line']))
                                   if r else ''))
    print('\n  %d of %d owner(s) decided - %d still pending'
          % (len(current), len(d1_owners), len(undecided)))
    if vintage:
        print('  %d pin-vintage note(s) outstanding (blocking only for the owners they name)'
              % len(vintage))

    if problems:
        print('')
        for p in problems:
            print('  -> %s' % p)
        print('\n=== %d PROBLEM(S) - the sign-off log is not valid ===' % len(problems))
        return 1
    print('\n=== SIGN-OFF LOG VALID ===')
    print('    An empty or partial log is NOT an error: it means the owner has not decided yet.')
    print('    This never reports ORDER-600 complete; it reports what has been decided, by whom,')
    print('    and against which bytes.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
