# -*- coding: utf-8 -*-
"""run_activation_tests.py -- ORDER-1000 (S7). The cage for the three modules that decide which
inputs a hypothesis can actually reach.

WHAT IS BEING CAGED, AND WHY IT MATTERS MORE THAN IT LOOKS. `architecture.py`, `capability.py` and
`activation.py` together answer: given this build and this config, which of the 116 inputs on
Boss_14's page can change anything? That answer decides three things at once -- what the operator
is shown, what the optimizer is allowed to sweep, and (in slice S8) which inputs the generator
turns into `const`. An error here is therefore not a display bug: an input wrongly called
unreachable becomes a `const` at its default and the strategy quietly changes.

EVERY criterion appears TWICE (`docs/GUARD_SHAPES.md` shape 5):

    ATTACK       the input the criterion exists to refuse. It must be RED.
    SPECIFICITY  the neighbouring input it must NOT refuse, or the property that must NOT move.

The specificity halves carry most of the weight here, because the failure mode of this machinery
is NOT over-refusal, it is INERTNESS: a classifier that calls everything unreachable satisfies
every completeness check, produces a beautifully small Operator surface, and is completely wrong.
So the suite asserts in both directions -- that a dial goes dark when its selector turns it off,
AND that it comes back when the selector turns it on (memory `inert-axis-fake-plateau`).

Each criterion carries a MUTATION PROBE: `--mutate` rewrites ONE line of a COPY of the module
under test and requires the case to go red. Nothing is written inside the repo.

USAGE  tools\\python312\\python.exe _triage/factory_os/run_activation_tests.py [--mutate]
EXIT   0 = every case behaved as declared - 1 = one did not
"""
import importlib.util
import io
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

import activation as ACT                                                    # noqa: E402
import architecture as ARCH                                                 # noqa: E402
import capability as CAP                                                    # noqa: E402
import preset as P                                                          # noqa: E402

BUILD = 'LAB_ENTRY_14'
INPUTS_TEXT = io.open(os.path.join(ROOT, P.INPUTS_REL.replace('/', os.sep)),
                      encoding='utf-8-sig').read()                  # snapshot: worktree
SURFACE = P.parse_surface(INPUTS_TEXT, BUILD)
S16 = P.parse_surface(INPUTS_TEXT, 'LAB_ENTRY_16')


def base_config(surface=None, **over):
    cfg = dict((d.name, d.default_expr) for d in (surface or SURFACE).inputs)
    cfg.update(over)
    return cfg


def _read(rel):
    return io.open(os.path.join(ROOT, rel.replace('/', os.sep)), encoding='utf-8-sig').read()


# --- A1 architecture: a selector the build does not expose is refused, not dropped --------------

def a1_attack(mod):
    """`mod` here is architecture. Ask for a build whose surface lacks a selector the table names,
    by handing it a surface/config pair that genuinely does not carry one."""
    cfg = base_config()
    del cfg['StackMode']
    try:
        mod.digest_for(BUILD, cfg, surface=SURFACE)
        return ('an architecture digest was produced with StackMode absent from the config. A '
                'dropped term makes two builds that genuinely differ hash to one digest, which '
                'is the exact boundary the digest exists to force a revision at.')
    except mod.Refusal:
        return None


def a1_specificity(mod):
    """A changed MECHANISM must move the digest; a changed DIAL must not. Both halves, because a
    digest that never moves and a digest that always moves are equally useless."""
    _a, base = mod.digest_for(BUILD, base_config(), surface=SURFACE)
    _b, mech = mod.digest_for(BUILD, base_config(LotProg='PROG_LOG_POWER'), surface=SURFACE)
    _c, dial = mod.digest_for(BUILD, base_config(_14_DistAtrMult='9.99'), surface=SURFACE)
    if mech == base:
        return 'changing LotProg (a mechanism) did not move the architecture digest'
    if dial != base:
        return ('changing _14_DistAtrMult (a tuning dial) moved the architecture digest, so every '
                're-optimize would force a new hypothesis revision and nobody would register one')
    return None


# --- A2 capability: an EQ-gated capability must not fire at its other values --------------------

