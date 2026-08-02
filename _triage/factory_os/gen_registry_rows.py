# -*- coding: utf-8 -*-
"""gen_registry_rows.py -- ORDER-1020 (slice S7). Emits the Hypothesis and ParameterBinding rows.

WHY GENERATED RATHER THAN HAND-WRITTEN. A `ParameterBinding` row carries five facts that are
DERIVED and two that are DECIDED. Derived: whether the parameter is reachable under this
hypothesis's config, which capability owns it, what the locked value is, the `OwnerRef` pin of the
row that owns its permanent semantics, and the architecture digest the hypothesis hangs off.
Decided: its `role`/`surface` and its `optimize_stage`/`safe_range`. Hand-writing 116 rows would
mean hand-copying the derived five into each -- 580 opportunities for a copy of a fact to go stale
while looking perfectly plausible, which is `BACKLOG-D29`'s shape at scale.

So: `hypothesis_b14.py` holds the DECIDED half as data, `activation.py`/`capability.py`/
`architecture.py` compute the DERIVED half, and this module joins them. Re-running it after any
change to `Inputs.mqh` reproduces the rows or REFUSES -- it cannot silently produce a smaller set.

  🔴 IT REFUSES RATHER THAN DEFAULTS, IN BOTH DIRECTIONS. A reachable input with no entry in
  `DECISIONS` is a refusal (it would otherwise land on some surface with nobody's decision behind
  it); and an entry in `DECISIONS` naming an input the config cannot reach is ALSO a refusal (a
  stale entry would keep a dial visible after the mode that needed it was switched off, and
  nothing else would notice).

  🔴 AND IT REFUSES AN ENGINE-EDGE HYPOTHESIS WITH NO REACHABLE LOSS CAP. `CLAUDE.md`'s ENGINE-EDGE
  cage condition 1 is "worst case is computable -- hard depth cap + basket-SL/DD-kill". At the
  chassis defaults every basket-level cap is zero, so a hypothesis registered without pinning one
  would carry the label and not the cage. This is the one place that can tell, because it is the
  only place that knows both the label and the reachability.

CATEGORY (TIER_SNAPSHOT_DESIGN.md section 2/3.3): BUILDER. Text comes from the caller through a
`read(relpath) -> text` callable; only the CLI opens paths and resolves git pins, and it says so.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import activation                                  # noqa: E402
import architecture                                # noqa: E402
import capability                                  # noqa: E402
import hypothesis_b14 as HB                        # noqa: E402
import preset                                      # noqa: E402
import registry                                    # noqa: E402

Refusal = preset.PresetRefusal

HYPOTHESES_REL = 'factory/hypotheses.jsonl'
BINDINGS_REL = 'factory/parameter_bindings.jsonl'

# The role every unreachable input gets, and the surface that follows from it. Not a default in the
# "we had to pick something" sense: an input the build cannot reach has no dial to show and no
# dimension to sweep, and design 5.4's table says exactly this row.
INACTIVE_ROLE = 'INACTIVE'
INACTIVE_SURFACE = 'HIDDEN'

# The inputs that satisfy ENGINE-EDGE cage condition 1 -- a basket-level loss cap. At least ONE of
# these must be REACHABLE in an engine_edge hypothesis's pinned config. CLOSED: a new cap added to
# the chassis has to be named here, and until it is, pinning only that one does not satisfy the
# check. That is the safe direction -- the failure is a refusal, not a false pass.
LOSS_CAPS = ('_32_SL_Money', '_32_SL_BalPct', 'RC_AcctDDLimitPct', '_2_MaxHoldBars')


def pinned_config(hyp, surface):
    """-> the full effective config for one hypothesis: the build's declared defaults with the
    hypothesis's overrides applied. REFUSES an override the build does not expose."""
    cfg = dict((d.name, d.default_expr) for d in surface.inputs)
    for key, value in sorted(hyp['config'].items()):
        if key not in cfg:
            raise Refusal(
                'hypothesis config sets %r, which build %s does not expose. Refused rather than '
                'carried: a config key the build cannot read describes a strategy that will not '
                'run, and the hypothesis would be about nothing.' % (key, surface.build_tag))
        cfg[key] = value
    return cfg


def _check_engine_edge_cage(hyp_id, hyp, verdicts):
    if not hyp.get('engine_edge'):
        return
    live = [n for n in LOSS_CAPS if n in verdicts and verdicts[n].active]
    if not live:
        raise Refusal(
            '%s is labelled engine_edge and its pinned config leaves EVERY basket-level loss cap '
            'unreachable (%s). CLAUDE.md ENGINE-EDGE cage condition 1 requires a computable worst '
            'case -- hard depth cap AND basket-SL/DD-kill, stated as a number. Refused at '
            'registration rather than caught at a verdict: a hypothesis that carries the label '
            'without the cage is the exact shape the label was invented to stop.'
            % (hyp_id, ', '.join(LOSS_CAPS)))


