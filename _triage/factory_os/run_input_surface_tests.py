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
import gen_locked_constants as GCONST   # noqa: E402
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

# ORDER-730. The constant half needs a translation unit, so the fixture grows a pair of wrappers
# and a tiny core. `TWO` is the discriminator: it is defined only under `#ifdef LAB_ENTRY_12`, so
# a scan that ignored the preprocessor would hand build 11 a constant its binary does not have --
# and MQL5 would not compile the reference. `LAB_ENTRY_TAG` is defined in the WRAPPER, above the
# include, which is the case that caught the first draft walking from the core file instead.
FIXTURE_WRAPPERS = {
    'ea_template/Boss_11_Fix.mq5': (
        '#define LAB_ENTRY_11\n'
        '#define LAB_ENTRY_TAG "11_Fix"\n'
        '#include "core/FixCore.mqh"\n'),
    'ea_template/Boss_12_Fix.mq5': (
        '#define LAB_ENTRY_12\n'
        '#define LAB_ENTRY_TAG "12_Fix"\n'
        '#include "core/FixCore.mqh"\n'),
}
FIXTURE_CORE = (
    '#ifndef FIX_CORE_MQH\n'
    '#define FIX_CORE_MQH\n'
    '#define CFG_FP_SCOPE "surface+constants"\n'
    '#define ONE 3600            // a plain long\n'
    '#define THROTTLE (4 * 900)  // folded arithmetic\n'
    '#define RATE (-1.0)         // a double, by its literal text\n'
    '#define PREFIX "GV_"        // a string\n'
    '#define BARE                // no value: an include guard shape, not a constant\n'
    '#ifdef LAB_ENTRY_12\n'
    '#define TWO 2\n'
    '#else\n'
    '#define ONLY_11 1\n'
    '#endif\n'
    '#ifndef LAB_ENTRY_TAG\n'
    '#define LAB_ENTRY_TAG "??"\n'
    '#endif\n'
    '#endif\n')


def fixture_closure(extra_core=None):
    files = dict(FIXTURE_WRAPPERS)
    files['ea_template/core/FixCore.mqh'] = FIXTURE_CORE if extra_core is None else extra_core
    return files


class Mods(object):
    """The three modules under test, passed to every case as ONE handle.

    Why not module-level imports: `--mutate` replaces ONE of them with a rewritten copy, and a
    case that reached for the module-level name would silently test the ORIGINAL while its
    label claimed otherwise -- a probe that cannot fail, which is the shape this suite exists
    to refuse. Every case reads its modules off this object, so the mutant is unavoidable.
    """

    def __init__(self, chk, gen, pre, gconst=None):
        self.chk = chk
        self.gen = gen
        self.preset = pre
        self.gconst = gconst if gconst is not None else GCONST


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

    def list_committed(self, pattern):
        """ORDER-730. Shaped like the real one: `*` stays inside one path segment, because the
        real `list_committed` says so and a fixture that enumerated more generously would let a
        case pass against a population the checker cannot actually see."""
        pattern = pattern.replace(os.sep, '/')
        rx = re.compile('^%s$' % '[^/]*'.join(re.escape(p) for p in pattern.split('*')))
        return sorted(f for f in self.files if rx.match(f))

    def marker(self, component):
        return '##EVIDENCE-MODE## %s %s git_index=fixture' % (component, self.mode)


def real_file(rel):
    """A real repo file used as a FIXTURE INPUT, never as a verdict. Worktree on purpose: these
    cases inject their own content and assert on the checker, not on the repository."""
    return io.open(os.path.join(ROOT, rel.replace('/', os.sep)),
                   encoding='utf-8-sig').read()  # snapshot: worktree -- a FIXTURE, not a verdict


def real_core_text():
    return real_file(REAL_CORE)


