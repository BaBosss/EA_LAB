"""
check_s2a_attestation.py - ORDER-602 A, RESCOPED after Codex audit 8.

WHAT THIS IS, AND WHAT IT IS NOT
  It is an **attestation log**: an append-only record that a decision about the S2a proposal was
  written down, bound to the exact bytes it was written about.

  It is NOT proof that the owner made that decision, and it must never be described as one. Audit 8
  put it plainly: nothing here can "distinguish an owner action from an author typing the owner's
  name". That is not a gap to be closed by adding fields -- MEASURED: this repository commits under a
  single git identity (`patip`), the same identity Claude commits under, so authorship cannot separate
  them either. A stronger `authorization_ref` would record a claim about provenance, not establish it.

  So the previous name (`check_s2a_signoff`, "sign-off") overclaimed, and the artifact is RENAMED
  rather than reinforced. The user chose this scope deliberately over building a 23-owner sign-off
  subsystem that would end at the same limit.

WHAT IT STILL BUYS, WHICH IS THE REASON IT EXISTS
  The deadlock audit 7 found is gone. Recording a decision no longer requires editing the evidence,
  the acceptance rule and the generator in one commit -- `check_s2a_migration.py` C2 keeps refusing
  `APPROVED` inside D1, and a decision is written here instead. Approving costs one appended line.

WHAT IT ASSERTS
  A1  every line is well-formed and carries the required fields
  A2  `bundle_sha256` matches the CURRENT reviewed bundle -- D1, D2, the coverage reconciliation and
      BOTH validators. Audit 8 BLOCKER 2: hashing D1 alone let the reviewed document or the
      acceptance rules change while the record still read as current.
  A3  exactly one CURRENT decision per distinct `current_owner` (append-only: last line wins)
  A4  `current_owner` is a real owner in D1, and not an `EMBEDDED:` pseudo-owner
  A5  `REFUSED` carries a non-empty reason
  A6  a stale pin BLOCKS the record unless it carries a STRUCTURED acknowledgement naming the pinned
      and current blob, recomputed here. Audit 8 MAJOR 5: generic truthiness meant the string
      "false" granted the exemption.
  A7  the log is APPEND-ONLY against HEAD -- the committed version must be a byte prefix of this one.
      Audit 8 BLOCKER 3: "append-only" was prose, and deleting an earlier line stayed green.

USAGE  tools\\python312\\python.exe _triage/factory_os/check_s2a_attestation.py [--template]
EXIT   0 = the log is valid (it may legitimately be empty) - 1 = a record is malformed or stale
"""
import hashlib
import io
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_s2a_migration as chk  # noqa: E402

ATTESTATION_PATH = '_triage/factory_os/s2a_attestations.jsonl'
DECISIONS = ('APPROVED', 'REFUSED')
REQUIRED = ('bundle_sha256', 'current_owner', 'decision', 'signer', 'decided_at', 'reason')

# audit 8 BLOCKER 2: the record binds the whole reviewed bundle, not just D1. If the document the
# owner read, or the rules that decide what the decision MEANS, change afterwards, the record stops
# matching and must be re-made.
BUNDLE = (
    '_triage/factory_os/s2a_migration.jsonl',               # D1 - the data
    '_triage/factory_os/s2a_coverage_reconciliation.json',  # C8's evidence
    '_triage/factory_os/S2A_OWNERSHIP_MIGRATION.md',        # D2 - what the owner actually reads
    '_triage/factory_os/gen_s2a_migration.py',              # what produced D1
    '_triage/factory_os/check_s2a_migration.py',            # what the acceptance MEANS
    '_triage/factory_os/check_s2a_attestation.py',          # ...and what this record means
)

_D1_ROWS = []          # set by main(); the D1 rows, for A6's recompute


def bundle_digest():
    h = hashlib.sha256()
    for path in BUNDLE:
        h.update(path.encode('utf-8'))
        h.update(b'\0')
        with io.open(path, 'rb') as fh:
            h.update(hashlib.sha256(fh.read().replace(b'\r\n', b'\n')).digest())
    return h.hexdigest()


