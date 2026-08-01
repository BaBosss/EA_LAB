# -*- coding: utf-8 -*-
"""ORDER-710's cage: every criterion below gets an attack, a specificity half and a mutation.

WHAT IT CANNOT DO, said first because it decides how to read a green run. This suite does not
execute MQL5. It cannot prove that MetaTrader's `CryptEncode(CRYPT_HASH_SHA256, ...)` and
Python's `hashlib.sha256` agree on the same bytes -- only a tester run can, and ORDER-710's
acceptance keeps that run as the evidence it accepts (`docs/` records the measured pair). What
this suite proves is everything up to that line, and in particular the part that would rot
silently afterwards:

  G1  the committed enumeration is what the generator produces from the committed `Inputs.mqh`
  G2  the enumeration is actually wired into a build
  G3  the two constants that are NOT in the generated file -- the scope label and the lowercase
      hex alphabet -- still agree with the Python side
  X1  the generated MQL5 enumerates EXACTLY the parsed surface, in order, through the
      canonicaliser its declared type requires -- read out of the emitted source, not assumed
  X2  the canonical double form is a function of the VALUE, never of the spelling, and is the
      fixed-width lowercase hex the MQL5 side emits
  X3  a type with no canonical MQL5 form is REFUSED, never emitted through a default

X1 is the one that earns its place. G1 keeps the copy current; X1 is what notices that "current"
was generated wrongly -- e.g. an `int` routed through the double canonicaliser, which would emit
a perfectly valid file, hash cleanly on both sides, and disagree.

USAGE  tools\\python312\\python.exe _triage/factory_os/run_input_surface_tests.py [--mutate]
"""
import importlib.util
import io
import os
import re
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

import check_input_surface_gen as CHK   # noqa: E402
import gen_input_surface as GEN         # noqa: E402
import preset                           # noqa: E402

# A minimal input source with two builds and one of every type this chassis declares. Small on
# purpose: the REAL Inputs.mqh is exercised by X1's specificity half, and a fixture that is a
# copy of the real file tests the copy rather than the mechanism.
FIXTURE_INPUTS = '''
#ifndef LAB_ENTRY_11
#ifndef LAB_ENTRY_12
#define LAB_ENTRY_11
#endif
#endif

enum ENUM_EXIT_MODE
{
   EXIT_FIXED_TP = 21,
   EXIT_ATR_TP   = 22
};

input group "core"
input bool   DryRun      = false;   // a bool
input double _9_Step     = 300.0;   // a double
input int    _9_Bars     = 20;      // an int
input long   _MG_Magic   = 990001;  // a long
input string _MG_File    = "x.csv"; // a string
input ENUM_EXIT_MODE ExitMode = EXIT_ATR_TP;
input ENUM_TIMEFRAMES _TF = PERIOD_H4;
#ifdef LAB_ENTRY_12
input double _12_Only    = 1.5;
#endif
'''

REAL_CORE = 'ea_template/core/LabCore.mqh'


class Mods(object):
    """The three modules under test, passed to every case as ONE handle.

    Why not module-level imports: `--mutate` replaces ONE of them with a rewritten copy, and a
    case that reached for the module-level name would silently test the ORIGINAL while its
    label claimed otherwise -- a probe that cannot fail, which is the shape this suite exists
    to refuse. Every case reads its modules off this object, so the mutant is unavoidable.
    """

    def __init__(self, chk, gen, pre):
        self.chk = chk
        self.gen = gen
        self.preset = pre


class FakeSource(object):
    """An EvidenceSource shaped like the real one, over a dict. ONE mode, like the real one."""

    def __init__(self, files, mode='index'):
        self.files = dict(files)
        self.mode = mode

    def read_committed(self, rel, errors='strict'):
        rel = rel.replace(os.sep, '/')
        if rel not in self.files:
            raise CHK.ToolFailure('%s is not in the fixture source' % rel)
        return self.files[rel]

    def marker(self, component):
        return '##EVIDENCE-MODE## %s %s git_index=fixture' % (component, self.mode)


def real_file(rel):
    """A real repo file used as a FIXTURE INPUT, never as a verdict. Worktree on purpose: these
    cases inject their own content and assert on the checker, not on the repository."""
    return io.open(os.path.join(ROOT, rel.replace('/', os.sep)),
                   encoding='utf-8-sig').read()  # snapshot: worktree -- a FIXTURE, not a verdict


def real_core_text():
    return real_file(REAL_CORE)


