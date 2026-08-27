# -*- coding: utf-8 -*-
"""run_preset_tests.py -- ORDER-700 (S6). The preset compiler's cage.

EVERY criterion P1-P8 appears here TWICE:

    ATTACK       the input the criterion exists to refuse. It must be RED.
    SPECIFICITY  the neighbouring input it must NOT refuse, or the property that must NOT move.

That pairing is `docs/GUARD_SHAPES.md` shape 5's mechanical half, and it is not decoration.
Three of the eight criteria have a failure mode where being BROKEN and being CORRECT point the
same way: a compiler that refuses everything passes every attack (P6), a writer that ignores
its inputs is perfectly deterministic (P3), and an assertion that "no read happened" passes
trivially if it cannot detect a read (P5).

AND every criterion carries a MUTATION PROBE. A green case proves nothing until it has been
seen red for its own reason, so `--mutate` rewrites ONE line of a COPY of preset.py, re-runs
that criterion's case, and requires it to go red. The copy matters: this repo has already had
an interrupted suite leave a mutation stranded in a real file and turn two unrelated gates red
(`run_enforcement_status_tests`). Nothing here writes inside the repo.

USAGE  tools\\python312\\python.exe _triage/factory_os/run_preset_tests.py [--mutate]
EXIT   0 = every case behaved as declared - 1 = one did not
"""
import io
import importlib.util
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

import preset as P                                                          # noqa: E402
from evidence import EvidenceSource                                         # noqa: E402

# ---------------------------------------------------------------------------------------------
# fixtures
# ---------------------------------------------------------------------------------------------

# A synthetic build source: two builds, one shared name declared per build (the StackMode shape),
# one enum, one string, one money-denominated input.
FIXTURE_INPUTS = '''
#ifndef LAB_ENTRY_11
#ifndef LAB_ENTRY_12
#define LAB_ENTRY_11
#endif
#endif

enum ENUM_EXIT_MODE
{
   EXIT_FIXED_TP  = 21,   // 21 fixed
   EXIT_ATR_TP    = 22,   // 22 atr
};

input group "=== selectors ==="
input ENUM_EXIT_MODE ExitMode = EXIT_ATR_TP;   // exit
input bool   DryRun   = false;
input double _9_Step  = 300;
input int    _9_Bars  = 55;
input string _MG_File = "regime.csv";          // a // inside the comment
input double _4_TpUsd = 50;
#ifdef LAB_ENTRY_11
input ENUM_STACK_MODE StackMode = EXIT_ATR_TP;   // 91
#endif
#ifdef LAB_ENTRY_12
input ENUM_STACK_MODE StackMode = EXIT_FIXED_TP; // 90
#endif
'''

FIXTURE_REGISTRY = (
    '> prose line that is not CSV\n'
    'name,owner,unit,context\n'
    '"ExitMode","x","enum (21/22)","exit"\n'
    '"DryRun","x","bool","misc"\n'
    '"_9_Step","x","points","grid"\n'
    '"_9_Bars","x","bars","grid"\n'
    '"_MG_File","x","filename","misc"\n'
    '"_4_TpUsd[LAB_ENTRY_11]","x","account money (USD)","exit"\n'
    '"StackMode","x","enum","stack"\n'
)

FIXTURE_PROFILES = (
    '{"_comment": "canonical store, no rows yet"}\n'
    '{"entity": "InstrumentProfile", "symbol": "EURUSD", "lane": "1"}\n'
)

JOB = {'lane': '1', 'symbol': 'EURUSD', 'timeframe': 'H1', 'model': '1',
       'window_from': '2023.01.01', 'window_to': '2025.12.31'}


class FakeSource(object):
    """A source that hands back declared bytes and records what was asked for.

    It is an EvidenceSource by DUCK TYPE only, and that is the point of the library rule: the
    compiler takes whatever source it is given and never reaches for one, so a fixture can hand
    it a synthetic tree without the compiler branching on which mode it is in.
    """

    def __init__(self, files):
        self.files = dict(files)
        self.reads = []

    def read_committed(self, rel, errors='strict'):
        self.reads.append(rel)
        if rel not in self.files:
            raise P.ToolFailure('%s not in this fake source' % rel)
        return self.files[rel]


def fake(**over):
    files = {P.INPUTS_REL: FIXTURE_INPUTS,
             P.PARAM_REGISTRY_REL: FIXTURE_REGISTRY,
             P.INSTRUMENT_PROFILES_REL: FIXTURE_PROFILES}
    files.update(over)
    return FakeSource(files)