def load_records():
    rows, problems = [], []
    if not os.path.exists(ATTESTATION_PATH):
        return rows, problems
    for n, line in enumerate(io.open(ATTESTATION_PATH, encoding='utf-8'), 1):
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except ValueError as exc:
            problems.append('%s:%d is not valid JSON: %s' % (ATTESTATION_PATH, n, exc))
            continue
        if '_comment' in obj and len(obj) == 1:
            continue
        obj['_line'] = n
        rows.append(obj)
    return rows, problems


def check_append_only(problems, path=None, committed=None, working=None):
    """A7 -- the committed log must be a byte PREFIX of the working copy.

    audit 8 BLOCKER 3. The header said "never edit or delete a previous line" and nothing enforced it,
    so removing an earlier REFUSED left the file green. A prefix comparison against HEAD is the
    cheapest real enforcement: appending passes, editing or deleting anything already committed fails.
    """
    path = path or ATTESTATION_PATH
    # `committed`/`working` are injectable so the RULE can be tested without depending on this
    # particular file already being in HEAD. The first version read both from git, which created a
    # bootstrap deadlock: the suite failed because the log was not yet committed, and the log could
    # not be committed because the suite failed. It also repeated a mistake already made twice here --
    # a control whose outcome depends on mutable repo state rather than on the logic under test.
    if committed is None:
        rc, oid, _ = chk._git('rev-parse', '--verify', 'HEAD:%s' % path)
        if rc != 0:
            return                              # not committed yet; no history to protect
        p = subprocess.run(['git', 'cat-file', 'blob', oid], capture_output=True)
        if p.returncode != 0:
            return
        committed = p.stdout
    committed = committed.replace(b'\r\n', b'\n')
    if working is None:
        with io.open(path, 'rb') as fh:
            working = fh.read()
    now = working.replace(b'\r\n', b'\n')
    if not now.startswith(committed):
        problems.append('A7 %s is not append-only: the version committed at HEAD is no longer a '
                        'prefix of this file, so a previously recorded decision was edited or '
                        'removed rather than superseded by a new line.' % path)


def check(rows, problems, digest, d1_owners, vintage_notes):
    stale = {n['path']: n for n in vintage_notes if isinstance(n, dict) and n.get('path')}
    current = {}
    for r in rows:
        n = r.get('_line')
        missing = [f for f in REQUIRED if not str(r.get(f) or '').strip()]
        if missing:
            problems.append('A1 line %s is missing %s' % (n, missing))
            continue
        if r['decision'] not in DECISIONS:
            problems.append('A1 line %s has decision=%r, not one of %s'
                            % (n, r['decision'], list(DECISIONS)))
            continue
        if r['bundle_sha256'] != digest:
            problems.append('A2 line %s attests bundle %s but the current bundle is %s -- D1, D2, '
                            'the reconciliation or a validator changed after this record, so it no '
                            'longer describes what is on disk. Re-make it against the current bytes.'
                            % (n, str(r['bundle_sha256'])[:12], digest[:12]))
            continue
        if r['current_owner'] not in d1_owners:
            problems.append('A4 line %s decides for %r, which is not a current_owner in D1'
                            % (n, r['current_owner']))
            continue
        if r['current_owner'].startswith('EMBEDDED:'):
            problems.append('A4 line %s decides for %r, but an EMBEDDED fact owns no file -- it '
                            'follows its parent. Record the decision against the parent\'s owner.'
                            % (n, r['current_owner']))
            continue
        if r['decision'] == 'REFUSED' and not str(r.get('reason') or '').strip():
            problems.append('A5 line %s is REFUSED with no reason' % n)
        note = stale.get(r['current_owner'])
        if note:
            ack = r.get('stale_pin_acknowledgement')
            # audit 8 MAJOR 5: this was `not row.get('stale_pin_acknowledged')`, so the STRING
            # "false" -- which reads as a refusal to acknowledge -- granted the exemption. Boolean
            # identity now, plus a structured record whose contents are recomputed below.
            if r.get('stale_pin_acknowledged') is not True or not isinstance(ack, dict):
                problems.append('A6 line %s attests for %r whose pin is STALE. Set '
                                '"stale_pin_acknowledged": true (JSON boolean, not a string) AND a '
                                '"stale_pin_acknowledgement" object naming {path, pinned_blob, '
                                'current_blob}, or re-pin with gen_s2a_migration.py.'
                                % (n, r['current_owner']))
            else:
                head = chk.head_oid()
                rc2, live, _ = chk._rev_parse_cached('%s:%s' % (head, note['path']))
                want_current = live if rc2 == 0 else 'MISSING'
                pinned = next((row['owner_ref']['blob_oid'] for row in _D1_ROWS
                               if row.get('owner_ref')
                               and row['owner_ref']['path'] == note['path']), None)
                if ack.get('path') != note['path']:
                    problems.append('A6 line %s acknowledges path %r but the stale pin is on %r'
                                    % (n, ack.get('path'), note['path']))
                elif pinned and ack.get('pinned_blob') != pinned:
                    problems.append('A6 line %s acknowledges pinned_blob %r but D1 pins %r'
                                    % (n, ack.get('pinned_blob'), pinned))
                elif ack.get('current_blob') != want_current:
                    problems.append('A6 line %s acknowledges current_blob %r but HEAD has %r'
                                    % (n, ack.get('current_blob'), want_current))
        current[r['current_owner']] = r
    return current


