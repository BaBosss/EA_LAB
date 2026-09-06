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
  Criterion ids emitted: R1-R7 (record-intrinsic) - F1-F14 (in-force) - G5/G7 (append-only) -
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
import candidate as C  # noqa: E402 -- ORDER-1263 is the one OwnerRef resolver
import evidence  # noqa: E402
import registry  # noqa: E402  -- ORDER-1310 #1, for classify_record ONLY: THE metadata rule

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
AUTHORIZATION_STATES = ('AUTHORIZED_BY_RESOLVED_REF', 'NON_AUTHORITATIVE',
                        'INVALID_AUTHORIZATION_REF')
AUTHORIZATION_SOURCE = {
    # Verified in the accepted 99e7b7ba checkout: this is the pre-existing ORDER-600 taskboard
    # record that says the owner approved the Coverage edge. The anchor is intentionally a token,
    # not a prose copy of the decision; OwnerRef R4 still requires it to be unique in the pinned
    # blob. Consumers bind to this source, not to the signer string in the attestation row.
    'owner_type': 'taskboard_order',
    'path': 'AGENT_TASKBOARD.md',
    'anchor': 'unblocks',
}

# audit 8 BLOCKER 2: the record binds the stable reviewed governance inputs, not just D1. The
# deterministic document the owner reads is verified as a derived artifact below, so a correct
# regeneration does not itself change the attested identity.
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
AUTHORITATIVE_BUNDLE = (
    '_triage/factory_os/s2a_migration.jsonl',               # D1 - the data
    '_triage/factory_os/s2a_coverage_reconciliation.json',  # C8's evidence
    '_triage/factory_os/check_s2a_migration.py',            # what D1's acceptance MEANS
    '_triage/factory_os/S2A_ATTESTATION_POLICY.md',         # what THESE criteria mean
    '_triage/factory_os/S2A_ATTESTATION_VECTORS.jsonl',     # what these criteria DO
)

# The previous contract was raw bytes of all six members. It remains readable only as a
# historical contract: a historical record may survive a regenerated projection when every
# authoritative member is still byte-identical to the revision that produced that record.
LEGACY_BUNDLE = (
    AUTHORITATIVE_BUNDLE[0],
    AUTHORITATIVE_BUNDLE[1],
    '_triage/factory_os/S2A_OWNERSHIP_MIGRATION.md',
    AUTHORITATIVE_BUNDLE[2],
    AUTHORITATIVE_BUNDLE[3],
    AUTHORITATIVE_BUNDLE[4],
)
BUNDLE = AUTHORITATIVE_BUNDLE
DERIVED_HANDOUT_PATH = '_triage/factory_os/S2A_OWNERSHIP_MIGRATION.md'
GENERATOR_SOURCE_PATH = '_triage/factory_os/gen_s2a_migration_doc.py'
# Governed implementation pin: changing the generator requires updating this instrumented pin
# in the same reviewed change. It is deliberately outside the owner-attested bundle because the
# generator is an implementation; its output remains independently verified below.
GENERATOR_SOURCE_SHA256 = '697bd7ddbedc98915643491e5731357f16d5ea484b12a6bb13c29b9df3e4ac79'

_D1_ROWS = []          # set by main(); the D1 rows, for A6's recompute

# ORDER-1269 #1: pins that `check()` decided NOT to enforce, each with the reason and the
# instruments that carried the decision instead. Printed by main(). This list is the difference
# between "narrowed deliberately" and "quietly stopped checking".
PIN_NOTES = []

# ORDER-1269 #3: owner -> line, for every in-force record that raised a problem OF ITS OWN.
#
# WHY THIS IS A SIDE CHANNEL AND NOT A CHANGE TO WHAT `check()` RETURNS -- the first version of
# this repair did the obvious thing and withheld the failing row from `current`, which reads
# better and cost an owner signature. `S2A_ATTESTATION_VECTORS.jsonl` is a BUNDLE MEMBER, and 29
# of its 68 canonical vectors assert `expected_current: {OWNER.md: {decision: APPROVED}}` for
# records their own `expected_reasons` refuses -- the defect, written into the signed policy
# corpus. Editing them to expect UNVERIFIED changes the bundle digest, which fails F1 on the
# record in force, which is the "signature to repair a signature" this same order prohibits.
#
# The ratified wording is the way out and it is exact: "The exit code is already honest; THE LINE
# A HUMAN READS is not." Conformance compares `expected_current`, `expected_exit`,
# `expected_reasons` and `expected_bundle_sha256` (run_s2a_conformance.run_vector) and never reads
# printed output. So demoting the PRINT satisfies the decision, keeps the signed contract byte-
# identical, and costs nothing. The returned map has exactly one other consumer -- main()'s own
# print -- so nothing real is lost by leaving it alone.
IN_FORCE_FAILED = {}


def reported_decision(row, owner):
    """(decision, note) for the line a human reads. ORDER-1269 #3.

    Separate from the row's own `decision` field on purpose: a record can be well-formed, signed,
    and refused by a criterion at the same time, and the printed line is the one surface where
    saying "APPROVED" is a false statement rather than an incomplete one.
    """
    if owner in IN_FORCE_FAILED:
        return 'UNVERIFIED', ('the record in force (line %s) is signed but did NOT pass its own '
                              'checks -- see the problems below; it is not an approval in effect'
                              % IN_FORCE_FAILED[owner])
    return row.get('decision'), row.get('_note')

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
_LEGACY_MATCH_CACHE = {}
_IMMUTABLE_GIT_BYTES_CACHE = {}
_FULL_GIT_OID = re.compile(r'^(?:[0-9a-f]{40}|[0-9a-f]{64})$')


def _digest_paths(paths, read_bytes):
    h = hashlib.sha256()
    for path in paths:
        h.update(path.encode('utf-8'))
        h.update(b'\0')
        h.update(hashlib.sha256(read_bytes(path).replace(b'\r\n', b'\n')).digest())
    return h.hexdigest()


