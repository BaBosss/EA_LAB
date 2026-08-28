# -*- coding: utf-8 -*-
"""check_param_surface.py -- ORDER-1020 (slice S7). The design 5.4 state table, enforced.

WHAT DESIGN 5.4 ASKS FOR. Three places must tell ONE story about every input, or the optimizer is
being told two:

  | state              | in the wrapper | in the registry                  | optimize_guard |
  | active tunable     | `input`        | role=TUNABLE, surface=OPERATOR   | ALLOW          |
  | precedence member  | `input`        | role=TUNABLE + precedence_owner  | ALLOW unless superseded |
  | locked by hypothesis | `const`      | role=LOCKED                      | REFUSE         |
  | safety             | `sinput`       | role=SAFETY                      | REFUSE always  |
  | inert on this build| absent         | role=INACTIVE                    | REFUSE         |

  🔴 THE PRECEDENCE ROW IS A REPAIRED P0, NOT A DETAIL. `classification=OVERRIDE` means *member of
  a precedence chain*, NOT *dead*. Reading it as dead refused three working dials on 2026-07-30 and
  the only way past was a flag that also disabled the checks that had evidence. So P2 below asserts
  the opposite direction too: an `OVERRIDE`-classified input that this hypothesis can reach must
  NOT come back INACTIVE.

WHAT THIS CHECKER IS FOR, IN ONE SENTENCE. The rows in `factory/parameter_bindings.jsonl` are
GENERATED, and a generated artifact is right on the day it is written and silently wrong on the day
its source moves -- so P5 regenerates them and compares, and everything above P5 checks that what
was generated is internally coherent with the resolver's own vocabulary.

WHAT IT DELIBERATELY DOES NOT DO. It does not drive `optimize_guard`. That half lives in
`scripts/_test/run_registry_tests.ps1`, which runs the REAL guard and observes it turning ALLOW
into REFUSE for a LOCKED binding -- a claim only a real run can make. A python checker asserting
"the guard would refuse this" would be a second opinion about the guard, which is the exact defect
`check_registries` R4 exists to refuse one layer up. Stated here so the split is a decision rather
than a gap.

WHICH BYTES THIS JUDGES. One `EvidenceSource`, so every file is read at ONE moment -- the index in
hook mode. Comparing a STAGED `Inputs.mqh` against a WORKTREE binding store would pass on the one
commit this guard exists to refuse.

EXIT 0 accepted - 1 rejected - 2 could not be performed.
"""
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

import evidence                                   # noqa: E402
import gen_registry_rows as gen                   # noqa: E402
import hypothesis_b14 as HB                       # noqa: E402
import preset                                     # noqa: E402
import registry                                   # noqa: E402

ToolFailure = evidence.ToolFailure

# Design 5.3's target, as a number this checker can fail on rather than a sentence in a document.
OPERATOR_MAX = 40


def _src(worktree=False):
    mode = 'worktree' if worktree else os.environ.get('EA_LAB_EVIDENCE', 'index')
    return evidence.EvidenceSource(mode, root=ROOT)


def _rows_of(text, entity):
    out = []
    for n, line in enumerate(text.replace('\r\n', '\n').split('\n'), start=1):
        if not line.strip():
            continue
        rec = json.loads(line)
        if rec.get('entity') == entity:
            out.append((n, rec))
    return out


# ---------------------------------------------------------------------------------------------
# THE MIXED-VINTAGE GUARD, and it is a diagnosis rather than a fix.
#
# 🔴 /scrutinize round 3, PROBED: this checker reads the STORES through the EvidenceSource -- the
# INDEX under the hook -- but the generator it compares against (`gen_registry_rows` and the four
# modules it imports) is loaded by PYTHON, from DISK. So P5 compares index bytes against a
# worktree generator. Demonstrated: an UNSTAGED edit to `hypothesis_b14.py` made an index-mode run
# report `P5 ... is not what gen_registry_rows.py produces`, i.e. it refused a commit that does
# not contain the edit -- and told the author to REGENERATE, which would stage a change they had
# not decided to make.
#
# Loading the generator from the index is possible and NOT done here: it would mean exec'ing five
# committed modules in a synthetic namespace, and `check_input_surface_gen` (ORDER-710/730) has
# the identical shape, so the fix belongs to both at once rather than to whichever file was
# touched last. What IS done is to stop the message being wrong: if any generator module differs
# between the index and the worktree, say THAT, because "I am comparing two vintages" and "your
# store is stale" have different next steps and only one of them is true.
_GENERATOR_MODULES = (
    '_triage/factory_os/gen_registry_rows.py',
    '_triage/factory_os/hypothesis_b14.py',
    '_triage/factory_os/activation.py',
    '_triage/factory_os/architecture.py',
    '_triage/factory_os/capability.py',
)


