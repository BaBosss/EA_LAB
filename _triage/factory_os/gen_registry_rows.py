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
import hypothesis_b17 as HB17                      # noqa: E402
import preset                                      # noqa: E402
import registry                                    # noqa: E402

Refusal = preset.PresetRefusal

HYPOTHESES_REL = 'factory/hypotheses.jsonl'
BINDINGS_REL = 'factory/parameter_bindings.jsonl'
PROVIDERS = (HB, HB17)

# The role every unreachable input gets, and the surface that follows from it. Not a default in the
# "we had to pick something" sense: an input the build cannot reach has no dial to show and no
# dimension to sweep, and design 5.4's table says exactly this row.
INACTIVE_ROLE = 'INACTIVE'
INACTIVE_SURFACE = 'HIDDEN'

# The inputs that satisfy ENGINE-EDGE cage condition 1 -- a basket-level loss cap -- each with the
# CEILING the ratified rules put on it, or None where no rule states one.
#
# 🔴 /scrutinize round 3: the first version was a bare tuple and checked only that ONE cap was
# REACHABLE, i.e. `> 0`. Probed: `_32_SL_BalPct = 9999` -- a stop at 9999% of balance, which no
# account can ever reach -- SATISFIED the cage. `CLAUDE.md`'s condition 1 is not "a cap exists",
# it is *"worst case is computable ... state the number: a single loss costs <= 15% equity at the
# real sizing"*. A cap whose number caps nothing is the same shape as a guard that never fires:
# present, green, and load-bearing for nothing.
#
# CLOSED: a new cap added to the chassis has to be named here, and until it is, pinning only that
# one does not satisfy the check. The failure direction is a refusal, not a false pass.
LOSS_CAPS = {
    # CLAUDE.md ENGINE-EDGE cage condition 1, verbatim: a single loss costs <= 15% equity.
    '_32_SL_BalPct': (15.0, "CLAUDE.md ENGINE-EDGE cage condition 1: 'a single loss costs "
                            "<=15% equity at the real sizing'"),
    # CLAUDE.md bar table, demo kill: eqDD > 12%. Capping at the same number makes the EA halt
    # WHERE the judge would kill it rather than after it.
    'RC_AcctDDLimitPct': (12.0, "CLAUDE.md bar table demo-kill: eqDD > 12%"),
    # ABSOLUTE money (Inputs.mqh:394 marks it so), therefore instrument- and account-dependent:
    # no ratified rule states a number that is meaningful across accounts, so none is enforced.
    # It still COUNTS as a cap -- it just cannot be checked against a ceiling.
    '_32_SL_Money': (None, 'absolute money; no portable ratified ceiling'),
}

# 🔴 `_2_MaxHoldBars` was in the first version of the list above and has been REMOVED. It is a TIME
# stop, not a loss cap: it force-closes a basket after N bars regardless of what the basket is
# worth, so it bounds DURATION and says nothing about the worst case in equity -- which is the only
# quantity cage condition 1 is about. Recorded rather than deleted silently, because "we already
# count that one" is exactly how a cage acquires a member that does not cage anything.
_NOT_A_LOSS_CAP = {'_2_MaxHoldBars': 'a TIME stop: it bounds duration, not the worst case in equity'}


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


def _check_engine_edge_cage(hyp_id, hyp, verdicts, config):
    """REFUSES an engine_edge hypothesis whose cage is absent OR whose cap does not cap.

    Two questions, and the second is the one round 3 added: is a basket-level loss cap REACHABLE,
    and is its pinned NUMBER within the ceiling the ratified rules put on it.
    """
    if not hyp.get('engine_edge'):
        return
    live = [n for n in sorted(LOSS_CAPS)
            if n in verdicts and verdicts[n]['state'] == 'ACTIVE']
    if not live:
        raise Refusal(
            '%s is labelled engine_edge and its pinned config leaves EVERY basket-level loss cap '
            'unreachable (%s). CLAUDE.md ENGINE-EDGE cage condition 1 requires a computable worst '
            'case -- hard depth cap AND basket-SL/DD-kill, stated as a number. Refused at '
            'registration rather than caught at a verdict: a hypothesis that carries the label '
            'without the cage is the exact shape the label was invented to stop.'
            % (hyp_id, ', '.join(sorted(LOSS_CAPS))))
    for name in live:
        ceiling, why = LOSS_CAPS[name]
        if ceiling is None:
            continue
        try:
            held = float(str(config[name]).strip())
        except (KeyError, TypeError, ValueError):
            raise Refusal(
                '%s pins %s to %r, which is not a number, so whether the cage caps anything '
                'cannot be answered.' % (hyp_id, name, config.get(name)))
        if held > ceiling:
            raise Refusal(
                '%s is labelled engine_edge and pins %s = %s, above the ratified ceiling of %s '
                '(%s). A cap whose number caps nothing is the same shape as a guard that never '
                'fires: present, green, and load-bearing for nothing. Refused at registration, '
                'because the label is what buys this hypothesis the right to proceed at all.'
                % (hyp_id, name, held, ceiling, why))


def hypothesis_row(hyp_id, hyp, surface, read, owner_ref, provider=HB):
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
        'preregistration_ref': owner_ref(
            provider.PREREGISTRATION_ORDER,
            anchor=hyp['preregistration_anchor'],
            commit=hyp.get('preregistration_commit')),
        'superseded_by': None,
    }


