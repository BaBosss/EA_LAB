# -*- coding: utf-8 -*-
"""ORDER-1100 (slice S10) -- write the magic cutover import ONCE, and check it afterwards.

WHAT IT PRODUCES
  `factory/magic_allocations.jsonl`: one MagicAllocation per distinct magic in
  `portfolio/DEPLOYMENTS.csv` -- the three real collisions as frozen LEGACY_ACCOUNT_SCOPED
  exceptions, every other magic as GLOBAL/ASSIGNED. That file is the exception list
  `scripts/check_state.ps1` reads, and producing it is what licenses the checker to flip to the
  global rule (PROJECT_STATE section 0.5, owner-ratified 2026-08-01).

  --apply refuses to run when the store already exists. The cutover happens once; a second run
  would re-mint the closed set at a new commit, which is precisely what `magic.store_problems`'s
  M6 refuses one layer down.

WHY --check DOES NOT REGENERATE AGAINST HEAD
  `allocated_at_commit` is a HISTORICAL statement: the commit whose `DEPLOYMENTS.csv` the import
  was READ AT -- deliberately not "the commit the cutover landed in", which is not knowable while
  the cutover is being written (the same shape as `ExecutionKey.ini_hash`, one entity along, and
  it is worth naming rather than quietly picking one). A drift check
  that regenerated it from today's HEAD would demand the store follow HEAD and would go red on
  every commit that touches nothing -- memory `drift-guard-regenerating-against-head`, where a
  guard cached the value it was watching and could never fire again. So --check reads the commit
  oid OUT of the store it is checking, regenerates the ROWS with it, and compares bytes. What it
  can therefore detect is exactly what it claims: the inventory grew a magic the store does not
  know, an exception was added or removed by hand, or a row was edited.

USAGE  tools\\python312\\python.exe _triage/factory_os/gen_magic_allocations.py --check
       tools\\python312\\python.exe _triage/factory_os/gen_magic_allocations.py --apply --commit=<oid>
EXIT   0 = ok  -  1 = drift / refusal  -  2 = could not read the inputs
"""

import io
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import magic as M                                                          # noqa: E402
import scheduler as S                                                      # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))


def render(rows):
    """The store's bytes. `scheduler.canonical` again -- one serializer across the slice."""
    return ''.join(S.canonical(r) + '\n' for r in rows)


def head_oid(root):
    out = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root)
    return out.decode('ascii').strip()


def main(argv):
    args = {}
    flags = set()
    for a in argv:
        if a.startswith('--') and '=' in a:
            k, v = a[2:].split('=', 1)
            args[k.replace('-', '_')] = v
        elif a.startswith('--'):
            flags.add(a[2:])
    root = args.get('root') or ROOT
    store = args.get('store') or M.store_path(root)
    inv = args.get('inventory') or M.inventory_path(root)

    try:
        inventory = M.read_inventory(inv)
    except (IOError, OSError) as exc:
        sys.stderr.write('cannot read %s: %s\n' % (inv, exc))
        return 2

    if 'apply' in flags:
        if os.path.exists(store):
            sys.stdout.write('REFUSED: %s already exists. The cutover import happens ONCE '
                             '(schemas.json RE-AUDIT P1: legacy exceptions are a closed set, not '
                             'an open category). Use --check.\n' % store)
            return 1
        commit = args.get('commit') or head_oid(root)
        rows = M.cutover_import(inventory, commit)
        problems = M.store_problems(rows) + M.inventory_problems(inventory, rows)
        if problems:
            sys.stdout.write('REFUSED: the generated store does not validate:\n  %s\n'
                             % '\n  '.join(problems))
            return 1
        d = os.path.dirname(store)
        if d and not os.path.isdir(d):
            os.makedirs(d)
        with io.open(store, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(render(rows))
        legacy = [r for r in rows if r['scope'] == 'LEGACY_ACCOUNT_SCOPED']
        sys.stdout.write('WROTE %s: %d allocation(s), %d legacy exception(s) %s, at commit %s\n'
                         % (store, len(rows), len(legacy),
                            sorted(r['magic'] for r in legacy), commit[:12]))
        return 0

    # --check (the default)
    if not os.path.exists(store):
        sys.stdout.write('DRIFT: %s does not exist. check_state.ps1 needs this exception list '
                         'before the global magic rule can be enforced.\n' % store)
        return 1
    existing = M.read_store(store)
    problems = M.store_problems(existing) + M.inventory_problems(inventory, existing)
    if problems:
        sys.stdout.write('DRIFT: the store does not validate:\n  %s\n' % '\n  '.join(problems))
        return 1
    commits = sorted(set(r['allocated_at_commit'] for r in existing))
    if len(commits) != 1:
        sys.stdout.write('DRIFT: the store records %d cutover commits (%s); the import is one '
                         'event\n' % (len(commits), [c[:12] for c in commits]))
        return 1
    want = render(M.cutover_import(inventory, commits[0]))
    with io.open(store, 'r', encoding='utf-8-sig', newline='') as fh:
        got = fh.read()
    if got != want:
        sys.stdout.write('DRIFT: %s is not what the inventory regenerates to at commit %s.\n'
                         % (store, commits[0][:12]))
        wl, gl = want.splitlines(), got.splitlines()
        for i in range(max(len(wl), len(gl))):
            w = wl[i] if i < len(wl) else '<missing>'
            g = gl[i] if i < len(gl) else '<missing>'
            if w != g:
                sys.stdout.write('  line %d\n    store    %s\n    inventory %s\n' % (i + 1, g, w))
        return 1
    legacy = [r for r in existing if r['scope'] == 'LEGACY_ACCOUNT_SCOPED']
    sys.stdout.write('magic allocations CLEAN: %d allocation(s) regenerate byte-identically from '
                     '%s; %d legacy exception(s) %s, frozen at cutover %s\n'
                     % (len(existing), M.INVENTORY_REL, len(legacy),
                        sorted(S.normalize_numbers(r['magic']) for r in legacy), commits[0][:12]))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
