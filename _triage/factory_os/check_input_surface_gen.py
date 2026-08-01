# -*- coding: utf-8 -*-
"""ORDER-710 -- the generated input-surface enumeration is still the surface it claims to be.

WHY A GUARD AT ALL. `ea_template/core/InputSurface_gen.mqh` is a COPY of a fact that lives in
`ea_template/core/Inputs.mqh`. MQL5 has no reflection, so the copy has to exist as source -- but
a copy of a fact is right on the day it is generated and silently wrong on the day the fact
moves, which is `BACKLOG-D29`'s shape and the reason `L0` refuses hand-kept lists. The failure it
would produce here is the quiet kind: an input is added, nobody regenerates, and the EA keeps
printing a fingerprint over 134 of its 135 inputs. It still LOOKS like a match, and the one input
that drifted is the one nobody is checking.

  G1  regenerating from `Inputs.mqh` reproduces `InputSurface_gen.mqh`, EXACTLY.
  G2  the enumeration is actually WIRED: `LabCore.mqh` includes it and prints `CFG_Fingerprint()`.
      G1 alone leaves the shape `GUARD_SHAPES.md` calls "the mechanism never engages" -- a
      perfectly current enumeration that no build ever calls, with the fingerprint line silently
      absent from every journal.
  G3  the two constants the generated file does NOT contain still agree with the Python side:
      the scope label (the first line of the preimage) and the lowercase hex alphabet (the case
      of every double's bits and of the digest). This is a SOURCE check and it is labelled one --
      it cannot prove `CryptEncode` agrees with `hashlib`; only a tester run does, and ORDER-710
      records four. What it refuses is the edit that moves every future digest while compiling
      cleanly and passing G1 and G2.

WHICH BYTES THIS JUDGES
-----------------------
BOTH files come from ONE `EvidenceSource`, so they are read at ONE moment. That is the whole
defect the 2026-08-01 front-guard batch found twice: `check_order_collision` read one board at
the index and the other at HEAD, and `check_handoff_contract` had the same mixed pair with the
opposite symptom. A staleness check is exactly where a mixed vintage is invisible -- comparing a
STAGED `Inputs.mqh` against a WORKTREE generated file would pass on a commit that stages only the
first, which is the one commit this guard exists to refuse.

Default mode is the index (the tier sets `EA_LAB_EVIDENCE=index`); `--worktree` judges the disk
and says so. Exit 0 accepted, 1 rejected, 2 could-not-read -- "I could not read it" is never
reported as "there was nothing wrong with it".
"""
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

import evidence                     # noqa: E402  (path is set above)
import gen_input_surface as gen     # noqa: E402  (path is set above)
import preset                       # noqa: E402  (path is set above)

ToolFailure = evidence.ToolFailure   # the reader's type, not a look-alike (ORDER-670 9/9)

INPUTS_PATH = preset.INPUTS_REL
GEN_PATH = gen.OUT_REL
CORE_PATH = 'ea_template/core/LabCore.mqh'
FP_PATH = 'ea_template/core/ConfigFingerprint.mqh'

# G3's two constants. They are the whole cross-language contract that is NOT visible in the
# generated file: the scope label goes into the preimage's first line, and the hex alphabet
# decides whether a double's bits and the digest itself come out in the same case Python's
# '%016x' and hexdigest() produce. Either one edited alone changes every fingerprint the EA
# emits, compiles cleanly, and is invisible until somebody runs a tester comparison.
SCOPE_DEFINE_RE = re.compile(r'^\s*#define\s+CFG_FP_SCOPE\s+"([^"]*)"\s*$', re.M)
HEX_ALPHABET_RE = re.compile(r'StringSubstr\(\s*"([^"]*)"\s*,')

# A trailing `// comment` is allowed on the include line -- the first version of this pattern
# anchored at `$` and rejected the real file on its first run. What is NOT allowed is the line
# being commented out, so the pattern still has to start at the directive.
INCLUDE_RE = re.compile(r'^[ \t]*#include\s+"InputSurface_gen\.mqh"[ \t]*(?://.*)?$', re.M)
CALL_RE = re.compile(r'\bCFG_Fingerprint\s*\(\s*\)')

_SRC = [None]


def _source(worktree=False):
    """The ONE EvidenceSource for this process (design section 3: a program chooses once).

    `--worktree` wins; otherwise the tier's `EA_LAB_EVIDENCE`; otherwise **index**. The unset
    default is the index rather than `EvidenceSource.for_run()`'s worktree because this file is a
    pre-commit gate: a gate whose default is the disk can be satisfied by content that is not
    being committed.
    """
    if _SRC[0] is None:
        mode = 'worktree' if worktree else os.environ.get(evidence.MODE_ENV, 'index')
        _SRC[0] = evidence.EvidenceSource(mode, root=ROOT)
    return _SRC[0]


def _fold(text):
    """CRLF -> LF, and nothing else.

    `core.autocrlf` is true in this repo: the blob holds LF and the working tree holds CRLF, so
    the SAME file compares unequal to itself across the two modes. Folding is named here rather
    than done silently inside the comparison, because a comparison that quietly rewrites its
    inputs is how a difference stops being reportable.
    """
    return text.replace('\r\n', '\n')


