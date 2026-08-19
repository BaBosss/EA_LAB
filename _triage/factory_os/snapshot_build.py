# -*- coding: utf-8 -*-
"""snapshot_build.py -- ORDER-612 (slice S4). Builder input -> validated v5 snapshot, atomically.

WHAT THIS ADDS THAT snapshot_validator.py DELIBERATELY DID NOT
  snapshot_validator proves INTERNAL CONSISTENCY: that a document's stored verdict is the verdict
  its own evidence produces. Its own docstring names the limit -- Codex audit 6 pointed every
  source row at a nonexistent drive with `mtime: 2099-01-01`, `age_hours: 0`, `read_ok: true`, and
  it was accepted, because every fact being recomputed was itself supplied by the document.

  This module closes that: `read_ok`, `sha256`, `mtime` and `age_hours` are DERIVED by stat-ing and
  hashing the real file, and a builder claim that CONTRADICTS the disk is REFUSED rather than
  overwritten. Overwritten and honoured look identical afterwards -- that is the same argument
  `_refuse_supplied_answer` is written on, applied one level down, to the evidence instead of the
  answer.

  The reconciliation counts are derived too, and that was NOT true in the first version of this
  file -- it said so in this paragraph and treated it as an acceptable limit. Probing it on
  2026-07-31 took one line: a builder input declaring `discovered: 0` and every other count 0 was
  accepted and produced `reconciliation_clear: true`, while the real boards reconcile to
  discovered=312 / unclassified=30 / duplicates=6. Half the verdict was derived and half was
  typed, and the typed half is the half that says the work is finished. `reconcile()` below is
  now the single producer, and `build_document` takes a REQUIRED `reconciler` argument with two
  legal values, exactly like the schema gate.

  What is STILL not proven, stated so it is a limit and not a surprise: `reconcile()` reads the
  two taskboards and factory/coverage.jsonl from the WORKING TREE, so it describes the tree as it
  is, not as a commit would contain it. And the six category buckets come from a closed
  STATUS_CATEGORY allowlist -- a status verb it does not know becomes `unclassified`, which makes
  the verdict false with a named reason rather than being guessed into a bucket. That is the
  intended failure direction; it is not the same as understanding the board.

THE IDENTITY DECISION (ORDER-612, engineering, recorded in the order)
  A source row carries BOTH:
    `path` -- PHYSICAL identity. What gets hashed and stat-ed, what `mtime`/`age_hours` describe,
              what this module resolves. A row without it cannot be re-verified, so a row without
              it is REFUSED rather than skipped.
    `name` -- LOGICAL identity. What `meta.mandatory_sources` enumerates and what the
              reconciliation joins on. A registry keyed on a path would report a MISSING MANDATORY
              SOURCE for a rename, which is a false alarm about the fleet caused by a file move.
  There are NO independently calculated totals anywhere here: every count the verdict consumes
  comes from the join in snapshot_validator.compute, never from a parallel tally kept in step.

ATOMICITY (C5)
  build_file() writes the candidate to a temp file IN THE DESTINATION DIRECTORY, validates it, and
  only then os.replace()s it over the canonical path. os.replace is atomic on Windows and POSIX
  for same-volume renames, which is why the temp file is a sibling and not in %TEMP%. Any failure
  before the replace leaves the previous file byte-for-byte unchanged -- there is a fixture that
  hashes it before and after a forced mid-build failure.

USAGE
  tools\\python312\\python.exe _triage/factory_os/snapshot_build.py build <builder-input.json> <out.json>
TESTS
  tools\\python312\\python.exe _triage/factory_os/run_snapshot_s4_tests.py
"""
import collections
import copy
import datetime
import glob
import hashlib
import io
import json
import os
import re
import sys
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import evidence as evd           # noqa: E402
import registry as reg           # noqa: E402
import snapshot_validator as sv  # noqa: E402

REPO_ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))

# The fields this module OWNS. A builder may state them; it may not state them differently from
# what the disk says. Kept as a tuple rather than three `if`s so the refusal message, the schema
# note and the fixtures all read from one list.
#
# `age_hours` is NOT in this list and that is deliberate: it is a function of (mtime, now), mtime
# is pinned by exact comparison above it, and the builder's clock is a different instant from this
# module's. Comparing it would produce refusals caused by the gap between two lines of a pipeline.
# It is overwritten, and it cannot launder a lie, because the mtime it derives from cannot.
DERIVED_EVIDENCE_FIELDS = ('read_ok', 'sha256', 'mtime')