def files_for(M, inputs_text=FIXTURE_INPUTS, gen_text=None, core_text=None, fp_text=None):
    return {
        M.chk.INPUTS_PATH: inputs_text,
        M.chk.GEN_PATH: M.gen.emit(inputs_text) if gen_text is None else gen_text,
        M.chk.CORE_PATH: real_core_text() if core_text is None else core_text,
        M.chk.FP_PATH: real_file(M.chk.FP_PATH) if fp_text is None else fp_text,
    }


def problems_for(M, **kw):
    probs, _info = M.chk.check(source=FakeSource(files_for(M, **kw)))
    return probs


# -- G1 the committed enumeration matches the committed surface --------------------------------

def g1_attack(M):
    """an input added to Inputs.mqh without regenerating must be REFUSED"""
    stale = M.gen.emit(FIXTURE_INPUTS)
    grown = FIXTURE_INPUTS.replace('input int    _9_Bars     = 20;',
                                   'input int    _9_Bars     = 20;\ninput int _9_New = 7;')
    probs = problems_for(M, inputs_text=grown, gen_text=stale)
    if not any(GEN.OUT_REL in p for p in probs):
        return 'a surface that grew by one input left the stale enumeration accepted'
    # ...and the reverse vintage too: regenerated file, un-regenerated source.
    probs = problems_for(M, inputs_text=FIXTURE_INPUTS,
                         gen_text=M.gen.emit(grown))
    if not any(GEN.OUT_REL in p for p in probs):
        return 'an enumeration ahead of its source was accepted'
    return None


def g1_specificity(M):
    """a consistent pair passes, and so does the REAL repository right now"""
    if problems_for(M):
        return 'a freshly generated pair was refused: %s' % problems_for(M)
    # CRLF must not read as drift: core.autocrlf gives the index LF and the worktree CRLF, so a
    # comparison that did not fold would refuse the same file it just generated.
    crlf = M.gen.emit(FIXTURE_INPUTS).replace('\n', '\r\n')
    if problems_for(M, gen_text=crlf):
        return 'the same enumeration in CRLF was reported as drift'
    real_inputs = io.open(os.path.join(ROOT, M.preset.INPUTS_REL.replace('/', os.sep)),
                          encoding='utf-8-sig').read()   # snapshot: worktree -- fixture input
    real_gen = io.open(os.path.join(ROOT, GEN.OUT_REL.replace('/', os.sep)),
                       encoding='utf-8-sig').read()      # snapshot: worktree -- fixture input
    probs = problems_for(M, inputs_text=real_inputs, gen_text=real_gen)
    if probs:
        return 'the REAL committed pair is refused: %s' % probs
    return None


# -- G2 the enumeration is wired into a build --------------------------------------------------

def g2_attack(M):
    """an enumeration nothing includes, or nothing calls, is not a fingerprint"""
    core = real_core_text()
    commented = core.replace('#include "InputSurface_gen.mqh"',
                             '//#include "InputSurface_gen.mqh"')
    if not any('#include' in p for p in problems_for(M, core_text=commented)):
        return 'a commented-out include was accepted'
    silent = re.sub(r'CFG_Fingerprint\s*\(\s*\)', 'CFG_NothingAtAll_()', core)
    if not any('CFG_Fingerprint' in p for p in problems_for(M, core_text=silent)):
        return 'a build that never calls CFG_Fingerprint() was accepted'
    return None


def g2_specificity(M):
    """the real LabCore.mqh passes, and a trailing comment on the include is not a violation"""
    if problems_for(M):
        return 'the real LabCore.mqh was refused'
    core = real_core_text().replace('#include "InputSurface_gen.mqh"',
                                    '#include "InputSurface_gen.mqh"')
    if problems_for(M, core_text=core):
        return 'the include line was refused for carrying a trailing comment'
    return None


# -- G3 the two constants that live OUTSIDE the generated file ---------------------------------

def g3_attack(M):
    """a scope label or a hex alphabet edited on ONE side must be REFUSED"""
    real = real_file(M.chk.FP_PATH)
    renamed = real.replace('#define CFG_FP_SCOPE "surface_only"',
                           '#define CFG_FP_SCOPE "surface+constants"')
    if renamed == real:
        return 'the fixture could not rename CFG_FP_SCOPE -- the anchor no longer matches the file'
    if not any(p.startswith('G3') for p in problems_for(M, fp_text=renamed)):
        return 'a scope label that disagrees with preset._constant_scope() was accepted'
    upper = real.replace('"0123456789abcdef"', '"0123456789ABCDEF"')
    if upper == real:
        return 'the fixture could not upper-case the hex alphabet -- the anchor no longer matches'
    if not any(p.startswith('G3') for p in problems_for(M, fp_text=upper)):
        return 'an UPPERCASE hex alphabet was accepted, and it moves every digest the EA prints'
    gone = real.replace('#define CFG_FP_SCOPE', '// #define CFG_FP_SCOPE')
    if not any(p.startswith('G3') for p in problems_for(M, fp_text=gone)):
        return 'a missing CFG_FP_SCOPE define was accepted -- an unreadable label is not a match'
    return None


