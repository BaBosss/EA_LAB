# -*- coding: utf-8 -*-
"""preset.py -- ORDER-700 (slice S6). The preset compiler.

WHAT IT IS FOR, in one measurement taken before a line of it was written:

    git ls-files '*.set'                -> 2177 tracked
      full-surface (>= 184 assignments) ->    0
      median keys per file 14 - max 134 - min 0

Not one committed `.set` carries the build's full input surface. Every unlisted input is
filled at run time from the PER-TERMINAL tester cache -- the documented root cause of the
ORDER-165 8/8 false drift (memory `mt5-tester-cache-nondeterminism`). A partial `.set` is
therefore not a smaller preset, it is a preset with an unknown remainder, and two terminals
disagree about what it means.

    THE RULE: this compiler emits FULL SURFACE or it emits nothing.

WHAT IT IS NOT FOR. It does not judge the 2177 files that already exist. A rule "every
committed .set is full-surface" would refuse all of them on its first run, which is the
`optimize_guard` failure of 2026-07-30 -- the guard that refuses valid work is the one that
gets switched off. It refuses what IT emits.

CATEGORY (TIER_SNAPSHOT_DESIGN.md section 2/3.3). This module is a LIBRARY. It never calls
`EvidenceSource.for_run()`; the caller hands it a source, exactly as `registry.py` does. A
library that defaults its source becomes a second decider of which bytes count. Consequence
worth stating because it is also acceptance criterion P5: this module opens NO path of its
own, so "must not read the terminal cache" is structural rather than promised.

TWO KINDS OF FAILURE, kept apart on purpose:
    PresetRefusal  -- the request cannot be compiled. A verdict about the REQUEST.
    ToolFailure    -- a reader could not answer (raised by evidence.py, passed through).
Collapsing them is how "I could not read it" starts looking like "there was nothing there"
(memory `guard-disarmed-by-prose-reported-as-note`).

CANONICALISATION IS PART OF THE POINT. `300`, `300.0` and `3e2` written in three places are
one value, and the fingerprint must say so. Every value is rendered through one function, so
a hash difference means a CONFIG difference and never a spelling difference.
"""
import hashlib
import json
import re

from evidence import ToolFailure          # noqa: F401  (re-exported for callers)

INPUTS_REL = 'ea_template/core/Inputs.mqh'
PARAM_REGISTRY_REL = 'docs/PARAM_REGISTRY.csv'
INSTRUMENT_PROFILES_REL = 'factory/instrument_profiles.jsonl'

# The value layers, in RANK ORDER. This tuple IS the precedence rule: a later layer overrides
# an earlier one, silently and legitimately, BECAUSE the order is total and declared here.
# What is never legitimate is two rows INSIDE one layer disagreeing -- that is last-wins across
# rows that disagree, which is half of the S7 defect the owner ratified `build_tag` to fix
# (PROJECT_STATE.md section 3, 2026-07-31). Same-layer disagreement is P7's refusal.
LAYER_ORDER = ('defaults', 'instrument_profile', 'account_unit', 'hypothesis')

ACCOUNT_UNITS = ('usd', 'cent')

# MQL5 platform constants that appear as input defaults but are NOT declared in Inputs.mqh.
# A CLOSED table: a symbol that is not here is REFUSED, never guessed. Values are the platform's
# own (ENUM_TIMEFRAMES is `PERIOD_H1 = 16385` upward, not 1..n -- guessing that one wrong is how
# a diff table lied in two directions, memory `proving-a-set-was-loaded-on-a-chart`).
MQL_BUILTIN_ENUMS = {
    'PERIOD_CURRENT': 0, 'PERIOD_M1': 1, 'PERIOD_M2': 2, 'PERIOD_M3': 3, 'PERIOD_M4': 4,
    'PERIOD_M5': 5, 'PERIOD_M6': 6, 'PERIOD_M10': 10, 'PERIOD_M12': 12, 'PERIOD_M15': 15,
    'PERIOD_M20': 20, 'PERIOD_M30': 30, 'PERIOD_H1': 16385, 'PERIOD_H2': 16386,
    'PERIOD_H3': 16387, 'PERIOD_H4': 16388, 'PERIOD_H6': 16390, 'PERIOD_H8': 16392,
    'PERIOD_H12': 16396, 'PERIOD_D1': 16408, 'PERIOD_W1': 32769, 'PERIOD_MN1': 49153,
    'MODE_SMA': 0, 'MODE_EMA': 1, 'MODE_SMMA': 2, 'MODE_LWMA': 3,
}