def main(argv):
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)
    if not os.path.exists(chk.MIGRATION_PATH):
        print('[ABORT] %s does not exist; there is no proposal to attest to.' % chk.MIGRATION_PATH)
        return 2
    digest = bundle_digest()
    d1 = [json.loads(l) for l in io.open(chk.MIGRATION_PATH, encoding='utf-8') if l.strip()]
    _D1_ROWS[:] = d1
    d1_owners = sorted({r['current_owner'] for r in d1})

    if '--template' in argv:
        print('# Append ONE line to %s. Nothing else changes -- no guard, no generator, no D1 edit.'
              % ATTESTATION_PATH)
        print(json.dumps({
            'bundle_sha256': digest,
            'current_owner': 'MASTER_BACKLOG.md',
            'decision': 'APPROVED',
            'signer': 'user (Boss)',
            'decided_at': '<YYYY-MM-DDTHH:MM>',
            'reason': '<why - required for REFUSED, good practice for APPROVED>',
        }, sort_keys=True))
        return 0

    print('=== ORDER-602 A (rescoped): S2a ATTESTATION log ===')
    print('NOTE: this records that a decision was WRITTEN DOWN against specific bytes.')
    print('      It does NOT prove who made it -- this repo commits under one git identity, so')
    print('      nothing here separates the owner from any other writer. Do not cite it as a')
    print('      signature. (Codex audit 8.)')
    print('bundle : %s (D1 + D2 + reconciliation + generator + both validators)' % digest[:16])
    print('log    : %s\n' % ATTESTATION_PATH)

    rows, problems = load_records()
    check_append_only(problems)
    vintage = chk.pin_vintage_notes(d1)
    current = check(rows, problems, digest, d1_owners, vintage)

    # RESCOPED (audit 8 section 2): ORDER-600 blocks on ONE decision, not on all 23 owners.
    coverage = current.get('MASTER_BACKLOG.md')
    print('  THE decision ORDER-600 blocks on:')
    print('    MASTER_BACKLOG.md (Coverage edge) -> %s'
          % ('%s by %s (line %s)' % (coverage['decision'], coverage['signer'], coverage['_line'])
             if coverage else 'NOT YET RECORDED'))
    others = [o for o in d1_owners if o in current and o != 'MASTER_BACKLOG.md']
    print('  %d other owner(s) recorded, %d not yet -- none of them block ORDER-600'
          % (len(others), len(d1_owners) - len(current)))
    if vintage:
        print('  %d pin-vintage note(s); blocking only for the owners they name' % len(vintage))

    if problems:
        print('')
        for p in problems:
            print('  -> %s' % p)
        print('\n=== %d PROBLEM(S) - the attestation log is not valid ===' % len(problems))
        return 1
    print('\n=== ATTESTATION LOG VALID ===')
    print('    An empty or partial log is NOT an error: it means no decision is recorded yet.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