def files_for(M, inputs_text=FIXTURE_INPUTS, gen_text=None, core_text=None, fp_text=None,
              const_text=None, closure=None):
    files = dict(closure if closure is not None else fixture_closure())
    read = lambda rel: files[rel.replace(os.sep, '/')]        # noqa: E731 - a one-line reader
    wrappers = sorted(f for f in files if f.endswith('.mq5'))
    files.update({
        M.chk.INPUTS_PATH: inputs_text,
        M.chk.GEN_PATH: M.gen.emit(inputs_text) if gen_text is None else gen_text,
        M.chk.CORE_PATH: real_core_text() if core_text is None else core_text,
        M.chk.FP_PATH: real_file(M.chk.FP_PATH) if fp_text is None else fp_text,
    })
    files[M.chk.CONST_PATH] = (M.gconst.emit(read, inputs_text, wrappers)
                               if const_text is None else const_text)
    return files


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
    # ORDER-730: the REAL Inputs.mqh declares eight builds, so it needs the REAL closure beside
    # it -- the two-wrapper fixture would leave six builds with no translation unit, and the
    # constant generator refuses that rather than skipping them.
    probs = problems_for(M, inputs_text=real_inputs, gen_text=real_gen,
                         closure=_real_closure(M),
                         const_text=real_file(M.gconst.OUT_REL))
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
    """a scope label or a hex alphabet edited on ONE side must be REFUSED

    ORDER-730 INVERTED THIS CASE, and the inversion is the point rather than a chore. It used to
    rename `surface_only` -> `surface+constants` and expect a refusal, because nothing enumerated
    constants and the wider label was the lie. Now the constants ARE enumerated, so that same
    rename is the TRUE value and the lie is the narrow one. A case that had been left alone would
    have kept asserting the old world and gone green for the wrong reason.
    """
    real = real_file(M.chk.FP_PATH)
    narrowed = real.replace('#define CFG_FP_SCOPE "surface+constants"',
                            '#define CFG_FP_SCOPE "surface_only"')
    if narrowed == real:
        return 'the fixture could not rename CFG_FP_SCOPE -- the anchor no longer matches the file'
    if not any(p.startswith('G3') for p in problems_for(M, fp_text=narrowed)):
        return 'a scope label that disagrees with preset._constant_scope() was accepted'
    invented = real.replace('#define CFG_FP_SCOPE "surface+constants"',
                            '#define CFG_FP_SCOPE "everything"')
    if not any(p.startswith('G3') for p in problems_for(M, fp_text=invented)):
        return 'an invented scope label was accepted'
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


# -- G4 the constant enumeration is current, and it is wired in (ORDER-730) --------------------

def g4_attack(M):
    """a constant ADDED or REMOVED without regenerating, in either vintage, must be REFUSED

    🔴 WHAT THIS CASE DELIBERATELY DOES NOT ASSERT, because trying to taught something real:
    a constant whose VALUE moves does not need this guard at all, and an earlier version of this
    case failed for claiming it did. The generated MQL5 emits `CFG_CanonLong((long)ONE)` -- it
    names the MACRO and never transcribes the value -- so `#define ONE 3600` becoming `7200` leaves
    the generated file byte-identical while BOTH sides pick the new value up automatically. There
    is no stale state to catch. What the generated file encodes is the NAME SET and the CANONICAL
    FORM, so those are what can go stale, and those are what is attacked here.
    """
    stale = files_for(M)[M.chk.CONST_PATH]
    added = FIXTURE_CORE.replace('#define PREFIX "GV_"',
                                 '#define PREFIX "GV_"\n#define EXTRA 5')
    probs = problems_for(M, closure=fixture_closure(added), const_text=stale)
    if not any(p.startswith('G4') for p in probs):
        return 'a NEW constant left the stale enumeration accepted'
    removed = FIXTURE_CORE.replace('#define PREFIX "GV_"        // a string\n', '')
    probs = problems_for(M, closure=fixture_closure(removed), const_text=stale)
    if not any(p.startswith('G4') for p in probs):
        return 'a DELETED constant left the stale enumeration accepted -- the EA would name a macro that no longer exists'
    retyped = FIXTURE_CORE.replace('#define RATE (-1.0)', '#define RATE (-1)')
    probs = problems_for(M, closure=fixture_closure(retyped), const_text=stale)
    if not any(p.startswith('G4') for p in probs):
        return 'a constant that changed KIND (double -> long) left the stale canonicaliser accepted'
    # the reverse vintage: enumeration ahead of its source
    ahead = files_for(M, closure=fixture_closure(added))[M.chk.CONST_PATH]
    if not any(p.startswith('G4') for p in problems_for(M, const_text=ahead)):
        return 'an enumeration ahead of its closure was accepted'
    core = real_core_text().replace('#include "LockedConstants_gen.mqh"',
                                    '//#include "LockedConstants_gen.mqh"')
    if not any(p.startswith('G4') for p in problems_for(M, core_text=core)):
        return 'a commented-out LockedConstants_gen include was accepted'
    return None