def bundle_digest():
    """The fingerprint of stable governance inputs, read through the process source.

    The generated D2 handout is not silently ignored: ``derived_artifact_problems`` verifies its
    exact canonical rendering. It is simply not part of this stable identity, so a deterministic
    projection can be regenerated without changing the owner's attested governance inputs.
    """
    src = _src()
    if src in _DIGEST_CACHE:
        return _DIGEST_CACHE[src]
    _DIGEST_CACHE[src] = _digest_paths(AUTHORITATIVE_BUNDLE, src.read_committed_bytes)
    return _DIGEST_CACHE[src]


def _git_bytes_at(commit, path):
    # A full object id names immutable Git history; HEAD, branches and index syntax do not.  The
    # runner is part of the scope because conformance tests replace it with hermetic Git worlds,
    # while the normalized root prevents one worktree answering for another.  Failed reads are
    # deliberately absent from the cache: the same return code covers a genuinely missing path
    # and transient process/repository failures, and neither may become a process-long verdict.
    cacheable = (isinstance(commit, str) and _FULL_GIT_OID.fullmatch(commit)
                 and isinstance(path, str))
    key = (os.path.normcase(os.path.realpath(_ROOT)), subprocess, subprocess.run, commit, path)
    if cacheable and key in _IMMUTABLE_GIT_BYTES_CACHE:
        return _IMMUTABLE_GIT_BYTES_CACHE[key]
    p = subprocess.run(['git', 'show', '%s:%s' % (commit, path)],
                       capture_output=True, cwd=_ROOT)
    if p.returncode != 0:
        return None
    if cacheable:
        _IMMUTABLE_GIT_BYTES_CACHE[key] = p.stdout
    return p.stdout


def historical_bundle_matches(expected, current_digest):
    """Accept an old raw-bundle digest only when its stable members are unchanged.

    This is compatibility for existing records, not a second attestation source. The matching
    historical revision is discovered from Git, its legacy six-file digest is recomputed, and its
    authoritative-member digest must equal the current one. A changed D1/policy/vector input
    therefore cannot be hidden behind an old handout-era digest.
    """
    key = (str(expected), str(current_digest))
    if key in _LEGACY_MATCH_CACHE:
        return _LEGACY_MATCH_CACHE[key]
    # Conformance vectors supply hermetic synthetic bundle digests. Historical Git lookup is a
    # real-repository compatibility path and must never escape into that synthetic world.
    if current_digest != bundle_digest():
        _LEGACY_MATCH_CACHE[key] = False
        return False
    if not isinstance(expected, str) or len(expected) != 64:
        _LEGACY_MATCH_CACHE[key] = False
        return False
    p = subprocess.run(['git', 'rev-list', '--all', '--', DERIVED_HANDOUT_PATH],
                       capture_output=True, cwd=_ROOT)
    if p.returncode != 0:
        _LEGACY_MATCH_CACHE[key] = False
        return False
    for raw_commit in p.stdout.splitlines():
        commit = raw_commit.decode('ascii', 'replace').strip()
        if not commit:
            continue
        cache = {}
        for path in LEGACY_BUNDLE:
            data = _git_bytes_at(commit, path)
            if data is None:
                break
            cache[path] = data
        else:
            if _digest_paths(LEGACY_BUNDLE, cache.get) != expected:
                continue
            if _digest_paths(AUTHORITATIVE_BUNDLE, cache.get) == current_digest:
                _LEGACY_MATCH_CACHE[key] = True
                return True
    _LEGACY_MATCH_CACHE[key] = False
    return False


def derived_artifact_problems(src):
    """Validate the generated handout against authoritative D1/C8 generator inputs."""
    import gen_s2a_migration_doc as gen_d2

    source_sha = hashlib.sha256(src.read_committed_bytes(GENERATOR_SOURCE_PATH)
                               .replace(b'\r\n', b'\n')).hexdigest()
    if source_sha != GENERATOR_SOURCE_SHA256:
        return ['D4 governed generator source changed without its required source pin: %s '
                'does not match the instrumented contract.' % GENERATOR_SOURCE_PATH]
    rows = [json.loads(line) for line in src.read_committed(chk.MIGRATION_PATH).split('\n')
            if line.strip()]
    cov = json.loads(src.read_committed(chk.COVERAGE_PATH))
    expected = gen_d2.build(rows, cov).encode('utf-8')
    actual = src.read_committed_bytes(DERIVED_HANDOUT_PATH).replace(b'\r\n', b'\n')
    if actual == expected:
        return []
    return ['D2 derived handout is stale or tampered: %s does not match canonical generator '
            'output; refuse until regenerated from authoritative inputs.' % DERIVED_HANDOUT_PATH]


BLOB_OID = re.compile(r'^[0-9a-f]{40}$')


def _is_blob_oid(value):
    return bool(BLOB_OID.match(str(value or '')))


SECTION_SHA = re.compile(r'^[0-9a-f]{64}$')
FENCE = ('```', '~~~')


def _is_section_sha(value):
    return bool(SECTION_SHA.match(str(value or '')))


def _default_head_text(path):
    """HEAD's content at `path`, as TEXT, decoded UTF-8 STRICT.

    BYTES then decode, never `chk._git` -- that helper runs subprocess with `text=True`, which
    decodes with the LOCALE codec. MASTER_BACKLOG.md is UTF-8 carrying Thai and an em-dash in the
    very heading F13 anchors on, so a locale decode would mangle the exact region F14 hashes and
    produce a mismatch nobody could attribute. Returns None when the path is not at HEAD (F9
    already owns that case) and raises ValueError when the bytes are not UTF-8 (F13 owns that).
    """
    rc, oid, _ = chk._rev_parse_cached('%s:%s' % (chk.head_oid(), path))  # snapshot: HEAD
    if rc != 0:
        return None
    p = subprocess.run(['git', 'cat-file', 'blob', oid], capture_output=True)  # snapshot: HEAD
    if p.returncode != 0:
        return None
    return p.stdout.decode('utf-8')            # strict on purpose; ValueError is F13's input


