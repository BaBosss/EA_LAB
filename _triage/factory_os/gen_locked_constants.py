# -*- coding: utf-8 -*-
"""gen_locked_constants.py -- ORDER-730 (slice S6, the LOCKED-CONSTANT half of the fingerprint).

WHAT DESIGN 5.6 ASKS FOR. `effective_config_hash` = a hash over "every input the build actually
exposes **plus every locked constant**". `ORDER-710` built the first half and labelled the result
`surface_only` rather than pretending it was complete. This module derives the second half.

WHAT A LOCKED CONSTANT IS, AS A RULE RATHER THAN AS A LIST (ORDER-730 C1). A compiled-in `#define`
that carries a VALUE and reaches the build. Everything about that sentence is mechanical:

  * `#define BOSS_LAB_BASKET_MQH` carries no value -- an include guard, a build selector
    (`LAB_ENTRY_16`) and `CFG_SURFACE_ENUMERATED` are all this shape, and all fall out
    automatically. No name appears in an exemption list, because there is no exemption list.
  * "reaches the build" is decided by evaluating the preprocessor, not by globbing the directory.
    The live example is `WAVE5_DIVERG_DEPTH`, declared inside `#ifdef LAB_ENTRY_17` in
    `ExitManager.mqh` -- which is why build 17 enumerates 24 constants and every other build 23.
    A glob would enumerate constants the binary does not have, and the EA half cannot even compile
    a reference to an undefined macro, so the two sides would not merely disagree: one of them
    would not build.
    <sub>An earlier draft of this paragraph cited `entries/Entry_Wave5.mqh` instead. That file is
    genuinely included only under `#ifdef LAB_ENTRY_17`, so the sentence read correctly -- but it
    defines NO valued constant, so it demonstrated nothing. A per-build claim illustrated by a
    module that contributes nothing to the per-build result is a claim nobody can check.</sub>
  * A value this module cannot reduce to a scalar is a REFUSAL, never an omission. That is the
    difference between an enumeration and a sample: a silently-skipped constant makes
    `surface+constants` a claim about an unknown subset, which is the exact failure
    `SCOPE_SURFACE_ONLY` was invented to avoid (memory `name-it-honestly-when-you-cannot-prove-it`).

WHY NOT REUSE `preset.parse_surface`'S WALKER. It models ONE file and refuses `#include`; this has
to expand the closure, because constants are spread across fifteen headers.

  🔴 AND IT MODELS `#else`, WHICH THAT WALKER REFUSES. `parse_surface` says MQL5's preprocessor has
  no `#else` and treats meeting one as proof its model of the file is wrong. That is true of
  `Inputs.mqh`, the only file it reads -- and false of the wider tree: `MoneyManagement.mqh:88` and
  `LabCore.mqh:123` both use one, and this module refused its own first run on exactly that. The
  refusal was correct behaviour on a false premise, which is the most expensive kind to inherit, so
  `#else` is modelled here rather than copied as a prohibition. `#elif` still is not: it appears
  nowhere in the tree, and a branch nobody writes is not one to guess at.

Where this goes further still is stated below at REDEFINITION.

ONE GENERATOR, TWO SIDES. The same scan produces the Python dict that goes into
`preset.compile_preset(locked_constants=...)` and the MQL5 that the EA compiles. They cannot drift
because there is nothing to keep in step: one function emits both.

CATEGORY (TIER_SNAPSHOT_DESIGN.md section 2/3.3): BUILDER. It never opens a path -- the caller
passes a `read(relpath) -> text` callable, so the checker can drive it from an `EvidenceSource` and
judge the bytes a commit carries. Only the CLI opens files, and it says which ones.
"""
import ast
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import preset                                    # noqa: E402  (path set above)

OUT_REL = 'ea_template/core/LockedConstants_gen.mqh'
GENERATOR_REL = '_triage/factory_os/gen_locked_constants.py'
WRAPPER_DIR = 'ea_template'

