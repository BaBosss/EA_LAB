"""ORDER-731 -- refuse a commit that would move an ATTESTED pin, BEFORE it lands.

THE DEFECT THIS CLOSES, measured twice in one afternoon on 2026-08-01:

    f4c9fd9f  lane S-2026-08-01-CFGFP appended one dormant row to MASTER_BACKLOG.md
    78a93129  lane S-2026-08-01-OPERATE appended another, an hour after the warning was written

Both commits PASSED the pre-commit gate and turned it RED the moment they landed, because
`F11` (and `F5`) in check_s2a_attestation.py compare the pin against `HEAD:` -- and during a
pre-commit hook HEAD is the PREVIOUS commit. The gate was therefore structurally incapable of
refusing the commit that breaks it, and equally incapable of accepting the commit that repairs
it: restoring MASTER_BACKLOG.md was itself refused, because HEAD still held the wrong blob. It
took an owner-approved `--no-verify` to get out. That is ORDER-674's defect class -- *read what
the commit WILL contain, not what it already contains* -- one layer along.

WHAT THIS FILE IS, AND WHAT IT DELIBERATELY IS NOT.

It is a FRONT GUARD: it reads the INDEX and answers one question -- *after this commit, will a
path that an in-force attestation record pins still hold the pinned blob?* If the answer is no,
the commit is refused here, where refusing is cheap and the author is still holding the change.

It is NOT a change to `F5`/`F11`. Those keep their HEAD semantics, deliberately:

  * `S2A_ATTESTATION_POLICY.md` STATES that semantics ("HEAD's blob at expected_post_state.path"),
    and that policy is a member of `bundle_sha256`. Editing it voids the owner's record and costs
    a signature -- which ORDER-614 rev 2 exists to stop happening for repairs that change no rule.
  * The frozen vector corpus pins F5/F11's behaviour. Changing it there would be a rule change
    wearing the clothes of a bug fix.

So this guard adds a NEW question at a DIFFERENT snapshot rather than moving an existing one.
Nothing in the bundle is touched, and `run_s2a_conformance.py` still reproduces every vector.

WHAT IT DOES NOT PROVE, stated here rather than discovered later (GUARD_SHAPES: "the guard's own
limits are stated IN the guard"):

  1. It does not judge whether the log is VALID. A malformed log yields no in-force record and
     this guard passes -- check_s2a_attestation.py is what reddens that, and it still runs.
     Concretely, the in-force selection shared with that checker applies `R4`-`R7` only, NOT `F1`
     (the bundle digest). So when the bundle has moved, the record is void and `F1` reddens the
     gate, while this guard still enforces that void record's pin. That is STRICTER than the
     checker, never looser -- it can refuse a commit `F11` would not have reached, and it can
     never let through one `F11` would have caught. The strict direction is the safe one for a
     gate, and it is named here rather than left for a reader to derive.
  2. `F5`'s note-existence derivation (`pin_vintage_notes`, N1-N4) is NOT re-derived here. F5
     only fires when D1's pin for that owner is stale; this guard enforces the acknowledged pin
     whenever an in-force record carries one for a path no `expected_post_state` already covers.
     Where D1's pin is NOT stale, that is stricter than F5 by exactly one case: a commit moving
     a path named only by a `stale_pin_acknowledgement` on a fresh pin. The refusal names the
     field it came from, so such a case is diagnosable rather than mysterious.
  3. It predicts ONE commit. It says nothing about a commit that lands afterwards, and nothing
     about `--no-verify`.

THE PIN IS NOW NARROWED, and this guard predicts the narrowed pin. ORDER-731 option A
(owner-ratified) moved `expected_post_state` from a whole-file blob to the approved SECTION,
because MASTER_BACKLOG.md took 30 commits in the 14 days to 2026-08-01 and a whole-file pin on a
board every lane appends to meant ~2 owner signatures a day. The extraction rule is
`S2A_ATTESTATION_POLICY.md` section 4.3.1 and the implementation is imported from
`check_s2a_attestation.extract_section` -- ONE rule, two readers. A section this guard cannot
locate in the staged bytes is P4: refused, never skipped.
"""
from __future__ import annotations

import collections
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_s2a_attestation as att  # noqa: E402
import check_s2a_migration as chk  # noqa: E402
import evidence  # noqa: E402

_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

TAG = '[attested-pin]'


def _index_source():
    """PINNED to the index in every mode, and the pin is the whole point.

    This guard asks what the COMMIT will contain. That question does not change because a human
    typed the command instead of a hook -- the same reasoning `check_s2a_attestation._index_src`
    gives for A7/G5. Following the process mode here would let a manual run answer about the
    working tree and print it as if it were about the commit.
    """
    return evidence.EvidenceSource('index', root=_ROOT)