def g3_specificity(M):
    """the REAL pair agrees, and G3 does not fire on an unrelated edit to the same file"""
    if problems_for(M):
        return 'the real ConfigFingerprint.mqh was refused: %s' % problems_for(M)
    noisy = real_file(M.chk.FP_PATH) + '\n// a comment added by an unrelated commit\n'
    if problems_for(M, fp_text=noisy):
        return 'an added comment was reported as a contract violation'
    return None


# -- X1 the emitted MQL5 enumerates the parsed surface, through the right canonicaliser ---------

EMIT_RE = re.compile(r'^   s \+= "\\n([A-Za-z_][A-Za-z0-9_]*)=" \+ (CFG_Canon[A-Za-z]+)\(([^;]*)\);$')
HEADER_RE = re.compile(r'^   string s = "scope=" \+ CFG_FP_SCOPE \+ "\\nbuild=([A-Z_0-9]+)";$')
EXPECT_CANON = {'bool': 'CFG_CanonBool', 'double': 'CFG_CanonDouble', 'int': 'CFG_CanonLong',
                'long': 'CFG_CanonLong', 'string': 'CFG_CanonString'}


def read_back(text, tag):
    """The emitted block for one tag -> [(name, canon_fn, arg)], and the header's build tag."""
    lines = text.split('\n')
    try:
        start = lines.index('#ifdef %s' % tag)
    except ValueError:
        raise AssertionError('no emitted block for %s' % tag)
    end = lines.index('#endif', start)
    build = None
    rows = []
    for line in lines[start:end]:
        m = HEADER_RE.match(line)
        if m:
            build = m.group(1)
            continue
        m = EMIT_RE.match(line)
        if m:
            rows.append((m.group(1), m.group(2), m.group(3)))
    return build, rows


def x1_attack(M):
    """read the emitted source back: same names, same order, right canonicaliser, per build"""
    for tag in sorted(M.preset.known_build_tags(FIXTURE_INPUTS)):
        surface = M.preset.parse_surface(FIXTURE_INPUTS, tag)
        build, rows = read_back(M.gen.emit(FIXTURE_INPUTS), tag)
        if build != tag:
            return '%s: the preimage header says build=%r' % (tag, build)
        if [r[0] for r in rows] != [d.name for d in surface.inputs]:
            return ('%s: the emitted enumeration is not the parsed surface in order '
                    '(%d emitted vs %d parsed)' % (tag, len(rows), len(surface)))
        for (name, fn, arg), decl in zip(rows, surface.inputs):
            want = EXPECT_CANON.get(decl.mql_type,
                                    'CFG_CanonLong' if decl.mql_type.startswith('ENUM_') else '?')
            if fn != want:
                return '%s: %s is %s and was emitted through %s, not %s' % (
                    tag, name, decl.mql_type, fn, want)
            if decl.name not in arg:
                return '%s: %s is hashed from the expression %r' % (tag, name, arg)
    return None


def x1_specificity(M):
    """the same read-back over the REAL Inputs.mqh -- all 8 builds, every declared type"""
    text = io.open(os.path.join(ROOT, M.preset.INPUTS_REL.replace('/', os.sep)),
                   encoding='utf-8-sig').read()          # snapshot: worktree -- fixture input
    emitted = M.gen.emit(text)
    seen = 0
    for tag in sorted(M.preset.known_build_tags(text)):
        surface = M.preset.parse_surface(text, tag)
        build, rows = read_back(emitted, tag)
        if build != tag or [r[0] for r in rows] != [d.name for d in surface.inputs]:
            return '%s: the real surface is not emitted in order' % tag
        for (name, fn, _arg), decl in zip(rows, surface.inputs):
            want = EXPECT_CANON.get(decl.mql_type,
                                    'CFG_CanonLong' if decl.mql_type.startswith('ENUM_') else '?')
            if fn != want:
                return '%s: %s (%s) -> %s' % (tag, name, decl.mql_type, fn)
            seen += 1
    if seen < 900:
        return 'only %d real inputs were read back; the emitter cannot have covered 8 builds' % seen
    return None


# -- X2 the canonical double is a function of the value, not the spelling ----------------------