# THE CLOSURE STARTS AT THE WRAPPER `.mq5`, NOT AT `LabCore.mqh`, and the first draft of this
# module got that wrong in a way worth keeping written down. Starting at `LabCore.mqh` produced
# `LAB_ENTRY_TAG = "??"` for every build -- because the real value is defined in the wrapper, two
# lines above the include, and `LabCore.mqh:54` carries an `#ifndef` fallback that only fires when
# nothing defined it. Every EA would have hashed `"11_GridTrend"` while this side hashed `"??"`.
# The compiler's translation unit is the wrapper; anything that starts lower down is modelling a
# file the compiler never compiles on its own.
_INCLUDE_RE = re.compile(r'^[ \t]*#include\s+"([^"]+)"')
_DEFINE_RE = re.compile(r'^[ \t]*#define\s+([A-Za-z_][A-Za-z0-9_]*)[ \t]*(.*)$')
# `#if` but NOT `#ifdef` / `#ifndef`, which are modelled. Matched rather than prefix-tested
# because `'#ifdef'.startswith('#if')` is true and would refuse the two forms this walker handles.
_PLAIN_IF_RE = re.compile(r'^#if(?![a-z])')

# A double is a value whose LITERAL TEXT says so. `0.0` and `1e3` are doubles; `(4 * 3600)` is a
# long. This is decided from the source spelling rather than from the evaluated Python type because
# `float(...)` of an integer expression would silently promote `MG_MAX_ROWS` into the IEEE-bits
# form and move a hash without moving a constant.
_LOOKS_DOUBLE_RE = re.compile(r'[0-9][0-9_]*\.|\.[0-9]|[0-9][eE][-+]?[0-9]')

KIND_STRING = 'string'
KIND_LONG = 'long'
KIND_DOUBLE = 'double'

_CANON_CALL = {
    KIND_STRING: 'CFG_CanonString(%s)',
    KIND_LONG:   'CFG_CanonLong((long)%s)',
    KIND_DOUBLE: 'CFG_CanonDouble(%s)',
}


class Constant(object):
    """One locked constant: where it came from, what kind it is, and its canonical text.

    `text` is what goes into BOTH preimages -- the Python side writes it into the hashed string
    directly and the MQL5 side is generated to produce the same bytes from the macro itself. The
    MQL5 half reading the MACRO and not this text is the point: that is what makes the EA's digest
    evidence about the BINARY rather than a second copy of this file.
    """

    def __init__(self, name, kind, text, raw, origin, number=None):
        self.name = name
        self.kind = kind
        self.text = text
        self.raw = raw
        self.origin = origin
        # The NUMERIC value, kept beside the canonical text because they are not the same thing
        # for a double: `text` is the IEEE-754 hex that goes into the preimage, `number` is what
        # a later constant's arithmetic can fold with. None for strings.
        self.number = number

    def canon_call(self):
        return _CANON_CALL[self.kind] % self.name


def _strip_comment(line):
    """Drop `//` and a single-line `/* ... */`, but never inside a string literal.

    `MG_BLOCK_PREFIX "MACROGATE_BLOCK_"` and `HEDGE_TAG "H"   // comment marker` both depend on
    this being right: cutting at the first `//` regardless of quoting would truncate a value, and
    ignoring comments entirely would make `LAB_ENTRY_11          // fallback build` look like a
    valued define whose value is a comment.
    """
    out = []
    i = 0
    quote = None
    while i < len(line):
        ch = line[i]
        if quote:
            out.append(ch)
            if ch == '\\' and i + 1 < len(line):
                out.append(line[i + 1])
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue
        if ch in '"\'':
            quote = ch
            out.append(ch)
            i += 1
            continue
        if ch == '/' and i + 1 < len(line) and line[i + 1] == '/':
            break
        if ch == '/' and i + 1 < len(line) and line[i + 1] == '*':
            end = line.find('*/', i + 2)
            if end < 0:
                break
            i = end + 2
            continue
        out.append(ch)
        i += 1
    return ''.join(out)


