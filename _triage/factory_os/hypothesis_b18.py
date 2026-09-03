# -*- coding: utf-8 -*-
"""Prospective fixed-config Boss18 H01 registration data.

The owner-ratified semantic decision is already canonical: DirMode 1 is the
faithful momentum-join identity. This provider only enrolls that exact frozen
baseline prospectively; it creates no optimizer authority and does not alter
the historical DEAD-OPTIMIZED / NOT-DEPLOY port/cell verdict.
"""
PREREGISTRATION_ORDER = 'AGENT_TASKBOARD.md'
PREREGISTRATION_COMMIT = '44adcd3fd02b8e5edc77842951f96b017e2a0d59'
PREREGISTRATION_ANCHOR = 'FACTORY-B18-H01-PREREGISTRATION'
DEFINITION_PATH = 'docs/PARAM_REGISTRY.csv'
BUILD_TAG = 'LAB_ENTRY_18'
CONFIG_SET_REL = 'ea_template/sets/regression/Boss_18_JumStoch_defaults.set'
EXPECTED_BASELINE_KEYS = 159
EXPECTED_BASELINE_SHA256 = '67973adaf57211858f8bb615c4a73864adc03fd31e6ad0d16f6a044a8882a1c1'
FIXED_BASELINE = True
LOCKED_SELECTORS = ()

HYPOTHESES = {
    'B18-H01': {
        'revision': 1,
        'boss_family': 18,
        'coupling_class': 'COUPLED',
        'engine_edge': False,
        'experimental': True,
        'status': 'REGISTERED',
        'preregistration_anchor': PREREGISTRATION_ANCHOR,
        'preregistration_commit': PREREGISTRATION_COMMIT,
        'config': {},
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
}


def decisions_for(hypothesis_id):
    if hypothesis_id != 'B18-H01':
        raise KeyError(hypothesis_id)
    return dict(DECISIONS)
