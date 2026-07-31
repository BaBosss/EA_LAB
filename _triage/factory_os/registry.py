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

# The role vocabulary. It lives HERE and nowhere else -- C4 greps for a second copy, because two
# copies of a vocabulary is the drift this module exists to prevent.
ROLES = ('TUNABLE', 'RUNTIME', 'SIZING', 'SAFETY', 'LOCKED', 'INACTIVE')
SURFACES = ('OPERATOR', 'RESEARCH', 'HIDDEN')

# Roles a run may OPTIMIZE. An allowlist, not a blacklist: the question "which roles are
# optimizable" must be answered by naming them, so a role added to the enum later is refused until
# somebody decides, rather than inheriting permission from not being on a deny list.
OPTIMIZABLE_ROLES = ('TUNABLE',)


class RegistryRefusal(Exception):
    """This module will not answer for these inputs. A statement about the input, not a verdict."""


def _refuse(msg):
    raise RegistryRefusal(msg)


def read_store(rel, root=None):
    """-> (meta_lines, rows) for one store. Refuses rather than skipping anything it cannot read.

    A store that is ABSENT is refused, not treated as empty -- the rule this repo has paid for
    more than any other. `factory/coverage.jsonl` proves the distinction matters: "no coverage
    cells" and "no coverage store" have opposite fixes.
    """
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
            if any(k in rec for k in META_KEYS):
                meta.append(rec)
                continue
            rows.append((n, rec))
    return meta, rows


def load_all(root=None):
    """-> {rel: (meta, rows)} for every UNBLOCKED store. One read each, so one moment for all.

    A BLOCKED store is skipped rather than refused -- but only while it is genuinely absent.
    `check_registries.R6` is what makes that safe: it refuses a blocked store that has APPEARED,
    so "skipped" can never quietly become "there but unchecked".
    """
    out = {}
    for rel in sorted(STORES):
        if rel in STORES_BLOCKED and not os.path.isfile(
                os.path.join(REPO_ROOT if root is None else root, rel.replace('/', os.sep))):
            continue
        out[rel] = read_store(rel, root=root)
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


def resolve(hypothesis_revision, parameter, root=None, stores=None):
    """-> {parameter, hypothesis_revision, role, surface, optimizable, locked_value, safe_range,
           definition_ref, source}

    `optimizable` is the ONE derived answer this module exists to give, and it is derived HERE so
    that nothing else derives it. `source` names where the answer came from, so a caller can tell
    "bound" from "not bound" without inspecting the shape of what it got back.

    NOT BOUND is not an error and not a default-to-tunable: it returns role=None,
    optimizable=None. A resolver that answered TUNABLE for a parameter nobody bound would be
    granting permission by silence, which is the same defect as reading an absent `experimental`
    field as false -- named in the Hypothesis schema for exactly that reason.
    """
    if stores is None:
        stores = load_all(root=root)
    _meta, rows = stores['factory/parameter_bindings.jsonl']
    rec = _binding_index(rows).get((hypothesis_revision, parameter))
    if rec is None:
        return {'parameter': parameter, 'hypothesis_revision': hypothesis_revision,
                'role': None, 'surface': None, 'optimizable': None,
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
    if role == 'LOCKED' and 'locked_value' not in rec:
        _refuse('binding for %r in %r is role=LOCKED with no `locked_value`. The schema requires '
                'one; this resolver is reached without ajv on the fast path, so it is refused here '
                'too. A locked parameter with no value to lock to is not a lock.'
                % (parameter, hypothesis_revision))
    return {'parameter': parameter, 'hypothesis_revision': hypothesis_revision,
            'role': role, 'surface': surface,
            'optimizable': role in OPTIMIZABLE_ROLES,
            'locked_value': rec.get('locked_value'),
            'safe_range': rec.get('safe_range'),
            'definition_ref': rec.get('definition_ref'),
            'source': 'BOUND'}


def resolve_all(hypothesis_revision, root=None, stores=None):
    """Every binding registered for one revision, keyed by parameter name."""
    if stores is None:
        stores = load_all(root=root)
    _meta, rows = stores['factory/parameter_bindings.jsonl']
    names = sorted(set(rec.get('parameter') for _n, rec in rows
                       if rec.get('hypothesis_revision') == hypothesis_revision))
    return dict((p, resolve(hypothesis_revision, p, stores=stores)) for p in names)


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
    """Rewrite a store in canonical form. The ONLY sanctioned writer of these files' formatting."""
    root = REPO_ROOT if root is None else root
    path = os.path.join(root, rel.replace('/', os.sep))
    with io.open(path, encoding='utf-8') as fh:  # snapshot: worktree
        recs = [json.loads(l) for l in fh if l.strip()]
    with io.open(path, 'w', encoding='utf-8', newline='\n') as fh:
        for rec in recs:
            fh.write(canonical_line(rec) + '\n')
    return len(recs)


USAGE = ('usage: python _triage/factory_os/registry.py check\n'
         '       python _triage/factory_os/registry.py resolve <hypothesis_revision> [<parameter>]\n'
         '       python _triage/factory_os/registry.py canonicalize')


def main(argv):
    # `--root=<path>` resolves against a different tree. It exists so a FIXTURE can drive a real
    # consumer (scripts/optimize_guard.ps1) against synthetic bindings without writing into the
    # committed store -- the same seam snapshot_build.py's <source-root> is, for the same reason.
    #
    # WHY IT CANNOT BUY PERMISSION, which is the question to ask of any override: a binding only
    # ever ADDS a refusal. An UNBOUND parameter resolves optimizable=None and the consumer leaves
    # its existing verdict alone, so pointing this at an empty tree yields exactly the behaviour
    # you get with no --root at all. There is no root that turns a REFUSE into an ALLOW.
    root = None
    argv = list(argv)
    for i, a in enumerate(argv):
        if a.startswith('--root='):
            root = a.split('=', 1)[1]
            argv.pop(i)
            break
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
                out = resolve(argv[2], argv[3], root=root)
            else:
                out = resolve_all(argv[2], root=root)
        except RegistryRefusal as exc:
            print('[REFUSED] %s' % exc)
            return 1
        sys.stdout.write(json.dumps(out, sort_keys=True))
        return 0
    if len(argv) == 2 and argv[1] == 'canonicalize':
        for rel in sorted(STORES):
            print('%-40s %d row(s) rewritten canonically' % (rel, rewrite_canonical(rel)))
        return 0
    print(USAGE)
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv))