def _eval_scalar(name, raw, resolved, origin):
    """The value's text -> (kind, canonical text), or PresetRefusal.

    Only three shapes are accepted, and every one of them is a shape both languages can produce
    identically. Anything else -- a function-like macro, a cast, a reference to an MQL5 runtime
    symbol -- is refused BY NAME, so the enumeration is never quietly narrower than the rule that
    defines it.
    """
    txt = raw.strip()
    if not txt:
        raise preset.PresetRefusal('internal: %s reached _eval_scalar with no value' % name)

    if txt[0] == '"':
        try:
            value = ast.literal_eval(txt)
        except Exception:
            raise preset.PresetRefusal(
                'locked constant %s in %s has the value %s, which starts as a string literal but '
                'does not parse as one. Refused rather than guessed: the EA would hash the macro '
                'and this side would hash a guess.' % (name, origin, txt))
        if not isinstance(value, str):
            raise preset.PresetRefusal(
                'locked constant %s in %s does not evaluate to a string' % (name, origin))
        if '\n' in value or '\r' in value:
            # THE PREIMAGE IS NEWLINE-JOINED AND HAS NO ESCAPING, so a string constant carrying a
            # newline does not corrupt the hash -- both sides emit the same bytes -- it makes the
            # hash AMBIGUOUS. Probed: three constants, one of them `"p\nconst:A=y"`, produce FOUR
            # preimage lines, and the injected line is indistinguishable from a real constant `A`
            # with value `y`. Two different constant sets then share one digest, which is the one
            # property a fingerprint may not lose. Refused rather than escaped: nothing in the
            # tree has such a constant today, so the strict rule costs nothing, and inventing an
            # escaping scheme would need the MQL5 side to implement it identically.
            raise preset.PresetRefusal(
                'locked constant %s in %s contains a newline. The fingerprint preimage is joined '
                'with newlines and carries no escaping, so this value would inject extra lines '
                'and two different constant sets could hash the same.' % (name, origin))
        return KIND_STRING, value, None

    node = _parse_arith(name, txt, origin)
    value = _fold_arith(name, node, resolved, txt, origin)

    # THE KIND IS THE SOURCE SPELLING **OR** A PROMOTION THROUGH A REFERENCE, and the second half
    # was missing until a cage case went red for it. `#define DERIVED (RATE * 2)` has no decimal
    # point of its own, so the spelling rule alone called it a long -- but MQL5 expands `RATE` and
    # evaluates `(1.5 * 2)` as a DOUBLE. That happened to agree here, because `(long)3.0` is 3 and
    # a non-integral result is refused two lines down; it agreed by luck, not by rule. C's own
    # promotion is the rule: any double in the expression makes the result a double.
    promoted = any(isinstance(n, ast.Name) and (resolved.get(n.id) is not None)
                   and resolved[n.id].kind == KIND_DOUBLE
                   for n in ast.walk(node))
    if _LOOKS_DOUBLE_RE.search(txt) or promoted:
        return KIND_DOUBLE, preset.canonical_double(float(value)), float(value)
    if isinstance(value, float) and value != int(value):
        raise preset.PresetRefusal(
            'locked constant %s in %s evaluates to the non-integral %r while its source text %s '
            'contains no decimal point and references no double constant, so this module cannot '
            'tell whether the EA will hold a long or a double.' % (name, origin, value, txt))
    return KIND_LONG, str(int(value)), int(value)


def _parse_arith(name, txt, origin):
    try:
        return ast.parse(txt, mode='eval').body
    except SyntaxError:
        raise preset.PresetRefusal(
            'locked constant %s in %s has the value %s, which this module cannot reduce to a '
            'scalar. A locked constant that cannot be canonicalised is REFUSED, not skipped: '
            'skipping it would make the `%s` scope a claim about an unknown subset of the '
            'constants.' % (name, origin, txt, preset.SCOPE_WITH_CONSTANTS))


