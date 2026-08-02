# -*- coding: utf-8 -*-
"""check_wrapper_gen.py -- ORDER-1021 (slice S8). The generated wrappers are still generated.

WHY A GUARD AT ALL. `ea_template/generated/**` is a COPY of facts that live in
`factory/hypotheses.jsonl`, `hypothesis_b14.py` and `ea_template/core/Inputs.mqh`. A copy of a
fact is right on the day it is written and silently wrong on the day the fact moves -- and this
copy is a **compiled artifact**, so the failure mode is a binary that trades under a hypothesis it
no longer implements while its filename still says it does.

  W1  regenerating reproduces both files EXACTLY. Slice S8's acceptance word is BYTE-IDENTICAL.
  W2  the wrapper contains ZERO logic. Decision 7, and the generator has no hook that could add
      any -- so W2 is really guarding the file against a HAND EDIT, which is S8's other
      prohibition ("no wrapper edited by hand"). A hand edit is exactly what W1 also catches, but
      W2 says WHICH RULE was broken, and "you added a statement to a wrapper" is a different
      conversation from "you forgot to regenerate".
  W3  the allowlist's tokens are EXACTLY the `module_set` on that revision's Hypothesis row. Two
      places recording which modules a revision uses is the drift every one-resolver rule in this
      tree exists to prevent -- and this is the pair that decides what the BINARY contains.
  W4  the wrapper is WIRED: exactly one `LAB_ENTRY_*` build token, and both includes present. W1
      alone leaves the shape `GUARD_SHAPES.md` calls "the mechanism never engages" -- a perfectly
      current wrapper that includes no allowlist and therefore compiles the full surface.

WHAT THIS CANNOT CHECK, STATED RATHER THAN IMPLIED. It cannot prove the generated wrapper and the
hand-written `Boss_14_GridLog.mq5` behave identically. That is the 7-point PARITY contract (design
5.5), it needs the tester, and it is deliberately NOT approximated here: a source-level claim
dressed up as a behavioural one is worse than no claim, because it occupies the place the real
check would go.

WHICH BYTES THIS JUDGES. One `EvidenceSource` for every read, so a commit that stages the
hypothesis row and not the regenerated wrapper is refused -- which is the one commit this guard
exists to refuse.

EXIT 0 accepted - 1 rejected - 2 could not be performed.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

import evidence                                    # noqa: E402
import gen_registry_rows as grr                    # noqa: E402
import gen_wrapper as gw                           # noqa: E402
import preset                                      # noqa: E402

ToolFailure = evidence.ToolFailure

# A wrapper line that is allowed to exist. Anything else is a statement, and a statement in a
# wrapper is trading logic by any other name. The list is CLOSED and short on purpose: every entry
# is a directive or a comment, and none of them can execute.
_ALLOWED = re.compile(r'^\s*(//.*|#(define|include|property|ifndef|ifdef|endif)\b.*)?$')

_BUILD_TOKEN = re.compile(r'^\s*#define\s+(LAB_ENTRY_[0-9]+)\s*$', re.M)
_TOKEN_DEFINE = re.compile(r'^\s*#define\s+(LAB_CAP_[A-Z0-9_]+)\s*$', re.M)


def _src(worktree=False):
    mode = 'worktree' if worktree else os.environ.get('EA_LAB_EVIDENCE', 'index')
    return evidence.EvidenceSource(mode, root=ROOT)


def check(worktree=False, source=None):
    src = source or _src(worktree)
    problems = []

    def read(rel):
        return src.read_committed(rel)

    try:
        expected = gw.build_all(read)
    except preset.PresetRefusal as exc:
        return ['W1 the generator REFUSED to reproduce the wrappers: %s' % exc]

    # --- W1 byte-identical regeneration ---------------------------------------------------------
    for rel, text in sorted(expected.items()):
        if not src.exists_committed(rel):
            problems.append(
                'W1 %s does not exist in the %s snapshot. A hypothesis is registered whose wrapper '
                'was never generated -- or the wrapper was deleted and the registry still names '
                'it.' % (rel, src.mode))
            continue
        stored = read(rel)
        if stored != text:
            problems.append(
                'W1 %s is not what %s produces from this snapshot. Regenerate with '
                '`gen_wrapper.py --write`. Slice S8\'s acceptance word is BYTE-IDENTICAL, and a '
                'wrapper that has drifted from its registry compiles to a binary implementing a '
                'hypothesis it no longer describes.' % (rel, gw.GENERATOR_REL))

    # --- W2 zero logic, W4 wiring ----------------------------------------------------------------
    for rel in sorted(r for r in expected if r.endswith('.mq5')):
        if not src.exists_committed(rel):
            continue
        stored = read(rel)
        offending = [(i, ln) for i, ln in
                     enumerate(stored.replace('\r\n', '\n').split('\n'), start=1)
                     if not _ALLOWED.match(ln)]
        if offending:
            problems.append(
                'W2 %s carries %d line(s) that are not a comment or a preprocessor directive, '
                'starting at line %d: %r. Decision 7: no trading logic in a wrapper, ever. A '
                'wrapper containing a statement is a generator bug or a hand edit, and S8 '
                'prohibits both.' % (rel, len(offending), offending[0][0], offending[0][1][:70]))
        builds = _BUILD_TOKEN.findall(stored)
        if len(builds) != 1:
            problems.append(
                'W4 %s defines %d LAB_ENTRY_* build token(s) (%s); exactly one must be defined. '
                'None means LabCore falls back to build 11; more than one means two entry modules '
                'compile into one binary.' % (rel, len(builds), ', '.join(builds) or 'none'))
        slug = os.path.basename(rel)[:-4]
        if 'generated/%s_allowlist.mqh' % slug not in stored:
            problems.append(
                'W4 %s does not include its own allowlist header. The tokens would then be '
                'undefined and every capability guard in Inputs.mqh would take its default '
                'branch -- a wrapper that is perfectly current and engages nothing.' % rel)
        if 'core/LabCore.mqh' not in stored:
            problems.append('W4 %s does not include core/LabCore.mqh, so it compiles to an EA '
                            'with no OnInit and no OnTick' % rel)

    # --- W3 the allowlist and the Hypothesis row tell ONE story ----------------------------------
    try:
        hyp_text = read(grr.HYPOTHESES_REL)
    except ToolFailure as exc:
        problems.append('W3 could not read %s: %s' % (grr.HYPOTHESES_REL, exc))
        return problems
    rows = {}
    for line in hyp_text.replace('\r\n', '\n').split('\n'):
        if not line.strip():
            continue
        rec = json.loads(line)
        if rec.get('entity') == 'Hypothesis':
            rows[rec.get('revision_id')] = rec

    for rel in sorted(r for r in expected if r.endswith('_allowlist.mqh')):
        if not src.exists_committed(rel):
            continue
        slug = os.path.basename(rel)[:-len('_allowlist.mqh')]
        revision_id = slug.replace('_', '-', 2).replace('-r', '-r')
        # `B14_H01_r1` -> `B14-H01-r1`: only the first two separators are hyphens in the id.
        parts = slug.split('_')
        if len(parts) == 3:
            revision_id = '%s-%s-%s' % (parts[0], parts[1], parts[2])
        row = rows.get(revision_id)
        if row is None:
            problems.append(
                'W3 %s exists but no Hypothesis row registers %s. A wrapper for an unregistered '
                'revision compiles, runs, and produces evidence attributed to nothing.'
                % (rel, revision_id))
            continue
        in_file = sorted(_TOKEN_DEFINE.findall(read(rel)))
        in_row = sorted(m.get('token') for m in row.get('module_set') or [])
        if in_file != in_row:
            problems.append(
                'W3 %s defines %s while %s\'s module_set declares %s. Two records of which '
                'modules a revision uses, disagreeing -- and this is the pair that decides what '
                'the BINARY contains.' % (rel, in_file, revision_id, in_row))

    return problems


def main(argv):
    worktree = '--worktree' in argv
    try:
        src = _src(worktree)
        sys.stdout.write(src.marker('check_wrapper_gen.py') + '\n')
        problems = check(source=src)
    except ToolFailure as exc:
        sys.stdout.write('TOOL FAILURE, not a verdict: %s\n' % exc)
        return 2
    except preset.PresetRefusal as exc:
        sys.stdout.write('REFUSED: %s\n' % exc)
        return 2

    sys.stdout.write('=== ORDER-1021 generated Thin Wrappers ===\n')
    if problems:
        sys.stdout.write('%d PROBLEM(S):\n' % len(problems))
        for p in problems:
            sys.stdout.write('  - %s\n' % p)
        return 1
    try:
        n = len(gw.build_all(lambda rel: src.read_committed(rel)))
    except preset.PresetRefusal:
        n = 0
    if n == 0:
        sys.stdout.write('  0 generated file(s) -- this run checked NOTHING and is UNTESTED, not '
                         'clean\n')
        return 1
    sys.stdout.write('  %d generated file(s) checked\n' % n)
    sys.stdout.write('W1 byte-identical regeneration - W2 zero logic - W3 allowlist == module_set '
                     '- W4 wired: all hold\n')
    sys.stdout.write('  NOT CHECKED HERE, and it is the acceptance that matters most: the 7-point '
                     'PARITY contract (design 5.5) needs the tester.\n')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