def _stat_evidence(abs_path, now):
    """-> {read_ok, sha256, mtime, age_hours} for one real file. Never raises for a bad path.

    `read_ok: False` covers absent, not-a-file, and unreadable alike at this level -- the
    DISTINCTION between "not there" and "there but unreadable" is carried by the reason codes
    MANDATORY_SOURCE_MISSING vs MANDATORY_SOURCE_UNREADABLE, which are decided by the registry
    join in snapshot_validator, not here. This function only answers "could I read these bytes".
    """
    try:
        if not os.path.isfile(abs_path):
            return {'read_ok': False, 'sha256': None, 'mtime': None, 'age_hours': None}
        # ORDER-670, T5 (design section 5): THIS WAS A SECOND IMPLEMENTATION OF `evidence.observe`.
        # One open handle, fstat before and after the read, refuse on disagreement -- the exact
        # mechanism `observe()` exists to own, reproduced here under a different name because the
        # reader had a category-B entry point and nothing pointed at it. Two implementations of one
        # rule is the failure this whole repo keeps paying for; the design's own table names the
        # test this collapse was supposed to make possible: "collapse the split (make observe read
        # the index) => the monitor suite goes RED. A split nothing tests gets collapsed by the
        # next editor." `observe()` was never actually wired to a real caller, so that red half
        # could not fire as written -- it fires HERE instead, on the reimplementation, which is the
        # more direct proof: this function's own fixtures (run_snapshot_s4_tests, the mid-read
        # rewrite case) now exercise `observe()`'s refusal rather than a parallel copy of it.
        #
        # category B, DELIBERATELY, per evidence.py's own header: an index blob has no mtime that
        # means anything, and a build source may be written by MT5, not committed at all.
        # TWO FAILURE MODES, TWO ANSWERS -- and collapsing them is a regression this repair
        # shipped in its first form. `observe()` raises for BOTH "it moved under me" and "I could
        # not open it", and ToolFailure is not an OSError, so the outer `except (IOError, OSError)`
        # below stopped catching the second one: every permission error became a hard REFUSAL of
        # the whole build, carrying a message that blamed a mid-read mutation. That broke this
        # function's own contract ("Never raises for a bad path", four lines up) and erased the
        # MISSING/UNREADABLE distinction its docstring exists to explain -- collateral outside the
        # slice the repair was written staring at (GUARD_SHAPES shape 5).
        try:
            raw, st = evd.observe(abs_path)
        except evd.ObservationUnstable as exc:
            sv._refuse(
                'the file at %r was modified while it was being read: mtime/size differ between '
                'the two stats of the SAME open handle (%s). Refused -- the hash and the '
                'timestamp would describe different moments, and a stale sensor labelled fresh is '
                'the one error this pipeline exists to make impossible.' % (abs_path, exc))
        except evd.ToolFailure:
            # "there but unreadable" -- the same answer this function has always given, which the
            # registry join turns into MANDATORY_SOURCE_UNREADABLE rather than a build refusal.
            return {'read_ok': False, 'sha256': None, 'mtime': None, 'age_hours': None}
        digest = hashlib.sha256(raw).hexdigest()
        mtime = datetime.datetime.fromtimestamp(st.st_mtime)
        age = (now - mtime).total_seconds() / 3600.0
        return {'read_ok': True,
                'sha256': digest,
                'mtime': mtime.isoformat(timespec='seconds'),
                # A file written a moment in the future (clock skew, a network share) must not
                # produce a NEGATIVE age that compares fresh against every bar by accident. It is
                # clamped to 0 and that is a deliberate, stated choice: "newer than now" is not a
                # staleness finding.
                # FOUR decimals, not one. A blind audit measured a real age of 1.04h being
                # stored as 1.0 and then compared <= a 1.0h bar, so a source that was over the bar
                # was published FRESH. The persisted number is what every later consumer -- and
                # the verifier's own recomputation -- decides from, so it has to carry enough
                # precision to survive the comparison. Renderers round for humans; the store does
                # not round for the arithmetic.
                'age_hours': round(max(age, 0.0), 4)}
    except (IOError, OSError):
        return {'read_ok': False, 'sha256': None, 'mtime': None, 'age_hours': None}


def _resolve(rel_path, root):
    """Repo-relative -> absolute, refusing anything that leaves the repo.

    An absolute path or a `..` escape in a source row means the snapshot is describing a file
    outside the tree the verdict is about. That is refused rather than resolved: a sensor row is
    only re-verifiable by a later reader if the later reader can find the same bytes from the same
    root, and `D:\\somewhere\\else` is not that.
    """
    if not isinstance(rel_path, str) or not rel_path.strip():
        sv._refuse('a source row has no usable `path`. `path` is the PHYSICAL identity in v5 -- '
                   'a row without one cannot be re-verified by any later reader, so it is refused '
                   'rather than carried as an unverifiable claim.')
    if os.path.isabs(rel_path) or ':' in rel_path:
        sv._refuse('source path %r is absolute. Source paths are repo-relative so the evidence '
                   'can be re-derived from the same root by a different machine.' % rel_path)
    # REALPATH, not abspath. A blind audit created `root/escape` as a junction to an outside
    # directory and resolved `escape/outside.txt` through it: the lexical check saw a path spelled
    # under the root and accepted it, and _stat_evidence then reported read_ok=True for a file
    # that is not in this tree at all. Containment expressed as a string prefix is containment of
    # STRINGS. os.path.realpath resolves junctions, symlinks and `..` to the real target, so the
    # question becomes WHERE THE BYTES ARE rather than how the path was written.
    abs_path = os.path.realpath(os.path.join(root, rel_path.replace('\\', os.sep)))
    root_abs = os.path.realpath(root)
    if os.path.normcase(abs_path) != os.path.normcase(root_abs) and \
            not os.path.normcase(abs_path).startswith(os.path.normcase(root_abs) + os.sep):
        sv._refuse('source path %r resolves to %r, which is outside the repository root %r. '
                   'Refused: a snapshot describes the state of THIS tree, and a junction or a '
                   'symlink pointing out of it is still pointing out of it.'
                   % (rel_path, abs_path, root_abs))
    return abs_path


# THE CANONICAL name -> path BINDING. A blind audit supplied name="deployments_inventory" with
# path="unrelated.txt", pointed it at a fresh unrelated file, and got fresh=True /
# reconciliation_clear=True with no reasons: the SAME builder supplied both the trusted logical
# label and an arbitrary physical path, so nothing bound the two. The identity decision this order
# made -- `name` logical, `path` physical -- is only worth anything if something other than the
# builder decides which physical file a logical name means.
#
# These three are the paths scripts/control_room_snapshot.ps1 already hardcodes; making the binding
# canonical and CHECKED closes the hole without inventing a policy. A name not listed here is
# unconstrained and says so, so adding a fourth source is a deliberate edit HERE rather than a
# silent widening.
MANDATORY_SOURCE_PATHS = {
    'deployments_inventory': 'portfolio/DEPLOYMENTS.csv',
    'live_dashboard': 'portfolio/LIVE_DASHBOARD.html',
    'attestation_map': 'portfolio/ATTESTATION_MAP.csv',
}