# THE SEAM the conformance runner replaces, in the same shape as `_index_src`. A vector's world
# has no git, so the SECTION criteria need one named entry point rather than a git call the
# runner has to guess at. Swapped by run_s2a_conformance.install_world, restored after.
_head_text = _default_head_text


def extract_section(text, anchor):
    """(region_bytes, error) -- policy section 4.3.1, the ONE implementation of the rule.

    `check_attested_pin_staged.py` imports THIS function rather than owning a copy: two readers
    of one approved region is GUARD_SHAPES shape 5, and the region is what the owner signed.

    Never raises for its own inputs. `error` is a human sentence naming WHICH fail-closed branch
    fired; the caller decides whether that is F13 (post-commit) or P4 (front guard), because the
    criterion id is a reporting convention and the RULE is not.
    """
    if text is None:
        return None, 'the path has no content at this snapshot'
    lines = text.replace('\r\n', '\n').split('\n')
    want = (anchor or '').rstrip()
    if not want:
        return None, 'the record names no section anchor'
    in_fence = False
    fenced = []
    for line in lines:
        s = line.rstrip()
        fenced.append(in_fence)
        if s.startswith(FENCE):
            in_fence = not in_fence
    if in_fence:
        return None, ('the file ends inside an unterminated fenced block, so the section end '
                      'cannot be determined')
    hits = [i for i, line in enumerate(lines) if not fenced[i] and line.rstrip() == want]
    if not hits:
        return None, 'the section heading %r does not appear at this snapshot' % want
    if len(hits) > 1:
        return None, ('the section heading %r appears %d times; two candidate regions is no '
                      'region' % (want, len(hits)))
    start = hits[0]
    end = len(lines)
    for j in range(start + 1, len(lines)):
        if not fenced[j] and lines[j].rstrip().startswith('## '):
            end = j
            break
    return ('\n'.join(lines[start:end]) + '\n').encode('utf-8'), None


def section_digest(text, anchor):
    """(sha256_hex, error). The pair `extract_section` is always consumed as."""
    region, err = extract_section(text, anchor)
    if err:
        return None, err
    return hashlib.sha256(region).hexdigest(), None


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
        # `authorization_ref` is optional for an informational attestation, but a supplied ref
        # must be real. This keeps malformed metadata from becoming an authority claim while
        # preserving every historical row that predates the field.
        auth = authorization_status(r, require=False)
        if auth['problems']:
            problems.extend('AUTH-INVALID line %s %s' % (n, p) for p in auth['problems'])
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


def owner_ref_paths(d1_rows):
    """current_owner -> the sorted paths that owner's D1 rows PIN. Derived once, here.

    WHY THIS EXISTS (ORDER-731 option 2, 2026-08-01). Notes are keyed on `owner_ref.path` (N1-N4);
    records are written against `current_owner`. Until 2026-08-01 those were the same string for
    every row in D1, so `stale.get(record['current_owner'])` was a correct lookup by accident of
    the data rather than by design. The moment one row's pin moved to the file holding its
    canonical bytes, that lookup silently stopped matching -- the note was still DERIVED and still
    PRINTED for `factory/coverage.jsonl`, while F2-F5 became permanently unreachable for the one
    owner the whole artifact exists for. A guard that reports and cannot refuse, presented as a
    guard that refuses, is memory `guard-disarmed-by-prose-reported-as-note` exactly.

    So the mapping is made explicit: an owner is asked about the bytes ITS OWN rows pin.

      * Where `current_owner == owner_ref.path` -- 13 of the 14 pinned rows, and every row that
        existed before 2026-08-01 -- this returns `{owner: [owner]}` and the lookup below is
        byte-identical to the old one. That is what keeps the frozen corpus reproducing.
      * N4 is UNCHANGED: the comparison is still exact path identity, never containment. What
        moved is WHICH path is looked up, not how it is compared.
      * An owner with no pinned row at all (`EMBEDDED:*`, the four owner-states) maps to `[]` and
        can never draw a note -- which is what it did before, since nothing pinned it.

    DECLARED LIMIT: one owner may pin SEVERAL paths (`AGENT_TASKBOARD.md` is pinned by both
    `Hypothesis` and `WorkReceipt` -- the same path today, but nothing forbids two different ones).
    `stale_pin_acknowledgement` is a single object and can name exactly one path, so when more than
    one of an owner's paths has drifted, this matches the FIRST in sorted order and the others are
    reported by the advisory but not enforced. Deterministic, and stated rather than discovered.
    """
    out = {}
    for r in d1_rows or ():
        owner = r.get('current_owner')
        if not owner:
            continue
        ref = r.get('owner_ref') or {}
        paths = out.setdefault(owner, set())
        if ref.get('path'):
            paths.add(ref['path'])
    return {k: sorted(v) for k, v in out.items()}


def _authorization_source_problems(ref, action):
    """Return action-specific source failures after OwnerRef has resolved."""
    if action != 'coverage_transfer':
        return []
    problems = []
    for field in ('owner_type', 'path', 'anchor'):
        expected = AUTHORIZATION_SOURCE[field]
        if ref.get(field) != expected:
            problems.append('AUTH-SOURCE %s must be %r for coverage_transfer, got %r'
                            % (field, expected, ref.get(field)))
    return problems


