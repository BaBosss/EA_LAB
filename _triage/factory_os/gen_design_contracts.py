"""
gen_design_contracts.py - generate the design document's NORMATIVE contract tables
from schemas.json, so the two cannot disagree.

WHY THIS EXISTS  (BACKLOG-D31)
  Every regression across three blind audits came through one seam: the normative
  contract was written by hand in TWO places - the design prose and the schema - and
  nothing bound them. Audit 3 measured the checker built to fix that (check_schema_structure.py)
  against the 7 REGRESSED findings and it would have caught 0 of 7, because it compares
  storage paths and greps banned sentences while every one of those defects was semantic.
  The proof was in the commit that installed it: design section 4.5 still described
  `attempts[]`, a lease with `pid`, and `launched_at` while the schema said the opposite,
  and the checker printed STRUCTURE OK.

  The fix audit 3 asked for, in its own words: generate the design's contract tables from
  one machine-readable manifest, and let prose carry only rationale.

THE MANIFEST IS schemas.json ITSELF.
  Deliberately NOT a new file. A separate manifest would be a third hand-maintained copy
  of the same contract - the disease, with one more host. schemas.json already carries
  `x-owner-file`, `x-writer`, `x-enforced-by`, `x-derived`, and it is already the input to
  a real Draft-2020-12 validator (run_schema_fixtures.py). One source, three consumers:
  the validator, this generator, and the design document.

WHAT IS GENERATED
  Blocks in the design delimited by
      <!-- BEGIN GENERATED CONTRACT: <key> -->  ...  <!-- END GENERATED CONTRACT: <key> -->
  Keys:
      __STORAGE__      one row per entity: owner file, writer, canonical/derived, enforcement
      <EntityName>     that entity's field table + conditional requirements
  Prose OUTSIDE the blocks is rationale and may say anything. Prose INSIDE the blocks is
  overwritten without mercy.

USAGE
  tools\\python312\\python.exe _triage/factory_os/gen_design_contracts.py           # rewrite in place
  tools\\python312\\python.exe _triage/factory_os/gen_design_contracts.py --check   # exit 1 if stale
EXIT
  0 = design matches the schema  |  1 = drift (or a malformed/missing block)
"""
import json, re, sys, difflib, io, os

SCHEMA_PATH = '_triage/factory_os/schemas.json'
DESIGN_PATH = '_triage/EA_LAB_FACTORY_OS_DESIGN.md'

BEGIN = '<!-- BEGIN GENERATED CONTRACT: {key} -->'
END = '<!-- END GENERATED CONTRACT: {key} -->'
BLOCK_RE = re.compile(
    r'<!-- BEGIN GENERATED CONTRACT: (?P<key>[A-Za-z0-9_]+) -->\r?\n'
    r'(?P<body>.*?)'
    r'<!-- END GENERATED CONTRACT: (?P=key) -->',
    re.DOTALL)

WARNING = ('<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by '
           '`_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — '
           'edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>')


# ---------------------------------------------------------------- type rendering

def render_type(spec):
    """One short, deterministic string describing what a field may hold.

    This is the part that has to be semantic. The checker this replaces compared
    storage paths; the seven regressions were all about what a field MEANS.
    """
    if not isinstance(spec, dict):
        return '`?`'
    if '$ref' in spec:
        return '[`{0}`](#{1})'.format(spec['$ref'].split('/')[-1], spec['$ref'].split('/')[-1].lower())
    if 'const' in spec:
        return 'const `{0}`'.format(spec['const'])
    if 'enum' in spec:
        return ' \\| '.join('`{0}`'.format(v) for v in spec['enum'])
    t = spec.get('type')
    if isinstance(t, list):
        return ' \\| '.join('`{0}`'.format(x) for x in t)
    if t == 'array':
        items = spec.get('items', {})
        if isinstance(items, dict) and items.get('properties'):
            return 'array of object *(fields below)*'
        return 'array of {0}'.format(render_type(items))
    if t == 'object':
        if spec.get('properties'):
            return 'object *(fields below)*'
        return '`object`'
    if t:
        return '`{0}`'.format(t)
    return '`any`'