def full_layers(mod, **over):
    """Every input of the LAB_ENTRY_11 fixture set, so a case can remove exactly one thing."""
    rows = [('ExitMode', 'EXIT_FIXED_TP'), ('DryRun', True), ('_9_Step', 250),
            ('_9_Bars', 55), ('_MG_File', 'regime.csv'),
            ('_4_TpUsd', {'value': 50, 'unit': 'usd'}), ('StackMode', 22)]
    rows = [(k, over.get(k, v)) for k, v in rows if k not in over.get('_drop', ())]
    return [mod.Layer('defaults', rows)]


def compile_ok(mod, src=None, layers=None, unit='usd', **kw):
    src = src or fake()
    surface = mod.load_surface(src, 'LAB_ENTRY_11')
    # ORDER-1050: `locked_constants` is no longer optional -- omitting it is a REFUSAL, because a
    # `surface_only` preimage cannot match any binary (ConfigFingerprint.mqh hardcodes
    # `surface+constants`). The fixture build genuinely declares no locked constants, so it says
    # so with `{}` rather than by staying silent. A case that wants the refusal calls
    # `compile_preset` directly; a case that wants real constants passes its own.
    kw.setdefault('locked_constants', {})
    return mod.compile_preset(
        surface, layers if layers is not None else full_layers(mod), unit,
        unit_classes=mod.load_unit_classes(src), enums=mod.load_enums(src), **kw)


# ---------------------------------------------------------------------------------------------
# the cases -- (criterion, label, callable). A callable returns None on success, or a reason.
# ---------------------------------------------------------------------------------------------

def refuses(fn, *needles):
    """Run fn; require a PresetRefusal whose text NAMES the thing it refused."""
    try:
        fn()
    except P.PresetRefusal as exc:
        text = str(exc)
        missing = [n for n in needles if n not in text]
        if missing:
            return 'refused, but did not name %s: %s' % (missing, text[:160])
        return None
    except Exception as exc:                                    # noqa: BLE001
        return 'raised %s instead of PresetRefusal: %s' % (type(exc).__name__, exc)
    return 'ACCEPTED -- no refusal at all'


def accepts(fn):
    try:
        fn()
    except Exception as exc:                                    # noqa: BLE001
        return 'refused a valid input: %s: %s' % (type(exc).__name__, str(exc)[:160])
    return None


# -- P1 full surface ---------------------------------------------------------------------------

def p1_attack(mod):
    """one declared input left unset => REFUSE, naming it"""
    return refuses(lambda: compile_ok(mod, layers=full_layers(mod, _drop=('_9_Bars',))),
                   '_9_Bars', 'partial preset refused')


def p1_specificity(mod):
    """the surface DECIDES: grow the build source by one input and the refusal follows it"""
    grown = FIXTURE_INPUTS.replace('input int    _9_Bars  = 55;',
                                   'input int    _9_Bars  = 55;\ninput int _9_New = 7;')
    src = fake(**{P.INPUTS_REL: grown})
    bad = refuses(lambda: compile_ok(mod, src=src), '_9_New')
    if bad:
        return 'a hardcoded key list would have passed here: %s' % bad
    # and once supplied, every OTHER key renders byte-identical to the ungrown compile
    base = mod.render_set(compile_ok(mod))
    grown_set = mod.render_set(compile_ok(
        mod, src=src, layers=[mod.Layer('defaults',
                                        full_layers(mod)[0].rows + [('_9_New', 7)])]))
    base_body = [l for l in base.split('\n') if '=' in l and not l.startswith(';')]
    grown_body = [l for l in grown_set.split('\n')
                  if '=' in l and not l.startswith(';') and not l.startswith('_9_New=')]
    if base_body != grown_body:
        return 'adding one input perturbed the other lines'
    return None


# -- P2 unknown key ----------------------------------------------------------------------------

def p2_attack(mod):
    """an overlay key the build does not expose => REFUSE, naming it"""
    return refuses(
        lambda: compile_ok(mod, layers=[mod.Layer('defaults',
                                                  full_layers(mod)[0].rows + [('_9_Nope', 1)])]),
        '_9_Nope', 'does not expose')