_INPUT_RE = re.compile(
    r'^\s*input\s+(?P<type>[A-Za-z_][A-Za-z0-9_]*)\s+'
    r'(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?P<default>.+?)\s*;')
_GROUP_RE = re.compile(r'^\s*input\s+group\b')
_ENUM_OPEN_RE = re.compile(r'^\s*enum\s+([A-Za-z_][A-Za-z0-9_]*)')
_ENUM_MEMBER_RE = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(-?\d+)\s*,?')
_TAG_RE = re.compile(r'^\s*#ifndef\s+(LAB_ENTRY_[0-9A-Za-z_]+)\s*$')
_SET_KEY_RE = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')


class PresetRefusal(Exception):
    """The REQUEST cannot be compiled. Not a tooling failure -- a verdict about the input."""


class InputDecl(object):
    __slots__ = ('name', 'mql_type', 'default_expr', 'line')

    def __init__(self, name, mql_type, default_expr, line):
        self.name = name
        self.mql_type = mql_type
        self.default_expr = default_expr
        self.line = line


class Surface(object):
    """The input surface of ONE build. `build_tag` is part of its identity, not decoration.

    Inputs.mqh declares `StackMode` EIGHT times, once per `#ifdef LAB_ENTRY_nn`. The raw file
    holds 184 `input` declarations; no single build exposes 184 inputs. A surface parsed without
    a build tag is a surface for no build at all, so `parse_surface` refuses to produce one.
    """

    def __init__(self, build_tag, inputs, known_tags):
        self.build_tag = build_tag
        self.inputs = tuple(inputs)
        self.known_tags = tuple(sorted(known_tags))
        self.by_name = dict((d.name, d) for d in self.inputs)

    def __len__(self):
        return len(self.inputs)


# ---------------------------------------------------------------------------------------------
# parsing
# ---------------------------------------------------------------------------------------------

def parse_enum_table(text):
    """`enum X { A = 21, B = 22 };` -> {'A': 21, 'B': 22}, plus the MQL5 builtins.

    Members without an explicit `= n` are NOT invented by counting upward. MQL5 would assign
    them by position, but this compiler resolves symbols into a FINGERPRINT: a value derived by
    a rule the EA does not run is a number nobody checked. Such a member is simply absent, and
    an input defaulting to it is refused by name at resolve time.
    """
    table = dict(MQL_BUILTIN_ENUMS)
    inside = False
    for line in text.split('\n'):
        if _ENUM_OPEN_RE.match(line):
            inside = True
            continue
        if inside:
            if '}' in line:
                inside = False
                continue
            m = _ENUM_MEMBER_RE.match(_strip_comment(line))
            if m:
                table[m.group(1)] = int(m.group(2))
    return table


def _strip_comment(line):
    """Drop a trailing `//` comment, but not one inside a string literal."""
    out = []
    in_str = False
    i = 0
    while i < len(line):
        ch = line[i]
        if ch == '"':
            in_str = not in_str
        elif not in_str and ch == '/' and i + 1 < len(line) and line[i + 1] == '/':
            break
        out.append(ch)
        i += 1
    return ''.join(out)


def known_build_tags(text):
    """The build tags THE FILE declares, taken from its own fallback guard.

    Derived, never listed here. A hand-kept list of build tags is the hand-maintained cache of
    reality that L0 exists to stop (BACKLOG-D29): a ninth entry would be added to Inputs.mqh and
    silently unknown to this compiler.
    """
    return set(m.group(1) for m in (_TAG_RE.match(l) for l in text.split('\n')) if m)


