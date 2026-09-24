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

RAW_SHA256 = '564099a9e48abffcfbeceb43b3558f9212ece603309eaf15e6947834aa957115'
# RCA inventory at canonical 1df924b1. The native-send hook inserts three lines
# before the final magic site; raw_line records that distinction explicitly.
WARNING_SPECS = (
    *((line, 'v::' + name, 'formula(compare, lo, ro)', 'int')
      for line, name in zip((1838,1873,1908,1943,1978,2013,2048,2083,2488,2523),
                            ('B1','B2','B3','B4','S1','S2','S3','S4','S5','B5'))),
    (4570, 'ObjPrice1.ModeCandleFindBy', 'c::Timeframe', 'string'),
    *((base+i-1, 'v::' + side + str(i), '_Value' + str(i) + '_()', 'int')
      for base, side in ((7031, 'S'), (7070, 'B')) for i in range(1, 6)),
    (11083, 'magic_number', 'EEFD::OrderMagicNumber()', 'int'),
    (11627, 'int ticket_oco',
     'EEFD::StrToInteger(EEFD::StringSubstr(EEFD::OrderComment(), 5, StringLen(EEFD::OrderComment())-1))', 'int'),
    (13756, 'int M', 'EEFD::OrderMagicNumber()', 'int'),
)


def warning_sites(raw):
    """Pin context and uniquely select whole RHS expressions, never operands.

    The raw hash binds all types, overloads, storage, callers and consumers.
    Exact statements/line locations additionally bind the approved RCA sites.
    No arithmetic, evaluation count, signedness or range policy is changed.
    """
    g.require(g.sha(raw) == RAW_SHA256, 'warning conversion raw/context drift')
    lines = raw.splitlines(keepends=True)
    sites = []
    for line, lhs, expression, cast in WARNING_SPECS:
        raw_line = line - 3 if line == 13756 else line
        statement = lines[raw_line-1]
        expected = (lhs + ' = ' + expression + ';').encode()
        g.require(g.code(statement) == g.code(expected), 'warning statement drift')
        # Whitespace aside, the complete assignment must occur exactly once.
        pattern = rb'\s*'.join(re.escape(t[0]) for t in g.tokens(expected))
        g.require(len(list(re.finditer(pattern, raw))) == 1,
                  'ambiguous/missing warning assignment')
        old = expression.encode()
        g.require(statement.count(old) == 1, 'warning expression drift')
        start = sum(map(len, lines[:raw_line-1])) + statement.index(old)
        sites.append(dict(line=line, raw_line=raw_line, lhs=lhs, cast=cast, raw_offset=start,
                          old=expression, new='(' + cast + ')(' + expression + ')'))
    g.require(len(sites) == 24, '24 conversion sites required')
    return sites


