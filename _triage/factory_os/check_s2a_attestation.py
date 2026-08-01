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

WHAT IT ASSERTS -- OWNED BY THE POLICY, NOT BY THIS DOCSTRING (ORDER-614 rev 2)
  The criteria, their semantics, their scope (record-intrinsic vs in-force vs global) and their
  evaluation order live in `S2A_ATTESTATION_POLICY.md`, version `s2a-attestation/1`, and the
  frozen corpus `S2A_ATTESTATION_VECTORS.jsonl` is what they DO. This file is the current
  IMPLEMENTATION of that policy; `run_s2a_conformance.py` is what holds it to the policy. A
  prose copy of the criteria here would be a second copy that drifts -- the earlier version of
  this header listed A1-A7 and had already drifted from the code beneath it (A5 was
  unreachable, and the header did not know).
  Criterion ids emitted: R1-R7 (record-intrinsic) - F1-F11 (in-force) - G5/G7 (append-only) -
  see the policy for G0-G8, N1-N4, B1-B4, X1.

USAGE  tools\\python312\\python.exe _triage/factory_os/check_s2a_attestation.py [--template]
EXIT   0 = the log is valid (it may legitimately be empty) - 1 = a record is malformed or stale
"""
import hashlib
import io
import json
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_s2a_migration as chk  # noqa: E402
import evidence  # noqa: E402

_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_SRC = [None]


def _src():
    """The ONE mode-driven source for this process (design section 3).

    MODE = `EA_LAB_EVIDENCE`, defaulting to **worktree** -- `EvidenceSource.for_run()`'s own
    default, and the right one here, unlike check_coverage_transfer where an explicit --worktree
    flag had already fixed the default at index. This checker is run by hand constantly
    (`run_s2a_gate.py`, `--template`), and those runs are exactly the "signer looking at the
    files" case: worktree bytes, with marker() saying so. Under the hook the tier exports
    `index` and the same code judges the commit.
    """
    if _SRC[0] is None:
        _SRC[0] = evidence.EvidenceSource.for_run(root=_ROOT)
    return _SRC[0]


def _index_src():
    """PINNED to the index, in every mode, and used by exactly one rule.

    `A7`/`G5` asks "is the committed log still a prefix of what is STAGED". That is a claim about
    the COMMIT whether a human typed the command or a hook did, so making it follow the process
    mode would hand manual runs back the defect Codex round 2 filed as a P0 -- A7 reading the
    working tree, so staging a deletion and restoring the working copy reported 0 problems. The
    mode is not a preference here; the rule names its snapshot itself.
    """
    return evidence.EvidenceSource('index', root=_ROOT)

ATTESTATION_PATH = '_triage/factory_os/s2a_attestations.jsonl'
DECISIONS = ('APPROVED', 'REFUSED')
REQUIRED = ('bundle_sha256', 'current_owner', 'decision', 'signer', 'decided_at', 'reason')

# audit 8 BLOCKER 2: the record binds the whole reviewed bundle, not just D1. If the document the
# owner read, or the rules that decide what the decision MEANS, change afterwards, the record stops
# matching and must be re-made.
# ORDER-614 rev 2 (owner-ratified 2026-07-31): the bundle binds WHAT THE CRITERIA MEAN and
# WHAT THEY DO -- never HOW they are executed. This file is therefore OUT of its own bundle:
# repairing it no longer voids the record that authorised the previous repair, which had cost
# five signatures in two sessions, four of them for repairs that changed no rule. What holds
# the implementation to the policy is the conformance corpus, run by run_s2a_conformance.py.
#
#   * gen_s2a_migration.py is OUT: it produced D1, but D1 ITSELF is bound, so the generator's
#     bytes cannot change what the owner read without changing D1 too.
#   * check_s2a_migration.py STAYS IN, deliberately (OPEN-2 resolved the conservative way):
#     this policy absorbed only its pin_vintage_notes semantics (N1-N4). Its OWN criteria --
#     what D1's acceptance MEANS -- have no policy-and-vectors replacement yet, and dropping
#     it would bind D1's bytes while unbinding D1's meaning. It leaves when it gets the same
#     treatment, and not before.
BUNDLE = (
    '_triage/factory_os/s2a_migration.jsonl',               # D1 - the data
    '_triage/factory_os/s2a_coverage_reconciliation.json',  # C8's evidence
    '_triage/factory_os/S2A_OWNERSHIP_MIGRATION.md',        # D2 - what the owner actually reads
    '_triage/factory_os/check_s2a_migration.py',            # what D1's acceptance MEANS
    '_triage/factory_os/S2A_ATTESTATION_POLICY.md',         # what THESE criteria mean
    '_triage/factory_os/S2A_ATTESTATION_VECTORS.jsonl',     # what these criteria DO
)

_D1_ROWS = []          # set by main(); the D1 rows, for A6's recompute

# KEYED ON THE SOURCE OBJECT, and that is the whole design of this cache rather than a detail.
#
# In index mode the digest costs six `git show` spawns, and the suites call it once per case --
# measured at +14s on run_contract_binding_tests, which the tier budget refused (92.5s against
# 90.0s). A cache is the right answer; a cache keyed on NOTHING would be the wrong one, and this
# repo has the receipt: ORDER-670 migration 4/9 nearly shipped `_CLASSIFICATION_CACHE` keyed on
# the root alone, so the first call would have decided for both vintages -- a guard caching the
# value it watches (memory `drift-guard-regenerating-against-head`).
#
# Keying on the SOURCE means two sources that read different bytes get different answers, which
# is exactly what the ATTACK case in run_s2a_attestation_tests requires: it builds a second
# EvidenceSource over a tampered index and demands a DIFFERENT digest, while the SPECIFICITY case
# demands the same digest when index and worktree agree. Those two cases fail if this cache ever
# collapses them, so the cache cannot go wrong silently.
#
# The dict holds a reference to each source, which is also why `id()` is not used: an id can be
# reused after garbage collection, and a cache that can answer for a dead object is a cache that
# can answer for the wrong one.
_DIGEST_CACHE = {}


def bundle_digest():
    """The fingerprint a record binds itself to, read through the process source.

    ORDER-670 migration: this read the DISK unconditionally, under the reasoning "the digest
    describes the bytes the signer is LOOKING AT". True of a manual run and false of the gate --
    and the gap between them was an A7 at the highest-ceremony target in the repo: stage a change
    to a bundle file, restore the worktree copy, and the digest recomputes to the OLD value, so
    the owner's record still validates and THE COMMIT LANDS A BUNDLE CHANGE NO ATTESTATION COVERS.

    The mode is what separates the two readings, which is what it is for. Manual runs
    (`run_s2a_gate.py`, `--template`) stay worktree and still describe what a signer sees; under
    the hook the same code fingerprints what the commit contains.

    BYTES, through read_committed_bytes: a digest over decoded-and-renormalised text would
    fingerprint something other than the file. The CRLF fold stays HERE, where it is visible and
    where it has always been, so the digest value is unchanged for every existing record.
    """
    src = _src()
    if src in _DIGEST_CACHE:
        return _DIGEST_CACHE[src]
    h = hashlib.sha256()
    for path in BUNDLE:
        h.update(path.encode('utf-8'))
        h.update(b'\0')
        h.update(hashlib.sha256(src.read_committed_bytes(path).replace(b'\r\n', b'\n')).digest())
    _DIGEST_CACHE[src] = h.hexdigest()
    return _DIGEST_CACHE[src]


BLOB_OID = re.compile(r'^[0-9a-f]{40}$')


def _is_blob_oid(value):
    return bool(BLOB_OID.match(str(value or '')))


def _is_blob_at_head(path):
    """True only when HEAD:path is a FILE. A directory resolves to a tree id, which git happily
    returns and which says nothing about content -- Codex round 2 used that to pass D2."""
    rc, out, _ = chk._git('cat-file', '-t', '%s:%s' % (chk.head_oid(), path))  # snapshot: HEAD
    return rc == 0 and out.strip() in ('blob', b'blob')


def load_records(src=None):
    """ORDER-731 added `src`. The DEFAULT is unchanged -- the process source, so every existing
    caller reads exactly the bytes it read before. A caller that is predicting what a COMMIT
    will contain must pin the index whatever mode the process is in (the same reasoning as
    `_index_src`), and passing it explicitly is how that caller says so."""
    if src is None:
        src = _src()
    rows, problems = [], []
    if os.path.isabs(ATTESTATION_PATH):
        # A FIXTURE'S OWN TEMP FILE (category C), and the split is by KIND of input rather than
        # by mode -- the same rule run_guard_shape_lint._read states for absolute paths. Both
        # suites that drive the REAL loader write their lines to a tempfile and point
        # ATTESTATION_PATH at it, deliberately, so the loader is the loader instead of being
        # reimplemented. Such a path is in no index, and read_committed would refuse it: correct
        # behaviour, wrong question. Caught by the tier the first time this ran in index mode --
        # every vector reported "no decision in force" because the fixture was invisible.
        if not os.path.isfile(ATTESTATION_PATH):
            return rows, problems
        with io.open(ATTESTATION_PATH, encoding='utf-8') as fh:  # snapshot: not-a-judged-input -- fixture temp file
            text = fh.read()
    else:
        # Existence is a judged fact too: "the log is gone" and "the log is gone FROM THE COMMIT"
        # are different, and asking the disk while reading the commit is the mixed pair one line
        # apart.
        if not src.exists_committed(ATTESTATION_PATH):
            return rows, problems
        # Through the process source: a decision APPENDED but not staged is not a decision this
        # commit records, and treating it as in force would let the gate pass on an approval the
        # commit does not contain. Manual runs still read the disk, which is where an owner has
        # just written; G5 below is the rule that holds the two vintages together.
        text = src.read_committed(ATTESTATION_PATH)
    for n, line in enumerate(text.split('\n'), 1):
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except ValueError as exc:
            # R1 (was unprefixed -- OPEN-8: a message with no criterion id cannot be matched by
            # the conformance runner, so the checker could stop naming this rule silently).
            problems.append('R1 line %d of %s is not valid JSON: %s'
                            % (n, ATTESTATION_PATH, exc))
            continue
        if not isinstance(obj, dict):
            # Codex round 2, Spec 8: `obj['_line'] = n` on a string raised TypeError, so a
            # malformed line ended the run in a traceback instead of the conformance exit 1 this
            # file promises. "The tool broke" and "the file is wrong" must not share an outcome.
            problems.append('R2 line %s is a %s, not an object -- every record must be a JSON '
                            'object' % (n, type(obj).__name__))
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
        # Codex round 2, Standards 1 (P0): this used to read the WORKING TREE. Stage a deletion of
        # an earlier line, restore the working copy, and A7 reported 0 problems -- a commit could
        # rewrite append-only history while the pre-commit gate stayed green. That is ORDER-545's
        # defect sitting inside the guard built to prevent exactly this, which is the third time
        # in this lineage a check has judged bytes that are not the ones being committed.
        #
        # The INDEX is what a commit contains. Fall back to the working tree only when the path is
        # untracked -- there is nothing staged to judge then -- and say which was read either way,
        # because a guard that does not name its snapshot cannot have its green interpreted.
        # BYTES, not text: A7 is a byte-prefix rule, so `chk._git` (which decodes) is the wrong
        # tool here and the first attempt crashed on `str.replace(b'\r\n', ...)`.
        #
        # ORDER-670 migration: the hand-rolled `git show :path` is now
        # `read_committed_bytes` on an INDEX-PINNED source -- see _index_src() for why this one
        # rule does not follow the process mode. The untracked fallback is kept and is now
        # explicit rather than a bare else: there is genuinely nothing staged to judge, and the
        # reader refuses that case (correctly, for a category-A read) which is the wrong answer
        # to THIS question.
        try:
            working = _index_src().read_committed_bytes(path)
        except evidence.ToolFailure as exc:
            rc2, _, _ = chk._git('ls-files', '--error-unmatch', path)
            if rc2 == 0:
                problems.append('G7 %s is tracked but could not be read from the index (%s). '
                                'Append-only cannot be judged against bytes that are not the ones '
                                'being committed.' % (path, exc))
                return
            # NOT IN THE INDEX AT ALL -- and the old code read the WORKING TREE here, described as
            # "reached ONLY for an untracked log (nothing staged to judge)". That description was
            # true of the path and false of the situation. Control only reaches this line when
            # `committed` is non-empty: a few lines up, a log with no HEAD blob RETURNS. So the
            # state is "HEAD has the log, the index does not" -- the commit DELETES it. Falling
            # back to the disk then compares HEAD against a working copy the commit is not
            # keeping, and an append-only guard can pass while append-only history is removed.
            #
            # The staged content of an absent path is EMPTY, so saying so lets the existing
            # prefix rule reach the right answer by itself: b'' cannot start with a non-empty
            # committed prefix => G5, the criterion that already means exactly this. No new
            # branch, no new criterion id, and no criterion invented without a fixture.
            working = b''
    now = working.replace(b'\r\n', b'\n')
    if not now.startswith(committed):
        problems.append('G5 %s is not append-only: the version committed at HEAD is no longer a '
                        'prefix of what is STAGED, so a previously recorded decision was edited or '
                        'removed rather than superseded by a new line.' % path)


def eligible_records(rows, d1_owners, problems):
    """R4/R5/R6/R7 -- the intrinsic checks that decide whether a row may be IN FORCE.

    EXTRACTED (ORDER-731) rather than copied. `check_attested_pin_staged.py` has to answer
    "which record is in force" to predict a pin, and a second hand-rolled copy of this
    predicate is GUARD_SHAPES shape 5 exactly: the repair carries the class forward. There is
    one predicate, in one place, and the conformance corpus already exercises it -- if this
    extraction changed behaviour, the vectors go red rather than a reader having to notice.

    `problems` is appended to, never read. A caller that is NOT judging the log's validity
    passes a throwaway list: it wants the SELECTION, and the log's own verdict belongs to
    check_s2a_attestation's exit code, not to it.
    """
    eligible = []
    for r in rows:
        n = r.get('_line')
        missing = [f for f in REQUIRED if not str(r.get(f) or '').strip()]
        if missing:
            problems.append('R4 line %s is missing %s' % (n, missing))
            continue
        if r['decision'] not in DECISIONS:
            problems.append('R5 line %s has decision=%r, not one of %s'
                            % (n, r['decision'], list(DECISIONS)))
            continue
        if r['current_owner'] not in d1_owners:
            problems.append('R6 line %s decides for %r, which is not a current_owner in D1'
                            % (n, r['current_owner']))
            continue
        if r['current_owner'].startswith('EMBEDDED:'):
            # R7 is separate from R6 because EMBEDDED:* values DO appear in D1 and pass R6.
            problems.append('R7 line %s decides for %r, but an EMBEDDED fact owns no file -- it '
                            'follows its parent. Record the decision against the parent\'s owner.'
                            % (n, r['current_owner']))
            continue
        eligible.append(r)
    return eligible


def in_force_map(rows, d1_owners, problems=None):
    """current_owner -> the row IN FORCE, by the same predicate `check()` uses.

    Last eligible row per owner wins, which is what this log's header has always promised and
    what ORDER-613 D1 made true in code. An INELIGIBLE row can no longer displace the decision
    in force -- that hole is the one /scrutinize found, and it is closed here once for both
    readers rather than once per reader.
    """
    if problems is None:
        problems = []
    latest = {}
    for r in eligible_records(rows, d1_owners, problems):
        latest[r['current_owner']] = r
    return latest


def check(rows, problems, digest, d1_owners, vintage_notes):
    stale = {n['path']: n for n in vintage_notes if isinstance(n, dict) and n.get('path')}
    # ORDER-613 D1, in TWO PASSES. /scrutinize found the one-pass version had a real hole and a
    # comment that asserted the opposite of the truth.
    #
    # The first version built `latest` from EVERY row, including rows that fail A1. So appending one
    # deliberately malformed line -- `{"signer": ""}` was enough -- made that line "in force", which
    # demoted the REAL current decision to "superseded" and let it skip A2 and A6 entirely. Probed:
    # a row carrying a wrong bundle AND a stale pin was reported for neither. The log still went red
    # on the A1 problem, so it was not a green bypass, but `current` and `latest` genuinely
    # disagreed about which row was in force -- while the comment claimed "stated once, so the two
    # cannot disagree". A comment that is false about the code beside it is worse than no comment.
    #
    # Both now come from ONE list, built by ONE predicate: a row is ELIGIBLE if it survives the
    # intrinsic checks. A malformed trailing line can no longer displace the decision in force.
    # ORDER-731: that predicate now lives in `eligible_records` so the staged-pin front guard
    # shares it instead of owning a second copy that can drift.
    eligible = eligible_records(rows, d1_owners, problems)

    latest = {}
    for r in eligible:
        latest[r['current_owner']] = r

    current = {}
    for r in eligible:
        n = r.get('_line')
        # ORDER-613 D1, EXTENDED after running it: A2 had the same defect A6 did, and narrowing
        # only A6 was not enough -- the log stayed red on lines 2 and 3, made under the previous
        # bundle, which append-only means can never be corrected.
        #
        # THE RULE, stated once so the next check lands on the right side of it:
        #   * a check about the RECORD ITSELF (A1 well-formedness, A4 attributability, A5 a reason)
        #     applies to EVERY row -- those were true when written or the row should not exist;
        #   * a check about the record's relationship to CURRENT EXTERNAL STATE (A2 the bundle,
        #     A6 the pin, A8 the expected post-state) applies ONLY to the row in force.
        # Superseded records are history. Demanding that history keep matching today's bytes is
        # demanding that history be rewritten, and in an append-only file that is not merely wrong,
        # it is impossible -- so the artifact could never survive its own evolution.
        in_force = r is latest.get(r['current_owner'])
        if in_force and r['bundle_sha256'] != digest:
            problems.append('F1 line %s attests bundle %s but the current bundle is %s -- the '
                            'bound policy, corpus, D1, D2 or the reconciliation changed after this '
                            'record, so it no longer describes what is on disk. Re-make it against '
                            'the current bytes.'
                            % (n, str(r['bundle_sha256'])[:12], digest[:12]))
            continue
        # (R6/R7 live in pass 1: eligibility must be decided before `latest` is, or a row that
        #  fails them could still displace the decision in force.)
        #
        # A5 ("REFUSED with no reason") is DELETED, not renamed -- OPEN-3, ratified. It was
        # UNREACHABLE: `reason` is in REQUIRED, so a blank reason fails R4 first and this branch
        # could never fire; the suite case named for it was asserting R4's message. Making
        # `reason` conditionally required instead would change WHAT IS DEMANDED, which E4
        # forbids. Deleting an unreachable branch changes nothing observable. R8 stays in the
        # policy as DISPUTED with a PROVISIONAL vector, so the history of the criterion is not
        # erased -- but the code stops carrying a guard that reads like coverage.
        # ORDER-613 D2: a record may declare the state the approved action is expected to PRODUCE.
        # Without it, an acknowledgement is a blanket exemption -- "these bytes moved, fine" -- and
        # cannot distinguish the approved change from any other change that happens to arrive
        # afterwards. With it, the record is a claim about a SPECIFIC post-state, and the claim is
        # recomputed here rather than believed.
        eps = r.get('expected_post_state') if in_force else None
        if eps is not None:
            if not isinstance(eps, dict) or not eps.get('path') or not eps.get('blob'):
                problems.append('F6 line %s has expected_post_state that is not an object naming '
                                '{path, blob}' % n)
            # Codex round 2, Standards 3 + Spec 3: this bound ANY path to ANY value. A record
            # deciding for MASTER_BACKLOG.md could bind AGENT_TASKBOARD.md and pass; a
            # {path: "NO_SUCH_PATH", blob: "MISSING"} pair passed; and a directory path resolved
            # to its TREE oid and passed. So it never enforced "changed INTO the approved state" --
            # it enforced "some path is at some value", which is not a claim about this decision.
            elif eps['path'] != r['current_owner']:
                problems.append(
                    'F7 line %s decides for %r but its expected_post_state binds %r. A record may '
                    'only make a claim about the state of the file it decides for -- binding '
                    'anything else lets the approved target sit in a state nobody approved while '
                    'this criterion stays green.' % (n, r['current_owner'], eps['path']))
            elif str(eps['blob']).upper() == 'MISSING' or not _is_blob_oid(eps['blob']):
                problems.append(
                    'F8 line %s expects %s at %r, which is not a 40-hex blob id. "MISSING" and a '
                    'tree id are both accepted by git and neither is a statement about the CONTENT '
                    'this decision approved.' % (n, eps['path'], eps['blob']))
            else:
                rc3, live3, _ = chk._rev_parse_cached('%s:%s' % (chk.head_oid(), eps['path']))
                if rc3 != 0:
                    problems.append(
                        'F9 line %s expects %s at blob %s, but that path does not exist at HEAD. A '
                        'record cannot approve the post-state of a file that is not there.'
                        % (n, eps['path'], str(eps['blob'])[:12]))
                elif not _is_blob_at_head(eps['path']):
                    problems.append(
                        'F10 line %s binds %s, which resolves to a TREE at HEAD, not a file. A '
                        'directory has no content this decision could have approved.'
                        % (n, eps['path']))
                elif live3 != eps['blob']:
                    problems.append(
                        'F11 line %s expects %s to be at blob %s after the action it approves, but '
                        'HEAD has %s. The record describes a change that did not happen, or a '
                        'different one happened -- either way this is not the state that was '
                        'approved.' % (n, eps['path'], str(eps['blob'])[:12], str(live3)[:12]))

        # ORDER-613 D1: the stale-pin rule now judges ONLY the CURRENT record per owner.
        # It used to run for every row, including superseded ones -- while this file's own header
        # promises "the latest line per current_owner wins". Because the log is append-only, an
        # earlier row could never acquire the acknowledgement it was being failed for, so a single
        # stale pin made that owner's history permanently unrepairable and the artifact could not
        # be returned to green by any legal action. Superseded rows stay in the file and stay
        # printed; they are history, not live claims. What is DEMANDED of the current row is
        # unchanged -- this narrows which row is judged, never what it must satisfy.
        note = stale.get(r['current_owner']) if in_force else None
        if note:
            ack = r.get('stale_pin_acknowledgement')
            # audit 8 MAJOR 5: this was `not row.get('stale_pin_acknowledged')`, so the STRING
            # "false" -- which reads as a refusal to acknowledge -- granted the exemption. Boolean
            # identity now, plus a structured record whose contents are recomputed below.
            if r.get('stale_pin_acknowledged') is not True or not isinstance(ack, dict):
                problems.append('F2 line %s attests for %r whose pin is STALE. Set '
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
                    problems.append('F3 line %s acknowledges path %r but the stale pin is on %r'
                                    % (n, ack.get('path'), note['path']))
                # OPEN-5, ratified: the `pinned and` guard that used to sit on the next branch
                # was DEAD -- under N1/N2 a note can only exist for a path D1 pins, so `pinned`
                # was always truthy on every reachable input. A guard that cannot fire reads as
                # tolerance for a case that cannot occur, which is worse than its absence.
                elif ack.get('pinned_blob') != pinned:
                    problems.append('F4 line %s acknowledges pinned_blob %r but D1 pins %r'
                                    % (n, ack.get('pinned_blob'), pinned))
                elif ack.get('current_blob') != want_current:
                    problems.append('F5 line %s acknowledges current_blob %r but HEAD has %r'
                                    % (n, ack.get('current_blob'), want_current))
        current[r['current_owner']] = r

    # Codex round 2, Spec 9: when the in-force row failed a check it `continue`d before reaching
    # the line above, so `current` still reported the SUPERSEDED row as the decision in force. The
    # printed diagnostic then pointed a reader at a record that is not the one being judged, which
    # is worse than printing nothing -- it invites fixing the wrong line.
    #
    # `latest` already knows which row is in force. Anything else in `current` for that owner is a
    # leftover, and the honest report is "the record in force did not verify", not an older one.
    for owner, row in latest.items():
        if current.get(owner) is not row:
            current[owner] = {'_line': row.get('_line'), 'decision': 'UNVERIFIED',
                              'current_owner': owner,
                              '_note': 'the record in force (line %s) did not pass; the previous '
                                       'record is NOT in force and is not reported as such'
                                       % row.get('_line')}
    return current


def main(argv):
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)
    if not _src().exists_committed(chk.MIGRATION_PATH):
        print('[ABORT] %s does not exist; there is no proposal to attest to.' % chk.MIGRATION_PATH)
        return 2
    digest = bundle_digest()
    # D1, through the process source. It is the proposal the records attest TO, so it must be the
    # same vintage as the digest that fingerprints it -- two moments in one verdict is A2, and
    # here it would mean recomputing A6's owner set from a D1 the commit does not contain.
    d1 = [json.loads(l) for l in _src().read_committed(chk.MIGRATION_PATH).split('\n') if l.strip()]
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
    print('bundle : %s (D1 + D2 + reconciliation + migration checker + POLICY + VECTORS -- '
          'the implementation is NOT a member, per ORDER-614 rev 2)' % digest[:16])
    print('log    : %s\n' % ATTESTATION_PATH)

    rows, problems = load_records()
    check_append_only(problems)
    vintage = chk.pin_vintage_notes(d1)
    current = check(rows, problems, digest, d1_owners, vintage)

    # RESCOPED (audit 8 section 2): ORDER-600 blocks on ONE decision, not on all 23 owners.
    coverage = current.get('MASTER_BACKLOG.md')
    # `.get`, because the in-force entry may be G3's UNVERIFIED placeholder, which carries no
    # signer by design -- it reports that the record in force did not verify, and pretending it
    # had a signer would put words in a row that failed. Found live: this line crashed with
    # KeyError the first time an F1-failed row was in force, i.e. the exact situation a bundle
    # change creates, on the day the bundle changed.
    print('  THE decision ORDER-600 blocks on:')
    print('    MASTER_BACKLOG.md (Coverage edge) -> %s'
          % ('%s by %s (line %s)%s' % (coverage['decision'], coverage.get('signer', '<n/a>'),
                                       coverage['_line'],
                                       ' -- ' + coverage['_note'] if coverage.get('_note') else '')
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