def parse_surface(text, build_tag):
    """-> Surface for exactly one build, with `#ifdef` evaluated rather than ignored."""
    tags = known_build_tags(text)
    if not tags:
        raise PresetRefusal(
            'no LAB_ENTRY_* build tag is declared anywhere in the input source, so there is no '
            'build to compile a surface for. This compiler derives the valid tag set from the '
            'file instead of holding a list of its own.')
    if build_tag is None:
        raise PresetRefusal(
            'no build_tag given. The surface is PER BUILD -- `StackMode` is declared once per '
            '#ifdef LAB_ENTRY_nn -- so a surface parsed without one belongs to no build. Known '
            'tags: %s' % ', '.join(sorted(tags)))
    if build_tag not in tags:
        raise PresetRefusal(
            'build_tag %r is not declared in the input source. Known tags: %s'
            % (build_tag, ', '.join(sorted(tags))))

    defined = set([build_tag])
    stack = []
    decls = []
    seen = {}
    for n, raw in enumerate(text.split('\n'), start=1):
        line = raw.rstrip()
        stripped = line.strip()
        if stripped.startswith('#ifdef '):
            stack.append(stripped.split(None, 1)[1].strip() in defined)
            continue
        if stripped.startswith('#ifndef '):
            stack.append(stripped.split(None, 1)[1].strip() not in defined)
            continue
        if stripped.startswith('#endif'):
            if not stack:
                raise PresetRefusal('unbalanced #endif at line %d of the input source' % n)
            stack.pop()
            continue
        if stripped.startswith('#else') or stripped.startswith('#elif'):
            # MQL5's preprocessor has neither; Inputs.mqh says so in its own header comment.
            # If one ever appears, this parser's model of the file is wrong -- say so loudly
            # rather than mis-parse the surface silently.
            raise PresetRefusal(
                'line %d uses %s, which this parser does not model. The surface it would '
                'produce is not the surface the compiler builds.' % (n, stripped.split()[0]))
        active = all(stack)
        if not active:
            continue
        if stripped.startswith('#define '):
            parts = stripped.split(None, 2)
            if len(parts) >= 2:
                defined.add(parts[1].strip())
            continue
        if _GROUP_RE.match(line):
            # `input group "..."` is a SECTION HEADER, not an input. It is the reason a count of
            # `^input ` lines reported 209 when the build exposes 184; the audit that caught that
            # is why this line exists rather than a comment saying to be careful.
            continue
        m = _INPUT_RE.match(_strip_comment(line))
        if not m:
            continue
        name = m.group('name')
        if name in seen:
            raise PresetRefusal(
                'input %s is declared twice in build %s (lines %d and %d). Two active '
                'declarations of one name means the #ifdef model above is wrong for this file, '
                'and the surface would silently take one of them.'
                % (name, build_tag, seen[name], n))
        seen[name] = n
        decls.append(InputDecl(name, m.group('type'), m.group('default').strip(), n))
    if stack:
        raise PresetRefusal('%d unclosed #ifdef/#ifndef block(s) in the input source' % len(stack))
    if not decls:
        raise PresetRefusal('build %s exposes no inputs at all' % build_tag)
    return Surface(build_tag, decls, tags)