def derive_source_evidence(doc, root=None, now=None):
    """Recompute every source row's evidence from disk, IN PLACE. Refuses a contradicted claim.

    This is the authenticity half of C4. It runs on the BUILDER INPUT, before the verdict is
    computed, so the verdict is computed from derived facts and never from claimed ones.
    """
    root = REPO_ROOT if root is None else root
    now = datetime.datetime.now() if now is None else now
    meta = doc.get('meta')
    # F2, found by an independent review and reproduced end to end: S6 stopped the builder choosing
    # WHICH FILE a logical name means, and left it choosing WHICH NAMES COUNT. A builder input whose
    # meta.mandatory_sources listed only `live_dashboard` BUILT CLEAN -- deployments_inventory and
    # attestation_map simply vanished, no MANDATORY_SOURCE_MISSING, and the document then verified
    # against its own evidence forever after. On a day the boards reconcile that is
    # reconciliation_clear: true with two of three fleet sensors unconsulted.
    #
    # The S6 repair pinned the counter-example's axis (name -> path) instead of the invariant
    # (the builder does not decide what must be present). Shape 5, in the fix for shape 5.
    # SCOPED TO THE REAL TREE, and the scoping was itself a shape-5 lesson: the first version of
    # this check applied to EVERY root and broke every synthetic fixture in the suite on its first
    # run -- collateral far outside the counter-example's slice, caught only because those fixtures
    # already existed. MANDATORY_SOURCE_PATHS names THIS repository's three sensors; a caller that
    # passes a different root has declared a different tree, where those names mean nothing.
    #
    # It cannot buy permission: the production path (control_room_snapshot.ps1 -> the CLI with no
    # root argument) always resolves to REPO_ROOT, so the real snapshot is always constrained.
    if isinstance(meta, dict) and os.path.normcase(os.path.abspath(root)) ==             os.path.normcase(REPO_ROOT):
        declared = set(meta.get('mandatory_sources') or [])
        absent = sorted(set(MANDATORY_SOURCE_PATHS) - declared)
        if absent:
            sv._refuse(
                'meta.mandatory_sources omits %s. The registry of what MUST be present is not '
                'the builder to shrink: a name missing from it is not reported missing, it is not '
                'reported at all, and the verdict is computed as though that sensor were never '
                'expected.' % ', '.join(repr(a) for a in absent))
    if not isinstance(meta, dict) or not isinstance(meta.get('sources'), list):
        sv._refuse('meta.sources is absent or not an array -- there is no evidence to derive')
    for row in meta['sources']:
        if not isinstance(row, dict):
            sv._refuse('a meta.sources entry is %r, not an object' % (row,))
        expected = MANDATORY_SOURCE_PATHS.get(row.get('name'))
        if expected is not None:
            declared = str(row.get('path') or '').replace('\\', '/')
            if declared != expected:
                sv._refuse(
                    'meta.sources[%r].path is %r but the canonical path for that logical '
                    'name is %r. Refused: `name` is the logical identity the registry and '
                    'the reconciliation join on, and if the builder chooses which file it '
                    'points at then the name carries no information at all -- a blind audit '
                    'pointed deployments_inventory at an unrelated fresh file and got '
                    'reconciliation_clear=true with no reasons.'
                    % (row.get('name'), row.get('path'), expected))
        abs_path = _resolve(row.get('path'), root)
        truth = _stat_evidence(abs_path, now)
        for field in DERIVED_EVIDENCE_FIELDS:
            claimed = row.get(field)
            if claimed is not None and claimed != truth[field]:
                sv._refuse(
                    'meta.sources[%r].%s claims %r but the file at %r is %r. This is REFUSED, not '
                    'overwritten: a builder that can assert evidence about a file it did not read '
                    'is the exact defect Codex audit 6 demonstrated (every source row pointed at a '
                    'nonexistent drive with read_ok:true and the document verified clean). '
                    'Overwritten and honoured look identical afterwards.'
                    % (row.get('name'), field, claimed, row.get('path'), truth[field]))
        row.update(truth)

    # `fresh` is derived here too, for the same reason and by the SAME function the verifier uses
    # on read (sv.derive_fresh). Doing it here rather than leaving it to build_snapshot is not
    # duplication: the schema requires `fresh` to be a boolean, so a builder that honestly declines
    # to claim it would be rejected by the gate before build_snapshot ever ran.
    f = sv.facts_of(doc)
    for row in meta['sources']:
        derived = sv.derive_fresh(f, row)
        claimed = row.get('fresh')
        if derived is not None and claimed is not None and claimed is not bool(derived):
            sv._refuse(
                'meta.sources[%r].fresh claims %r but age_hours=%r against stale_bar_hours=%r '
                'derives %r. Refused for the same reason as read_ok/sha256/mtime.'
                % (row.get('name'), claimed, row.get('age_hours'), f.stale_bar_hours, derived))
        # An UNREADABLE source has no derivable freshness (age_hours is null). The schema still
        # requires a boolean, so it is recorded False -- the fail-closed direction -- and the fact
        # that actually matters is carried by MANDATORY_SOURCE_UNREADABLE, which is a different
        # code from MANDATORY_SOURCE_STALE precisely so the two never collapse.
        row['fresh'] = bool(derived) if derived is not None else False
    return doc