def render_rule(spec):
    """Constraints, rendered so that changing one of them changes this text."""
    if not isinstance(spec, dict):
        return ''
    bits = []
    for key, label in (('pattern', 'pattern'), ('minLength', 'minLength'),
                       ('maxLength', 'maxLength'), ('minimum', 'min'),
                       ('maximum', 'max'), ('minItems', 'minItems'),
                       ('format', 'format'), ('multipleOf', 'multipleOf')):
        if key in spec:
            bits.append('{0} `{1}`'.format(label, spec[key]))
    if spec.get('additionalProperties') is False or spec.get('unevaluatedProperties') is False:
        bits.append('closed')
    items = spec.get('items')
    if spec.get('type') == 'array' and isinstance(items, dict) and items.get('properties'):
        if items.get('unevaluatedProperties') is False or items.get('additionalProperties') is False:
            bits.append('items closed')
        else:
            bits.append('⚠️ items OPEN')
        if items.get('required'):
            bits.append('items require ' + ', '.join('`%s`' % r for r in items['required']))
    desc = spec.get('description')
    if desc:
        bits.append(' '.join(str(desc).split()))
    return ' · '.join(bits)


def walk_fields(defn, prefix='', depth=0):
    """Flatten an object schema into (dotted_path, spec, required) rows.

    Nested objects are walked because that is where two of the audit findings lived:
    `SafeProjection.findings[].public_id` is the field that decides whether an internal
    finding id - which may embed an account, a magic or a strategy name - can reach a
    Telegram surface. A renderer that stopped at `array of object` would have printed a
    table that looked complete and said nothing about the leak.
    `$ref` is never followed: the target has its own generated table, and inlining it
    would create the second copy this whole tool exists to prevent.
    """
    rows = []
    if depth > 3:
        return rows
    required = set(defn.get('required') or [])
    for field, spec in (defn.get('properties') or {}).items():
        path = prefix + field
        rows.append((path, spec, field in required))
        if not isinstance(spec, dict) or '$ref' in spec:
            continue
        if spec.get('type') == 'object' and spec.get('properties'):
            rows.extend(walk_fields(spec, path + '.', depth + 1))
        elif spec.get('type') == 'array':
            items = spec.get('items')
            if isinstance(items, dict) and items.get('properties') and '$ref' not in items:
                rows.extend(walk_fields(items, path + '[].', depth + 1))
    return rows


# ------------------------------------------------------- conditional requirements

def render_conditionals(defn):
    """Render allOf/if-then rules as sentences.

    These carry the per-state required payloads. Audit 3's Q2 finding was that
    LAUNCH_INTENT-before-spawn and spawned-then-died are indistinguishable; whatever
    the schema does about that has to be visible in the design, or the design is
    describing a run model the schema does not implement.
    """
    out = []
    for clause in defn.get('allOf', []) or []:
        cond, then = clause.get('if'), clause.get('then')
        if not (isinstance(cond, dict) and isinstance(then, dict)):
            continue
        when = []
        for field, sub in (cond.get('properties') or {}).items():
            if 'const' in sub:
                when.append('`{0}` = `{1}`'.format(field, sub['const']))
            elif 'enum' in sub:
                when.append('`{0}` ∈ {1}'.format(field, ', '.join('`%s`' % v for v in sub['enum'])))
            else:
                when.append('`{0}` {1}'.format(field, render_type(sub)))
        req = then.get('required') or []
        eff = []
        if req:
            eff.append('requires ' + ', '.join('`%s`' % r for r in req))
        for field, sub in (then.get('properties') or {}).items():
            rule = render_rule(sub)
            eff.append('`{0}` → {1}{2}'.format(field, render_type(sub), ' (%s)' % rule if rule else ''))
        if 'not' in then:
            eff.append('is REFUSED')
        if when and eff:
            out.append('- **when {0}** → {1}'.format(' and '.join(when), ' · '.join(eff)))
    return out