def a2_attack(mod):
    cfg = base_config(StackConfirm='CONF_SIG_VALID')
    tokens = mod.enabled_tokens(BUILD, cfg, surface=SURFACE)
    if 'LAB_CAP_PRICEACTION' in tokens:
        return ('LAB_CAP_PRICEACTION is enabled at StackConfirm=CONF_SIG_VALID, which does not '
                'reach PriceAction.mqh at all. That is the "!= off" collapse: it would keep an '
                'entire module\'s inputs visible and sweepable under three values that cannot '
                'run it.')
    return None


def a2_specificity(mod):
    cfg = base_config(StackConfirm='CONF_PA_ENGULF')
    tokens = mod.enabled_tokens(BUILD, cfg, surface=SURFACE)
    if 'LAB_CAP_PRICEACTION' not in tokens:
        return ('LAB_CAP_PRICEACTION is NOT enabled at CONF_PA_ENGULF, the one value that does '
                'reach the module -- so the capability can never be switched on')
    return None


# --- A3 capability: the Boss_16 ownership override ----------------------------------------------

def a3_attack(mod):
    """Kangaroo short-circuits before Stack, so a non-SINGLE StackMode on build 16 does NOT mean
    the stacking module runs. Inputs.mqh:156 calls its own value "informational only"."""
    cfg = base_config(S16, StackMode='STACK_GRID_AGAINST')
    tokens = mod.enabled_tokens('LAB_ENTRY_16', cfg, surface=S16)
    if 'LAB_CAP_STACK' in tokens:
        return ('LAB_CAP_STACK is enabled on build 16 because StackMode is not SINGLE -- but '
                'LabCore short-circuits before Stack.mqh on that build, so the token names a '
                'module that never runs')
    return None


def a3_specificity(mod):
    """The same value on build 14 DOES enable it -- otherwise the override is a blanket off
    switch rather than a build-scoped one."""
    tokens = mod.enabled_tokens(BUILD, base_config(StackMode='STACK_GRID_AGAINST'),
                                surface=SURFACE)
    if 'LAB_CAP_STACK' not in tokens:
        return 'LAB_CAP_STACK is not enabled on build 14 at STACK_GRID_AGAINST'
    return None


# --- A4 activation: the table must cover the surface exactly ------------------------------------

def a4_attack(mod):
    """An input with no entry must be REFUSED, not defaulted to reachable."""
    saved = mod.TABLE[BUILD].pop('_22_TP_ATRmult')
    try:
        mod.classify(BUILD, base_config(), surface=SURFACE)
        return ('an input with no activation entry was classified anyway. It would default to '
                'reachable and land on the Operator surface with no evidence behind it.')
    except mod.Refusal:
        return None
    finally:
        mod.TABLE[BUILD]['_22_TP_ATRmult'] = saved


def a4_specificity(mod):
    """The REAL table classifies the REAL surface with no refusal and no gaps."""
    try:
        verdicts = mod.classify(BUILD, base_config(), surface=SURFACE)
    except mod.Refusal as exc:
        return 'the real build-14 table was refused against the real surface: %s' % str(exc)[:180]
    if len(verdicts) != len(SURFACE):
        return 'classify returned %d verdicts for a %d-input surface' % (len(verdicts),
                                                                        len(SURFACE))
    return None


# --- A5 activation: a STALE entry is refused too -------------------------------------------------

def a5_attack(mod):
    mod.TABLE[BUILD]['_17_UseStructLevels'] = ('LAB_CAP_CORE', mod.ALWAYS)
    try:
        mod.classify(BUILD, base_config(), surface=SURFACE)
        return ('the table classifies an input build 14 does not expose and nothing complained. '
                'A stale entry keeps passing every check that only looks the other way.')
    except mod.Refusal:
        return None
    finally:
        mod.TABLE[BUILD].pop('_17_UseStructLevels', None)


def a5_specificity(mod):
    """An UNDECLARED BUILD is refused rather than answered -- "no table" must not look like "no
    inactive inputs"."""
    try:
        mod.classify('LAB_ENTRY_16', base_config(S16), surface=S16)
        return ('build 16 was classified although slice S7 declared build 14 only, so an absent '
                'table produced a confident answer')
    except mod.Refusal:
        return None


# --- A6 activation: reachability actually MOVES with the selector (the inertness check) ----------

DARK_UNDER_NO_SL = ('_33_SL_ATRmult', '_33_AdaptiveON', '_31_SL_Pip', '_34_DonchianBars')