def authorization_status(row, require=False, action=None, src=None):
    """Classify attestation authority without upgrading its ``decision`` field.

    The normal ledger path permits an absent ref as an informational/legacy attestation. An
    owner-sensitive consumer calls this with ``require=True``; absence and invalidity then fail
    closed with deterministic ``AUTH-*`` reasons. OwnerRef resolution is delegated to
    ``candidate.owner_ref_problems``; resolver ToolFailure deliberately propagates as exit 2.
    """
    status = {
        'attestation_state': 'VALID',
        'authorization_state': 'NON_AUTHORITATIVE',
        'signer_role': 'display_only',
        'decision_role': 'attestation_disposition',
        'legacy': False,
        'problems': [],
    }
    if 'authorization_ref' not in row or row.get('authorization_ref') is None:
        status['legacy'] = True
        if require:
            status['problems'].append(
                'AUTH-ABSENT current %r has no authorization_ref; owner authorization is required '
                'for %s and signer text is display-only'
                % (row.get('current_owner'), action or 'this action'))
        return status

    ref = row.get('authorization_ref')
    ref_problems = C.owner_ref_problems(ref, 'authorization_ref', src=src)
    if ref_problems:
        status['attestation_state'] = 'INVALID'
        status['authorization_state'] = 'INVALID_AUTHORIZATION_REF'
        status['problems'].extend(ref_problems)
        if require:
            status['problems'].insert(0,
                                      'AUTH-INVALID authorization_ref cannot authorize %s'
                                      % (action or 'this action'))
        return status

    source_problems = _authorization_source_problems(ref, action)
    if source_problems:
        status['attestation_state'] = 'INVALID'
        status['authorization_state'] = 'INVALID_AUTHORIZATION_REF'
        status['problems'].extend(source_problems)
        if require:
            status['problems'].insert(0,
                                      'AUTH-INVALID authorization_ref source is not authorized '
                                      'for %s' % (action or 'this action'))
        return status

    status['authorization_state'] = 'AUTHORIZED_BY_RESOLVED_REF'
    return status


def note_for_owner(stale, ref_paths, owner):
    """The note an owner must acknowledge, or None. Path identity only (N4)."""
    for path in ref_paths.get(owner, ()):
        if path in stale:
            return stale[path]
    return None


def executed_transfer_destinations(d1_rows, owner):
    """Paths THIS OWNER's own D1 rows pin as the DESTINATION of an already-executed transfer.

    🔴 ORDER-1310 #3 -- `owner` IS REQUIRED, AND THAT IS THE WHOLE REPAIR. This function used to
    take only `d1_rows` and return a set of paths gathered from EVERY row, which the comment below
    described as an exemption "for that row only". It was not: it was PATH-scoped. Any owner whose
    note happened to name a path some OTHER row had donated to the set inherited the exemption --
    reproduced by the independent review with a synthetic `KEEP` row pinning the same path as the
    real executed transfer, whose stale pin was exempted and whose decision stayed APPROVED.
    Today's D1 has no such pair, so it was latent rather than live; a positional argument with no
    default is what stops it being reintroduced by a caller that simply forgets.

    ⚠️ DECLARED LIMIT, raised by the same review and NOT closed here. This predicate reads
    `disposition == TRANSFER` plus path equality as proof that the transfer was EXECUTED, while
    `S2A_ATTESTATION_POLICY.md:154` states D1 has no executed-state vocabulary at all. The
    inference is therefore structural, not recorded: it holds because a row only re-points its pin
    at `proposed_owner` once the move has happened. Giving D1 a real executed-state field would
    close it properly and is a BUNDLE MEMBER change -- a policy edit and an owner signature -- so
    it is stated here rather than done quietly under a different order.

    ORDER-1269 #1, owner-ratified as ORDER-1257 option (b) -- "change the instrument, not the
    record". This is the predicate that instrument turns on, and it is DERIVED from the row rather
    than typed as a path list, because a typed list is a second place for D1 to drift away from.

    WHAT WENT WRONG, stated as aim rather than as staleness. `owner_ref` exists to answer one
    question (N1-N4): "have the bytes this proposal is about changed since the owner read them?"
    Every other TRANSFER row in D1 answers it by pinning the SOURCE -- the file the fact still
    lives in while the move is only proposed -- so a change there really is the owner's reading
    going out of date. Row 10 is the one row whose transfer has been EXECUTED (`a424e90b`), so its
    pin was re-pointed at `proposed_owner`, the destination. A destination changing is the approval
    SUCCEEDING. Pinning a whole blob there asks whether the approved outcome happened and treats
    "yes" as a defect, which is why a legitimate 16-row append voided a one-time ownership decision.

    IT IS A GRANULARITY MISMATCH AND ALSO AN AIM ERROR, and the second half is what makes a
    narrower pin the wrong repair too. MEASURED, because I designed a byte-prefix pin first and it
    would have been a guard that worked today and reintroduced the toll silently later: the pinned
    9-line blob IS a byte-exact prefix of HEAD, but `ec47f37d` rewrote 16 EXISTING lines in place
    (16 insertions / 16 deletions) when those cells changed state. The store is designed to MUTATE,
    not merely to grow, so no pin over the whole store -- equality, prefix or otherwise -- can be
    stable. Only a pin on something that does not move can be, which is the ratified wording:
    the MIGRATION and the GENERATED SECTION.

    BLAST RADIUS, measured against the real D1 rather than reasoned about (29 rows):
      * `disposition == TRANSFER` AND `owner_ref.path == proposed_owner` selects exactly ONE row,
        CoverageCell. The other 12 TRANSFER rows all pin a source path that differs from their
        proposed owner, so they keep biting unchanged.
      * five KEEP rows also have `path == proposed_owner` (nothing moves, so the pin correctly aims
        at where the fact already lives). The TRANSFER conjunct is what excludes them, and the
        SPECIFICITY case in the suite is what holds that.
    """
    out = set()
    for r in d1_rows or ():
        if r.get('current_owner') != owner:
            continue                     # ORDER-1310 #3: another owner's transfer is not this
        ref = r.get('owner_ref') or {}   # owner's licence to stop being asked about its own pin
        if (r.get('disposition') == 'TRANSFER' and ref.get('path')
                and ref['path'] == r.get('proposed_owner')):
            out.add(ref['path'])
    return out