def fixture_region(raw):
    """Extract only pure conversion dependencies; no strategy/trade include.

    Market identity/comment providers are deliberately replaced with counted
    injected values. The actual assignments, double formula, parsing wrappers,
    reset value getter and string selector predicate remain source-bound.
    """
    sites = warning_sites(raw)
    out = ['// BEGIN SOURCE-BOUND CONVERSIONS',
           '// Raw SHA256: ' + g.sha(raw),
           'class v { public: static int B1,B2,B3,B4,B5,S1,S2,S3,S4,S5; };',
           'class c { public: static ENUM_TIMEFRAMES Timeframe; };',
           # MQL5 class statics need definitions shared by both fixture arms.
           *(f'int v::{side}{i} = 0;' for side in ('B', 'S') for i in range(1, 6)),
           'ENUM_TIMEFRAMES c::Timeframe = PERIOD_CURRENT;',
           'struct PriceSelector { string ModeCandleFindBy; };',
           'PriceSelector ObjPrice1;',
           'int identity_calls=0, comment_calls=0, value_calls=0;',
           'long injected_magic=0; string injected_comment="";']
    # Generic overload is the actual double/double path used by all ten sites.
    formula = re.search(rb'template<typename DT1, typename DT2>\r?\n'
                        rb'double formula\(string sign, DT1 v1, DT2 v2\)\r?\n'
                        rb'\{.*?\r?\n\}', raw, re.S)
    g.require(formula is not None, 'fixture formula dependency missing')
    out.append(formula[0].decode())
    out.append('class EEFD { public:')
    for name, signature in (
        ('StrToInteger', 'static long StrToInteger(string value)'),
        ('StringSubstr', 'static string StringSubstr(const string string_value, int start_pos, int length = 0)'),
    ):
        a, b = function_span(raw, name)
        out.append(signature + raw[a:b].decode())
    out.extend(['static long OrderMagicNumber(){ identity_calls++; return injected_magic; }',
                'static string OrderComment(){ comment_calls++; return injected_comment; }', '};'])
    value_class = re.search(rb'class MDLIC_value_value\r?\n\{.*?\r?\n\};', raw, re.S)
    g.require(value_class is not None, 'fixture reset dependency missing')
    out.append(value_class[0].decode())
    out.append('MDLIC_value_value Value1,Value2,Value3,Value4,Value5;')
    for i in range(1, 6):
        getter = f'double _Value{i}_() {{return Value{i}._execute_();}}'
        g.require(getter.encode() in raw, 'fixture getter drift')
        # Count calls without changing the called source getter/expression.
        out.append(getter.replace('{return', '{value_calls++; return'))
    out.append('void SourceInitialState(){')
    for side in ('B', 'S'):
        for i in range(1, 6):
            statement = f'v::{side}{i} = {i};'
            g.require(raw.count(statement.encode()) == 1, 'initial state drift')
            out.append(statement)
    out.append('}')
    for index, site in enumerate(sites):
        lhs, old, new = site['lhs'], site['old'], site['new']
        statement = raw.splitlines()[site['raw_line']-1].strip().decode()
        result = lhs.removeprefix('int ')
        params = 'string compare, double lo, double ro' if index < 10 else ''
        out.append(f'// RCA {site["line"]}; raw RHS offset {site["raw_offset"]}')
        out.append(f'{site["cast"]} Site{index}({params})' + '{')
        if lhs == 'magic_number':
            out.append('int magic_number;')
        out.extend(['#ifdef DF03_IMPLICIT_ORACLE',
                    '// TEST CONTROL ONLY: original implicit conversion warning expected.',
                    statement, '#else', statement.replace(old, new, 1), '#endif',
                    f'return {result};', '}'])
    for name, indices, params, args in (
        ('FormulaSite', range(10), 'string compare, double lo, double ro', 'compare,lo,ro'),
        ('ResetSite', range(11,21), '', ''),
        ('MagicSite', (21,23), '', ''),
    ):
        out.append('int ' + name + '(int site' + (', '+params if params else '') + '){')
        for i in indices:
            out.append(f'if(site=={i}) return Site{i}({args});')
        out.append('return 0; }')
    out.append('int FormulaInitial(int site){')
    for i, site in enumerate(sites[:10]):
        out.append(f'if(site=={i}) return {site["lhs"]};')
    out.append('return 0; }')
    predicate = 'ModeCandleFindBy == "time"'
    g.require(raw.count(predicate.encode()) == 1, 'time branch dependency drift')
    out.append('bool TimeBranch(string ModeCandleFindBy){ return ' + predicate + '; }')
    out.append('// END SOURCE-BOUND CONVERSIONS')
    return ('\n'.join(out) + '\n').encode()


def fixture_bytes(raw):
    fixture = g.ROOT / 'ea_template/tests/DF03_ConversionCompat_Test.mq5'
    data = fixture.read_bytes()
    a = data.index(b'// BEGIN SOURCE-BOUND CONVERSIONS')
    b = data.index(b'// END SOURCE-BOUND CONVERSIONS') + len(b'// END SOURCE-BOUND CONVERSIONS')
    return data[:a] + fixture_region(raw).rstrip(b'\n') + data[b:]


def fixture_keys():
    keys = {f'formula:{s}:{op}:{i}' for s in range(10) for op in range(4) for i in range(26)}
    keys |= {f'reset:{s}:{i}' for s in range(11,21) for i in range(26)}
    keys |= {f'initial:{i}' for i in range(10)}
    keys |= {f'native-reset:{s}' for s in range(11,21)}
    keys |= {f'repeat:{s}:{edge}:{n}' for s in range(10) for edge in range(2) for n in range(8)}
    keys |= {f'magic:{s}:{i}' for s in (21,23) for i in range(16)}
    keys |= {f'comment:{i}' for i in range(22)}
    keys |= {f'timeframe:{i}' for i in range(22)}
    return keys