def p2_specificity(mod):
    """allowlist over the PARSED surface, not a name blacklist"""
    # case and whitespace are not normalised into a match ...
    for variant in ('exitmode', 'ExitMode ', 'EXITMODE'):
        rows = [r for r in full_layers(mod)[0].rows if r[0] != 'ExitMode']
        bad = refuses(lambda v=variant: compile_ok(
            mod, layers=[mod.Layer('defaults', rows + [(v, 22)])]), 'does not expose')
        if bad:
            return 'variant %r was matched by resemblance: %s' % (variant, bad)
    # ... and an `input group` header is NOT a key, which is why 209 was once reported as 184
    surface = mod.load_surface(fake(), 'LAB_ENTRY_11')
    if any('===' in d.name or d.name == 'group' for d in surface.inputs):
        return 'an `input group` header entered the surface as an input'
    # ... and the build-excluded declaration is genuinely excluded
    if len(surface) != 7:
        return 'LAB_ENTRY_11 surface is %d inputs, expected 7' % len(surface)
    return None


# -- P3 determinism ----------------------------------------------------------------------------

def p3_attack(mod):
    """two compiles of one request, and a shuffled overlay, are byte-identical"""
    a = mod.render_set(compile_ok(mod))
    b = mod.render_set(compile_ok(mod))
    if a != b:
        return 'two compiles of one request differ'
    rows = full_layers(mod)[0].rows
    shuffled = list(reversed(rows))
    c = mod.render_set(compile_ok(mod, layers=[mod.Layer('defaults', shuffled)]))
    if a != c:
        return 'overlay insertion order leaked into the output'
    # and canonicalisation: 300, 300.0 and "3e2" are ONE value
    forms = [mod.render_set(compile_ok(mod, layers=full_layers(mod, _9_Step=f)))
             for f in (250, 250.0, '2.5e2')]
    if len(set(forms)) != 1:
        return 'three spellings of one number produced %d different files' % len(set(forms))
    # ... including optimize-range bounds (/scrutinize: these were written raw, so (100, ...)
    # and (100.0, ...) produced different bytes for one request)
    pre = compile_ok(mod)
    r1 = mod.render_set(pre, ranges={'_9_Step': (100, 50, 400, True)})
    r2 = mod.render_set(pre, ranges={'_9_Step': (100.0, 50.0, '4e2', True)})
    if r1 != r2:
        return 'two spellings of one optimize range produced different bytes'
    # ... and a SYMBOLIC range bound resolves against the same enum table the values used
    # (round 2: render_set was handed only the MQL builtins, so a file-declared enum symbol
    # that compiled fine as a value refused as a bound)
    try:
        sym = mod.render_set(pre, ranges={'ExitMode': ('EXIT_FIXED_TP', 1, 'EXIT_ATR_TP', True)})
    except mod.PresetRefusal as exc:
        return 'a file-declared enum symbol was refused as a range bound: %s' % str(exc)[:100]
    if 'ExitMode=21||21||1||22||Y' not in sym:
        return 'the symbolic range did not render to its numeric codes'
    return None


def p3_specificity(mod):
    """a writer that ignores its inputs is also deterministic -- one changed value must move both"""
    base = compile_ok(mod)
    moved = compile_ok(mod, layers=full_layers(mod, _9_Step=251))
    if mod.render_set(base) == mod.render_set(moved):
        return 'changing a value did not change the .set'
    if base.effective_config_hash == moved.effective_config_hash:
        return 'changing a value did not change the fingerprint'
    return None


# -- P4 the fingerprint is over the CONFIG -----------------------------------------------------

def p4_attack(mod):
    """every input value is inside the hash"""
    base = compile_ok(mod).effective_config_hash
    for key, val in (('ExitMode', 'EXIT_ATR_TP'), ('DryRun', False), ('_9_Bars', 56),
                     ('_MG_File', 'other.csv'), ('StackMode', 21)):
        if compile_ok(mod, layers=full_layers(mod, **{key: val})).effective_config_hash == base:
            return '%s is not inside the fingerprint' % key
    return None