def parse_unit_classes(text):
    """`docs/PARAM_REGISTRY.csv` -> {input_name: unit_string}.

    The registry is CSV with `>`-prefixed prose lines above the header, and names may carry a
    `[LAB_ENTRY_nn]` build tag (the encoded form the owner ratified splitting apart in
    ORDER-672). The tag is dropped for the unit lookup because a unit is a property of the
    parameter, not of the build -- and it is dropped ONLY here, where that is true.
    """
    import csv
    import io as _io
    body = '\n'.join(l for l in text.split('\n') if not l.startswith('>'))
    out = {}
    for row in csv.DictReader(_io.StringIO(body)):
        name = (row.get('name') or '').strip()
        if not name:
            continue
        name = re.sub(r'\[[^\]]*\]$', '', name).strip()
        unit = (row.get('unit') or '').strip()
        if name in out and out[name] != unit:
            # /scrutinize: `out[name] = unit` was LAST-WINS ACROSS TAGGED ROWS THAT DISAGREE --
            # the exact S7 defect the owner ratified `build_tag` to fix, recreated in the file
            # built the same day. If X[LAB_ENTRY_11] is money and X[LAB_ENTRY_12] is not,
            # whichever row came later silently decided P8 for both. Disagreement is recorded,
            # not resolved: the sentinel fails is_money_unit (so a bare number on such a key is
            # not silently fine) and compile_preset refuses it BY NAME whenever the key is set.
            out[name] = UNIT_CONFLICT
            continue
        if out.get(name) != UNIT_CONFLICT:
            out[name] = unit
    return out


# The sentinel parse_unit_classes stores when tagged registry rows disagree about a unit.
# Not a valid unit string by construction (starts with '!'), and checked for by compile_preset.
UNIT_CONFLICT = '!unit-rows-disagree'


def is_money_unit(unit_text):
    """True when a unit denominates ACCOUNT MONEY, so its number changes meaning with the unit.

    Deliberately narrow. `pip`, `points`, `%`, `bars`, `lot` and every enum are unaffected by
    whether an account is USD or cent; only account-currency amounts are.
    """
    u = (unit_text or '').strip().lower()
    if not u:
        return False
    return ('money' in u or 'usd' in u or 'currency' in u
            or u.startswith('$') or 'account money' in u)


# ---------------------------------------------------------------------------------------------
# value canonicalisation
# ---------------------------------------------------------------------------------------------

_BOOL_LITERALS = {'true': True, 'false': False}


def render_value(decl, value, enums):
    """ONE representation per value, whatever it was written as. -> str for a .set line."""
    t = decl.mql_type
    if isinstance(value, str):
        v = value.strip()
        if t == 'string':
            return v.strip('"')
        low = v.lower()
        if low in _BOOL_LITERALS:
            value = _BOOL_LITERALS[low]
        elif v.strip('"') in enums and not _is_number(v):
            value = enums[v.strip('"')]
        elif _is_number(v):
            value = float(v) if ('.' in v or 'e' in low) else int(v)
        else:
            raise PresetRefusal(
                'cannot resolve %r for input %s (%s): it is not a number, not `true`/`false`, '
                'and not a symbol this compiler knows. Symbols come from the enums declared in '
                'the input source plus a CLOSED table of MQL5 platform constants -- an unknown '
                'one is refused rather than guessed, because the number would end up inside a '
                'fingerprint nobody checked.' % (value, decl.name, t))
    if t == 'bool':
        if not isinstance(value, bool):
            raise PresetRefusal('input %s is bool but got %r' % (decl.name, value))
        return 'true' if value else 'false'
    if isinstance(value, bool):
        raise PresetRefusal('input %s is %s but got a bool %r' % (decl.name, t, value))
    if t in ('int', 'long') or t.startswith('ENUM_'):
        if isinstance(value, float) and value != int(value):
            raise PresetRefusal('input %s is %s but got the non-integral %r'
                                % (decl.name, t, value))
        return str(int(value))
    if t == 'double':
        return repr(float(value))
    if t == 'string':
        return str(value)
    raise PresetRefusal('input %s has type %s, which this compiler does not render'
                        % (decl.name, t))


def _is_number(text):
    try:
        float(text)
        return True
    except (TypeError, ValueError):
        return False


# ---------------------------------------------------------------------------------------------
# layers
# ---------------------------------------------------------------------------------------------