def a6_attack(mod):
    """Under SLMode=SL_NONE every SL sub-mode dial must be unreachable."""
    v = mod.classify(BUILD, base_config(SLMode='SL_NONE'), surface=SURFACE)
    live = [n for n in DARK_UNDER_NO_SL if v[n].active]
    if live:
        return ('with SLMode=SL_NONE these SL dials are still called reachable: %s. They would '
                'be offered to the optimizer as dimensions that cannot change the result -- the '
                'inert-axis fake plateau, by construction.' % ', '.join(live))
    return None


def a6_specificity(mod):
    """...and they must come BACK when the selector selects them. A classifier that calls
    everything dark passes the attack above and is completely wrong."""
    v = mod.classify(BUILD, base_config(SLMode='SL_ATR'), surface=SURFACE)
    if not v['_33_SL_ATRmult'].active:
        return ('_33_SL_ATRmult is unreachable at SLMode=SL_ATR, the one mode that reads it -- '
                'the classifier is inert, not selective')
    if not v['_33_AdaptiveON'].active:
        return '_33_AdaptiveON is unreachable at SLMode=SL_ATR'
    v2 = mod.classify(BUILD, base_config(SLMode='SL_STRUCT_DONCHIAN'), surface=SURFACE)
    if not v2['_34_DonchianBars'].active:
        return '_34_DonchianBars is unreachable at SLMode=SL_STRUCT_DONCHIAN'
    return None


# --- A7 activation: the two reasons for darkness are told apart ----------------------------------

def a7_attack(mod):
    """A dial dark because its MODULE is off, and one dark because its OWN gate is closed, have
    different fixes. Reporting both as "inactive" sends the reader to the wrong place."""
    v = mod.classify(BUILD, base_config(RecoveryMode='REC_NONE', SLMode='SL_ATR'),
                     surface=SURFACE)
    module_off = v['_8_TriggerATR']          # LAB_CAP_RECOVERY not enabled
    gate_closed = v['_33_SL_MaxPips']        # capability on, own SELF_GT0 gate closed at 0.0
    if module_off.active or gate_closed.active:
        return 'the fixture is wrong: both of these should be dark'
    if module_off.token_enabled:
        return '_8_TriggerATR reports its capability as ENABLED while RecoveryMode is REC_NONE'
    if not gate_closed.token_enabled:
        return ('_33_SL_MaxPips reports its capability as disabled, but LAB_CAP_EXIT is always '
                'on -- the two reasons have been collapsed into one')
    return None


def a7_specificity(mod):
    """The reachable case must say so, and must not claim either failure reason."""
    v = mod.classify(BUILD, base_config(SLMode='SL_ATR'), surface=SURFACE)
    r = v['_33_SL_ATRmult']
    if not r.active or r.reason != 'reachable':
        return 'a reachable input does not report itself reachable: %s' % r.reason
    return None


CASES = (
    ('A1', 'architecture: a missing selector is refused; mechanism moves the digest, a dial does not',
     ARCH, a1_attack, a1_specificity,
     ('        raise Refusal(\n            \'architecture selector %r has no value in the supplied config.',
      '        return "MISSING"; raise Refusal(\n            \'architecture selector %r has no value in the supplied config.')),
    ('A2', 'capability: an EQ-gated module does not fire at its other values',
     CAP, a2_attack, a2_specificity,
     ("        if (op == 'NE' and held != _canon(ref)) or (op == 'EQ' and held == _canon(ref)):",
      "        if held != _canon(ref):")),
    ('A3', 'capability: the Boss_16 ownership override is build-scoped',
     CAP, a3_attack, a3_specificity,
     ('    suppressed = _BUILD_TOKEN_SUPPRESS.get(build_tag, ())',
      '    suppressed = ()')),
    ('A4', 'activation: an input with no entry is refused, not defaulted to reachable',
     ACT, a4_attack, a4_specificity,
     ('        missing = [n for n in names if n not in table]',
      '        missing = []')),
    ('A5', 'activation: a stale entry, and an undeclared build, are both refused',
     ACT, a5_attack, a5_specificity,
     ('        extra = [n for n in sorted(table) if n not in set(names)]',
      '        extra = []')),
    ('A6', 'activation: a dial goes dark when its selector turns it off, AND comes back',
     ACT, a6_attack, a6_specificity,
     ("    if kind == 'EQ':\n        return _value(config, gate[1], name) in gate[2]",
      "    if kind == 'EQ':\n        return True")),
    ('A7', 'activation: module-off and own-gate-closed are told apart',
     ACT, a7_attack, a7_specificity,
     ('    tokens = set(capability.enabled_tokens(build_tag, config, surface=surface))',
      '    tokens = set(capability.CAPABILITY) | {capability.entry_token(build_tag)}')),
)