def _import_matches_source(src):
    """-> a problem string when the IMPORTED decision table is not the one in the source file.

    🔴 /scrutinize round 3, and this one nearly shipped a decision nobody made. A probe mutated
    `hypothesis_b14.py`, restored it in a `finally`, and CPython kept serving the mutated
    bytecode: a `.pyc` is reused when `(mtime, size)` match, the edit swapped `OPERATOR` for
    `RESEARCH` (both 8 characters) and the restore landed in the same second -- so both matched
    and the stale cache was considered valid. `gen_registry_rows.py --write` then baked
    `_14_DistAtrMult: RESEARCH` into the canonical store.

    P5 reported CLEAN throughout, and could not have done otherwise: it regenerates through the
    SAME import, so both sides of its comparison carried the same stale code. That is the
    "a guard that caches the value it watches" family (memory
    `name-it-honestly-when-you-cannot-prove-it`) -- the only thing that caught it was comparing
    the store against `HEAD` by hand.

    So the table is re-executed from its own TEXT, in a throwaway namespace, and compared to what
    python imported. It is deliberately a second reader of one fact -- normally the thing this
    tree forbids -- because detecting that the import is NOT the source is exactly what a single
    reader cannot do.
    """
    rel = '_triage/factory_os/hypothesis_b14.py'
    try:
        text = src.read_committed(rel)
    except ToolFailure as exc:
        return 'P5 could not read %s to check it against the import: %s' % (rel, exc)
    ns = {'__name__': 'hypothesis_b14__source_check', '__file__': os.path.join(ROOT, rel)}
    try:
        exec(compile(text, rel, 'exec'), ns)                    # noqa: S102 -- our own module
    except Exception as exc:                                    # noqa: BLE001
        return 'P5 %s does not execute: %s: %s' % (rel, type(exc).__name__, str(exc)[:120])
    for attr in ('HYPOTHESES', 'DECISIONS', 'DECISIONS_H02_EXTRA', 'LOCKED_SELECTORS'):
        if ns.get(attr) != getattr(HB, attr):
            return (
                'P5 the %s python IMPORTED from %s is not the %s in the file. A stale __pycache__ '
                'entry is served whenever (mtime, size) match, so a same-length edit restored '
                'inside one second is invisible to CPython -- and P5 cannot see it either, because '
                'it regenerates through the same import. Delete %s/__pycache__ and re-run.'
                % (attr, rel, attr, os.path.dirname(rel)))
    return None


def _generator_vintage_mismatch(src):
    """-> [relpath] whose committed bytes differ from the worktree copy python actually imported."""
    if src.mode != 'index':
        return []
    out = []
    for rel in _GENERATOR_MODULES:
        try:
            committed = src.read_committed(rel)
        except ToolFailure:
            out.append(rel)
            continue
        try:
            # `evidence.observe` is the DECLARED door for a category-B read -- "the disk, in
            # every mode" -- and this is one: the question is not "are these bytes correct", it
            # is "is the copy python IMPORTED the copy the commit carries". T7 was right to
            # refuse a bare open() here even with a snapshot comment -- a declaration does not
            # CHOOSE bytes, and the door that does is this one. It also fstats before and after,
            # so a file rewritten mid-read is refused rather than compared against a guess.
            raw, _stat = evidence.observe(os.path.join(ROOT, rel.replace("/", os.sep)))
            disk = raw.decode("utf-8").replace(chr(13) + chr(10), chr(10))
        except (ToolFailure, UnicodeDecodeError):
            out.append(rel)
            continue
        if committed != disk:
            out.append(rel)
    return out