def _fold_arith(name, node, resolved, txt, origin):
    """A deliberately tiny constant folder: literals, unary +/-, + - * / // %, and names that are
    ALREADY-RESOLVED locked constants. No calls, no attributes, no subscripts -- this reads source
    that a preprocessor will expand, and anything richer than arithmetic is a shape MQL5's
    preprocessor does not have either."""
    if isinstance(node, ast.Expression):                       # pragma: no cover - defensive
        node = node.body
    num_types = (int, float)
    if isinstance(node, ast.Constant):
        if isinstance(node.value, bool) or not isinstance(node.value, num_types):
            raise preset.PresetRefusal(
                'locked constant %s in %s: %s is not a number' % (name, origin, txt))
        return node.value
    # There was an `ast.Num` fallback here for older interpreters. It was DEAD on this box --
    # tools/python312 is the only interpreter and its ast.Num is a deprecated alias that emits a
    # DeprecationWarning on every isinstance() -- so the checker printed a warning line above its
    # own verdict on every run. A guard whose output carries permanent noise is one people stop
    # reading, which is the same failure as a guard that cries wolf.
    if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.UAdd, ast.USub)):
        inner = _fold_arith(name, node.operand, resolved, txt, origin)
        return inner if isinstance(node.op, ast.UAdd) else -inner
    if isinstance(node, ast.BinOp):
        left = _fold_arith(name, node.left, resolved, txt, origin)
        right = _fold_arith(name, node.right, resolved, txt, origin)
        if isinstance(node.op, ast.Add):
            return left + right
        if isinstance(node.op, ast.Sub):
            return left - right
        if isinstance(node.op, ast.Mult):
            return left * right
        if isinstance(node.op, ast.Div):
            if right == 0:
                raise preset.PresetRefusal(
                    'locked constant %s in %s divides by zero' % (name, origin))
            return left / float(right)
        if isinstance(node.op, ast.FloorDiv) and right != 0:
            return left // right
        if isinstance(node.op, ast.Mod) and right != 0:
            return left % right
    if isinstance(node, ast.Name):
        ref = resolved.get(node.id)
        if ref is None:
            raise preset.PresetRefusal(
                'locked constant %s in %s refers to %s, which is not an already-defined locked '
                'constant at that point in the include closure.' % (name, origin, node.id))
        if ref.kind == KIND_STRING:
            raise preset.PresetRefusal(
                'locked constant %s in %s uses the string constant %s in arithmetic'
                % (name, origin, node.id))
        # A DOUBLE's stored text is its IEEE-754 HEX, not a number -- `canonical_double` already
        # ran on it. The first version did `float(ref.text_value)` here and raised ValueError out
        # of the whole checker instead of refusing: `float('0x3ff8000000000000')`. The numeric
        # value is kept alongside the canonical text precisely so this branch has something real
        # to fold with.
        if ref.kind == KIND_DOUBLE:
            return ref.number
        return int(ref.text)
    raise preset.PresetRefusal(
        'locked constant %s in %s has the value %s, which this module cannot reduce to a scalar. '
        'A locked constant that cannot be canonicalised is REFUSED, not skipped.'
        % (name, origin, txt))


def wrapper_map(read, wrapper_rels, known_tags):
    """-> {build tag: wrapper relpath}, DERIVED by reading each wrapper rather than listed here.

    `known_tags` comes from `preset.known_build_tags(Inputs.mqh)` -- the same derivation the
    surface half uses, rather than a second regex here deciding independently what a build tag
    looks like. A tag with two wrappers is refused: two translation units for one build means the
    closure this module walks is one of two the compiler could build, and picking either makes the
    fingerprint a coin toss nobody can see. A tag with NONE is refused by the caller, which knows
    the whole expected set.
    """
    found = {}
    for rel in sorted(wrapper_rels):
        text = read(rel)
        for raw in text.replace('\r\n', '\n').split('\n'):
            m = _DEFINE_RE.match(_strip_comment(raw).strip())
            if not m or m.group(2).strip() or m.group(1) not in known_tags:
                continue
            tag = m.group(1)
            if tag in found and found[tag] != rel:
                raise preset.PresetRefusal(
                    'build tag %s is defined by two wrappers (%s and %s), so there is no single '
                    'closure to enumerate constants from.' % (tag, found[tag], rel))
            found[tag] = rel
    return found