def binding_rows(hyp_id, hyp, surface, owner_ref, provider=HB, activation_surface=None):
    """-> [ParameterBinding] for every input on the build's surface, in surface order."""
    cfg = pinned_config(hyp, surface)
    act_surface = activation_surface or surface
    states_all = activation.effective_state(surface.build_tag, cfg, surface=act_surface)
    states = {d.name: states_all[d.name] for d in surface.inputs}
    _check_engine_edge_cage(hyp_id, hyp, states, cfg)

    decisions = provider.decisions_for(hyp_id)
    revision_id = '%s-r%d' % (hyp_id, hyp['revision'])
    definition = owner_ref(provider.DEFINITION_PATH)

    # Both completeness directions, computed before anything is emitted so the refusal names the
    # whole discrepancy rather than the first item of it.
    visible = [n for n, state in states.items()
               if state['state'] == 'ACTIVE' and n not in provider.LOCKED_SELECTORS]
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
    for name, state in states.items():
        row = {
            'entity': 'ParameterBinding',
            'hypothesis_revision': revision_id,
            'parameter': name,
            'parameter_pid': registry.parameter_pid_for(name, surface.build_tag),
            'build_tag': surface.build_tag,
            'definition_ref': definition,
        }
        if state['state'] != 'ACTIVE':
            row['role'] = INACTIVE_ROLE
            row['surface'] = INACTIVE_SURFACE
            row['optimize_stage'] = 'FREEZE'
            row['safe_range'] = None
        elif name in provider.LOCKED_SELECTORS:
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


def build(surface, read, owner_ref, hypothesis_ids=None, provider=HB, activation_surface=None):
    """-> rows for one decision provider. Default preserves the B14 API."""
    ids = sorted(hypothesis_ids or provider.HYPOTHESES)
    hyps, binds = [], []
    for hyp_id in ids:
        hyp = provider.HYPOTHESES[hyp_id]
        hyps.append(hypothesis_row(hyp_id, hyp, surface, read, owner_ref, provider))
        binds.extend(binding_rows(hyp_id, hyp, surface, owner_ref, provider, activation_surface))
    _validate_vocabulary(binds)
    return hyps, binds


def _surfaces(inputs_text, registry_text, build_tag):
    """Return (logical emit surface, exact activation surface) for one build.

    R0 keeps compatibility declarations physical but outside Factory bindings. Activation tables
    may cover either the logical set (B14) or the full physical set (B17/B18); both are valid if
    their table is exact for the surface it claims.
    """
    raw = preset.parse_surface(inputs_text, build_tag)
    rows = registry.parse_parameter_registry_text(registry_text, registry.PARAM_REGISTRY_REL)
    logical = {registry.bare_registry_name(r['name']) for r in rows
               if r.get('classification', '').strip().upper() != 'COMPATIBILITY'}
    emit = preset.Surface(build_tag, [d for d in raw.inputs if d.name in logical], raw.known_tags)
    emit.enums = raw.enums
    table_names = set(activation.TABLE[build_tag])
    act = preset.Surface(build_tag, [d for d in raw.inputs if d.name in table_names], raw.known_tags)
    act.enums = raw.enums
    if set(d.name for d in act.inputs) != table_names:
        missing = sorted(table_names - set(d.name for d in act.inputs))
        raise Refusal('activation table for %s names missing physical input(s): %s'
                      % (build_tag, ', '.join(missing[:10])))
    return emit, act


def build_all(read, owner_ref):
    """Build every registered provider in deterministic provider order."""
    hyps, binds = [], []
    inputs = read(preset.INPUTS_REL)
    registry_text = read(registry.PARAM_REGISTRY_REL)
    for provider in PROVIDERS:
        surface, act_surface = _surfaces(inputs, registry_text, provider.BUILD_TAG)
        hrows, brows = build(surface, read, owner_ref, provider=provider,
                             activation_surface=act_surface)
        hyps.extend(hrows); binds.extend(brows)
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


_GIT_RESOLVED = ('commit_oid', 'blob_oid', 'raw_sha256')

def _store_key(entity, row):
    if entity == 'Hypothesis': return row.get('revision_id')
    return (row.get('hypothesis_revision'), row.get('parameter'))

def _semantic_line(row):
    c = dict(row)
    for field in ('definition_ref', 'preregistration_ref'):
        ref = c.get(field)
        if isinstance(ref, dict):
            c[field] = dict((k, v) for k, v in ref.items() if k not in _GIT_RESOLVED)
    return registry.canonical_line(c)

def render_preserving_equivalent(existing_text, rows, entity):
    """Keep exact bytes/pins for semantically unchanged rows; render only new/changed rows."""
    header, old = [], {}
    for line in (existing_text or '').replace('\r\n','\n').split('\n'):
        if not line.strip(): continue
        obj = json.loads(line)
        if '_comment' in obj and 'entity' not in obj: header.append(line); continue
        if obj.get('entity') == entity: old[_store_key(entity, obj)] = (obj, line)
    out = list(header)
    for row in rows:
        prior = old.get(_store_key(entity, row))
        out.append(prior[1] if prior and _semantic_line(prior[0]) == _semantic_line(row)
                   else registry.canonical_line(row))
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

    def owner_ref(path, anchor=None, commit=None):
        ref = gen_s2a_migration.owner_ref_for(path, commit or head)
        ref['entity'] = 'OwnerRef'
        ref['owner_type'] = ('taskboard_order' if path.endswith('TASKBOARD.md')
                             else 'param_registry')
        ref['anchor'] = anchor
        return ref

    try:
        hyps, binds = build_all(read, owner_ref)
    except Refusal as exc:
        sys.stderr.write('REFUSED: %s\n' % exc)
        return 1

    hyp_text = render_preserving_equivalent(read(HYPOTHESES_REL), hyps, 'Hypothesis')
    bind_text = render_preserving_equivalent(read(BINDINGS_REL), binds, 'ParameterBinding')

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
