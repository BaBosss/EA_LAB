# -*- coding: utf-8 -*-
"""Prospective fixed-config Boss12 H01 registration data.

The owner-approved preregistration lives in AGENT_TASKBOARD.md. This module grants no optimizer
ranges: every reachable strategy/mechanism input not explicitly classified as safety/sizing/runtime
is LOCKED to the preregistered regression-default baseline by gen_registry_rows.py.
"""
PREREGISTRATION_ORDER = 'AGENT_TASKBOARD.md'
PREREGISTRATION_COMMIT = '82fb2d06f8b6a6240ff1aa222d14e4438fead1e4'
PREREGISTRATION_ANCHOR = 'FACTORY-B11-16-PROSPECTIVE-H01-PREREGISTRATION:'
DEFINITION_PATH = 'docs/PARAM_REGISTRY.csv'
BUILD_TAG = 'LAB_ENTRY_12'
CONFIG_SET_REL = 'ea_template/sets/regression/Boss_12_Breakout_defaults.set'
EXPECTED_BASELINE_KEYS = 155
EXPECTED_BASELINE_SHA256 = '62ffa4e95a08a483617046694309a8082c1d07bece39a778704f67cb389626c1'
FIXED_BASELINE = True
LOCKED_SELECTORS = ()

HYPOTHESES = {
    'B12-H01': {
        'revision': 1,
        'boss_family': 12,
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
    if hypothesis_id != 'B12-H01':
        raise KeyError(hypothesis_id)
    return dict(DECISIONS)
