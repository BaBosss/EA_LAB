# -*- coding: utf-8 -*-
"""registry.py -- ORDER-630 (slice S5). The Factory registries, and THE ParameterBinding resolver.

THERE IS EXACTLY ONE RESOLVER AND THIS IS IT.
  The design's S5 acceptance says "generator and optimize_guard provably read ONE resolver". That
  word is doing real work. `docs/PARAM_REGISTRY.csv` owns a parameter's PERMANENT semantics
  (classification ACTIVE / OVERRIDE / INACTIVE / COMPATIBILITY -- can this input change behaviour
  at all). A `ParameterBinding` owns its PER-HYPOTHESIS role (TUNABLE / LOCKED / SAFETY / ...).
  Neither answers "may this run optimize this parameter" on its own, and two consumers each
  combining them their own way is how the same parameter becomes tunable in one tool and locked in
  the other -- with nothing red anywhere.

  So the combination happens here, once. `check_registries.py` C4 refuses a second implementation
  by requiring that every consumer reach it through this module, and by refusing a second copy of
  the role vocabulary anywhere in the tree.

WHAT IS *IN* THE REGISTRIES TODAY, AND WHY THAT IS THE HONEST ANSWER
  All four stores exist, are schema-bound, are round-trippable and are guarded. Three of them
  carry no content rows, each for a reason recorded in the file's own header:
    universe.jsonl             Core Universe v1 membership is an OWNER decision
                               (_triage/USER_DECISIONS_PENDING.md #1). Every cell is tester hours.
    hypotheses.jsonl           registering one asserts a causal claim and pins the order that
                               pre-registered it; no order exists in the B11-B18 form yet.
    parameter_bindings.jsonl   a binding names a hypothesis_revision, and there are none.
  coverage.jsonl is the exception: it was populated by ORDER-610's transfer and is EXTENDED here,
  never re-opened.

  Empty is not the same as unbuilt, and it is not the same as broken. The mechanism is exercised
  against SYNTHETIC registries in run_registry_tests.py, which is the only way to test it without
  inventing owner-owned content -- and inventing it is what the design forbids by name.

USAGE
  tools\\python312\\python.exe _triage/factory_os/registry.py check
  tools\\python312\\python.exe _triage/factory_os/registry.py resolve <hypothesis_revision> [<parameter>]
TESTS
  tools\\python312\\python.exe _triage/factory_os/run_registry_tests.py
"""
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))

# The stores, and the ONE entity each may contain. A file is not allowed to hold a mixture:
# a store whose rows can be any entity is a store nothing can validate as a whole.
STORES = {
    'factory/universe.jsonl': 'TestUniverse',
    'factory/instrument_profiles.jsonl': 'InstrumentProfile',
    'factory/hypotheses.jsonl': 'Hypothesis',
    'factory/parameter_bindings.jsonl': 'ParameterBinding',
    'factory/coverage.jsonl': 'CoverageCell',
}

# STORES THAT MAY NOT EXIST YET, each with the gate that blocks it and the condition that lifts it.
#
# MEASURED 2026-07-31 (ORDER-630), by creating the file and running the S2a gate:
# `factory/universe.jsonl` refutes TWO rows of D1 the moment it is staged --
#   C3 TestUniverse claims NO_CURRENT_OWNER, but the schema names factory/universe.jsonl as its
#      owner file and that file EXISTS -- the state is refuted by the repo
#   C3 LogicalSymbol claims NOT_YET_BUILT, same file, same refutation
# and D1 (`_triage/factory_os/s2a_migration.jsonl`) is a member of the owner's attestation
# `bundle_sha256`. So creating this store costs the OWNER A SIGNATURE, and that is not a cost this
# seat may decide to spend.
#
# This is not a surprise, it is a KNOWN STRUCTURAL PROBLEM already recorded: an approval that pins
# the bytes of the thing it authorises invalidates itself the moment the transfer is executed, and
# EVERY `disposition: TRANSFER` row is shaped like that (memory `approval-pinning-self-invalidates`).
# The recorded resolution -- make that class of check ADVISORY and loud rather than blocking -- has
# not been built. Until it is, the honest move is to leave the store uncreated and say so in the
# place a reader will actually look, which is here and in check_registries' output on every run.
#
# Deliberately NOT done: editing D1 to make the refutation go away. That would spend an owner
# signature to hide a structural defect, and the resolution for that defect is already decided
# elsewhere.
STORES_BLOCKED = {
    'factory/universe.jsonl':
        "blocked by the S2a migration table: D1 declares TestUniverse NO_CURRENT_OWNER and "
        "LogicalSymbol NOT_YET_BUILT with factory/universe.jsonl as their PROPOSED owner, and D1 "
        "is inside the owner's attestation bundle_sha256. Creating the file refutes both rows "
        "(verified by running run_s2a_gate.py with the file staged), and repairing them costs a "
        "signature this seat may not spend. LIFTS WHEN: D1 stops declaring those two states. "
        "Core Universe v1 MEMBERSHIP is separately the owner's (USER_DECISIONS_PENDING #1), so "
        "the store would be created empty even if this block were lifted today.",
}

