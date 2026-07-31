# -*- coding: utf-8 -*-
"""ORDER-616 -- the four defect SHAPES, made mechanical where they can be.

WHY THIS EXISTS
  Two blind audits produced 24 findings across three slices. They are not 24 different mistakes.
  Sorted by shape, they are FOUR, each repeated four or more times:

    1. A CHECK READS THE WRONG BYTES.
       A7 judged the working tree instead of the staged bytes, so a commit could rewrite
       append-only history with the gate green. read_input accepted a mixed index/worktree pair,
       then accepted worktree/worktree. A2's "immutable" baseline joined a pinned blob to a
       working-tree file. A drift guard regenerated against HEAD while its data pinned
       generation-time HEAD (memory `drift-guard-regenerating-against-head`).

    2. A CHECK TESTS NAMES, NOT VALUES -- or blacklists instead of allowlisting.
       A3 checked key names and never values, so `"status": "DEAD-STRUCTURAL"` carried a verdict
       into the store whose whole acceptance forbids one. `unowned_evidence` accepted any file that
       MENTIONED an entity. A citation guard was satisfied by a file that defines all 27.

    3. A CHECK THAT CANNOT FAIL.
       a4_deterministic rendered the same objects twice through the same function. A1 had a branch
       reachable only in a state the renderer makes impossible. `says=[{}]`, then
       `says=[{"bogus": null}]`, earned coverage while asserting nothing. C6 could not fail against
       any generated file.

    4. A CLAIM STATED WITHOUT MEASURING IT IN THE SAME BREATH.
       "14 mutations" written while the suite held 18. "12 entities" while the list showed 11.
       "No Live path touched" over a commit range containing an automated writer. "Every commit
       revertible in isolation", refuted by `git merge-tree`.

  Shapes 1 and 3 have mechanical proxies. They are L1 and L2 below. Shapes 2 and 4 do not -- they
  are judgement, and they live in `docs/GUARD_SHAPES.md` as questions to answer before a slice
  closes. Pretending to lint them would itself be shape 3.

WHAT L1 AND L2 ARE, AND WHAT THEY ARE NOT
  L1 does not stop a checker reading the wrong bytes. It stops a checker reading bytes WITHOUT
  SAYING WHICH -- which is the step that was skipped every time. A wrong declaration is a lie a
  reviewer can catch; an absent one is a question nobody asked.

  L2 does not prove a criterion is exercised. It proves the suite NAMES it. A criterion nobody
  names is a criterion nobody tested, which is how A8 shipped with no fixture at all. The limit is
  stated here rather than implied, because a lint that oversells itself is shape 3 wearing a badge.

USAGE  tools\\python312\\python.exe _triage/factory_os/run_guard_shape_lint.py [--self-test]
EXIT   0 = both lints pass - 1 = a violation - 2 = the lint could not read its own inputs
"""

import ast
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))

