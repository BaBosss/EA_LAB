# -*- coding: utf-8 -*-
"""A6 human metadata builder over the accepted registry/activation truth."""
import csv
import io
import json
import os
import re
import sys
from collections import OrderedDict

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import activation  # noqa: E402
import preset  # noqa: E402
import registry  # noqa: E402
import strategy_catalog  # noqa: E402

PARAM_REL = 'docs/PARAM_REGISTRY.csv'
DISPLAY_REL = 'factory/parameter_display_metadata.jsonl'
CATALOG_REL = 'factory/strategy_catalog.json'
INPUTS_REL = 'ea_template/core/Inputs.mqh'
PORTABILITY_VALUES = (
    'PORTABLE', 'SYMBOL_PROFILE_DEPENDENT', 'ACCOUNT_PROFILE_DEPENDENT',
    'BROKER_POINT_DEPENDENT', 'NOT_APPLICABLE',
)
EXTRA_HEADERS = ('unit_true', 'portability', 'display_label', 'relation_hint')
CARD_FIELDS = strategy_catalog.CARD_FIELDS


class A6Refusal(Exception):
    pass


def _root(root=None):
    return os.path.abspath(root or os.path.join(HERE, '..', '..'))


def _bare(name):
    return re.sub(r'\[LAB_ENTRY_\d+\]$', '', name)


def _rows(root):
    return registry.read_parameter_registry(root=root)


def _logical_rows(root):
    """The human metadata projection deliberately omits physical-only identities."""
    return [row for row in _rows(root)
            if row.get('classification', '').strip().upper() != 'COMPATIBILITY']


def _portability(unit, context):
    u = unit.strip().lower()
    if not u:
        raise A6Refusal('empty unit cannot receive a portability classification')
    if any(x in u for x in ('money', 'usd', '% of current balance', '% of balance',
                            'account currency', 'account dd', 'equity dd')):
        return 'ACCOUNT_PROFILE_DEPENDENT'
    if any(x in u for x in ('pip', 'point', 'spread')):
        return 'BROKER_POINT_DEPENDENT'
    if u in ('timeframe', 'filename (csv)') or 'chart tf' in u:
        return 'SYMBOL_PROFILE_DEPENDENT' if u != 'filename (csv)' else 'NOT_APPLICABLE'
    if 'atr' in u:
        return 'SYMBOL_PROFILE_DEPENDENT'
    if u in ('integer (magic number)',):
        return 'NOT_APPLICABLE'
    if context.strip().lower() == 'runtime' and 'magic' in u:
        return 'NOT_APPLICABLE'
    # All remaining units are dimensionless, bar/count, enum, boolean, or time controls.
    # Their numeric meaning is stable across symbol/account profiles.
    return 'PORTABLE'


def _label(name):
    special = {
        'MID_LOW': 'Middle low', 'MID_HIGH': 'Middle high',
        'MIN_CHANNEL_ATR': 'Min channel ATR', 'MIN_LINE_WEIGHT': 'Min line weight',
        'UseMiddlePathVeto': 'Middle Path veto',
    }
    base = _bare(name)
    if base in special:
        return special[base]
    base = re.sub(r'^_+', '', base)
    base = re.sub(r'^\d+_', '', base)
    base = re.sub(r'([a-z])([A-Z])', r'\1 \2', base)
    base = base.replace('_', ' ')
    return base.strip() or 'Parameter'


def _known_names(rows):
    return {_bare(r['name']) for r in rows}


def _targets(row, names):
    text = '%s %s' % (row.get('coupled_parameters', ''), row.get('classification_note', ''))
    found = []
    for name in sorted(names, key=len, reverse=True):
        if name == _bare(row['name']):
            continue
        if re.search(r'(?<![A-Za-z0-9_])' + re.escape(name) + r'(?![A-Za-z0-9_])', text):
            found.append(name)
    return tuple(dict.fromkeys(found))


def load_parameter_metadata(root=None):
    root = _root(root)
    raw = _logical_rows(root)
    names = _known_names(raw)
    out = OrderedDict()
    for row in raw:
        key = _bare(row['name'])
        unit = row.get('unit_true') or row.get('unit') or ''
        portability = row.get('portability') or _portability(unit, row.get('context', ''))
        if portability not in PORTABILITY_VALUES:
            raise A6Refusal('%s has invalid portability %r' % (key, portability))
        item = OrderedDict([
            ('parameter', key),
            ('parameter_pid', int(row['parameter_pid'])),
            ('unit_true', unit.strip()),
            ('portability', portability),
            ('display_label', row.get('display_label') or _label(key)),
        ])
        targets = _targets(row, names)
        item['relations'] = tuple(OrderedDict([('kind', 'COUPLED_WITH'),
                                                ('target', t)]) for t in targets)
        item['relation_hint'] = row.get('relation_hint') or (
            ('with P%05d' % next(int(x['parameter_pid']) for x in raw if _bare(x['name']) == targets[0]))
            if targets else '')
        if key not in out:
            out[key] = item
        elif (out[key]['parameter_pid'], out[key]['unit_true'], out[key]['portability']) != \
                (item['parameter_pid'], item['unit_true'], item['portability']):
            raise A6Refusal('tagged registry rows disagree for %s' % key)
    if len(out) != 196:
        raise A6Refusal('expected 196 logical metadata rows, got %d' % len(out))
    for item in out.values():
        text = '[P%05d] %s' % (item['parameter_pid'], item['display_label'])
        if item['relation_hint']:
            text += ' | ' + item['relation_hint']
        if len(text) > 63:
            # Keep the PID and relation hint; trim only the human label.
            suffix = (' | ' + item['relation_hint']) if item['relation_hint'] else ''
            room = 63 - len('[P%05d] ' % item['parameter_pid']) - len(suffix)
            if room < 1:
                raise A6Refusal('%s cannot fit its PID/relation hint in 63 characters' % item['parameter'])
            item['display_label'] = item['display_label'][:room].rstrip()
    return out


