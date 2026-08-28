# -*- coding: utf-8 -*-
"""Boss17 Factory registration decision table.

This module records only the decided half of B17-H01. Reachability, PIDs,
capability membership and architecture digest remain derived by the Factory
resolvers. The causal mechanism and prospective naked-pass bar predate the
historical selected set and remain in AGENT_TASKBOARD.md at the pinned commit.

The XAU set is identity evidence, not optimizer authority. This historical registration is deliberately frozen: ORDER-148 says to use the selected
demo set and not tune it. Active research dials are therefore LOCKED with explicit values;
a future sweep requires a prospective hypothesis revision rather than inheriting post-hoc range authority.
"""

PREREGISTRATION_ORDER = 'AGENT_TASKBOARD.md'
PREREGISTRATION_COMMIT = '0e9cebb1e87f155656c479055ea0e94212f51384'
PREREGISTRATION_ANCHOR = 'Entry_Wave5:'
DEFINITION_PATH = 'docs/PARAM_REGISTRY.csv'
BUILD_TAG = 'LAB_ENTRY_17'
CONFIG_SET_REL = '_vps_deploy/WAVE5_XAU/WAVE5_XAU_H1_demo_v1.set'
CONFIG_SET_FIRST_COMMIT = '86151de9b1dba7bd52bc98980ee30f6be686fcb1'

CONFIG = {
    # Tracked selected-set overrides.
    'ExitMode': '23', '_9_MaxLevels': '1', '_23_TrailStart': '2000',
    '_23_TrailStep': '800', '_17_UseStructLevels': 'true',
    '_17_DivergTrail': 'true', '_17_EntryFib': '23.6',
    '_17_Wave3MinMult': '0.618', '_0_Magic': '990301',
    # Explicit frozen chassis/entry values. Do not fall back to mutable defaults.
    'SLMode': 'SL_ATR', 'FirstLotMode': 'FIRSTLOT_FIXED', 'LotProg': 'PROG_NONE',
    'StackMode': 'STACK_SINGLE', 'RecoveryMode': 'REC_NONE', 'HedgeMode': 'HEDGE_OFF',
    '_50_RegimeMode': '0', '_MG_SelfGate': 'false', '_4_DdAdaptiveOn': 'false',
    '_57_DynCloseOn': 'false', '_33_AdaptiveON': 'false', '_0_BarOpenOnly': 'false',
    '_17_FractalDepth': '3', '_17_SLbufferATR': '0.5', '_17_MaxSwings': '8',
    '_17_RSI_Period': '14', '_2_BasketTP_Money': '0', '_2_SuppressLegTP': 'false',
    '_33_SL_ATRmult': '2.0', '_0_ATR_Period': '14', '_0_ATR_TF': 'PERIOD_CURRENT',
    '_3_RiskATR_Period': '14', '_3_RiskATR_TF': 'PERIOD_CURRENT',
    'UseMiddlePathVeto': 'false',
}

HYPOTHESES = {
    'B17-H01': {
        'revision': 1,
        'boss_family': 17,
        'coupling_class': 'SCALE_INVARIANT',
        'engine_edge': False,
        'experimental': True,
        # Boss_17 exists historically, but no Factory-generated wrapper exists.
        'status': 'REGISTERED',
        'preregistration_anchor': PREREGISTRATION_ANCHOR,
        'preregistration_commit': PREREGISTRATION_COMMIT,
        'config': dict(CONFIG),
    },
}

# A selector chooses a mechanism. Changing one is a new hypothesis/revision,
# not an optimizer axis. The three _17/_33 switches below are B17-specific
# mechanism selectors in addition to the generic chassis selectors.
LOCKED_SELECTORS = (
    'ExitMode', 'SLMode', 'FirstLotMode', 'LotProg', 'StackMode',
    'RecoveryMode', 'HedgeMode', '_50_RegimeMode', '_MG_SelfGate',
    '_4_DdAdaptiveOn', '_57_DynCloseOn', '_17_UseStructLevels',
    '_17_DivergTrail', '_33_AdaptiveON', '_0_BarOpenOnly',
    '_17_FractalDepth', '_17_Wave3MinMult', '_17_EntryFib',
    '_17_SLbufferATR', '_17_MaxSwings', '_17_RSI_Period',
    '_2_BasketTP_Money', '_23_TrailStart', '_23_TrailStep',
    '_2_SuppressLegTP', '_33_SL_ATRmult', '_0_ATR_Period', '_0_ATR_TF',
    '_3_RiskATR_Period', '_3_RiskATR_TF', 'UseMiddlePathVeto',
)

DECISIONS = {
    'DryRun':             ('SAFETY', 'OPERATOR', 'FREEZE', None),
    '_9_MaxLevels':       ('SAFETY', 'OPERATOR', 'FREEZE', None),
    'ProtectLevel':       ('SAFETY', 'OPERATOR', 'FREEZE', None),
    'RC_MaxLot':          ('SAFETY', 'OPERATOR', 'FREEZE', None),
    'RC_PersistHalt':     ('SAFETY', 'RESEARCH', 'FREEZE', None),
    'RC_AdoptLegacyHalt': ('SAFETY', 'RESEARCH', 'FREEZE', None),
    '_HEAT_Enable':       ('SAFETY', 'OPERATOR', 'FREEZE', None),
    '_41_FixedLot':       ('SIZING', 'OPERATOR', 'FREEZE', None),
    '_0_Magic':           ('RUNTIME', 'OPERATOR', 'FREEZE', None),
    '_0_Slippage':        ('RUNTIME', 'RESEARCH', 'FREEZE', None),
}


def decisions_for(hypothesis_id):
    if hypothesis_id != 'B17-H01':
        raise KeyError(hypothesis_id)
    return dict(DECISIONS)


def _validate_against_resolver():
    import os as _os
    import sys as _sys
    here = _os.path.dirname(_os.path.abspath(__file__))
    if here not in _sys.path:
        _sys.path.insert(0, here)
    import registry as _registry
    bad = []
    for param, (role, surface, _stage, _range) in sorted(DECISIONS.items()):
        if role not in _registry.ROLES:
            bad.append('%s role %r not in registry.ROLES' % (param, role))
        if surface not in _registry.SURFACES:
            bad.append('%s surface %r not in registry.SURFACES' % (param, surface))
    if bad:
        raise ValueError('hypothesis_b17.py invalid decision vocabulary:\n  ' + '\n  '.join(bad))


_validate_against_resolver()
