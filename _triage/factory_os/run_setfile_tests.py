# -*- coding: utf-8 -*-
"""run_setfile_tests.py -- ORDER-1000 (S7). The cage for the ratified old-`.set` policy.

WHAT IS BEING CAGED. The owner ratified on 2026-08-01 that an unknown or removed key in a `.set`
is a REFUSAL THAT NAMES THE KEY -- never a skipped line, never a default substituted underneath --
and that migration is a separate tool writing a NEW file with a full report. Slice S7's third
acceptance criterion is that an old `.set` "either migrates or fails loudly".

EVERY criterion appears TWICE, per `docs/GUARD_SHAPES.md` shape 5:

    ATTACK       the input the criterion exists to refuse. It must be RED.
    SPECIFICITY  the neighbouring input it must NOT refuse.

The specificity half is doing real work here and is not symmetry for its own sake: **a reader
that refuses every `.set` passes every attack in this file.** The refusals are the easy half; the
hard claim is that a VALID full-surface `.set` still loads, and that a migration that CAN be done
IS done rather than reported as impossible.

AND the refusal message is asserted to CONTAIN THE KEY NAME. That is criterion S1's real content.
A refusal that fires but says "this .set is not valid for this build" leaves the reader with 116
candidates in a 116-line file, and the cheapest way past it is to delete lines until it loads --
which reintroduces the partial-set defect (memory `mt5-tester-cache-nondeterminism`) that the
refusal exists to prevent. So "it refused" is not the assertion; "it refused and named the key"
is.

Each criterion also carries a MUTATION PROBE: `--mutate` rewrites ONE line of a COPY of
setfile.py and requires the case to go red. A green case proves nothing until it has been seen
red for its own reason. Nothing is written inside the repo -- an interrupted suite has stranded a
mutation in a real file here before (`run_enforcement_status_tests`).

USAGE  tools\\python312\\python.exe _triage/factory_os/run_setfile_tests.py [--mutate]
EXIT   0 = every case behaved as declared - 1 = one did not
"""
import importlib.util
import io
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

import preset as P                                                          # noqa: E402
import setfile as S                                                         # noqa: E402

BUILD = 'LAB_ENTRY_14'


def _surface():
    text = io.open(os.path.join(ROOT, P.INPUTS_REL.replace('/', os.sep)),
                   encoding='utf-8-sig').read()                 # snapshot: worktree
    return P.parse_surface(text, BUILD)


SURFACE = _surface()


def full_set_text(surface=None, extra_lines=(), drop=()):
    """A .set covering the WHOLE surface at its declared defaults, optionally corrupted."""
    surface = surface or SURFACE
    out = ['; fixture']
    for decl in surface.inputs:
        if decl.name in drop:
            continue
        out.append('%s=%s' % (decl.name, decl.default_expr))
    out.extend(extra_lines)
    return '\n'.join(out) + '\n'


def _refusal(mod, fn, *args, **kwargs):
    """-> (raised?, message). The module under test may be a mutant, so its Refusal type is read
    off the module rather than imported: a mutant that raises the REAL Refusal while the case
    catches the mutant's own would look green for the wrong reason."""
    try:
        fn(*args, **kwargs)
        return False, ''
    except mod.Refusal as exc:
        return True, str(exc)


# ---------------------------------------------------------------------------------------------
# S1 -- an unknown key is refused, AND the refusal names it
# ---------------------------------------------------------------------------------------------

REMOVED_KEY = '_17_UseStructLevels'      # real input, exists on build 17, NOT on build 14


def s1_attack(mod):
    text = full_set_text(extra_lines=['%s=true' % REMOVED_KEY])
    raised, msg = _refusal(mod, mod.read_set, text, SURFACE)
    if not raised:
        return ('a .set carrying %r -- an input build 14 does not expose -- was accepted. That '
                'is the skipped-line path the owner ratified against.' % REMOVED_KEY)
    if REMOVED_KEY not in msg:
        return ('it refused, but the message does not contain the key %r, so the reader is left '
                'to find it among %d lines. Message: %s'
                % (REMOVED_KEY, len(SURFACE), msg[:160]))
    return None


def s1_specificity(mod):
    """The neighbouring input it must NOT refuse: the same file WITHOUT the foreign key."""
    text = full_set_text()
    try:
        values = mod.read_set(text, SURFACE)
    except mod.Refusal as exc:
        return 'a valid full-surface .set was refused: %s' % str(exc)[:200]
    if len(values) != len(SURFACE):
        return ('a valid .set loaded but yielded %d values for a %d-input surface'
                % (len(values), len(SURFACE)))
    return None


# ---------------------------------------------------------------------------------------------
# S2 -- a PARTIAL .set is refused, and the missing keys are named
# ---------------------------------------------------------------------------------------------