def load_strategy_cards(root=None):
    path = os.path.join(_root(root), CATALOG_REL.replace('/', os.sep))
    if os.path.isfile(path):
        value = json.load(io.open(path, encoding='utf-8'))
        return strategy_catalog.validate(value)
    return strategy_catalog.validate()


def memory_aid(card):
    return strategy_catalog.memory_aid(card)


def display_comments(root=None):
    return dict((k, '[P%05d] %s%s' % (
        v['parameter_pid'], v['display_label'],
        (' | ' + v['relation_hint']) if v['relation_hint'] else ''))
                for k, v in load_parameter_metadata(root).items())


def relation_hints_resolve(rows):
    pids = {r['parameter_pid'] for r in rows}
    for row in rows:
        hint = row.get('relation_hint', '')
        if hint:
            for pid in re.findall(r'P(\d{5})', hint):
                if int(pid) not in pids:
                    return False
        if any(rel['target'] not in {r['parameter'] for r in rows} for rel in row['relations']):
            return False
    return True


def _metadata_by_pid(root):
    return dict((v['parameter_pid'], v) for v in load_parameter_metadata(root).values())


def _pid_for(name, root, build_tag=None):
    return registry.parameter_pid_for(name, build_tag=build_tag, root=root)


def explain_build(build_tag, config, root=None):
    root = _root(root)
    metadata = load_parameter_metadata(root)
    if build_tag in activation.TABLE:
        # The accepted A5 logical surface deliberately excludes the legacy SMC/5B declarations;
        # use its own table domain so those excluded keys cannot become accidental UI truth.
        states = activation.effective_state(build_tag, config)
    else:
        # A6 does not invent an activation table for builds A5 does not own. The
        # registry's permanent classification is the existing resolver truth.
        states = {}
        rows = _rows(root)
        for name, item in metadata.items():
            row = next((r for r in rows if _bare(r['name']) == name), None)
            inactive = (row or {}).get('classification') in ('INACTIVE', 'COMPATIBILITY')
            states[name] = {
                'name': name, 'state': 'HIDDEN_INACTIVE' if inactive else 'VISIBLE_EFFECTIVE',
                'effective': not inactive, 'reason_code':
                'REGISTRY_INACTIVE' if inactive else None,
                'reason': 'registry classification', 'token': None,
                'gate': ('NEVER', 'REGISTRY_INACTIVE') if inactive else ('ALWAYS',),
                'gate_dependencies': (), 'relations': item['relations'],
            }
    out = {}
    for name, state in states.items():
        item = metadata.get(_bare(name))
        if item is None:
            continue
        deps = tuple(state.get('gate_dependencies', ()))
        out[name] = dict(state)
        if out[name].get('state') == 'ACTIVE':
            out[name]['state'] = 'VISIBLE_EFFECTIVE'
        out[name].update({
            'parameter_pid': item['parameter_pid'],
            'reason_short': state.get('reason_code') or
                           ('effective' if state.get('effective') else 'gate closed'),
            'gate_pid': (_pid_for(deps[0], build_tag=build_tag, root=root)
                         if deps else None),
            'overriding_pid': None,
            'unit_true': item['unit_true'],
            'portability': item['portability'],
        })
    return out


def _override_targets(row, names):
    text = '%s %s' % (row.get('coupled_parameters', ''), row.get('classification_note', ''))
    if not re.search(r'override|overrides|supersedes|superseded', text, re.I):
        return ()
    return _targets(row, names)


def preview_effective_config(preset_value, root=None):
    root = _root(root)
    raw = _rows(root)
    names = {_bare(r['name']) for r in raw}
    by_name = {}
    for row in raw:
        by_name.setdefault(_bare(row['name']), row)
    pid = dict((name, int(row['parameter_pid'])) for name, row in by_name.items())
    overrides = dict((name, _override_targets(row, names)) for name, row in by_name.items())
    ignored = []
    ignored_by = {}
    params = {}
    for name, value in preset_value.values.items():
        base = _bare(name)
        own_pid = pid.get(base)
        provenance = preset_value.provenance.get(name, {'layer': None, 'overridden': []})
        losers = []
        for target in overrides.get(base, ()):
            target_prov = preset_value.provenance.get(target, {'layer': None})
            if provenance.get('layer') and target_prov.get('layer') and \
                    target_prov.get('layer') != provenance.get('layer'):
                losers.append(pid[target])
        ignored.extend(losers)
        if losers:
            ignored_by[own_pid] = sorted(set(losers))
        params[name] = {
            'effective_pid': own_pid,
            'effective_value': value,
            'ignored_pids': sorted(set(losers)),
            'reason': ('OVERRIDDEN_TARGET' if losers else 'PRECEDENCE_EFFECTIVE'),
            'precedence_chain': [own_pid] + sorted(set(losers)),
        }
    return {
        'read_only': True,
        'effective_config_hash': preset_value.effective_config_hash,
        'parameters': params,
        'ignored_pids': sorted(set(ignored)),
        'ignored_pids_by_parameter': ignored_by,
    }