def staged_paths():
    """The paths this commit carries, added or modified. A DELETION is reported separately by
    `staged_blob` returning None, so the two outcomes never share a branch."""
    rc, out, err = chk._git('-c', 'core.quotePath=false',
                            'diff', '--cached', '--name-only')  # snapshot: index
    if rc != 0:
        raise evidence.ToolFailure('git diff --cached --name-only failed: %s' % err)
    return {p.strip() for p in out.split('\n') if p.strip()}


def staged_blob(path):
    """The oid this commit will record for `path`, or None when the commit does not carry it.

    `git rev-parse :path` reads the INDEX, which is what a partial commit publishes through
    GIT_INDEX_FILE -- so this answers for the temporary index of `git commit -- <paths>` as well
    as for the real one. That is deliberate: the front-guard suite copies the real index for its
    children precisely because a partial commit's own index is otherwise invisible.
    """
    rc, out, _ = chk._git('rev-parse', ':%s' % path)  # snapshot: index
    if rc != 0:
        return None
    return out.strip()


def staged_bytes(path):
    """The CONTENT this commit will record for `path`, as text. Same snapshot as `staged_blob`.

    A ToolFailure is deliberately NOT caught here: it propagates to main() and becomes P3
    (exit 2). "I could not read the staged bytes" and "the section is fine" must not share an
    outcome -- that is the whole reason this guard exists one snapshot earlier.
    """
    return _index_source().read_committed_bytes(path).decode('utf-8')  # snapshot: index


# ORDER-731 option A: a pin is no longer a bare (value, field) pair, because there are now TWO
# kinds of claim and a tuple that does not say which kind it is would be read as the old one --
# which is exactly how a narrowed pin quietly re-widens.
Pin = collections.namedtuple('Pin', 'kind value field section')   # kind: 'blob' | 'section'


def pinned_expectations(src):
    """path -> Pin for every path an IN-FORCE record pins.

    `expected_post_state` wins where both exist: F7 forces its path to equal the record's own
    `current_owner`, so it is the specific claim about the file the decision is for, while the
    acknowledgement is a statement about where the file sat when the record was written.
    """
    rows, _load_problems = att.load_records(src=src)
    d1_text = src.read_committed(chk.MIGRATION_PATH)  # snapshot: index
    d1 = [json.loads(l) for l in d1_text.split('\n') if l.strip()]
    d1_owners = sorted({r['current_owner'] for r in d1})

    # SHARED, not reimplemented. A second hand-rolled "which row is in force" is GUARD_SHAPES
    # shape 5 -- the repair carrying forward the class it repairs. `problems` is discarded on
    # purpose: this guard does not judge the log, it predicts one pin.
    in_force = att.in_force_map(rows, d1_owners, problems=[])

    pins = {}
    for row in in_force.values():
        eps = row.get('expected_post_state')
        if not isinstance(eps, dict) or not eps.get('path'):
            continue
        path = str(eps['path'])
        # ORDER-731 option A: a SECTION pin narrows the claim; the front guard has to predict the
        # SAME narrowed claim or it goes back to refusing every commit that touches the board,
        # which is the trap the CONTROL case exists to catch.
        if eps.get('section') and eps.get('section_sha256') and not eps.get('blob'):
            pins[path] = Pin('section', str(eps['section_sha256']),
                             'expected_post_state.section_sha256', str(eps['section']))
        elif eps.get('blob'):
            pins[path] = Pin('blob', str(eps['blob']), 'expected_post_state.blob', None)
        # A record in NEITHER form pins nothing here. F6 is what reddens it, post-commit; this
        # guard predicts pins and does not judge the log (limit 1 in this file's header).
    # ORDER-731 review M3: an ack pin predicts F5, and F5 can only fire for a path some D1 row
    # PINS (a note needs an owner_ref; no ref, no note, no F2-F5). The checker never validates an
    # ack naming an unpinned path -- note=None skips F3-F5 entirely, so its contents are read by
    # NOBODY but this guard. Enforcing it here therefore predicted a criterion that cannot fire,
    # and the concrete attack it enabled was measured: copy line 8's old ack (naming
    # MASTER_BACKLOG.md, which no D1 row pins since option 2) into a future record -- the checker
    # passes it GREEN and this guard would have resurrected the whole-file toll on the busiest
    # file in the repo. Fidelity to F5's reachability, not a new rule.
    d1_pinned = {p for paths in att.owner_ref_paths(d1).values() for p in paths}
    for row in in_force.values():
        ack = row.get('stale_pin_acknowledgement')
        if isinstance(ack, dict) and ack.get('path') and ack.get('current_blob'):
            path = str(ack['path'])
            if path not in d1_pinned:
                print('%s NOTE: ack pin for %s IGNORED -- no D1 row pins that path, so F5 can '
                      'never fire for it and the ack is validated by nothing (ORDER-731 M3)'
                      % (TAG, path))
                continue
            if path not in pins:
                pins[path] = Pin('blob', str(ack['current_blob']),
                                 'stale_pin_acknowledgement.current_blob', None)
    return pins