def g4_specificity(M):
    """a consistent closure passes -- including the REAL one -- and CRLF is not drift"""
    if problems_for(M):
        return 'a freshly generated constant pair was refused: %s' % problems_for(M)

    # 🔴 A CONTENT PROBLEM MUST COME BACK AS A VERDICT, NOT AS A TRACEBACK. check()'s own docstring
    # promises it never raises for one, and it did: main() catches only ToolFailure, so a commit
    # that deleted a wrapper printed a Python traceback at the pre-commit hook. The reader cannot
    # tell a refusal from a crash in the tool, and the fix for the two is different. Driven with
    # the exact edit that exposed it.
    files = files_for(M)
    del files['ea_template/Boss_12_Fix.mq5']
    try:
        probs, _info = M.chk.check(source=FakeSource(files))
    except M.chk.ToolFailure:
        return 'a missing wrapper was reported as an unreadable input rather than as content'
    except Exception as exc:
        return ('a deleted wrapper escaped check() as %s -- the hook shows a traceback instead of '
                'a criterion' % type(exc).__name__)
    if not any(p.startswith('G4') for p in probs):
        return 'a build tag with no wrapper produced no G4 problem: %s' % probs
    crlf = files_for(M)[M.chk.CONST_PATH].replace('\n', '\r\n')
    if problems_for(M, const_text=crlf):
        return 'the same enumeration in CRLF was reported as drift'
    # A comment edited beside a constant must NOT move the enumeration: the value is what is
    # hashed. Without this half, G4 would be satisfied by any file-level diff at all.
    recomment = FIXTURE_CORE.replace('// a plain long', '// a plain long, renamed in this commit')
    if problems_for(M, closure=fixture_closure(recomment),
                    const_text=files_for(M)[M.chk.CONST_PATH]):
        return 'a comment edited next to a constant was reported as drift'
    real_inputs = real_file(M.preset.INPUTS_REL)
    real_const = real_file(M.gconst.OUT_REL)
    probs = problems_for(M, inputs_text=real_inputs,
                         gen_text=real_file(GEN.OUT_REL),
                         closure=_real_closure(M),
                         const_text=real_const)
    if probs:
        return 'the REAL committed closure is refused: %s' % probs
    return None


def _real_closure(M):
    """Every real file the constant scan reaches, as a fixture dict. Read from the worktree on
    purpose: these are fixture INPUTS, and the verdict under test is the checker's."""
    files = {}
    for name in sorted(os.listdir(os.path.join(ROOT, M.gconst.WRAPPER_DIR))):
        if name.endswith('.mq5'):
            rel = '%s/%s' % (M.gconst.WRAPPER_DIR, name)
            files[rel] = real_file(rel)
    for dirpath, _dirs, names in os.walk(os.path.join(ROOT, 'ea_template', 'core')):
        for name in names:
            if name.endswith('.mqh'):
                rel = os.path.relpath(os.path.join(dirpath, name), ROOT).replace(os.sep, '/')
                files[rel] = real_file(rel)
    return files


# -- G5 the label and the enumeration may not move apart (ORDER-730) ---------------------------

def g5_attack(M):
    """BOTH directions: a label promising constants with none behind it, and an enumeration
    compiled in while the label still denies it"""
    empty_core = FIXTURE_CORE.replace('#define CFG_FP_SCOPE "surface+constants"', '')
    for line in ('#define ONE 3600', '#define THROTTLE (4 * 900)', '#define RATE (-1.0)',
                 '#define PREFIX "GV_"', '#define TWO 2', '#define ONLY_11 1',
                 '#define LAB_ENTRY_TAG "??"'):
        empty_core = empty_core.replace(line, '')
    closure = fixture_closure(empty_core)
    for rel in list(closure):
        if rel.endswith('.mq5'):
            closure[rel] = closure[rel].replace('#define LAB_ENTRY_TAG "11_Fix"\n', '') \
                                       .replace('#define LAB_ENTRY_TAG "12_Fix"\n', '')
    stripped = files_for(M, closure=closure)[M.chk.CONST_PATH]
    # The precondition asks the CHECKER'S OWN question, not a looser one of its own. A plain
    # `'const:' in stripped` looked right and was wrong: the unenumerated fallback branch returns
    # the literal "\nconst:UNENUMERATED", which is not a preimage EMISSION and which
    # CFG_Fingerprint() never hashes -- so the fixture reported itself broken while being exactly
    # what the case needed.
    if M.chk.CONST_BLOCK_RE.search(stripped):
        return 'the fixture meant to produce a constant-free enumeration still emits a const line'
    probs = problems_for(M, closure=closure, const_text=stripped)
    if not any(p.startswith('G5') for p in probs):
        return 'the label claimed surface+constants while nothing enumerated a constant'

    narrowed = real_file(M.chk.FP_PATH).replace('"surface+constants"', '"surface_only"')
    probs = problems_for(M, fp_text=narrowed)
    if not any(p.startswith('G5') for p in probs):
        return 'an enumeration was compiled in while the label still said surface_only'
    return None