# ---------------------------------------------------------------------------------------------
# L1 -- every read of a judged repository input must declare WHICH SNAPSHOT it reads.
#
# SCOPE, and the reason for it: the three checkers inside attestation bundle `aaa5998d`'s successor
# are DELIBERATELY EXCLUDED. Adding a comment to one of them changes the bundle digest and costs
# the owner a signature, and spending fewer signatures is the point of ORDER-614 rev 2. They join
# this lint when rev 2 moves implementations out of the bundle -- recorded here so the exclusion is
# a decision with an end date rather than a hole.
L1_FILES = (
    '_triage/factory_os/check_coverage_transfer.py',
    '_triage/factory_os/check_schema_structure.py',
    '_triage/factory_os/snapshot_validator.py',
    '_triage/factory_os/gen_coverage.py',
    # ORDER-612 (S4). Declared even though it does not match CHECKER_GLOB, so L0 would never have
    # demanded it: it reads the real files on disk to DERIVE source evidence and reads both
    # taskboards to reconcile, which makes every one of those reads a judged input. A module that
    # is outside the glob is exactly the module a hand-maintained list forgets.
    '_triage/factory_os/snapshot_build.py',
    # ORDER-630 (S5). L0 demanded these on their first run, which is the list-completeness lint
    # doing exactly what it was built for -- the previous four additions to this file were all
    # remembered by hand.
    '_triage/factory_os/check_registries.py',
    '_triage/factory_os/registry.py',
    # ORDER-670. The evidence reader itself: its two direct disk reads are the worktree-mode
    # entry point (which SAYS it is manual-run semantics) and observe() (category B by design).
    # The index-mode path reads through `git show`, which is the lint's deliberate exclusion --
    # that subprocess IS how the correct pattern reads the index and names its snapshot in the
    # call itself.
    '_triage/factory_os/evidence.py',
    # ORDER-614 rev 2: out of its own bundle, so declaring a snapshot no longer costs the owner
    # a signature -- which was the deferral's whole reason, and reasons that expire must take
    # their exemptions with them.
    '_triage/factory_os/check_s2a_attestation.py',
)
# Checkers L1 CANNOT parse, with the reason. L1 walks a Python AST; PowerShell is a different
# language and this lint does not have a parser for it. They are DECLARED so that L0's completeness
# claim is true -- the list of what exists is derived from the filesystem, and each entry says
# whether it is checked or merely known. That distinction is the whole difference between "L1
# covers every checker" (false) and "L1 covers every checker it can parse, and here is the rest"
# (true, and useful).
L1_NOT_PARSED = {
    'scripts/check_block_staleness.ps1':
        'PowerShell -- L1 has no parser for it',
    'scripts/check_experiment_events.ps1':
        'PowerShell -- L1 has no parser for it',
    'scripts/check_handoff_contract.ps1':
        'PowerShell -- L1 has no parser for it',
    'scripts/check_order_collision.ps1':
        'PowerShell -- L1 has no parser for it',
    'scripts/check_precommit_staged.ps1':
        'PowerShell -- L1 has no parser for it',
    'scripts/check_stale_binaries.ps1':
        'PowerShell -- L1 has no parser for it',
    'scripts/check_state.ps1':
        'PowerShell -- L1 has no parser for it',
    'scripts/check_taskboard_archive.ps1':
        'PowerShell -- L1 has no parser for it',
    'scripts/check_template_dependencies.ps1':
        'PowerShell -- L1 has no parser for it',
    'scripts/check_truncated_run.ps1':
        'PowerShell -- L1 has no parser for it',
    'scripts/check_verdict_kill.ps1':
        'PowerShell -- L1 has no parser for it',
}
# MEASURED at declaration time: 11 PowerShell checkers, discovered by the glob rather than
# remembered. If one is added or removed, L0 says so on the next run instead of this number
# quietly becoming wrong.
assert len(L1_NOT_PARSED) == 11

L1_DEFERRED = {
    '_triage/factory_os/check_s2a_migration.py': 'inside the attestation bundle (ORDER-614 rev 2 '
                                                 'RATIFIED it stays: its criteria have no '
                                                 'policy-and-vectors replacement yet)',
    # check_s2a_attestation.py LEFT this list when rev 2 landed -- the deferral's own text said
    # it ends "when rev 2 moves implementations out of the bundle", and that happened. It is in
    # L1_FILES now, with its reads declared.
}
SNAPSHOTS = ('index', 'HEAD', 'blob', 'worktree', 'not-a-judged-input')
READ_CALL = re.compile(r'\b(?:io\.)?open\s*\(')
DECLARATION = re.compile(r'#\s*snapshot:\s*(%s)\b' % '|'.join(SNAPSHOTS))

# ---------------------------------------------------------------------------------------------
# L2 -- every criterion a checker can emit must be NAMED by its suite.
L2_PAIRS = {
    '_triage/factory_os/check_coverage_transfer.py':
        ('_triage/factory_os/run_coverage_transfer_tests.py',),
    '_triage/factory_os/check_s2a_attestation.py':
        ('_triage/factory_os/run_s2a_attestation_tests.py',),
    # ORDER-630 (S5): check_registries emits R1-R5, and run_registry_tests.py must name each.
    '_triage/factory_os/check_registries.py':
        ('_triage/factory_os/run_registry_tests.py',),
}
# `[A-Z]`, not `[A-E]`. BLIND AUDIT 2026-07-31, reproduced: the class was `[A-E]` because the
# checkers that existed when L2 was written emitted A1-E9. ORDER-630's checker emits R1-R6, so the
# regex found ZERO criteria in it, the L2 pair declared for it was INERT, and every R fixture could
# have been deleted with this lint still green. A hand-narrowed character class is the same
# hand-maintained cache of reality that L0 exists to prevent, one line further down.
CRITERION = re.compile(r"problems\.append\(\s*['\"]\s*([A-Z]\d+)\b")


def _read(rel):
    path = rel if os.path.isabs(rel) else os.path.join(ROOT, rel)
    with io.open(path, encoding='utf-8') as fh:  # snapshot: not-a-judged-input
        return fh.read()


