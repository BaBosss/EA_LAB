"""
gen_design_contracts.py - generate the NORMATIVE contract tables from schemas.json into
_triage/factory_os/CONTRACTS.md, so the design and the schema cannot disagree.

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
  Blocks in CONTRACTS.md delimited by
      <!-- BEGIN GENERATED CONTRACT: <key> -->  ...  <!-- END GENERATED CONTRACT: <key> -->
  Keys:
      __STORAGE__      one row per entity: owner file, writer, canonical/derived, enforcement
      META_<name>      a non-entity contract from x-ea-lab-meta.contracts
      <EntityName>     that entity's field table + conditional requirements
  Each block opens with its own `### <key>` heading, which is what the design's links anchor to --
  generated, so a heading cannot drift from the key naming it. Prose INSIDE a block is overwritten
  without mercy.

WHAT IS CHECKED IN THE DESIGN
  Nothing is written there. It is read to confirm it still LINKS every contract, because moving the
  tables out removed the one property that used to hold by construction: that the design states each
  contract at all. An entity nobody references is an entity nobody reviews.

USAGE
  tools\\python312\\python.exe _triage/factory_os/gen_design_contracts.py           # rewrite CONTRACTS.md
  tools\\python312\\python.exe _triage/factory_os/gen_design_contracts.py --check   # exit 1 if stale
EXIT
  0 = CONTRACTS.md matches the schema and the design links it all
  1 = drift, a malformed/missing block, or a broken/missing design link
"""
import json, re, sys, difflib, io, os

SCHEMA_PATH = '_triage/factory_os/schemas.json'
DESIGN_PATH = '_triage/EA_LAB_FACTORY_OS_DESIGN.md'

# The generated tables used to be injected into DESIGN_PATH. They now live in their own file and
# the design links to them (BACKLOG-D31 follow-up, recommended independently by this seat and by
# Codex audit 5 Q4). Two reasons, and the second is the one that matters:
#   1. Injecting 30 blocks took the design from 829 to 1807 lines, while its own section 7.4 is
#      about being readable without exhausting an agent's context.
#   2. It put generated output inside a hand-written narrative, which is where both marker
#      defects lived - a stray BEGIN hiding hand-written prose inside what reads as generated
#      output, and a block written twice. CONTRACTS.md carries no narrative for a stray marker
#      to capture, so the blast radius of that failure mode is now a generated file that
#      --check rewrites wholesale.
# DESIGN_PATH is still read, but READ-ONLY, and only to verify it links every contract. An
# entity nobody references is an entity nobody reviews.
CONTRACTS_PATH = '_triage/factory_os/CONTRACTS.md'

BEGIN = '<!-- BEGIN GENERATED CONTRACT: {key} -->'
END = '<!-- END GENERATED CONTRACT: {key} -->'
BLOCK_RE = re.compile(
    r'<!-- BEGIN GENERATED CONTRACT: (?P<key>[A-Za-z0-9_]+) -->\r?\n'
    r'(?P<body>.*?)'
    r'<!-- END GENERATED CONTRACT: (?P=key) -->',
    re.DOTALL)

# How the design references a contract. The KEY is carried in backticks and the ANCHOR in the
# URL, and validate_coverage asserts the two agree -- a link whose visible name and destination
# disagree is the same two-copies defect this tool exists to remove, one line long.
LINK_RE = re.compile(
    r'\[`(?P<key>[A-Za-z0-9_]+)`\]\(factory_os/CONTRACTS\.md#(?P<anchor>[A-Za-z0-9_-]+)\)')


def anchor_of(key):
    """The markdown anchor for the generated `### <key>` heading."""
    return key.lower()

MAX_NEST_DEPTH = 3


class DepthExceeded(Exception):
    pass


WARNING = ('<sub>⚙️ Generated from `_triage/factory_os/schemas.json` by '
           '`_triage/factory_os/gen_design_contracts.py`. **Do not edit by hand** — '
           'edit the schema and regenerate. `--check` runs in the fast cage tier.</sub>')


