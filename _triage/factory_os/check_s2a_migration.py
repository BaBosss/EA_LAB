"""
check_s2a_migration.py - ORDER-600 (S2a) deliverable D3: the checker.

WHY THIS EXISTS, AND WHY IT IS WRITTEN BEFORE THE DATA
  ORDER-600's own words: "A criterion with no line in this file is not acceptance; it is a wish."
  Codex audit 5 closed rev 1 of that order by constructing, for every criterion, the cheapest
  output that met the letter and defeated the purpose -- 27 rows named from `$defs`, a constant in
  every hash field, and no migration proposed at all. So this file is built FIRST, against no data,
  which means the data cannot be shaped to whatever the checker happened to accept. It refuses an
  empty file, and it refuses the null migration.

WHAT IT ASSERTS  (the nine MACHINE criteria of ORDER-600 rev 4, one function each)
  C1  entity set == the generated __STORAGE__ row set, by SET EQUALITY, read from the generator
  C2  zero rows with signoff_state == APPROVED
  C3  owner vocabulary: current_owner exists at HEAD; proposed_owner exists or is in PLANNED_PATHS
  C4  owner_ref is RECOMPUTED from git, not shaped: blob_oid and raw_sha256 both verified
  C5  owner_ref values distinct across rows unless same_blob_reason is given
  C6  exactly one sign-off row per distinct current_owner, each with a named signer
  C7  the Coverage edge row is present and explicit
  C8  coverage counting is RECONCILED: source_rows_consumed vs cells_emitted, mapped, not equated
  C9  reverse_steps / evidence_lost / retention_window non-empty on every row

TWO SPEC DECISIONS THIS FILE MAKES, both recorded rather than assumed
  1. The coverage reconciliation (C8) lives in a SEPARATE file, not as a row in the jsonl. It cannot
     be a row: C1 demands the entity set equal the __STORAGE__ set exactly, so a `__META__` entity
     would fail C1. Path: factory_os/s2a_coverage_reconciliation.json.
  2. `EMBEDDED:<Parent>` and a null `owner_ref` are legal only under the rev-4 amendment, and only
     with a stated reason. C4 still recomputes every ref that IS claimed.

NOT IN THE PRE-COMMIT TIER, AND MUST NOT BE UNTIL D1 EXISTS
  It exits 2 while `factory_os/s2a_migration.jsonl` is absent, which is correct behaviour and would
  make the fast tier permanently red. Wire it in the same commit that lands D1 -- and note the tier
  has zero headroom (median 14.8s of a 15.0s advisory budget), so it belongs in the existing
  `run_contract_binding_tests.ps1` python wrapper rather than as a new PowerShell suite. `--self-test`
  needs no data and can be run at any time; that is the mode that proves this file is not a wish.

USAGE  python _triage/factory_os/check_s2a_migration.py [--self-test]
EXIT   0 = every criterion holds · 1 = at least one does not · 2 = the inputs are missing
"""
import hashlib
import io
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_design_contracts as gen  # noqa: E402  -- C1 reads the entity set from the generator

# rev 5: these were `factory_os/...`, which resolves to a REPO-ROOT directory that does not exist and
# where no other artifact of this slice lives. Every sibling path here is root-relative WITH the
# `_triage/` prefix, and D2 in the order carries that prefix -- the bare form was shorthand for a
# location, and implementing it literally would have scattered the deliverable outside the slice.
MIGRATION_PATH = '_triage/factory_os/s2a_migration.jsonl'
COVERAGE_PATH = '_triage/factory_os/s2a_coverage_reconciliation.json'

REQUIRED_FIELDS = ('entity', 'current_owner', 'proposed_owner', 'disposition',
                   'canonical_or_derived', 'owner_ref', 'breaks_if_moved', 'breaks_if_not_moved',
                   'signoff_owner', 'signoff_state', 'reverse_steps', 'evidence_lost',
                   'retention_window')

DISPOSITIONS = ('TRANSFER', 'KEEP', 'RETIRE')
SIGNOFF_STATES = ('PROPOSED', 'REFUSED')          # APPROVED is the owner's act, not this order's

# ORDER-600 rev 4: a proposed_owner may name a file that does not exist yet -- 11 of the 27
# entities are in that position and the order forbids creating them -- but it must be a DECLARED
# future path, so a typo is still caught. Adding a line here is a reviewable act.
PLANNED_PATHS = (
    'factory/hypotheses.jsonl',
    'factory/parameter_bindings.jsonl',
    'factory/universe.jsonl',
    'factory/instrument_profiles.jsonl',
    'factory/coverage.jsonl',
    'factory/magic_allocations.jsonl',
    'factory/runs/',                  # per-run file, one per run_id
    'factory/candidates/',            # per-candidate file
    'ops/findings.jsonl',
    'ops/receipts/',
    'build/safe_projection.json',
)

COVERAGE_CURRENT_OWNER = 'MASTER_BACKLOG.md'
COVERAGE_PROPOSED_OWNER = 'factory/coverage.jsonl'

# ORDER-600 rev 5: four of the 27 entities have NEITHER a file nor a parent entity -- design 1.3 #2 says
# Test Universe is "genuinely unowned" in as many words. C3 as written left them three options, all
# illegal: name a real file (a false claim about today), claim EMBEDDED (false, nothing references them),
# or omit the row (C1 fails set equality). This sentinel is the fourth. It is deliberately NOT a free
# pass: see c3_owner_vocabulary, which opens unowned_evidence rather than believing it.
# ORDER-602 B RETIRED the single `UNOWNED` value in favour of the four states below. The name is kept
# ONLY so that a stale row still carrying it fails loudly through the normal path-existence check
# ("does not exist at HEAD") rather than crashing an importer. It is not a legal owner value and
# nothing branches on it -- if you are reading this while adding a state, add it to OWNER_STATES.
UNOWNED = 'UNOWNED'      # retired; see OWNER_STATES

# Codex audit 7 BLOCKER 1. The rev-5 guard required `unowned_evidence` to be a tracked file that
# MENTIONS the entity -- and `_triage/factory_os/schemas.json` DEFINES all 27 entities, so it mentions
# every one of them. Declaring all 27 `UNOWNED` with schemas.json as evidence passed C3, which then
# handed every row C4's null-pin exemption, and the whole file passed with exit 0.
#
# A substring cannot establish an ownership claim. What can is a CLOSED declaration: the entities
# permitted to be UNOWNED are listed here, each with the design statement that establishes it, and
# adding a line is a reviewable act -- the same shape as PLANNED_PATHS. An entity absent from this map
# may not be UNOWNED at all, so the attack cannot scale past the four rows that are genuinely unowned.
#
# The second value is the CLAIM ITSELF, quoted verbatim from the cited file -- not the entity name and
# not a keyword near it. Checking proximity to the entity name was tried first and was wrong for a
# reason worth keeping: design 1.3 states the verdict against the human phrase "Test Universe", and
# never against the schema identifier `TestUniverse`, so a name-proximity test failed on a citation
# that is actually correct. Verifying the sentence that carries the claim is both stronger and honest:
# if the design is reworded, this goes red and a human must re-establish the claim, which is exactly
# what should happen to a citation whose source moved.
# ORDER-602 B (audit 7 MAJOR 4): the four rows are NOT one kind of thing, and collapsing them into a
# single `UNOWNED` is what made the escape broad enough for the blocker to walk through. Each state now
# carries its OWN disposition rule, so "a governance gap", "not built yet" and "correctly not persisted"
# can no longer borrow each other's exemption.
#
#   NO_CURRENT_OWNER      a canonical fact nobody owns; the missing owner IS the migration subject
#                         -> must TRANSFER (it is here to get a first owner)
#   NOT_YET_BUILT         a planned part of a contract that does not exist yet
#                         -> must TRANSFER
#   DERIVED_NOT_PERSISTED derived output that is written somewhere but owns no source of truth
#                         -> must TRANSFER, and must be `derived`
#   TRANSIENT             correctly never persisted, now or later -> must KEEP, and must be `derived`
OWNER_STATES = ('NO_CURRENT_OWNER', 'NOT_YET_BUILT', 'DERIVED_NOT_PERSISTED', 'TRANSIENT')
STATE_DISPOSITION = {
    'NO_CURRENT_OWNER':      ('TRANSFER',),
    'NOT_YET_BUILT':         ('TRANSFER',),
    'DERIVED_NOT_PERSISTED': ('TRANSFER',),
    'TRANSIENT':             ('KEEP',),
}
STATE_REQUIRES_DERIVED = ('DERIVED_NOT_PERSISTED', 'TRANSIENT')