# Metadata lines a store may carry instead of a row. Closed, and each one starts with `_` so a
# real entity can never be mistaken for one: every entity's discriminator is `entity`.
META_KEYS = ('_comment', '_section')

# Keys that make a record STRUCTURED DATA rather than a note. `entity` is every registry row's
# discriminator; `cells` is what ORDER-610's imported coverage rows carry instead, and they predate
# the discriminator.
STRUCTURAL_KEYS = ('entity', 'cells')


def classify_record(rec, where=''):
    """-> 'META' or 'ROW'. Refuses a record that is both. THE ONE metadata rule in this repo.

    A blind audit called the duplication out by name: this rule existed in `read_store` AND again,
    written differently, in snapshot_build.reconcile -- so the same defect had to be found twice.
    It was: adding `_comment` to a real coverage row turned 1 untested cell into an empty 0/0/0
    universe, three commits after the identical hole was closed here. Two copies of a rule is one
    rule and one liability, and the second copy is always the one nobody fixes.

    So there is one function, it lives here, and snapshot_build imports it. The rule:
      META       a metadata key and no structural key -- a note
      ROW        no metadata key -- data
      REFUSED    both -- ambiguous, and reading it either way silently discards the other meaning
    """
    has_meta = any(k in rec for k in META_KEYS)
    has_structure = any(k in rec for k in STRUCTURAL_KEYS)
    if has_meta and has_structure:
        _refuse('%s carries both a metadata key (%s) and structured data (%s). Refused: it is '
                'ambiguous whether this is a row or a note, and reading it as a note is how a '
                'LOCKED binding, a forbidden verdict and a real coverage cell each became '
                'invisible to every check at once.'
                % (where or 'a record',
                   ', '.join(k for k in META_KEYS if k in rec),
                   ', '.join(k for k in STRUCTURAL_KEYS if k in rec)))
    return 'META' if has_meta else 'ROW'

# The role vocabulary. It lives HERE and nowhere else -- C4 greps for a second copy, because two
# copies of a vocabulary is the drift this module exists to prevent.
ROLES = ('TUNABLE', 'RUNTIME', 'SIZING', 'SAFETY', 'LOCKED', 'INACTIVE')
SURFACES = ('OPERATOR', 'RESEARCH', 'HIDDEN')

# Roles a run may OPTIMIZE. An allowlist, not a blacklist: the question "which roles are
# optimizable" must be answered by naming them, so a role added to the enum later is refused until
# somebody decides, rather than inheriting permission from not being on a deny list.
OPTIMIZABLE_ROLES = ('TUNABLE',)

# THE OTHER HALF OF THE COMBINATION, which this module CLAIMED to perform and did not.
# A blind audit bound `StackMode[LAB_ENTRY_16]` as TUNABLE and got optimizable=True, while
# docs/PARAM_REGISTRY.csv classifies that input INACTIVE. optimize_guard recovers the right answer
# today because it applies the permanent-semantics half itself -- but the whole point of "ONE
# resolver" is that the NEXT consumer does not have to, and the generator would have been handed
# the wrong canonical answer. The docstring at the top of this file described a combination that
# happened in two places, one of which was not this one.
#
# LIVE = the input can still change behaviour somewhere; DEAD = it cannot on the build it is tagged
# for. Same vocabulary scripts/optimize_guard.ps1 uses, and it is an ALLOWLIST: a classification
# value in neither list is refused rather than assumed harmless.
PARAM_REGISTRY_REL = 'docs/PARAM_REGISTRY.csv'
LIVE_CLASSIFICATIONS = ('ACTIVE', 'OVERRIDE')
DEAD_CLASSIFICATIONS = ('INACTIVE', 'COMPATIBILITY')