def compute_build_id(doc):
    """A digest over WHAT WAS READ, not over when. Same sources at the same bytes -> same id.

    Deliberately excludes generated_at and the verdict: two builds of the same evidence should
    carry the same build_id so a reader can tell "rebuilt" from "changed". git_head IS included --
    the same source bytes at a different commit describe a different tree.
    """
    meta = doc.get('meta') or {}
    h = hashlib.sha256()
    h.update(str(meta.get('git_head') or '').encode('utf-8'))
    h.update(b'\0')
    for name in sorted(meta.get('mandatory_sources') or []):
        h.update(('m:' + str(name)).encode('utf-8'))
        h.update(b'\0')
    for row in sorted(meta.get('sources') or [], key=lambda r: str(r.get('name'))):
        # `mtime` and `fresh` are in the digest and `age_hours` is NOT, deliberately. A blind
        # audit found age 1h and age 31h producing the same id while one verdict was clear and the
        # other MANDATORY_SOURCE_STALE -- freshness drives the verdict, so it is part of what was
        # read. But `age_hours` changes on every single build by construction, so hashing it would
        # make build_id differ on every rebuild and destroy the one question it answers ("rebuilt,
        # or changed?"). `fresh` is the verdict-driving fact and it is stable while the file is.
        h.update(('%s|%s|%s|%s|%s|%s' % (row.get('name'), row.get('path'), row.get('sha256'),
                                         row.get('read_ok'), row.get('mtime'),
                                         row.get('fresh'))).encode('utf-8'))
        h.update(b'\0')
    # BLIND AUDIT 2026-07-31, reproduced: this function calls itself "a digest over WHAT WAS READ"
    # and did not hash the reconciliation at all, so `discovered: 312` and `discovered: 0` produced
    # the SAME build_id at the same git_head. A reader using build_id to tell "rebuilt" from
    # "changed" would have been told nothing changed while the entire order/coverage picture had.
    # The reconciliation IS read -- from two taskboards and the coverage store -- so it belongs in
    # the digest by this function's own definition.
    h.update(json.dumps(meta.get('reconciliation') or {}, sort_keys=True).encode('utf-8'))
    h.update(b'\0')
    return h.hexdigest()[:16]


class _ClaimedReconciliation(object):
    """Named sentinel, so declining to derive the counts reads as a decision and greps."""

    def __repr__(self):
        return 'RECONCILIATION_NOT_DERIVED'


RECONCILIATION_NOT_DERIVED = _ClaimedReconciliation()

_UNSET = object()


def _resolve_reconciler(reconciler):
    """Accept ONLY `reconcile` or the named sentinel. Same rule, same reason, as _resolve_gate.

    FOUND BY PROBING THIS MODULE, 2026-07-31 (ORDER-612 round 1). C4 made the SOURCE ROWS
    authentic -- read_ok/sha256/mtime/fresh derived from disk, a contradicting claim refused.
    The reconciliation counts were left as builder claims, and the probe was one line: a builder
    input declaring `discovered: 0, categorized: 0, ...everything 0` was accepted and produced
    `reconciliation_clear: true`, while the real repo reconciles to discovered=312,
    unclassified=30, duplicates=6. Half the verdict was derived and half was typed, and the
    typed half is the half that says the work is done.

    An OPTIONAL reconciler would reintroduce exactly what Codex audit 6 removed from the schema
    gate ("a boundary whose caller chooses whether to check is not a boundary"), so this is a
    required argument with two legal values, one of them named after what it gives up.
    """
    if reconciler is RECONCILIATION_NOT_DERIVED or reconciler is reconcile:
        return reconciler
    if reconciler is _UNSET:
        raise TypeError(
            'build_document/build_file require an explicit `reconciler`: snapshot_build.reconcile '
            'to DERIVE the counts from the boards and refuse a contradicting claim, or the named '
            'sentinel snapshot_build.RECONCILIATION_NOT_DERIVED to accept the builder\'s claim. '
            'There is no default, because a default is how half a verdict went unauthenticated.')
    raise TypeError(
        'reconciler must be snapshot_build.reconcile or the named sentinel '
        'snapshot_build.RECONCILIATION_NOT_DERIVED, not %r.' % (reconciler,))


def _apply_reconciliation(inp, reconciler, root):
    """Derive meta.reconciliation, refusing a claim the boards do not support."""
    if _resolve_reconciler(reconciler) is RECONCILIATION_NOT_DERIVED:
        return
    truth = reconcile(root=root)
    claimed = inp['meta'].get('reconciliation')
    if claimed is not None and claimed != truth:
        sv._refuse(
            'meta.reconciliation does not match what the boards actually reconcile to. REFUSED, '
            'not overwritten, for the same reason a contradicted source row is: overwritten and '
            'honoured look identical afterwards.\n  claimed: %s\n  derived: %s'
            % (json.dumps(claimed, sort_keys=True), json.dumps(truth, sort_keys=True)))
    inp['meta']['reconciliation'] = truth


def _apply_git_head(inp, root):
    """Derive meta.git_head from the tree, refusing a claim that disagrees or cannot be checked.

    F3: `git_head` was the last typed field in a document whose every other fact graduated to
    derived this slice -- and it is the one that makes `build_id` answer "rebuilt or changed".
    A fabricated `git_head: "deadbeef"` was accepted, persisted, and hashed into the identity.

    If the root is not a git worktree, the value cannot be checked, so a SUPPLIED one is refused
    rather than trusted: "I cannot verify this" is not a licence to publish it. An input that
    claims nothing is fine and simply carries no git_head.
    """
    import subprocess
    base = REPO_ROOT if root is None else root
    meta = inp.get('meta')
    if not isinstance(meta, dict):
        return
    try:
        p = subprocess.run(['git', '-C', base, 'rev-parse', '--short', 'HEAD'],
                           capture_output=True, text=True)
        derived = p.stdout.strip() if p.returncode == 0 else None
    except (OSError, ValueError):
        derived = None
    claimed = meta.get('git_head')
    if derived is None:
        if claimed:
            sv._refuse('meta.git_head claims %r but %r is not a git worktree this process can '
                       'query, so the claim cannot be checked. Refused rather than trusted.'
                       % (claimed, base))
        return
    if claimed and claimed != derived:
        sv._refuse('meta.git_head claims %r but the tree at %r is at %r. Refused: git_head is '
                   'hashed into build_id, so a typed value makes "rebuilt" and "changed" '
                   'indistinguishable.' % (claimed, base, derived))
    meta['git_head'] = derived