# entity -> (state, evidence path, the claim sentence quoted verbatim from that file)
UNOWNABLE = {
    'TestUniverse':   ('NO_CURRENT_OWNER', '_triage/EA_LAB_FACTORY_OS_DESIGN.md',
                       'No canonical artifact exists for a versioned mandatory symbol'),
    'LogicalSymbol':  ('NOT_YET_BUILT', '_triage/EA_LAB_FACTORY_OS_DESIGN.md',
                       'broker symbol per lane'),
    'SafeProjection': ('DERIVED_NOT_PERSISTED', '_triage/EA_LAB_FACTORY_OS_DESIGN.md',
                       'Generated projections go to'),
    'RunJournal':     ('TRANSIENT', '_triage/factory_os/schemas.json',
                       'Never persisted, never written'),
}


def fail(problems, msg):
    problems.append(msg)


def _git(*args):
    p = subprocess.run(('git',) + args, capture_output=True, text=True)
    return p.returncode, p.stdout.strip(), p.stderr.strip()


# Per-process memo for the two git reads C4 makes. This is CORRECT, not a shortcut: git objects are
# content-addressed, so `commit:path` resolves to the same blob and a blob's bytes are immutable for
# the life of a process. Measured need: run_s2a_migration_tests.py re-runs C4 for 24 mutations x ~14
# pinned rows = ~670 git spawns, and took 29.8s -- twice the entire pre-commit tier's budget. This is
# the ORDER-270 pathology at small scale (memory: a chain-walk spawning 3 git subprocesses per commit),
# so it is fixed the same way: stop spawning for an answer already known.
_REVPARSE_MEMO = {}
_BLOB_MEMO = {}
_PARENTS_MEMO = []
_ENTITIES_MEMO = []
_HEAD_MEMO = []
_FINGERPRINT = []


def head_oid():
    """Resolve the symbolic HEAD ONCE, to an immutable OID.

    Codex audit 7 MODERATE 9, accepted. `commit_oid:path` and blob bytes are content-addressed, so
    caching them is sound. `HEAD:path` is NOT -- HEAD is a moving reference, and this repository has
    concurrent writers (memory `shared-worktree-concurrent-writers`). A cached `HEAD:path` answer can
    therefore describe a commit that is no longer HEAD by the time the result is printed. Resolving
    once and keying every later lookup by that OID makes the whole run describe one commit.
    """
    if not _HEAD_MEMO:
        rc, out, _ = _git('rev-parse', 'HEAD')
        _HEAD_MEMO.append(out if rc == 0 else None)
    return _HEAD_MEMO[0]


def input_fingerprint():
    """(HEAD oid, index size+mtime) -- the identity of what this run is judging.

    `tracked_paths()` caches `git ls-files`, and the old comment claimed the index "cannot change
    underneath a single check run". In a repo with concurrent writers that is an assumption, not a
    fact. Rather than give up the cache (the mutation suite calls the criteria 25+ times), the run
    records what it read at the start and REFUSES to report a verdict if it moved -- a stale answer is
    turned into a tool failure instead of a quiet pass.
    """
    # CONTENT-based, not mtime-based, and that distinction is load-bearing. The first version stat'ed
    # .git/index -- but git rewrites the index during an ordinary commit, and this check runs INSIDE
    # the pre-commit tier, so a stat-based fingerprint would abort the tier for a reason that has
    # nothing to do with the data.
    #
    # audit 8 MAJOR 6, TWO defects, both mine:
    #  (1) this used the MEMOIZED head_oid(), so the end-of-run comparison compared the starting HEAD
    #      with the starting HEAD and could never observe HEAD moving. A guard written to detect
    #      movement, built so that it cannot. `rev-parse HEAD` is read FRESH here -- the memo stays,
    #      but only as the stable key for object lookups, which is what it is actually for.
    #  (2) it covered HEAD and the index while the judged inputs -- D1, the reconciliation,
    #      MASTER_BACKLOG.md and the schema -- are read from the WORKING TREE and could change
    #      without moving either. They are hashed directly now.
    rc, live_head, _ = _git('rev-parse', 'HEAD')
    rc2, out, _ = _git('ls-files', '-s')
    h = hashlib.sha256(out.encode('utf-8', 'replace')) if rc2 == 0 else None
    for path in (MIGRATION_PATH, COVERAGE_PATH, 'MASTER_BACKLOG.md', gen.SCHEMA_PATH):
        if h is None:
            break
        try:
            with io.open(path, 'rb') as fh:
                h.update(hashlib.sha256(fh.read().replace(b'\r\n', b'\n')).digest())
        except IOError:
            h.update(b'<absent>')
    return ((live_head if rc == 0 else None), h.hexdigest() if h else None)


def _rev_parse_cached(spec):
    if spec not in _REVPARSE_MEMO:
        _REVPARSE_MEMO[spec] = _git('rev-parse', spec)
    return _REVPARSE_MEMO[spec]


def _blob_sha256_cached(blob_oid):
    if blob_oid not in _BLOB_MEMO:
        p = subprocess.run(['git', 'cat-file', 'blob', blob_oid], capture_output=True)
        _BLOB_MEMO[blob_oid] = (p.returncode,
                                hashlib.sha256(p.stdout).hexdigest() if p.returncode == 0 else None)
    return _BLOB_MEMO[blob_oid]


_TRACKED_MEMO = []


def tracked_paths():
    # Memoized for the same reason as the blob reads, and it matters more: the mutation suite calls
    # every criterion 25 times in one process, so an un-memoized `git ls-files` over this repo was
    # being paid 25 times and was the single largest cost in the suite. The index cannot change
    # underneath a single check run.
    if not _TRACKED_MEMO:
        rc, out, _ = _git('ls-files')
        if rc != 0:
            return None
        _TRACKED_MEMO.append(set(out.split('\n')))
    return _TRACKED_MEMO[0]


def storage_entities():
    """C1's source of truth: the entities the generated __STORAGE__ block actually lists.

    Read from the schema through the generator rather than hardcoded. ORDER-600 says "do not
    hardcode 24" -- and the number is 27 today, which is exactly why hardcoding it would have
    silently drifted.
    """
    # Memoized alongside the $ref graph and `git ls-files`. /scrutinize caught that this one was
    # missed: it re-parses the whole schema on every C1 call, which the mutation suite makes 25 times
    # in one process. Same cost class as the two that were fixed, so it should not have been left out.
    if not _ENTITIES_MEMO:
        with io.open(gen.SCHEMA_PATH, encoding='utf-8') as fh:
            schema = json.load(fh)
        _ENTITIES_MEMO.append(set(k for k, v in schema['$defs'].items() if isinstance(v, dict)))
    return set(_ENTITIES_MEMO[0])


def _schema_defs():
    with io.open(gen.SCHEMA_PATH, encoding='utf-8') as fh:
        return json.load(fh)['$defs']