class Layer(object):
    """One named source of values, holding ROWS rather than a dict.

    Rows, not a dict, on purpose: a dict has already resolved a same-layer disagreement by the
    time anyone can look at it, and resolving it silently is the defect (P7).
    """

    def __init__(self, name, rows):
        if name not in LAYER_ORDER:
            raise PresetRefusal(
                'layer %r is not one of the declared layers %s. Precedence is a TOTAL order '
                'fixed in LAYER_ORDER; an undeclared layer has no rank, so "later wins" would '
                'mean whatever the caller happened to pass last.' % (name, list(LAYER_ORDER)))
        self.name = name
        self.rows = list(rows)


def _row_parts(row, layer_name):
    """A row is (key, value) or (key, {'value':..., 'unit':...}) or (key, value, source_id)."""
    if len(row) == 2:
        key, val = row
        source_id = layer_name
    elif len(row) == 3:
        key, val, source_id = row
    else:
        raise PresetRefusal('malformed row %r in layer %s' % (row, layer_name))
    unit = None
    if isinstance(val, dict):
        if 'value' not in val:
            raise PresetRefusal('row %s in layer %s has no `value`' % (key, layer_name))
        unit = val.get('unit')
        val = val['value']
    return key, val, unit, source_id


# ---------------------------------------------------------------------------------------------
# the compile
# ---------------------------------------------------------------------------------------------

class Preset(object):
    def __init__(self, surface, values, provenance, fingerprint, fingerprint_scope,
                 account_unit, locked_constants):
        self.surface = surface
        self.values = values                    # OrderedDict name -> rendered str
        self.provenance = provenance            # name -> {'layer':..., 'overridden':[...]}
        self.effective_config_hash = fingerprint
        self.fingerprint_scope = fingerprint_scope
        self.account_unit = account_unit
        self.locked_constants = locked_constants


