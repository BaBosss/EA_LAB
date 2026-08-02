# -*- coding: utf-8 -*-
"""hypothesis_b14.py -- ORDER-1020 (slice S7). The two Boss_14 hypotheses, as DATA.

WHAT THIS FILE IS. Design section 8.1 states `B14-H01` and `B14-H02` in prose: the causal claim,
the architecture, the falsifier, the coupling class and the class label. Design section 8.6
requires them to exist as rows in `factory/hypotheses.jsonl` with a `preregistration_ref` that
resolves to a taskboard order carrying the claim and the falsifier -- **and requires that the
registry NOT copy them.** So this file holds the MACHINE-READ half only: identity, the pinned
configuration, and the per-parameter decisions. The claim and the falsifier live on `ORDER-1020`
and are reached by reference.

  🔴 THE PINNED CONFIG IS PART OF THE HYPOTHESIS, NOT A DEFAULT. `H01`'s claim is a GridLog grid
  with LOG-power escalation, no broker SL, and a basket money target. The chassis DEFAULTS give
  the first three and NOT the fourth, and they also leave every basket-level loss cap at zero:
  `_32_SL_Money=0`, `_32_SL_BalPct=0`, `RC_AcctDDLimitPct=0.0`, `_2_MaxHoldBars=0`. Registering
  H01 at its defaults would therefore register a LOG-power escalation with **no target and no
  basket stop** -- an EA whose losing basket has no exit at all except the depth cap declining to
  add more. `_9_MaxLevels=5` and `RC_MaxLot=0.20` keep it out of `CLAUDE.md`'s uncapped-ruin
  structural test (that needs no SL AND no depth cap AND a geometric ladder), so this is
  ENGINE-EDGE class rather than dead -- and ENGINE-EDGE cage condition 1 is *"worst case is
  computable: hard depth cap + basket-SL/DD-kill, stated as a number"*. A hypothesis that does not
  pin that is not the hypothesis section 8.1 describes.

  The two cage numbers are DERIVED FROM RATIFIED RULES, not chosen:
    `_32_SL_BalPct = 15.0`   `CLAUDE.md` ENGINE-EDGE cage condition 1 -- "a single loss costs
                             <= 15% equity at the real sizing" -- expressed as the portable
                             (balance-%) form rather than the absolute-money one, because
                             `Inputs.mqh:394` marks `_32_SL_Money` ABSOLUTE and the registry's
                             `_2_BasketTP_BalPct` row records the same portability problem.
    `RC_AcctDDLimitPct = 12.0`  the demo-kill bar in `CLAUDE.md`'s bar table (eqDD > 12%). Same
                             number the judge would use, so the EA halts where the judge would
                             kill it rather than after it.

WHAT THIS FILE DOES NOT DECIDE. Reachability -- that is `activation.py`, computed from the pinned
config. Every input this file does not name is classified `INACTIVE`/`HIDDEN` automatically, and
`check_param_surface.py` refuses a decision table that names an input the config cannot reach:
otherwise a stale entry would keep a dial on the Operator surface after the mode that needed it
was turned off.

CATEGORY (TIER_SNAPSHOT_DESIGN.md section 2/3.3): PURE DATA. No reads, no clock.
"""

# The order that pre-registers both hypotheses. It carries the causal claim, the falsifier and the
# pre-registered bars; this module must not restate them (design 8.6).
PREREGISTRATION_ORDER = 'AGENT_TASKBOARD.md'
PREREGISTRATION_ANCHOR_H01 = 'B14-H01-PREREGISTRATION'
PREREGISTRATION_ANCHOR_H02 = 'B14-H02-PREREGISTRATION'

# The file that owns each parameter's PERMANENT semantics. Every ParameterBinding pins it.
DEFINITION_PATH = 'docs/PARAM_REGISTRY.csv'

BUILD_TAG = 'LAB_ENTRY_14'


# --- the two hypotheses ------------------------------------------------------------------------
# `config` is the OVERRIDE over the build's declared defaults. Anything absent is the default, and
# `gen_registry_rows.py` resolves it that way so this file cannot drift from `Inputs.mqh`.