def p4_specificity(mod):
    """job facts and cosmetics must NOT move it, or it is a file hash wearing a config name"""
    base = compile_ok(mod)
    # a comment header is cosmetic
    if (mod.render_set(base, header_note='hello').count('hello') != 1
            or compile_ok(mod).effective_config_hash != base.effective_config_hash):
        return 'a comment header moved the fingerprint'
    # the whole job -- symbol, TF, model, window, lane -- is manifest, not config
    import json as _json
    m1 = _json.loads(mod.render_manifest(base, JOB, generated_at='2026-07-31T21:00:00'))
    other = dict(JOB, symbol='XAUUSD', timeframe='H4', model='4', lane='5c',
                 window_from='2020.01.01')
    m2 = _json.loads(mod.render_manifest(base, other, generated_at='1999-01-01T00:00:00'))
    if m1['effective_config_hash'] != m2['effective_config_hash']:
        return 'a job field moved the fingerprint'
    # the account unit is not visible to the EA at OnInit, so it is not config either
    cent = compile_ok(mod, unit='cent',
                      layers=full_layers(mod, _4_TpUsd={'value': 50, 'unit': 'cent'}))
    if cent.effective_config_hash != base.effective_config_hash:
        return 'the account unit moved the fingerprint'
    # ORDER-1050. The scope label is the FIRST line of the preimage, and the EA does not derive
    # it -- `ConfigFingerprint.mqh:35` hardcodes `surface+constants`. So a compile that produces
    # `surface_only` produces a digest that cannot match ANY binary, for any `.set`, ever. That
    # is what the live mismatch was: two hand-built `.set` files disagreeing totally rather than
    # subtly, because the recompute was called without `locked_constants` and relabelled instead
    # of refusing.
    #
    # A caller SAYING there are no constants (`{}`) and a caller SAYING NOTHING (`None`) are
    # different claims and must not collapse into one branch. The fixture build has none, and
    # says so, so it still hashes under the label the EA emits:
    if base.fingerprint_scope != 'surface+constants':
        return ('scope is %r; a preimage the EA can never reproduce is not a fingerprint'
                % base.fingerprint_scope)
    # and silence is refused BY NAME -- the message has to say which argument was missing, or the
    # next caller debugs a hash instead of reading a sentence
    src = fake()
    surface = mod.load_surface(src, 'LAB_ENTRY_11')
    bad = refuses(lambda: mod.compile_preset(
        surface, full_layers(mod), 'usd', unit_classes=mod.load_unit_classes(src),
        enums=mod.load_enums(src)), 'locked_constants', 'surface+constants')
    if bad:
        return bad
    withc = compile_ok(mod, locked_constants={'MAX_SLIPPAGE': 3})
    if withc.fingerprint_scope != 'surface+constants' or \
            withc.effective_config_hash == base.effective_config_hash:
        return 'declaring a locked constant neither renamed nor moved the fingerprint'
    return None


# -- P5 must not read the terminal cache -------------------------------------------------------

CACHE_PATH = r'C:\\Users\\x\\AppData\\Roaming\\MetaQuotes\\Terminal\\ABC\\tester\\cache.ini'


class _OpenBan(object):
    """Patch every file-open primitive this process has, and record what tried to use one."""

    def __init__(self):
        self.attempts = []

    def __enter__(self):
        import builtins
        self._b, self._io = builtins.open, io.open

        def banned(*a, **k):
            self.attempts.append(a[0] if a else k.get('file'))
            raise AssertionError('P5: a file was opened during compile: %r'
                                 % (a[0] if a else k.get('file')))
        builtins.open = banned
        io.open = banned
        return self

    def __exit__(self, *exc):
        import builtins
        builtins.open, io.open = self._b, self._io
        return False


def p5_attack(mod):
    """a FULL compile completes with every open() banned -- the compiler owns no path"""
    src = fake()
    with _OpenBan():
        preset_obj = compile_ok(mod, src=src)
        mod.render_set(preset_obj)
        mod.render_manifest(preset_obj, JOB, generated_at='2026-07-31T21:00:00')
    if sorted(set(src.reads)) != sorted(set([P.INPUTS_REL, P.PARAM_REGISTRY_REL])):
        return 'the compiler read %r -- every read must go through the caller`s source' \
               % sorted(set(src.reads))
    return None


def p5_specificity(mod):
    """the ban can FIRE -- otherwise `no read happened` is a claim no instrument could refute"""
    ban = _OpenBan()
    try:
        with ban:
            io.open(CACHE_PATH, encoding='utf-8').read()
    except AssertionError:
        pass
    else:
        return 'the open-ban did not fire on a deliberate tester-cache read'
    if not ban.attempts or 'tester' not in str(ban.attempts[0]):
        return 'the ban fired but recorded nothing identifying'
    return None


# -- P6 refuse rather than invent ---------------------------------------------------------------