def declared_owner_section(destination_path):
    """The heading of the OWNER file that this destination store DECLARES it projects into.

    🔴 ORDER-1310 #1 -- THE EXEMPTION USED TO ACCEPT ANY REPRODUCIBLE SECTION OF THE OWNER FILE.
    `pin_exemption_reason` required a section claim that RESOLVES and F7 required it to bind
    `current_owner`; nothing anywhere asked WHICH section. The independent review bought the
    exemption with a correctly-hashed claim on `## 1. ความจริงสั้น ๆ (อ่านก่อน)` -- an unrelated
    stable heading that has nothing to do with the approved transfer. Reproduced.

    THE ANSWER MUST NOT BE A HARDCODED HEADING, and this is why it does not have to be. The
    transfer being exempted moved a fact OUT of a section of the owner file and INTO a store; the
    store then projects that section back. Which section that is is DATA the store itself carries
    -- the `_section` metadata record, a repo-wide convention declared in `registry.META_KEYS`,
    written by `gen_coverage.py` and read by `check_coverage_transfer.py`. So the approved section
    is not a name this checker knows: it is the name the DESTINATION declares, re-read from HEAD
    on the run that grants the exemption, exactly like the digest beside it. A destination that
    declares nothing gets no exemption (memories `rule-names-categories-not-enum-members` and
    `citation-guard-satisfied-by-a-universal-file` -- an enum of headings would be the first, and
    "any section that happens to resolve" was the second).

    FAIL CLOSED at every branch: not at HEAD, undecodable, unparseable, a record that is both a
    note and a row, no `_section` at all, or MORE THAN ONE -- all return None, which costs the
    owner a signature instead of granting an exemption on an ambiguous reading.

    `registry.classify_record` is IMPORTED rather than copied, because that is the one metadata
    rule in this repo and the second copy is always the one nobody fixes. The line-splitting is
    local because the bytes come from `_head_text`, the seam the conformance runner replaces --
    `registry.read_store` reads the worktree or an EvidenceSource, neither of which is what F13,
    F14 and this exemption are judging.
    """
    try:
        text = _head_text(destination_path)
    except (UnicodeDecodeError, ValueError):
        return None
    if not text:
        return None
    headings = []
    for line in text.replace('\r\n', '\n').split('\n'):
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except ValueError:
            return None
        if not isinstance(rec, dict):
            return None
        try:
            kind = registry.classify_record(rec, '%s (pin exemption)' % destination_path)
        except Exception:
            return None
        if kind == 'META' and isinstance(rec.get('_section'), dict):
            headings.append(rec['_section'].get('heading'))
    if len(headings) != 1 or not headings[0]:
        return None
    return headings[0]


def pin_exemption_reason(note, eps, destinations, digest):
    """Why this vintage note is NOT enforced, or None. ONE rule, TWO readers.

    `check()` asks it to decide F2. `--template` asks it to decide whether to hand the signer an
    acknowledgement skeleton. They must not be able to disagree: a handout that asks the owner to
    acknowledge a pin the checker will not demand is defect #2 of this same order -- the deadlock
    written into the owner's own instructions -- and a second copy of this predicate is how that
    happens. GUARD_SHAPES shape 5, the same reasoning that made `check_attested_pin_staged.py`
    import `extract_section` rather than own a copy of it.

    The section claim is RE-RESOLVED here rather than trusted, so this answers "did the replacement
    instrument work" and not "was one declared". F14 computes the identical comparison, which is
    what keeps the two answers the same by construction rather than by inspection.
    """
    if not note or note.get('kind') != 'STALE':
        return None
    if note.get('path') not in (destinations or ()):
        return None
    # SECTION form only, and `blob` absent rather than merely falsy -- a record offering both forms
    # has made no single claim (that is F6), and it must not buy an exemption here either.
    if not (isinstance(eps, dict) and eps.get('path') and eps.get('section')
            and eps.get('section_sha256') and not eps.get('blob')):
        return None
    try:
        text = _head_text(eps['path'])
    except (UnicodeDecodeError, ValueError):
        return None                      # FAIL CLOSED, exactly as F13 does
    got, err = section_digest(text, eps['section'])
    if err or got != eps['section_sha256']:
        return None
    # ORDER-1310 #1: WHICH section. Everything above proves the claim RESOLVES; this proves it is
    # the section the transfer was about, by asking the destination store what it projects.
    declared = declared_owner_section(note['path'])
    if not declared or eps['section'] != declared:
        return None
    return ('the pin on %r is NOT enforced -- %r is the destination of a transfer THIS OWNER\'S '
            'own D1 row records as already executed, so its bytes changing is the approved '
            'outcome, not the record going stale. What binds this decision instead: the migration '
            '(bundle %s) and the generated section %r of %s (sha %s), both re-resolved on this '
            'run -- and that section is the one %s DECLARES it projects, not merely one that '
            'happens to resolve. A MISSING note, a section claim that did not reproduce, a claim '
            'naming a DIFFERENT section, an exemption borrowed from another owner\'s transfer, or '
            'no claim at all would all still demand the owner.'
            % (note['path'], note['path'], str(digest)[:12], eps['section'], eps['path'],
               str(eps['section_sha256'])[:12], note['path']))