_CLASSIFICATION_CACHE = {}


def _classifications(root=None, source=None):
    """-> {bare parameter name: classification} from docs/PARAM_REGISTRY.csv.

    ORDER-670 migration (the resolver's OWN read). `resolve()` decides whether a parameter is
    optimizable, and it decided that from the WORKING TREE while the tier that consumes it runs
    as a pre-commit hook. `source` moves it: the index in hook mode, the disk otherwise. Handed
    no source it still reads the disk, and that default is a scheduled removal (design section
    6), not a preference -- the same wording `read_store` carries.

    🔴 THE CACHE IS KEYED ON (root, MODE), and the mode half is not decoration. `_CLASSIFICATION_
    CACHE` was keyed on the root alone; adding a source without touching it would let a worktree
    answer be served to an index-mode caller from the first call onwards -- a guard caching the
    value it is watching, which is the defect recorded in memory
    `drift-guard-regenerating-against-head`. The two vintages must not share a slot.

    POSITIONAL, index 0 = name and index 10 = classification, which is what
    scripts/optimize_guard.ps1 reads ($m[10]) and what its own header calls "column 11". The file
    has NO quoted header row -- it opens with `>` prose lines and then goes straight to data -- so
    a header-driven parser finds nothing. The first version of this function was header-driven and
    returned ZERO rows silently, which is the "readable but not understood, published as empty"
    defect this pipeline refuses everywhere else. It is refused here too.

    Deliberately not a general CSV parser: it relies on every field being double-quoted with no
    embedded quotes, exactly as optimize_guard does, and a row that does not match that shape is
    SKIPPED AND COUNTED rather than guessed at.
    """
    base = REPO_ROOT if root is None else root
    key = (base, source.mode if source is not None else 'worktree-direct')
    if key in _CLASSIFICATION_CACHE:
        return _CLASSIFICATION_CACHE[key]
    if source is not None:
        if not source.exists_committed(PARAM_REGISTRY_REL):
            _refuse('%s is not present (%s mode), so a parameter PERMANENT-semantics lookup is '
                    'impossible. Refused rather than defaulted: "I cannot tell whether this '
                    'input is dead" must never be answered as "it is live".'
                    % (PARAM_REGISTRY_REL, source.mode))
        try:
            text = source.read_committed(PARAM_REGISTRY_REL)
        except Exception as exc:      # evidence.ToolFailure -- cannot read IS a refusal here
            _refuse('%s: %s' % (PARAM_REGISTRY_REL, exc))
    else:
        path = os.path.join(base, PARAM_REGISTRY_REL.replace('/', os.sep))
        if not os.path.isfile(path):
            _refuse('%s is not present, so a parameter PERMANENT-semantics lookup is impossible. '
                    'Refused rather than defaulted: "I cannot tell whether this input is dead" '
                    'must never be answered as "it is live".' % PARAM_REGISTRY_REL)
        with io.open(path, encoding='utf-8-sig') as fh:  # snapshot: worktree
            text = fh.read()
    out, skipped = {}, 0
    for line in text.split('\n'):
        if not line.startswith('"'):
            continue
        fields = re.findall(r'"([^"]*)"', line)
        if len(fields) < 11:
            skipped += 1
            continue
        name = fields[0].strip()
        if not name:
            skipped += 1
            continue
        # KEYED ON THE FULL NAME, TAG INCLUDED. The first version stripped the build tag
        # and wrote out[bare], which is last-wins across rows that disagree -- and they DO:
        # measured, StackMode[LAB_ENTRY_16] is INACTIVE while the other seven StackMode rows
        # are ACTIVE. Collapsing eight answers into one and keeping whichever came last is the
        # same "a store with two answers cannot be a resolver" defect this module refuses for
        # duplicate bindings, committed by the resolver itself.
        out[name] = fields[10].strip().upper()
    if not out:
        _refuse('%s parsed to ZERO classifications (%d row(s) skipped as unparseable). Refused: a '
                'permanent-semantics table that reads as empty would make every parameter '
                'UNKNOWN, and the first version of this parser did exactly that in silence.'
                % (PARAM_REGISTRY_REL, skipped))
    _CLASSIFICATION_CACHE[key] = out
    return out