def _schema_owner_file(entity):
    """The bare path the schema names as this entity's owner, or None.

    audit 8 MODERATE 8: used to recompute an owner-state claim instead of believing a substring. The
    schema's `x-owner-file` carries prose around the path ("portfolio/ATTESTATION_MAP.csv (EXISTING)
    + append-only event log"), so the first token is taken and the prose ignored.
    """
    v = _schema_defs().get(entity)
    if not isinstance(v, dict):
        return None
    raw = v.get('x-owner-file')
    if not raw or not isinstance(raw, str):
        return None
    first = raw.strip().split()[0]
    return first if '/' in first or '.' in first else None


def _schema_says_unpersisted(entity):
    """Does the schema itself describe this entity as derived or never persisted?"""
    v = _schema_defs().get(entity)
    if not isinstance(v, dict):
        return False
    if v.get('x-derived') is True:
        return True
    raw = (v.get('x-owner-file') or '')
    low = raw.lower()
    return raw.strip().startswith('NONE') or 'never persisted' in low or 'derived' in low


def ref_parents():
    """Which entities actually $ref each entity -- the EMBEDDED claim, RECOMPUTED.

    rev 5. `EMBEDDED:<Parent>` was previously believed on sight, so `EMBEDDED:Anything` would have passed
    and taken the KEEP exemption with it. The schema already knows the answer; asking it costs one pass.
    This is the same question that found every real defect in this slice: the row states a parent, and
    the checker was trusting the half it could have computed.
    """
    import re as _re
    if _PARENTS_MEMO:
        return _PARENTS_MEMO[0]
    with io.open(gen.SCHEMA_PATH, encoding='utf-8') as fh:
        defs = json.load(fh)['$defs']
    parents = {}
    for owner, body in defs.items():
        if not isinstance(body, dict):
            continue
        for m in _re.finditer(r'"#/\$defs/([A-Za-z0-9_]+)"', json.dumps(body)):
            child = m.group(1)
            if child != owner:
                parents.setdefault(child, set()).add(owner)
    _PARENTS_MEMO.append(parents)
    return parents


# ---------------------------------------------------------------------------- criteria

def c1_entity_set(rows, problems):
    expected = storage_entities()
    got = [r.get('entity') for r in rows]
    dupes = sorted({e for e in got if got.count(e) > 1})
    if dupes:
        fail(problems, 'C1 duplicate entity rows: %s' % dupes)
    missing = sorted(expected - set(got))
    extra = sorted(set(got) - expected)
    if missing:
        fail(problems, 'C1 %d entity/entities in the schema have no migration row: %s'
             % (len(missing), missing))
    if extra:
        fail(problems, 'C1 row(s) for entities the schema does not define: %s' % extra)


def c2_no_approved(rows, problems):
    bad = [r.get('entity') for r in rows if r.get('signoff_state') == 'APPROVED']
    if bad:
        fail(problems, 'C2 %d row(s) write signoff_state=APPROVED, which is the owner\'s act in '
                       'their own commit, not this order\'s: %s' % (len(bad), bad))
    for r in rows:
        if r.get('signoff_state') not in SIGNOFF_STATES:
            fail(problems, 'C2 %s has signoff_state=%r, not one of %s'
                 % (r.get('entity'), r.get('signoff_state'), list(SIGNOFF_STATES)))
        # /scrutinize 2026-07-30: REFUSED was accepted bare. D2 tells the owner that "a refusal with
        # a stated reason closes the question; silence leaves it open and it comes back" -- so the
        # document made a promise the checker did not keep. An unexplained REFUSED is also the
        # cheapest way to make a row look considered without deciding anything.
        if r.get('signoff_state') == 'REFUSED' and not (r.get('refused_reason') or '').strip():
            fail(problems, 'C2 %s is REFUSED with no refused_reason -- a refusal without a stated '
                           'reason does not close the question, it just hides it'
                 % r.get('entity'))


def _check_embedded_claim(e, value, rows_entities, parents, problems):
    """rev 5: verify an `EMBEDDED:<Parent>` claim against the $ref graph instead of believing it."""
    claim = value.split(':', 1)[1].strip()
    if claim == '*':
        listed = [p for p in (rows_entities.get(e) or []) if p]
        if len(listed) < 2:
            fail(problems, 'C3 %s uses EMBEDDED:* but embedded_in lists %d parent(s); the wildcard is '
                           'for a primitive with MANY parents, so it needs at least 2 named and verified'
                 % (e, len(listed)))
            return
        wrong = [p for p in listed if p not in parents.get(e, set())]
        if wrong:
            fail(problems, 'C3 %s claims embedded_in %s but the schema $ref graph says those do not '
                           'reference it (real parents: %s)'
                 % (e, wrong, sorted(parents.get(e, set())) or 'NONE'))
        return
    if claim not in parents.get(e, set()):
        fail(problems, 'C3 %s claims EMBEDDED:%s, but the schema $ref graph says %s does not reference '
                       'it (real parents: %s)'
             % (e, claim, claim, sorted(parents.get(e, set())) or 'NONE'))


