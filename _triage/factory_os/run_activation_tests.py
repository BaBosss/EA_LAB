# -*- coding: utf-8 -*-
"""run_activation_tests.py -- ORDER-1020 (S7). The cage for the three modules that decide which
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
_RAW_SURFACE = P.parse_surface(INPUTS_TEXT, BUILD)
SURFACE = P.Surface(BUILD, [d for d in _RAW_SURFACE.inputs if d.name in ACT.TABLE[BUILD]],
                    _RAW_SURFACE.known_tags)
SURFACE.enums = _RAW_SURFACE.enums
S11 = P.parse_surface(INPUTS_TEXT, 'LAB_ENTRY_11')
S12 = P.parse_surface(INPUTS_TEXT, 'LAB_ENTRY_12')
S13 = P.parse_surface(INPUTS_TEXT, 'LAB_ENTRY_13')
S15 = P.parse_surface(INPUTS_TEXT, 'LAB_ENTRY_15')
S16 = P.parse_surface(INPUTS_TEXT, 'LAB_ENTRY_16')
S17 = P.parse_surface(INPUTS_TEXT, 'LAB_ENTRY_17')
S18 = P.parse_surface(INPUTS_TEXT, 'LAB_ENTRY_18')


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
        undeclared = P.parse_surface(INPUTS_TEXT, 'LAB_ENTRY_19')
        mod.classify('LAB_ENTRY_19', base_config(undeclared), surface=undeclared)
        return ('build 19 was classified although this activation table has not declared it, so an absent '
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


# --- A8 one configuration, two spellings, ONE answer (the /scrutinize round-1 defect) -----------

# What a real `.set` carries. `ea_template/sets/regression/Boss_14_GridLog_regression_full.set`
# spells every enum as a NUMBER -- `ExitMode=22`, `RecoveryMode=80`, `HedgeMode=0` -- while the
# declared defaults in Inputs.mqh spell them `EXIT_ATR_TP`, `REC_NONE`, `HEDGE_OFF`.
NUMERIC_FORM = {'ExitMode': '22', 'SLMode': '33', 'FirstLotMode': '41', 'LotProg': '50',
                'StackMode': '92', 'StackConfirm': '0', 'RecoveryMode': '80', 'HedgeMode': '0'}


def a8_attack(mod):
    """THE DEFECT THIS CASE EXISTS FOR, reproduced before the fix and recorded so the pair cannot
    be read as ceremony. Selector values were compared as RAW STRINGS. A config loaded from a real
    `.set` therefore disagreed with the identical config expressed in declared defaults:

        architecture digest   30420f65...  vs  6ba43c96...   -- one strategy, two revisions
        capability tokens     8            vs  11            -- LAB_CAP_RECOVERY and LAB_CAP_HEDGE
                                                                enabled AT THEIR OFF VALUES

    The second line is the expensive one: the wrapper would compile the recovery and hedge modules
    for a hypothesis that switches both off, and every input those modules own would stay visible
    and sweepable. `mod` here is whichever of the three modules the case is registered against;
    each half reaches for what it needs.
    """
    import architecture as _arch
    import capability as _cap
    base = base_config()
    numeric = base_config(**NUMERIC_FORM)
    _a, d1 = _arch.digest_for(BUILD, base, surface=SURFACE)
    _b, d2 = _arch.digest_for(BUILD, numeric, surface=SURFACE)
    if d1 != d2:
        return ('the same architecture hashes differently depending on whether its enums are '
                'spelled as symbols or as the numbers a real .set carries: %s vs %s' % (d1, d2))
    t1 = _cap.enabled_tokens(BUILD, base, surface=SURFACE)
    t2 = _cap.enabled_tokens(BUILD, numeric, surface=SURFACE)
    if t1 != t2:
        return ('the same config enables different capabilities per spelling: %s vs %s'
                % (sorted(set(t1) ^ set(t2)), len(t1)))
    v1 = mod.classify(BUILD, base, surface=SURFACE)
    v2 = mod.classify(BUILD, numeric, surface=SURFACE)
    moved = [n for n in v1 if v1[n].active != v2[n].active]
    if moved:
        return ('%d input(s) change reachability with the spelling, so what becomes a `const` '
                'depends on how the .set was written: %s' % (len(moved), moved[:6]))
    return None


def a8_specificity(mod):
    """...and canonicalising must NOT become "accept anything". An unknown symbol has to REFUSE:
    a spelling nobody can resolve that quietly matched would be permission granted by a typo."""
    import capability as _cap
    try:
        _cap.enabled_tokens(BUILD, base_config(RecoveryMode='REC_NONEE'), surface=SURFACE)
        return ('a misspelled enum symbol was accepted. Canonicalisation that guesses is worse '
                'than raw comparison, because it makes a typo look like a decision.')
    except Exception as exc:                                    # noqa: BLE001
        if 'REC_NONEE' not in str(exc):
            return 'it refused the typo but did not name it: %s' % str(exc)[:120]
    return None


# --- B11/B12/B13/B15/B16 prospective enrollment activation extension ---------------------------

NEW_FAMILY_SURFACES = ((11, S11, 151), (12, S12, 155), (13, S13, 157),
                       (15, S15, 157), (16, S16, 173))


def new_family_surface_completeness(mod):
    for number, surface, expected in NEW_FAMILY_SURFACES:
        build = 'LAB_ENTRY_%d' % number
        names = set(d.name for d in surface.inputs)
        table_names = set(mod.TABLE[build])
        if len(names) != expected:
            return '%s fixture has %d physical inputs, expected %d' % (build, len(names), expected)
        if table_names != names:
            return '%s table differs from its surface: missing=%s extra=%s' % (
                build, sorted(names-table_names), sorted(table_names-names))
        verdicts = mod.classify(build, base_config(surface), surface=surface)
        if set(verdicts) != names:
            return '%s classify output is not the exact physical surface' % build
    return None


def new_family_gate_specificity(mod):
    # B11: shared entry direction/trend filter genuinely control the entry.
    b11 = mod.classify('LAB_ENTRY_11', base_config(S11), surface=S11)
    if not b11['TradeDir'].active or not b11['TrendFilter'].active:
        return 'B11 shared TradeDir/TrendFilter are not reachable'
    # B12: equal hours mean session filter disabled; unequal means both hour selectors matter.
    b12eq = mod.classify('LAB_ENTRY_12', base_config(S12, _12_HourFrom='0', _12_HourTo='0'), surface=S12)
    b12ne = mod.classify('LAB_ENTRY_12', base_config(S12, _12_HourFrom='8', _12_HourTo='17'), surface=S12)
    if b12eq['_12_HourFrom'].active or b12eq['_12_HourTo'].active:
        return 'B12 equal-hour disabled session exposed its hour dials'
    if not b12ne['_12_HourFrom'].active or not b12ne['_12_HourTo'].active:
        return 'B12 unequal-hour active session did not expose both hour dials'
    # B13: BB deviation only matters when the BB condition is required.
    b13on = mod.classify('LAB_ENTRY_13', base_config(S13, _13_RequireBB='true'), surface=S13)
    b13off = mod.classify('LAB_ENTRY_13', base_config(S13, _13_RequireBB='false'), surface=S13)
    if not b13on['_13_BB_Dev'].active or b13off['_13_BB_Dev'].active:
        return 'B13 _13_BB_Dev did not follow _13_RequireBB'
    # B15 has TradeDir but no shared TrendFilter path; RearmBars is edge-trigger only.
    b15on = mod.classify('LAB_ENTRY_15', base_config(S15, _15_EdgeTrigger='true'), surface=S15)
    b15off = mod.classify('LAB_ENTRY_15', base_config(S15, _15_EdgeTrigger='false'), surface=S15)
    if not b15on['TradeDir'].active or b15on['TrendFilter'].active:
        return 'B15 TradeDir/TrendFilter ownership is not source-specific'
    if not b15on['_15_RearmBars'].active or b15off['_15_RearmBars'].active:
        return 'B15 RearmBars did not follow EdgeTrigger'
    # B16 owns the runtime pipeline: shared stack/exit selectors are inert, direction-specific RSI is not.
    b16buy = mod.classify('LAB_ENTRY_16', base_config(S16, _16_Direction='1'), surface=S16)
    b16sell = mod.classify('LAB_ENTRY_16', base_config(S16, _16_Direction='2'), surface=S16)
    for name in ('ExitMode','SLMode','StackMode','RecoveryMode','HedgeMode','TradeDir','TrendFilter'):
        if b16buy[name].active:
            return 'B16 exposes shared runtime selector %s despite Kangaroo ownership' % name
    if not b16buy['_16_RsiLow'].active or b16buy['_16_RsiHigh'].active:
        return 'B16 buy instance does not expose only its RSI-low threshold'
    if not b16sell['_16_RsiHigh'].active or b16sell['_16_RsiLow'].active:
        return 'B16 sell instance does not expose only its RSI-high threshold'
    return None


NEW_EXTENSION_CASES = (
    ('B11-16-1', 'new-family exact physical activation surfaces', new_family_surface_completeness),
    ('B11-16-2', 'family-specific entry gates and Kangaroo ownership', new_family_gate_specificity),
)


# --- B17/B18 activation extension: exact complete tables with source-proven gates ---------------

B17_ENTRY_ROWS = ('_17_FractalDepth', '_17_Wave3MinMult', '_17_EntryFib',
                  '_17_SLbufferATR', '_17_UseStructLevels', '_17_DivergTrail',
                  '_17_MaxSwings', '_17_RSI_Period')
B18_ENTRY_ROWS = ('_18_Direction', '_18_DirMode', '_18_MaPeriod', '_18_KPeriod',
                  '_18_DPeriod', '_18_Slowing', '_18_LoLevel', '_18_UpLevel')


def b17_b18_surface_completeness(mod):
    """Both extensions must classify and project exactly their 159-key physical surfaces."""
    for build, surface in (('LAB_ENTRY_17', S17), ('LAB_ENTRY_18', S18)):
        names = set(d.name for d in surface.inputs)
        table_names = set(mod.TABLE[build])
        if len(names) != 159:
            return '%s fixture has %d physical inputs, expected 159' % (build, len(names))
        if table_names != names:
            return '%s table differs from its surface: missing=%s extra=%s' % (
                build, sorted(names - table_names), sorted(table_names - names))
        verdicts = mod.classify(build, base_config(surface), surface=surface)
        states = mod.effective_state(build, base_config(surface), surface=surface)
        if set(verdicts) != names or set(states) != names:
            return '%s classify/effective_state is not an exact surface projection' % build
    return None


def b17_b18_baseline_specificity(mod):
    """Default baselines retain the declared module sets and no B14 entry row leaks across."""
    expected = {
        'LAB_ENTRY_17': {'LAB_CAP_CORE', 'LAB_CAP_ENTRY_WAVE5', 'LAB_CAP_EXEC', 'LAB_CAP_EXIT',
                         'LAB_CAP_INDICATORS', 'LAB_CAP_MM', 'LAB_CAP_RISK'},
        'LAB_ENTRY_18': {'LAB_CAP_CORE', 'LAB_CAP_ENTRY_JUMSTOCH', 'LAB_CAP_EXEC', 'LAB_CAP_EXIT',
                         'LAB_CAP_INDICATORS', 'LAB_CAP_MM', 'LAB_CAP_RISK', 'LAB_CAP_STACK'},
    }
    for build, surface, entry_rows in (('LAB_ENTRY_17', S17, B17_ENTRY_ROWS),
                                       ('LAB_ENTRY_18', S18, B18_ENTRY_ROWS)):
        cfg = base_config(surface)
        tokens = set(CAP.enabled_tokens(build, cfg, surface=surface))
        if tokens != expected[build]:
            return '%s baseline tokens differ: got=%s expected=%s' % (
                build, sorted(tokens), sorted(expected[build]))
        verdicts = mod.classify(build, cfg, surface=surface)
        dark_entry_rows = set(name for name in entry_rows if not verdicts[name].active)
        expected_dark = ({'_17_DivergTrail', '_17_RSI_Period'} if build == 'LAB_ENTRY_17' else set())
        if dark_entry_rows != expected_dark:
            return '%s baseline dark entry rows differ: got=%s expected=%s' % (
                build, sorted(dark_entry_rows), sorted(expected_dark))
        leaked = [name for name in ('_14_Direction', '_14_DistAtrMult', '_14_MinDistPips')
                  if name in mod.TABLE[build]]
        if leaked:
            return '%s retained B14 entry rows: %s' % (build, leaked)
    return None


def b17_b18_gate_specificity(mod):
    """B17 structural/trail controls open and close independently; B18 keeps its entry dials live."""
    b17_default = mod.classify('LAB_ENTRY_17', base_config(S17), surface=S17)
    b17_no_struct = mod.classify('LAB_ENTRY_17',
                                 base_config(S17, _17_UseStructLevels='false'), surface=S17)
    # Entry_Wave5.mqh consumes SLbufferATR in its risk-ATR and Wave5_SLValid veto paths
    # independently of UseStructLevels, so the dial must remain reachable in both states.
    if not b17_default['_17_SLbufferATR'].active or not b17_no_struct['_17_SLbufferATR'].active:
        return '_17_SLbufferATR was not reachable with UseStructLevels true and false'
    b17_trail = mod.classify('LAB_ENTRY_17',
                             base_config(S17, ExitMode='EXIT_TRAIL', _17_DivergTrail='true'),
                             surface=S17)
    b17_no_diverg = mod.classify('LAB_ENTRY_17',
                                 base_config(S17, ExitMode='EXIT_TRAIL', _17_DivergTrail='false'),
                                 surface=S17)
    if b17_default['_17_DivergTrail'].active or b17_default['_17_RSI_Period'].active:
        return 'B17 divergence controls are reachable outside EXIT_TRAIL'
    if not b17_trail['_17_DivergTrail'].active or not b17_trail['_17_RSI_Period'].active:
        return 'B17 divergence controls did not open at EXIT_TRAIL with DivergTrail=true'
    if not b17_no_diverg['_17_DivergTrail'].active or b17_no_diverg['_17_RSI_Period'].active:
        return 'B17 RSI period did not follow DivergTrail=true/false under EXIT_TRAIL'
    for build, surface in (('LAB_ENTRY_17', S17), ('LAB_ENTRY_18', S18)):
        trade_dir = mod.classify(build, base_config(surface), surface=surface)['TradeDir']
        if trade_dir.active or trade_dir.token_enabled:
            return '%s exposes inert TradeDir as an enabled capability' % build
    return None


EXTENSION_CASES = (
    ('B17/B18-1', 'surface completeness and effective-state exactness', b17_b18_surface_completeness),
    ('B17/B18-2', 'baseline specificity and no B14 entry leakage', b17_b18_baseline_specificity),
    ('B17/B18-3', 'B17 structural/trail gates and B18 entry reachability', b17_b18_gate_specificity),
)


CASES = (
    ('A8', 'one configuration in two spellings gives ONE digest, ONE token set, ONE reachability',
     ACT, a8_attack, a8_specificity,
     ("        return _preset.render_value(decl, str(value).strip(), surface.enums)",
      "        return str(value).strip()")),
    ('A1', 'architecture: a missing selector is refused; mechanism moves the digest, a dial does not',
     ARCH, a1_attack, a1_specificity,
     ('        raise Refusal(\n            \'architecture selector %r has no value in the supplied config.',
      '        return "MISSING"; raise Refusal(\n            \'architecture selector %r has no value in the supplied config.')),
    ('A2', 'capability: an EQ-gated module does not fire at its other values',
     CAP, a2_attack, a2_specificity,
     ("        if (op == 'NE' and held != want) or (op == 'EQ' and held == want):",
      "        if held != want:")),
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
     ("    if kind == 'EQ':\n        held = _canon(_value(config, gate[1], name), gate[1], surface)",
      "    if kind == 'EQ':\n        return True; held = _canon(_value(config, gate[1], name), gate[1], surface)")),
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
    print('=== ORDER-1020 reachability (S7): %d criteria, each with an attack and a specificity '
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

    print('\n=== B11/B12/B13/B15/B16 activation extension: %d focused criteria ===' % len(NEW_EXTENSION_CASES))
    for cid, label, fn in NEW_EXTENSION_CASES:
        why = fn(ACT)
        ok = why is None
        bad += 0 if ok else 1
        print('  [%s] %-9s %s' % ('OK ' if ok else 'BAD', cid, label))
        if not ok:
            print('        -> %s' % why)

    print('\n=== B17/B18 activation extension: %d focused criteria ===' % len(EXTENSION_CASES))
    for cid, label, fn in EXTENSION_CASES:
        why = fn(ACT)
        ok = why is None
        bad += 0 if ok else 1
        print('  [%s] %-9s %s' % ('OK ' if ok else 'BAD', cid, label))
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
