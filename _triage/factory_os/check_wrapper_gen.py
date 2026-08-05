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
  W6  every input on every declared build's surface has a `#ifndef`/`#ifdef LAB_CONST_<name>`
      GUARD PAIR in `Inputs.mqh`. W1-W5 are all blind to this: they regenerate the ALLOWLIST, and
      an input added to `Inputs.mqh` without its pair regenerates a perfectly correct allowlist
      that cannot possibly const it. The failure is silent and one-directional -- the input simply
      stays on every wrapper's page forever, and the registry's word for it is never applied.
  W7  every `LAB_CONST_<name>` in an allowlist names an input the build exposes, and carries its
      `LAB_CONSTVAL_<name>`. A `LAB_CONST_` with no value macro compiles to
      `const double x = LAB_CONSTVAL_x;` -- an undefined identifier, which at least fails loudly;
      a `LAB_CONST_` for a name nothing declares compiles to NOTHING and reads as applied.
  W8  the const plan and the ParameterBinding rows agree about what is off the page. Every input
      the registry calls HIDDEN is either const-ed or in `const_plan().refused`, and every
      const-ed input is HIDDEN. This is the criterion that makes `85 = 78 + 7` a CHECK instead of
      a sentence in a handoff: the registry's HIDDEN count and the wrapper's Inputs page are two
      independent statements of the same fact, and before W8 nothing compared them.

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
# /scrutinize round 2. W2 accepted ANY `#include`, so a wrapper carrying
# `#include "../core/Evil.mqh"` was refused only by W1 -- which says "regenerate", not "you
# smuggled a header in". Decision 7 is *no trading logic in a wrapper*, and an arbitrary include
# is logic by reference: the statement lives one file away and the wrapper still reads as twelve
# clean lines. The allowed set is CLOSED and derived from the generator's own two includes.
_INCLUDE = re.compile(r'^\s*#include\s+"([^"]+)"', re.M)
_TOKEN_DEFINE = re.compile(r'^\s*#define\s+(LAB_CAP_[A-Z0-9_]+)\s*$', re.M)
_CONST_DEFINE = re.compile(r'^\s*#define\s+LAB_CONST_([A-Za-z_][A-Za-z0-9_]*)\s*$', re.M)
_CONSTVAL_DEFINE = re.compile(r'^\s*#define\s+LAB_CONSTVAL_([A-Za-z_][A-Za-z0-9_]*)\s+\S', re.M)
_GUARD_IFNDEF = re.compile(r'^\s*#ifndef\s+LAB_CONST_([A-Za-z_][A-Za-z0-9_]*)\s*$', re.M)
_GUARD_IFDEF = re.compile(r'^\s*#ifdef\s+LAB_CONST_([A-Za-z_][A-Za-z0-9_]*)\s*$', re.M)


def _src(worktree=False):
    mode = 'worktree' if worktree else os.environ.get('EA_LAB_EVIDENCE', 'index')
    return evidence.EvidenceSource(mode, root=ROOT)


def _params_missing_semantics(read, revision_id):
    """-> [(parameter, column)] for every parameter BOUND by this revision whose registry row is
    missing one of design 3.1's three required cells. Reads the registry through the same source
    as everything else, so a STAGED csv is judged and not the worktree's."""
    import csv
    import re as _re
    bound = set()
    for line in read(grr.BINDINGS_REL).replace(chr(13) + chr(10), chr(10)).split(chr(10)):
        if not line.strip():
            continue
        rec = json.loads(line)
        if (rec.get('entity') == 'ParameterBinding'
                and rec.get('hypothesis_revision') == revision_id):
            bound.add(rec.get('parameter'))
    rows = {}
    text = read(preset.PARAM_REGISTRY_REL)
    body = [l for l in text.split(chr(10)) if not l.startswith('> ')]
    for r in csv.DictReader(body):
        key = _re.sub(r"\[.*\]", "", (r.get("name") or "").strip())
        rows.setdefault(key, r)
    out = []
    for name in sorted(bound):
        r = rows.get(name)
        if r is None:
            out.append((name, 'NO ROW'))
            continue
        for col in ('active_when', 'context', 'causal_question'):
            v = (r.get(col) or '').strip()
            if not v or v.upper() == 'UNKNOWN':
                out.append((name, col))
    return out