def compile_preset(surface, layers, account_unit, unit_classes=None, locked_constants=None,
                   enums=None):
    """-> Preset. Refuses; never fills a gap and never converts a currency.

    `layers` is any iterable of Layer. Their ORDER IN THE ARGUMENT IS IGNORED -- rank comes from
    LAYER_ORDER -- so shuffling the caller's list cannot change the output (P3).
    """
    if account_unit not in ACCOUNT_UNITS:
        raise PresetRefusal('account_unit %r is not one of %s' % (account_unit,
                                                                 list(ACCOUNT_UNITS)))
    enums = enums if enums is not None else dict(MQL_BUILTIN_ENUMS)
    unit_classes = unit_classes or {}

    by_layer = {}
    for layer in layers:
        if layer.name in by_layer:
            raise PresetRefusal('layer %s supplied twice' % layer.name)
        by_layer[layer.name] = layer

    resolved = {}
    provenance = {}
    for layer_name in LAYER_ORDER:
        layer = by_layer.get(layer_name)
        if layer is None:
            continue
        seen_here = {}
        for row in layer.rows:
            key, val, unit, source_id = _row_parts(row, layer_name)

            decl = surface.by_name.get(key)
            if decl is None:
                # P2. An ALLOWLIST over the parsed surface: the surface decides, so a key that
                # merely looks plausible has no way in. Case and whitespace are NOT normalised
                # into a match -- `exitmode` is a different string, and quietly accepting it
                # would be the compiler deciding what the author meant.
                raise PresetRefusal(
                    'layer %s sets %r, which build %s does not expose. The accepted keys are '
                    'exactly the %d inputs parsed from the build source -- nothing is matched '
                    'by resemblance. Nearest declared: %s'
                    % (layer_name, key, surface.build_tag, len(surface),
                       ', '.join(_nearest(key, surface)) or 'none'))

            # P7: same-layer disagreement is a refusal; agreement is not.
            if key in seen_here:
                prev_val, prev_src = seen_here[key]
                if _canonical(prev_val) != _canonical(val):
                    raise PresetRefusal(
                        'layer %s gives %s two different values: %r (from %s) and %r (from %s). '
                        'Taking the last one is last-wins across rows that DISAGREE, which is '
                        'the defect `build_tag` was split out to stop. Rank exists BETWEEN '
                        'layers, not inside one.'
                        % (layer_name, key, prev_val, prev_src, val, source_id))
                continue
            seen_here[key] = (val, source_id)

            # P8: the unit is carried, never converted.
            declared_unit_class = unit_classes.get(key)
            if declared_unit_class == UNIT_CONFLICT:
                raise PresetRefusal(
                    'the parameter registry\'s tagged rows DISAGREE about %s\'s unit, so '
                    'whether it is account money is unanswerable. Refused rather than letting '
                    'whichever row was parsed last decide -- last-wins across rows that '
                    'disagree is the defect the registry\'s own resolver refuses as AMBIGUOUS.'
                    % key)
            money = is_money_unit(declared_unit_class)
            if money:
                if unit is None:
                    raise PresetRefusal(
                        '%s is denominated in account money (unit %r in the parameter registry) '
                        'but layer %s supplied a bare number. A money amount without its unit '
                        'cannot be checked against a %s account, and this compiler will not '
                        'assume one.' % (key, declared_unit_class, layer_name, account_unit))
                if unit not in ACCOUNT_UNITS:
                    raise PresetRefusal('%s declares unit %r, which is not one of %s'
                                        % (key, unit, list(ACCOUNT_UNITS)))
                if unit != account_unit:
                    raise PresetRefusal(
                        '%s was declared in %s but this preset compiles for a %s account. This '
                        'compiler does NOT convert: an automatic x100 is a money decision '
                        'nobody authorised, and it would land on a chart looking like a '
                        'validated number. Supply the %s value.'
                        % (key, unit, account_unit, account_unit))
            elif unit is not None:
                if declared_unit_class is None:
                    raise PresetRefusal(
                        '%s carries an account unit (%r) but the parameter registry has no row '
                        'for it, so whether it is money is UNKNOWN. An unknown answer to "does '
                        'this number change meaning with the account unit" is refused, not '
                        'defaulted to no.' % (key, unit))
                raise PresetRefusal(
                    '%s carries an account unit (%r) but its registry unit is %r, which does '
                    'not denominate account money. A unit on a non-money key is a claim about '
                    'the wrong parameter.' % (key, unit, declared_unit_class))

            rendered = render_value(decl, val, enums)
            if key in resolved:
                provenance[key]['overridden'].append(provenance[key]['layer'])
            else:
                provenance[key] = {'layer': None, 'overridden': []}
            resolved[key] = rendered
            provenance[key]['layer'] = layer_name

    # P1. Full surface or nothing. Checked against the PARSED surface, so a build whose surface
    # grows by one input fails here until the new key is supplied -- a hardcoded key list would
    # pass this and be wrong.
    missing = [d.name for d in surface.inputs if d.name not in resolved]
    if missing:
        raise PresetRefusal(
            'partial preset refused: %d of %d inputs on build %s have no value (%s%s). An '
            'unlisted input is filled at run time from the per-terminal tester cache, so a '
            'partial .set does not mean the same thing on two terminals -- it is the ORDER-165 '
            'false-drift mechanism.'
            % (len(missing), len(surface), surface.build_tag, ', '.join(missing[:8]),
               ' ...' if len(missing) > 8 else ''))

    ordered = _ordered(surface, resolved)
    scope, constants = _constant_scope(locked_constants)
    digest = _fingerprint(surface.build_tag, ordered, constants, scope)
    return Preset(surface, ordered, provenance, digest, scope, account_unit, constants)


def _ordered(surface, resolved):
    try:
        from collections import OrderedDict
    except ImportError:                                     # pragma: no cover
        OrderedDict = dict
    return OrderedDict((d.name, resolved[d.name]) for d in surface.inputs)


def _canonical(v):
    if isinstance(v, bool):
        return 'b:%s' % v
    if isinstance(v, (int, float)):
        return 'n:%r' % float(v)
    return 's:%s' % str(v).strip()