# ---------------------------------------------------------------- type rendering

def type_names(spec):
    """The declared JSON types of a spec, as a set. `type` may be a string OR a list."""
    t = spec.get('type') if isinstance(spec, dict) else None
    if isinstance(t, list):
        return set(t)
    return {t} if t else set()


def is_kind(spec, kind):
    """True for `type: "object"` AND for `type: ["object", "null"]`.

    AUDIT-4 P1: the first version tested `spec.get('type') == 'object'`, so every NULLABLE
    nested object was skipped - and `lease`, `process_observed` and `safe_range` are all
    `["object", "null"]`. Their nested required fields (`lease_id`/`owner`/`expires_at`,
    `pid`/`observed_at`/`process_fingerprint`) silently vanished from the generated design
    while the schema still carried them. That is the exact defect class this file exists to
    remove, reintroduced by the file itself: a contract that left the document without any
    check noticing, because absence is not disagreement.
    """
    return kind in type_names(spec)


def nullable(spec):
    return 'null' in type_names(spec)



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
    if is_kind(spec, 'array'):
        items = spec.get('items', {})
        if isinstance(items, dict) and items.get('properties'):
            return '{0}array of object *(fields below)*'.format('nullable ' if nullable(spec) else '')
        return '{0}array of {1}'.format('nullable ' if nullable(spec) else '', render_type(items))
    if is_kind(spec, 'object'):
        if spec.get('properties'):
            return '{0}object *(fields below)*'.format('nullable ' if nullable(spec) else '')
        return '`object`' if not nullable(spec) else '`object` \\| `null`'
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
    if is_kind(spec, 'object') and spec.get('required'):
        bits.append('requires ' + ', '.join('`%s`' % r for r in spec['required']))
    items = spec.get('items')
    if is_kind(spec, 'array') and isinstance(items, dict) and items.get('properties'):
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
    if depth > MAX_NEST_DEPTH:
        # Loudly, not silently. A cap that returns an empty list is a contract that leaves
        # the document with nothing disagreeing - the same shape as the nullable-object bug
        # audit 4 found in this very function. Nothing in the schema is this deep today; if
        # something becomes this deep, the generator must stop rather than quietly truncate.
        raise DepthExceeded(
            'nesting deeper than {0} at `{1}` — raise MAX_NEST_DEPTH deliberately after '
            'checking the rendered table is still readable. Refusing to truncate silently.'
            .format(MAX_NEST_DEPTH, prefix.rstrip('.')))
    required = set(defn.get('required') or [])
    for field, spec in (defn.get('properties') or {}).items():
        path = prefix + field
        rows.append((path, spec, field in required))
        if not isinstance(spec, dict) or '$ref' in spec:
            continue
        if is_kind(spec, 'object') and spec.get('properties'):
            rows.extend(walk_fields(spec, path + '.', depth + 1))
        elif is_kind(spec, 'array'):
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
        cond = clause.get('if')
        if not isinstance(cond, dict):
            out.append(unrendered(clause))
            continue

        when = []
        for field, sub in (cond.get('properties') or {}).items():
            if 'const' in sub:
                when.append('`{0}` = `{1}`'.format(field, sub['const']))
            elif 'enum' in sub:
                when.append('`{0}` ∈ {1}'.format(field, ', '.join('`%s`' % v for v in sub['enum'])))
            else:
                when.append('`{0}` {1}'.format(field, render_type(sub)))
        # AUDIT-4 P1: an `if` carrying ONLY `required` used to produce an empty `when`, and
        # an empty `when` was silently dropped. That is the shape of WorkReceipt's anti-copy
        # rule - "a receipt that has an order_ref may not also carry title/owner/status" -
        # so the single most load-bearing ownership constraint in that entity could be
        # deleted from the schema without changing one character of the design.
        bare = [r for r in (cond.get('required') or []) if r not in (cond.get('properties') or {})]
        if bare:
            when.append('{0} present'.format(', '.join('`%s`' % r for r in bare)))

        rendered = []
        for label, branch in (('then', clause.get('then')), ('else', clause.get('else'))):
            if not isinstance(branch, dict):
                continue
            eff = []
            if branch.get('required'):
                eff.append('requires ' + ', '.join('`%s`' % r for r in branch['required']))
            for field, sub in (branch.get('properties') or {}).items():
                rule = render_rule(sub)
                eff.append('`{0}` → {1}{2}'.format(field, render_type(sub), ' (%s)' % rule if rule else ''))
            neg = branch.get('not')
            if isinstance(neg, dict):
                forbidden = list(neg.get('required') or [])
                # `not: {anyOf: [{required:[a]}, {required:[b]}]}` is how "may carry none of
                # these" is written in JSON Schema. Rendering it as a bare "REFUSED" would
                # print a rule without naming the fields it protects, which is a table that
                # looks complete and says nothing - the failure mode of the whole first pass.
                for sub in (neg.get('anyOf') or []) + (neg.get('oneOf') or []):
                    forbidden.extend(sub.get('required') or [])
                forbidden.extend(sorted(neg.get('properties') or {}))
                eff.append('**REFUSED if it also carries** ' + ', '.join('`%s`' % f for f in forbidden)
                           if forbidden else '**REFUSED**')
            if branch.get('description'):
                eff.append(' '.join(str(branch['description']).split()))
            if eff:
                rendered.append((label, eff))

        if when and rendered:
            joined = ' and '.join(when)
            for label, eff in rendered:
                head = ('when {0}'.format(joined) if label == 'then'
                        else 'otherwise (no {0})'.format(joined))
                out.append('- **{0}** → {1}'.format(head, ' · '.join(eff)))
        else:
            # Never skip. A clause this renderer does not understand is dumped raw, so that
            # editing it still moves the document. Silence is how the WorkReceipt rule hid.
            out.append(unrendered(clause))
    return out