def x2_attack(M):
    """three spellings of one number are one preimage; -0.0 is +0.0; different values differ"""
    canon = M.preset.canonical_double
    if len(set(canon(v) for v in (300, 300.0, '300', '3e2', '300.000'))) != 1:
        return 'five spellings of 300 produced more than one canonical form'
    if canon(-0.0) != canon(0.0):
        return '-0.0 and 0.0 canonicalise differently, so a sign on a zero would move the hash'
    if canon(0.1) == canon(0.2) or canon(1.0) == canon(1.0000000000000002):
        return 'two different doubles share one canonical form'
    for v in (0.0, 0.1, -2.5, 1e-5, 1.7976931348623157e308):
        got = canon(v)
        if not re.match(r'^0x[0-9a-f]{16}$', got):
            return ('%r canonicalised to %r, which the MQL5 side cannot produce: CFG_HexLower '
                    'emits exactly 16 lowercase hex digits' % (v, got))
    return None


def x2_specificity(M):
    """the value still reaches the fingerprint -- a canonicaliser that ignores it is not one"""
    a = M.preset.canonical_for_hash(M.preset.InputDecl('x', 'double', '0', 1), '0.30')
    b = M.preset.canonical_for_hash(M.preset.InputDecl('x', 'double', '0', 1), '0.31')
    if a == b:
        return 'two different doubles reached the same canonical form'
    # the non-double types pass through as the .set text, which is what the EA re-emits
    if M.preset.canonical_for_hash(M.preset.InputDecl('b', 'bool', '0', 1), 'true') != 'true':
        return 'a bool did not survive canonicalisation as true/false'
    if M.preset.canonical_for_hash(M.preset.InputDecl('i', 'int', '0', 1), '-7') != '-7':
        return 'an int did not survive canonicalisation as a decimal'
    if M.preset.canonical_for_hash(M.preset.InputDecl('e', 'ENUM_EXIT_MODE', '0', 1), '22') != '22':
        return 'an enum did not survive canonicalisation as its integer code'
    return None


# -- X3 an unknown type is refused, never defaulted --------------------------------------------

def x3_attack(M):
    """a declared type with no canonical MQL5 form must refuse, not emit something plausible"""
    exotic = FIXTURE_INPUTS.replace('input int    _9_Bars     = 20;',
                                    'input color  _9_Tint     = clrRed;')
    try:
        M.gen.emit(exotic)
    except M.preset.PresetRefusal as exc:
        if '_9_Tint' not in str(exc):
            return 'refused without naming the input: %s' % exc
        return None
    return 'a `color` input was emitted through some default canonicaliser'


def x3_specificity(M):
    """every type the real chassis declares IS emittable -- the refusal is not blanket"""
    text = io.open(os.path.join(ROOT, M.preset.INPUTS_REL.replace('/', os.sep)),
                   encoding='utf-8-sig').read()          # snapshot: worktree -- fixture input
    try:
        M.gen.emit(text)
    except M.preset.PresetRefusal as exc:
        return 'the real Inputs.mqh cannot be emitted: %s' % exc
    return None


CASES = [
    ('G1', 'the committed enumeration is the committed surface', g1_attack, g1_specificity,
     ('check_input_surface_gen.py',
      '    if _fold(committed_gen) != _fold(expected):',
      '    if False:')),
    ('G2', 'the enumeration is wired into a build', g2_attack, g2_specificity,
     ('check_input_surface_gen.py',
      '    if not INCLUDE_RE.search(_fold(core_text)):',
      '    if False:')),
    ('G3', 'the scope label and hex alphabet agree across the two languages', g3_attack,
     g3_specificity,
     ('check_input_surface_gen.py',
      "    elif m.group(1) != want_scope:",
      "    elif False:")),
    ('X1', 'the emitted MQL5 is the parsed surface, in order', x1_attack, x1_specificity,
     ('gen_input_surface.py',
      "    if decl.mql_type in _CANON_CALL:\n        return _CANON_CALL[decl.mql_type] % decl.name",
      "    if decl.mql_type in _CANON_CALL:\n        return 'CFG_CanonDouble(%s)' % decl.name")),
    ('X2', 'the canonical double is the value, not the spelling', x2_attack, x2_specificity,
     ('preset.py',
      "    return '0x%016x' % struct.unpack('>Q', struct.pack('>d', v))[0]",
      "    return '0x%x' % struct.unpack('>Q', struct.pack('>d', v))[0]")),
    ('X3', 'an unknown type is refused, never defaulted', x3_attack, x3_specificity,
     ('gen_input_surface.py',
      "    if decl.mql_type.startswith('ENUM_'):",
      "    if True:")),
]