def build_document(builder_input, root=None, now=None, schema_validator=None,
                   reconciler=_UNSET):
    """SnapshotBuilderInput (dict) -> validated ControlRoomSnapshotV5 (dict). No file I/O.

    `schema_validator` defaults to the real ajv gate. It is an argument only so the fast fixture
    suite can drive the derivation and verdict logic without paying a node subprocess per case;
    _resolve_gate still refuses anything that is neither the canonical validator nor the named
    sentinel, so this cannot become a hole a caller widens with a lambda.

    `reconciler` has NO default -- see _resolve_reconciler.
    """
    gate = sv.ajv_schema_validator if schema_validator is None else schema_validator
    _resolve_reconciler(reconciler)
    inp = copy.deepcopy(builder_input)
    # Order matters and is load-bearing:
    #   1. refuse a supplied ANSWER   (verdict / reconciliation_clear / all_clear / reasons)
    #   2. derive the EVIDENCE from disk, refusing a contradicted claim
    #   3. validate the input against its schema
    #   4. compute the verdict FROM THE DERIVED EVIDENCE
    # Deriving before validating is intentional: the builder emits `read_ok`/`sha256` as nulls in
    # the common case, and the schema requires `read_ok` to be a boolean. Validating first would
    # reject the honest builder for declining to claim what it has not measured.
    sv._refuse_supplied_answer(inp)
    # Reconciliation BEFORE evidence: derive_source_evidence calls sv.facts_of, which requires
    # meta.reconciliation to exist. An input that legitimately claims nothing (which is what the
    # PowerShell writer now emits, so it CANNOT claim) would otherwise be refused for the absence
    # the next line is about to fill.
    _apply_git_head(inp, root)
    _apply_reconciliation(inp, reconciler, root)
    derive_source_evidence(inp, root=root, now=now)
    inp['meta']['build_id'] = compute_build_id(inp)
    out = sv.build_snapshot(inp, gate)
    # Re-verify the finished document through the SAME path a reader uses. If build and read could
    # disagree, every fixture below would be proving something about a code path no reader takes.
    return sv.verify_snapshot(out, gate)


# ---------------------------------------------------------------------------------------------
# The reconciliation evidence. ONE producer, so there is no parallel tally to drift.
#
# The design's equation is `discovered = categorized` and
# `categorized = actionable + running + waiting + review_audit + completed + cancelled_by_user`.
# Both halves are computed from ONE walk over ONE list here; nothing else in the pipeline counts
# orders, which is what ORDER-612's "no independently calculated totals anywhere" means in code.

# ALLOWLIST, not a blacklist -- shape 2. A status verb that is not in this table is counted
# `unclassified`, which makes the verdict FALSE with UNCLASSIFIED_PRESENT naming it. It is NOT
# guessed into the nearest bucket: a work item whose state this table cannot read is a fact about
# the table, and burying it in `completed` is how a board reports itself finished.
#
# The six bucket names are the design's (§1, the reconciliation equation), not chosen here.
# `cancelled_by_user` is the design's name and this mapping does NOT assert who cancelled a row --
# only CANCELLED and WITHDRAWN reach it, and neither verb names an actor.
STATUS_CATEGORY = {
    'OPEN': 'actionable',
    'OPEN-STANDING': 'actionable',
    'RE-OPENED': 'actionable',
    'CLAIMED': 'running',
    'RUNNING': 'running',
    'IN-PROGRESS': 'running',
    'WAITING': 'waiting',
    'WAITING-USER': 'waiting',
    'BLOCKED': 'waiting',
    'PARKED': 'waiting',
    'PENDING': 'waiting',
    'DONE': 'review_audit',
    'RESOLVED': 'review_audit',
    'REVIEWED': 'completed',
    'CLOSED': 'completed',
    # `cancelled_by_user` IS DELIBERATELY UNREACHABLE FROM THIS TABLE, and that is the fix, not an
    # omission. It used to map CANCELLED and WITHDRAWN. A blind audit pointed out what the comment
    # above had claimed away: `## ORDER-1 -- x `CANCELLED(agent qwen)`` parses to the verb
    # CANCELLED and landed in a bucket whose NAME asserts the user cancelled it. The board says an
    # agent did. Reproduced.
    #
    # The six bucket names are the design's and I may not rename one. What I may do is decline to
    # assert an actor the source does not state: a cancellation now falls to `unclassified`, which
    # is COUNTED, NAMED and turns the verdict false with UNCLASSIFIED_PRESENT -- the same treatment
    # every other verb this table cannot read gets. Measured before and after: the bucket held 0
    # rows either way, so nothing about today's numbers changes; what changes is that it can no
    # longer be filled by a guess.
    #
    # What is owed: either a bucket that names no actor, or an owner rule for reading one off the
    # board. Both are decisions, and neither is this table's to make.
}

# Same convention as scripts/check_taskboard_archive.ps1 Get-StatusClass, and for the same reason
# it was fixed there (memory `validator-substring-misclassifies-reviewed`): the status verb is the
# FIRST token of a backtick span, so the match is ANCHORED. Unanchored, `OPEN` matches inside
# "open question" and `HOLD` inside "holdout", which cost that parser 17 orders.
# The two ranks, DERIVED from STATUS_CATEGORY so they cannot drift from it. Non-terminal = the
# buckets that mean work is still live; terminal = the buckets that mean it is not.
NON_TERMINAL_BUCKETS = ('actionable', 'running', 'waiting')
NON_TERMINAL_VERBS = frozenset(v for v, b in STATUS_CATEGORY.items() if b in NON_TERMINAL_BUCKETS)
TERMINAL_VERBS = frozenset(v for v, b in STATUS_CATEGORY.items() if b not in NON_TERMINAL_BUCKETS)

_ORDER_ID = re.compile(r'^## (ORDER-[0-9A-Za-z_-]+?)\s*(?:--|—|$)')
_SPAN = re.compile(r'`([^`]+)`')
_VERB = re.compile(r'^[^A-Za-z]*([A-Z][A-Z-]*)\b')


