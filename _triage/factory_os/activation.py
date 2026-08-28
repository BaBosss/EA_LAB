# -*- coding: utf-8 -*-
"""activation.py -- ORDER-1020 (slice S7). Which of a build's inputs are REACHABLE, per config.

WHY THIS FILE IS THE HEART OF S7. Slice S7's acceptance is an Operator surface with zero
`UNKNOWN` on it, and design 5.3's target is `Operator <= 40` against Boss_14's **116 visible
inputs**. You cannot get from 116 to 40 by deciding which dials are "important" -- that is taste,
and taste does not survive review. You get there by answering a question with a right answer:
**given this build and this configuration, can this input change anything at all?** An input whose
answer is no is not a dial the operator should be shown, and it is not a dimension the optimizer
should be offered.

WHERE THE ANSWERS COME FROM, AND WHY THEY ARE NOT GUESSES. `docs/PARAM_REGISTRY.csv` already holds
an `active_when` cell for all 183 inputs, and its header records that every one was traced by
reading the actual code at a pinned commit. This module ENCODES that prose as a predicate a
program can evaluate. It does not re-derive it and it does not extend it: where the prose says
`SLMode==SL_ATR(33)`, the gate here says exactly that.

  🔴 THE TABLE IS PER BUILD, and that is a correction rather than a convenience. Several
  `active_when` cells are build-conditional ("builds 11/12/13 only", "NOT build 16"). A
  chassis-wide table would have to flatten those into a claim that is false somewhere, and the
  place it would be false is exactly the place a reader would not check. Each declared build has
  its own exact table; an undeclared build is a REFUSAL -- "this build has no declared activation
  table" and "this build has no inactive inputs" are different answers and must not share a code
  path.

  🔴 A CAPABILITY SELECTOR BELONGS TO `LAB_CAP_CORE`, NOT TO THE CAPABILITY IT SELECTS. `LotProg`
  decides whether `LAB_CAP_LOTPROG` is enabled; if it were itself owned by that token, then
  turning the capability off would const away the input that decides it, and the resulting wrapper
  could never be configured back. The selectors are chassis-level by construction. This is the one
  place where the ownership is a consequence of the mechanism rather than of the module that reads
  the value.

WHAT THIS MODULE DOES NOT DECIDE. Whether a REACHABLE input is `TUNABLE` or `SAFETY` or `LOCKED`,
and whether it belongs on the `OPERATOR` or the `RESEARCH` surface, is a per-hypothesis judgement
and lives with the hypothesis. Reachability is a property of the code and belongs here.

CATEGORY (TIER_SNAPSHOT_DESIGN.md section 2/3.3): PURE. Config in, verdicts out; it opens nothing.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import capability                                  # noqa: E402  (path set above)
import preset                                      # noqa: E402  (path set above)

Refusal = preset.PresetRefusal


# --- the gate vocabulary -----------------------------------------------------------------------
# Deliberately tiny. Every `active_when` cell that this build needs reduces to one of these four
# or an AND of them; a fifth form would mean the prose says something the code cannot check, and
# that is worth discovering as a refusal rather than approximating.

ALWAYS = ('ALWAYS',)


def EQ(selector, *values):
    """active only when `selector` holds one of `values`."""
    return ('EQ', selector, tuple(values))


def NE(selector, value):
    """active unless `selector` holds `value`."""
    return ('NE', selector, value)


SELF_GT0 = ('SELF_GT0',)      # active only when the input's OWN value is > 0 (0 = off)


def GT0(selector):
    """active only when ANOTHER input's value is > 0."""
    return ('GT0', selector)


def AND(*gates):
    return ('AND',) + gates


def NEVER(reason_code):
    """A permanently closed metadata gate with an explicit reason code."""
    return ('NEVER', reason_code)


# A4's relation vocabulary is closed here. Relations describe existing source
# call/gate paths; they do not create runtime callers or change execution.
RELATION_KINDS = ('PARENT', 'GATES', 'REQUIRES', 'COUPLED_WITH', 'SUPERSEDES')