# The import order of the three modules under test. A mutant is installed under its own name and
# EVERYTHING DOWNSTREAM OF IT IS RE-IMPORTED, so the mutation actually reaches the code being
# probed. Skipping that step is how a mutation suite runs 5 probes against 5 pristine modules and
# prints DETECTED for none of them.
CHAIN = ('preset', 'gen_input_surface', 'check_input_surface_gen')


def _fresh(name):
    """(re)import one module of the chain from its REAL path, binding to whatever is in
    sys.modules right now."""
    sys.modules.pop(name, None)
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, name + '.py'))
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def load_mutant(filename, old, new):
    """-> (Mods, tmpdir, saved). ONE line of ONE module rewritten, in a temp copy.

    The real file is never opened for writing. `old` must appear EXACTLY ONCE: an anchor matching
    zero places mutates nothing and the probe reports a false green (ORDER-700's suite earned
    that check on its first run), and one matching twice mutates something the label does not
    name.
    """
    name = os.path.splitext(filename)[0]
    if name not in CHAIN:
        raise AssertionError('%s is not one of the modules this suite can mutate' % filename)
    src = io.open(os.path.join(HERE, filename), encoding='utf-8').read()  # snapshot: worktree
    hits = src.count(old)
    if hits != 1:
        raise AssertionError('mutation anchor matched %d times, expected 1: %r' % (hits, old))
    tmp = tempfile.mkdtemp(prefix='surfmut_')
    path = os.path.join(tmp, filename)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(src.replace(old, new))
    saved = dict((k, sys.modules[k]) for k in CHAIN if k in sys.modules)
    try:
        loaded = {}
        for step in CHAIN:
            if step == name:
                sys.modules.pop(step, None)
                spec = importlib.util.spec_from_file_location(step, path)
                mod = importlib.util.module_from_spec(spec)
                sys.modules[step] = mod
                spec.loader.exec_module(mod)
                loaded[step] = mod
            elif CHAIN.index(step) > CHAIN.index(name):
                loaded[step] = _fresh(step)          # downstream: must see the mutant
            else:
                loaded[step] = sys.modules[step]     # upstream: unchanged
        return (Mods(loaded['check_input_surface_gen'], loaded['gen_input_surface'],
                     loaded['preset']), tmp, saved)
    except Exception:
        sys.modules.update(saved)
        shutil.rmtree(tmp, ignore_errors=True)
        raise


def restore(saved):
    for k in CHAIN:
        sys.modules.pop(k, None)
    sys.modules.update(saved)


def main(argv):
    os.chdir(ROOT)
    bad = 0
    print('=== ORDER-710 input-surface enumeration: %d criteria, attack + specificity ==='
          % len(CASES))
    live = Mods(CHK, GEN, preset)
    for cid, label, attack, spec, _mut in CASES:
        for kind, fn in (('attack', attack), ('specificity', spec)):
            why = fn(live)
            ok = why is None
            bad += 0 if ok else 1
            print('  [%s] %-3s %-11s %-52s' % ('OK ' if ok else 'BAD', cid, kind, label[:52]))
            if not ok:
                print('        -> %s' % why)

    if '--mutate' in argv:
        print('\n=== mutation probes: break the mechanism, the case must go RED ===')
        for cid, label, attack, spec, (filename, old, new) in CASES:
            saved, tmp = {}, ''
            try:
                mutated, tmp, saved = load_mutant(filename, old, new)
            except AssertionError as exc:
                print('  [BAD] %-3s could not build its mutant: %s' % (cid, exc))
                bad += 1
                continue
            try:
                a = attack(mutated)
                s = spec(mutated)
            except Exception as exc:                            # noqa: BLE001
                a, s = 'raised %s: %s' % (type(exc).__name__, str(exc)[:80]), None
            caught = (a is not None) or (s is not None)
            bad += 0 if caught else 1
            print('  [%s] %-3s mutant   %-52s %s'
                  % ('OK ' if caught else 'BAD', cid, label[:52],
                     'DETECTED' if caught else 'WENT GREEN -- this case cannot fail'))
            if caught:
                print('        -> %s' % (a or s)[:120])
            shutil.rmtree(tmp, ignore_errors=True)
            restore(saved)

    if bad:
        print('\n=== %d CASE(S) DID NOT BEHAVE AS DECLARED ===' % bad)
        return 1
    print('\n=== every criterion refused its attack, allowed its neighbour, and (with --mutate) '
          'was seen red for its own reason ===')
    return 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