def _nearest(key, surface, limit=3):
    low = key.strip().lower()
    return [d.name for d in surface.inputs if d.name.lower() == low][:limit] or \
           [d.name for d in surface.inputs if low and low in d.name.lower()][:limit]


def _constant_scope(locked_constants):
    """The fingerprint's honest name.

    Design section 5.6 wants a hash over every exposed input PLUS every locked constant. Nothing
    enumerates the locked constants yet -- that needs the generated enumeration ORDER-701 owes.
    Until then the scope is `surface_only`, and it SAYS so, both in the manifest and inside the
    hash's own preimage. An incomplete claim gets an incomplete name (memory
    `name-it-honestly-when-you-cannot-prove-it`); silently calling it complete is the failure.
    """
    if not locked_constants:
        return 'surface_only', {}
    constants = dict(locked_constants)
    for k, v in constants.items():
        if not isinstance(k, str) or isinstance(v, (dict, list)):
            raise PresetRefusal('locked constant %r must be a scalar under a string name' % k)
    return 'surface+constants', constants


def _fingerprint(build_tag, ordered_values, constants, scope):
    """sha256 over the CONFIG, and over nothing else.

    In deliberately: the build tag (it selects which code the values reach) and every rendered
    input value. Out deliberately: symbol, timeframe, model, window, lane, account unit, the
    generation time and the file's comment header. Those describe the JOB, not the
    configuration -- an EA at OnInit cannot see most of them, and the question this hash exists
    to answer is "is the .set on this chart the .set we validated".
    """
    lines = ['scope=%s' % scope, 'build=%s' % build_tag]
    lines += ['%s=%s' % (k, v) for k, v in ordered_values.items()]
    lines += ['const:%s=%s' % (k, constants[k]) for k in sorted(constants)]
    return hashlib.sha256('\n'.join(lines).encode('utf-8')).hexdigest()


# ---------------------------------------------------------------------------------------------
# rendering
# ---------------------------------------------------------------------------------------------

def render_set(preset, ranges=None, header_note=None):
    """-> the .set text. Deterministic: no clock, no dict iteration order, no host paths.

    `ranges` maps an input name to (start, step, stop, enabled) for an optimizer pass. A range
    over a key the preset does not hold is refused for the same reason an unknown overlay key
    is: the surface decides.
    """
    ranges = ranges or {}
    for key in ranges:
        if key not in preset.values:
            raise PresetRefusal(
                'optimize range given for %r, which build %s does not expose'
                % (key, preset.surface.build_tag))
    out = []
    if header_note:
        for line in str(header_note).split('\n'):
            out.append('; %s' % line)
    out.append('; build=%s surface=%d effective_config_hash=%s (%s)'
               % (preset.surface.build_tag, len(preset.values), preset.effective_config_hash,
                  preset.fingerprint_scope))
    for name, value in preset.values.items():
        if not _SET_KEY_RE.match(name):
            raise PresetRefusal('input name %r cannot be written to a .set line' % name)
        rng = ranges.get(name)
        if rng is None:
            out.append('%s=%s' % (name, value))
            continue
        start, step, stop, enabled = rng
        # Range bounds go through the SAME canonicalisation as values (/scrutinize round 1:
        # they were written raw, so (1, ...) and (1.0, ...) produced different bytes for one
        # request -- a hole in exactly the determinism P3 asserts for the rest of the line).
        decl = preset.surface.by_name[name]
        out.append('%s=%s||%s||%s||%s||%s'
                   % (name, value,
                      render_value(decl, start, MQL_BUILTIN_ENUMS),
                      render_value(decl, step, MQL_BUILTIN_ENUMS),
                      render_value(decl, stop, MQL_BUILTIN_ENUMS),
                      'Y' if enabled else 'N'))
    return '\n'.join(out) + '\n'