def check(rows, problems, digest, d1_owners, vintage_notes):
    stale = {n['path']: n for n in vintage_notes if isinstance(n, dict) and n.get('path')}
    # The record->note match goes through D1's own current_owner -> owner_ref.path mapping, NOT
    # through string identity on current_owner. See owner_ref_paths for why, and for the one
    # property that makes this a no-op everywhere else in the table.
    ref_paths = owner_ref_paths(_D1_ROWS)
    # ORDER-1310 #3: the destination set is now derived PER ROW, inside the loop, because it is
    # scoped to the row's own owner. Hoisting it back out here is the defect.
    del PIN_NOTES[:]        # per run, not per process: the suites call check() many times in one
    IN_FORCE_FAILED.clear()
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
        # ORDER-1269 #3, owner-ratified: "a record whose pin failed must print UNVERIFIED, not
        # APPROVED". F1 and the R-checks `continue` out of this loop, so a row they refuse never
        # reached the assignment at the bottom and the reconciliation below caught it. F2-F14 do
        # NOT continue -- they append to `problems` and fall through -- so a record could fail its
        # own pin check and still be reported as the decision in force, four printed lines above
        # its own failure. The exit code was honest the whole time; the line a human reads was not.
        #
        # The count is snapshotted PER ROW, not tested as `if problems`. `problems` is shared with
        # load_records, check_append_only and every other row, so "non-empty" would un-approve a
        # record that verified perfectly because a malformed line was appended after it. That
        # distinction is what the SPECIFICITY case in the suite exists to hold.
        problems_before = len(problems)
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
        if (in_force and r['bundle_sha256'] != digest and
                not historical_bundle_matches(r['bundle_sha256'], digest)):
            problems.append('F1 line %s attests bundle %s but the current bundle is %s -- the '
                            'authoritative governance inputs changed after this record, so it no '
                            'longer describes what is on disk. Re-make it against the current '
                            'contract.'
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
            # ORDER-731 option A (owner-ratified): expected_post_state has TWO forms and a record
            # must be in exactly one. WHOLE-FILE {path, blob} is unchanged -- every vector written
            # for it still reproduces. SECTION {path, section, section_sha256} narrows the claim to
            # the region the approval was about, because a whole-file pin on MASTER_BACKLOG.md
            # measured 30 commits / 14 days = ~2 owner signatures a day (ORDER-731 C1).
            #
            # Codex round 2, Standards 3 + Spec 3: this bound ANY path to ANY value. A record
            # deciding for MASTER_BACKLOG.md could bind AGENT_TASKBOARD.md and pass; a
            # {path: "NO_SUCH_PATH", blob: "MISSING"} pair passed; and a directory path resolved
            # to its TREE oid and passed. So it never enforced "changed INTO the approved state" --
            # it enforced "some path is at some value", which is not a claim about this decision.
            is_obj = isinstance(eps, dict)
            has_blob = bool(is_obj and eps.get('blob'))
            has_sec = bool(is_obj and (eps.get('section') or eps.get('section_sha256')))
            whole = has_blob and not has_sec
            section = bool(is_obj and eps.get('section') and eps.get('section_sha256')
                           and not has_blob)
            if not is_obj or not eps.get('path') or not (whole or section):
                problems.append('F6 line %s has expected_post_state that is not an object naming '
                                'EXACTLY ONE of {path, blob} or {path, section, section_sha256}. '
                                'A record offering two answers to "what was approved" has not made '
                                'one claim, it has made none.' % n)
            elif eps['path'] != r['current_owner']:
                problems.append(
                    'F7 line %s decides for %r but its expected_post_state binds %r. A record may '
                    'only make a claim about the state of the file it decides for -- binding '
                    'anything else lets the approved target sit in a state nobody approved while '
                    'this criterion stays green.' % (n, r['current_owner'], eps['path']))
            elif whole and (str(eps['blob']).upper() == 'MISSING'
                            or not _is_blob_oid(eps['blob'])):
                problems.append(
                    'F8 line %s expects %s at %r, which is not a 40-hex blob id. "MISSING" and a '
                    'tree id are both accepted by git and neither is a statement about the CONTENT '
                    'this decision approved.' % (n, eps['path'], eps['blob']))
            elif section and (str(eps['section_sha256']).upper() == 'MISSING'
                              or not _is_section_sha(eps['section_sha256'])):
                problems.append(
                    'F12 line %s expects section %r at %r, which is not a 64-hex sha256. F8\'s '
                    'reasoning one level down: a value sha256 would accept as an argument is not a '
                    'statement about content.' % (n, eps['section'], eps['section_sha256']))
            else:
                rc3, live3, _ = chk._rev_parse_cached('%s:%s' % (chk.head_oid(), eps['path']))
                if rc3 != 0:
                    problems.append(
                        'F9 line %s expects %s at %s, but that path does not exist at HEAD. A '
                        'record cannot approve the post-state of a file that is not there.'
                        % (n, eps['path'], str(eps.get('blob') or eps.get('section'))[:40]))
                elif not _is_blob_at_head(eps['path']):
                    problems.append(
                        'F10 line %s binds %s, which resolves to a TREE at HEAD, not a file. A '
                        'directory has no content this decision could have approved.'
                        % (n, eps['path']))
                elif whole and live3 != eps['blob']:
                    problems.append(
                        'F11 line %s expects %s to be at blob %s after the action it approves, but '
                        'HEAD has %s. The record describes a change that did not happen, or a '
                        'different one happened -- either way this is not the state that was '
                        'approved.' % (n, eps['path'], str(eps['blob'])[:12], str(live3)[:12]))
                elif section:
                    # FAIL CLOSED. "I could not find the section" must never share an outcome with
                    # "the section is unchanged" -- that is the one way a narrowed pin could be
                    # weaker than the whole-file pin it replaces.
                    try:
                        text = _head_text(eps['path'])
                    except (UnicodeDecodeError, ValueError) as exc:
                        text, decode_err = None, str(exc)
                    else:
                        decode_err = None
                    if decode_err:
                        problems.append(
                            'F13 line %s cannot locate section %r in %s: HEAD\'s content is not '
                            'decodable as UTF-8 (%s). A section that cannot be located is REFUSED, '
                            'never skipped.' % (n, eps['section'], eps['path'], decode_err))
                    else:
                        got, err = section_digest(text, eps['section'])
                        if err:
                            problems.append(
                                'F13 line %s cannot locate section %r in %s at HEAD: %s. A section '
                                'that cannot be located is REFUSED, never skipped.'
                                % (n, eps['section'], eps['path'], err))
                        elif got != eps['section_sha256']:
                            problems.append(
                                'F14 line %s expects section %r of %s to hash to %s after the '
                                'action it approves, but HEAD hashes to %s. The record describes a '
                                'change that did not happen, or a different one happened -- either '
                                'way this is not the state that was approved.'
                                % (n, eps['section'], eps['path'],
                                   str(eps['section_sha256'])[:12], str(got)[:12]))

        # ORDER-613 D1: the stale-pin rule now judges ONLY the CURRENT record per owner.
        # It used to run for every row, including superseded ones -- while this file's own header
        # promises "the latest line per current_owner wins". Because the log is append-only, an
        # earlier row could never acquire the acknowledgement it was being failed for, so a single
        # stale pin made that owner's history permanently unrepairable and the artifact could not
        # be returned to green by any legal action. Superseded rows stay in the file and stay
        # printed; they are history, not live claims. What is DEMANDED of the current row is
        # unchanged -- this narrows which row is judged, never what it must satisfy.
        note = note_for_owner(stale, ref_paths, r['current_owner']) if in_force else None
        # ORDER-1269 #1 = ORDER-1257 option (b), owner-ratified: CHANGE THE INSTRUMENT.
        #
        # The pin is not enforced on the destination of an already-executed transfer -- but ONLY
        # when the two stable instruments the ratification names have actually done their work on
        # THIS run. Not "are declared". VERIFIED:
        #
        #   the MIGRATION        F1, above, recomputed the authoritative bundle digest (D1 + the
        #                        reconciliation + migration checker + POLICY + VECTORS) and the record
        #                        still binds it. A row
        #                        that failed F1 `continue`d and never reached this line.
        #   the GENERATED SECTION  F6-F14, immediately above, resolved this record's
        #                        `expected_post_state` against HEAD and it reproduced. F7 already
        #                        forces that claim to bind `current_owner`, which for row 10 is
        #                        MASTER_BACKLOG.md -- the generated projection a reader actually
        #                        sees. `problems_before` is what proves it raised nothing.
        #
        # DELIBERATELY NARROW, SIX ways, because an exemption that is wider than its justification
        # is how a guard stops guarding. IT SAID "FOUR" AND WAS TWO SHORT, and both missing ones
        # were reproduced by the independent review -- 5 was CLAIMED in prose and not implemented,
        # 6 was not thought of at all. A condition that exists only in a comment is not a condition:
        #   1. SECTION form only. A whole-file post-state claim is the granularity ORDER-731 C1
        #      measured at ~2 owner signatures a day; accepting it here would swap one coarse
        #      instrument for another.
        #   2. `kind == STALE` only. A MISSING note means the destination was DELETED, and that is
        #      not the approval succeeding -- it still demands the owner.
        #   3. the post-state claim must have VERIFIED. If F13/F14 reddened, there is no working
        #      replacement instrument and the whole-store pin is all that is left, so it stands.
        #   4. no claim at all = no exemption. That is also the defect this order lists as #4
        #      ("an APPROVED record may carry no expected_post_state, so the front guard pins
        #      nothing"), and it must not be reachable through this door.
        #   5. (ORDER-1310 #3) the executed transfer must be THIS OWNER'S OWN. The destination set
        #      is derived from `r['current_owner']` here rather than from all of D1, so a row
        #      cannot inherit an exemption from a path some other row donated.
        #   6. (ORDER-1310 #1) the claim must name THE APPROVED SECTION, not any section that
        #      resolves. F7 forces the right FILE and F13/F14 force the claim to reproduce; both
        #      were satisfied by a correctly-hashed claim on an unrelated stable heading. Which
        #      section is the approved one is asked of the DESTINATION STORE
        #      (`declared_owner_section`), never of a list of headings in here.
        #
        # PRINTED, never silent. A pin that is not enforced and says nothing is exactly
        # memory `guard-disarmed-by-prose-reported-as-note`, which is the shape this same order
        # was written to fix one layer up.
        # `len(problems) == problems_before` is an ADDITIONAL condition, not a restatement of the
        # helper's. The helper re-resolves the section claim; this says no OTHER F-check (F6 two
        # forms, F7 binding a foreign path, F9 the path absent at HEAD, F10 a directory) reddened
        # for this row either. A record that is broken in any of those ways has not earned an
        # exemption from a different check.
        _exempt = pin_exemption_reason(
            note, eps, executed_transfer_destinations(_D1_ROWS, r['current_owner']), digest)
        if _exempt and len(problems) == problems_before:
            PIN_NOTES.append('line %s: %s' % (n, _exempt))
            note = None
        if note:
            ack = r.get('stale_pin_acknowledgement')
            # audit 8 MAJOR 5: this was `not row.get('stale_pin_acknowledged')`, so the STRING
            # "false" -- which reads as a refusal to acknowledge -- granted the exemption. Boolean
            # identity now, plus a structured record whose contents are recomputed below.
            if r.get('stale_pin_acknowledged') is not True or not isinstance(ack, dict):
                # ORDER-731 review M1: this message used to name only `current_owner`, while F3
                # demands the ack name the PINNED path -- so when the two differ (option 2), the
                # message guided the signer to exactly the line F3 refuses. The path the ack must
                # name is stated here, once, from the note itself.
                problems.append('F2 line %s attests for %r whose pin is STALE. The pinned path is '
                                '%r -- the acknowledgement must name THAT path (F3 refuses any '
                                'other). Set "stale_pin_acknowledged": true (JSON boolean, not a '
                                'string) AND a "stale_pin_acknowledgement" object naming '
                                '{path: %r, pinned_blob, current_blob}, or re-pin with '
                                'gen_s2a_migration.py.'
                                % (n, r['current_owner'], note['path'], note['path']))
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
        # ORDER-1269 #3: a row that raised problems OF ITS OWN is recorded here, so that what
        # `check()` RETURNS is unchanged -- see IN_FORCE_FAILED for why that distinction is not
        # cosmetic. The demotion happens on the printed line, which is what was ratified.
        if len(problems) != problems_before:
            IN_FORCE_FAILED[r['current_owner']] = n
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
    try:
        derived_problems = derived_artifact_problems(_src())
    except evidence.ToolFailure as exc:
        print('[TOOL FAILURE] cannot validate generated handout: %s' % exc)
        return 2

    if '--template' in argv:
        if derived_problems:
            for problem in derived_problems:
                print('  -> %s' % problem)
            return 1
        owner = 'MASTER_BACKLOG.md'
        line = {
            'bundle_sha256': digest,
            'current_owner': owner,
            'decision': 'APPROVED',
            'signer': 'user (Boss)',
            'decided_at': '<YYYY-MM-DDTHH:MM>',
            'reason': '<why - required for REFUSED, good practice for APPROVED>',
        }
        # ORDER-731 review M2: the post-state claim is carried FORWARD from the record in force.
        # `expected_post_state` is optional (F6-F14 sit inside `if eps is not None`), so a line in
        # the bare template shape passes GREEN with no post-state claim at all -- the section pin
        # option A bought would evaporate at the next signature by DEFAULT rather than by decision.
        # The values are the in-force record's own; F11/F14 recompute them and refuse stale ones,
        # so carrying them forward can mislead nobody.
        rows_t, _ = load_records()
        prev = in_force_map(rows_t, d1_owners, problems=[]).get(owner) or {}
        eps_prev = prev.get('expected_post_state')
        if isinstance(eps_prev, dict):
            line['expected_post_state'] = eps_prev
        # ORDER-731 review M1: when a note exists, the ack skeleton is emitted WITH the path the
        # checker will actually demand -- through the SAME mapping F2-F5 enforce (note_for_owner),
        # never through `current_owner`, which is a different question since option 2. The blobs
        # are filled with the recomputed values a correct ack must carry; F4/F5 verify them again
        # on every run, so a stale template is refused, not believed.
        stale_t = {n['path']: n for n in chk.pin_vintage_notes(d1)
                   if isinstance(n, dict) and n.get('path')}
        note_t = note_for_owner(stale_t, owner_ref_paths(d1), owner)
        # ORDER-1269 #1: through the SAME predicate F2 uses, so the handout and the checker cannot
        # disagree about whether an acknowledgement is owed. Without this line the template would
        # hand the owner a skeleton for a pin that is no longer enforced -- asking for a signature
        # nothing demands, which is #2 of this order pointing the other way.
        if note_t and pin_exemption_reason(note_t, eps_prev,
                                           executed_transfer_destinations(d1, owner), digest):
            note_t = None
        if note_t:
            pinned_t = next((row['owner_ref']['blob_oid'] for row in d1
                             if row.get('owner_ref')
                             and row['owner_ref']['path'] == note_t['path']), None)
            rc_t, live_t, _ = chk._rev_parse_cached('%s:%s' % (chk.head_oid(), note_t['path']))
            line['stale_pin_acknowledged'] = True
            line['stale_pin_acknowledgement'] = {
                'path': note_t['path'],
                'pinned_blob': pinned_t,
                'current_blob': live_t if rc_t == 0 else 'MISSING',
                'reason': '<why this divergence is the approved change>',
            }
        print('# Append ONE line to %s. Nothing else changes -- no guard, no generator, no D1 edit.'
              % ATTESTATION_PATH)
        print(json.dumps(line, sort_keys=True))
        return 0

    print('=== ORDER-602 A (rescoped): S2a ATTESTATION log ===')
    print('NOTE: this records that a decision was WRITTEN DOWN against specific bytes.')
    print('      It does NOT prove who made it -- this repo commits under one git identity, so')
    print('      nothing here separates the owner from any other writer. Do not cite it as a')
    print('      signature. (Codex audit 8.)')
    print('bundle : %s (authoritative D1 + reconciliation + migration checker + POLICY + VECTORS; '
          'D2 is a separately verified deterministic projection)' % digest[:16])
    print('log    : %s\n' % ATTESTATION_PATH)

    rows, problems = load_records()
    check_append_only(problems)
    vintage = chk.pin_vintage_notes(d1)
    try:
        current = check(rows, problems, digest, d1_owners, vintage)
    except evidence.ToolFailure as exc:
        print('[TOOL FAILURE] cannot resolve authorization metadata: %s' % exc)
        return 2
    if derived_problems:
        problems.extend(derived_problems)
        # Keep the human-facing decision fail-closed as well as the exit code. A derived artifact
        # failure is not permission to print the last owner decision as APPROVED.
        IN_FORCE_FAILED['MASTER_BACKLOG.md'] = 'derived handout'

    # RESCOPED (audit 8 section 2): ORDER-600 blocks on ONE decision, not on all 23 owners.
    coverage = current.get('MASTER_BACKLOG.md')
    # `.get`, because the in-force entry may be G3's UNVERIFIED placeholder, which carries no
    # signer by design -- it reports that the record in force did not verify, and pretending it
    # had a signer would put words in a row that failed. Found live: this line crashed with
    # KeyError the first time an F1-failed row was in force, i.e. the exact situation a bundle
    # change creates, on the day the bundle changed.
    print('  THE decision ORDER-600 blocks on:')
    # ORDER-1269 #3: through `reported_decision`, so a record that failed its own checks cannot be
    # announced as APPROVED four lines above its own failure.
    _dec, _note = reported_decision(coverage, 'MASTER_BACKLOG.md') if coverage else (None, None)
    auth = authorization_status(coverage, require=False, action='coverage_transfer') \
        if coverage else None
    print('    MASTER_BACKLOG.md (Coverage edge) -> %s'
          % ('%s [%s; signer display-only] (line %s)%s'
             % (_dec, auth['authorization_state'] if auth else 'NOT_AUTHORITATIVE',
                coverage['_line'], ' -- ' + _note if _note else '')
             if coverage else 'NOT YET RECORDED'))
    others = [o for o in d1_owners if o in current and o != 'MASTER_BACKLOG.md']
    print('  %d other owner(s) recorded, %d not yet -- none of them block ORDER-600'
          % (len(others), len(d1_owners) - len(current)))
    if vintage:
        print('  %d pin-vintage note(s); blocking only for the owners they name' % len(vintage))
    for pn in PIN_NOTES:
        print('  PIN NOT ENFORCED -> %s' % pn)

    if '--require-authorization' in argv:
        print('  owner-reserved consumer: Coverage transfer requires a resolved authorization_ref')
        if problems:
            print('  -> AUTH-ATTESTATION-INVALID current attestation ledger is not valid')
            return 1
        if not coverage:
            print('  -> AUTH-ABSENT Coverage has no current attestation')
            return 1
        required = authorization_status(coverage, require=True,
                                         action='coverage_transfer')
        if coverage.get('decision') != 'APPROVED':
            required['problems'].insert(0,
                                        'AUTH-DECISION Coverage current decision is %r, not APPROVED'
                                        % coverage.get('decision'))
        if required['problems']:
            for p in required['problems']:
                print('  -> %s' % p)
            return 1
        print('  -> AUTHORIZED_BY_RESOLVED_REF (owner authorization source is independently '
              'validated; signer remains display-only)')

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