HYPOTHESES = {
    'B14-H01': {
        'revision': 1,
        'boss_family': 14,
        'coupling_class': 'COUPLED',        # money-denominated basket TP + lot progression
        'engine_edge': True,                # section 8.1 class label
        'experimental': True,               # no parity has ever run; design 3.2
        # /scrutinize round 2: this said DRAFT while the rows WERE registered and the wrappers
        # WERE generated -- a lifecycle field describing a state two commits in the past.
        # design 3.1 REFUSES `WRAPPER_GENERATED` if any bound parameter lacks `active_when`,
        # `context` or `causal_question` in docs/PARAM_REGISTRY.csv. MEASURED before writing it:
        # 0 of build 14's 116 inputs are missing any of the three -- and `check_wrapper_gen` W5
        # now re-measures it rather than trusting this comment.
        'status': 'WRAPPER_GENERATED',
        'preregistration_anchor': PREREGISTRATION_ANCHOR_H01,
        'config': {
            # the architecture section 8.1 names
            'LotProg':            'PROG_LOG_POWER',    # LOG-power escalation, the Zeus port
            'SLMode':             'SL_NONE',           # "no broker SL"
            # the cage, without which the claim's own class cannot proceed (see the docstring)
            '_32_SL_BalPct':      '15.0',
            'RC_AcctDDLimitPct':  '12.0',
            # the basket money target the claim names, in its portable form
            '_2_BasketTP_BalPct': '1.0',
        },
    },
    'B14-H02': {
        'revision': 1,
        'boss_family': 14,
        'coupling_class': 'COUPLED',
        'engine_edge': True,                # "ENGINE-EDGE until measured otherwise" (section 8.1)
        'experimental': True,
        'status': 'WRAPPER_GENERATED',   # same measurement as H01; see the note there
        'preregistration_anchor': PREREGISTRATION_ANCHOR_H02,
        'config': {
            'LotProg':            'PROG_LOG_POWER',
            'SLMode':             'SL_NONE',
            '_32_SL_BalPct':      '15.0',
            'RC_AcctDDLimitPct':  '12.0',
            '_2_BasketTP_BalPct': '1.0',
            # ...and the one thing that makes it H02 rather than H01
            'HedgeMode':          'HEDGE_LOCK',
        },
    },
}

# H02 starts EXPERIMENTAL for a REASON that outlives the flag, and design 8.2 gate 2 states it:
# `PROJECT_STATE` section 7 records that HEDGE_LOCK has never passed a backtest, so enabling it the
# first time is VALIDATING A NEW MECHANISM, not toggling one. It therefore cannot produce promotion
# evidence until its module reaches Stable Core (design 3.2).
H02_EXPERIMENTAL_REASON = (
    'HEDGE_LOCK has never passed a backtest (PROJECT_STATE section 7), so enabling it is '
    'validating a new mechanism rather than toggling a flag (design 8.2 gate 2)')


# --- the mechanism selectors each hypothesis LOCKS ------------------------------------------------
# A locked parameter becomes a `const` in the generated wrapper (design 5.4) and is REFUSED by
# `optimize_guard` -- not sweepable and not even present. These are exactly the inputs that decide
# WHICH MECHANISM runs; a numeric dial inside a selected mechanism is TUNABLE, not locked, or every
# re-optimize would need a new hypothesis revision.
LOCKED_SELECTORS = (
    'ExitMode', 'SLMode', 'FirstLotMode', 'LotProg',
    'StackMode', 'StackConfirm', 'RecoveryMode', 'HedgeMode',
    '_50_RegimeMode', '_MG_SelfGate',
)