_R4_RELATIONS = {
    '_50_ADX_TrendMin_Exit': (('REQUIRES', '_50_RegimeMode'),
                              ('COUPLED_WITH', '_50_ADX_TrendMin')),
    '_50_RegimeConfirmBars': (('REQUIRES', '_50_RegimeMode'),
                              ('COUPLED_WITH', '_50_ADX_TrendMin_Exit')),
    '_EVT_BucketATRmult': (('COUPLED_WITH', '_EVT_BucketSeconds'),),
    '_EVT_BucketSeconds': (('COUPLED_WITH', '_EVT_BucketATRmult'),),
    '_EVT_PreemptMargin': (),
    '_EVT_RevengeBlockBars': (),
    '_HEAT_Enable': tuple([('PARENT', n) for n in (
        '_HEAT_MaxClusterLots', '_HEAT_MaxPortfolioLots', '_HEAT_ClusterCorr',
        '_HEAT_DefaultCorr', '_HEAT_UseDynamicCorr', '_HEAT_CorrWindowBars')]) +
        tuple([('GATES', n) for n in (
        '_HEAT_MaxClusterLots', '_HEAT_MaxPortfolioLots', '_HEAT_ClusterCorr',
        '_HEAT_DefaultCorr', '_HEAT_UseDynamicCorr', '_HEAT_CorrWindowBars')]),
    '_HEAT_MaxClusterLots': (('REQUIRES', '_HEAT_Enable'),),
    '_HEAT_MaxPortfolioLots': (('REQUIRES', '_HEAT_Enable'),),
    '_HEAT_ClusterCorr': (('REQUIRES', '_HEAT_Enable'),
                          ('COUPLED_WITH', '_HEAT_DefaultCorr')),
    '_HEAT_DefaultCorr': (('REQUIRES', '_HEAT_Enable'),
                          ('COUPLED_WITH', '_HEAT_ClusterCorr')),
    '_HEAT_UseDynamicCorr': (('REQUIRES', '_HEAT_Enable'),),
    '_HEAT_CorrWindowBars': (('REQUIRES', '_HEAT_Enable'),
                             ('REQUIRES', '_HEAT_UseDynamicCorr')),
    'UseMiddlePathVeto': tuple([('PARENT', n) for n in (
        '_MID_LineSource', 'MID_LOW', 'MID_HIGH', 'MIN_CHANNEL_ATR',
        'MIN_LINE_WEIGHT', '_MID_DonchianBars', '_MID_PivotDepth',
        '_MID_LineLookbackBars', '_MID_MaxLines', '_MID_ClusterATRmult',
        '_MID_UseRoomCheck', '_MID_MinRR')]) +
        tuple([('GATES', n) for n in (
        '_MID_LineSource', 'MID_LOW', 'MID_HIGH', 'MIN_CHANNEL_ATR',
        'MIN_LINE_WEIGHT', '_MID_DonchianBars', '_MID_PivotDepth',
        '_MID_LineLookbackBars', '_MID_MaxLines', '_MID_ClusterATRmult',
        '_MID_UseRoomCheck', '_MID_MinRR')]),
}
for _name in ('_MID_LineSource', 'MID_LOW', 'MID_HIGH', 'MIN_CHANNEL_ATR',
              'MIN_LINE_WEIGHT'):
    _R4_RELATIONS[_name] = (('REQUIRES', 'UseMiddlePathVeto'),)
for _name in ('_MID_DonchianBars', '_MID_PivotDepth', '_MID_LineLookbackBars',
              '_MID_MaxLines', '_MID_ClusterATRmult'):
    _R4_RELATIONS[_name] = (('REQUIRES', 'UseMiddlePathVeto'),
                            ('REQUIRES', '_MID_LineSource'))
_R4_RELATIONS['_MID_UseRoomCheck'] = (('REQUIRES', 'UseMiddlePathVeto'),)
_R4_RELATIONS['_MID_MinRR'] = (('REQUIRES', 'UseMiddlePathVeto'),
                               ('REQUIRES', '_MID_UseRoomCheck'))

_STATIC_INACTIVE = {
    '_50_ADX_TrendMin_Exit': 'UNWIRED_REGIME_STABLE_PATH',
    '_50_RegimeConfirmBars': 'UNWIRED_REGIME_STABLE_PATH',
    '_EVT_BucketATRmult': 'UNWIRED_EVENT_BUS_RUNTIME_CALLER',
    '_EVT_BucketSeconds': 'UNWIRED_EVENT_BUS_RUNTIME_CALLER',
    '_EVT_PreemptMargin': 'UNWIRED_EVENT_BUS_RUNTIME_CALLER',
    '_EVT_RevengeBlockBars': 'OUTCOME_LEDGER_NOT_IMPLEMENTED',
}


def relation_metadata(name):
    """Return deterministic static relation/effect metadata for one identity."""
    if name not in _R4_RELATIONS:
        raise Refusal('no R4 relation metadata is declared for %r' % name)
    reason_code = _STATIC_INACTIVE.get(name)
    return {
        'name': name,
        'relations': tuple({'kind': kind, 'target': target}
                           for kind, target in _R4_RELATIONS[name]),
        'state': 'HIDDEN_INACTIVE' if reason_code else 'REACHABLE_WHEN_GATED',
        'reason_code': reason_code,
        'effective': False if reason_code else None,
    }


def _gate_dependencies(gate):
    kind = gate[0]
    if kind in ('EQ', 'NE', 'GT0'):
        return (gate[1],)
    if kind == 'AND':
        return tuple(dict.fromkeys(
            dependency for sub in gate[1:] for dependency in _gate_dependencies(sub)))
    return ()


# --- the Boss_14 table -------------------------------------------------------------------------
# name -> (capability token, gate). Sourced cell by cell from docs/PARAM_REGISTRY.csv's
# `active_when`, using the [LAB_ENTRY_14]-tagged row where one exists.