def scan(read, build_tag, wrapper_rel):
    """-> ordered list of Constant for exactly one build, with the include closure expanded.

    `read(relpath) -> text` is supplied by the caller so this stays a BUILDER: the checker hands it
    an `EvidenceSource` and gets an answer about the bytes the commit carries, and the CLI hands it
    the working tree and says so.
    """
    resolved = {}
    order = []
    defined = set()
    _walk(read, wrapper_rel, defined, resolved, order, [], set())
    if build_tag not in defined:
        raise preset.PresetRefusal(
            'walking %s never defined %s, so that file is not this build\'s translation unit'
            % (wrapper_rel, build_tag))
    return [resolved[n] for n in order]


def _walk(read, rel, defined, resolved, order, stack, seen_chain):
    if rel in seen_chain:
        raise preset.PresetRefusal('circular #include reached %s' % rel)
    text = read(rel)
    here = rel.rsplit('/', 1)[0] if '/' in rel else ''
    depth0 = len(stack)
    for n, raw in enumerate(text.replace('\r\n', '\n').split('\n'), start=1):
        stripped = _strip_comment(raw).strip()
        # Each frame is (this branch is live, some branch of this #if has already been taken).
        # The second half is what makes `#else` correct rather than merely present: flipping the
        # live flag alone would re-open a block whose #ifdef branch was already compiled.
        if stripped.startswith('#ifdef '):
            cond = stripped.split(None, 1)[1].strip() in defined
            stack.append([cond, cond])
            continue
        if stripped.startswith('#ifndef '):
            cond = stripped.split(None, 1)[1].strip() not in defined
            stack.append([cond, cond])
            continue
        if stripped.startswith('#endif'):
            if len(stack) <= depth0:
                raise preset.PresetRefusal('unbalanced #endif at %s:%d' % (rel, n))
            stack.pop()
            continue
        if stripped.startswith('#else'):
            if len(stack) <= depth0:
                raise preset.PresetRefusal('#else with no open #ifdef at %s:%d' % (rel, n))
            frame = stack[-1]
            frame[0] = not frame[1]
            frame[1] = True
            continue
        if stripped.startswith('#elif') or _PLAIN_IF_RE.match(stripped):
            # Not modelled, and deliberately not guessed at: neither appears anywhere in the
            # closure today, so there is no real branch to validate an implementation against.
            #
            # `#if` IS LISTED HERE FOR A REASON THAT `#elif` DOES NOT HAVE. Left unhandled it is
            # not ignored, it is MIS-COUNTED: the directive pushes no frame and its `#endif` then
            # pops the ENCLOSING one, so every define after it is attributed to the wrong branch.
            # The walk does still fail in the end -- the frame count cannot balance -- but it fails
            # saying `unbalanced #endif`, which sends the reader hunting for a missing directive
            # that is not missing. Naming it here turns a confusing symptom into the cause.
            raise preset.PresetRefusal(
                '%s:%d uses %s, which this module does not model. The constants it would '
                'enumerate are not the constants the compiler bakes in.'
                % (rel, n, stripped.split()[0]))
        if stripped.startswith('#undef'):
            # THE ONE THAT WOULD HAVE BEEN SILENT. Every other gap in this walker ends in a
            # refusal; ignoring `#undef` ends in a WRONG ANSWER -- the name stays in `defined`, an
            # `#ifdef` on it stays live, and a constant the compiler never bakes in is enumerated
            # and hashed. Modelling it is three lines, but the value of those lines is that they
            # remove the only path here that produces a plausible hash instead of an error.
            parts = stripped.split()
            if len(parts) >= 2:
                defined.discard(parts[1].strip())
            continue
        if not all(f[0] for f in stack):
            continue
        inc = _INCLUDE_RE.match(stripped)
        if inc:
            target = inc.group(1).replace('\\', '/')
            nxt = '%s/%s' % (here, target) if here else target
            _walk(read, _normalise(nxt), defined, resolved, order, stack,
                  seen_chain | set([rel]))
            continue
        m = _DEFINE_RE.match(stripped)
        if not m:
            continue
        name, value = m.group(1), m.group(2).strip()
        defined.add(name)
        if not value:
            continue                       # include guard / build selector: no value, no constant
        kind, text_value, number = _eval_scalar(name, value, resolved, '%s:%d' % (rel, n))
        const = Constant(name, kind, text_value, value, '%s:%d' % (rel, n), number)
        prev = resolved.get(name)
        if prev is not None:
            # REDEFINITION. Two headers giving one name two different values is not a style
            # question here: the compiler takes the last one, and a hash built from the first is a
            # hash of a configuration no binary has. Identical redefinition is allowed because it
            # changes nothing; a conflicting one is refused with both sites named.
            if prev.kind != kind or prev.text != text_value:
                raise preset.PresetRefusal(
                    'locked constant %s is defined twice with different values in one build: %s '
                    'at %s and %s at %s. The compiler keeps the last; a fingerprint built from '
                    'either is a claim about a configuration only half the build has.'
                    % (name, prev.text, prev.origin, text_value, const.origin))
            continue
        resolved[name] = const
        order.append(name)
    if len(stack) != depth0:
        raise preset.PresetRefusal('%s ends inside an unclosed #ifdef/#ifndef' % rel)