_MODULE_FILE = {id(ACT): 'activation.py', id(ARCH): 'architecture.py', id(CAP): 'capability.py'}


def load_mutant(module, old, new):
    """The module under test with ONE line rewritten, imported from a TEMP copy. The temp
    directory also holds copies of its siblings, because these three import each other -- a
    mutant that imported the REAL sibling would have half its behaviour unmutated and could
    report a false green."""
    name = _MODULE_FILE[id(module)]
    src = io.open(os.path.join(HERE, name), encoding='utf-8').read()   # snapshot: worktree
    hits = src.count(old)
    if hits != 1:
        raise AssertionError('mutation anchor matched %d times, expected 1: %r' % (hits, old[:60]))
    tmp = tempfile.mkdtemp(prefix='actmut_')
    for sibling in ('preset.py', 'activation.py', 'architecture.py', 'capability.py'):
        text = io.open(os.path.join(HERE, sibling), encoding='utf-8').read()
        if sibling == name:
            text = text.replace(old, new)
        io.open(os.path.join(tmp, sibling), 'w', encoding='utf-8', newline='\n').write(text)
    sys.path.insert(0, tmp)
    try:
        spec = importlib.util.spec_from_file_location('mut_' + name[:-3],
                                                      os.path.join(tmp, name))
        mod = importlib.util.module_from_spec(spec)
        # The siblings must resolve to the TEMP copies, so the mutant's own imports are shadowed
        # for the duration of the load.
        saved = dict((k, sys.modules.pop(k, None))
                     for k in ('preset', 'activation', 'architecture', 'capability'))
        try:
            spec.loader.exec_module(mod)
        finally:
            for k, v in saved.items():
                if v is not None:
                    sys.modules[k] = v
                else:
                    sys.modules.pop(k, None)
    finally:
        sys.path.remove(tmp)
    mod.__mutant_dir__ = tmp
    return mod


def main(argv):
    os.chdir(ROOT)
    bad = 0
    print('=== ORDER-1000 reachability (S7): %d criteria, each with an attack and a specificity '
          'half ===' % len(CASES))
    print('    build %s, %d inputs on its surface' % (BUILD, len(SURFACE)))
    for cid, label, module, attack, spec, _mut in CASES:
        for kind, fn in (('attack', attack), ('specificity', spec)):
            why = fn(module)
            ok = why is None
            bad += 0 if ok else 1
            print('  [%s] %-3s %-11s %s' % ('OK ' if ok else 'BAD', cid, kind, label[:78]))
            if not ok:
                print('        -> %s' % why)

    if '--mutate' in argv:
        print('\n=== mutation probes: break the mechanism, the case must go RED ===')
        for cid, label, module, attack, spec, (old, new) in CASES:
            try:
                mod = load_mutant(module, old, new)
            except Exception as exc:                            # noqa: BLE001
                print('  [BAD] %-3s could not build its mutant: %s' % (cid, exc))
                bad += 1
                continue
            try:
                a = attack(mod)
                s = spec(mod)
            except Exception as exc:                            # noqa: BLE001
                a, s = 'raised %s: %s' % (type(exc).__name__, str(exc)[:80]), None
            caught = (a is not None) or (s is not None)
            bad += 0 if caught else 1
            print('  [%s] %-3s mutant   %-52s %s'
                  % ('OK ' if caught else 'BAD', cid, label[:52],
                     'DETECTED' if caught else 'WENT GREEN -- this case cannot fail'))
            if caught:
                print('        -> %s' % (a or s)[:130])
            shutil.rmtree(getattr(mod, '__mutant_dir__', ''), ignore_errors=True)

    if bad:
        print('\n=== %d CASE(S) DID NOT BEHAVE AS DECLARED ===' % bad)
        return 1
    print('\n=== every criterion refused its attack, allowed its neighbour, and (with --mutate) '
          'was seen red for its own reason ===')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