_B14 = {
    # --- chassis-level mechanism selectors (LAB_CAP_CORE; see the note in the docstring) -------
    'ExitMode':            ('LAB_CAP_CORE', ALWAYS),
    'SLMode':              ('LAB_CAP_CORE', ALWAYS),
    'FirstLotMode':        ('LAB_CAP_CORE', ALWAYS),
    'LotProg':             ('LAB_CAP_CORE', ALWAYS),
    'StackMode':           ('LAB_CAP_CORE', ALWAYS),
    'StackConfirm':        ('LAB_CAP_CORE', EQ('StackMode', 'STACK_GRID_TREND', 'STACK_GRID_AGAINST')),
    'RecoveryMode':        ('LAB_CAP_CORE', ALWAYS),
    'HedgeMode':           ('LAB_CAP_CORE', ALWAYS),
    '_50_RegimeMode':      ('LAB_CAP_CORE', ALWAYS),
    '_MG_SelfGate':        ('LAB_CAP_CORE', ALWAYS),
    '_0_BarOpenOnly':      ('LAB_CAP_CORE', ALWAYS),
    # TradeDir/TrendFilter are read only by the 11/12/13/15 entry family. On build 14 the entry
    # module owns its own direction (`_14_Direction`) and never reads them.
    'TradeDir':            ('LAB_CAP_ENTRY_GRIDTRENDMA', ALWAYS),
    'TrendFilter':         ('LAB_CAP_ENTRY_GRIDTRENDMA', ALWAYS),

    # --- execution -----------------------------------------------------------------------------
    'DryRun':              ('LAB_CAP_EXEC', ALWAYS),
    '_0_Magic':            ('LAB_CAP_EXEC', ALWAYS),
    '_0_Slippage':         ('LAB_CAP_EXEC', ALWAYS),
    '_0_MaxSpread':        ('LAB_CAP_EXEC', SELF_GT0),

    # --- risk control --------------------------------------------------------------------------
    '_9_MaxLevels':        ('LAB_CAP_RISK', ALWAYS),
    'ProtectLevel':        ('LAB_CAP_RISK', ALWAYS),
    'RC_MaxLot':           ('LAB_CAP_RISK', ALWAYS),
    'RC_RecMultMax':       ('LAB_CAP_RISK', EQ('LotProg', 'PROG_MULTIPLIER')),
    'RC_MaxLevelsOverride': ('LAB_CAP_RISK', SELF_GT0),
    'RC_AcctDDLimitPct':   ('LAB_CAP_RISK', SELF_GT0),
    'RC_PersistHalt':      ('LAB_CAP_RISK', ALWAYS),
    'RC_AdoptLegacyHalt':  ('LAB_CAP_RISK', ALWAYS),

    # --- stacking ------------------------------------------------------------------------------
    '_9_StepUseATR':       ('LAB_CAP_STACK', ALWAYS),
    '_9_StepATRmult':      ('LAB_CAP_STACK', EQ('_9_StepUseATR', 'true')),
    '_9_StepPoints':       ('LAB_CAP_STACK', ALWAYS),
    '_9_StepMinPips':      ('LAB_CAP_STACK', AND(EQ('_9_StepUseATR', 'true'), SELF_GT0)),
    '_9_StepATRShift':     ('LAB_CAP_STACK', EQ('_9_StepUseATR', 'true')),
    '_9_PendingMode':      ('LAB_CAP_STACK', EQ('StackMode', 'STACK_PYRAMID')),
    '_9_PendingLegs':      ('LAB_CAP_STACK', AND(EQ('StackMode', 'STACK_PYRAMID'),
                                                 EQ('_9_PendingMode', '2', '3'))),

    # --- price action (reachable only at CONF_PA_ENGULF) ---------------------------------------
    '_9_PA_MinBodyRatio':  ('LAB_CAP_PRICEACTION', ALWAYS),

    # --- regime --------------------------------------------------------------------------------
    '_9_RegimeGateAdds':   ('LAB_CAP_REGIME', ALWAYS),
    '_50_AllowTrendUp':    ('LAB_CAP_REGIME', EQ('_50_RegimeMode', '1')),
    '_50_AllowTrendDown':  ('LAB_CAP_REGIME', EQ('_50_RegimeMode', '1')),
    '_50_AllowRange':      ('LAB_CAP_REGIME', EQ('_50_RegimeMode', '1')),
    '_50_Regime_TF':       ('LAB_CAP_REGIME', ALWAYS),
    '_50_ADX_Period':      ('LAB_CAP_REGIME', ALWAYS),
    '_50_ADX_TrendMin':    ('LAB_CAP_REGIME', ALWAYS),
    '_50_StormATRmult':    ('LAB_CAP_REGIME', SELF_GT0),
    '_50_StormLookback':   ('LAB_CAP_REGIME', GT0('_50_StormATRmult')),
    # The stable exit classifier is declared but has no current runtime caller.
    '_50_ADX_TrendMin_Exit': ('LAB_CAP_REGIME', NEVER('UNWIRED_REGIME_STABLE_PATH')),
    '_50_RegimeConfirmBars': ('LAB_CAP_REGIME', NEVER('UNWIRED_REGIME_STABLE_PATH')),

    # --- entry (build 14's own) ------------------------------------------------------------------
    '_14_Direction':       ('LAB_CAP_ENTRY_GRIDLOG', ALWAYS),
    '_14_DistAtrMult':     ('LAB_CAP_ENTRY_GRIDLOG', ALWAYS),
    '_14_MinDistPips':     ('LAB_CAP_ENTRY_GRIDLOG', ALWAYS),

    # --- the 11/12/13 trend-filter dials ---------------------------------------------------------
    '_71_ATRMA':           ('LAB_CAP_ENTRY_GRIDTRENDMA', EQ('TrendFilter', 'TFILTER_ATR_EXPAND')),
    '_71_ATRRatio':        ('LAB_CAP_ENTRY_GRIDTRENDMA', EQ('TrendFilter', 'TFILTER_ATR_EXPAND')),
    '_72_SlopeBar':        ('LAB_CAP_ENTRY_GRIDTRENDMA', EQ('TrendFilter', 'TFILTER_MA_SLOPE')),

    # --- indicators ------------------------------------------------------------------------------
    # The handles are always built; what the registry records is where the VALUE is consumed. On
    # build 14 the shared MA pair is consumed only by EXIT_RUN_TREND (build 11's entry and the
    # trend filter are the other two consumers, and neither exists here).
    '_0_FastMA':           ('LAB_CAP_INDICATORS', EQ('ExitMode', 'EXIT_RUN_TREND')),
    '_0_SlowMA':           ('LAB_CAP_INDICATORS', EQ('ExitMode', 'EXIT_RUN_TREND')),
    '_0_MAMethod':         ('LAB_CAP_INDICATORS', EQ('ExitMode', 'EXIT_RUN_TREND')),
    '_0_MA_TF':            ('LAB_CAP_INDICATORS', EQ('ExitMode', 'EXIT_RUN_TREND')),
    '_0_ATR_Period':       ('LAB_CAP_INDICATORS', ALWAYS),
    '_0_ATR_TF':           ('LAB_CAP_INDICATORS', ALWAYS),
    '_3_RiskATR_Period':   ('LAB_CAP_INDICATORS', ALWAYS),
    '_3_RiskATR_TF':       ('LAB_CAP_INDICATORS', ALWAYS),
    '_36_SD_Period':       ('LAB_CAP_INDICATORS', EQ('SLMode', 'SL_SD')),

    # --- exits -----------------------------------------------------------------------------------
    '_21_TP_Pip':          ('LAB_CAP_EXIT', EQ('ExitMode', 'EXIT_FIXED_TP')),
    '_22_TP_ATRmult':      ('LAB_CAP_EXIT', EQ('ExitMode', 'EXIT_ATR_TP')),
    '_2_BasketTP_Money':   ('LAB_CAP_EXIT', ALWAYS),
    '_2_BasketTP_ATRmult': ('LAB_CAP_EXIT', SELF_GT0),
    '_2_BasketTP_BalPct':  ('LAB_CAP_EXIT', SELF_GT0),
    '_23_TrailStart':      ('LAB_CAP_EXIT', EQ('ExitMode', 'EXIT_TRAIL')),
    '_23_TrailStep':       ('LAB_CAP_EXIT', EQ('ExitMode', 'EXIT_TRAIL')),
    '_2_PartialPct1':      ('LAB_CAP_EXIT', AND(NE('StackMode', 'STACK_PYRAMID'), SELF_GT0)),
    '_2_PartialFrac1':     ('LAB_CAP_EXIT', AND(NE('StackMode', 'STACK_PYRAMID'),
                                                GT0('_2_PartialPct1'))),
    '_2_PartialPct2':      ('LAB_CAP_EXIT', AND(NE('StackMode', 'STACK_PYRAMID'), SELF_GT0)),
    '_2_PartialFrac2':     ('LAB_CAP_EXIT', AND(NE('StackMode', 'STACK_PYRAMID'),
                                                GT0('_2_PartialPct2'))),
    '_2_SuppressLegTP':    ('LAB_CAP_EXIT', ALWAYS),
    '_2_MaxHoldBars':      ('LAB_CAP_EXIT', SELF_GT0),
    '_57_DynCloseOn':      ('LAB_CAP_EXIT', ALWAYS),
    '_57_DynCloseBase':    ('LAB_CAP_EXIT', EQ('_57_DynCloseOn', 'true')),
    '_57_DynCloseBalPct':  ('LAB_CAP_EXIT', AND(EQ('_57_DynCloseOn', 'true'), SELF_GT0)),
    '_57_DynCloseDivisor': ('LAB_CAP_EXIT', EQ('_57_DynCloseOn', 'true')),
    '_31_SL_Pip':          ('LAB_CAP_EXIT', EQ('SLMode', 'SL_FIXED_POINTS')),
    '_33_SL_ATRmult':      ('LAB_CAP_EXIT', EQ('SLMode', 'SL_ATR')),
    '_33_SL_MaxPips':      ('LAB_CAP_EXIT', AND(EQ('SLMode', 'SL_ATR'), SELF_GT0)),
    '_33_SL_MaxATRmult':   ('LAB_CAP_EXIT', AND(EQ('SLMode', 'SL_ATR'), SELF_GT0)),
    # Not SL-only despite living in the "3x Stop loss" group: the adaptive term is read by
    # EXIT_ATR_TP as well. The registry says so explicitly, and encoding it as SL-only here would
    # have made a live dial disappear from build 14, whose ExitMode default IS EXIT_ATR_TP.
    '_33_AdaptiveON':      ('LAB_CAP_EXIT', EQ('SLMode', 'SL_ATR')),
    '_33_AdaptiveN':       ('LAB_CAP_EXIT', EQ('_33_AdaptiveON', 'true')),
    # Basket-level money stops, checked unconditionally regardless of SLMode.
    '_32_SL_Money':        ('LAB_CAP_EXIT', SELF_GT0),
    '_32_SL_BalPct':       ('LAB_CAP_EXIT', SELF_GT0),
    '_34_DonchianBars':    ('LAB_CAP_EXIT', EQ('SLMode', 'SL_STRUCT_DONCHIAN')),
    '_35_SRBars':          ('LAB_CAP_EXIT', EQ('SLMode', 'SL_STRUCT_SR')),
    '_36_SD_Mult':         ('LAB_CAP_EXIT', EQ('SLMode', 'SL_SD')),

    # --- money management ------------------------------------------------------------------------
    '_41_FixedLot':        ('LAB_CAP_MM', EQ('FirstLotMode', 'FIRSTLOT_FIXED')),
    '_42_RiskPct':         ('LAB_CAP_MM', EQ('FirstLotMode', 'FIRSTLOT_RISK')),
    '_43_LotPerAnchor':    ('LAB_CAP_MM', EQ('FirstLotMode', 'FIRSTLOT_BALANCE')),
    '_43_BalanceAnchor':   ('LAB_CAP_MM', EQ('FirstLotMode', 'FIRSTLOT_BALANCE')),
    '_4_DdAdaptiveOn':     ('LAB_CAP_MM', ALWAYS),
    '_4_DdTier1Pct':       ('LAB_CAP_MM', EQ('_4_DdAdaptiveOn', 'true')),
    '_4_DdTier1Mult':      ('LAB_CAP_MM', EQ('_4_DdAdaptiveOn', 'true')),
    '_4_DdTier2Pct':       ('LAB_CAP_MM', EQ('_4_DdAdaptiveOn', 'true')),
    '_4_DdTier2Mult':      ('LAB_CAP_MM', EQ('_4_DdAdaptiveOn', 'true')),
    '_4_DdHardCapMult':    ('LAB_CAP_MM', EQ('_4_DdAdaptiveOn', 'true')),

    # --- lot progression -------------------------------------------------------------------------
    '_51_ProgFactor':      ('LAB_CAP_LOTPROG', EQ('LotProg', 'PROG_LINEAR', 'PROG_LOG')),
    '_52_ProgMult':        ('LAB_CAP_LOTPROG', EQ('LotProg', 'PROG_MULTIPLIER')),
    '_53_PlusLot':         ('LAB_CAP_LOTPROG', EQ('LotProg', 'PROG_PLUS')),
    '_55_LogPowerFactor':  ('LAB_CAP_LOTPROG', EQ('LotProg', 'PROG_LOG_POWER')),
    '_55_UseLnNotLog10':   ('LAB_CAP_LOTPROG', EQ('LotProg', 'PROG_LOG_POWER')),
    '_56_FibMaxStep':      ('LAB_CAP_LOTPROG', EQ('LotProg', 'PROG_FIBONACCI')),

    # --- recovery ---------------------------------------------------------------------------------
    '_8_TriggerATR':       ('LAB_CAP_RECOVERY', ALWAYS),
    '_8_StepATR':          ('LAB_CAP_RECOVERY', ALWAYS),
    '_8_RecMult':          ('LAB_CAP_RECOVERY', EQ('RecoveryMode', 'REC_AGGRESSIVE')),
    '_8_DDRefMoney':       ('LAB_CAP_RECOVERY', EQ('RecoveryMode', 'REC_ADAPTIVE')),
    '_8_DDRefBalPct':      ('LAB_CAP_RECOVERY', AND(EQ('RecoveryMode', 'REC_ADAPTIVE'), SELF_GT0)),

    # --- hedge -------------------------------------------------------------------------------------
    '_H_TriggerDDPct':     ('LAB_CAP_HEDGE', ALWAYS),
    '_H_ReleaseDDPct':     ('LAB_CAP_HEDGE', ALWAYS),
    '_H_Ratio':            ('LAB_CAP_HEDGE', ALWAYS),
    '_H_MaxLot':           ('LAB_CAP_HEDGE', SELF_GT0),

    # --- R4 Event Bus / Heat / Middle Path additions --------------------------------------------
    # Event Bus functions are currently uncalled, so these remain metadata-only and inactive.
    '_EVT_BucketATRmult':  ('LAB_CAP_CORE', NEVER('UNWIRED_EVENT_BUS_RUNTIME_CALLER')),
    '_EVT_BucketSeconds':  ('LAB_CAP_CORE', NEVER('UNWIRED_EVENT_BUS_RUNTIME_CALLER')),
    '_EVT_PreemptMargin':  ('LAB_CAP_CORE', NEVER('UNWIRED_EVENT_BUS_RUNTIME_CALLER')),
    '_EVT_RevengeBlockBars': ('LAB_CAP_CORE', NEVER('OUTCOME_LEDGER_NOT_IMPLEMENTED')),

    # Heat is called from Lab_OpenOrder; the master switch is the real gate.
    '_HEAT_Enable':        ('LAB_CAP_RISK', ALWAYS),
    '_HEAT_MaxClusterLots': ('LAB_CAP_RISK', EQ('_HEAT_Enable', 'true')),
    '_HEAT_MaxPortfolioLots': ('LAB_CAP_RISK', EQ('_HEAT_Enable', 'true')),
    '_HEAT_ClusterCorr':   ('LAB_CAP_RISK', EQ('_HEAT_Enable', 'true')),
    '_HEAT_DefaultCorr':   ('LAB_CAP_RISK', EQ('_HEAT_Enable', 'true')),
    '_HEAT_UseDynamicCorr': ('LAB_CAP_RISK', EQ('_HEAT_Enable', 'true')),
    '_HEAT_CorrWindowBars': ('LAB_CAP_RISK', AND(EQ('_HEAT_Enable', 'true'),
                                                  EQ('_HEAT_UseDynamicCorr', 'true'))),

    # MiddlePath_AllowEntry is called from Lab_OpenOrder; all other values are gated by its switch.
    'UseMiddlePathVeto':   ('LAB_CAP_CORE', ALWAYS),
    '_MID_LineSource':     ('LAB_CAP_CORE', EQ('UseMiddlePathVeto', 'true')),
    'MID_LOW':             ('LAB_CAP_CORE', EQ('UseMiddlePathVeto', 'true')),
    'MID_HIGH':            ('LAB_CAP_CORE', EQ('UseMiddlePathVeto', 'true')),
    'MIN_CHANNEL_ATR':     ('LAB_CAP_CORE', EQ('UseMiddlePathVeto', 'true')),
    'MIN_LINE_WEIGHT':     ('LAB_CAP_CORE', EQ('UseMiddlePathVeto', 'true')),
    '_MID_DonchianBars':   ('LAB_CAP_CORE', AND(EQ('UseMiddlePathVeto', 'true'),
                                                 EQ('_MID_LineSource', 'MID_LINES_DONCHIAN'))),
    '_MID_PivotDepth':     ('LAB_CAP_CORE', AND(EQ('UseMiddlePathVeto', 'true'),
                                                 EQ('_MID_LineSource', 'MID_LINES_PIVOT'))),
    '_MID_LineLookbackBars': ('LAB_CAP_CORE', AND(EQ('UseMiddlePathVeto', 'true'),
                                                   EQ('_MID_LineSource', 'MID_LINES_PIVOT'))),
    '_MID_MaxLines':       ('LAB_CAP_CORE', AND(EQ('UseMiddlePathVeto', 'true'),
                                                 EQ('_MID_LineSource', 'MID_LINES_PIVOT'))),
    '_MID_ClusterATRmult': ('LAB_CAP_CORE', AND(EQ('UseMiddlePathVeto', 'true'),
                                                 EQ('_MID_LineSource', 'MID_LINES_PIVOT'))),
    '_MID_UseRoomCheck':   ('LAB_CAP_CORE', EQ('UseMiddlePathVeto', 'true')),
    '_MID_MinRR':          ('LAB_CAP_CORE', AND(EQ('UseMiddlePathVeto', 'true'),
                                                 EQ('_MID_UseRoomCheck', 'true'))),

    # --- macro gate ---------------------------------------------------------------------------------
    '_MG_RegimeFile':      ('LAB_CAP_MACROGATE', ALWAYS),
    '_MG_InCommon':        ('LAB_CAP_MACROGATE', ALWAYS),
    '_MG_LotMult':         ('LAB_CAP_MACROGATE', ALWAYS),
    '_MG_BlockNew':        ('LAB_CAP_MACROGATE', ALWAYS),
    '_MG_TriggerRiskOff':  ('LAB_CAP_MACROGATE', ALWAYS),
    '_MG_OffsetHours':     ('LAB_CAP_MACROGATE', ALWAYS),
}