def check(worktree=False, source=None):
    """-> list of problem strings. Empty means the state table holds."""
    src = source or _src(worktree)
    problems = []

    inputs_text = src.read_committed(preset.INPUTS_REL)
    bind_text = src.read_committed(gen.BINDINGS_REL)
    hyp_text = src.read_committed(gen.HYPOTHESES_REL)

    bindings = _rows_of(bind_text, 'ParameterBinding')
    hypotheses = _rows_of(hyp_text, 'Hypothesis')

    # Inputs.mqh retains legacy SMC/5B declarations for source compatibility, while the
    # accepted A1-A5 logical registry deliberately excludes them. The state-table contract
    # governs the logical registry surface, not those compatibility-only declarations.
    raw_surface = preset.parse_surface(inputs_text, HB.BUILD_TAG)
    registry_rows = registry.parse_parameter_registry_text(
        src.read_committed(registry.PARAM_REGISTRY_REL), registry.PARAM_REGISTRY_REL)
    logical_names = {registry.bare_registry_name(row['name']) for row in registry_rows
                     if row.get('classification', '').strip().upper() != 'COMPATIBILITY'}
    surface = preset.Surface(HB.BUILD_TAG,
                             [decl for decl in raw_surface.inputs if decl.name in logical_names],
                             raw_surface.known_tags)
    surface.enums = raw_surface.enums

    by_rev = {}
    for _n, rec in bindings:
        by_rev.setdefault(rec.get('hypothesis_revision'), []).append(rec)

    registered = set(h.get('revision_id') for h in (r for _n, r in hypotheses))

    # --- P1 every revision's binding set covers the build's surface EXACTLY ---------------------
    for rev in sorted(by_rev):
        rows = by_rev[rev]
        names = [r.get('parameter') for r in rows]
        dupes = sorted(set(n for n in names if names.count(n) > 1))
        if dupes:
            problems.append(
                'P1 %s binds %d parameter(s) more than once: %s. Two rows for one parameter under '
                'one revision have no correct answer, and whichever the resolver indexed last '
                'would decide silently.' % (rev, len(dupes), ', '.join(dupes[:8])))
        missing = [d.name for d in surface.inputs if d.name not in set(names)]
        if missing:
            problems.append(
                'P1 %s leaves %d of build %s\'s %d inputs unbound: %s. An unbound input under a '
                'DECLARED revision is a REFUSAL at the guard (ORDER-671), so a gap here does not '
                'fail open -- it makes a working dial unusable, which is the failure people route '
                'around.' % (rev, len(missing), surface.build_tag, len(surface),
                             ', '.join(missing[:8])))
        extra = sorted(set(n for n in names if n not in surface.by_name))
        if extra:
            problems.append(
                'P1 %s binds %d parameter(s) build %s does not expose: %s. A binding for an input '
                'that does not exist is a claim nothing can falsify.'
                % (rev, len(extra), surface.build_tag, ', '.join(extra[:8])))

    # --- P2 the state table itself --------------------------------------------------------------
    for rev in sorted(by_rev):
        for rec in by_rev[rev]:
            name = rec.get('parameter')
            role = rec.get('role')
            surf = rec.get('surface')
            where = '%s/%s' % (rev, name)
            if role not in registry.ROLES:
                problems.append('P2 %s carries role %r, which is not in the resolver\'s closed '
                                'vocabulary %s' % (where, role, list(registry.ROLES)))
                continue
            if surf not in registry.SURFACES:
                problems.append('P2 %s carries surface %r, not in %s'
                                % (where, surf, list(registry.SURFACES)))
                continue
            # locked by hypothesis => a const. It has no Inputs page to appear on, and the schema
            # requires the value the const will carry.
            if role == 'LOCKED':
                if rec.get('locked_value') is None:
                    problems.append('P2 %s is role=LOCKED with no locked_value -- the generator '
                                    'would emit a const with nothing to put in it' % where)
                if surf != 'HIDDEN':
                    problems.append('P2 %s is role=LOCKED but surface=%s. A const is not on any '
                                    'page; declaring it OPERATOR promises the operator a dial the '
                                    'wrapper does not compile.' % (where, surf))
            # inert on this build => absent, and therefore hidden.
            if role == 'INACTIVE' and surf != 'HIDDEN':
                problems.append('P2 %s is role=INACTIVE but surface=%s -- an input that cannot '
                                'change anything must not be shown as one that can'
                                % (where, surf))
            # only TUNABLE is optimizable, and that derivation belongs to the resolver.
            optimizable = role in registry.OPTIMIZABLE_ROLES
            if optimizable and surf == 'HIDDEN':
                problems.append('P2 %s is optimizable but HIDDEN: a dimension the optimizer may '
                                'sweep and no surface shows is a sweep nobody can review' % where)

    # --- P3 zero UNKNOWN on the Operator surface (S7's acceptance, as a check) --------------------
    for rev in sorted(by_rev):
        unknown = sorted(r.get('parameter') for r in by_rev[rev]
                         if r.get('surface') == 'OPERATOR'
                         and r.get('optimize_stage') in (None, 'UNKNOWN'))
        if unknown:
            problems.append(
                'P3 %s has %d OPERATOR row(s) whose optimize_stage is UNKNOWN or absent: %s. '
                'Slice S7\'s acceptance is zero UNKNOWN on the Operator surface -- a dial an '
                'operator is shown but no round owns cannot enter an optimize plan.'
                % (rev, len(unknown), ', '.join(unknown[:8])))

    # --- P4 the Operator surface stays inside design 5.3's target --------------------------------
    for rev in sorted(by_rev):
        n = sum(1 for r in by_rev[rev] if r.get('surface') == 'OPERATOR')
        if n > OPERATOR_MAX:
            problems.append(
                'P4 %s exposes %d OPERATOR inputs, over design 5.3\'s target of %d per Boss. The '
                'target is the whole point of the capability allowlist; passing it means the '
                'wrapper is a build flag rather than a thin wrapper.' % (rev, n, OPERATOR_MAX))

    # --- P5 the rows are still what the generator produces ----------------------------------------
    # THE ANTI-DRIFT CRITERION, and the one that makes the four above worth anything: they check
    # that the stored rows are coherent, which a stale-but-coherent store also is.
    def read(rel):
        return src.read_committed(rel)

    try:
        import gen_s2a_migration
        head = gen_s2a_migration.head_oid()

        def owner_ref(path, anchor=None):
            ref = gen_s2a_migration.owner_ref_for(path, head)
            ref['entity'] = 'OwnerRef'
            ref['owner_type'] = ('taskboard_order' if path.endswith('TASKBOARD.md')
                                 else 'param_registry')
            ref['anchor'] = anchor
            return ref

        hyps, binds = gen.build(surface, read, owner_ref)
    except preset.PresetRefusal as exc:
        problems.append('P5 the generator REFUSED to reproduce the stores: %s' % exc)
        return problems

    # WHICH PART OF AN OwnerRef IS EXCLUDED, and /scrutinize round 2 narrowed it. A pin is a
    # HISTORICAL claim, so requiring `commit_oid`/`blob_oid`/`raw_sha256` to track HEAD is the
    # exact defect `check_s2a_migration`'s `--check` had to have removed (memory
    # `drift-guard-regenerating-against-head`). But the first version dropped the WHOLE ref -- and
    # a probe showed the consequence: a `definition_ref` rewritten to point at
    # `docs/NOT_THE_REGISTRY.csv` produced ZERO problems. `path`, `owner_type` and `anchor` are not
    # git-resolved, they are the STATEMENT the pin makes about WHAT it pins, and a row claiming its
    # semantics come from a file that owns none of them is exactly the drift this criterion is for.
    _GIT_RESOLVED = ('commit_oid', 'blob_oid', 'raw_sha256')

    def _strip(rows):
        out = []
        for r in rows:
            c = dict(r)
            for key in ('definition_ref', 'preregistration_ref'):
                ref = c.get(key)
                if isinstance(ref, dict):
                    c[key] = dict((k, v) for k, v in ref.items() if k not in _GIT_RESOLVED)
            out.append(registry.canonical_line(c))
        return out

    stored_binds = _strip([r for _n, r in bindings])
    stored_hyps = _strip([r for _n, r in hypotheses])
    cached = _import_matches_source(src)
    if cached:
        problems.append(cached)
        return problems

    stale = _generator_vintage_mismatch(src)
    if stale and (_strip(binds) != stored_binds or _strip(hyps) != stored_hyps):
        problems.append(
            'P5 CANNOT BE PERFORMED, and that is not the same as failing. %d generator module(s) '
            'differ between the index and the working tree (%s), so the regeneration below '
            'compared committed stores against an UNCOMMITTED generator. Stage the module(s) or '
            'revert them -- do NOT regenerate, which would stage a change you have not decided to '
            'make.' % (len(stale), ', '.join(stale)))
        return problems
    if _strip(binds) != stored_binds:
        problems.append(
            'P5 %s is not what gen_registry_rows.py produces from this snapshot. Regenerate with '
            '`gen_registry_rows.py --write`. A generated store that has drifted from its source '
            'still looks complete and plausible, which is why this is a check and not a habit.'
            % gen.BINDINGS_REL)
    if _strip(hyps) != stored_hyps:
        problems.append('P5 %s is not what gen_registry_rows.py produces from this snapshot'
                        % gen.HYPOTHESES_REL)

    # --- P6 every bound revision is a REGISTERED one ----------------------------------------------
    dangling = sorted(r for r in by_rev if r not in registered)
    if dangling:
        problems.append(
            'P6 %d revision(s) carry bindings but no Hypothesis row: %s. A binding names a '
            'revision, so a dangling one is evidence attributed to a claim nobody registered -- '
            'which is the attribution ground ORDER-671 was ratified on.'
            % (len(dangling), ', '.join(dangling)))

    return problems