def unrendered(clause):
    """Visible fallback for a conditional shape this renderer does not model.

    Deliberately ugly. An ugly line in the design is a bug report; a missing line is a
    contract that quietly stopped existing.
    """
    return '- ⚠️ **conditional not modelled by the generator, shown raw so it cannot hide:** ' \
           '`{0}`'.format(json.dumps(clause, sort_keys=True, ensure_ascii=False))


# -------------------------------------------------------------- block generators

def gen_entity(name, defn):
    owner = defn.get('x-owner-file')
    derived = defn.get('x-derived')
    writer = defn.get('x-writer')
    enforced = defn.get('x-enforced-by')

    # The heading is INSIDE the generated block on purpose: it is what the design's link anchors
    # to, so a hand-written heading here could drift from the key the link names.
    lines = ['### {0}'.format(name), '', WARNING, '']
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
    lines = ['### __STORAGE__', '', WARNING, '',
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
    lines = ['### META_{0}'.format(key), '', WARNING, '']
    # `note` is normative and IS rendered; `_why` is history and is not. The distinction is
    # load-bearing: replacing section 8.4's prose with a generated table silently dropped
    # "every case is judged on all seven points of 5.5" until this field existed to hold it.
    if isinstance(body, dict) and body.get('note'):
        lines.append('**{0}**'.format(' '.join(str(body['note']).split())))
        lines.append('')
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


HTML_COMMENT_RE = re.compile(r'<!--.*?-->', re.DOTALL)
FENCE_RE = re.compile(r'^```.*?^```', re.DOTALL | re.MULTILINE)


def visible_markdown(text):
    """Drop HTML comments and fenced code blocks -- text a reader of the rendered page never sees.

    Codex audit 6 (MAJOR 5, reproduced): validate_links regex-scanned the RAW bytes, so putting all
    30 links inside one `<!-- ... -->` block returned CLEAN with zero visible prose. The check was
    establishing "the design file contains a matching URL", not "the design references this
    contract". A link a reader cannot see does not reference anything.
    """
    return FENCE_RE.sub('', HTML_COMMENT_RE.sub('', text))


def validate_links(design, keys):
    """Return problems with how the DESIGN references the contracts file.

    This replaces what the old in-document layout gave for free. When the blocks lived in the
    design, "the design states this contract" was true by construction. Now that they live in
    CONTRACTS.md, the design could quietly stop mentioning an entity and nothing would notice --
    and an entity nobody references is an entity nobody reviews, which is the condition all seven
    regressions were found in. So the link is the replacement obligation, and it is checked.
    """
    problems = []
    linked = {}
    hidden_only = set()
    visible = visible_markdown(design)
    for m in LINK_RE.finditer(design):
        if m.group('key') not in [v.group('key') for v in LINK_RE.finditer(visible)]:
            hidden_only.add(m.group('key'))
    for key in sorted(hidden_only):
        problems.append(
            'the design links `{0}` only from inside an HTML comment or a fenced code block, '
            'where no reader sees it. A hidden link satisfies a regex, not a reference.'
            .format(key))
    for m in LINK_RE.finditer(visible):
        key, anchor = m.group('key'), m.group('anchor')
        linked.setdefault(key, []).append(anchor)
        if anchor != anchor_of(key):
            problems.append(
                'the design links `{0}` but points at #{1} (expected #{2}) — a link whose name '
                'and destination disagree is the two-copies defect, one line long.'
                .format(key, anchor, anchor_of(key)))

    for key in keys:
        if key not in linked:
            problems.append(
                'CONTRACTS.md defines `{0}` but the design never links it. An entity nobody '
                'references is an entity nobody reviews; add a link at the point the design '
                'discusses it.'.format(key))
    for key in sorted(linked):
        if key not in keys:
            problems.append(
                'the design links `{0}`, which CONTRACTS.md does not define — a dangling '
                'contract reference reads as coverage.'.format(key))
    return problems


def validate_coverage(text, schema, keys):
    """Return a list of problems. Empty list = the contracts file covers the schema.

    A FUNCTION, not inline code in main(), because the negative-fixture harness has to be
    able to call the real thing. AUDIT-4 P1 caught the previous control asserting
    `'ExecutionKey' not in keys` after deleting the ExecutionKey block — which is true by
    arithmetic and tests nothing. A control that cannot fail is worse than no control: it
    reports coverage that was never checked.
    """
    problems = []

    # Unmatched markers. The block regex only sees complete pairs, so a stray BEGIN or END
    # used to be invisible to every check here - and everything between a stray BEGIN and
    # the next real END is hand-written text sitting inside what reads as a generated block.
    n_begin = text.count('<!-- BEGIN GENERATED CONTRACT:')
    n_end = text.count('<!-- END GENERATED CONTRACT:')
    if n_begin != len(keys) or n_end != len(keys):
        problems.append(
            'marker imbalance: {0} BEGIN and {1} END markers but only {2} complete pair(s). '
            'An unpaired marker hides hand-written text inside what reads as generated output.'
            .format(n_begin, n_end, len(keys)))

    if not keys:
        problems.append(
            'CONTRACTS.md contains no generated contract blocks at all — that is a design back '
            'on hand-maintained contracts, which is the defect BACKLOG-D31 exists to remove.')

    dupes = sorted({k for k in keys if keys.count(k) > 1})
    if dupes:
        problems.append('duplicated block(s): {0} — two blocks for one contract is the same '
                        'two-copies defect this tool removes.'.format(', '.join(dupes)))

    missing = [name for name in schema['$defs'] if name not in keys]
    if missing:
        problems.append(
            '{0} entity/entities in schemas.json have no generated block in CONTRACTS.md: {1}. '
            'An entity the contracts file never states cannot be caught contradicting the schema, '
            'which is not the same as agreeing with it.'.format(len(missing), ', '.join(missing)))

    meta = [k for k in ((schema.get('x-ea-lab-meta') or {}).get('contracts') or {})
            if not k.startswith('_')]
    missing_meta = [k for k in meta if 'META_' + k not in keys]
    if missing_meta:
        problems.append('non-entity contract(s) declared in x-ea-lab-meta.contracts with no '
                        'block in CONTRACTS.md: {0}'.format(', '.join(missing_meta)))
    return problems


def main():
    check = '--check' in sys.argv
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)

    with io.open(SCHEMA_PATH, encoding='utf-8') as fh:
        schema = json.load(fh)
    with io.open(CONTRACTS_PATH, encoding='utf-8', newline='') as fh:
        original = fh.read()
    # READ-ONLY. The design is no longer written by this tool; it is read solely to confirm it
    # still links every contract.
    with io.open(DESIGN_PATH, encoding='utf-8', newline='') as fh:
        design = fh.read().replace('\r\n', '\n')

    # Line endings are NOT part of the contract. This repo's working tree is CRLF (core.autocrlf)
    # while the blobs are LF, so a file straight from `git checkout` is CRLF and anything this
    # script writes is LF. Comparing raw text made --check go red on a clean checkout with an
    # EMPTY diff -- red for a reason the operator cannot see is how a cage gets bypassed, which
    # is the entire premise of the fast-tier budget two directories away. Compare content;
    # preserve whatever convention the file already uses when writing.
    eol = '\r\n' if '\r\n' in original else '\n'

    def norm(text):
        return text.replace('\r\n', '\n')

    try:
        new, keys = rewrite(norm(original), schema)
    except KeyError as exc:
        print('[FAIL] {0}'.format(exc.args[0]))
        return 1
    except DepthExceeded as exc:
        print('[FAIL] {0}'.format(exc.args[0]))
        return 1

    problems = validate_coverage(original, schema, keys) + validate_links(design, keys)
    if problems:
        for p in problems:
            print('[FAIL] {0}'.format(p))
        return 1

    if new == norm(original):
        print('[OK] {0} blocks in {1} match {2}, and the design links all {0}'
              .format(len(keys), CONTRACTS_PATH, SCHEMA_PATH))
        return 0

    if check:
        diff = list(difflib.unified_diff(
            norm(original).splitlines(), new.splitlines(),
            'CONTRACTS.md (committed)', 'CONTRACTS.md (generated from schema)',
            lineterm='', n=1))
        if not diff:
            # Belt and braces: if the texts differ but the line-diff is empty, the difference
            # is invisible (whitespace, encoding). Say so instead of printing nothing.
            print('[FAIL] the file differs from the generated output in a way that produces no '
                  'line diff — invisible whitespace or encoding, not a contract change. '
                  'Regenerate; do not hunt for a semantic difference that is not there.')
            return 1
        print('[FAIL] CONTRACTS.md no longer matches the schema.')
        print('       This is BACKLOG-D31\'s whole purpose: the design and the schema stated')
        print('       different contracts seven times across three audits. Regenerate with:')
        print('         tools\\python312\\python.exe {0}'.format(__file__.replace('\\', '/')))
        print('')
        for line in diff[:120]:
            print('  ' + line)
        if len(diff) > 120:
            print('  ... {0} more diff lines'.format(len(diff) - 120))
        return 1

    with io.open(CONTRACTS_PATH, 'w', encoding='utf-8', newline='') as fh:
        fh.write(new.replace('\n', eol) if eol != '\n' else new)
    print('[WROTE] {0} — {1} generated blocks: {2}'.format(CONTRACTS_PATH, len(keys),
                                                           ', '.join(keys)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