def c3_owner_vocabulary(rows, problems, tracked):
    parents = ref_parents()
    embedded_in = {r.get('entity'): r.get('embedded_in') for r in rows}
    for r in rows:
        e = r.get('entity')
        cur = r.get('current_owner') or ''
        prop = r.get('proposed_owner') or ''
        disp = r.get('disposition')
        if cur.startswith('EMBEDDED:'):
            if disp != 'KEEP':
                fail(problems, 'C3 %s is EMBEDDED but disposition=%r; an embedded fact owns no '
                               'file to transfer' % (e, disp))
            _check_embedded_claim(e, cur, embedded_in, parents, problems)
        elif cur in OWNER_STATES:
            # Codex audit 7: the substring form of this guard was defeated by citing a file that
            # mentions every entity. Eligibility is now a CLOSED declaration, and the citation must
            # match the one declared for THAT entity -- an entity may not nominate its own evidence.
            if e not in UNOWNABLE:
                fail(problems, 'C3 %s claims owner state %s but is not declared UNOWNABLE. Only %s '
                               'may be, each with the statement that establishes it; adding one is a '
                               'reviewable edit to check_s2a_migration.py, not a field a row may '
                               'assert about itself.' % (e, cur, sorted(UNOWNABLE)))
            else:
                want_state, want_path, anchor = UNOWNABLE[e]
                if cur != want_state:
                    fail(problems, 'C3 %s declares owner state %s but its declared state is %s -- '
                                   'the four states carry different disposition rules and are not '
                                   'interchangeable' % (e, cur, want_state))
                allowed = STATE_DISPOSITION.get(cur, ())
                if disp not in allowed:
                    fail(problems, 'C3 %s is %s with disposition=%r; that state allows only %s'
                         % (e, cur, disp, list(allowed)))
                if cur in STATE_REQUIRES_DERIVED and r.get('canonical_or_derived') != 'derived':
                    fail(problems, 'C3 %s is %s but canonical_or_derived=%r -- that state exists for '
                                   'derived facts' % (e, cur, r.get('canonical_or_derived')))
                ev = (r.get('unowned_evidence') or '').strip()
                if ev != want_path:
                    fail(problems, 'C3 %s cites unowned_evidence=%r but its declared evidence is %r'
                         % (e, ev, want_path))
                elif ev not in tracked:
                    fail(problems, 'C3 %s declared evidence %r is not tracked at HEAD' % (e, ev))
                else:
                    try:
                        body = io.open(ev, encoding='utf-8', errors='replace').read()
                    except IOError as exc:
                        fail(problems, 'C3 %s evidence %r could not be read: %s' % (e, ev, exc))
                    else:
                        # RECOMPUTED: the claim sentence itself must still be in the cited file.
                        if anchor not in body:
                            fail(problems, 'C3 %s cites %r for being unowned, but the claim %r is no '
                                           'longer in that file -- the citation has rotted and the '
                                           'exemption must be re-established by a human'
                                 % (e, ev, anchor))
                # audit 8 MODERATE 8: a citation is at best corroboration -- two of the four anchors
                # ("broker symbol per lane", "Generated projections go to") describe SHAPE or
                # LOCATION, not non-existence, so they could stay green while the state was false.
                # The part that CAN be computed is now computed: an entity claiming to have no
                # current owner must genuinely have no tracked owner file, and a derived/transient
                # state must agree with the schema. What is left over is judgement, and is labelled
                # as judgement rather than presented as proof.
                declared_owner = _schema_owner_file(e)
                if cur in ('NO_CURRENT_OWNER', 'NOT_YET_BUILT') and declared_owner in tracked:
                    fail(problems, 'C3 %s claims %s, but the schema names %r as its owner file and '
                                   'that file EXISTS at HEAD -- the state is refuted by the repo, '
                                   'whatever the citation says' % (e, cur, declared_owner))
                if cur in STATE_REQUIRES_DERIVED and not _schema_says_unpersisted(e):
                    fail(problems, 'C3 %s claims %s, but the schema does not describe it as derived '
                                   'or never-persisted -- recomputed from x-derived/x-owner-file, '
                                   'not taken from the citation' % (e, cur))
            # (the old blanket "UNOWNED + KEEP must be derived" rule is now carried per state by
            #  STATE_DISPOSITION + STATE_REQUIRES_DERIVED above, which is strictly narrower: only
            #  TRANSIENT may KEEP at all, and it must be derived.)
        elif cur not in tracked:
            fail(problems, 'C3 %s current_owner=%r does not exist at HEAD. current_owner is a '
                           'claim about TODAY.' % (e, cur))
        elif cur.endswith('schemas.json'):
            fail(problems, 'C3 %s names schemas.json as current_owner; the schema DESCRIBES the '
                           'fact, it does not own it' % e)
        if prop.startswith('EMBEDDED:'):
            _check_embedded_claim(e, prop, embedded_in, parents, problems)
            continue
        if prop in OWNER_STATES:
            # Only TRANSIENT proposes staying unowned; the other three exist to GET an owner, so
            # proposing the state as the destination would be proposing nothing.
            if prop != 'TRANSIENT':
                fail(problems, 'C3 %s proposes owner state %s as its DESTINATION. Only TRANSIENT may '
                               'be proposed (it is correctly never persisted); %s exists to acquire '
                               'an owner, so naming it as the destination proposes nothing.'
                     % (e, prop, prop))
            elif disp != 'KEEP':
                fail(problems, 'C3 %s proposes TRANSIENT with disposition=%r; staying unpersisted is '
                               'only expressible as KEEP' % (e, disp))
            continue
        if prop not in tracked and not any(prop.startswith(p) for p in PLANNED_PATHS):
            fail(problems, 'C3 %s proposed_owner=%r neither exists at HEAD nor appears in '
                           'PLANNED_PATHS -- declare it there if it is intended' % (e, prop))


def c4_owner_ref_recomputed(rows, problems):
    """The criterion the rev-1 order failed: a plausible constant must not pass."""
    for r in rows:
        e, ref = r.get('entity'), r.get('owner_ref')
        if ref is None:
            cur = r.get('current_owner') or ''
            # /scrutinize 2026-07-30: this used to accept ANY row that supplied an
            # owner_ref_absent_reason, which made the strongest criterion in the order -- the hash
            # recomputation that killed audit 5's null migration -- bypassable in one line: set
            # owner_ref to null, write any sentence, done. The rev-4 text never allowed that ("a row
            # may only decline one when its current_owner is EMBEDDED:* or names a fact that lives in
            # no file today"); the code was looser than the rule it was enforcing. A reason string
            # explains an exemption, it does not GRANT one -- eligibility comes from current_owner.
            if not (cur.startswith('EMBEDDED:') or cur in OWNER_STATES):
                fail(problems, 'C4 %s declines an owner_ref, but its current_owner is %r -- a real '
                               'file at HEAD has a blob to pin, and no reason string buys an '
                               'exemption from pinning it' % (e, cur))
                continue
            if not (r.get('owner_ref_absent_reason') or '').strip():
                fail(problems, 'C4 %s is exempt from pinning but states no owner_ref_absent_reason'
                     % e)
            continue
        for k in ('path', 'commit_oid', 'blob_oid', 'raw_sha256'):
            if not ref.get(k):
                fail(problems, 'C4 %s owner_ref is missing %s' % (e, k))
        if any(not ref.get(k) for k in ('path', 'commit_oid', 'blob_oid', 'raw_sha256')):
            continue
        spec = '%s:%s' % (ref['commit_oid'], ref['path'])
        rc, blob_oid, err = _rev_parse_cached(spec)
        if rc != 0:
            fail(problems, 'C4 %s owner_ref does not resolve (%s): %s' % (e, spec, err[:70]))
            continue
        if blob_oid != ref['blob_oid']:
            fail(problems, 'C4 %s blob_oid MISMATCH for %s: stated %s, git says %s'
                 % (e, spec, ref['blob_oid'][:12], blob_oid[:12]))
        rc2, digest = _blob_sha256_cached(blob_oid)
        if rc2 != 0:
            fail(problems, 'C4 %s blob %s cannot be read' % (e, blob_oid[:12]))
            continue
        if digest != ref['raw_sha256']:
            fail(problems, 'C4 %s raw_sha256 MISMATCH for %s: stated %s, recomputed %s'
                 % (e, spec, ref['raw_sha256'][:12], digest[:12]))


def pin_vintage_notes(rows):
    """Which pinned owners have CHANGED since they were pinned. Advisory, and deliberately not a
    failure.

    /scrutinize 2026-07-30 found a mixed-vintage hole in this file: C4 validates each `owner_ref`
    against the commit the row pins (correctly -- a pin is historical), while C8 recomputes the
    coverage numbers from the WORKING TREE copy of MASTER_BACKLOG.md. So one artifact can describe two
    different versions of the same file and every criterion stays green. Nothing was wrong with either
    half; what was missing was anyone saying the halves had drifted apart.

    This cannot be an error: a proposal written last week against last week's file is still a valid
    proposal, and failing here would force a re-pin on every unrelated edit -- the exact false alarm
    the --check fix removed. But it must not be silent either, because the judgement columns cite
    specific line numbers (`scripts/check_state.ps1:124`), and a citation into a file that has since
    moved is how a reviewer is quietly misled. So: counted, named, and printed.

    EXPECTED NOISE, so nobody reads it as a defect: `Hypothesis` and `WorkReceipt` both pin
    `AGENT_TASKBOARD.md`, which changes on essentially every order update -- so those two notes
    reappear as soon as anyone touches the board, and that is correct behaviour rather than drift.
    Re-pin (a plain `gen_s2a_migration.py` run) if the proposal is about to be signed; otherwise
    ignore them. Do NOT make this a failure to force the issue: the suite's own PART 4 control was
    first written as "the real D1 draws no notes" and broke immediately for exactly this reason.
    """
    notes = []
    for r in rows:
        ref = r.get('owner_ref')
        if not ref or not ref.get('path') or not ref.get('blob_oid'):
            continue
        head = head_oid()
        if not head:
            continue
        rc, now, _ = _rev_parse_cached('%s:%s' % (head, ref['path']))
        # /scrutinize ORDER-602 H4: these were plain strings, and the sign-off gate decided whether a
        # note applied to an owner by testing `owner in note`. A note about `docs/MASTER_BACKLOG.md.bak`
        # would therefore have blocked signing `MASTER_BACKLOG.md` -- a substring test standing in for
        # an identity test, which is the exact weakness that produced this order. They are structured
        # now, and consumers match on `path`, not on prose.
        if rc != 0:
            # `rc != 0` was skipped silently at first, so a DELETED owner was invisible -- C4 keeps
            # passing because the old pin still resolves at the commit it names. A proposal whose
            # subject no longer exists is moot, and a signer must not have to notice that unaided.
            notes.append({
                'entity': r.get('entity'), 'path': ref['path'], 'kind': 'MISSING',
                'text': '%s pins %s, which NO LONGER EXISTS at HEAD -- the row proposes something '
                        'about a file that is gone, and C4 stays green because the pin still '
                        'resolves at the commit it names' % (r.get('entity'), ref['path'])})
        elif now != ref['blob_oid']:
            notes.append({
                'entity': r.get('entity'), 'path': ref['path'], 'kind': 'STALE',
                'text': '%s pins %s at %s, but HEAD now has %s -- the proposal describes an older '
                        'revision of its own owner' % (r.get('entity'), ref['path'],
                                                       ref['blob_oid'][:12], now[:12])})
    return notes