# --- per-parameter decisions for the inputs that stay VISIBLE --------------------------------------
# name -> (role, surface, optimize_stage, safe_range or None)
#
# 🔴 WHAT A `safe_range` IS AND IS NOT. It is the PRE-REGISTERED STARTING GRID for a sweep -- the
# span it is safe to explore -- not a measured optimum and not a claim that the answer is inside
# it. `backtest-optimize-rigor` and memory `grid-answer-outside-the-grid` both require the grid to
# be EXPANDED when a result lands on a boundary, so a bound here is the start of that procedure,
# never the end of it. Where no defensible bound exists the value is `None` and the reason is that
# nothing in the code or the registry constrains it -- stated as absence rather than filled with a
# plausible number.
#
# ROLE VOCABULARY (registry.py owns it; only TUNABLE is optimizable):
#   TUNABLE  a dial a sweep may move          SAFETY   a cap; sinput, never swept
#   SIZING   decides money at risk            RUNTIME  per-deployment identity/plumbing
#   LOCKED   pinned by the hypothesis         INACTIVE unreachable under this config
DECISIONS = {
    # --- entry / grid geometry: the signal, and where H01 says the mechanism lives --------------
    '_14_Direction':      ('TUNABLE', 'OPERATOR', 'ARCHITECTURE', None),
    '_14_DistAtrMult':    ('TUNABLE', 'OPERATOR', 'SIGNAL',  (0.5, 0.25, 3.0)),
    '_14_MinDistPips':    ('TUNABLE', 'OPERATOR', 'SIGNAL',  (5.0, 5.0, 50.0)),
    '_9_StepUseATR':      ('TUNABLE', 'OPERATOR', 'SIGNAL',  None),
    '_9_StepATRmult':     ('TUNABLE', 'OPERATOR', 'SIGNAL',  (0.5, 0.25, 3.0)),
    '_9_StepPoints':      ('TUNABLE', 'RESEARCH', 'SIGNAL',  None),
    '_9_StepATRShift':    ('TUNABLE', 'RESEARCH', 'SIGNAL',  None),
    '_0_ATR_Period':      ('TUNABLE', 'OPERATOR', 'SIGNAL',  (7.0, 7.0, 28.0)),
    '_0_ATR_TF':          ('TUNABLE', 'RESEARCH', 'SIGNAL',  None),

    # --- the escalation law: H01's claim is that the edge is HERE, not in the signal -------------
    '_55_LogPowerFactor': ('TUNABLE', 'OPERATOR', 'ARCHITECTURE', (1.1, 0.1, 2.0)),
    '_55_UseLnNotLog10':  ('TUNABLE', 'OPERATOR', 'ARCHITECTURE', None),

    # --- exits -----------------------------------------------------------------------------------
    '_22_TP_ATRmult':     ('TUNABLE', 'OPERATOR', 'EXIT',    (1.0, 0.5, 6.0)),
    '_2_BasketTP_BalPct': ('TUNABLE', 'OPERATOR', 'EXIT',    (0.5, 0.5, 5.0)),
    '_2_BasketTP_Money':  ('TUNABLE', 'RESEARCH', 'EXIT',    None),
    '_2_SuppressLegTP':   ('TUNABLE', 'RESEARCH', 'EXIT',    None),
    '_57_DynCloseOn':     ('TUNABLE', 'RESEARCH', 'EXIT',    None),
    '_3_RiskATR_Period':  ('TUNABLE', 'RESEARCH', 'EXIT',    None),
    '_3_RiskATR_TF':      ('TUNABLE', 'RESEARCH', 'EXIT',    None),

    # --- stress ------------------------------------------------------------------------------------
    '_4_DdAdaptiveOn':    ('TUNABLE', 'RESEARCH', 'STRESS',  None),

    # --- execution ---------------------------------------------------------------------------------
    '_0_BarOpenOnly':     ('TUNABLE', 'RESEARCH', 'EXECUTION', None),

    # --- sizing: NOT optimizable, and that is the ENGINE-EDGE rule, not a preference --------------
    # `CLAUDE.md`: the engine-edge label means permanently small sizing, never sized up on PF. A
    # sweepable base lot is precisely how "never size up on PF" gets violated by an optimizer that
    # has no opinion about the label.
    '_41_FixedLot':       ('SIZING',  'OPERATOR', 'FREEZE',  None),

    # --- safety: sinput, refused by optimize_guard always ------------------------------------------
    '_9_MaxLevels':       ('SAFETY',  'OPERATOR', 'FREEZE',  None),
    '_32_SL_BalPct':      ('SAFETY',  'OPERATOR', 'FREEZE',  None),
    'RC_AcctDDLimitPct':  ('SAFETY',  'OPERATOR', 'FREEZE',  None),
    'RC_MaxLot':          ('SAFETY',  'OPERATOR', 'FREEZE',  None),
    'ProtectLevel':       ('SAFETY',  'OPERATOR', 'FREEZE',  None),
    'RC_PersistHalt':     ('SAFETY',  'RESEARCH', 'FREEZE',  None),
    'RC_AdoptLegacyHalt': ('SAFETY',  'RESEARCH', 'FREEZE',  None),
    'DryRun':             ('SAFETY',  'OPERATOR', 'FREEZE',  None),

    # --- runtime identity / plumbing: settable per deployment, never a sweep dimension -------------
    '_0_Magic':           ('RUNTIME', 'OPERATOR', 'FREEZE',  None),
    '_0_Slippage':        ('RUNTIME', 'RESEARCH', 'FREEZE',  None),
}