# Boss 17/18 share every B14 row except its build-local entry inputs.  Copying the full table and
# then replacing that exact row set keeps shared gates mechanically identical while making a stale
# B14 entry row impossible to carry into another build.
_B14_ENTRY_ROWS = ('_14_Direction', '_14_DistAtrMult', '_14_MinDistPips')
_COMPATIBILITY_NEVER_ROWS = (
    '_5A_UseSMCVeto', '_5A_PivotDepth', '_5A_SwingLookback', '_5A_MaxSwings',
    '_5A_BreakLookbackBars', '_5A_ChochRecentBars', '_5A_SweepMinATR', '_5A_MinScore',
    '_5A_HighScore', '_5B_ExtendMinRR', '_5B_LockStepR', '_5B_MaxChain',
)


def _with_build_entry_rows(entry_rows):
    table = dict(_B14)
    for name in _B14_ENTRY_ROWS:
        table.pop(name)
    # PARAM_REGISTRY marks these serialized compatibility inputs active_when=NEVER with no
    # behavioral owner. B14's older S7 table predates them; classify them only on the newly
    # declared builds so this extension does not widen B14's accepted metadata surface.
    table.update((name, ('LAB_CAP_CORE', NEVER('PHYSICAL_SURFACE_ONLY')))
                 for name in _COMPATIBILITY_NEVER_ROWS)
    table.update(entry_rows)
    return table