def _normalise(path):
    parts = []
    for piece in path.split('/'):
        if piece in ('', '.'):
            continue
        if piece == '..':
            if parts:
                parts.pop()
            continue
        parts.append(piece)
    return '/'.join(parts)


def constants_for(read, build_tag, wrapper_rel):
    """-> {name: canonical text} in the shape `preset.compile_preset(locked_constants=...)` wants.

    The dict is what the PYTHON side hashes. `_fingerprint` sorts by name, so the ordering of the
    scan does not reach the hash -- but the MQL5 emitter below sorts the same way anyway, because
    two sides that agree by coincidence stop agreeing without anyone editing either.
    """
    return dict((c.name, c.text) for c in scan(read, build_tag, wrapper_rel))


def _resolve_wrappers(read, inputs_text, wrapper_rels):
    tags = sorted(preset.known_build_tags(inputs_text))
    if not tags:
        raise preset.PresetRefusal(
            'no LAB_ENTRY_* build tag is declared in the input source, so there is no build to '
            'enumerate constants for.')
    wrappers = wrapper_map(read, wrapper_rels, set(tags))
    missing = [t for t in tags if t not in wrappers]
    if missing:
        raise preset.PresetRefusal(
            'build tag(s) %s are declared in %s but no wrapper under %s/ defines them, so this '
            'module has no translation unit to walk. Refused rather than skipped: a build silently '
            'missing from the enumeration is a build whose EA can never match this side.'
            % (', '.join(missing), preset.INPUTS_REL, WRAPPER_DIR))
    return tags, wrappers