def c5_refs_distinct(rows, problems):
    seen = {}
    for r in rows:
        ref = r.get('owner_ref')
        if not ref or not ref.get('blob_oid'):
            continue
        key = ref['blob_oid']
        if key in seen and not r.get('same_blob_reason'):
            fail(problems, 'C5 %s and %s pin the same blob with no same_blob_reason'
                 % (seen[key], r.get('entity')))
        seen.setdefault(key, r.get('entity'))


def c6_one_signoff_per_owner(rows, problems):
    """CONSISTENT SIGNER per current_owner -- which is NOT the rule ORDER-600 states.

    Codex audit 7 MAJOR 3, accepted. The order says "exactly one sign-off row per distinct
    `current_owner`". This function has never checked that: it groups rows by owner and requires the
    signer STRING to agree, and it skips `EMBEDDED:*` owners entirely. The real D1 has 5 owners
    carrying more than one row (`UNOWNED` carries 4) and C6 reports green.

    I noticed the weaker half of this myself during /scrutinize -- that the generator assigns signers
    from a dict keyed by owner, so C6 cannot fail against any generated file -- and recorded it as
    "not a defect" instead of asking whether the criterion matched its own name. That was the miss.

    It is renamed rather than reimplemented because the honest fix is not a bigger loop: a migration
    row and a sign-off decision are different records, and one row per owner cannot express both
    (audit 7 MAJOR 2). Making decisions their own append-only artifact is ORDER-602; this stays a
    consistency check until then, and now says so in its own name.
    """
    by_owner = {}
    for r in rows:
        cur = r.get('current_owner') or ''
        if cur.startswith('EMBEDDED:'):
            continue
        by_owner.setdefault(cur, []).append(r)
    for owner, group in sorted(by_owner.items()):
        signers = sorted({(r.get('signoff_owner') or '').strip() for r in group})
        if '' in signers:
            fail(problems, 'C6 %s has row(s) with an empty signoff_owner: %s'
                 % (owner, [r.get('entity') for r in group if not (r.get('signoff_owner') or '').strip()]))
            signers = [s for s in signers if s]
        if len(signers) > 1:
            fail(problems, 'C6 %s has %d different signers across its rows (%s) -- exactly one '
                           'sign-off per distinct current_owner' % (owner, len(signers), signers))


def c7_coverage_edge(rows, problems):
    # The null-migration guard runs FIRST and outside any early return. Found by --self-test:
    # it used to sit after the `if not edge: return` below, so on the null migration -- the exact
    # artifact it was written for, which has no Coverage edge -- it never executed. The guard that
    # matters most was unreachable in the only case that matters most.
    if rows and all(r.get('disposition') == 'KEEP' for r in rows):
        fail(problems, 'C7 EVERY row is KEEP. That is the null migration audit 5 constructed; a '
                       'proposal that proposes nothing is not a proposal.')

    edge = [r for r in rows
            if (r.get('current_owner') or '').startswith(COVERAGE_CURRENT_OWNER)
            and r.get('proposed_owner') == COVERAGE_PROPOSED_OWNER]
    if not edge:
        fail(problems, 'C7 the Coverage edge row is ABSENT: no row moves %s (section 2) to %s. '
                       'Its absence fails the order -- rev 1 could omit the entire point.'
             % (COVERAGE_CURRENT_OWNER, COVERAGE_PROPOSED_OWNER))
        return
    for r in edge:
        if r.get('disposition') not in ('TRANSFER', 'KEEP'):
            fail(problems, 'C7 the Coverage edge row has disposition=%r, expected TRANSFER or KEEP'
                 % r.get('disposition'))
        if not (r.get('signoff_owner') or '').strip():
            fail(problems, 'C7 the Coverage edge row has no named signoff_owner')
        # Codex audit 7: the all-KEEP guard above is proposal-WIDE, so a single unrelated decoy
        # transfer satisfied it while the Coverage row itself proposed nothing -- which is the one
        # row this order exists to put in front of an owner. The decision must live on THAT row.
        if r.get('disposition') == 'KEEP':
            if r.get('signoff_state') != 'REFUSED':
                fail(problems, 'C7 the Coverage edge row is KEEP with signoff_state=%r. Leaving the '
                               'coverage matrix where it is IS a decision, so it must be recorded as '
                               'REFUSED with a reason -- a KEEP that is merely PROPOSED proposes '
                               'nothing, and this is the row the order exists for.'
                     % r.get('signoff_state'))
            elif not (r.get('refused_reason') or '').strip():
                fail(problems, 'C7 the Coverage edge row refuses the transfer with no refused_reason')


SECTION2_HEADING = '## 2. COVERAGE MATRIX'


def parse_section2(path='MASTER_BACKLOG.md'):
    """Recompute section 2's source rows and their LIVE cells FROM THE FILE.

    /scrutinize round 3 found the asymmetry this closes: C4 recomputes every hash from git, while
    C8 read `MASTER_BACKLOG.md` not at all -- it only checked that D1's numbers agreed with D1's own
    mapping. That is exactly the defect Codex audit 6 found in verify_snapshot one directory over
    (recompute the verdict, trust the evidence), sitting one criterion away from the code that gets
    it right.

    Cross-checked against the order's own measurement: ORDER-600 states section 2 has 7 EA rows and
    8 LIVE cells because ST_EA03 carries GBPUSD H1 AND USDCAD H1. This parser independently returns
    7 and 8. Two derivations agreeing is why the numbers below are trusted; if they had disagreed,
    one of us would have been wrong and that would have needed finding out first.
    """
    lines = io.open(path, encoding='utf-8').read().replace('\r\n', '\n').split('\n')
    try:
        start = next(i for i, l in enumerate(lines) if l.startswith(SECTION2_HEADING))
    except StopIteration:
        return None
    out = []
    for line in lines[start + 1:]:
        if line.startswith('## '):
            break
        if not line.startswith('|'):
            if out:
                break
            continue
        cells = [c.strip() for c in line.strip().strip('|').split('|')]
        if not cells or cells[0].lower() == 'ea':
            continue
        if set(''.join(cells)) <= set('-: '):
            continue
        live_raw = cells[2] if len(cells) > 2 else ''
        live_raw = live_raw.replace('**', '')
        live_raw = __import__('re').sub(r'\(.*?\)', '', live_raw)
        live = [c.strip() for c in live_raw.split('·') if c.strip()]
        # Codex audit 7: C8 accepted 32 bare "junk" strings as cells. The raw text of the
        # other-symbols column is carried so every NON-LIVE cell can be checked back against the
        # source it claims to come from, instead of being counted and believed.
        out.append({'source_row': cells[0], 'live_cells': live,
                    'other_raw': cells[5] if len(cells) > 5 else ''})
    return out