def hypothesis_row(hyp_id, hyp, surface, read, owner_ref):
    """-> the Hypothesis dict. `owner_ref` is a callable (path) -> OwnerRef dict."""
    cfg = pinned_config(hyp, surface)
    _arch, digest = architecture.digest_for(surface.build_tag, cfg, surface=surface)
    modules = capability.module_set(surface.build_tag, cfg, read, surface=surface)
    return {
        'entity': 'Hypothesis',
        'hypothesis_id': hyp_id,
        'boss_family': hyp['boss_family'],
        'revision': hyp['revision'],
        'revision_id': '%s-r%d' % (hyp_id, hyp['revision']),
        'architecture_digest': digest,
        'module_set': modules,
        'coupling_class': hyp['coupling_class'],
        'experimental': hyp['experimental'],
        'engine_edge': hyp['engine_edge'],
        'status': hyp['status'],
        'preregistration_ref': owner_ref(HB.PREREGISTRATION_ORDER,
                                         anchor=hyp['preregistration_anchor']),
        'superseded_by': None,
    }


def binding_rows(hyp_id, hyp, surface, owner_ref):
    """-> [ParameterBinding] for every input on the build's surface, in surface order."""
    cfg = pinned_config(hyp, surface)
    verdicts = activation.classify(surface.build_tag, cfg, surface=surface)
    _check_engine_edge_cage(hyp_id, hyp, verdicts)

    decisions = HB.decisions_for(hyp_id)
    revision_id = '%s-r%d' % (hyp_id, hyp['revision'])
    definition = owner_ref(HB.DEFINITION_PATH)

    # Both completeness directions, computed before anything is emitted so the refusal names the
    # whole discrepancy rather than the first item of it.
    visible = [n for n, v in verdicts.items()
               if v.active and n not in HB.LOCKED_SELECTORS]
    undecided = [n for n in visible if n not in decisions]
    if undecided:
        raise Refusal(
            '%s leaves %d reachable, unlocked input(s) with no entry in DECISIONS: %s. Refused: '
            'an input nobody classified would still be emitted, land on a surface, and be offered '
            'to the optimizer with no decision behind it.'
            % (revision_id, len(undecided), ', '.join(undecided)))
    stale = [n for n in sorted(decisions) if n not in visible]
    if stale:
        raise Refusal(
            '%s DECISIONS names %d input(s) that are not reachable-and-unlocked under its pinned '
            'config: %s. Refused: a stale entry keeps a dial on the Operator surface after the '
            'mode that needed it was switched off, and nothing else in the chain would notice.'
            % (revision_id, len(stale), ', '.join(stale)))

    rows = []
    for name, verdict in verdicts.items():
        row = {
            'entity': 'ParameterBinding',
            'hypothesis_revision': revision_id,
            'parameter': name,
            'build_tag': surface.build_tag,
            'definition_ref': definition,
        }
        if not verdict.active:
            row['role'] = INACTIVE_ROLE
            row['surface'] = INACTIVE_SURFACE
            row['optimize_stage'] = 'FREEZE'
            row['safe_range'] = None
        elif name in HB.LOCKED_SELECTORS:
            row['role'] = 'LOCKED'
            row['surface'] = INACTIVE_SURFACE     # a const has no page to appear on
            row['locked_value'] = cfg[name]
            row['optimize_stage'] = 'FREEZE'
            row['safe_range'] = None
        else:
            role, surf, stage, rng = decisions[name]
            row['role'] = role
            row['surface'] = surf
            row['optimize_stage'] = stage
            row['safe_range'] = (None if rng is None else
                                 {'start': rng[0], 'step': rng[1], 'stop': rng[2]})
        rows.append(row)
    return rows


def _validate_vocabulary(rows):
    """Every role and surface must be in the ONE vocabulary `registry.py` owns. Read from that
    module rather than restated, because `check_registries` R4 refuses a second copy of it and a
    second copy is exactly what a literal list here would be."""
    for row in rows:
        if row.get('role') not in registry.ROLES:
            raise Refusal('row for %r carries role %r, not in %s'
                          % (row.get('parameter'), row.get('role'), list(registry.ROLES)))
        if row.get('surface') not in registry.SURFACES:
            raise Refusal('row for %r carries surface %r, not in %s'
                          % (row.get('parameter'), row.get('surface'), list(registry.SURFACES)))