def _order_rows(text, archive=False):
    """Every `## ORDER-...` header as (order_id, status_verb_or_None), in file order.

    The active board uses the conservative precedence rule below: an explicit non-terminal
    status wins over a terminal status mentioned elsewhere in the header, so a title cannot hide
    live work. The archive is different: its headers routinely preserve historical phrases such
    as ``was `OPEN``` after the current `` `REVIEWED(...)` `` status. Applying the active-board
    precedence to those historical mentions resurrects already-reviewed work as actionable.
    For archive rows, the first known status span is the current status; later status mentions are
    historical context.
    """
    out = []
    for line in text.splitlines():
        if not line.startswith('## ORDER-'):
            continue
        m = _ORDER_ID.match(line)
        order_id = m.group(1) if m else line[3:].split()[0]
        if archive:
            verb = None
            fallback = None
            for span in _SPAN.findall(line):
                vm = _VERB.match(span.strip())
                if not vm:
                    continue
                if fallback is None:
                    fallback = vm.group(1)
                if vm.group(1) in NON_TERMINAL_VERBS or vm.group(1) in TERMINAL_VERBS:
                    verb = vm.group(1)
                    break
            out.append((order_id, verb if verb is not None else fallback))
            continue

        # PRECEDENCE, not position. Round 3 changed this from "first uppercase span" to "first
        # span whose verb is a KNOWN status", which fixed inline code in a title -- and round 4
        # broke it with one line: `## ORDER-X -- title mentions `DONE` -- `OPEN`` resolved to DONE,
        # so a TITLE could hide actionable work. A failed generalization: I replaced one
        # position rule with another position rule.
        #
        # The board already has a parser that got this right, and it got it right by RANKING
        # rather than by ordering -- scripts/check_taskboard_archive.ps1's Get-StatusClass scans
        # every span for NON-TERMINAL verbs first, then REVIEWED, then terminal ones. Same rule
        # here, and the tie-break direction is the safe one: an order that is both "mentioned as
        # DONE" and "marked OPEN" is counted as OPEN. Over-reporting actionable work is a
        # nuisance; under-reporting it is how work disappears.
        verb = None
        fallback = None
        for rank in (NON_TERMINAL_VERBS, TERMINAL_VERBS):
            for span in _SPAN.findall(line):
                vm = _VERB.match(span.strip())
                if not vm:
                    continue
                if fallback is None:
                    fallback = vm.group(1)
                if vm.group(1) in rank:
                    verb = vm.group(1)
                    break
            if verb is not None:
                break
        out.append((order_id, verb if verb is not None else fallback))
    return out


TASKBOARDS = ('AGENT_TASKBOARD.md', 'ARCHIVE_TASKBOARD_2026-07A.md')

# The boards that are DELIBERATELY not counted, each with a reason. Probing round 2 of ORDER-612
# found five taskboard-shaped files in the repo root and only two of them being read, so
# `discovered` was a hand-maintained list of where work lives -- BACKLOG-D29's shape exactly, and
# the same rule ("silence is not zero") that reconcile() already refuses a MISSING board for.
#
# MEASURED 2026-07-31: all three below carry ZERO `## ORDER-` headers today, so the count was not
# wrong -- it was UNGUARDED. Both of the AGENT_TASKBOARD_* boards say in their own header that
# claim/status rules are the same as the main board, so an order landing in one is a normal thing
# to do, and nothing would have noticed.
TASKBOARDS_NOT_READ = {
    'AGENT_TASKBOARD_MERGE.md': 'a closed-track board; it must stay EMPTY of orders, and the '
                                'completeness check below enforces that rather than assuming it',
    'AGENT_TASKBOARD_PQUANT.md': 'a design board for a track that has not opened; same rule',
    'TASKBOARD_DIGEST.md': 'a GENERATED projection of the main board -- counting it would '
                           'double-count every order it summarises',
}

# THE LIMIT OF THAT COMPLETENESS CHECK, STATED IN THE GUARD RATHER THAN IMPLIED.
# It globs ROOT-LEVEL files whose NAME contains TASKBOARD. Probed 2026-07-31 (round 3): a board
# one directory down, or a root file called WORK_QUEUE.md, is invisible to it -- both confirmed.
#
# That scope is deliberate and the alternative was measured before choosing it: 46 tracked .md
# files carry `## ORDER-` headers, and 36 of them are test fixtures under
# scripts/_test/fixtures/order101/, the rest verdicts, handoffs and docs that quote an order.
# Only 2 are boards. A repo-wide "every file with an order header must be declared" check would
# therefore need a 44-entry exclusion list, and an exclusion list that long is a worse guard than
# the hole it closes -- it is the shape-2 blacklist, at scale.
#
# So the claim this check makes is exactly: NO ROOT-LEVEL TASKBOARD-SHAPED FILE IS SILENTLY
# OMITTED. It is not "no order can hide anywhere". A new board that follows the repo's own naming
# convention is caught; one that does not is not, and that is written here so nobody reads the
# green as the stronger sentence.
TASKBOARD_GLOB = '*TASKBOARD*.md'

# The coverage store's cell statuses, mapped onto the design's three coverage parts. A status this
# table cannot read is deliberately mapped to NOTHING, so the parts sum falls short of
# cells_in_universe and COVERAGE_SUM_MISMATCH fires naming both numbers. Silence is not an option
# the schema offers here (`coverage` has no `unclassified` slot), so the equation carries it.
# S5 replaces this store with real CoverageCell rows and their 9-state enum; this table extends
# there rather than being replaced.
COVERAGE_PART = {
    'LIVE': 'tested',
    'EVIDENCE_COMPLETE': 'tested',
    'BASELINE_RUN': 'tested',
    'PROBE_RUN': 'tested',
    'PULSE': 'tested',
    'NO_PULSE': 'tested',
    'UNTESTED': 'untested',
    'UNVERIFIED_IMPORT': 'untested',
    'RESCUE_IN_PROGRESS': 'untested',
    'NOT_APPLICABLE': 'not_applicable',
}