DROPPED = ('_22_TP_ATRmult', '_9_StepATRmult')


def s2_attack(mod):
    text = full_set_text(drop=DROPPED)
    raised, msg = _refusal(mod, mod.read_set, text, SURFACE)
    if not raised:
        return ('a .set missing %d inputs was accepted. MT5 fills an unlisted input from the '
                'per-terminal tester cache, so this run\'s configuration would depend on what '
                'that terminal ran last.' % len(DROPPED))
    if not all(k in msg for k in DROPPED):
        return 'it refused, but did not name the missing key(s). Message: %s' % msg[:200]
    return None


def s2_specificity(mod):
    """A caller that deliberately wants a partial overlay -- the migration tool reading an OLD
    file -- must still be able to say so and be served."""
    text = full_set_text(drop=DROPPED)
    try:
        values = mod.read_set(text, SURFACE, require_full_surface=False)
    except mod.Refusal as exc:
        return ('require_full_surface=False still refused, so the migration tool has no way to '
                'read the file it exists to migrate: %s' % str(exc)[:160])
    if len(values) != len(SURFACE) - len(DROPPED):
        return 'partial read yielded %d values, expected %d' % (len(values),
                                                                len(SURFACE) - len(DROPPED))
    return None


# ---------------------------------------------------------------------------------------------
# S3 -- a .set that sets one key TWICE is refused, not resolved by last-wins
# ---------------------------------------------------------------------------------------------

def s3_attack(mod):
    text = full_set_text(extra_lines=['ExitMode=EXIT_TRAIL'])   # ExitMode already set above
    raised, msg = _refusal(mod, mod.parse_set, text)
    if not raised:
        return ('a .set setting ExitMode twice was parsed without complaint. Whichever value the '
                'terminal takes is an accident of ordering, not a configuration anyone chose.')
    if 'ExitMode' not in msg:
        return 'it refused the duplicate but did not name it. Message: %s' % msg[:160]
    return None


def s3_specificity(mod):
    """A file with comments and blank lines around a single setting is NOT a duplicate."""
    text = '; header\n\nExitMode=EXIT_ATR_TP\n\n; trailing comment\n'
    try:
        lines, comments = mod.parse_set(text)
    except mod.Refusal as exc:
        return 'an ordinary commented .set was refused: %s' % str(exc)[:160]
    if len(lines) != 1 or len(comments) != 2:
        return ('comments/blank lines were miscounted: %d value line(s), %d comment(s)'
                % (len(lines), len(comments)))
    return None


# ---------------------------------------------------------------------------------------------
# S4 -- migration REPORTS every key, and refuses to invent one
# ---------------------------------------------------------------------------------------------

def s4_attack(mod):
    """An old file carrying a key this build does not expose, with NO default supplied for the
    inputs it never set: the migration must come back with the key in `unmappable` and NO text,
    rather than a plausible-looking new file."""
    old = 'ExitMode=EXIT_ATR_TP\n%s=true\n' % REMOVED_KEY
    text, report = mod.migrate_set(old, SURFACE)                # no defaults on purpose
    if text is not None:
        return ('migration produced a file although %r has no mapping and %d inputs had no '
                'value. A full-surface file whose unguessed half came from nowhere is the '
                'worst possible output here.' % (REMOVED_KEY, len(SURFACE) - 1))
    names = [n for n, _v, _r in report.unmappable]
    if REMOVED_KEY not in names:
        return 'the unmappable list does not name %r: %s' % (REMOVED_KEY, names[:8])
    if not any(n == '_22_TP_ATRmult' for n in names):
        return ('inputs the build exposes that the old file never set were not reported as '
                'unmappable, so they would have been silently defaulted')
    return None


def s4_specificity(mod):
    """A migration that CAN be done must be done -- and must write every input exactly once."""
    old = 'ExitMode=EXIT_TRAIL\n'
    defaults = dict((d.name, d.default_expr) for d in SURFACE.inputs)
    text, report = mod.migrate_set(old, SURFACE, defaults=defaults)
    if text is None:
        return ('a migration with a full default set was refused: %s'
                % report.render()[:200])
    if not report.ok:
        return 'report.ok is False on a migration that produced a file'
    value_lines = [ln for ln in text.split('\n') if ln and not ln.startswith(';')]
    if len(value_lines) != len(SURFACE):
        return ('the migrated file has %d value lines for a %d-input surface'
                % (len(value_lines), len(SURFACE)))
    if 'ExitMode=EXIT_TRAIL' not in value_lines:
        return 'the migrated file did not carry the value the OLD file actually set'
    if len(report.kept) != 1 or len(report.filled) != len(SURFACE) - 1:
        return ('the report does not account for every key: kept=%d filled=%d for a %d-input '
                'surface' % (len(report.kept), len(report.filled), len(SURFACE)))
    return None


