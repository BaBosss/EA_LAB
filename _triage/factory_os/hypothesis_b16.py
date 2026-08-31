# -*- coding: utf-8 -*-
"""Prospective fixed-config Boss16 H01/H05 registration data.

The owner-approved preregistration lives in AGENT_TASKBOARD.md. This module grants no optimizer
ranges: every reachable strategy/mechanism input not explicitly classified as safety/sizing/runtime
is LOCKED to the preregistered regression-default baseline by gen_registry_rows.py.
"""
PREREGISTRATION_ORDER = 'AGENT_TASKBOARD.md'
PREREGISTRATION_COMMIT = '82fb2d06f8b6a6240ff1aa222d14e4438fead1e4'
PREREGISTRATION_ANCHOR = 'FACTORY-B11-16-PROSPECTIVE-H01-PREREGISTRATION:'
PREREGISTRATION_COMMIT_H05 = '0f0ffbc8c86a304e937c0b509a7c4719a3e10bf1'
PREREGISTRATION_ANCHOR_H05 = 'B16-H05-r1'
DEFINITION_PATH = 'docs/PARAM_REGISTRY.csv'
BUILD_TAG = 'LAB_ENTRY_16'
CONFIG_SET_REL = 'ea_template/sets/regression/Boss_16_KangarooGrid_defaults.set'
EXPECTED_BASELINE_KEYS = 134
EXPECTED_BASELINE_SHA256 = '4c18e345bd773d47cfde945bfa5ed47e7bbff3cd3d245dd0079829084ef15563'
FIXED_BASELINE = True
LOCKED_SELECTORS = ()

HYPOTHESES = {
    'B16-H01': {
        'revision': 1,
        'boss_family': 16,
        'coupling_class': 'COUPLED',
        'engine_edge': False,
        'experimental': True,
        'status': 'REGISTERED',
        'preregistration_anchor': PREREGISTRATION_ANCHOR,
        'preregistration_commit': PREREGISTRATION_COMMIT,
        'config': {},
    },
    'B16-H05': {
        'revision': 1,
        'boss_family': 16,
        'coupling_class': 'COUPLED',
        'engine_edge': False,
        'experimental': True,
        'status': 'REGISTERED',
        'preregistration_anchor': PREREGISTRATION_ANCHOR_H05,
        'preregistration_commit': PREREGISTRATION_COMMIT_H05,
        # Exact accepted SELL child differs from the 134-key logical baseline only here.
        'config': {'_16_Direction': '2'},
    },
}

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
    '_16_BaseLot':          ('SIZING', 'OPERATOR', 'FREEZE', None),
    '_16_MaxOrdersPerSide': ('SAFETY', 'OPERATOR', 'FREEZE', None),
    '_16_MaxLotPerOrder':   ('SAFETY', 'OPERATOR', 'FREEZE', None),
    '_16_EmergencyDDPct':   ('SAFETY', 'OPERATOR', 'FREEZE', None),
}

# H05 asks one causal question only: whether the accepted GBPUSD/H4 SELL edge has a stable
# RSI-entry region around 14/70. Position engine, spacing, exits, sizing and safety stay frozen.
DECISIONS_H05 = dict(DECISIONS)
DECISIONS_H05.update({
    '_16_RsiPeriod': ('TUNABLE', 'OPERATOR', 'SIGNAL', (7.0, 7.0, 28.0)),
    '_16_RsiHigh':   ('TUNABLE', 'OPERATOR', 'SIGNAL', (60.0, 5.0, 80.0)),
})


def decisions_for(hypothesis_id):
    if hypothesis_id == 'B16-H01':
        return dict(DECISIONS)
    if hypothesis_id == 'B16-H05':
        return dict(DECISIONS_H05)
    raise KeyError(hypothesis_id)