def _open_calls(tree):
    """Every `open(...)` / `io.open(...)` READ call, as (lineno, mode).

    Parsed rather than grepped, and this matters twice. Greping matched `open(` inside comments,
    and -- caught on the lint's first real run -- it flagged every WRITE as if it were a judged
    read: `io.open(path, 'w')` is the generator producing output, not a check consuming evidence.
    A lint that fires on writes trains people to ignore it, which is how a guard goes quiet.
    """
    out = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        fn = node.func
        name = (fn.attr if isinstance(fn, ast.Attribute) else
                fn.id if isinstance(fn, ast.Name) else None)
        # /scrutinize: L1 saw ONLY a literal `open()`. `Path(x).read_text()`, `os.popen` and
        # `json.load` through a helper were all invisible, which makes a bypass as easy as
        # importing pathlib. The known-mechanism list is closed and named; `subprocess` running
        # `git show` is DELIBERATELY not here -- that is how the correct pattern reads the index,
        # and it names its snapshot in the call itself.
        if name not in ('open', 'read_text', 'read_bytes', 'popen'):
            continue
        mode = ''
        if len(node.args) > 1 and isinstance(node.args[1], ast.Constant):
            mode = str(node.args[1].value or '')
        for kw in node.keywords:
            if kw.arg == 'mode' and isinstance(kw.value, ast.Constant):
                mode = str(kw.value.value or '')
        out.append((node.lineno, mode))
    return out


def string_literals(source, path):
    """Every string literal in the file's AST, EXCEPT docstrings.

    Parsed, not grepped: a criterion id sitting in a COMMENT would satisfy a grep while asserting
    nothing, which is the same shape L2 exists to catch. `ast` drops comments by construction.

    /scrutinize then showed that was not enough. A DOCSTRING is a string literal, so
    `\"\"\"E9 is handled\"\"\"` satisfied L2 while asserting nothing -- prose wearing the shape of a
    test, which is precisely what L2 is for. Docstrings are excluded now. An id in an unused
    variable still passes, and that is left as a stated limit rather than chased: at some point
    the only thing that proves a criterion is exercised is running it.
    """
    tree = ast.parse(source, filename=path)
    docstrings = set()
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
            body = getattr(node, 'body', None)
            if body and isinstance(body[0], ast.Expr) and \
                    isinstance(body[0].value, ast.Constant) and \
                    isinstance(body[0].value.value, str):
                docstrings.add(id(body[0].value))
    out = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Constant) and isinstance(node.value, str) \
                and id(node) not in docstrings:
            out.append(node.value)
    return out


# ---------------------------------------------------------------------------------------------
# L0 -- the lists above must not be hand-maintained caches of the filesystem.
#
# /scrutinize found the lint carrying the defect it exists to catch: L1_FILES and L2_PAIRS are
# hardcoded, and two checkers were in neither. That is shape 4 -- a list that was right the day it
# was written and quietly stops being true -- and this repo already tracks that pattern as
# BACKLOG-D29. So the lists are still declarations (which is correct: DEFERRED needs a reason a
# glob cannot express), but the FILESYSTEM decides whether they are complete.
CHECKER_GLOBS = (
    '_triage/factory_os/check_*.py',
    # BLIND AUDIT 2026-07-31: L0's whole claim is "a hand-maintained list of what to check is a
    # list that stops being true", and its OWN discovery glob was hand-narrowed to one directory
    # and one language. ELEVEN scripts/check_*.ps1 existed -- check_state.ps1, check_taskboard_
    # archive.ps1, check_order_collision.ps1 among them -- and L0 asserted completeness over a set
    # that never contained any of them. The lint carried its own defect for the second time.
    'scripts/check_*.ps1',
)
CHECKER_GLOB = CHECKER_GLOBS[0]   # kept: the self-test drives the python half by name


def lint_l0(problems, present=None):
    import glob as _glob
    if present is not None:
        found = sorted(present)
    else:
        found = []
        for pat in CHECKER_GLOBS:
            found += [p.replace(os.sep, '/') for p in _glob.glob(os.path.join(ROOT, pat))]
        found = sorted(os.path.relpath(p, ROOT).replace(os.sep, '/') for p in found)
    declared = set(L1_FILES) | set(L1_DEFERRED) | set(L1_NOT_PARSED)
    for rel in found:
        if rel not in declared:
            problems.append(
                'L0 %s exists but is in neither L1_FILES nor L1_DEFERRED. A hand-maintained list '
                'of what to check is a list that stops being true -- add it, or defer it WITH A '
                'REASON.' % rel)
        if rel in L1_FILES:
            try:
                emits = sorted(set(CRITERION.findall(_read(rel))))
            except IOError:
                continue
            if emits and rel not in L2_PAIRS:
                problems.append(
                    'L0 %s emits criterion id(s) %s but declares no suite in L2_PAIRS, so nothing '
                    'checks that any of them is ever named by a test.' % (rel, emits))