def check(worktree=False, source=None):
    """-> (problems, info). Never raises for a content problem; raises ToolFailure for a read."""
    src = source or _source(worktree)
    problems = []

    inputs_text = src.read_committed(INPUTS_PATH)      # snapshot: index (or --worktree; printed)
    committed_gen = src.read_committed(GEN_PATH)       # snapshot: index (or --worktree; printed)
    core_text = src.read_committed(CORE_PATH)          # snapshot: index (or --worktree; printed)
    fp_text = src.read_committed(FP_PATH)              # snapshot: index (or --worktree; printed)

    expected = gen.emit(inputs_text)
    tags = sorted(preset.known_build_tags(inputs_text))
    keys = dict((t, len(preset.parse_surface(inputs_text, t))) for t in tags)

    # G1
    if _fold(committed_gen) != _fold(expected):
        problems.append(
            'G1 %s is not what %s generates from %s at this snapshot (%s). Regenerate it in the '
            'same commit: `tools\\python312\\python.exe %s --write`. What the drift costs: the '
            'EA hashes the inputs this file lists, so a stale copy fingerprints a surface the '
            'binary no longer has -- and it still prints a perfectly well-formed digest.'
            % (GEN_PATH, gen.GENERATOR_REL, INPUTS_PATH, src.mode, gen.GENERATOR_REL))

    # G2
    if not INCLUDE_RE.search(_fold(core_text)):
        problems.append(
            'G2 %s does not #include "InputSurface_gen.mqh". The enumeration would be current and '
            'never compiled into anything -- the fingerprint line simply stops appearing, and an '
            'absent line is not a mismatch anyone notices.' % CORE_PATH)
    if not CALL_RE.search(_fold(core_text)):
        problems.append(
            'G2 %s never calls CFG_Fingerprint(). Including the enumeration without emitting it is '
            'the same silence by a shorter route.' % CORE_PATH)

    # G3 -- the two constants that are NOT in the generated file, and are therefore the only part
    # of the cross-language contract nothing else looks at. This is a SOURCE check, and it says so:
    # it cannot prove MetaTrader's CryptEncode agrees with hashlib (only a tester run does that,
    # and ORDER-710 records four). What it can do is refuse the edit that silently moves every
    # future digest -- which compiles cleanly, passes G1 and G2, and shows up as a mismatch nobody
    # can explain, with the binary as the first suspect.
    want_scope = preset.SCOPE_SURFACE_ONLY
    m = SCOPE_DEFINE_RE.search(_fold(fp_text))
    if not m:
        problems.append(
            'G3 %s does not #define CFG_FP_SCOPE as a quoted literal, so the EA\'s preimage begins '
            'with a scope label this checker cannot read -- and the label is the FIRST line of the '
            'hashed string.' % FP_PATH)
    elif m.group(1) != want_scope:
        problems.append(
            'G3 %s says CFG_FP_SCOPE is %r but preset._constant_scope() produces %r for the same '
            'no-locked-constants case (preset.SCOPE_SURFACE_ONLY). The scope is the first line '
            'of the preimage on BOTH '
            'sides, so the two hashes can never match again -- and nothing else in the tier looks '
            'at it.' % (FP_PATH, m.group(1), want_scope))
    alphabets = [a for a in HEX_ALPHABET_RE.findall(_fold(fp_text)) if len(a) == 16]
    if not alphabets:
        problems.append(
            'G3 %s has no 16-character hex alphabet literal. CFG_HexLower indexes one, and it is '
            'what decides the CASE of every double\'s bits and of the digest itself.' % FP_PATH)
    elif any(a != '0123456789abcdef' for a in alphabets):
        problems.append(
            'G3 %s uses the hex alphabet(s) %s. Python emits \'0x%%016x\' and hashlib.hexdigest(), '
            'both LOWERCASE; an uppercase alphabet changes every digest the EA prints while '
            'compiling cleanly and passing every other criterion here.'
            % (FP_PATH, ', '.join(repr(a) for a in alphabets)))

    return problems, {'mode': src.mode, 'tags': tags, 'keys': keys,
                      'scope': m.group(1) if m else '(unreadable)'}


def main(argv):
    out = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', newline='\n')
    worktree = '--worktree' in argv
    out.write('=== ORDER-710: the generated input-surface enumeration ===\n')
    try:
        problems, info = check(worktree=worktree)
    except ToolFailure as exc:
        out.write('[TOOL FAILURE] %s\n' % exc)
        out.write('This is NOT a rejection: the checker could not read what it judges. Exit 2.\n')
        out.flush()
        return 2
    out.write('%s\n' % _source(worktree).marker('check_input_surface_gen'))
    out.write('judged bytes : %s, %s, %s and %s, all at %s\n'
              % (INPUTS_PATH, GEN_PATH, CORE_PATH, FP_PATH, info['mode']))
    out.write('surface      : %s\n'
              % ' '.join('%s=%d' % (t, info['keys'][t]) for t in info['tags']))
    out.write('scope label  : %s (both sides)\n' % info['scope'])
    if problems:
        out.write('\n%s PROBLEM(S):\n' % len(problems))
        for p in problems:
            out.write('  - %s\n' % p)
        out.write('\n=== REJECTED ===\n')
        out.flush()
        return 1
    out.write('\n=== ACCEPTED: the enumeration matches the surface, and it is wired in ===\n')
    out.flush()
    return 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