def compare_fixture_logs(implicit, explicit):
    """Strict row equality, not a Python emulation of MQL conversions."""
    parsed = []
    for text, arm in ((implicit, 'IMPLICIT_TEST_CONTROL'), (explicit, 'EXPLICIT')):
        rows, markers = {}, {'ARM': [], 'RUNTIME': [], 'DONE': []}
        for line in text.splitlines():
            marker = re.search(r'DF03_(?:ROW|ARM|RUNTIME|DONE)\|', line)
            if marker is None:
                continue
            message = line[marker.start():].strip()
            parts = message.split('|')
            if parts[0] == 'DF03_ROW':
                g.require(len(parts) == 3 and parts[1] not in rows and parts[2],
                          'duplicate/malformed fixture row')
                rows[parts[1]] = parts[2]
            else:
                key = parts[0].removeprefix('DF03_')
                g.require(key in markers and len(parts) == 2, 'unexpected fixture marker')
                markers[key].append(parts[1])
        g.require(markers['ARM'] == [arm], 'fixture arm identity mismatch')
        g.require(len(markers['RUNTIME']) == 1 and markers['RUNTIME'][0].isdigit(),
                  'missing/ambiguous runtime build')
        g.require(set(rows) == fixture_keys(), 'incomplete/unexpected fixture domain')
        g.require(markers['DONE'] == [str(len(rows))], 'incomplete/duplicate fixture completion')
        parsed.append((rows, markers['RUNTIME'][0]))
    g.require(parsed[0][1] == parsed[1][1], 'runtime identity differs')
    differences = [key for key in sorted(fixture_keys()) if parsed[0][0][key] != parsed[1][0][key]]
    g.require(not differences, 'BLOCK conversion differences: ' + ','.join(differences[:12]))
    return dict(status='DIFFERENTIAL_ROWS_EQUAL_ONLY', rows=len(parsed[0][0]),
                runtime_build=int(parsed[0][1]), production_acceptance=False)