_B17 = _with_build_entry_rows({
    '_17_FractalDepth':    ('LAB_CAP_ENTRY_WAVE5', ALWAYS),
    '_17_Wave3MinMult':    ('LAB_CAP_ENTRY_WAVE5', ALWAYS),
    '_17_EntryFib':        ('LAB_CAP_ENTRY_WAVE5', ALWAYS),
    '_17_SLbufferATR':     ('LAB_CAP_ENTRY_WAVE5', ALWAYS),
    '_17_UseStructLevels': ('LAB_CAP_ENTRY_WAVE5', ALWAYS),
    '_17_DivergTrail':     ('LAB_CAP_EXIT', EQ('ExitMode', 'EXIT_TRAIL')),
    '_17_MaxSwings':       ('LAB_CAP_ENTRY_WAVE5', ALWAYS),
    '_17_RSI_Period':      ('LAB_CAP_EXIT', AND(EQ('ExitMode', 'EXIT_TRAIL'),
                                                 EQ('_17_DivergTrail', 'true'))),
})


_B18 = _with_build_entry_rows({
    '_18_Direction': ('LAB_CAP_ENTRY_JUMSTOCH', ALWAYS),
    '_18_DirMode':   ('LAB_CAP_ENTRY_JUMSTOCH', ALWAYS),
    '_18_MaPeriod':  ('LAB_CAP_ENTRY_JUMSTOCH', ALWAYS),
    '_18_KPeriod':   ('LAB_CAP_ENTRY_JUMSTOCH', ALWAYS),
    '_18_DPeriod':   ('LAB_CAP_ENTRY_JUMSTOCH', ALWAYS),
    '_18_Slowing':   ('LAB_CAP_ENTRY_JUMSTOCH', ALWAYS),
    '_18_LoLevel':   ('LAB_CAP_ENTRY_JUMSTOCH', ALWAYS),
    '_18_UpLevel':   ('LAB_CAP_ENTRY_JUMSTOCH', ALWAYS),
})