def lint_l1(problems, files=None):
    for rel in (files if files is not None else L1_FILES):
        try:
            src = _read(rel)
        except IOError as exc:
            problems.append('L1 TOOL FAILURE: cannot read %s: %s' % (rel, exc))
            continue
        try:
            tree = ast.parse(src, filename=rel)
        except SyntaxError as exc:
            problems.append('L1 TOOL FAILURE: cannot parse %s: %s' % (rel, exc))
            continue
        lines = src.split('\n')
        for n, mode in _open_calls(tree):
            if any(ch in mode for ch in 'wax'):
                continue                      # a write is output, not judged evidence
            line = lines[n - 1] if n - 1 < len(lines) else ''
            if DECLARATION.search(line):
                continue
            problems.append(
                'L1 %s:%s reads a file without declaring which snapshot: %s\n'
                '     Add `# snapshot: %s` on this line. The declaration is the point -- every '
                'time this question went unasked, the check judged bytes that were not the ones '
                'being committed.' % (rel, n, line.strip()[:90], '|'.join(SNAPSHOTS)))


def lint_l2(problems, pairs=None):
    for checker, suites in (pairs if pairs is not None else L2_PAIRS).items():
        try:
            emitted = sorted(set(CRITERION.findall(_read(checker))))
            named = []
            for s in suites:
                src = _read(s)
                named += string_literals(src, s)
        except (IOError, SyntaxError) as exc:
            problems.append('L2 TOOL FAILURE: %s / %s: %s' % (checker, suites, exc))
            continue
        # A DECLARED PAIR THAT FINDS NOTHING IS THE DECLARATION FAILING, NOT THE FILE PASSING.
        # This is the check that would have caught the `[A-E]` regex on the day it was declared:
        # check_registries.py emits R1-R6, the class did not include R, `emitted` was [], and the
        # loop below iterated zero times and went green. Somebody declares an L2 pair because the
        # checker HAS criteria; finding none means the parser and the file disagree, and silence is
        # the one answer that cannot be right.
        if not emitted:
            problems.append(
                'L2 %s is declared in L2_PAIRS but no criterion id was found in it, so this pair '
                'enforces NOTHING and its suite could delete every fixture with this lint still '
                'green. Either the checker emits ids in a shape CRITERION does not match, or the '
                'pair should not be declared.' % os.path.basename(checker))
        blob = '\n'.join(named)
        for cid in emitted:
            if not re.search(r'\b%s\b' % cid, blob):
                problems.append(
                    'L2 %s can emit criterion %s, but %s never names it in any string literal.\n'
                    '     A criterion no fixture names is a criterion no fixture targets -- which '
                    'is exactly how A8 shipped with no negative case at all.'
                    % (os.path.basename(checker), cid,
                       ', '.join(os.path.basename(x) for x in suites)))