def g5_specificity(M):
    """the matched pair -- label and enumeration together -- passes in the state the repo is in"""
    if problems_for(M):
        return 'the matched label/enumeration pair was refused: %s' % problems_for(M)
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


# -- G6 the digest is over BOTH halves (/scrutinize round 2) -----------------------------------

def g6_attack(M):
    """a generated file that hashes only the surface, while every label says otherwise

    THIS IS THE CASE G4 STRUCTURALLY CANNOT BE. G4 compares the committed file against what the
    generator emits, so an edit made IN THE GENERATOR moves both and stays green -- probed, and it
    produced ZERO problems across every other criterion while the EA would have hashed the surface
    alone under a `surface+constants` label. The mutation for this case is that exact edit.
    """
    good = files_for(M)[M.chk.CONST_PATH]
    half = good.replace('CFG_Sha256Hex(CFG_SurfacePreimage() + CFG_ConstPreimage())',
                        'CFG_Sha256Hex(CFG_SurfacePreimage())')
    if half == good:
        return 'the fixture could not find the fingerprint body -- the anchor no longer matches'
    if not any(p.startswith('G6') for p in problems_for(M, const_text=half)):
        return 'a fingerprint that drops the constants half was accepted'
    # ...and the surface half dropped is refused too, not just the constant half
    other = good.replace('CFG_Sha256Hex(CFG_SurfacePreimage() + CFG_ConstPreimage())',
                         'CFG_Sha256Hex(CFG_ConstPreimage())')
    if not any(p.startswith('G6') for p in problems_for(M, const_text=other)):
        return 'a fingerprint that drops the SURFACE half was accepted'
    return None


def g6_specificity(M):
    """the real pair passes, and whitespace inside the call is not a violation"""
    if problems_for(M):
        return 'the generated fingerprint body was refused: %s' % problems_for(M)
    spaced = files_for(M)[M.chk.CONST_PATH].replace(
        'CFG_Sha256Hex(CFG_SurfacePreimage() + CFG_ConstPreimage())',
        'CFG_Sha256Hex( CFG_SurfacePreimage()  +  CFG_ConstPreimage() )')
    # G4 SHOULD fire on this -- the committed file no longer matches the generator, and
    # regenerating is the fix. What must NOT fire is G6: the two halves are both still there, and
    # a criterion that reported "you dropped the constants" for a whitespace edit would send the
    # reader after the wrong defect. The first version of this case asserted "no problems at all"
    # and failed for catching G4 doing its job.
    if any(p.startswith('G6') for p in problems_for(M, const_text=spaced)):
        return 'reformatting the call was reported as dropping a half'
    return None


# -- X4 the DERIVATION rule itself: per build, and refuse what it cannot reduce (ORDER-730) -----