def emit(read, inputs_text, wrapper_rels):
    """-> the full text of LockedConstants_gen.mqh. Deterministic: no clock, no host path."""
    tags, wrappers = _resolve_wrappers(read, inputs_text, wrapper_rels)
    out = []
    w = out.append
    w('//+------------------------------------------------------------------+')
    w('//| LockedConstants_gen.mqh - GENERATED FILE, DO NOT EDIT BY HAND.    |')
    w('//| generator : %s' % GENERATOR_REL)
    w('//| source    : the #include closure of each %s/Boss_*.mq5 wrapper' % WRAPPER_DIR)
    w('//| regenerate: tools\\python312\\python.exe %s --write' % GENERATOR_REL)
    w('//|                                                                   |')
    w('//| ORDER-730 -- the LOCKED-CONSTANT half of design section 5.6. Every |')
    w('//| valued #define that reaches this build, canonicalised the same way |')
    w('//| preset.py canonicalises it. Each line reads the MACRO, not a copy  |')
    w('//| of its value, which is what makes the digest evidence about the    |')
    w('//| BINARY rather than a second transcription of the source.           |')
    w('//|                                                                   |')
    w('//| Included LAST by LabCore.mqh, after every header that defines one  |')
    w('//| of these macros - an enumeration placed before them would not      |')
    w('//| merely be wrong, it would not compile.                             |')
    w('//+------------------------------------------------------------------+')
    w('#ifndef BOSS_LOCKED_CONSTANTS_GEN_MQH')
    w('#define BOSS_LOCKED_CONSTANTS_GEN_MQH')
    w('')
    w('#include "ConfigFingerprint.mqh"')
    w('')
    for tag in tags:
        consts = sorted(scan(read, tag, wrappers[tag]), key=lambda c: c.name)
        w('#ifdef %s' % tag)
        w('#define CFG_CONSTANTS_ENUMERATED')
        w('int    CFG_ConstKeys() { return(%d); }' % len(consts))
        w('string CFG_ConstPreimage()')
        w('  {')
        w('   string s = "";')
        for c in consts:
            w('   s += "\\nconst:%s=" + %s;' % (c.name, c.canon_call()))
        w('   return(s);')
        w('  }')
        w('#endif')
        w('')
    w('#ifndef CFG_CONSTANTS_ENUMERATED')
    w('// Reached only when no LAB_ENTRY_* tag was defined -- the same unenumerated case')
    w('// InputSurface_gen.mqh handles, and it returns the same kind of visible sentinel rather')
    w('// than an empty string that would hash to a perfectly ordinary-looking digest.')
    w('int    CFG_ConstKeys() { return(-1); }')
    w('string CFG_ConstPreimage() { return("\\nconst:UNENUMERATED"); }')
    w('#endif')
    w('')
    w('// The entry point LabCore prints. It lives HERE rather than in InputSurface_gen.mqh')
    w('// because it now calls BOTH halves, and this is the file that is included late enough')
    w('// for every constant macro to exist.')
    w('string CFG_Fingerprint()')
    w('  {')
    w('   if(CFG_SurfaceKeys() < 0 || CFG_ConstKeys() < 0)')
    w('      return("UNENUMERATED-NO-BUILD-TAG");')
    w('   return(CFG_Sha256Hex(CFG_SurfacePreimage() + CFG_ConstPreimage()));')
    w('  }')
    w('')
    w('#endif // BOSS_LOCKED_CONSTANTS_GEN_MQH')
    return '\n'.join(out) + '\n'


def _repo_root():
    return os.path.dirname(os.path.dirname(HERE))


def _disk_reader(root):
    def read(rel):
        path = os.path.join(root, rel.replace('/', os.sep))
        return io.open(path, encoding='utf-8-sig').read()      # snapshot: worktree
    return read


def wrapper_rels_on_disk(root):
    d = os.path.join(root, WRAPPER_DIR)
    return ['%s/%s' % (WRAPPER_DIR, n) for n in sorted(os.listdir(d))   # snapshot: worktree
            if n.endswith('.mq5')]


def main(argv):
    root = _repo_root()
    read = _disk_reader(root)
    inputs_text = read(preset.INPUTS_REL)
    text = emit(read, inputs_text, wrapper_rels_on_disk(root))
    if '--write' in argv:
        dst = os.path.join(root, OUT_REL.replace('/', os.sep))
        io.open(dst, 'w', encoding='utf-8', newline='\n').write(text)
        print('wrote %s (%d lines) from the WORKING TREE wrappers under %s/'
              % (OUT_REL, text.count('\n'), WRAPPER_DIR))
        return 0
    sys.stdout.write(text)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