def self_test(out=None):
    """Both lints must be able to FAIL, and must not fire on the shape they are meant to allow."""
    import tempfile
    # Write through the CALLER's stream. self_test used print() while main() wrote through its own
    # TextIOWrapper over the same stdout buffer -- two wrappers, one buffer -- and every line of
    # the self-test vanished. A self-test whose result is invisible is worse than not having one.
    def emit(line):
        if out is None:
            print(line)
        else:
            out.write(line + '\n')
            out.flush()
    ok = True
    # ABSOLUTE paths. `os.path.relpath()` RAISES across drives on Windows -- the temp dir is on C:
    # and this repo is on D: -- so the self-test crashed on its very first run. `_read` accepts an
    # absolute path for exactly this reason.
    tmp = tempfile.mkdtemp(prefix='shapelint_')

    def write(name, body):
        full = os.path.join(tmp, name)
        with io.open(full, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(body)
        return full

    cases = [
        ('L1 an undeclared read is refused',
         lambda p: lint_l1(p, [write('bad.py', 'x = io.open("a.md").read()\n')]), True),
        ('L1 CONTROL a declared read is allowed',
         lambda p: lint_l1(p, [write('good.py',
                                     'x = io.open("a.md").read()  # snapshot: worktree\n')]), False),
        ('L1 CONTROL a read inside a comment is not a read',
         lambda p: lint_l1(p, [write('cmt.py', '# io.open("a.md") in prose\n')]), False),
        ('L1 CONTROL a WRITE is output, not judged evidence',
         lambda p: lint_l1(p, [write('w.py', 'io.open("a.md", "w").write("x")\n')]), False),
        ('L1 an invented snapshot name does not satisfy it',
         lambda p: lint_l1(p, [write('inv.py',
                                     'x = io.open("a.md")  # snapshot: whatever\n')]), True),
        ('L2 an unnamed criterion is refused',
         lambda p: lint_l2(p, {write('c.py', "problems.append('E9 boom')\n"):
                               (write('s.py', "case('unrelated')\n"),)}), True),
        ('L2 CONTROL a named criterion passes',
         lambda p: lint_l2(p, {write('c2.py', "problems.append('E9 boom')\n"):
                               (write('s2.py', "case('E9 must fire')\n"),)}), False),
        ('L2 a criterion named only in a DOCSTRING is refused',
         lambda p: lint_l2(p, {write('c4.py', "problems.append('E9 boom')\n"):
                               (write('s4.py', '"""E9 is handled"""\n'),)}), True),
        ('L1 a pathlib read is not invisible',
         lambda p: lint_l1(p, [write('pl.py', 'x = Path("a.md").read_text()\n')]), True),
        ('L0 a checker in neither list is refused',
         lambda p: lint_l0(p, ['_triage/factory_os/check_brand_new.py']), True),
        ('L0 CONTROL a declared checker is fine',
         lambda p: lint_l0(p, ['_triage/factory_os/check_coverage_transfer.py']), False),
        ('L2 a criterion named only in a COMMENT is refused',
         lambda p: lint_l2(p, {write('c3.py', "problems.append('E9 boom')\n"):
                               (write('s3.py', "# E9 is covered, honest\ncase('x')\n"),)}), True),
    ]
    for label, fn, expect_red in cases:
        got = []
        fn(got)
        good = bool(got) == expect_red
        ok = ok and good
        emit('  [%s] %-56s expect=%s got=%s'
             % ('OK ' if good else 'BAD', label, 'RED' if expect_red else 'GREEN',
                'RED' if got else 'GREEN'))
    import shutil
    shutil.rmtree(tmp, ignore_errors=True)
    return 0 if ok else 1


def main(argv):
    os.chdir(ROOT)
    out = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', newline='\n')
    if '--self-test' in argv:
        out.write('=== ORDER-616: both lints must be able to fail ===\n')
        out.flush()
        return self_test(out)
    problems = []
    lint_l0(problems)
    lint_l1(problems)
    lint_l2(problems)
    tool = [p for p in problems if 'TOOL FAILURE' in p]
    out.write('=== ORDER-616 guard-shape lint ===\n')
    out.write('L1 snapshot declarations : %s file(s) checked, %s deferred (%s)\n'
              % (len(L1_FILES), len(L1_DEFERRED),
                 '; '.join('%s -- %s' % (os.path.basename(k), v)
                           for k, v in sorted(L1_DEFERRED.items()))))
    out.write('L2 criterion coverage    : %s checker/suite pair(s)\n' % len(L2_PAIRS))
    import glob as _g
    # COUNT WHAT L0 ACTUALLY DISCOVERS, not what the first glob finds. This line said "5 checkers
    # match _triage/factory_os/check_*.py" in the same commit that widened discovery to 16 across
    # two globs -- a summary describing the old scope while the check used the new one, which is
    # shape 4 inside the file that names shape 4.
    _found = sorted(set(
        os.path.relpath(_p, ROOT).replace(os.sep, '/')
        for _pat in CHECKER_GLOBS for _p in _g.glob(os.path.join(ROOT, _pat))))
    out.write('L0 list completeness     : %s checker(s) on disk across %s -- %s parsed by L1, '
              '%s deferred, %s declared unparseable (PowerShell)\n'
              % (len(_found), ' + '.join(CHECKER_GLOBS),
                 len([f for f in _found if f in L1_FILES]),
                 len([f for f in _found if f in L1_DEFERRED]),
                 len([f for f in _found if f in L1_NOT_PARSED])))
    if tool:
        for p in tool:
            out.write('  %s\n' % p)
        out.write('\nThe lint could not read its own inputs. That is not a pass. Exit 2.\n')
        out.flush()
        return 2
    if problems:
        out.write('\n%s VIOLATION(S):\n' % len(problems))
        for p in problems:
            out.write('  - %s\n' % p)
        out.write('\n=== REFUSED ===\n')
        out.flush()
        return 1
    out.write('\n=== both shapes hold, and both lints have a self-test that proves they can '
              'fail ===\n')
    out.flush()
    return 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