def p6_attack(mod):
    """a symbol with no InstrumentProfile row => REFUSE naming it"""
    bad = refuses(lambda: mod.load_instrument_profile(fake(), 'GBPJPY'),
                  'GBPJPY', 'no InstrumentProfile row')
    if bad:
        return bad
    # the explanation must be conditional on the store's actual state: the fixture has one
    # row (EURUSD), so the refusal may not claim the registry is empty
    try:
        mod.load_instrument_profile(fake(), 'GBPJPY')
    except mod.PresetRefusal as exc:
        if 'no rows at all' in str(exc):
            return 'the refusal claims the registry is empty while it holds a row'
        if '1 row(s) for other symbols' not in str(exc):
            return 'the refusal does not state what the registry does hold: %s' % str(exc)[:120]
    return None


def p6_specificity(mod):
    """the refusal must not degrade into `everything fails`, which is P6 broken, not passing"""
    row = mod.load_instrument_profile(fake(), 'EURUSD')
    if row.get('lane') != '1':
        return 'a declared profile row was not returned'
    bad = accepts(lambda: compile_ok(mod))
    if bad:
        return 'a compile needing no profile was refused: %s' % bad
    # and the REAL registry is empty, which is the state this criterion is written against
    real = EvidenceSource('worktree')
    err = refuses(lambda: mod.load_instrument_profile(real, 'EURUSD'), 'EURUSD')
    if err:
        return 'the real registry unexpectedly holds a row: %s' % err
    return None


# -- P7 precedence -----------------------------------------------------------------------------

def p7_attack(mod):
    """two rows INSIDE one layer disagreeing => REFUSE (last-wins is the S7 defect)"""
    rows = full_layers(mod)[0].rows + [('_9_Step', 999, 'row-b')]
    return refuses(lambda: compile_ok(mod, layers=[mod.Layer('defaults', rows)]),
                   '_9_Step', 'two different values')


def p7_specificity(mod):
    """agreement inside a layer is fine; BETWEEN layers the declared rank applies silently"""
    same = full_layers(mod)[0].rows + [('_9_Step', 250.0, 'row-b')]
    if accepts(lambda: compile_ok(mod, layers=[mod.Layer('defaults', same)])):
        return 'two rows AGREEING inside a layer were refused'
    got = compile_ok(mod, layers=[mod.Layer('defaults', full_layers(mod)[0].rows),
                                  mod.Layer('hypothesis', [('_9_Step', 111)])])
    if got.values['_9_Step'] != '111.0':
        return 'a higher-ranked layer did not win: %r' % got.values['_9_Step']
    prov = got.provenance['_9_Step']
    if prov['layer'] != 'hypothesis' or prov['overridden'] != ['defaults']:
        return 'the manifest did not record who won and who was overridden: %r' % prov
    # argument order must not be able to substitute for rank
    flipped = compile_ok(mod, layers=[mod.Layer('hypothesis', [('_9_Step', 111)]),
                                      mod.Layer('defaults', full_layers(mod)[0].rows)])
    if flipped.effective_config_hash != got.effective_config_hash:
        return 'passing the layers in the other order changed the result'
    if accepts(lambda: mod.Layer('made_up', [])) is None:
        return 'an undeclared layer name was accepted, so it has no rank'
    return None


# -- P8 the account unit is carried, never converted --------------------------------------------

def p8_attack(mod):
    """a cent value compiled for a usd account => REFUSE. No automatic x100."""
    return refuses(
        lambda: compile_ok(mod, unit='usd',
                           layers=full_layers(mod, _4_TpUsd={'value': 5000, 'unit': 'cent'})),
        '_4_TpUsd', 'does NOT convert')