def x4_attack(M):
    """the preprocessor decides membership, and an unreducible value is refused BY NAME"""
    files = fixture_closure()
    read = lambda rel: files[rel]                              # noqa: E731
    wrappers = sorted(f for f in files if f.endswith('.mq5'))
    _tags, wmap = M.gconst._resolve_wrappers(read, FIXTURE_INPUTS, wrappers)

    names11 = set(c.name for c in M.gconst.scan(read, 'LAB_ENTRY_11', wmap['LAB_ENTRY_11']))
    names12 = set(c.name for c in M.gconst.scan(read, 'LAB_ENTRY_12', wmap['LAB_ENTRY_12']))
    if 'TWO' in names11:
        return 'TWO is behind `#ifdef LAB_ENTRY_12` and was handed to build 11 anyway'
    if 'TWO' not in names12:
        return 'TWO is missing from build 12, which does define it'
    if 'ONLY_11' not in names11 or 'ONLY_11' in names12:
        return 'the #else branch was not evaluated: ONLY_11 belongs to build 11 and only to it'
    if 'BARE' in names11:
        return 'a valueless #define was enumerated as a constant'

    # the value, per build, must be the WRAPPER's -- the bug the first draft shipped
    got = dict((c.name, c.text)
               for c in M.gconst.scan(read, 'LAB_ENTRY_11', wmap['LAB_ENTRY_11']))
    if got.get('LAB_ENTRY_TAG') != '11_Fix':
        return ('LAB_ENTRY_TAG resolved to %r, not the wrapper value -- the closure is not '
                'starting at the translation unit' % got.get('LAB_ENTRY_TAG'))
    if got.get('THROTTLE') != '3600':
        return 'the arithmetic value (4 * 900) did not fold to 3600'
    if not got.get('RATE', '').startswith('0x'):
        return 'a double-spelled constant did not canonicalise to IEEE bits'
    if got.get('ONE') != '3600':
        return 'an integer constant was not emitted as a plain decimal'

    # unreducible -> REFUSED, not skipped
    bad = FIXTURE_CORE.replace('#define ONE 3600', '#define ONE SymbolInfoDouble(_Symbol, 1)')
    badfiles = fixture_closure(bad)
    try:
        M.gconst.scan(lambda rel: badfiles[rel], 'LAB_ENTRY_11', wmap['LAB_ENTRY_11'])
        return 'a constant this module cannot reduce to a scalar was silently skipped'
    except M.preset.PresetRefusal as exc:
        if 'ONE' not in str(exc):
            return 'the refusal did not name the constant it could not reduce'

    # a conflicting redefinition inside ONE build is refused with both sites named
    dup = FIXTURE_CORE.replace('#define PREFIX "GV_"',
                               '#define PREFIX "GV_"\n#define ONE 99')
    dupfiles = fixture_closure(dup)
    try:
        M.gconst.scan(lambda rel: dupfiles[rel], 'LAB_ENTRY_11', wmap['LAB_ENTRY_11'])
        return 'one name defined twice with different values in one build was accepted'
    except M.preset.PresetRefusal:
        pass

    # -- the four /scrutinize round-1 findings, each as its own case ---------------------------
    #
    # 🔴 `#undef` WAS THE ONE THAT WENT SILENT. Every other gap in the walker ends in a refusal;
    # ignoring #undef ended in a WRONG ANSWER -- the name stayed in `defined`, an #ifdef on it
    # stayed live, and a constant the compiler never bakes in was enumerated and hashed. Probed
    # before the fix: this fixture returned ['GONE', 'REACHED'].
    undef = ('#define GONE 1\n#undef GONE\n#ifdef GONE\n#define REACHED 9\n#endif\n')
    uf = {'ea_template/Boss_11_Fix.mq5':
          '#define LAB_ENTRY_11\n#define LAB_ENTRY_TAG "11_Fix"\n#include "core/FixCore.mqh"\n',
          'ea_template/core/FixCore.mqh': undef}
    got = [c.name for c in M.gconst.scan(lambda rel: uf[rel], 'LAB_ENTRY_11',
                                         'ea_template/Boss_11_Fix.mq5')]
    if 'REACHED' in got:
        return ('#undef was ignored, so a branch the compiler skips was enumerated: %s' % got)
    if 'GONE' not in got:
        return '#undef removed the constant from the enumeration as well as from `defined`'

    # `#if` is not modelled. Unhandled it is not ignored, it is MIS-COUNTED: its #endif pops the
    # enclosing frame. The walk did still fail, but saying `unbalanced #endif` -- which sends the
    # reader looking for a directive that is not missing.
    plain_if = ('#define KEEP 1\n#if SOMETHING\n#define HIDDEN 2\n#endif\n')
    pf = dict(uf)
    pf['ea_template/core/FixCore.mqh'] = plain_if
    try:
        M.gconst.scan(lambda rel: pf[rel], 'LAB_ENTRY_11', 'ea_template/Boss_11_Fix.mq5')
        return 'a plain #if was accepted, and its #endif silently closed the enclosing branch'
    except M.preset.PresetRefusal as exc:
        if '#if' not in str(exc):
            return 'the #if refusal names the wrong cause: %s' % exc

    # a DOUBLE referenced in a later constant's arithmetic. Before the fix this raised ValueError
    # out of the checker -- `float('0x3ff8000000000000')` -- instead of folding.
    dbl = dict(uf)
    dbl['ea_template/core/FixCore.mqh'] = '#define RATE 1.5\n#define DERIVED (RATE * 2)\n'
    try:
        vals = dict((c.name, c.text) for c in
                    M.gconst.scan(lambda rel: dbl[rel], 'LAB_ENTRY_11',
                                  'ea_template/Boss_11_Fix.mq5'))
    except M.preset.PresetRefusal as exc:
        return 'folding a double reference was refused rather than computed: %s' % exc
    if vals.get('DERIVED') != M.preset.canonical_double(3.0):
        return ('(RATE * 2) folded to %r, not the canonical form of 3.0'
                % vals.get('DERIVED'))

    # /scrutinize round 2: a string constant carrying a NEWLINE. It does not corrupt the hash --
    # both sides emit the same bytes -- it makes the hash AMBIGUOUS, because the preimage is
    # newline-joined and carries no escaping. Probed before the fix: three constants, one of them
    # "p\nconst:A=y", produced FOUR preimage lines, with the injected line indistinguishable from
    # a real constant A=y. Two constant sets, one digest.
    nl = dict(uf)
    nl['ea_template/core/FixCore.mqh'] = '#define A "x"\n#define B "p' + chr(92) + 'nconst:A=y"\n'
    try:
        M.gconst.scan(lambda rel: nl[rel], 'LAB_ENTRY_11', 'ea_template/Boss_11_Fix.mq5')
        return 'a string constant containing a newline was accepted into a newline-joined preimage'
    except M.preset.PresetRefusal as exc:
        if 'newline' not in str(exc):
            return 'the newline refusal does not name its cause: %s' % exc
    return None