def _bare(parameter):
    """Strip a trailing build tag: `StackMode[LAB_ENTRY_16]` -> `StackMode`. ONE definition.

    Used by the binding join AND by classification_of. Two spellings of "the same parameter" is
    exactly the drift that made a tagged binding invisible to its consumer.
    """
    return re.sub(r'\[[^\]]*\]$', '', str(parameter)).strip()


def classification_of(parameter, root=None, source=None):
    """-> (classification, why) for one parameter name. `classification` is None when unresolvable.

    Three cases, and the third is the one that matters:
      * an EXACT match (the binding names the tag, e.g. `StackMode[LAB_ENTRY_16]`) -> that row
      * no tag, and every tagged row for that bare name AGREES -> the agreed value
      * no tag, and the tagged rows DISAGREE -> None, AMBIGUOUS. Measured: the eight StackMode
        rows are seven ACTIVE and one INACTIVE, so a binding that does not say which build it
        means has no answer here, and must not be handed the majority one.
    """
    table = _classifications(root, source=source)
    if parameter in table:
        return table[parameter], 'exact'
    bare = _bare(parameter)
    matches = dict((k, v) for k, v in table.items()
                   if _bare(k) == bare)
    if not matches:
        return None, 'not in the registry'
    values = set(matches.values())
    if len(values) == 1:
        return values.pop(), 'agreed across %d tagged row(s)' % len(matches)
    return None, ('AMBIGUOUS: %d tagged rows disagree (%s) -- the binding must name the build tag'
                  % (len(matches), ', '.join(sorted(values))))


class RegistryRefusal(Exception):
    """This module will not answer for these inputs. A statement about the input, not a verdict."""


def _refuse(msg):
    raise RegistryRefusal(msg)


def read_store(rel, root=None, source=None):
    """-> (meta_lines, rows) for one store. Refuses rather than skipping anything it cannot read.

    A store that is ABSENT is refused, not treated as empty -- the rule this repo has paid for
    more than any other. `factory/coverage.jsonl` proves the distinction matters: "no coverage
    cells" and "no coverage store" have opposite fixes.

    `source` (ORDER-670): an evidence.EvidenceSource choosing WHICH bytes are judged -- the
    index in hook mode, the disk otherwise. When None, this reads the worktree directly: that
    is the UN-MIGRATED default, kept because resolve()/optimize_guard run outside hooks where
    worktree is the correct mode anyway. The design's end state is that a library handed no
    source refuses; that lands when the remaining callers migrate (design section 6), and
    this sentence is here so the default reads as a scheduled removal, not a choice.
    """
    if source is not None:
        if not source.exists_committed(rel):
            _refuse('%s is not present (%s mode). An absent registry is not an empty registry: '
                    'one means the store was never created, the other means nothing has been '
                    'registered yet, and they have different fixes.' % (rel, source.mode))
        try:
            text = source.read_committed(rel)
        except Exception as exc:  # evidence.ToolFailure -- "cannot read" is a refusal here too
            _refuse('%s: %s' % (rel, exc))
        meta, rows = [], []
        for n, line in enumerate(text.split('\n'), 1):
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except ValueError as exc:
                _refuse('%s line %d is not parseable JSON: %s' % (rel, n, exc))
            if not isinstance(rec, dict):
                _refuse('%s line %d is %s, not an object' % (rel, n, type(rec).__name__))
            if classify_record(rec, '%s line %d' % (rel, n)) == 'META':
                meta.append(rec)
                continue
            rows.append((n, rec))
        return meta, rows
    root = REPO_ROOT if root is None else root
    path = os.path.join(root, rel.replace('/', os.sep))
    if not os.path.isfile(path):
        _refuse('%s is not present. An absent registry is not an empty registry: one means the '
                'store was never created, the other means nothing has been registered yet, and '
                'they have different fixes.' % rel)
    meta, rows = [], []
    with io.open(path, encoding='utf-8') as fh:  # snapshot: worktree
        for n, line in enumerate(fh, 1):
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except ValueError as exc:
                _refuse('%s line %d is not parseable JSON: %s' % (rel, n, exc))
            if not isinstance(rec, dict):
                _refuse('%s line %d is %s, not an object' % (rel, n, type(rec).__name__))
            if classify_record(rec, '%s line %d' % (rel, n)) == 'META':
                meta.append(rec)
                continue
            rows.append((n, rec))
    return meta, rows