# -------------------------------------------------------------- block generators

def gen_entity(name, defn):
    owner = defn.get('x-owner-file')
    derived = defn.get('x-derived')
    writer = defn.get('x-writer')
    enforced = defn.get('x-enforced-by')

    lines = [WARNING, '']
    head = ['**`{0}`**'.format(name)]
    if derived:
        head.append('**DERIVED** — {0}'.format(' '.join(str(derived).split())))
    if owner:
        head.append('stored in `{0}`'.format(owner))
    else:
        head.append('embedded — has no file of its own')
    if writer:
        head.append('written by *{0}*'.format(' '.join(str(writer).split())))
    if enforced:
        head.append('enforced by *{0}*'.format(' '.join(str(enforced).split())))
    lines.append(' · '.join(head))
    lines.append('')

    rows = walk_fields(defn)
    if rows:
        lines.append('| field | type | required | rule |')
        lines.append('|---|---|---|---|')
        for path, spec, is_req in rows:
            rule = render_rule(spec).replace('|', '\\|')
            lines.append('| `{0}` | {1} | {2} | {3} |'.format(
                path, render_type(spec), '**yes**' if is_req else '—', rule))
        lines.append('')

    closed = defn.get('unevaluatedProperties') is False or defn.get('additionalProperties') is False
    lines.append('**Unknown fields:** {0}'.format(
        'rejected (closed object).' if closed
        else '⚠️ ACCEPTED — this object is open, so a typo becomes a silently-ignored field.'))
    lines.append('')

    conds = render_conditionals(defn)
    if conds:
        lines.append('**Conditional requirements:**')
        lines.extend(conds)
        lines.append('')
    return '\n'.join(lines)


def gen_storage(schema):
    defs = schema['$defs']
    lines = [WARNING, '',
             '| entity | canonical storage | writer | enforced by |',
             '|---|---|---|---|']
    for name in defs:
        d = defs[name]
        if not isinstance(d, dict):
            continue
        owner = d.get('x-owner-file')
        derived = d.get('x-derived')
        if derived:
            store = '**derived, never written** — {0}'.format(' '.join(str(derived).split()))
        elif owner:
            store = '`{0}`'.format(owner)
        else:
            store = '*embedded in its parent — no file*'
        lines.append('| `{0}` | {1} | {2} | {3} |'.format(
            name, store.replace('|', '\\|'),
            ' '.join(str(d.get('x-writer', '—')).split()),
            ' '.join(str(d.get('x-enforced-by', '—')).split()).replace('|', '\\|')))
    lines.append('')
    return '\n'.join(lines)


def gen_meta(schema, key):
    """Non-entity contracts held under x-ea-lab-meta.contracts.<key>.

    Some normative content is not an entity - the parity case list, ownership gates.
    Audit 3 finding #12 (pilot parity) is exactly that shape: nothing in the design
    bound it to anything machine-readable, so it drifted freely.
    """
    contracts = (schema.get('x-ea-lab-meta') or {}).get('contracts') or {}
    body = contracts.get(key)
    if body is None:
        raise KeyError('x-ea-lab-meta.contracts.{0} is not in the schema'.format(key))
    lines = [WARNING, '']
    if isinstance(body, dict) and 'columns' in body and 'rows' in body:
        cols = body['columns']
        lines.append('| ' + ' | '.join(cols) + ' |')
        lines.append('|' + '---|' * len(cols))
        for row in body['rows']:
            lines.append('| ' + ' | '.join(str(row.get(c, '')).replace('|', '\\|') for c in cols) + ' |')
        lines.append('')
    else:
        lines.append('```json')
        lines.append(json.dumps(body, indent=2, ensure_ascii=False))
        lines.append('```')
        lines.append('')
    return '\n'.join(lines)