def c8_coverage_reconciled(problems):
    if not os.path.exists(COVERAGE_PATH):
        fail(problems, 'C8 %s is missing: the two coverage numbers must be REPORTED with a '
                       'mapping, not asserted equal' % COVERAGE_PATH)
        return
    with io.open(COVERAGE_PATH, encoding='utf-8') as fh:
        cov = json.load(fh)
    for k in ('source_rows_consumed', 'cells_emitted', 'mapping'):
        if k not in cov:
            fail(problems, 'C8 %s has no %r' % (COVERAGE_PATH, k))
    if any(k not in cov for k in ('source_rows_consumed', 'cells_emitted', 'mapping')):
        return
    # RECOMPUTED from section 2, not taken from D1. The previous version asserted only that the two
    # numbers differ, which is a fragile proxy: it is a claim about today's section-2 content, so it
    # would fail a correct file the day every EA has exactly one cell. Deriving the real numbers is
    # both stronger and stable.
    section2 = parse_section2()
    if section2 is None:
        fail(problems, 'C8 could not find %r in MASTER_BACKLOG.md, so nothing was recomputed. That '
                       'is a tool failure, not a clean check.' % SECTION2_HEADING)
        return
    recomputed_rows = len(section2)
    recomputed_live = sum(len(r['live_cells']) for r in section2)
    if cov['source_rows_consumed'] != recomputed_rows:
        fail(problems, 'C8 source_rows_consumed is %r but section 2 actually has %d EA rows -- '
                       'every source row must be consumed exactly once'
             % (cov['source_rows_consumed'], recomputed_rows))
    # cells_emitted may legitimately EXCEED the LIVE count: the order notes the rejected/attempted
    # column holds many more. It may never be LESS, because the LIVE cells are a subset.
    if isinstance(cov['cells_emitted'], int) and cov['cells_emitted'] < recomputed_live:
        fail(problems, 'C8 cells_emitted is %d but the LIVE column alone normalises to %d cells; '
                       'LIVE cells are a subset of all cells, so this number cannot be smaller'
             % (cov['cells_emitted'], recomputed_live))
    # ...and the mapping must actually carry each row's LIVE cells, which is what makes copying one
    # total into both fields impossible: ST_EA03 forces at least one row to hold two cells.
    by_row = {}
    for m in cov['mapping']:
        by_row.setdefault((m.get('source_row') or '').strip(), []).extend(m.get('cells', []))
    for r in section2:
        got = by_row.get(r['source_row'].strip())
        if got is None:
            fail(problems, 'C8 the mapping has no entry for section-2 row %r' % r['source_row'])
            continue
        labels = {(c.get('cell') if isinstance(c, dict) else c) for c in got}
        missing = [c for c in r['live_cells'] if c not in labels]
        if missing:
            fail(problems, 'C8 the mapping for %r omits its LIVE cell(s) %s'
                 % (r['source_row'], missing))
    mapped = sum(len(m.get('cells', [])) for m in cov['mapping'])
    if mapped != cov['cells_emitted']:
        fail(problems, 'C8 the mapping accounts for %d cells but cells_emitted is %d'
             % (mapped, cov['cells_emitted']))
    if len(cov['mapping']) != cov['source_rows_consumed']:
        fail(problems, 'C8 the mapping covers %d source rows but source_rows_consumed is %d -- '
                       'every source row must be consumed exactly once'
             % (len(cov['mapping']), cov['source_rows_consumed']))
    # Codex audit 7: every cell must be TYPED, UNIQUE, and traceable to section 2. Previously a cell
    # could be a bare string, and 32 copies of "junk" were counted as coverage. Tolerating two shapes
    # was the hole: the LIVE check accepted both, so the weaker shape was never rejected anywhere.
    by_raw = {r['source_row'].strip(): r.get('other_raw', '') for r in section2}
    live_by_row = {r['source_row'].strip(): set(r['live_cells']) for r in section2}
    seen_pairs = set()
    for m in cov['mapping']:
        row = (m.get('source_row') or '').strip()
        for cell in m.get('cells', []):
            if not isinstance(cell, dict):
                fail(problems, 'C8 %r carries the bare cell %r. A cell must be an object with a '
                               'label and a status -- an untyped string cannot be checked against '
                               'anything, which is how 32 copies of "junk" once counted as coverage.'
                     % (row, cell))
                continue
            label = (cell.get('cell') or '').strip()
            status = cell.get('status')
            if not label:
                fail(problems, 'C8 %r carries a cell with no label' % row)
                continue
            if status not in ('LIVE', 'UNVERIFIED_IMPORT'):
                fail(problems, 'C8 %r cell %r has status=%r, not LIVE or UNVERIFIED_IMPORT'
                     % (row, label, status))
            if (row, label) in seen_pairs:
                fail(problems, 'C8 %r emits the cell %r twice -- every cell is emitted once'
                     % (row, label))
            seen_pairs.add((row, label))
            # /scrutinize ORDER-602 H6: claiming LIVE used to SKIP traceability altogether, because
            # the rule below only applied to non-LIVE cells -- so a fabricated label relabelled LIVE
            # passed. The LIVE-subset check elsewhere proves the real LIVE cells are PRESENT; it never
            # proved that everything CLAIMING LIVE is real. Same shape as the blocker this order
            # exists to fix: one path was closed and its twin left open.
            if status == 'LIVE' and label not in live_by_row.get(row, ()):
                fail(problems, 'C8 %r claims %r is a LIVE cell, but section 2 lists %s as that row\'s '
                               'LIVE cell(s). A cell cannot mark itself LIVE to skip traceability.'
                     % (row, label, sorted(live_by_row.get(row, ())) or 'none'))
            if status == 'UNVERIFIED_IMPORT' and not cell.get('source_coordinates'):
                fail(problems, 'C8 an UNVERIFIED_IMPORT cell carries no source_coordinates -- the '
                               'order requires its source coordinates, not just the label')
            # RECOMPUTED: a non-LIVE cell must declare the exact substring of section 2 it came from,
            # and that substring must still be there. Guessing the token from the label was tried
            # first and was wrong in a way worth keeping: two cells are labelled `XAUUSD H4` /
            # `GBPUSD H4` while the source states only `H4` and the symbol is inherited from the
            # row's LIVE cell -- so a label-derived guess accused two CORRECT cells of being
            # untraceable, and would have pushed someone to "fix" the data to satisfy the checker.
            if status != 'LIVE' and label not in live_by_row.get(row, ()):
                token = (cell.get('source_token') or '').strip()
                if not token:
                    fail(problems, 'C8 %r cell %r is UNVERIFIED_IMPORT with no source_token -- it '
                                   'must name the exact substring of section 2 it came from, or it '
                                   'cannot be traced to anything' % (row, label))
                elif token not in by_raw.get(row, ''):
                    fail(problems, 'C8 %r claims the cell %r from source_token %r, but %r does not '
                                   'appear in that row\'s other-symbols column in section 2'
                         % (row, label, token, token))
                else:
                    # audit 8 MAJOR 4: a traceable token and a MEANINGLESS label could coexist --
                    # the token was checked against the source, the label never was, so `cell` could
                    # be any invented string while `source_token` stayed honest. The label must now
                    # be DERIVABLE from the token: either it IS the token, or it is the token
                    # qualified by this row's own LIVE symbol (the `XAUUSD H4` case, where the source
                    # states only `H4` and the symbol is inherited).
                    live_syms = {c.split()[0] for c in live_by_row.get(row, ()) if c.split()}
                    allowed = {token} | {'%s %s' % (s, token) for s in live_syms}
                    if label not in allowed:
                        fail(problems, 'C8 %r cell %r is not derivable from its source_token %r. A '
                                       'label must be the token itself, or the token qualified by '
                                       'this row\'s LIVE symbol (%s) -- otherwise the token is '
                                       'traceable while the label it labels is invented.'
                             % (row, label, token, sorted(live_syms) or 'none'))