def load_all(root=None, source=None):
    """-> {rel: (meta, rows)} for every UNBLOCKED store. One read each, so one moment for all.

    A BLOCKED store is skipped rather than refused -- but only while it is genuinely absent.
    `check_registries.R6` is what makes that safe: it refuses a blocked store that has APPEARED,
    so "skipped" can never quietly become "there but unchecked".

    `source` chooses which bytes are judged (ORDER-670); the blocked-store absence probe uses
    the SAME source, because "absent from the commit" and "absent from the disk" are different
    facts and mixing them here would be one verdict over two vintages.
    """
    out = {}
    for rel in sorted(STORES):
        if rel in STORES_BLOCKED:
            absent = (not source.exists_committed(rel)) if source is not None else \
                not os.path.isfile(
                    os.path.join(REPO_ROOT if root is None else root, rel.replace('/', os.sep)))
            if absent:
                continue
        out[rel] = read_store(rel, root=root, source=source)
    return out


# ---------------------------------------------------------------------------------------------
# THE RESOLVER.

def _binding_index(rows):
    """(hypothesis_revision, parameter) -> binding. Refuses a duplicate key.

    A duplicate is refused rather than last-wins: two rows binding the same parameter in the same
    revision is a store that cannot answer its own question, and picking one silently is how a
    consumer and a generator end up reading different answers from the same file.
    """
    out = {}
    for n, rec in rows:
        key = (rec.get('hypothesis_revision'), rec.get('parameter'))
        if key in out:
            _refuse('factory/parameter_bindings.jsonl line %d binds %r in %r a second time. '
                    'Refused: a store with two answers cannot be a resolver.'
                    % (n, key[1], key[0]))
        out[key] = rec
    return out


def _overlay_index(root, overlay_root):
    """Bindings from the canonical tree, with an overlay that may only ADD.

    BLIND AUDIT 2026-07-31, and my claim was simply FALSE. `--root` REPLACED the store, so a root
    holding a LOCKED binding gave REFUSE and an empty root gave ALLOW -- the seam bought permission,
    which is exactly what its own comment said it could not do. Reproduced end to end through
    optimize_guard.

    An OVERLAY cannot: the canonical binding wins on every key it defines, and the overlay may only
    supply keys the canonical store does not bind. So an overlay can add a refusal and can never
    remove one, which is the property that was claimed and is now true rather than asserted.
    """
    canonical = _binding_index(load_all(root=root)['factory/parameter_bindings.jsonl'][1])
    if overlay_root is None:
        return canonical
    extra = _binding_index(load_all(root=overlay_root)['factory/parameter_bindings.jsonl'][1])
    merged = dict(extra)
    merged.update(canonical)   # canonical last: it wins every key it defines
    return merged