def prepare_fixture(destination):
    """Copy genuine local include closure and two test arms to a NEW external dir.

    This does not compile, stage in Git, deploy, reserve or launch anything.
    System includes remain an explicit Stage B installation-binding dependency.
    """
    destination = Path(destination).resolve()
    g.require(not destination.is_relative_to(g.ROOT.resolve()), 'external evidence directory required')
    g.require(not destination.exists(), 'refuse existing evidence destination')
    parent = g.PARENT.read_bytes()
    engine, manifest = build(parent)
    g.require((g.DEST/'DF03_TemplateEngine.mqh').read_bytes() == engine, 'engine output drift')
    g.require(json.loads((g.DEST/'template_manifest.json').read_bytes()) == manifest, 'manifest drift')
    raw = (g.DEST/'DF03_Generated.mqh').read_bytes()
    fixture = fixture_bytes(raw)
    fixture_rel = 'ea_template/tests/DF03_ConversionCompat_Test.mq5'
    g.require((g.ROOT/fixture_rel).read_bytes() == fixture, 'fixture output drift')
    files, system = {}, set()
    def visit(rel):
        if rel in files:
            return
        path = (g.ROOT/rel).resolve()
        g.require(path.is_relative_to(g.ROOT.resolve()), 'include traversal')
        data = path.read_bytes()
        files[rel] = data
        for bracket, name in re.findall(rb'^\s*#include\s*(["<])([^">]+)[">]', data, re.M):
            name = name.decode().replace('\\', '/')
            if bracket == b'<':
                system.add(name)
            else:
                child = (path.parent/name).resolve()
                g.require(child.is_relative_to(g.ROOT.resolve()), 'include traversal')
                visit(child.relative_to(g.ROOT.resolve()).as_posix())
    for rel in ('ea_template/Boss_21_GridFibo.mq5', 'ea_template/tests/GridFibo_B21_Test.mq5', fixture_rel):
        visit(rel)
    for rel in ('tools/df03_compat/template_engine.py', 'tools/df03_compat/generate.py',
                'tools/df03_compat/test_b21.py', 'ea_template/compat/df03/parent.mq5',
                'ea_template/compat/df03/DF03_Generated.mqh', 'ea_template/compat/df03/manifest.json',
                'ea_template/compat/df03/template_manifest.json',
                'scripts/_test/run_df03_conversion_compat_tests.ps1'):
        files[rel] = (g.ROOT/rel).read_bytes()
    implicit_rel = 'ea_template/tests/DF03_ConversionCompat_Implicit_Test.mq5'
    files[implicit_rel] = b'#define DF03_IMPLICIT_ORACLE // TEST CONTROL ONLY\n' + fixture
    oracle_warnings = []
    oracle_lines = files[implicit_rel].decode().splitlines()
    for index, site in enumerate(warning_sites(raw)):
        statement = raw.splitlines()[site['raw_line']-1].strip().decode()
        matches = [n+1 for n, line in enumerate(oracle_lines) if line.strip() == statement]
        g.require(len(matches) == 1, 'oracle warning source ambiguity')
        kind = 'ENUM_TIMEFRAMES' if index == 10 else ('long' if index >= 21 else 'double')
        message = ("implicit conversion from 'ENUM_TIMEFRAMES' to 'string'" if index == 10 else
                   "possible loss of data due to type conversion from '" + kind + "' to 'int'")
        oracle_warnings.append(dict(line=matches[0], code=94 if index == 10 else 43, message=message))
    destination.mkdir(parents=True)
    for rel, data in files.items():
        path = destination/'source'/rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    receipt = dict(schema='df03-conversion-fixture/1', stage='A_PREPARED_NO_COMPILER_NO_RUNTIME',
                   files={rel:g.sha(data) for rel,data in sorted(files.items())},
                   system_includes_require_stage_b_binding=sorted(system),
                   engine_sha256=g.sha(engine), raw_sha256=g.sha(raw), parent_sha256=g.sha(parent),
                   warning_sites=manifest['warning_conversions'], expected_rows=len(fixture_keys()),
                   oracle_warnings=oracle_warnings,
                   targets=dict(production='ea_template/Boss_21_GridFibo.mq5',
                                harness='ea_template/tests/GridFibo_B21_Test.mq5',
                                explicit=fixture_rel, implicit_test_control=implicit_rel),
                   compiler_identity=None, runtime_identity=None, acceptance=False)
    (destination/'fixture_manifest.json').write_text(json.dumps(receipt, indent=2)+'\n', encoding='utf-8')
    return receipt


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
    conversions = warning_sites(raw)
    patches.extend((s['raw_offset'], s['raw_offset'] + len(s['old']), s['new'].encode())
                   for s in conversions)
    by_offset = {s['raw_offset']: s for s in conversions}
    chunks, records, cursor, offset = [], [], 0, 0
    for start, end, replacement in sorted(patches):
        g.require(start >= cursor, 'overlapping transforms')
        chunks.extend((raw[cursor:start], replacement))
        records.append(dict(offset=start+offset, old=raw[start:end].decode(), new=replacement.decode()))
        if start in by_offset:
            by_offset[start]['engine_offset'] = start + offset
        offset += len(replacement) - (end-start)
        cursor = end
    chunks.append(raw[cursor:])
    engine = b''.join(chunks)
    manifest = dict(schema='df03-template/1', parent_sha256=g.sha(parent),
                    raw_sha256=g.sha(raw), engine_sha256=g.sha(engine),
                    mappings=mappings, patches=records, compatibility_changes=compat['changes'],
                    warning_conversions=conversions,
                    generator_sha256=g.sha(Path(__file__).read_bytes()))
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
    parser.add_argument('--prepare-fixture', type=Path)
    parser.add_argument('--compare-fixture', nargs=2, metavar=('IMPLICIT_LOG', 'EXPLICIT_LOG'))
    args = parser.parse_args()
    g.require(sum((args.check, bool(args.prepare_fixture), bool(args.compare_fixture))) <= 1,
              'choose one operation')
    if args.prepare_fixture:
        receipt = prepare_fixture(args.prepare_fixture)
        print(json.dumps(dict(status=receipt['stage'], files=len(receipt['files']), rows=receipt['expected_rows'])))
        sys.exit(0)
    if args.compare_fixture:
        def log_text(path):
            data = Path(path).read_bytes()
            return data.decode('utf-16' if data.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
        print(json.dumps(compare_fixture_logs(*(log_text(p) for p in args.compare_fixture))))
        sys.exit(0)
    engine, manifest = build(g.PARENT.read_bytes())
    outputs = {'DF03_TemplateEngine.mqh': engine,
               'template_manifest.json': (json.dumps(manifest, indent=2)+'\n').encode()}
    for name, data in outputs.items():
        path = g.DEST / name
        if args.check:
            g.require(path.read_bytes() == data, 'output drift: ' + name)
        else:
            path.write_bytes(data)
    fixture = g.ROOT / 'ea_template/tests/DF03_ConversionCompat_Test.mq5'
    expected_fixture = fixture_bytes(g.build(g.PARENT.read_bytes())[0])
    if args.check:
        g.require(fixture.read_bytes() == expected_fixture, 'conversion fixture drift')
    else:
        fixture.write_bytes(expected_fixture)
    print(json.dumps({k: manifest[k] for k in ('parent_sha256', 'raw_sha256', 'engine_sha256')}))