def p8_specificity(mod):
    """matching units compile; non-money keys need no unit; an unknown unit is its own refusal"""
    if accepts(lambda: compile_ok(mod, unit='cent',
                                  layers=full_layers(mod,
                                                     _4_TpUsd={'value': 5000, 'unit': 'cent'}))):
        return 'a cent value on a cent account was refused'
    if accepts(lambda: compile_ok(mod)):
        return 'non-money keys were made to carry a unit'
    bare = refuses(lambda: compile_ok(mod, layers=full_layers(mod, _4_TpUsd=50)),
                   '_4_TpUsd', 'account money')
    if bare:
        return 'a bare money number was accepted: %s' % bare
    # a unit attached to a key the registry does not classify is UNKNOWN, not "not money"
    stray = refuses(lambda: compile_ok(mod, src=fake(**{
        P.PARAM_REGISTRY_REL: FIXTURE_REGISTRY.replace(
            '"_4_TpUsd[LAB_ENTRY_11]","x","account money (USD)","exit"\n', '')}),
        layers=full_layers(mod, _4_TpUsd={'value': 50, 'unit': 'usd'})), 'UNKNOWN')
    if stray:
        return 'an unclassified key with a unit was not refused: %s' % stray
    # tagged registry rows that DISAGREE about a unit are a refusal, not last-wins. This is the
    # S7 defect (`build_tag` decision, PROJECT_STATE 2026-07-31) recreated in the unit lookup:
    # with X[LAB_ENTRY_11]=money and X[LAB_ENTRY_12]=pips, whichever row parses last decided P8
    # for both -- and in THIS ordering (money first) the pre-fix parser concluded "not money",
    # accepting a bare number on a key one build calls account money.
    conflicted = fake(**{P.PARAM_REGISTRY_REL: FIXTURE_REGISTRY.replace(
        '"_4_TpUsd[LAB_ENTRY_11]","x","account money (USD)","exit"\n',
        '"_4_TpUsd[LAB_ENTRY_11]","x","account money (USD)","exit"\n'
        '"_4_TpUsd[LAB_ENTRY_12]","x","pips","exit"\n')})
    clash = refuses(lambda: compile_ok(mod, src=conflicted,
                                       layers=full_layers(mod, _4_TpUsd=50)),
                    '_4_TpUsd', 'DISAGREE')
    if clash:
        return 'disagreeing tagged unit rows were resolved by last-wins: %s' % clash
    # ... and rows that AGREE are not a conflict
    agreeing = fake(**{P.PARAM_REGISTRY_REL: FIXTURE_REGISTRY.replace(
        '"_4_TpUsd[LAB_ENTRY_11]","x","account money (USD)","exit"\n',
        '"_4_TpUsd[LAB_ENTRY_11]","x","account money (USD)","exit"\n'
        '"_4_TpUsd[LAB_ENTRY_12]","x","account money (USD)","exit"\n')})
    if accepts(lambda: compile_ok(mod, src=agreeing,
                                  layers=full_layers(mod,
                                                     _4_TpUsd={'value': 50, 'unit': 'usd'}))):
        return 'two tagged rows AGREEING on a unit were refused as a conflict'
    return None


# -- P9 the REAL build source, not only the fixture ---------------------------------------------

def _real_text():
    return EvidenceSource('worktree').read_committed(P.INPUTS_REL)


def p9_attack(mod):
    """`#ifdef LAB_ENTRY_nn` is EVALUATED on the real file, not skipped over

    The real `Inputs.mqh` declares `StackMode` eight times, once per build. A parser that
    ignores the branches sees all eight and cannot say what any build exposes -- and the whole
    fixture suite above would still be green, because the fixture is small enough to be right
    for the wrong reason. That is `GUARD_SHAPES.md` shape 5's third row: the mechanism never
    engaging, with the acceptance test unable to tell.
    """
    try:
        text = _real_text()
        a = mod.parse_surface(text, 'LAB_ENTRY_11')
        b = mod.parse_surface(text, 'LAB_ENTRY_14')
    except mod.PresetRefusal as exc:
        return 'the real source did not parse per build: %s' % str(exc)[:160]
    if 'StackMode' not in a.by_name or 'StackMode' not in b.by_name:
        return 'StackMode is missing from a real build surface'
    if a.by_name['StackMode'].default_expr == b.by_name['StackMode'].default_expr:
        return ('StackMode has the same declared default on LAB_ENTRY_11 and LAB_ENTRY_14, so '
                'the #ifdef branches are not being selected')
    return None


def p9_specificity(mod):
    """all declared builds parse, legacy builds remain present, and an unknown tag is refused"""
    text = _real_text()
    enums = mod.parse_enum_table(text)
    tags = sorted(mod.known_build_tags(text))
    required = {'LAB_ENTRY_%d' % n for n in range(11, 19)}
    missing = sorted(required.difference(tags))
    if missing:
        return 'the real source lost required build tags: %s' % ', '.join(missing)
    sizes = {}
    for tag in tags:
        surface = mod.parse_surface(text, tag)
        sizes[tag] = len(surface)
        for decl in surface.inputs:
            try:
                mod.render_value(decl, decl.default_expr, enums)
            except mod.PresetRefusal as exc:
                return ('%s default %r on %s does not resolve: %s'
                        % (decl.name, decl.default_expr, tag, str(exc)[:90]))
    if not all(100 <= n <= 173 for n in sizes.values()):
        return 'a real build surface is outside the measured current R4 band (max 173): %r' % sizes
    bad = refuses(lambda: mod.parse_surface(text, 'LAB_ENTRY_99'), 'LAB_ENTRY_99')
    if bad:
        return 'an undeclared build tag was accepted: %s' % bad
    return None