def resolve(hypothesis_revision, parameter, root=None, stores=None, overlay_root=None,
            source=None):
    """-> {parameter, hypothesis_revision, role, surface, optimizable, locked_value, safe_range,
           definition_ref, source}

    `optimizable` is the ONE derived answer this module exists to give, and it is derived HERE so
    that nothing else derives it. `source` names where the answer came from, so a caller can tell
    "bound" from "not bound" without inspecting the shape of what it got back.

    NOT BOUND is not an error and not a default-to-tunable: it returns role=None,
    optimizable=None. A resolver that answered TUNABLE for a parameter nobody bound would be
    granting permission by silence, which is the same defect as reading an absent `experimental`
    field as false -- named in the Hypothesis schema for exactly that reason.

    ⚠️ CORRECTED 2026-07-31 after a blind audit read this paragraph against the consumer and found
    them disagreeing. The sentence above overclaimed. `optimizable=None` stops THIS FUNCTION from
    granting permission by silence; it does not stop the SYSTEM. optimize_guard was dropping the
    None on the floor, so a run declared to belong to a revision swept a parameter that revision
    never described and nothing said so -- permission by silence, one call frame later. What None
    means, exactly: THE PER-HYPOTHESIS LAYER HAS NO OPINION. It is now the consumer's obligation to
    say so out loud, and scripts/optimize_guard.ps1 emits a note naming the parameter. Whether an
    unbound parameter should instead be REFUSED depends on whether a revision's binding set is
    required to be complete, which no entity declares and no design row asks for -- so it is an
    open question, not a rule this module gets to invent.
    """
    def _lookup(idx):
        # EXACT first, then a TAG-AWARE join. F1, found by an independent review and reproduced:
        # the resolver keyed bindings on the exact `parameter` string while optimize_guard joined
        # on Split-NameTag's BASE name -- so a binding written as `StackMode[LAB_ENTRY_16]` was
        # invisible to the only consumer, silently degrading a LOCKED binding to an UNBOUND note.
        # The two constraints were JOINTLY UNSATISFIABLE for a multi-build parameter: bare -> this
        # module calls the classification AMBIGUOUS; tagged -> the consumer never sees it.
        #
        # The join lives HERE, not in the consumer, for the reason the whole module exists: a
        # second implementation of "which binding does this parameter mean" is a second resolver.
        # Ambiguity is refused rather than resolved by majority -- same rule as classification_of.
        hit = idx.get((hypothesis_revision, parameter))
        if hit is not None:
            return hit
        want = _bare(parameter)
        near = [v for (rev, p), v in idx.items()
                if rev == hypothesis_revision and _bare(p) == want]
        if len(near) > 1:
            _refuse('%d bindings in %r match the parameter %r once build tags are ignored (%s). '
                    'Refused: a store with two answers cannot be a resolver, and picking one by '
                    'position is how a LOCKED binding becomes an ALLOW.'
                    % (len(near), hypothesis_revision, parameter,
                       ', '.join(sorted(str(v.get('parameter')) for v in near))))
        return near[0] if near else None

    if overlay_root is not None:
        rec = _lookup(_overlay_index(root, overlay_root))
    else:
        if stores is None:
            stores = load_all(root=root)
        _meta, rows = stores['factory/parameter_bindings.jsonl']
        rec = _lookup(_binding_index(rows))
    if rec is None:
        return {'parameter': parameter, 'hypothesis_revision': hypothesis_revision,
                'role': None, 'surface': None, 'classification': None,
                'classification_source': None, 'optimizable': None,
                'locked_value': None, 'safe_range': None, 'definition_ref': None,
                'source': 'UNBOUND'}
    role = rec.get('role')
    if role not in ROLES:
        _refuse('binding for %r in %r carries role %r, which is not in the closed vocabulary %s'
                % (parameter, hypothesis_revision, role, list(ROLES)))
    surface = rec.get('surface')
    if surface not in SURFACES:
        _refuse('binding for %r in %r carries surface %r, which is not in the closed vocabulary %s'
                % (parameter, hypothesis_revision, surface, list(SURFACES)))
    # FOUND BY PROBING, 2026-07-31 (ORDER-630 round 1): the schema requires `locked_value` when
    # role is LOCKED (an `allOf`/`if`-`then`), and this resolver never consults the schema -- a
    # LOCKED binding with no locked_value resolved happily and handed back None. optimize_guard
    # fails safe on it (LOCKED is not optimizable either way), but the generator's whole job is to
    # emit that value as a const, and a const of null is a locked parameter locked to nothing.
    # Re-checked here rather than left to ajv, because the fast path never runs ajv.
    # `is None`, not `not in`. F4: this tested PRESENCE while its own message is about the VALUE,
    # so `locked_value: null` walked through the check written to stop exactly that -- shape 2
    # recreated inside the repair that closed it. Harmless only until the generator exists, whose
    # whole job is to emit this as a const: a const of null is what the message already predicts.
    if role == 'LOCKED' and rec.get('locked_value') is None:
        _refuse('binding for %r in %r is role=LOCKED with no usable `locked_value` (absent or null). The schema requires '
                'one; this resolver is reached without ajv on the fast path, so it is refused here '
                'too. A locked parameter with no value to lock to is not a lock.'
                % (parameter, hypothesis_revision))
    # THE COMBINATION. Until a blind audit checked it, `optimizable` was `role in
    # OPTIMIZABLE_ROLES` and nothing else -- so binding `StackMode[LAB_ENTRY_16]` TUNABLE returned
    # optimizable=True while docs/PARAM_REGISTRY.csv classifies that input INACTIVE. optimize_guard
    # recovered the right answer by applying the permanent-semantics half ITSELF, which is exactly
    # the thing "ONE resolver" exists to make unnecessary: the next consumer, the generator, would
    # have been handed the wrong canonical answer. The docstring at the top of this file described
    # a combination that was happening in two places, one of which was not this one.
    #
    # ALLOWLIST on the classification, not a deny-list: a value in neither list is UNKNOWN, and
    # UNKNOWN is not optimizable. A classification this module has never seen must not inherit
    # permission from not being on a list of bad ones.
    classification, why = classification_of(parameter, root, source=source)
    if classification in LIVE_CLASSIFICATIONS:
        permanent_ok = True
    elif classification in DEAD_CLASSIFICATIONS:
        permanent_ok = False
    else:
        permanent_ok = False
    return {'parameter': parameter, 'hypothesis_revision': hypothesis_revision,
            'role': role, 'surface': surface,
            'classification': classification,
            'classification_source': why,
            'optimizable': (role in OPTIMIZABLE_ROLES) and permanent_ok,
            'locked_value': rec.get('locked_value'),
            'safe_range': rec.get('safe_range'),
            'definition_ref': rec.get('definition_ref'),
            'source': 'BOUND'}


