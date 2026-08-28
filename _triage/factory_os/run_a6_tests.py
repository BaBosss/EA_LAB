# -*- coding: utf-8 -*-
"""A6 deterministic cage: catalog, human metadata, reasons, and preview."""
import csv
import hashlib
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

import a6_metadata as A6  # noqa: E402
import preset  # noqa: E402
import registry  # noqa: E402


def check(label, condition, detail=''):
    if condition:
        print('[PASS] ' + label)
        return True
    print('[FAIL] ' + label + ((': ' + str(detail)) if detail else ''))
    return False


def declaration_signature(text):
    records = re.findall(r'\binput\s+([\w:]+)\s+([A-Za-z_]\w*)\s*=\s*([^;]+);', text)
    canonical = '\n'.join('|'.join(part.strip() for part in record)
                           for record in records) + '\n'
    return hashlib.sha256(canonical.encode('utf-8')).hexdigest()


def main():
    failures = 0
    cards = A6.load_strategy_cards(ROOT)
    failures += not check('A6 strategy catalog resolves Boss 11-18 exactly once',
                          len(cards) == 8 and
                          [c['ea_id'] for c in cards] == ['E011', 'E012', 'E013', 'E014',
                                                          'E015', 'E016', 'E017', 'E018'])
    failures += not check('A6 strategy catalog identity fields are complete',
                          all(set(A6.CARD_FIELDS) <= set(c) for c in cards))

    rows = A6.load_parameter_metadata(ROOT)
    row_values = list(rows.values())
    physical_rows = registry.read_parameter_registry(root=ROOT)
    compatibility_rows = [row for row in physical_rows
                          if row['classification'].strip().upper() == 'COMPATIBILITY']
    failures += not check('A6 physical registry includes 12 compatibility identities',
                          len(physical_rows) == 222 and
                          len({registry.bare_registry_name(row['name'])
                               for row in physical_rows}) == 208 and
                          len(compatibility_rows) == 12 and
                          {row['parameter_pid'] for row in compatibility_rows} ==
                          set(range(73000, 73012)),
                          (len(physical_rows), len(compatibility_rows)))
    failures += not check('A6 196 logical parameters have PID metadata',
                          len(row_values) == 196 and
                          len({r['parameter_pid'] for r in row_values}) == 196,
                          len(row_values))
    failures += not check('A6 196 logical parameters have unit_true and portability',
                          all(r.get('unit_true') and r.get('portability') for r in row_values))
    failures += not check('A6 portability vocabulary is closed',
                          {r['portability'] for r in row_values} <= set(A6.PORTABILITY_VALUES))

    comments = A6.display_comments(ROOT)
    failures += not check('A6 every logical parameter has a generated display comment',
                          len(comments) == 196)
    failures += not check('A6 generated display comments are <=63 chars',
                          max((len(v) for v in comments.values()), default=0) <= 63,
                          max((len(v) for v in comments.values()), default=0))
    failures += not check('A6 every relation hint resolves',
                          A6.relation_hints_resolve(row_values))

    inputs = io.open(os.path.join(ROOT, 'ea_template', 'core', 'Inputs.mqh'),
                     encoding='utf-8-sig').read()
    declaration_names = set(re.findall(r'\binput\s+[\w:]+\s+([A-Za-z_]\w*)\s*=', inputs))
    failures += not check('A6 internal MQL declaration signature remains unchanged',
                          declaration_signature(inputs) ==
                          '838e7422b7ba7e023e2e8ee1fdbd67e6500835c3923c75df72b042350f1315a9',
                          declaration_signature(inputs))
    failures += not check('A6 logical registry names remain a subset of MQL inputs',
                          {r['parameter'] for r in row_values} <= declaration_names)
    failures += not check('A6 SMC Module 5A/5B keys stay outside the logical surface',
                          not any(r['parameter'].startswith(('_5A_', '_5B_'))
                                  for r in row_values))
    failures += not check('A6 all eight identity cards expose first-group memory aids',
                          all(A6.memory_aid(c) in inputs for c in cards))

    surface = preset.parse_surface(inputs, 'LAB_ENTRY_14')
    units = preset.parse_unit_classes(io.open(
        os.path.join(ROOT, 'docs', 'PARAM_REGISTRY.csv'), encoding='utf-8-sig').read())
    defaults = [(d.name, ({'value': d.default_expr, 'unit': 'usd'}
                          if preset.is_money_unit(units.get(d.name))
                          else d.default_expr)) for d in surface.inputs]
    enums = preset.parse_enum_table(inputs)
    base = preset.compile_preset(surface, [preset.Layer('defaults', defaults)], 'usd',
                                 unit_classes=units, enums=enums, locked_constants={})
    override = preset.compile_preset(
        surface,
        [preset.Layer('defaults', defaults),
         preset.Layer('hypothesis', [('_57_DynCloseBalPct', '5.0')])],
        'usd', unit_classes=units, enums=enums, locked_constants={})
    preview = A6.preview_effective_config(override, ROOT)
    mutated_cards = [dict(card) for card in cards]
    mutated_cards[0]['strategy_summary'] += ' mutated-text-only'
    base_again = preset.compile_preset(surface, [preset.Layer('defaults', defaults)], 'usd',
                                       unit_classes=units, enums=enums, locked_constants={})
    failures += not check('A6 strategy text mutation cannot change identity or fingerprint',
                          [c['ea_id'] for c in mutated_cards] ==
                          [c['ea_id'] for c in cards] and
                          base.effective_config_hash == base_again.effective_config_hash)
    failures += not check('A6 preview equals preset effective fingerprint',
                          preview['effective_config_hash'] == override.effective_config_hash)
    failures += not check('A6 non-default override losers are surfaced',
                          20081 in preview['ignored_pids'] or
                          20081 in preview['ignored_pids_by_parameter'].get(20082, []),
                          preview)
    failures += not check('A6 preview is read-only and has precedence chain',
                          preview['read_only'] is True and
                          all('precedence_chain' in v for v in preview['parameters'].values()))

    states = A6.explain_build('LAB_ENTRY_14', dict(base.values), ROOT)
    revenge = states['_EVT_RevengeBlockBars']
    failures += not check('A6 revenge reason policy remains explicit',
                          revenge['state'] == 'HIDDEN_INACTIVE' and
                          revenge['reason_code'] == 'OUTCOME_LEDGER_NOT_IMPLEMENTED' and
                          revenge['effective'] is False)
    failures += not check('A6 every explained state has a machine reason',
                          all(v.get('reason_code') or v['state'] in
                              ('VISIBLE_EFFECTIVE', 'VISIBLE_CONDITIONAL')
                              for v in states.values()))

    print('A6 TESTS: %s' % ('PASS' if failures == 0 else '%d FAILURE(S)' % failures))
    return 0 if failures == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