def c9_reversal_fields(rows, problems):
    for r in rows:
        for k in ('reverse_steps', 'evidence_lost', 'retention_window'):
            v = r.get(k)
            if not v or (isinstance(v, str) and not v.strip()):
                fail(problems, 'C9 %s has an empty %s' % (r.get('entity'), k))
        steps = r.get('reverse_steps')
        if isinstance(steps, str) and steps.strip().lower() in ('revert the commit', 'revert'):
            fail(problems, 'C9 %s reverse_steps is %r -- the order calls that out by name as not '
                           'being executable steps' % (r.get('entity'), steps))


def load_rows():
    if not os.path.exists(MIGRATION_PATH):
        return None, ['%s does not exist yet. This checker is deliberately written BEFORE the '
                      'data (ORDER-600 D3), so this is the expected state until D1 is produced.'
                      % MIGRATION_PATH]
    rows, problems = [], []
    with io.open(MIGRATION_PATH, encoding='utf-8') as fh:
        for n, line in enumerate(fh, 1):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except ValueError as exc:
                problems.append('%s:%d is not valid JSON: %s' % (MIGRATION_PATH, n, exc))
                continue
            missing = [f for f in REQUIRED_FIELDS if f not in obj]
            if missing:
                problems.append('%s:%d (%s) is missing field(s): %s'
                                % (MIGRATION_PATH, n, obj.get('entity', '?'), missing))
            if obj.get('disposition') not in DISPOSITIONS:
                problems.append('%s:%d has disposition=%r, not one of %s'
                                % (MIGRATION_PATH, n, obj.get('disposition'), list(DISPOSITIONS)))
            if obj.get('disposition') == 'KEEP' and not (obj.get('keep_reason') or '').strip():
                problems.append('%s:%d is KEEP with no keep_reason -- KEEP is a visible choice '
                                'with a name on it, not a default' % (MIGRATION_PATH, n))
            rows.append(obj)
    if not rows and not problems:
        problems.append('%s is empty. An empty migration satisfies nothing.' % MIGRATION_PATH)
    return rows, problems


def self_test():
    """Rebuild audit 5's gaming artifact and assert this checker refuses it.

    A checker written before the data, and never run against data, is a wish with a shebang. So the
    null migration audit 5 constructed to close rev 1 is reconstructed here -- every entity named
    from $defs, schemas.json as the owner, a plausible constant in every hash field, every
    disposition KEEP, and no Coverage edge -- and each criterion that should fire is asserted BY
    NAME. A generic "it produced problems" would pass even if the wrong nine things broke.
    """
    print('=== self-test: does this checker refuse audit 5\'s null migration? ===')
    entities = sorted(storage_entities())
    null_migration = [{
        'entity': e,
        'current_owner': '_triage/factory_os/schemas.json',      # describes the fact, owns nothing
        'proposed_owner': '_triage/factory_os/schemas.json',
        'disposition': 'KEEP',                                    # ...for all 27
        'canonical_or_derived': 'canonical',
        'owner_ref': {'path': '_triage/factory_os/schemas.json',
                      'commit_oid': 'a' * 40, 'blob_oid': 'b' * 40, 'raw_sha256': 'c' * 64},
        'breaks_if_moved': 'dashboard may break',
        'breaks_if_not_moved': 'drift',
        'signoff_owner': '',
        'signoff_state': 'APPROVED',
        'reverse_steps': 'revert the commit',
        'evidence_lost': 'n/a',
        'retention_window': '30d',
    } for e in entities]

    problems = []
    tracked = tracked_paths() or set()
    c1_entity_set(null_migration, problems)
    c2_no_approved(null_migration, problems)
    c3_owner_vocabulary(null_migration, problems, tracked)
    c4_owner_ref_recomputed(null_migration, problems)
    c5_refs_distinct(null_migration, problems)
    c6_one_signoff_per_owner(null_migration, problems)
    c7_coverage_edge(null_migration, problems)
    c9_reversal_fields(null_migration, problems)

    blob = '\n'.join(problems)
    expected = [
        ('C2 APPROVED refused', 'C2 ' in blob and 'APPROVED' in blob),
        ('C3 schemas.json refused as owner', 'does not own it' in blob),
        ('C4 constant hash refused', 'C4 ' in blob and ('MISMATCH' in blob or 'does not resolve' in blob)),
        ('C5 identical blobs refused', 'same_blob_reason' in blob),
        ('C6 empty signer refused', 'empty signoff_owner' in blob),
        ('C7 missing Coverage edge refused', 'Coverage edge row is ABSENT' in blob),
        ('C7 all-KEEP refused', 'null migration' in blob),
        ('C9 "revert the commit" refused', 'not being executable steps' in blob),
    ]
    bad = 0
    for label, ok in expected:
        print('  [%s] %s' % ('OK ' if ok else 'BAD', label))
        if not ok:
            bad += 1
    # C1 must NOT fire: the null migration names every entity correctly. That is the whole point --
    # counting entity names was rev 1's only real check, and it passed.
    c1_fired = 'C1 ' in blob
    print('  [%s] C1 stays SILENT on the null migration (it names every entity, which is exactly '
          'why counting names was never enough)' % ('OK ' if not c1_fired else 'BAD'))
    if c1_fired:
        bad += 1
    # C8 needs its own case: the self-test above never reaches it, because it has no coverage file.
    # The attack is the one the order names -- copy one total into both fields and map 1:1 -- which
    # the old internally-consistent check would have accepted from a 7/7 claim.
    global COVERAGE_PATH
    section2 = parse_section2()
    print('\n  recomputed from MASTER_BACKLOG section 2: %d source rows, %d LIVE cells'
          % (len(section2), sum(len(r['live_cells']) for r in section2)))
    saved_path = COVERAGE_PATH
    import tempfile
    fd, tmp = tempfile.mkstemp(suffix='.json')
    try:
        one_to_one = {
            'source_rows_consumed': len(section2),
            'cells_emitted': len(section2),                       # ...the copied number
            'mapping': [{'source_row': r['source_row'],
                         'cells': [r['live_cells'][0]] if r['live_cells'] else []}
                        for r in section2],                       # ...forced 1:1
        }
        with os.fdopen(fd, 'w', encoding='utf-8') as fh:
            json.dump(one_to_one, fh)
        COVERAGE_PATH = tmp
        c8 = []
        c8_coverage_reconciled(c8)
        joined = '\n'.join(c8)
        hit = 'omits its LIVE cell' in joined or 'cannot be smaller' in joined
        print('  [%s] C8 refuses a 1:1 mapping that drops ST_EA03\'s second LIVE cell'
              % ('OK ' if hit else 'BAD'))
        if not hit:
            print('        -> C8 said: %s' % (c8[:1] or ['nothing']))
            bad += 1
    finally:
        COVERAGE_PATH = saved_path
        try:
            os.unlink(tmp)
        except OSError:
            pass

    # ------------------------------------------------------------------ rev 5 rules
    # The two forms added in rev 5 are exemptions from C3, and an exemption nobody tests is a hole.
    # Each case below is the cheapest abuse of the new form, and must be refused BY NAME.
    print('\n=== rev 5: do the two new owner forms refuse their own abuse? ===')
    tracked_real = tracked or set()
    real_evidence = '_triage/EA_LAB_FACTORY_OS_DESIGN.md'   # really does mention TestUniverse

    def c3_says(row, want, label):
        global_bad = []
        base = {'entity': 'TestUniverse', 'disposition': 'TRANSFER', 'proposed_owner': 'factory/universe.jsonl',
                'canonical_or_derived': 'canonical'}
        base.update(row)
        c3_owner_vocabulary([base], global_bad, tracked_real)
        joined = '\n'.join(global_bad)
        ok = want in joined
        print('  [%s] %s' % ('OK ' if ok else 'BAD', label))
        if not ok:
            print('        -> C3 said: %s' % (global_bad[:1] or ['NOTHING AT ALL']))
        return 0 if ok else 1

    rev5 = 0
    # Codex audit 7 replaced the substring guard with a closed declaration, so these three now assert
    # three DIFFERENT rules. They used to differ only in which way the citation was bad, and after the
    # fix all three produced the same message -- three tests asserting one rule is one test.
    rev5 += c3_says({'entity': 'CoverageCell', 'current_owner': 'NO_CURRENT_OWNER',
                     'unowned_evidence': '_triage/EA_LAB_FACTORY_OS_DESIGN.md'},
                    'not declared UNOWNABLE',
                    'an entity not on the closed list may not claim an owner state')
    rev5 += c3_says({'current_owner': 'NO_CURRENT_OWNER', 'unowned_evidence': 'CLAUDE.md'},
                    'declared evidence is',
                    'a declared entity citing evidence other than its own refused')
    # ORDER-602 B: the four states are not interchangeable.
    rev5 += c3_says({'current_owner': 'TRANSIENT', 'disposition': 'KEEP',
                     'proposed_owner': 'TRANSIENT', 'canonical_or_derived': 'derived',
                     'unowned_evidence': real_evidence},
                    'its declared state is',
                    'a row wearing another entity\'s owner state refused')
    # ...and the rot check: point the declaration at a tracked file that does NOT carry the claim.
    saved_decl = dict(UNOWNABLE)
    try:
        UNOWNABLE['TestUniverse'] = ('NO_CURRENT_OWNER', 'CLAUDE.md',
                                     'this exact sentence is not in CLAUDE.md')
        rev5 += c3_says({'current_owner': 'NO_CURRENT_OWNER', 'unowned_evidence': 'CLAUDE.md'},
                        'has rotted',
                        'a citation whose claim is no longer in the cited file refused')
    finally:
        UNOWNABLE.clear()
        UNOWNABLE.update(saved_decl)
    rev5 += c3_says({'current_owner': 'NO_CURRENT_OWNER', 'unowned_evidence': real_evidence,
                     'disposition': 'KEEP', 'proposed_owner': 'NO_CURRENT_OWNER',
                     'canonical_or_derived': 'canonical'},
                    'that state allows only',
                    'NO_CURRENT_OWNER sitting at KEEP refused (it exists to acquire an owner)')
    rev5 += c3_says({'current_owner': 'NO_CURRENT_OWNER', 'unowned_evidence': real_evidence,
                     'proposed_owner': 'NO_CURRENT_OWNER', 'disposition': 'TRANSFER'},
                    'proposes nothing',
                    'an acquiring state named as its own DESTINATION refused')
    rev5 += c3_says({'entity': 'MetricRef', 'current_owner': 'EMBEDDED:Hypothesis',
                     'disposition': 'KEEP', 'proposed_owner': 'EMBEDDED:Hypothesis'},
                    'does not reference',
                    'EMBEDDED naming a parent the $ref graph denies refused')
    rev5 += c3_says({'entity': 'OwnerRef', 'current_owner': 'EMBEDDED:*',
                     'disposition': 'KEEP', 'proposed_owner': 'EMBEDDED:*',
                     'embedded_in': ['CoverageCell']},
                    'needs at least 2',
                    'EMBEDDED:* with a single parent refused')
    # ...and the control: the honest form must stay SILENT, or the guard is just noise.
    control = []
    c3_owner_vocabulary([{'entity': 'TestUniverse', 'current_owner': 'NO_CURRENT_OWNER',
                          'unowned_evidence': real_evidence, 'disposition': 'TRANSFER',
                          'proposed_owner': 'factory/universe.jsonl',
                          'canonical_or_derived': 'canonical'},
                         {'entity': 'MetricRef', 'current_owner': 'EMBEDDED:CoverageCell',
                          'disposition': 'KEEP', 'proposed_owner': 'EMBEDDED:CoverageCell',
                          'canonical_or_derived': 'canonical'}], control, tracked_real)
    print('  [%s] CONTROL a correct UNOWNED row and a correct EMBEDDED row stay silent'
          % ('OK ' if not control else 'BAD'))
    if control:
        print('        -> C3 wrongly said: %s' % control[:2])
        rev5 += 1
    bad += rev5

    print('\n  %d criteria checked, %d did not behave as declared' % (len(expected) + 2 + 8, bad))
    return 1 if bad else 0