def render_manifest(preset, job, generated_at=None):
    """-> a JSON string naming lane, symbol, TF, model and window ALONGSIDE the preset.

    `generated_at` is an ARGUMENT. Reading a clock in here would make the compiler
    non-deterministic in the one function whose determinism is asserted, and it would put a
    timestamp inside a document whose hash is meant to move only when the config moves.
    """
    required = ('lane', 'symbol', 'timeframe', 'model', 'window_from', 'window_to')
    missing = [k for k in required if not job.get(k)]
    if missing:
        raise PresetRefusal(
            'the manifest must name %s; missing %s. A preset without its lane and window is a '
            'number that cannot be compared to another number -- cross-install comparison is '
            'refused everywhere else in this lab for the same reason.'
            % (', '.join(required), ', '.join(missing)))
    doc = {
        'schema': 'preset_manifest/1',
        'generated_by': 'ORDER-700',
        'build_tag': preset.surface.build_tag,
        'surface_size': len(preset.values),
        'account_unit': preset.account_unit,
        'effective_config_hash': preset.effective_config_hash,
        'fingerprint_scope': preset.fingerprint_scope,
        'fingerprint_excludes': ['symbol', 'timeframe', 'model', 'window', 'lane',
                                 'account_unit', 'generated_at'],
        'locked_constants': dict(preset.locked_constants),
        'layer_order': list(LAYER_ORDER),
        'provenance': dict((k, {'layer': v['layer'], 'overridden': list(v['overridden'])})
                           for k, v in preset.provenance.items()),
        'job': dict((k, job[k]) for k in sorted(job)),
        'generated_at': generated_at,
    }
    return json.dumps(doc, indent=2, sort_keys=True, ensure_ascii=False) + '\n'


# ---------------------------------------------------------------------------------------------
# loaders -- every read goes through the CALLER's source. This module opens no path (P5).
# ---------------------------------------------------------------------------------------------

def load_surface(src, build_tag, rel=INPUTS_REL):
    return parse_surface(src.read_committed(rel), build_tag)


def load_enums(src, rel=INPUTS_REL):
    return parse_enum_table(src.read_committed(rel))


def load_unit_classes(src, rel=PARAM_REGISTRY_REL):
    return parse_unit_classes(src.read_committed(rel))


def load_instrument_profile(src, symbol, rel=INSTRUMENT_PROFILES_REL):
    """-> the profile row for `symbol`. REFUSES when there is none (P6).

    All three factory registries carry comment rows only today, deliberately: a profile asserts
    which broker and lane a symbol trades on, and asserting one nobody measured would be a claim
    about the machine. So this refuses for every symbol right now, and that is the correct
    answer -- what it must NOT do is invent a default profile so a compile can proceed.
    """
    rows = []
    total_rows = 0
    for line in src.read_committed(rel).split('\n'):
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except ValueError as exc:
            raise PresetRefusal('%s has an unparseable row: %s' % (rel, exc))
        if '_comment' in obj and 'symbol' not in obj:
            continue
        total_rows += 1
        if obj.get('symbol') == symbol:
            rows.append(obj)
    if not rows:
        # The explanation is CONDITIONAL on the store actually being empty. An unconditional
        # "empty by design" would become a false statement about the registry the moment its
        # first row lands, for every symbol that is not that row (/scrutinize round 1).
        empty_note = (' The registry holds no rows at all today, by design -- no run has '
                      'measured a broker/lane mapping yet.' if not total_rows else
                      ' The registry holds %d row(s) for other symbols.' % total_rows)
        raise PresetRefusal(
            'no InstrumentProfile row for %r in %s.%s A profile asserts which broker and lane '
            'a symbol trades on; compiling without one would put an invented broker mapping '
            'behind a fingerprint.' % (symbol, rel, empty_note))
    if len(rows) > 1:
        raise PresetRefusal(
            '%d InstrumentProfile rows for %r in %s. Two profiles for one symbol is the '
            'same-layer disagreement of P7 one file up.' % (len(rows), symbol, rel))
    return rows[0]