def reconcile(root=None):
    """-> a ReconciliationEvidence object. Every count comes from this one function."""
    root = REPO_ROOT if root is None else root

    # COMPLETENESS, before counting anything. The two lists above are declarations; the
    # FILESYSTEM decides whether they are complete -- the same shape as run_guard_shape_lint's L0,
    # and for the same reason: a hand-maintained list of where to look is a list that stops being
    # true. A board in neither list is refused outright; a board declared NOT_READ that has
    # acquired orders is refused too, because "it is empty" was the entire basis for excluding it.
    for path in sorted(glob.glob(os.path.join(root, TASKBOARD_GLOB))):
        rel = os.path.basename(path)
        if rel in TASKBOARDS:
            continue
        with io.open(path, encoding='utf-8') as fh:  # snapshot: worktree
            n = len(_order_rows(fh.read()))
        if rel not in TASKBOARDS_NOT_READ:
            sv._refuse('%s looks like a taskboard and is in neither TASKBOARDS nor '
                       'TASKBOARDS_NOT_READ (it carries %d order header(s)). Refusing: a count of '
                       '"all discovered work" that quietly omits a board is worse than no count.'
                       % (rel, n))
        if n:
            sv._refuse('%s is declared NOT READ on the grounds that it holds no orders (%r), and '
                       'it now carries %d. Either count it or change the reason -- an exclusion '
                       'whose premise has expired is an exclusion nobody re-examined.'
                       % (rel, TASKBOARDS_NOT_READ[rel], n))

    per_board = []
    rows = []
    for rel in TASKBOARDS:
        path = os.path.join(root, rel)
        if not os.path.isfile(path):
            # A missing board is NOT zero orders. Refusing is the whole rule 1 of this pipeline:
            # "I could not read the input" must never be published as "there was nothing there".
            sv._refuse('cannot reconcile: %s is not present, and an absent board is not the same '
                       'fact as a board with no orders.' % rel)
        with io.open(path, encoding='utf-8') as fh:  # snapshot: worktree
            board = _order_rows(fh.read(), archive=(rel == TASKBOARDS[1]))
        per_board.append([oid for oid, _v in board])
        rows.extend(board)

    categories = dict((k, 0) for k in sv.CATEGORY_KEYS)
    unclassified = 0
    for _oid, verb in rows:
        bucket = STATUS_CATEGORY.get(verb)
        if bucket is None:
            unclassified += 1
        else:
            categories[bucket] += 1
    discovered = len(rows)
    categorized = sum(categories.values())

    # duplicates = one board carrying the same order id at the head of MORE THAN ONE BLOCK.
    # conflicts = the same order id on more than one BOARD, i.e. simultaneously active and
    # archived. Both are real, both are computed here, and neither is a constant -- a hardcoded
    # `0` in a count the verdict reads is shape 3 (a criterion that cannot fire) sitting inside
    # the evidence instead of the check.
    #
    # SAY WHAT `duplicates` MEANS, because the 6 it reports today are not 6 mis-issued numbers.
    # Inspected 2026-07-31: `## ORDER-082 -- ...` and `## ORDER-082 -- AMENDMENT` are two blocks
    # under one id, as are `## ORDER-095 / #4` and `## ORDER-095`. That is a real, reportable
    # condition -- it is why an id can be simultaneously archivable and not -- but it is NOT the
    # claim "two different orders were issued the same number". A counter whose name invites the
    # stronger reading is the shape-2 defect, so the reading is pinned here.
    duplicates = 0
    for ids in per_board:
        counts = collections.Counter(ids)
        duplicates += sum(1 for _i, n in counts.items() if n > 1)
    seen_boards = collections.Counter()
    for ids in per_board:
        for oid in set(ids):
            seen_boards[oid] += 1
    conflicts = sum(1 for _i, n in seen_boards.items() if n > 1)

    cov_path = os.path.join(root, 'factory', 'coverage.jsonl')
    parts = dict((k, 0) for k in sv.COVERAGE_PARTS)
    cells_in_universe = 0
    if os.path.isfile(cov_path):
        with io.open(cov_path, encoding='utf-8') as fh:  # snapshot: worktree
            for n, line in enumerate(fh, 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except ValueError as exc:
                    sv._refuse('factory/coverage.jsonl line %d is not parseable JSON: %s'
                               % (n, exc))
                # BLIND AUDIT 2026-07-31, reproduced: a line that parsed as JSON but had the wrong
                # SHAPE was skipped by `continue`, so a coverage store of `{"bogus": 1}` reconciled
                # to cells_in_universe=0 with every part zero and NO REASON GIVEN. "I could read
                # the file and did not understand it" was published as "the universe is empty" --
                # the exact defect this pipeline refuses everywhere else, surviving in the one
                # place it was written as a `continue`.
                if not isinstance(rec, dict):
                    sv._refuse('factory/coverage.jsonl line %d is %s, not an object. Refused: a '
                               'coverage store this function cannot read is not a universe of zero '
                               'cells.' % (n, type(rec).__name__))
                # THE ONE metadata rule, imported. This block used to carry its own copy --
                # `if any meta key: continue` -- which meant a real coverage row with a `_comment`
                # on it was ERASED: 1 untested cell became an empty 0/0/0 universe. The identical
                # hole had been closed in registry.read_store three commits earlier, and the second
                # copy is the one nobody fixed. There is no second copy now.
                # The shared rule raises registry.RegistryRefusal; this module's contract is that
                # it raises SnapshotRefusal. Translated at the boundary rather than leaked, so a
                # caller still has ONE exception type to catch -- importing a rule must not import
                # a second failure vocabulary along with it.
                try:
                    kind = reg.classify_record(rec, 'factory/coverage.jsonl line %d' % n)
                except reg.RegistryRefusal as exc:
                    sv._refuse(str(exc))
                if kind == 'META':
                    continue
                # ORDER-1250. The moment the comment above COVERAGE_PART anticipated: a real
                # `CoverageCell` object IS one cell, and its `state` is the 9-state enum that
                # table already spells out. An imported row is a container of `cells`; a native
                # row is a cell. Counted here rather than refused -- but the refusal below is
                # NARROWED, not removed, so a row that is neither shape still stops the build.
                if rec.get('entity') == 'CoverageCell':
                    cells_in_universe += 1
                    state = str(rec.get('state') or '')
                    part = COVERAGE_PART.get(state)
                    if part is None:
                        sv._refuse(
                            'factory/coverage.jsonl line %d is a CoverageCell whose state %r is '
                            'in no coverage part. Refused rather than counted into the universe '
                            'and out of every part, which would make cells_in_universe disagree '
                            'with the parts sum for a reason nobody could see.' % (n, state))
                    parts[part] += 1
                    continue
                if 'cells' not in rec:
                    sv._refuse(
                        'factory/coverage.jsonl line %d has no `cells` key and is not a metadata '
                        'line, so this function cannot tell how many coverage cells it describes. '
                        'Refused rather than counted as zero: "readable but not understood" and '
                        '"empty" have opposite fixes.' % n)
                for cell in (rec.get('cells') or []):
                    cells_in_universe += 1
                    part = COVERAGE_PART.get(str(cell.get('status') or ''))
                    if part is not None:
                        parts[part] += 1
    else:
        sv._refuse('cannot reconcile: factory/coverage.jsonl is not present. An absent coverage '
                   'store is not a universe of zero cells.')

    return {
        'discovered': discovered,
        'categorized': categorized,
        'categories': categories,
        'duplicates': duplicates,
        'conflicts': conflicts,
        'unclassified': unclassified,
        'coverage': dict(parts, cells_in_universe=cells_in_universe),
    }


def _sha256_file(path):
    with io.open(path, 'rb') as fh:  # snapshot: worktree
        return hashlib.sha256(fh.read()).hexdigest()


def build_file(input_path, out_path, root=None, now=None, schema_validator=None,
               reconciler=_UNSET):
    """Read a builder input, build+validate, and atomically replace `out_path`.

    C5. Nothing touches `out_path` until a fully validated document exists in memory AND has been
    written and re-read from a sibling temp file. A failure anywhere before os.replace leaves the
    previous file byte-unchanged.
    """
    with io.open(input_path, encoding='utf-8-sig') as fh:  # snapshot: worktree
        builder_input = json.load(fh)
    doc = build_document(builder_input, root=root, now=now, schema_validator=schema_validator,
                         reconciler=reconciler)

    out_dir = os.path.dirname(os.path.abspath(out_path)) or '.'
    if not os.path.isdir(out_dir):
        sv._refuse('output directory %r does not exist' % out_dir)
    # INVOCATION-UNIQUE. A blind audit ran two snapshot builds against the same out_path and
    # reproduced JSONDecodeError, FileNotFoundError and a sharing violation: both processes used
    # this one fixed name, so each read the other's half-written bytes and one os.replace()d a file
    # the other had already moved. The daily monitor chain and a manual run CAN overlap on this
    # machine -- `[auto] daily monitor snapshot` is a scheduled committer here.
    tmp = os.path.join(out_dir, '.%s.%d.%s.tmp'
                       % (os.path.basename(out_path), os.getpid(), uuid.uuid4().hex[:8]))
    text = json.dumps(doc, indent=2, ensure_ascii=False)
    with io.open(tmp, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(text)
    try:
        # Read the temp file back and check THAT, not the in-memory object. A document that is
        # valid in memory and unreadable on disk (an encoding fault, a truncated write) would
        # otherwise be published and only discovered by the reader it breaks.
        #
        # The check is EQUALITY WITH THE VERIFIED DOCUMENT, not a second ajv+verdict pass. That is
        # not a shortcut and it is not shape 3 (comparing a value to itself): `doc` came out of
        # build_document already verified, and `reread` is what the FILESYSTEM gave back, so this
        # asks the one question the in-memory verification cannot -- did the write preserve the
        # document? Re-deriving the same verdict from the same evidence would answer a question
        # already answered, and cost a node subprocess to do it. MEASURED: it was ~1.4s per build.
        with io.open(tmp, encoding='utf-8-sig') as fh:  # snapshot: worktree
            reread = json.load(fh)
        if reread != doc:
            sv._refuse('the snapshot written to disk is not the document that was validated. The '
                       'canonical file has NOT been replaced. This is an encoding or truncation '
                       'fault in the write itself, which no amount of validating the in-memory '
                       'object can see.')
        os.replace(tmp, out_path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
    return doc


USAGE = ('usage: python _triage/factory_os/snapshot_build.py build '
         '<builder-input.json> <out-snapshot.json> [<source-root>]\n'
         '       (<source-root> defaults to the repo root; it is the directory every source row\'s\n'
         '        `path` resolves against, and exists so a FIXTURE can be built through this exact\n'
         '        pipeline against a controlled directory instead of a hand-authored document)\n'
         '       python _triage/factory_os/snapshot_build.py reconcile [<root>]\n'
         '       (<root> defaults to the repo root; same fixture rationale as <source-root>)\n'
         '       (prints a ReconciliationEvidence object on stdout)')


def main(argv):
    if len(argv) in (2, 3) and argv[1] == 'reconcile':
        try:
            sys.stdout.write(json.dumps(reconcile(root=argv[2] if len(argv) == 3 else None)))
        except sv.SnapshotRefusal as exc:
            sys.stderr.write('[REFUSED] %s\n' % exc)
            return 1
        return 0
    if len(argv) not in (4, 5) or argv[1] != 'build':
        print(USAGE)
        return 2
    try:
        # The CLI is the PRODUCTION path, so it always derives. The sentinel exists for
        # fixtures, which build against a temp root that has no boards.
        doc = build_file(argv[2], argv[3], root=(argv[4] if len(argv) == 5 else None),
                         reconciler=(reconcile if len(argv) == 4
                                     else RECONCILIATION_NOT_DERIVED))
    except sv.ToolFailure as exc:
        print('[TOOL-FAILURE] %s' % exc)
        return 3
    except sv.SnapshotRefusal as exc:
        print('[REFUSED] %s' % exc)
        return 1
    v = doc['verdict']
    print('[OK] %s written  build_id=%s  reconciliation_clear=%s  reasons=%d'
          % (argv[3], doc['meta']['build_id'], v['reconciliation_clear'], len(v['reasons'])))
    for r in v['reasons']:
        print('     %s: %s' % (r['code'], r.get('detail')))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