def _render_registry(root, metadata):
    path = os.path.join(root, PARAM_REL.replace('/', os.sep))
    raw_lines = io.open(path, encoding='utf-8-sig').read().splitlines()
    prefix = [line for line in raw_lines if not line.strip() or line.startswith('>')]
    data = [line for line in raw_lines if line.strip() and not line.startswith('>')]
    rows = list(csv.DictReader(data))
    headers = list(rows[0]) + [h for h in EXTRA_HEADERS if h not in rows[0]]
    out = list(prefix)
    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=headers, quoting=csv.QUOTE_ALL,
                            lineterminator='\n')
    writer.writeheader()
    for row in rows:
        key = _bare(row['name'])
        item = metadata.get(key)
        if item is not None:
            row.update({
                'unit_true': item['unit_true'], 'portability': item['portability'],
                'display_label': item['display_label'], 'relation_hint': item['relation_hint'],
            })
        elif row.get('classification', '').strip().upper() != 'COMPATIBILITY':
            raise KeyError(key)
        writer.writerow(row)
    out.extend(buf.getvalue().splitlines())
    return '\n'.join(out) + '\n'


def _render_inputs(root, metadata, cards_value):
    path = os.path.join(root, INPUTS_REL.replace('/', os.sep))
    lines = io.open(path, encoding='utf-8-sig').read().splitlines()
    by_name = dict((k, v) for k, v in metadata.items())
    groups = {
        '11 Entry:': strategy_catalog.memory_aid(cards_value[0]),
        '12 Entry:': strategy_catalog.memory_aid(cards_value[1]),
        '13 Entry:': strategy_catalog.memory_aid(cards_value[2]),
        '14 Entry:': strategy_catalog.memory_aid(cards_value[3]),
        '15 Entry:': strategy_catalog.memory_aid(cards_value[4]),
        '16 Entry:': strategy_catalog.memory_aid(cards_value[5]),
        '17 Entry:': strategy_catalog.memory_aid(cards_value[6]),
        'Entry 18:': strategy_catalog.memory_aid(cards_value[7]),
    }
    out = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('input group '):
            for marker, label in groups.items():
                if marker in line:
                    line = 'input group "=== %s ==="' % label
                    break
        match = re.match(r'^(\s*)input\s+[^;]+\s+([A-Za-z_]\w*)\s*=.*?;(?:\s*//.*)?$', line)
        if match and match.group(2) in by_name:
            comment = display_comments(root)[match.group(2)]
            line = line[:line.find(';') + 1] + '   // ' + comment
        out.append(line)
    return '\n'.join(out) + '\n'


def write_outputs(root=None):
    root = _root(root)
    metadata = load_parameter_metadata(root)
    cards_value = strategy_catalog.validate()
    registry_text = _render_registry(root, metadata)
    io.open(os.path.join(root, PARAM_REL.replace('/', os.sep)), 'w',
            encoding='utf-8', newline='\n').write(registry_text)
    display_path = os.path.join(root, DISPLAY_REL.replace('/', os.sep))
    with io.open(display_path, 'w', encoding='utf-8', newline='\n') as handle:
        handle.write(json.dumps({'_comment': 'A6 generated parameter human metadata'},
                                sort_keys=True) + '\n')
        for item in metadata.values():
            handle.write(json.dumps(item, ensure_ascii=False, sort_keys=True) + '\n')
    io.open(os.path.join(root, CATALOG_REL.replace('/', os.sep)), 'w',
            encoding='utf-8', newline='\n').write(json.dumps(cards_value, ensure_ascii=False,
                                                               indent=2) + '\n')
    inputs_path = os.path.join(root, INPUTS_REL.replace('/', os.sep))
    inputs_text = _render_inputs(root, metadata, cards_value)
    with io.open(inputs_path, 'w', encoding='utf-8', newline='\n') as handle:
        handle.write(inputs_text)
    return metadata, cards_value


if __name__ == '__main__':
    if '--write' not in sys.argv[1:]:
        sys.stderr.write('usage: a6_metadata.py --write\n')
        sys.exit(2)
    root_arg = None
    if '--root' in sys.argv:
        root_arg = sys.argv[sys.argv.index('--root') + 1]
    metadata_value, cards_value = write_outputs(root_arg)
    print('wrote %d logical parameter metadata rows and %d strategy cards' %
          (len(metadata_value), len(cards_value)))