def _surface_by_registry(read, revision_id):
    """-> {parameter: surface} for one revision's ParameterBinding rows."""
    out = {}
    for line in read(grr.BINDINGS_REL).replace(chr(13) + chr(10), chr(10)).split(chr(10)):
        if not line.strip():
            continue
        rec = json.loads(line)
        if (rec.get('entity') == 'ParameterBinding'
                and rec.get('hypothesis_revision') == revision_id):
            out[rec.get('parameter')] = rec.get('surface')
    return out


def _plan_for(read, revision_id):
    """-> (ConstPlan, surface) for one revision, derived through the SAME calls the generator
    uses. Re-deriving it here rather than re-reading the emitted header is the point: W7/W8 must
    be able to disagree with the file, and a checker that read its expectation out of the artifact
    it is checking can only ever agree with it."""
    import hypothesis_b14 as HB
    hyp_id = revision_id.rsplit('-r', 1)[0]
    hyp = HB.HYPOTHESES[hyp_id]
    surface = preset.parse_surface(read(preset.INPUTS_REL), HB.BUILD_TAG)
    cfg = grr.pinned_config(hyp, surface)
    return gw.const_plan(HB.BUILD_TAG, hyp, surface, cfg), surface


def check(worktree=False, source=None):
    src = source or _src(worktree)
    problems = []

    def read(rel):
        return src.read_committed(rel)

    # --- W6 every input carries its guard pair in Inputs.mqh -------------------------------------
    # 🔴 EVALUATED BEFORE THE GENERATOR RUNS, and the cage is what forced that order. W6's attack
    # -- an input added with no guard pair -- ALSO trips `activation.classify`, which refuses an
    # input nobody has classified. So `build_all` raised first, `check()` returned the W1 refusal
    # alone, and W6 never got to speak: the case failed with `NOT CAUGHT BY W6`. Two independent
    # defences firing is good; the one that names the ACTUAL omission being unable to reach the
    # output is not. W6 is a claim about `Inputs.mqh` by itself and needs nothing generated.
    # Checked ONCE, over every declared build tag, because Inputs.mqh is shared: an input added
    # under `#ifdef LAB_ENTRY_16` without a pair is just as unconstable as one added for 14, and
    # the per-Boss rollout means build 16's turn comes later, not never.
    inputs_text = read(preset.INPUTS_REL)
    paired = set(_GUARD_IFNDEF.findall(inputs_text)) & set(_GUARD_IFDEF.findall(inputs_text))
    for tag in sorted(preset.known_build_tags(inputs_text)):
        declared = [d.name for d in preset.parse_surface(inputs_text, tag).inputs]
        unguarded = [n for n in declared if n not in paired]
        if unguarded:
            problems.append(
                'W6 %s declares %d input(s) on build %s with no `#ifndef`/`#ifdef LAB_CONST_<name>` '
                'guard pair: %s. An unguarded input can never be compiled away, so it sits on '
                'every generated wrapper\'s Inputs page whatever the registry says about it -- and '
                'W1 stays green throughout, because the ALLOWLIST it regenerates is correct.'
                % (preset.INPUTS_REL, len(unguarded), tag, ', '.join(sorted(unguarded)[:8])))

    try:
        expected = gw.build_all(read)
    except preset.PresetRefusal as exc:
        return problems + ['W1 the generator REFUSED to reproduce the wrappers: %s' % exc]

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
        # The include is matched on the FILE NAME, not on a directory-qualified path. The wrapper
        # and the allowlist sit in the same directory today; they did not for one commit, and
        # pinning the path here would have made W4 red for a wrapper that was correct. What W4 is
        # actually asserting is that the wrapper reaches ITS OWN allowlist -- the directory
        # relationship is `gen_wrapper`'s to decide and a compile's to confirm.
        if '%s_allowlist.mqh' % slug not in stored:
            problems.append(
                'W4 %s does not include its own allowlist header. The tokens would then be '
                'undefined and every capability guard in Inputs.mqh would take its default '
                'branch -- a wrapper that is perfectly current and engages nothing.' % rel)
        if 'core/LabCore.mqh' not in stored:
            problems.append('W4 %s does not include core/LabCore.mqh, so it compiles to an EA '
                            'with no OnInit and no OnTick' % rel)
        allowed = set(_INCLUDE.findall(expected[rel]))   # what the GENERATOR emits for THIS wrapper
        extra = sorted(set(_INCLUDE.findall(stored)) - allowed)
        if extra:
            problems.append(
                'W2 %s includes %d header(s) the generator does not emit: %s. Decision 7 is no '
                'trading logic in a wrapper, and an arbitrary include is logic BY REFERENCE -- the '
                'statement lives one file away and the wrapper still reads as sixteen clean lines.'
                % (rel, len(extra), ', '.join(extra)))

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
        # `B14_H01_r1` -> `B14-H01-r1`. A malformed slug is REFUSED rather than joined anyway:
        # a name this parse cannot invert would silently look up nothing and W3 would report the
        # wrong problem ("unregistered") for it.
        parts = slug.split('_')
        if len(parts) != 3:
            problems.append('W3 %s has a name this checker cannot map to a revision id '
                            '(expected <FAM>_<HYP>_<REV>)' % rel)
            continue
        revision_id = '%s-%s-%s' % (parts[0], parts[1], parts[2])
        row = rows.get(revision_id)
        if row is None:
            problems.append(
                'W3 %s exists but no Hypothesis row registers %s. A wrapper for an unregistered '
                'revision compiles, runs, and produces evidence attributed to nothing.'
                % (rel, revision_id))
            continue
        # --- W5 the lifecycle field is not two commits behind the artifact ---------------------
        # /scrutinize round 2: both rows said `status: DRAFT` while their wrappers existed on
        # disk. design 3.1's order is DRAFT -> REGISTERED -> WRAPPER_GENERATED, and it REFUSES
        # the last transition if any bound parameter lacks `active_when`/`context`/
        # `causal_question`. Both halves are checked here, because a status advanced without its
        # precondition is worse than a stale one: it asserts a gate was passed.
        status = row.get('status')
        if status in ('DRAFT', 'REGISTERED'):
            problems.append(
                'W5 %s exists but %s is still status=%s. design 3.1 puts WRAPPER_GENERATED after '
                'REGISTERED, so a generated wrapper on disk under a DRAFT row means the lifecycle '
                'field describes a state the tree has already left.' % (rel, revision_id, status))
        else:
            thin = _params_missing_semantics(read, revision_id)
            if thin:
                problems.append(
                    'W5 %s is status=%s but %d bound parameter(s) lack active_when / context / '
                    'causal_question in %s: %s. design 3.1 REFUSES that transition -- and a status '
                    'advanced without its precondition asserts a gate was passed.'
                    % (revision_id, status, len(thin), preset.PARAM_REGISTRY_REL,
                       ', '.join('%s.%s' % t for t in thin[:6])))

        in_file = sorted(_TOKEN_DEFINE.findall(read(rel)))
        in_row = sorted(m.get('token') for m in row.get('module_set') or [])
        if in_file != in_row:
            problems.append(
                'W3 %s defines %s while %s\'s module_set declares %s. Two records of which '
                'modules a revision uses, disagreeing -- and this is the pair that decides what '
                'the BINARY contains.' % (rel, in_file, revision_id, in_row))

        # --- W7 / W8 the const decisions ---------------------------------------------------------
        try:
            plan, surface = _plan_for(read, revision_id)
        except (preset.PresetRefusal, KeyError) as exc:
            problems.append('W7 the const plan for %s could not be derived: %s' % (revision_id, exc))
            continue

        text = read(rel)
        const_in_file = set(_CONST_DEFINE.findall(text))
        val_in_file = set(_CONSTVAL_DEFINE.findall(text))
        declared = set(d.name for d in surface.inputs)

        stray = sorted(const_in_file - declared)
        if stray:
            problems.append(
                'W7 %s defines LAB_CONST_ for %d name(s) build %s does not declare: %s. That '
                'compiles to nothing at all -- there is no guard pair to switch -- while reading '
                'in every review as a decision that was applied.'
                % (rel, len(stray), surface.build_tag, ', '.join(stray[:8])))
        valueless = sorted(const_in_file - val_in_file)
        if valueless:
            problems.append(
                'W7 %s defines LAB_CONST_ without LAB_CONSTVAL_ for: %s. The const branch in '
                '%s reads `= LAB_CONSTVAL_<name>`, so this is an undefined identifier at compile '
                'time.' % (rel, ', '.join(valueless[:8]), preset.INPUTS_REL))
        if const_in_file != set(plan.const_values):
            missing = sorted(set(plan.const_values) - const_in_file)
            surplus = sorted(const_in_file - set(plan.const_values))
            problems.append(
                'W7 %s const set disagrees with gen_wrapper.const_plan(): %d missing (%s), %d '
                'surplus (%s).' % (rel, len(missing), ', '.join(missing[:6]) or '-',
                                   len(surplus), ', '.join(surplus[:6]) or '-'))

        # W8 -- the registry's HIDDEN set and the compile-time const set are two independent
        # statements about which inputs are off the operator's page. Reconciled, not assumed.
        by_registry = _surface_by_registry(read, revision_id)
        if by_registry:
            hidden = set(n for n, s in by_registry.items() if s == 'HIDDEN')
            refused = set(n for n, _s, _w in plan.refused)
            const = set(plan.const_values)
            unexplained = sorted(hidden - const - refused)
            if unexplained:
                problems.append(
                    'W8 %s: %d input(s) the registry calls HIDDEN are neither const-ed nor listed '
                    'as refused: %s. HIDDEN means "the operator does not see this"; if the binary '
                    'still exposes it and nothing recorded why, the two halves of the surface have '
                    'drifted and the Inputs page is the one that is true.'
                    % (revision_id, len(unexplained), ', '.join(unexplained[:8])))
            visible_const = sorted(const - hidden)
            if visible_const:
                problems.append(
                    'W8 %s: %d input(s) are compiled away although the registry advertises them '
                    'as visible: %s. This is the dangerous direction -- the registry offers the '
                    'operator (and optimize_guard) a dial the binary does not have.'
                    % (revision_id, len(visible_const), ', '.join(visible_const[:8])))

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
    try:
        read = lambda rel: src.read_committed(rel)                              # noqa: E731
        for rev in sorted(r for r in ('B14-H01-r1', 'B14-H02-r1')):
            plan, _surface = _plan_for(read, rev)
            sys.stdout.write('  %-12s %3d const / %3d on the Inputs page / %d unreachable but '
                             'KEPT (a live input decides whether they matter)\n'
                             % (rev, len(plan.const_values), len(plan.live), len(plan.refused)))
    except Exception:                                                # pragma: no cover - reporting
        pass
    sys.stdout.write('W1 byte-identical regeneration - W2 zero logic and no smuggled include - '
                     'W3 allowlist == module_set - W4 wired - W5 the lifecycle field matches the '
                     'artifact, with its design 3.1 precondition re-measured - W6 every input has '
                     'its guard pair - W7 the const defines are complete and land somewhere - '
                     'W8 the const set and the registry\'s HIDDEN set reconcile: all hold\n')
    sys.stdout.write('  NOT CHECKED HERE, and it is the acceptance that matters most: the 7-point '
                     'PARITY contract (design 5.5) needs the tester.\n')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
