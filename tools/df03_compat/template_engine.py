"""B21 source-bound integration transform. Raw compatibility control is never written."""
import argparse
import json
import re
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate as g

SUFFIXES = ('Lot1', 'Lot2', 'Lot3', 'Lot4', 'Lot5', 'PullBack', 'NearbyPip',
            'CloseAllPercent', 'Timeframe', 'HedgingMode', 'TPPip', 'SLPip',
            'MagicStart', 'CandleFindBy')
SEND = b'ticket = EEFD::OrderSend(symbol, type, lots, op, (int)(slippage * PipValue(symbol)), sl, tp, comment, magic, expiration, arrowcolor);'
HOOK = (b'// B21: retry from native lots; never compound the macro reduction.\n'
        b'\t\tdouble df03_safe_lots = lots;\n'
        b'\t\tif (!DF03_B21NewOrder(symbol, magic, type, df03_safe_lots)) return -1;\n\t\t')
TIMER_TICK_HOOK = b'if (DF03_B21PreTick()) DF03_SourceOnTick();'


def function_span(data, name):
    """Locate a unique function definition with byte offsets, ignoring trivia."""
    ts = g.tokens(data)
    found = []
    for i, token in enumerate(ts[:-1]):
        if token[0] != name.encode() or ts[i+1][0] != b'(':
            continue
        depth, j = 1, i + 2
        while j < len(ts) and depth:
            depth += (ts[j][0] == b'(') - (ts[j][0] == b')')
            j += 1
        if j >= len(ts) or ts[j][0] != b'{':
            continue
        opening, depth, k = j, 1, j + 1
        while k < len(ts) and depth:
            if ts[k][3] == 'punct':
                depth += (ts[k][0] == b'{') - (ts[k][0] == b'}')
            k += 1
        g.require(depth == 0, 'unbalanced function: ' + name)
        found.append((ts[opening][1], ts[k-1][2]))
    g.require(len(found) == 1, 'ambiguous/missing function: ' + name)
    return found[0]


def send_patches(raw):
    """Only the pinned native open helper may contain the one qualified send.

    Build pins parent bytes before this structural selection. Never search by
    newline spelling or hook the lower EEFD dispatcher shared with risk exits.
    """
    for name, direction in (('BuyNow', 'OP_BUY'), ('SellNow', 'OP_SELL')):
        start, end = function_span(raw, name)
        expected = ('{ return OrderCreate(symbol, ' + direction +
                    ', lots, 0, sll, tpl, slp, tpp, slippage, magic, comment, arrowcolor, expiration); }')
        g.require(g.code(raw[start:end]) == g.code(expected.encode()),
                  'native open forwarding drift: ' + name)
    start, end = function_span(raw, 'OrderCreate')
    ts = g.tokens(raw)
    values = [t[0] for t in ts]
    qualified = [i for i in range(len(ts)-3)
                 if values[i:i+4] == [b'EEFD', b'::', b'OrderSend', b'(']]
    g.require(len(qualified) == 1, 'ambiguous/missing native send seam')
    i = qualified[0] - 2
    expected = [t[0] for t in g.tokens(SEND)]
    g.require(i >= 0 and values[i:i+len(expected)] == expected,
              'native send argument drift')
    g.require(start < ts[i][1] < ts[i+len(expected)-1][2] < end,
              'native send outside OrderCreate')
    # Insert the guard and replace only the third argument. All remaining
    # original bytes (including mixed line endings) survive inverse restoration.
    lot = ts[i+10]
    g.require(lot[0] == b'lots', 'native lot argument drift')
    return [(ts[i][1], ts[i][1], HOOK),
            (lot[1], lot[2], b'df03_safe_lots')]


def timer_tick_patches(raw):
    """Guard only the pinned offline timer's nested native-tick delegate."""
    start, end = function_span(raw, 'DF03_SourceOnTimer')
    ts = [t for t in g.tokens(raw) if start <= t[1] and t[2] <= end]
    values = [t[0] for t in ts]
    nested_calls = [i for i in range(len(ts) - 3)
                    if values[i:i+4] ==
                    [b'DF03_SourceOnTick', b'(', b')', b';']]
    g.require(len(nested_calls) == 1,
              'ambiguous/missing timer tick seam')
    expected = [t[0] for t in g.tokens(
        b'if (FXD_CHART_IS_OFFLINE && EEFD::RefreshRates()) {'
        b'DF03_SourceOnTick();}')]
    matches = [i for i in range(len(ts) - len(expected) + 1)
               if values[i:i+len(expected)] == expected]
    g.require(len(matches) == 1, 'ambiguous/missing timer tick seam')
    i = matches[0]
    call = i + expected.index(b'DF03_SourceOnTick')
    semi = call + 3
    g.require(values[call:semi+1] ==
              [b'DF03_SourceOnTick', b'(', b')', b';'],
              'timer tick seam call drift')
    return [(ts[call][1], ts[semi][2], TIMER_TICK_HOOK)]