TABLE = {'LAB_ENTRY_14': _B14, 'LAB_ENTRY_17': _B17, 'LAB_ENTRY_18': _B18}


def _num(text):
    """-> float, or None when the text is not a number. Enum names and booleans are not numbers
    and must not be coerced into one -- `false` is not 0 here, because an input whose off state
    is `false` is gated by EQ, not by SELF_GT0, and conflating them would silently move a gate."""
    try:
        return float(str(text).strip())
    except (TypeError, ValueError):
        return None


def _value(config, name, whose):
    if name not in config:
        raise Refusal(
            'the activation gate for %s reads %r, which has no value in the supplied config. '
            'Refused rather than assumed inactive: "inactive" removes the input from the '
            'Operator surface and from the optimizer, which is a decision, and an omission is '
            'not one.' % (whose, name))
    return str(config[name]).strip()


def _canon(value, selector, surface):
    """-> the canonical (.set-form) spelling. /scrutinize round 1 (ORDER-1020): gate values are
    written symbolically here (`SL_ATR`, `true`) while a real `.set` supplies `33` -- compared
    raw, the same configuration produced two different reachability answers, and reachability
    decides what becomes a `const`. `preset.render_value` REFUSES an unknown symbol, so the
    canonicalisation cannot invent a match."""
    if surface is not None:
        import preset as _preset
        decl = surface.by_name.get(selector)
        if decl is not None:
            return _preset.render_value(decl, str(value).strip(), surface.enums)
    return str(value).strip()