def resolve_all(hypothesis_revision, root=None, stores=None, overlay_root=None, source=None):
    """Every binding registered for one revision, keyed by parameter name."""
    # KEYED ON THE BARE NAME, with the bound (possibly tagged) string preserved inside each
    # record. F1's other half: resolve() now joins a bare request to a tagged binding, but this map
    # still handed the consumer the TAGGED key, and optimize_guard looks up Split-NameTag's base
    # name -- so the tagged binding stayed invisible through the map even after the direct lookup
    # was fixed. Fixing one of two join sites is fixing where the counter-example pointed.
    #
    # Keying by bare name is unambiguous BY CONSTRUCTION: resolve() refuses a revision that carries
    # two bindings sharing a bare name, so this dict can never silently lose one.
    if overlay_root is not None:
        idx = _overlay_index(root, overlay_root)
        names = sorted(set(_bare(p) for (rev, p) in idx if rev == hypothesis_revision))
        return dict((p, resolve(hypothesis_revision, p, root=root,
                                overlay_root=overlay_root, source=source))
                    for p in names)
    if stores is None:
        stores = load_all(root=root)
    _meta, rows = stores['factory/parameter_bindings.jsonl']
    names = sorted(set(_bare(rec.get('parameter')) for _n, rec in rows
                       if rec.get('hypothesis_revision') == hypothesis_revision))
    # `root=root` is NOT optional and was missing. resolve_all delegated to resolve() without it,
    # so the per-parameter answers were computed against the REPO's PARAM_REGISTRY while the rows
    # came from the caller's root -- two trees, one answer. Caught by the exhaustive-role fixture
    # going red the moment resolve() started consulting the classification table at all: before
    # that, root only selected the bindings, which resolve_all had already loaded.
    return dict((p, resolve(hypothesis_revision, p, root=root, stores=stores, source=source))
                for p in names)


# ---------------------------------------------------------------------------------------------
# Round-trip. The design's first acceptance word for this slice.

def canonical_line(rec):
    """The one canonical serialisation of a registry row.

    Sorted keys and a compact separator, so a row read and re-written is byte-identical unless its
    CONTENT changed. Without a canonical form, "round-trip deterministic" is a claim about
    whichever json writer happened to run.
    """
    return json.dumps(rec, sort_keys=True, ensure_ascii=False, separators=(', ', ': '))


def round_trip(rel, root=None):
    """-> list of line numbers whose canonical re-serialisation differs from the stored line."""
    root = REPO_ROOT if root is None else root
    path = os.path.join(root, rel.replace('/', os.sep))
    if not os.path.isfile(path):
        _refuse('%s is not present' % rel)
    bad = []
    with io.open(path, encoding='utf-8') as fh:  # snapshot: worktree
        for n, line in enumerate(fh, 1):
            line = line.rstrip('\n')
            if not line.strip():
                continue
            rec = json.loads(line)
            if canonical_line(rec) != line:
                bad.append(n)
    return bad