def main(argv):
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)
    if '--self-test' in argv:
        return self_test()

    print('=== ORDER-600 (S2a) acceptance: the nine MACHINE criteria ===')
    print('migration: %s' % MIGRATION_PATH)
    print('coverage : %s\n' % COVERAGE_PATH)

    started_at = input_fingerprint()          # audit 7 MODERATE 9: pin what this run is judging
    _FINGERPRINT[:] = [started_at]
    tracked = tracked_paths()
    if tracked is None:
        print('[ABORT] git ls-files failed, so no path claim could be checked. That is a tool')
        print('        failure, not a clean run -- exiting 2 rather than reporting success.')
        return 2

    rows, problems = load_rows()
    if rows is None:
        for p in problems:
            print('[PENDING] %s' % p)
        print('\n=== D1 NOT PRESENT - nothing asserted. This is exit 2, not exit 0: "no data" and')
        print('    "data that passes" must never share an exit code. ===')
        return 2

    print('  %d row(s) loaded, %d structural problem(s)\n' % (len(rows), len(problems)))
    for name, fn in (('C1 entity set == __STORAGE__ set', lambda: c1_entity_set(rows, problems)),
                     ('C2 no APPROVED signoff', lambda: c2_no_approved(rows, problems)),
                     ('C3 owner vocabulary / existence', lambda: c3_owner_vocabulary(rows, problems, tracked)),
                     ('C4 owner_ref recomputed from git', lambda: c4_owner_ref_recomputed(rows, problems)),
                     ('C5 owner_refs distinct', lambda: c5_refs_distinct(rows, problems)),
                     ('C6 CONSISTENT signer per owner (not 1 row)', lambda: c6_one_signoff_per_owner(rows, problems)),
                     ('C7 Coverage edge present, not all-KEEP', lambda: c7_coverage_edge(rows, problems)),
                     ('C8 coverage counting reconciled', lambda: c8_coverage_reconciled(problems)),
                     ('C9 reversal fields non-empty', lambda: c9_reversal_fields(rows, problems))):
        before = len(problems)
        fn()
        added = len(problems) - before
        print('  [%s] %-42s %s' % ('OK ' if added == 0 else 'BAD', name,
                                   '' if added == 0 else '%d problem(s)' % added))

    notes = pin_vintage_notes(rows)
    if notes:
        print('\n  %d ADVISORY note(s) -- not failures, but read them before signing:' % len(notes))
        for n in notes:
            print('  ~> %s' % n['text'])

    # audit 7 MODERATE 9: the cached index/HEAD answers are only valid for the commit this run
    # started on. If something committed or staged underneath us, no verdict here is trustworthy.
    if input_fingerprint() != started_at:
        print('\n[ABORT] HEAD or the git index changed while this check was running, so its cached')
        print('        answers describe a state that no longer exists. That is a tool failure, not a')
        print('        clean run -- exiting 2 rather than reporting a verdict. Re-run it.')
        return 2

    if problems:
        print('')
        for p in problems:
            print('  -> %s' % p)
        print('\n=== %d PROBLEM(S) - ORDER-600 is not satisfied ===' % len(problems))
        return 1
    print('\n=== ALL NINE MACHINE CRITERIA HOLD ===')
    print('    NOTE: the HUMAN-REVIEW checklist in ORDER-600 is NOT checked here and cannot be.')
    print('    A green run means the table is well-formed and its hashes are real, not that the')
    print('    breakage analysis is any good.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
