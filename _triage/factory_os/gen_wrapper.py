# -*- coding: utf-8 -*-
"""gen_wrapper.py -- ORDER-1021 (slice S8). The Thin Wrapper generator.

WHAT DESIGN 5.2 ASKS FOR, and the good news it starts from: `Boss_14_GridLog.mq5` is **12 lines** --
two `#define`s and one `#include`. The Boss family is ALREADY a thin-wrapper pattern; this
generator does not have to invent it, only to extend it with a hypothesis token and a compile-time
capability allowlist. That is the single largest reuse in the whole design.

WHAT IT EMITS, per hypothesis revision:

  ea_template/generated/<REV>_allowlist.mqh   one `#define LAB_CAP_*` per capability the revision's
                                              pinned config ENABLES, and nothing else
  ea_template/generated/<REV>.mq5             the wrapper: `#define`s and `#include`s, no statements
                                              (BOTH in generated/ -- see the note on WRAPPER_OUT_DIR;
                                               a wrapper in ea_template/ root would give LAB_ENTRY_14
                                               a second translation unit and the locked-constant
                                               enumeration REFUSES that, correctly)

🔴 **NO TRADING LOGIC IN A WRAPPER, EVER (decision 7).** The generator emits only `#define` and
`#include` lines; a wrapper containing a STATEMENT is a generator bug, and `check_wrapper_gen.py`
refuses one. That rule is why this file has no template hook, no "extra lines" parameter and no
per-hypothesis escape hatch: the cheapest way to violate decision 7 is to add a way to.

🔴 **THE TOKEN SET IS NOT A LIST HERE.** It comes from `capability.enabled_tokens()` -- the same
call `architecture.py` and `gen_registry_rows.py` reach through -- so "which modules does this
wrapper compile" and "which modules does its Hypothesis row declare" cannot answer differently. A
literal list in this file would be the second opinion that every one-resolver rule in this tree
exists to prevent.

WHAT THIS GENERATOR DOES **NOT** DO YET, STATED BECAUSE THE GAP IS THE POINT. Design 5.3 says
"inputs outside the wrapper's capability set become `const` at their canonical default". That
requires `ea_template/core/Inputs.mqh` to declare each input inside its capability token -- the
PER-BOSS token-guard rollout the owner ratified on 2026-08-01, Boss_14 first. Until that lands, a
generated wrapper defines the tokens and `Inputs.mqh` ignores them, so the wrapper compiles to a
binary IDENTICAL to the hand-written `Boss_14_GridLog.mq5`.

  That is not a defect, it is the safe order to do it in: it makes parity case 1 (baseline
  equivalence) a check on the GENERATOR alone, with the Inputs.mqh change as a separate, separately
  falsifiable step. The alternative -- rolling out token guards and generating wrappers in one
  commit -- gives a parity failure two candidate causes and no way to tell them apart.

CATEGORY (TIER_SNAPSHOT_DESIGN.md section 2/3.3): BUILDER. Text comes from the caller through a
`read(relpath) -> text` callable; only the CLI opens paths, and it says which.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import architecture                                # noqa: E402
import capability                                  # noqa: E402
import gen_registry_rows as grr                    # noqa: E402
import hypothesis_b14 as HB                        # noqa: E402
import preset                                      # noqa: E402

Refusal = preset.PresetRefusal

# WHERE THE TWO ARTIFACTS LIVE, and it took TWO measurements to settle.
#
# 🔴 Design 5.2's snippet shows `#include "generated/<REV>_allowlist.mqh"` AND
# `#include "../core/LabCore.mqh"` in one wrapper -- which cannot both be right: the first says the
# wrapper is one level ABOVE `generated/`, the second says it is one level BELOW `core/`. The first
# version put the wrapper inside `generated/` and kept BOTH lines verbatim, and MetaEditor said
#     error 106: file '...\EALabTpl\generated\generated\B14_H01_r1_allowlist.mqh' not found
# on the first real compile. No source-level cage could catch that -- the file was byte-identical
# to the generator's output, contained zero logic, was fully wired and named the right tokens.
#
# The obvious repair was to move the WRAPPER up beside the hand-written `Boss_*.mq5`, and it
# compiled 0/0. It also broke something no cage in this generator's own suite could see:
# `gen_locked_constants.py` globs `ea_template/*.mq5` and REFUSES a build tag carrying more than
# one wrapper -- "two translation units for one build means the closure this module walks is one of
# two the compiler could build, and picking either makes the fingerprint a coin toss nobody can
# see". Both generated wrappers `#define LAB_ENTRY_14`, so `LAB_ENTRY_14` acquired THREE, and the
# ORDER-730 locked-constant enumeration refused the whole tree.
#
# So design 5.2 was right about the SECOND include and wrong about the first. Both artifacts live
# in `generated/`; the allowlist is included from the SAME directory and LabCore from `../core/`.
# That keeps `ea_template/*.mq5` at exactly one wrapper per build tag, and leaves deploy.ps1's
# nine-target compile policy untouched.
GENERATED_DIR = 'ea_template/generated'
WRAPPER_OUT_DIR = GENERATED_DIR
GENERATOR_REL = '_triage/factory_os/gen_wrapper.py'

# The entry tag each build's wrapper declares. Taken from the HAND-WRITTEN wrapper rather than
# invented, so a generated wrapper and the one it replaces cannot disagree about the string that
# ends up in every log line and every magic-scoped GlobalVariable name.
_TAG_DEFINE = '#define LAB_ENTRY_TAG'


def _slug(revision_id):
    """`B14-H01-r1` -> `B14_H01_r1`. MQL5 include names and file names may not carry a hyphen in
    an identifier context, and the include guard below is an identifier."""
    return revision_id.replace('-', '_')


def entry_tag(read, build_tag):
    """-> the `LAB_ENTRY_TAG` string the hand-written wrapper declares, e.g. `14_GridLog`."""
    rel = '%s/%s' % (capability.WRAPPER_DIR, capability.WRAPPER_FILE[build_tag])
    for line in read(rel).replace('\r\n', '\n').split('\n'):
        stripped = line.strip()
        if stripped.startswith(_TAG_DEFINE):
            rest = stripped[len(_TAG_DEFINE):].strip()
            if rest.startswith('"') and rest.endswith('"') and len(rest) >= 2:
                return rest[1:-1]
            raise Refusal('%s declares LAB_ENTRY_TAG as %r, which is not a quoted string' %
                          (rel, rest))
    raise Refusal(
        '%s declares no LAB_ENTRY_TAG. Refused rather than defaulted: LabCore falls back to "??" '
        'when none is defined, and that string reaches every journal line and every magic-scoped '
        'persistence key -- a wrapper that silently adopted it would be traceable to nothing.'
        % rel)


def emit_allowlist(revision_id, tokens):
    """-> the full text of `<REV>_allowlist.mqh`. Deterministic: sorted, no clock, no host path."""
    if not tokens:
        raise Refusal(
            'revision %s enables NO capability token. Refused: every build compiles an entry, an '
            'exit owner and a money-management module at minimum, so an empty set means the '
            'derivation failed rather than that the hypothesis is minimal.' % revision_id)
    slug = _slug(revision_id)
    w = []
    w.append('//+------------------------------------------------------------------+')
    w.append('//| %s_allowlist.mqh - GENERATED FILE, DO NOT EDIT BY HAND.' % slug)
    w.append('//| generator : %s' % GENERATOR_REL)
    w.append('//| revision  : %s' % revision_id)
    w.append('//| regenerate: tools\\python312\\python.exe %s --write' % GENERATOR_REL)
    w.append('//|')
    w.append('//| ORDER-1021 (design 5.3). One token per capability module this revision\'s')
    w.append('//| PINNED CONFIG can reach. The set is derived by capability.enabled_tokens()')
    w.append('//| from the same selectors the architecture digest reads, so it cannot disagree')
    w.append('//| with the module_set on this revision\'s Hypothesis row.')
    w.append('//|')
    w.append('//| MQL5 has no `#if EXPR==n` and no `#elif` (Inputs.mqh:11 says so), so this file')
    w.append('//| emits TOKEN #defines only. Any design that assumes expression conditionals is')
    w.append('//| wrong on this platform.')
    w.append('//+------------------------------------------------------------------+')
    w.append('#ifndef BOSS_ALLOWLIST_%s_MQH' % slug.upper())
    w.append('#define BOSS_ALLOWLIST_%s_MQH' % slug.upper())
    w.append('')
    for token in tokens:
        w.append('#define %s' % token)
    w.append('')
    w.append('#endif // BOSS_ALLOWLIST_%s_MQH' % slug.upper())
    return '\n'.join(w) + '\n'


def emit_wrapper(revision_id, build_tag, tag_string):
    """-> the full text of `<REV>.mq5`. `#define` and `#include` ONLY -- no statement, ever."""
    slug = _slug(revision_id)
    w = []
    w.append('//+------------------------------------------------------------------+')
    w.append('//| %s.mq5 - GENERATED FILE, DO NOT EDIT BY HAND.' % slug)
    w.append('//| generator : %s' % GENERATOR_REL)
    w.append('//| revision  : %s' % revision_id)
    w.append('//| regenerate: tools\\python312\\python.exe %s --write' % GENERATOR_REL)
    w.append('//+------------------------------------------------------------------+')
    w.append('#property copyright "EA_LAB / Boss"')
    w.append('#property version   "2.00"')
    w.append('#property description "GENERATED thin wrapper for %s"' % revision_id)
    w.append('#property strict')
    w.append('')
    w.append('#define %s' % build_tag)
    w.append('#define LAB_ENTRY_TAG "%s"' % tag_string)
    w.append('#define LAB_HYP "%s"' % revision_id)
    w.append('#include "%s_allowlist.mqh"' % slug)
    w.append('#include "../core/LabCore.mqh"')
    # Both paths are relative to `ea_template/generated/`. See the note on WRAPPER_OUT_DIR: this
    # pair was settled by two measurements, not by the design snippet, which got the second line
    # right and the first wrong.
    return '\n'.join(w) + '\n'


def build_for(revision_id, read):
    """-> {relpath: text} for one hypothesis revision."""
    hyp_id = revision_id.rsplit('-r', 1)[0]
    if hyp_id not in HB.HYPOTHESES:
        raise Refusal(
            'revision %s names hypothesis %s, which is not declared. Refused rather than '
            'generated from defaults: a wrapper for a hypothesis nobody registered would compile '
            'and run and produce evidence attributed to nothing.' % (revision_id, hyp_id))
    hyp = HB.HYPOTHESES[hyp_id]
    expected = '%s-r%d' % (hyp_id, hyp['revision'])
    if revision_id != expected:
        raise Refusal('revision %s does not match %s\'s registered revision %s'
                      % (revision_id, hyp_id, expected))

    build_tag = HB.BUILD_TAG
    surface = preset.parse_surface(read(preset.INPUTS_REL), build_tag)
    cfg = grr.pinned_config(hyp, surface)
    tokens = capability.enabled_tokens(build_tag, cfg, surface=surface)

    # The architecture digest is not written into the wrapper -- it belongs on the Hypothesis row
    # -- but it IS computed here, because computing it is what proves the pinned config this
    # wrapper was generated from is the same one the row describes. A refusal here means the two
    # have drifted, and that is worth discovering at generation rather than at parity.
    architecture.digest_for(build_tag, cfg, surface=surface)

    slug = _slug(revision_id)
    return {
        '%s/%s_allowlist.mqh' % (GENERATED_DIR, slug): emit_allowlist(revision_id, tokens),
        '%s/%s.mq5' % (WRAPPER_OUT_DIR, slug): emit_wrapper(revision_id, build_tag,
                                                            entry_tag(read, build_tag)),
    }


def build_all(read, revision_ids=None):
    ids = sorted(revision_ids or
                 ['%s-r%d' % (h, HB.HYPOTHESES[h]['revision']) for h in HB.HYPOTHESES])
    out = {}
    for rev in ids:
        out.update(build_for(rev, read))
    return out


def _repo_root():
    return os.path.dirname(os.path.dirname(HERE))


def main(argv):
    import io
    root = _repo_root()

    def read(rel):
        return io.open(os.path.join(root, rel.replace('/', os.sep)), encoding='utf-8-sig').read()

    try:
        files = build_all(read)
    except Refusal as exc:
        sys.stderr.write('REFUSED: %s\n' % exc)
        return 1

    if '--write' in argv:
        os.makedirs(os.path.join(root, GENERATED_DIR.replace('/', os.sep)), exist_ok=True)
        os.makedirs(os.path.join(root, WRAPPER_OUT_DIR.replace('/', os.sep)), exist_ok=True)
        for rel, text in sorted(files.items()):
            io.open(os.path.join(root, rel.replace('/', os.sep)), 'w',
                    encoding='utf-8', newline='\n').write(text)
            sys.stdout.write('wrote %s (%d lines)\n' % (rel, text.count('\n')))
        return 0

    for rel, text in sorted(files.items()):
        sys.stdout.write('--- %s (%d lines) ---\n%s\n' % (rel, text.count('\n'), text))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
