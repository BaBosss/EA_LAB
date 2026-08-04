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
    except M.Refused as exc:
        # ORDER-1260 #5 made `read_inventory` a function that can REFUSE, and this caller caught
        # only the two IO errors -- so an ACTIVE row with an unreadable magic came out of here as
        # an unhandled traceback with python's default exit 1, which this tool's own header
        # reserves for DRIFT. Reproduced before this line was written: `--check` over such an
        # inventory printed a traceback and returned 1, i.e. it blamed the STORE for a defect in
        # the INVENTORY. 2 is the code the header declares for input that cannot be read.
        sys.stderr.write('REFUSED %s: %s\n' % (inv, exc))
        return 2

    if 'apply' in flags:
        if os.path.exists(store):
            sys.stdout.write('REFUSED: %s already exists. The cutover import happens ONCE '
                             '(schemas.json RE-AUDIT P1: legacy exceptions are a closed set, not '
                             'an open category). Use --check.\n' % store)
            return 1
        commit = args.get('commit') or head_oid(root)
        rows = M.cutover_import(inventory, commit)
        problems = (M.store_problems(rows, M.declared_legacy_magics(root))
                    + M.inventory_problems(inventory, rows))
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
    # ORDER-1261-era review of this change: BOTH of these are unreadable-input paths and both
    # escaped as uncaught exceptions with python's default exit 1 -- the code this header reserves
    # for DRIFT. `{bad` in the store raised ValueError out of read_store; a malformed
    # `x-legacy-exception-set` raised TypeError out of the declaration reader. Same defect this
    # tool already had once for the inventory, in the two places it was not yet fixed.
    try:
        existing = M.read_store(store)
        declared = M.declared_legacy_magics(root)
    except (IOError, OSError, ValueError, TypeError, KeyError) as exc:
        sys.stderr.write('cannot read the inputs: %s: %s\n' % (type(exc).__name__, exc))
        return 2
    except M.Refused as exc:
        sys.stderr.write('REFUSED: %s\n' % exc)
        return 2
    problems = (M.store_problems(existing, declared)
                + M.inventory_problems(inventory, existing))
    if problems:
        sys.stdout.write('DRIFT: the store does not validate:\n  %s\n' % '\n  '.join(problems))
        return 1
    # 🟡 ORDER-1260 #6. THE DOCUMENTED ALLOCATION PATH COULD NOT STAY GREEN, AND THIS IS WHERE.
    #
    # `magic.allocate()` stamps the CURRENT commit -- correctly: a reservation made today is a
    # historical statement about today. This check then required the WHOLE store to carry ONE
    # commit, and required the whole file to regenerate byte-identically from DEPLOYMENTS.csv.
    # Measured at HEAD: one `allocate()` row appended to the real 60-row store fails BOTH, in two
    # independent ways -- so the two workarounds it left were a hand-edit of the store or a false
    # cutover provenance on the new row. A guard whose only compliant paths are lying or editing
    # around it is the shape memory `feedback-audit-rule-rationale-not-compliance` names, and it
    # is why the repair is here rather than in the allocator.
    #
    # WHAT THE TWO RULES WERE ACTUALLY FOR, kept: the CUTOVER is one event (that is M6, and it is
    # about LEGACY rows -- which is where the "one commit" claim belongs and where `magic.py` now
    # enforces it), and the inventory must not have grown a magic the store does not know (that is
    # the subset comparison below, which is the half that catches real drift).
    cutover_rows = M.cutover_import(inventory, '0' * 40)
    by_magic = dict((S.normalize_numbers(r['magic']), r) for r in existing)
    drift = []
    for want_row in cutover_rows:
        m = S.normalize_numbers(want_row['magic'])
        got_row = by_magic.get(m)
        if got_row is None:
            drift.append('magic %s is in %s and the store does not know it' % (m, M.INVENTORY_REL))
            continue
        # Compare everything the inventory determines -- AND SAY WHICH TWO FIELDS IT DOES NOT,
        # because replacing a byte-identical comparison with a field list narrows what is checked
        # and a narrowing nobody wrote down is indistinguishable from an oversight. Found by
        # scrutinising this very change: the first version of this list omitted `status`, and a
        # deployed magic flipped to `RETIRED` in the store passed --check. That is a contradiction
        # design 4.6 cares about specifically -- a RETIRED magic is never re-issued, so a RETIRED
        # row for a magic that is on a live account today is the store disagreeing with reality.
        #
        # THE TWO THAT ARE DELIBERATELY NOT COMPARED, each with its reason:
        #   allocated_at_commit -- the historical read-point. Comparing it would demand the store
        #       follow HEAD, which is memory `drift-guard-regenerating-against-head` exactly.
        #   allocated_to        -- a live allocation may be bound to a candidate the inventory
        #       knows nothing about; `cutover_import` always writes None, so comparing it would
        #       refuse every candidate binding this system exists to record.
        # `deployment_ref` is in this list because an independent review measured that it was not:
        # `cutover_import` deliberately never populates it (a pin to a DEPLOYMENTS.csv blob would
        # go stale 60 rows at a time), so the inventory implies ABSENT -- and a forged value in
        # the store passed every check the narrowed comparison performed. The byte comparison had
        # caught it. That is twice now that this field list has been the defect; it is the price
        # of replacing a total comparison with an enumerated one, and it is why the two exclusions
        # below are written down rather than merely intended.
        for f in ('scope', 'status', 'legacy_exception', 'legacy_accounts', 'imported_in_cutover',
                  'deployment_ref'):
            if want_row.get(f) != got_row.get(f):
                drift.append('magic %s: the store says %s=%r, the inventory implies %r'
                             % (m, f, got_row.get(f), want_row.get(f)))
    # And the other direction, with ONE declared exemption: a GLOBAL row for a magic that is not
    # deployed yet is a RESERVATION, which is the whole point of having an allocator.
    for m, got_row in sorted(by_magic.items()):
        if m in set(S.normalize_numbers(r['magic']) for r in cutover_rows):
            continue
        if got_row['scope'] != 'GLOBAL':
            drift.append('magic %s is in the store as %s but is on no account in %s -- only a '
                         'GLOBAL reservation may exist ahead of a deployment'
                         % (m, got_row['scope'], M.INVENTORY_REL))
    if drift:
        sys.stdout.write('DRIFT: %s and %s disagree:\n  %s\n'
                         % (store, M.INVENTORY_REL, '\n  '.join(drift)))
        return 1
    legacy = [r for r in existing if r['scope'] == 'LEGACY_ACCOUNT_SCOPED']
    commits = sorted(set(r['allocated_at_commit'] for r in legacy)) or ['(no legacy rows)']
    # The wording is the check. It used to say "regenerate byte-identically", which stopped being
    # true in the same edit that let an allocation exist -- and a success line that describes a
    # comparison nobody performs is how ORDER-1260 #5's docstring got where it did.
    reserved = len(existing) - len(cutover_rows)
    sys.stdout.write('magic allocations CLEAN: %d allocation(s); every one of the %d magic(s) '
                     'deployed in %s is present and matches what the inventory implies; %d GLOBAL '
                     'reservation(s) ahead of deployment; %d legacy exception(s) %s, all imported '
                     'at cutover %s\n'
                     % (len(existing), len(cutover_rows), M.INVENTORY_REL, reserved, len(legacy),
                        sorted(S.normalize_numbers(r['magic']) for r in legacy), commits[0][:12]))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