def x4_specificity(M):
    """the rule ALLOWS the ordinary cases, including the REAL tree, and an identical
    redefinition -- a derivation that refuses everything is not a derivation"""
    files = fixture_closure()
    read = lambda rel: files[rel]                              # noqa: E731
    wrappers = sorted(f for f in files if f.endswith('.mq5'))
    _tags, wmap = M.gconst._resolve_wrappers(read, FIXTURE_INPUTS, wrappers)
    same = FIXTURE_CORE.replace('#define PREFIX "GV_"', '#define PREFIX "GV_"\n#define ONE 3600')
    samefiles = fixture_closure(same)
    try:
        M.gconst.scan(lambda rel: samefiles[rel], 'LAB_ENTRY_11', wmap['LAB_ENTRY_11'])
    except M.preset.PresetRefusal as exc:
        return 'an IDENTICAL redefinition was refused, and it changes nothing: %s' % exc
    real = _real_closure(M)
    try:
        rt, rw = M.gconst._resolve_wrappers(lambda r: real[r], real_file(M.preset.INPUTS_REL),
                                            [f for f in real if f.endswith('.mq5')])
        for tag in rt:
            if not M.gconst.scan(lambda r: real[r], tag, rw[tag]):
                return 'build %s derived ZERO locked constants from the real tree' % tag
    except M.preset.PresetRefusal as exc:
        return 'the REAL tree cannot be scanned: %s' % exc
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
    ('G4', 'the constant enumeration is the closure, and it is wired in', g4_attack,
     g4_specificity,
     ('check_input_surface_gen.py',
      '    if expected_const is not None and _fold(committed_const) != _fold(expected_const):',
      '    if False:')),
    ('G5', 'the scope label and the constant enumeration cannot move apart', g5_attack,
     g5_specificity,
     ('check_input_surface_gen.py',
      '    enumerated = bool(CONST_BLOCK_RE.search(_fold(committed_const)))',
      '    enumerated = True')),
    ('G6', 'the digest is over BOTH halves, read out of the committed text', g6_attack,
     g6_specificity,
     ('gen_locked_constants.py',
      "    w('   return(CFG_Sha256Hex(CFG_SurfacePreimage() + CFG_ConstPreimage()));')",
      "    w('   return(CFG_Sha256Hex(CFG_SurfacePreimage()));')")),
    ('X4', 'a locked constant is derived per BUILD, and an unreducible one is refused',
     x4_attack, x4_specificity,
     ('gen_locked_constants.py',
      '        if not all(f[0] for f in stack):',
      '        if False:')),
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
CHAIN = ('preset', 'gen_input_surface', 'gen_locked_constants', 'check_input_surface_gen')


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
                     loaded['preset'], loaded['gen_locked_constants']), tmp, saved)
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