def generate(key, schema):
    if key == '__STORAGE__':
        return gen_storage(schema)
    if key.startswith('META_'):
        return gen_meta(schema, key[len('META_'):])
    defs = schema['$defs']
    if key not in defs:
        raise KeyError('the design asks for a generated block named `{0}`, '
                       'but schemas.json has no $defs entry with that name'.format(key))
    return gen_entity(key, defs[key])


# ------------------------------------------------------------------------ driver

def rewrite(text, schema):
    """Return (new_text, [keys]). Raises KeyError if the design names an unknown block."""
    keys = []

    def repl(m):
        key = m.group('key')
        keys.append(key)
        body = generate(key, schema)
        return '{0}\n{1}\n{2}'.format(BEGIN.format(key=key), body, END.format(key=key))

    return BLOCK_RE.sub(repl, text), keys


def main():
    check = '--check' in sys.argv
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)

    with io.open(SCHEMA_PATH, encoding='utf-8') as fh:
        schema = json.load(fh)
    with io.open(DESIGN_PATH, encoding='utf-8', newline='') as fh:
        original = fh.read()

    try:
        new, keys = rewrite(original, schema)
    except KeyError as exc:
        print('[FAIL] {0}'.format(exc.args[0]))
        return 1

    if not keys:
        print('[FAIL] {0} contains no generated contract blocks at all. The whole point of '
              'BACKLOG-D31 is that the normative tables are generated; a design with zero '
              'blocks is a design back on hand-maintained contracts.'.format(DESIGN_PATH))
        return 1

    dupes = sorted({k for k in keys if keys.count(k) > 1})
    if dupes:
        print('[FAIL] duplicated generated block(s): {0} — two blocks for one contract is '
              'the same two-copies defect this tool exists to remove.'.format(', '.join(dupes)))
        return 1

    # Coverage. Without this, an entity drifts by simply not being written down: the design
    # stays silent, the schema changes, and nothing disagrees because nothing was ever said.
    # Silence is how six of the seven regressions survived a checker that only compared what
    # WAS written.
    missing = [name for name in schema['$defs'] if name not in keys]
    if missing:
        print('[FAIL] {0} entity/entities in schemas.json have no generated block in the design: {1}'
              .format(len(missing), ', '.join(missing)))
        print('       Add "<!-- BEGIN GENERATED CONTRACT: <Entity> -->" / "<!-- END ... -->" where the')
        print('       design discusses it. An entity the design never states cannot be caught')
        print('       contradicting the schema, which is not the same as agreeing with it.')
        return 1

    meta_contracts = [k for k in ((schema.get('x-ea-lab-meta') or {}).get('contracts') or {})
                      if not k.startswith('_')]
    missing_meta = [k for k in meta_contracts if 'META_' + k not in keys]
    if missing_meta:
        print('[FAIL] non-entity contract(s) declared in x-ea-lab-meta.contracts with no block '
              'in the design: {0}'.format(', '.join(missing_meta)))
        return 1

    if new == original:
        print('[OK] {0} blocks in {1} match {2}'.format(len(keys), DESIGN_PATH, SCHEMA_PATH))
        return 0

    if check:
        diff = list(difflib.unified_diff(
            original.replace('\r\n', '\n').splitlines(),
            new.replace('\r\n', '\n').splitlines(),
            'design (committed)', 'design (generated from schema)', lineterm='', n=1))
        print('[FAIL] the design\'s generated contract tables no longer match the schema.')
        print('       This is BACKLOG-D31\'s whole purpose: the design and the schema stated')
        print('       different contracts seven times across three audits. Regenerate with:')
        print('         tools\\python312\\python.exe {0}'.format(__file__.replace('\\', '/')))
        print('')
        for line in diff[:120]:
            print('  ' + line)
        if len(diff) > 120:
            print('  ... {0} more diff lines'.format(len(diff) - 120))
        return 1

    with io.open(DESIGN_PATH, 'w', encoding='utf-8', newline='') as fh:
        fh.write(new)
    print('[WROTE] {0} — {1} generated blocks: {2}'.format(DESIGN_PATH, len(keys), ', '.join(keys)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