# ---------------------------------------------------------------------------------------------
# S5 -- an unparseable line is refused rather than skipped
# ---------------------------------------------------------------------------------------------

def s5_attack(mod):
    text = full_set_text(extra_lines=['this line has no equals sign'])
    raised, msg = _refusal(mod, mod.parse_set, text)
    if not raised:
        return ('a line this reader cannot parse was skipped. The TERMINAL may well parse it, so '
                'skipping means judging a file that is not the one the tester will load.')
    if 'no equals sign' not in msg:
        return 'it refused but did not quote the offending line. Message: %s' % msg[:160]
    return None


def s5_specificity(mod):
    """A value CONTAINING an `=` (a path, a formula) is not an unparseable line."""
    text = '_MG_RegimeFile=C:\\x\\y=z.csv\n'
    try:
        lines, _c = mod.parse_set(text)
    except mod.Refusal as exc:
        return 'a value containing "=" was refused: %s' % str(exc)[:160]
    if len(lines) != 1 or lines[0].value != 'C:\\x\\y=z.csv':
        return 'the value after the FIRST "=" was not preserved: %r' % (
            lines[0].value if lines else None)
    return None


CASES = (
    ('S1', 'unknown/removed key refused AND named',
     s1_attack, s1_specificity,
     ('% (len(unknown), surface.build_tag, detail))',
      "% (len(unknown), surface.build_tag, '<redacted>'))")),
    ('S2', 'partial .set refused AND the missing keys named',
     s2_attack, s2_specificity,
     ('    if require_full_surface:', '    if False and require_full_surface:')),
    ('S3', 'duplicate key refused, not last-wins',
     s3_attack, s3_specificity,
     ('        if name in seen:', '        if False and name in seen:')),
    ('S4', 'migration reports every key and invents none',
     s4_attack, s4_specificity,
     ('        report.unmappable.append(\n            (decl.name, \'\',',
      '        resolved[decl.name] = decl.default_expr; report.kept.append((decl.name, decl.default_expr)); _unused = (\n            (decl.name, \'\',')),
    ('S5', 'unparseable line refused, not skipped',
     s5_attack, s5_specificity,
     ('        if not m:', '        if False and not m:')),
)


def load_mutant(old, new):
    """setfile.py with ONE line rewritten, imported from a TEMP copy. `old` must appear EXACTLY
    once: zero matches mutates nothing and reports a false green; two matches mutate something
    the label does not name."""
    src = io.open(os.path.join(HERE, 'setfile.py'), encoding='utf-8').read()  # snapshot: worktree
    hits = src.count(old)
    if hits != 1:
        raise AssertionError('mutation anchor matched %d times, expected 1: %r' % (hits, old[:60]))
    tmp = tempfile.mkdtemp(prefix='setfilemut_')
    path = os.path.join(tmp, 'setfile_mutant.py')
    io.open(path, 'w', encoding='utf-8', newline='\n').write(src.replace(old, new))
    spec = importlib.util.spec_from_file_location('setfile_mutant', path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.__mutant_dir__ = tmp
    return mod


def main(argv):
    os.chdir(ROOT)
    bad = 0
    print('=== ORDER-1000 old-.set policy (ratified 2026-08-01): %d criteria, each with an '
          'attack and a specificity half ===' % len(CASES))
    print('    build %s, %d inputs on its surface' % (BUILD, len(SURFACE)))
    for cid, label, attack, spec, _mut in CASES:
        for kind, fn in (('attack', attack), ('specificity', spec)):
            why = fn(S)
            ok = why is None
            bad += 0 if ok else 1
            print('  [%s] %-3s %-11s %s' % ('OK ' if ok else 'BAD', cid, kind, label))
            if not ok:
                print('        -> %s' % why)

    if '--mutate' in argv:
        print('\n=== mutation probes: break the mechanism, the case must go RED ===')
        for cid, label, attack, spec, (old, new) in CASES:
            try:
                mod = load_mutant(old, new)
            except Exception as exc:                            # noqa: BLE001
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
            print('  [%s] %-3s mutant   %-46s %s'
                  % ('OK ' if caught else 'BAD', cid, label[:46],
                     'DETECTED' if caught else 'WENT GREEN -- this case cannot fail'))
            if caught:
                print('        -> %s' % (a or s)[:130])
            shutil.rmtree(getattr(mod, '__mutant_dir__', ''), ignore_errors=True)

    if bad:
        print('\n=== %d CASE(S) DID NOT BEHAVE AS DECLARED ===' % bad)
        return 1
    print('\n=== every criterion refused its attack, allowed its neighbour, and (with --mutate) '
          'was seen red for its own reason ===')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