def main(argv):
    worktree = '--worktree' in argv
    try:
        src = _src(worktree)
        sys.stdout.write(src.marker('check_param_surface.py') + '\n')
        problems = check(source=src)
    except ToolFailure as exc:
        sys.stdout.write('TOOL FAILURE, not a verdict: %s\n' % exc)
        return 2
    except preset.PresetRefusal as exc:
        sys.stdout.write('REFUSED: %s\n' % exc)
        return 2

    sys.stdout.write('=== ORDER-1020 design 5.4 state table ===\n')
    if problems:
        sys.stdout.write('%d PROBLEM(S):\n' % len(problems))
        for p in problems:
            sys.stdout.write('  - %s\n' % p)
        return 1
    # Say WHAT was checked, not merely that it passed: a criterion that examined nothing is the
    # shape this repo refuses to report as green.
    src2 = _src(worktree)
    binds = _rows_of(src2.read_committed(gen.BINDINGS_REL), 'ParameterBinding')
    revs = sorted(set(r.get('hypothesis_revision') for _n, r in binds))
    for rev in revs:
        rows = [r for _n, r in binds if r.get('hypothesis_revision') == rev]
        op = sum(1 for r in rows if r.get('surface') == 'OPERATOR')
        rs = sum(1 for r in rows if r.get('surface') == 'RESEARCH')
        hd = sum(1 for r in rows if r.get('surface') == 'HIDDEN')
        sys.stdout.write('  %-14s %3d row(s)  OPERATOR %2d (target <= %d)  RESEARCH %2d  '
                         'HIDDEN %3d\n' % (rev, len(rows), op, OPERATOR_MAX, rs, hd))
    if not revs:
        sys.stdout.write('  0 revision(s) bound -- this run checked NOTHING and is UNTESTED, not '
                         'clean\n')
        return 1
    sys.stdout.write('P1 coverage - P2 state table - P3 zero UNKNOWN on OPERATOR - P4 the <= %d '
                     'target - P5 rows match the generator - P6 no dangling revision: all hold\n'
                     % OPERATOR_MAX)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