def build(surface, read, owner_ref, hypothesis_ids=None):
    """-> (hypothesis rows, binding rows). Deterministic: no clock, no dict-order dependence."""
    ids = sorted(hypothesis_ids or HB.HYPOTHESES)
    hyps, binds = [], []
    for hyp_id in ids:
        hyp = HB.HYPOTHESES[hyp_id]
        hyps.append(hypothesis_row(hyp_id, hyp, surface, read, owner_ref))
        binds.extend(binding_rows(hyp_id, hyp, surface, owner_ref))
    _validate_vocabulary(binds)
    return hyps, binds


def render_jsonl(existing_text, rows, entity):
    """-> the store's full text: its `_comment` header lines, then the rows.

    The header is PRESERVED and the previous rows for this entity are REPLACED, not appended to.
    Appending would make a re-run double the store while every individual line stayed valid --
    the failure mode a generator has that a hand-edited file does not.
    """
    header = []
    for line in (existing_text or '').replace('\r\n', '\n').split('\n'):
        if not line.strip():
            continue
        try:
            obj = json.loads(line)
        except ValueError:
            raise Refusal('%s store carries a line that is not JSON: %r' % (entity, line[:80]))
        if '_comment' in obj and 'entity' not in obj:
            header.append(line)
    out = list(header)
    for row in rows:
        # THE RESOLVER'S canonical form, not a local `json.dumps`. The first version of this line
        # chose its own separators and `check_registries` R1 refused all 232 rows: a store whose
        # re-serialisation differs from its stored bytes reports every line as changed on the next
        # read-write cycle, for edits nobody made.
        out.append(registry.canonical_line(row))
    return '\n'.join(out) + '\n'


def _repo_root():
    return os.path.dirname(os.path.dirname(HERE))


def main(argv):
    import io
    import gen_s2a_migration                       # noqa: E402  -- the ONE OwnerRef builder

    root = _repo_root()

    def read(rel):
        return io.open(os.path.join(root, rel.replace('/', os.sep)), encoding='utf-8-sig').read()

    head = gen_s2a_migration.head_oid()

    def owner_ref(path, anchor=None):
        ref = gen_s2a_migration.owner_ref_for(path, head)
        ref['entity'] = 'OwnerRef'
        ref['owner_type'] = ('taskboard_order' if path.endswith('TASKBOARD.md')
                             else 'param_registry')
        ref['anchor'] = anchor
        return ref

    surface = preset.parse_surface(read(preset.INPUTS_REL), HB.BUILD_TAG)
    try:
        hyps, binds = build(surface, read, owner_ref)
    except Refusal as exc:
        sys.stderr.write('REFUSED: %s\n' % exc)
        return 1

    hyp_text = render_jsonl(read(HYPOTHESES_REL), hyps, 'Hypothesis')
    bind_text = render_jsonl(read(BINDINGS_REL), binds, 'ParameterBinding')

    if '--write' in argv:
        for rel, text in ((HYPOTHESES_REL, hyp_text), (BINDINGS_REL, bind_text)):
            io.open(os.path.join(root, rel.replace('/', os.sep)), 'w',
                    encoding='utf-8', newline='\n').write(text)
            sys.stdout.write('wrote %s\n' % rel)

    import collections
    by = collections.Counter((r['role'], r['surface']) for r in binds)
    sys.stdout.write('\n%d hypothesis row(s), %d binding row(s), pinned at %s\n'
                     % (len(hyps), len(binds), head[:12]))
    for hyp in hyps:
        sys.stdout.write('  %-12s digest=%s  %d capability token(s)  status=%s\n'
                         % (hyp['revision_id'], hyp['architecture_digest'],
                            len(hyp['module_set']), hyp['status']))
    sys.stdout.write('  role x surface:\n')
    for (role, surf), n in sorted(by.items()):
        sys.stdout.write('    %-9s %-9s %3d\n' % (role, surf, n))
    operator = sum(n for (r, s), n in by.items() if s == 'OPERATOR')
    sys.stdout.write('  OPERATOR surface total: %d  (design 5.3 target: <= 40 per Boss)\n'
                     % operator)
    unknown = [r['parameter'] for r in binds
               if r['surface'] == 'OPERATOR' and r.get('optimize_stage') == 'UNKNOWN']
    sys.stdout.write('  OPERATOR rows carrying optimize_stage=UNKNOWN: %d%s\n'
                     % (len(unknown), (' -- ' + ', '.join(unknown)) if unknown else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