def rewrite_canonical(rel, root=None):
    """Rewrite a store in canonical form. The ONLY sanctioned writer of these files' formatting.

    ATOMIC per file: the canonical text is built, written to a sibling temp file, then
    os.replace()d. A blind audit measured the previous version leaving a PARTIAL MUTATION -- it
    rewrote four stores and then raised on the fifth (the BLOCKED, absent universe store), so a
    failed canonicalize left the tree half-rewritten with no signal about which half. Reproduced
    live twice while fixing it, which is why this is written in the past tense rather than as a
    hypothetical.
    """
    root = REPO_ROOT if root is None else root
    path = os.path.join(root, rel.replace('/', os.sep))
    with io.open(path, encoding='utf-8') as fh:  # snapshot: worktree
        recs = [json.loads(l) for l in fh if l.strip()]
    text = ''.join(canonical_line(rec) + '\n' for rec in recs)
    tmp = path + '.tmp'
    with io.open(tmp, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(text)
    os.replace(tmp, path)
    return len(recs)


USAGE = ('usage: python _triage/factory_os/registry.py check\n'
         '       python _triage/factory_os/registry.py resolve <hypothesis_revision> [<parameter>]\n'
         '       python _triage/factory_os/registry.py canonicalize')


def main(argv):
    # `--root=<path>` REPLACES the tree. `--overlay-root=<path>` ADDS to it, canonical winning
    # every key it defines.
    #
    # ⚠️ THE ARGUMENT FOR --root WAS WRONG AND A BLIND AUDIT DISPROVED IT. It used to read "there
    # is no root that turns a REFUSE into an ALLOW", on the grounds that a binding only ever adds a
    # refusal. That is true of ADDING a binding and false of REPLACING the store: a canonical root
    # holding a LOCKED binding gave REFUSE, and an empty --root gave ALLOW. The seam bought exactly
    # the permission its own comment said it could not, reproduced end to end through
    # optimize_guard.
    #
    # So the CONSUMER seam is now --overlay-root, which merges canonical-last and therefore cannot
    # remove or relax a canonical binding by construction rather than by argument. --root survives
    # for callers that legitimately mean a different tree entirely (this module's own fixtures,
    # which build a whole synthetic repo), and it is NOT what optimize_guard passes.
    root = None
    overlay = None
    argv = [a for a in argv]
    keep = []
    for a in argv:
        if a.startswith('--root='):
            root = a.split('=', 1)[1]
        elif a.startswith('--overlay-root='):
            overlay = a.split('=', 1)[1]
        else:
            keep.append(a)
    argv = keep
    if len(argv) >= 2 and argv[1] == 'check':
        try:
            stores = load_all(root=root)
        except RegistryRefusal as exc:
            print('[REFUSED] %s' % exc)
            return 1
        for rel in sorted(stores):
            meta, rows = stores[rel]
            print('%-40s %d row(s), %d metadata line(s)' % (rel, len(rows), len(meta)))
        return 0
    if len(argv) in (3, 4) and argv[1] == 'resolve':
        try:
            if len(argv) == 4:
                out = resolve(argv[2], argv[3], root=root, overlay_root=overlay)
            else:
                out = resolve_all(argv[2], root=root, overlay_root=overlay)
        except RegistryRefusal as exc:
            print('[REFUSED] %s' % exc)
            return 1
        sys.stdout.write(json.dumps(out, sort_keys=True))
        return 0
    if len(argv) == 2 and argv[1] == 'canonicalize':
        # PLAN FIRST, THEN WRITE. The audit reproduced `CANONICALIZE_PARTIAL_MUTATION=True`: this
        # loop rewrote four stores and then raised on the BLOCKED store that does not exist, and it
        # ignored the `--root` it had just parsed. Both are fixed -- the target list is resolved and
        # EVERY file is parsed before ANY file is written, so an unreadable store aborts the whole
        # operation with nothing mutated.
        base = REPO_ROOT if root is None else root
        targets = []
        for rel in sorted(STORES):
            path = os.path.join(base, rel.replace('/', os.sep))
            if not os.path.isfile(path):
                if rel in STORES_BLOCKED:
                    print('%-40s SKIPPED (declared BLOCKED and absent)' % rel)
                    continue
                print('[REFUSED] %s is not present -- nothing was rewritten' % rel)
                return 1
            targets.append(rel)
        for rel in targets:
            with io.open(  # snapshot: worktree
                    os.path.join(base, rel.replace('/', os.sep)),
                    encoding='utf-8') as fh:
                for line in fh:
                    if line.strip():
                        json.loads(line)
        for rel in targets:
            print('%-40s %d row(s) rewritten canonically'
                  % (rel, rewrite_canonical(rel, root=base)))
        return 0
    print(USAGE)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv))