def build(parent):
    raw, compat = g.build(parent)
    patches = []
    inputs = compat['causal']['inputs']
    g.require(len(inputs) == len(SUFFIXES), '14 inputs required')
    mappings = []
    for i, (text, suffix) in enumerate(zip(inputs, SUFFIXES)):
        match = re.fullmatch(r'input (\w+) (\w+) = (.+) ;', text)
        g.require(match is not None, 'input syntax drift')
        decl = dict(type=match[1], name=match[2], default=match[3])
        name = decl['name']
        target = '_21_DF03_' + suffix
        pattern = rb'(?m)^input [^\r\n;]+\b' + name.encode() + rb'\s*=[^;]+;'
        matches = list(re.finditer(pattern, raw))
        g.require(len(matches) == 1, 'input declaration drift: ' + name)
        m = matches[0]
        patches.append((m.start(), m.end(), b''))
        # Preserve source c/v/_externs member names and all causal blocks. Only
        # the input-to-native-state binding changes, not similarly named members.
        owner = '_externs' if i == 13 else 'c'
        binding = (owner + '::' + name + ' = ' + name + ';').encode()
        g.require(raw.count(binding) == 1, 'input binding drift: ' + name)
        start = raw.index(binding) + len((owner + '::' + name + ' = ').encode())
        patches.append((start, start + len(name), target.encode()))
        mappings.append(dict(decl, target=target, pid=12100+i))
    # The frozen source also reads the global MagicStart directly in both
    # market-block send calls and the native group-membership helper. The
    # c::MagicStart member and its declaration remain untouched.
    ts = g.tokens(raw)
    extra_magic = []
    for i, (value, start, end, kind) in enumerate(ts):
        if value != b'MagicStart' or ts[i-1][0] in (b'::', b'int'):
            continue
        if any(a <= start < b for a, b, _ in patches):
            continue
        extra_magic.append((start, end, b'_21_DF03_MagicStart'))
    g.require(len(extra_magic) == 4, 'global magic reference drift')
    patches.extend(extra_magic)
    patches.extend(timer_tick_patches(raw))
    patches.extend(send_patches(raw))
    chunks, records, cursor, offset = [], [], 0, 0
    for start, end, replacement in sorted(patches):
        g.require(start >= cursor, 'overlapping transforms')
        chunks.extend((raw[cursor:start], replacement))
        records.append(dict(offset=start+offset, old=raw[start:end].decode(), new=replacement.decode()))
        offset += len(replacement) - (end-start)
        cursor = end
    chunks.append(raw[cursor:])
    engine = b''.join(chunks)
    manifest = dict(schema='df03-template/1', parent_sha256=g.sha(parent),
                    raw_sha256=g.sha(raw), engine_sha256=g.sha(engine),
                    mappings=mappings, patches=records, compatibility_changes=compat['changes'])
    g.require(restore(engine, manifest) == parent, 'inverse reconstruction failed')
    return engine, manifest


def restore(engine, manifest):
    result = engine
    for patch in reversed(manifest['patches']):
        at, old, new = patch['offset'], patch['old'].encode(), patch['new'].encode()
        g.require(result[at:at+len(new)] == new, 'template patch drift')
        result = result[:at] + old + result[at+len(new):]
    g.require(g.sha(result) == manifest['raw_sha256'], 'raw reconstruction drift')
    parent = g.inverse(result, manifest['compatibility_changes'])
    g.require(g.sha(parent) == g.PARENT_SHA256, 'parent reconstruction drift')
    return parent


def verify(parent, engine, manifest):
    expected, records = build(parent)
    g.require(engine == expected and manifest == records, 'template dependency drift')
    g.require(restore(engine, manifest) == parent, 'parent bytes differ')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    engine, manifest = build(g.PARENT.read_bytes())
    outputs = {'DF03_TemplateEngine.mqh': engine,
               'template_manifest.json': (json.dumps(manifest, indent=2)+'\n').encode()}
    for name, data in outputs.items():
        path = g.DEST / name
        if args.check:
            g.require(path.read_bytes() == data, 'output drift: ' + name)
        else:
            path.write_bytes(data)
    print(json.dumps({k: manifest[k] for k in ('parent_sha256', 'raw_sha256', 'engine_sha256')}))