def _long(mod):
    return mod.InputDecl('Magic', 'long', '0', 1)


def p10_attack(mod):
    """ORDER-1266 #2 and #7: an integer type never routes through float, and every rejection
    leaves through the DECLARED refusal set.

    #2 measured at HEAD before the repair: `9007199254740992e0` and `...93e0` both rendered as
    `9007199254740992` and hashed identically, because any exponent spelling took the float
    branch. Above 2^53 a float64 has no bit left to separate consecutive integers. This is the
    attack rather than a smaller one because MAGIC NUMBERS are the values this repo must never
    conflate -- `magic.py` is append-only and refuses renumbering for exactly that reason.
    """
    d = _long(mod)
    enums = dict(mod.MQL_BUILTIN_ENUMS)
    a = mod.render_value(d, '9007199254740992e0', enums)
    b = mod.render_value(d, '9007199254740993e0', enums)
    if a == b:
        return ('two consecutive longs above 2^53 rendered identically (%s) -- they share a '
                'fingerprint, and a shared fingerprint over two magics is a re-attributed deal '
                'history' % a)
    # #7: the declared set is {PresetRefusal, ToolFailure}. A caller catching it does not catch
    # OverflowError or ValueError, so a verdict about the input arrives as a broken tool.
    for spell in ('nan', 'inf', '1e9999'):
        try:
            mod.render_value(d, spell, enums)
            return '%r on a long was ACCEPTED' % spell
        except mod.PresetRefusal:
            pass
        except Exception as exc:                                        # noqa: BLE001
            return ('%r on a long left as %s, which is outside the declared refusal set this '
                    'module\'s own docstring names' % (spell, type(exc).__name__))
    return None


def p10_specificity(mod):
    """the ordinary numbers it must NOT start refusing, and the canonicalisation it must keep"""
    d = _long(mod)
    enums = dict(mod.MQL_BUILTIN_ENUMS)
    # one value, three spellings, still one rendering -- P3's rule, re-checked at the boundary
    # this case moved, because "make longs exact" is one bad edit away from "stop canonicalising"
    if len(set(mod.render_value(d, f, enums) for f in ('250', '250.0', '2.5e2'))) != 1:
        return 'three spellings of 250 no longer render as one value'
    # the extremes a long legitimately holds must round-trip, or the range check is a size limit
    for edge in ('9223372036854775807', '-9223372036854775808', '0'):
        if mod.render_value(d, edge, enums) != edge:
            return 'a long at its own limit (%s) did not round-trip' % edge
    # and a double is still a double: float64 precision is the TYPE's, not the parser's to fix
    dd = mod.InputDecl('Ratio', 'double', '0.0', 1)
    if mod.render_value(dd, '1.5', enums) != '1.5':
        return 'a plain double stopped rendering as itself'
    return None