def _eval(gate, name, config, surface=None):
    kind = gate[0]
    if kind == 'ALWAYS':
        return True
    if kind == 'EQ':
        held = _canon(_value(config, gate[1], name), gate[1], surface)
        return held in tuple(_canon(v, gate[1], surface) for v in gate[2])
    if kind == 'NE':
        return _canon(_value(config, gate[1], name), gate[1], surface) !=             _canon(gate[2], gate[1], surface)
    if kind == 'SELF_GT0':
        v = _num(_value(config, name, name))
        if v is None:
            raise Refusal(
                'the gate for %s is SELF_GT0 but its configured value %r is not a number. That '
                'is a table error, not a config error: SELF_GT0 belongs only on inputs whose 0 '
                'means off.' % (name, config.get(name)))
        return v > 0
    if kind == 'GT0':
        v = _num(_value(config, gate[1], name))
        if v is None:
            raise Refusal('the gate for %s reads %s > 0 but that value %r is not a number'
                          % (name, gate[1], config.get(gate[1])))
        return v > 0
    if kind == 'NEVER':
        return False
    if kind == 'AND':
        return all(_eval(g, name, config, surface) for g in gate[1:])
    raise Refusal('unknown activation gate kind %r for %s' % (kind, name))


class Verdict(object):
    """One input's reachability, with the REASON. A boolean alone cannot say whether an input is
    dark because its module is off or because its own sub-mode is not selected, and those have
    different fixes."""

    def __init__(self, name, token, gate, token_enabled, gate_open):
        self.name = name
        self.token = token
        self.gate = gate
        self.token_enabled = token_enabled
        self.gate_open = gate_open

    @property
    def active(self):
        return self.token_enabled and self.gate_open

    @property
    def reason(self):
        if self.gate[0] == 'NEVER':
            return self.gate[1]
        if self.active:
            return 'reachable'
        if not self.token_enabled:
            return 'capability %s is not enabled by this config' % self.token
        return 'capability %s is enabled, but this input\'s own gate is closed' % self.token