def evaluate(pins, staged, resolve=None, read=None):
    """The verdict, as a list of problems.

    `resolve` and `read` are injected so the CAGE can drive every branch without constructing a
    git repo whose index happens to be in the required state. The defaults are the real index
    reads; a test that supplies its own is testing the RULE, and the rule is what P1/P2/P4 are.
    """
    if resolve is None:
        resolve = staged_blob
    if read is None:
        read = staged_bytes
    problems = []
    for path in sorted(pins):
        pin = pins[path]
        if path not in staged:
            # SPECIFICITY: a commit that does not carry the pinned path cannot move it, and a
            # guard that fired anyway would be refusing commits for something they did not do.
            continue
        actual = resolve(path)
        if actual is None:
            problems.append(
                'P2 %s is DELETED by this commit, but the attestation record in force pins it '
                'via %s. A record cannot approve the post-state of a file the commit removes '
                '(F9 refuses exactly this once it lands).' % (path, pin.field))
            continue
        if pin.kind == 'section':
            try:
                text = read(path)
            except (UnicodeDecodeError, ValueError) as exc:
                problems.append(
                    'P4 %s is carried by this commit but its staged bytes are not decodable as '
                    'UTF-8 (%s), so the pinned section %r cannot be located. REFUSED rather than '
                    'skipped.' % (path, exc, pin.section))
                continue
            got, err = att.section_digest(text, pin.section)
            if err:
                problems.append(
                    'P4 %s is carried by this commit but the pinned section %r cannot be located '
                    'in the STAGED bytes: %s. A section that cannot be located is REFUSED, never '
                    'skipped -- that is the one way a narrowed pin could be weaker than the '
                    'whole-file pin it replaces (F13 refuses the same thing once it lands).'
                    % (path, pin.section, err))
            elif got != pin.value:
                problems.append(
                    'P1 %s section %r would land hashing %s, but the attestation record in force '
                    'pins it at %s (%s). This commit passes every other check and turns the S2a '
                    'gate RED the moment it lands. Either restore the approved section, or get the '
                    'owner to re-attest in the SAME commit. Edits OUTSIDE this section are not '
                    'pinned and are not what refused you.'
                    % (path, pin.section, got[:12], pin.value[:12], pin.field))
            continue
        if pin.value.upper() == 'MISSING':
            problems.append(
                'P2 %s is carried by this commit, but the record in force pins it via %s to the '
                'literal MISSING -- it approves a state in which that path is ABSENT.'
                % (path, pin.field))
        elif actual != pin.value:
            problems.append(
                'P1 %s would land at blob %s, but the attestation record in force pins it at %s '
                '(%s). This commit passes every other check and turns the S2a gate RED the moment '
                'it lands -- and the commit that would repair it is refused too, because F5/F11 '
                'read HEAD. Either restore the pinned bytes, or get the owner to re-attest in the '
                'SAME commit.' % (path, actual[:12], pin.value[:12], pin.field))
    return problems


def main(argv):
    os.chdir(_ROOT)
    src = _index_source()
    print(src.marker('attested-pin-staged'))
    try:
        staged = staged_paths()
        if not staged:
            print('%s nothing staged -- pass (no-op)' % TAG)
            return 0
        if not src.exists_committed(att.ATTESTATION_PATH):
            # Not a failure: an empty or absent log means no decision is recorded, which is the
            # same thing check_s2a_attestation says. It is printed rather than silent so "no
            # pins" and "the guard did not run" cannot look alike.
            print('%s no attestation log in this commit -- no pin to protect' % TAG)
            return 0
        pins = pinned_expectations(src)
    except Exception as exc:  # noqa: BLE001 -- tooling failure is its own outcome, never a verdict
        print('%s P3 TOOLING: cannot read the pins from the index: %s' % (TAG, exc))
        return 2

    if not pins:
        print('%s the log carries no blob pin -- nothing to predict' % TAG)
        return 0

    touched = sorted(p for p in pins if p in staged)
    print('%s %d pinned path(s) (%d section-scoped); %d carried by this commit%s'
          % (TAG, len(pins), sum(1 for p in pins.values() if p.kind == 'section'),
             len(touched), (': ' + ', '.join(touched)) if touched else ''))

    problems = evaluate(pins, staged)
    if problems:
        print('')
        for p in problems:
            print('  -> %s' % p)
        print('\n%s %d PROBLEM(S) -- refused HERE rather than after it lands' % (TAG, len(problems)))
        return 1
    print('%s every pinned path this commit carries still holds its pinned blob' % TAG)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