CASES = (
    # The P1 mutant models the defect that actually happens: silently completing the set from
    # the declared defaults instead of refusing. `if False and missing:` would only make the
    # compiler CRASH later, and a crash is not the failure this criterion is about.
    ('P1', 'full surface: a missing input is refused by name', p1_attack, p1_specificity,
     ('    missing = [d.name for d in surface.inputs if d.name not in resolved]',
      '    for _d in surface.inputs:\n'
      '        if _d.name not in resolved:\n'
      '            resolved[_d.name] = render_value(_d, _d.default_expr, enums)\n'
      "            provenance[_d.name] = {'layer': 'defaults', 'overridden': []}\n"
      '    missing = []')),
    ('P2', 'unknown key: the parsed surface is the allowlist', p2_attack, p2_specificity,
     ('            decl = surface.by_name.get(key)',
      '            decl = surface.by_name.get(key) or surface.inputs[0]')),
    ('P3', 'determinism: one request, one file', p3_attack, p3_specificity,
     ("'%s=%s' % (k, canonical_for_hash(surface.by_name[k], v))",
      "'%s' % (k,)")),
    ('P4', 'the fingerprint is over the config, not the job', p4_attack, p4_specificity,
     ('    digest = _fingerprint(surface, ordered, constants, scope)',
      '    digest = _fingerprint(surface, ordered, constants, scope + account_unit)')),
    ('P5', 'no path of its own: the terminal cache is unreachable', p5_attack, p5_specificity,
     ('    enums = enums if enums is not None else dict(MQL_BUILTIN_ENUMS)',
      '    enums = enums if enums is not None else dict(MQL_BUILTIN_ENUMS)\n'
      '    import io as _cacheio; _cacheio.open(%r).read()' % CACHE_PATH)),
    ('P6', 'refuse rather than invent a missing registry row', p6_attack, p6_specificity,
     ('    if not rows:',
      "    if not rows:\n        return {'symbol': symbol, 'lane': 'invented'}\n    if False:")),
    ('P7', 'precedence is declared, never accidental', p7_attack, p7_specificity,
     ('                if _canonical(prev_val) != _canonical(val):',
      '                if False:')),
    ('P8', 'the account unit is carried, never converted', p8_attack, p8_specificity,
     ('                if unit != account_unit:', '                if False:')),
    ('P9', 'the REAL Inputs.mqh, parsed per build', p9_attack, p9_specificity,
     ('            stack.append(stripped.split(None, 1)[1].strip() in defined)',
      '            stack.append(True)')),
    # The mutant restores the EXACT pre-repair spelling of the defect -- an integer routed
    # through float -- rather than disabling a branch, so what goes red is the collision itself.
    ('P10', 'an integer type never routes through float, and every rejection is DECLARED',
     p10_attack, p10_specificity,
     ('        # because the defect was one line.\n        return int(d)',
      '        # because the defect was one line.\n        return int(float(d))')),
)


# ---------------------------------------------------------------------------------------------
# mutation probes -- a green case proves nothing until it has been seen red for its own reason
# ---------------------------------------------------------------------------------------------

def load_mutant(old, new):
    """preset.py with ONE line rewritten, imported from a TEMP copy.

    The real file is never opened for writing. `old` must appear EXACTLY ONCE: a search string
    that matches zero places mutates nothing and the probe would report a false green, and one
    that matches twice is mutating something the label does not name.
    """
    src = io.open(os.path.join(HERE, 'preset.py'), encoding='utf-8').read()  # snapshot: worktree
    hits = src.count(old)
    if hits != 1:
        raise AssertionError('mutation anchor matched %d times, expected 1: %r' % (hits, old))
    tmp = tempfile.mkdtemp(prefix='presetmut_')
    path = os.path.join(tmp, 'preset_mutant.py')
    io.open(path, 'w', encoding='utf-8', newline='\n').write(src.replace(old, new))
    spec = importlib.util.spec_from_file_location('preset_mutant', path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.__mutant_dir__ = tmp
    return mod


def main(argv):
    os.chdir(ROOT)
    bad = 0
    print('=== ORDER-700 preset compiler: %d criteria, each with an attack and a specificity '
          'half ===' % len(CASES))
    for cid, label, attack, spec, _mut in CASES:
        for kind, fn in (('attack', attack), ('specificity', spec)):
            why = fn(P)
            ok = why is None
            bad += 0 if ok else 1
            print('  [%s] %-3s %-11s %-52s' % ('OK ' if ok else 'BAD', cid, kind, label[:52]))
            if not ok:
                print('        -> %s' % why)

    if '--mutate' in argv:
        print('\n=== mutation probes: break the mechanism, the case must go RED ===')
        for cid, label, attack, spec, (old, new) in CASES:
            try:
                mod = load_mutant(old, new)
            except AssertionError as exc:
                print('  [BAD] %-3s could not build its mutant: %s' % (cid, exc))
                bad += 1
                continue
            try:
                a = attack(mod)
                s = spec(mod)
            except Exception as exc:                            # noqa: BLE001
                a, s = 'raised %s: %s' % (type(exc).__name__, str(exc)[:80]), None
            caught = (a is not None) or (s is not None)
            bad += 0 if caught else 1
            print('  [%s] %-3s mutant   %-52s %s'
                  % ('OK ' if caught else 'BAD', cid, label[:52],
                     'DETECTED' if caught else 'WENT GREEN -- this case cannot fail'))
            if caught:
                print('        -> %s' % (a or s)[:120])
            import shutil
            shutil.rmtree(getattr(mod, '__mutant_dir__', ''), ignore_errors=True)

    if bad:
        print('\n=== %d CASE(S) DID NOT BEHAVE AS DECLARED ===' % bad)
        return 1
    print('\n=== every criterion refused its attack, allowed its neighbour, and (with --mutate) '
          'was seen red for its own reason ===')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