def classify(build_tag, config, surface=None):
    """-> OrderedDict name -> Verdict, for every input on the build's surface."""
    from collections import OrderedDict
    table = TABLE.get(build_tag)
    if table is None:
        raise Refusal(
            'no activation table is declared for build %r. REFUSED rather than answered: slice '
            'S7 declared %s only, and "this build has no table" must not be able to look like '
            '"this build has no inactive inputs" -- the second is a claim, the first is the '
            'absence of one.' % (build_tag, ', '.join(sorted(TABLE))))

    tokens = set(capability.enabled_tokens(build_tag, config, surface=surface))
    names = [d.name for d in surface.inputs] if surface is not None else sorted(table)

    if surface is not None:
        missing = [n for n in names if n not in table]
        if missing:
            raise Refusal(
                'build %s exposes %d input(s) with no activation entry: %s. REFUSED: an input '
                'nobody has classified would default to "reachable" and land on the Operator '
                'surface with no evidence behind it, which is the opposite of what this slice '
                'is for.' % (build_tag, len(missing), ', '.join(missing[:10])))
        extra = [n for n in sorted(table) if n not in set(names)]
        if extra:
            raise Refusal(
                'the activation table for %s classifies %d input(s) the build does not expose: '
                '%s. REFUSED: a stale entry is a claim about an input that no longer exists, and '
                'it would keep passing every check that only looks the other way.'
                % (build_tag, len(extra), ', '.join(extra[:10])))

    out = OrderedDict()
    for name in names:
        token, gate = table[name]
        out[name] = Verdict(name, token, gate, token in tokens, _eval(gate, name, config, surface))
    return out


def effective_state(build_tag, config, surface=None):
    """Return the shared deterministic effective-state projection.

    This is metadata only. It combines the existing activation verdict with
    the typed relation metadata so surface generation, wrappers, and previews
    have one reason-bearing projection without adding runtime behavior.
    """
    states = {}
    for name, verdict in classify(build_tag, config, surface=surface).items():
        static = relation_metadata(name) if name in _R4_RELATIONS else {
            'relations': (), 'reason_code': None
        }
        if verdict.active:
            state, effective, reason_code = 'ACTIVE', True, None
        elif verdict.gate[0] == 'NEVER':
            state, effective, reason_code = 'HIDDEN_INACTIVE', False, verdict.gate[1]
        elif not verdict.token_enabled:
            state, effective, reason_code = 'HIDDEN_INACTIVE', False, 'CAPABILITY_DISABLED'
        else:
            state, effective, reason_code = 'HIDDEN_INACTIVE', False, 'GATE_CLOSED'
        states[name] = {
            'name': name,
            'state': state,
            'effective': effective,
            'reason_code': reason_code,
            'reason': verdict.reason,
            'token': verdict.token,
            'token_enabled': verdict.token_enabled,
            'gate_open': verdict.gate_open,
            'gate': verdict.gate,
            'gate_dependencies': _gate_dependencies(verdict.gate),
            'relations': static.get('relations', ()),
        }
    return states


def _repo_root():
    return os.path.dirname(os.path.dirname(HERE))


def main(argv):
    import io
    import collections
    if not argv:
        sys.stderr.write('usage: activation.py <LAB_ENTRY_nn> [Name=Value ...]\n')
        return 2
    build_tag = argv[0]
    overrides = dict(a.split('=', 1) for a in argv[1:] if '=' in a)
    root = _repo_root()
    text = io.open(os.path.join(root, preset.INPUTS_REL.replace('/', os.sep)),
                   encoding='utf-8-sig').read()
    try:
        surface = preset.parse_surface(text, build_tag)
        config = dict((d.name, d.default_expr) for d in surface.inputs)
        config.update(overrides)
        states = effective_state(build_tag, config, surface=surface)
    except Refusal as exc:
        sys.stderr.write('REFUSED: %s\n' % exc)
        return 1
    active = [v for v in states.values() if v['state'] == 'ACTIVE']
    dark = [v for v in states.values() if v['state'] != 'ACTIVE']
    by_reason = collections.Counter(
        v['reason_code'] or 'GATE_CLOSED' for v in dark)
    sys.stdout.write('build %s%s\n' % (build_tag,
                                       (' with ' + ', '.join('%s=%s' % kv for kv in
                                                             sorted(overrides.items()))
                                        if overrides else '')))
    sys.stdout.write('  surface           : %d input(s)\n' % len(states))
    sys.stdout.write('  reachable         : %d\n' % len(active))
    sys.stdout.write('  unreachable       : %d  (%s)\n'
                     % (len(dark), ', '.join('%s %d' % (k, v) for k, v in by_reason.most_common())))
    if '--list' in argv:
        for v in states.values():
            sys.stdout.write('    %-22s %-28s %s\n'
                             % (v['name'], v['token'],
                                'ACTIVE' if v['state'] == 'ACTIVE' else v['reason']))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