# The inputs H02 adds on top of H01's visible set, because HEDGE_LOCK makes the hedge module
# reachable. Same shape as DECISIONS; merged for H02 only.
DECISIONS_H02_EXTRA = {
    '_H_TriggerDDPct':    ('TUNABLE', 'OPERATOR', 'STRESS',  (5.0, 2.5, 20.0)),
    '_H_ReleaseDDPct':    ('TUNABLE', 'OPERATOR', 'STRESS',  (2.0, 1.0, 10.0)),
    '_H_Ratio':           ('TUNABLE', 'OPERATOR', 'STRESS',  (0.5, 0.25, 1.5)),
    # 🔴 `_H_MaxLot` is DELIBERATELY ABSENT, and the completeness check is why it is now a comment
    # rather than a row. It was listed here as a SAFETY dial on the first draft; the generator
    # refused, because the input is gated `> 0` and its default is `0.0`, so it is unreachable.
    # Reading `Inputs.mqh:517` explains it: `0 = use RC_MaxLot only`. The hedge leg's ceiling is
    # therefore NOT absent -- it is `RC_MaxLot`, which is in the visible SAFETY set already. A row
    # here would have advertised a second cap that never applies. This is the check catching a
    # decision about a dial the config cannot reach, which is exactly what it is for.
}


def decisions_for(hypothesis_id):
    """-> the decision table for one hypothesis. H02 is H01 plus the hedge dials."""
    if hypothesis_id == 'B14-H01':
        return dict(DECISIONS)
    if hypothesis_id == 'B14-H02':
        merged = dict(DECISIONS)
        merged.update(DECISIONS_H02_EXTRA)
        return merged
    raise KeyError(hypothesis_id)


# --- the vocabulary check that makes this file a TABLE rather than a second resolver ---------------
# `check_registries` R4 sweeps every `_triage/factory_os/*.py` for a file that names the role
# vocabulary, because two files deciding what `TUNABLE` means is the drift the one-resolver rule
# exists to stop. This file is exempted there, and the exemption's reason is only worth anything if
# it is enforced: so every role and surface written above is validated against the resolver's own
# tuples AT IMPORT. A value the resolver does not know cannot survive in this table for one run.
#
# It runs at import rather than inside `decisions_for()` on purpose -- a typo in a row that no
# hypothesis currently uses would otherwise sit here unnoticed until the day it was used.
def _validate_against_resolver():
    import os as _os
    import sys as _sys
    _here = _os.path.dirname(_os.path.abspath(__file__))
    if _here not in _sys.path:
        _sys.path.insert(0, _here)
    import registry as _registry
    bad = []
    for table_name, table in (('DECISIONS', DECISIONS),
                              ('DECISIONS_H02_EXTRA', DECISIONS_H02_EXTRA)):
        for param, (role, surf, _stage, _rng) in sorted(table.items()):
            if role not in _registry.ROLES:
                bad.append('%s[%s] role %r is not in registry.ROLES %s'
                           % (table_name, param, role, list(_registry.ROLES)))
            if surf not in _registry.SURFACES:
                bad.append('%s[%s] surface %r is not in registry.SURFACES %s'
                           % (table_name, param, surf, list(_registry.SURFACES)))
    if bad:
        raise ValueError('hypothesis_b14.py names value(s) the resolver does not know:\n  '
                         + '\n  '.join(bad))


_validate_against_resolver()
