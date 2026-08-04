# -*- coding: utf-8 -*-
"""ORDER-1100 (slice S10) -- magic reservation. design 4.6, design 10's S10 row.

THE ACCEPTANCE THIS FILE OWNS
  "legacy magic exceptions preserved" -- the three real collisions (990103, 991001, 991002) are
  LEGACY_ACCOUNT_SCOPED, frozen to their judge dates, NEVER renumbered as a side effect -- and
  the prohibition beside it: "no renumbering of a live magic".

  There is no function in this module that changes an existing row's `magic`. That is deliberate
  and it is the whole prohibition: a rule enforced by the absence of the code that could break it
  cannot be forgotten by the next caller.

WHY THE EXCEPTION LIST EXISTS AT ALL, AND WHY THIS SLICE OWES IT
  PROJECT_STATE section 0.5 (owner-ratified 2026-08-01) says the scope decision is MADE -- GLOBAL
  for every new allocation -- and that `check_state.ps1` flips to the global rule "only when S10
  gives it an exception list to read, because flipping it first would redden the state check on
  three rows the owner has just declared legitimate". So the order is: produce the list, THEN
  flip the checker. `factory/magic_allocations.jsonl` is that list.

WHY LEGACY IS A CLOSED SET AND NOT A CATEGORY
  schemas.json's RE-AUDIT P1: rev 2 let an unlimited number of new LEGACY_ACCOUNT_SCOPED rows be
  minted, which would have quietly reintroduced account-scoped magics forever -- the decision
  adopted, and then undone by its own escape hatch. The set is imported ONCE, at a cutover commit,
  and `M6` refuses any legacy row that does not belong to that import.

BOTH DIRECTIONS, ALWAYS
  `inventory_problems` checks that every real collision is DECLARED (sensitivity) and that every
  DECLARED exception is a real collision (specificity). A list that only had to cover the real
  collisions could be satisfied by declaring every magic an exception, which is the global rule
  switched off in the file that is supposed to turn it on
  (memory `gate-specificity-not-just-sensitivity`).

USAGE  tools\\python312\\python.exe _triage/factory_os/magic.py <command> [args]
       commands: verify | exceptions | next | --self-test
EXIT   0 = ok  -  1 = a REFUSAL (the reasons are on stdout as JSON)  -  2 = unreadable input
"""

import collections
import csv
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scheduler as S                                                      # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
STORE_REL = 'factory/magic_allocations.jsonl'
INVENTORY_REL = 'portfolio/DEPLOYMENTS.csv'

ALLOC_FIELDS = ('entity', 'magic', 'scope', 'status', 'allocated_at_commit')
OPTIONAL_FIELDS = ('legacy_exception', 'legacy_accounts', 'allocated_to', 'deployment_ref',
                   'imported_in_cutover')
SCOPES = ('GLOBAL', 'LEGACY_ACCOUNT_SCOPED')
STATUSES = ('RESERVED', 'ASSIGNED', 'RETIRED')

# ORDER-1260 #5. The DEPLOYMENTS.csv statuses that mean something is running on a chart, and for
# which "I could not read the magic" is therefore a refusal rather than a skip. Measured on the
# real file before this was armed, because a new refusal on the commit path is the ORDER-1310 #6
# shape: 64 rows, statuses ACTIVE 58 / REMOVED 5 / UNVERIFIED 1, and exactly ONE row carries a
# non-numeric magic -- `ClevrFX_EA` on account 69424711, status UNVERIFIED. So this set arms the
# refusal on 58 rows and refuses none of them today.
#
# UNVERIFIED IS THE DECLARED EXEMPTION, not an oversight, and `check_state.ps1` already gives the
# word the same meaning one check along ("every inventory row with a magic (status not
# UNVERIFIED) has a dashboard cohort map entry"). It means the lab has not established what that
# row is. Refusing it would take the commit path down over the one row whose whole point is that
# it is not yet described -- and the honest fix for that row is to describe it, which is an
# owner action and not something a validator can perform. It is named here so that tightening the
# boundary is a decision someone takes rather than a line nobody notices.
INVENTORY_RUNNING_STATUSES = ('ACTIVE',)

HEX40_RE = re.compile(r'^[0-9a-f]{40}$')
CAND_ID_RE = re.compile(r'^CAND-[0-9a-f]{12}$')

# ORDER-1260 #4. WHERE THE CLOSED SET IS DECLARED, AND WHY IT IS NOT DECLARED HERE.
#
# M6 bound membership of the legacy set to "one `allocated_at_commit`" and never to WHICH magics
# are in it. Measured at HEAD against the real 60-row store: a FOURTH legacy row reusing the
# cutover oid passed `validate_allocation`, `store_problems` AND `inventory_problems`. The control
# -- the same row at a different commit -- was refused, so M6 was live and simply answering a
# different question. Reusing an oid costs nothing: it is copied out of the file being attacked.
#
# The three magics were named in PROSE in four places (this module's docstring, schemas.json's
# user decision, PROJECT_STATE section 0.5, the S10 cage) and DERIVED in none. Retyping them here
# would have made a fifth copy, so the set is READ from the one of the four that is already
# machine-readable and already carries the user's decision: `MagicAllocation.x-legacy-exception-
# set` in schemas.json. Adding a member is then an edit to a user-decision field, which is what
# "closed set" was supposed to mean, rather than an edit to a rule.
LEGACY_SET_KEY = 'x-legacy-exception-set'


def declared_legacy_magics(root=None):
    """The closed legacy set, READ from schemas.json. Raises rather than returning a default:
    a missing declaration is not an empty declaration, and treating it as one would turn the
    closed set into "no exceptions are legal", which reads as strict and is simply wrong."""
    path = os.path.join(root or ROOT, '_triage', 'factory_os', 'schemas.json')
    with io.open(path, 'r', encoding='utf-8-sig') as fh:
        schema = json.load(fh)
    d = schema['$defs']['MagicAllocation']
    if LEGACY_SET_KEY not in d:
        raise Refused('schemas.json MagicAllocation declares no %s -- the closed legacy set has '
                      'no declaration to derive from, and this module will not invent one'
                      % LEGACY_SET_KEY)
    return tuple(S.normalize_numbers(m) for m in d[LEGACY_SET_KEY])


class Refused(Exception):
    """Raised by the allocator, for the reason the other two S10 modules raise: a writer that
    returned a problem list is a writer whose caller can write anyway."""


# ---------------------------------------------------------------------------------------------
# THE INVENTORY. DEPLOYMENTS.csv owns "what runs where" (PROJECT_STATE section 0.5) and this
# module never writes it -- it only reads which magic sits on which account.
# ---------------------------------------------------------------------------------------------
def read_inventory(path):
    """[(account, magic, status, judge_date)] for every row whose magic is a number.

    THE NON-NUMERIC FILTER IS LOAD-BEARING and it is the same one check_precommit_staged had to
    have spelled correctly: some rows carry a blank magic, and reading blanks as equal would
    report them as a collision with each other.

    🔴 ORDER-1260 #5 -- WHAT THE OLD SENTENCE HERE GOT WRONG, AND IT IS A CLASS OF ERROR THIS
    REPO HAS A NAME FOR. It read "measured on the real file, this drops exactly the rows with no
    magic and nothing else". That is a statement about the FILE ON ONE DAY, not a property the
    filter enforces -- and it was written inside the module that owns global uniqueness for a
    real-money magic. Measured at HEAD: three ACTIVE rows in (one good, one blank, one `99x001`),
    ONE row out, no refusal and no count. An ACTIVE deployment whose magic is malformed vanishes
    from every uniqueness check in the system, silently.
    (memory: unreadable-input-must-refuse-not-skip)

    The filter stays -- a blank magic on a row that is not deployed is ordinary -- but it is now
    a DECLARED exemption with a boundary rather than a silent drop: a row is only dropped when
    its status says nothing is running. A row that says something IS running and does not say
    what magic it is running under is unreadable input, and unreadable input refuses.
    """
    out = []
    unreadable = []
    with io.open(path, 'r', encoding='utf-8-sig', newline='') as fh:
        for n, row in enumerate(csv.DictReader(fh), 2):     # 2 = the first data line, 1 is header
            raw = (row.get('magic') or '').strip()
            if not raw.isdigit():
                status = (row.get('status') or '').strip().upper()
                if status in INVENTORY_RUNNING_STATUSES:
                    unreadable.append('line %d: account %r has status %s and magic %r, which is '
                                      'not a number -- a running deployment with no readable '
                                      'magic is invisible to every uniqueness check, which is the '
                                      'one thing this file exists to make impossible'
                                      % (n, (row.get('account') or '').strip(), status, raw))
                continue
            out.append({'account': (row.get('account') or '').strip(), 'magic': int(raw),
                        'status': (row.get('status') or '').strip(),
                        'judge_date': (row.get('judge_date') or '').strip()})
    if unreadable:
        raise Refused('%s: %s' % (path, '; '.join(unreadable)))
    return out


def accounts_by_magic(inventory):
    """{magic: sorted distinct accounts}. A magic on more than one account is a collision under
    the GLOBAL rule regardless of status: `990103` and `991002` each have one side already
    REMOVED, and the historical deals a reused magic would re-attribute are still in the account
    history whether or not the EA is attached today."""
    by = collections.defaultdict(set)
    for r in inventory:
        by[r['magic']].add(r['account'])
    return dict((m, sorted(a)) for m, a in by.items())


# ---------------------------------------------------------------------------------------------
# THE VALIDATOR. M1-M6.
# ---------------------------------------------------------------------------------------------
def validate_allocation(row):
    problems = []
    if not isinstance(row, dict):
        return ['M1 a MagicAllocation must be an object, got %s' % type(row).__name__]
    missing = [f for f in ALLOC_FIELDS if f not in row]
    extra = [f for f in row if f not in ALLOC_FIELDS + OPTIONAL_FIELDS]
    if missing or extra:
        problems.append('M1 allocation missing %s / unknown %s' % (sorted(missing), sorted(extra)))
        return problems
    if row['entity'] != 'MagicAllocation':
        problems.append('M1 entity must be MagicAllocation, got %r' % row['entity'])
    magic = S.normalize_numbers(row['magic'])
    if not isinstance(magic, int) or isinstance(magic, bool) or magic < 1:
        problems.append('M1 magic %r is not an integer >= 1' % (row['magic'],))
    if row['scope'] not in SCOPES:
        problems.append('M1 scope %r is not one of %s' % (row['scope'], list(SCOPES)))
    if row['status'] not in STATUSES:
        problems.append('M1 status %r is not one of %s' % (row['status'], list(STATUSES)))
    if not HEX40_RE.match(str(row['allocated_at_commit'])):
        problems.append('M1 allocated_at_commit %r is not a 40-hex oid'
                        % row['allocated_at_commit'])
    if row.get('allocated_to') is not None and not CAND_ID_RE.match(str(row['allocated_to'])):
        problems.append('M1 allocated_to %r is not a candidate_id' % row['allocated_to'])
    if problems:
        return problems

    # -- M2 the scope and the exception flags must agree. schemas.json states this as a
    #    conditional; it is restated here because the schema is validated by ajv in a suite that
    #    does not run when a row is appended.
    if row['scope'] == 'LEGACY_ACCOUNT_SCOPED':
        if row.get('legacy_exception') is not True:
            problems.append('M2 a LEGACY_ACCOUNT_SCOPED row must set legacy_exception=true')
        accts = row.get('legacy_accounts')
        if not isinstance(accts, list) or len(accts) < 2:
            problems.append('M2 legacy_accounts must list at least 2 accounts -- a legacy '
                            'exception exists precisely because the magic is on more than one')
        elif len(set(accts)) != len(accts):
            problems.append('M2 legacy_accounts repeats an account: %s' % accts)
        if row.get('imported_in_cutover') is not True:
            # -- M6, stated on the row rather than only across the store, so a single row handed
            #    to the validator alone is still refused.
            problems.append('M6 a LEGACY_ACCOUNT_SCOPED row must carry imported_in_cutover=true. '
                            'Legacy exceptions are a CLOSED SET imported once, not an open '
                            'category (schemas.json RE-AUDIT P1) -- minting a new one after the '
                            'cutover would reintroduce account-scoped magics forever.')
    else:
        if row.get('legacy_exception') not in (False, None):
            problems.append('M2 a %s row may not set legacy_exception=%r'
                            % (row['scope'], row.get('legacy_exception')))
        if row.get('legacy_accounts'):
            problems.append('M2 legacy_accounts is populated only for legacy exceptions')
    return problems


def store_problems(rows, declared_legacy=None):
    """Every problem with the store AS A WHOLE. Per-row rules are `validate_allocation`; these are
    the ones no single row can answer.

    `declared_legacy` is INJECTED rather than read from disk so this function stays pure -- the
    same reason `candidate.validate_manifest` takes `run_lookup`. When it is None the membership
    criterion (M7) is SKIPPED and SAYS SO in the returned list, because a check that passes
    silently when its input is absent is the shape this repo keeps paying for
    (memory `guard-disarmed-by-prose-reported-as-note`). Every real caller passes
    `declared_legacy_magics()`.
    """
    problems = []
    for i, row in enumerate(rows):
        problems.extend('line %d: %s' % (i + 1, p) for p in validate_allocation(row))
    if problems:
        return problems

    # -- M3 one row per magic. The store is the allocator's own uniqueness record, so a repeated
    #    magic here is two allocations of one number -- the exact thing it exists to prevent,
    #    inside the file that exists to prevent it.
    seen = collections.Counter(S.normalize_numbers(r['magic']) for r in rows)
    dups = sorted(m for m, n in seen.items() if n > 1)
    if dups:
        problems.append('M3 the store holds more than one allocation for magic(s) %s' % dups)

    # -- M6 the closed set, across the store. Every legacy row must have been imported at ONE
    #    commit; a legacy row at any other commit is a post-cutover mint.
    legacy = [r for r in rows if r['scope'] == 'LEGACY_ACCOUNT_SCOPED']
    commits = sorted(set(r['allocated_at_commit'] for r in legacy))
    if len(commits) > 1:
        problems.append('M6 legacy exceptions were imported at %d different commits (%s) -- the '
                        'set is imported ONCE, at the cutover, and a second import commit is how '
                        'an open category grows back'
                        % (len(commits), [c[:12] for c in commits]))

    # -- M7 THE CLOSED SET IS CLOSED BY MEMBERSHIP, NOT BY TIMESTAMP. ORDER-1260 #4.
    #    M6 above asks WHEN, which a forged row answers by copying the oid out of the file it is
    #    attacking. This asks WHICH, against the declaration.
    present = sorted(S.normalize_numbers(r['magic']) for r in legacy)
    if declared_legacy is None:
        problems.append('M7 SKIPPED: no declared legacy set was supplied, so the MEMBERSHIP of the '
                        'closed exception set was not checked -- only that its rows agree on one '
                        'import commit (M6). The store has been checked for CONSISTENCY, not for '
                        'the set being the one the owner declared.')
    else:
        want = sorted(S.normalize_numbers(m) for m in declared_legacy)
        if present != want:
            problems.append('M7 the legacy exceptions in this store are %s but schemas.json '
                            'declares the closed set as %s. Extra %s / missing %s -- a legacy '
                            'exception is account-scoped uniqueness held open forever, so the set '
                            'grows by a user decision recorded in the declaration, never by a row '
                            'appearing in the store'
                            % (present, want, sorted(set(present) - set(want)),
                               sorted(set(want) - set(present))))
    return problems


def inventory_problems(inventory, rows):
    """The GLOBAL rule, read against the exception list. BOTH DIRECTIONS.

    This is the function `check_state.ps1` reimplements in PowerShell, and the two are kept
    honest by the cage driving the same fixtures through both (design's own lesson: a cage over a
    pure module proves the pure module and nothing else).
    """
    problems = []
    declared = dict((S.normalize_numbers(r['magic']), sorted(r.get('legacy_accounts') or []))
                    for r in rows if r['scope'] == 'LEGACY_ACCOUNT_SCOPED')
    observed = accounts_by_magic(inventory)

    # -- M4 SENSITIVITY: every real collision is declared, with the SAME accounts.
    for magic in sorted(observed):
        accts = observed[magic]
        if len(accts) < 2:
            continue
        if magic not in declared:
            problems.append('M4 magic %d is on %d accounts (%s) and is not a declared legacy '
                            'exception -- scope is GLOBAL, one magic belongs to exactly one EA '
                            'across every account' % (magic, len(accts), accts))
        elif declared[magic] != accts:
            problems.append('M4 magic %d is declared frozen to %s but the inventory has it on %s '
                            '-- a frozen exception that moved is not frozen'
                            % (magic, declared[magic], accts))

    # -- M5 SPECIFICITY: every declared exception is a real collision. Without this the list can
    #    be satisfied by declaring everything, which turns the exception list into an off switch.
    for magic in sorted(declared):
        accts = observed.get(magic, [])
        if len(accts) < 2:
            problems.append('M5 magic %d is declared a legacy exception but the inventory has it '
                            'on %s -- a stale exception is a hole held open for a collision that '
                            'no longer exists' % (magic, accts or 'no account at all'))
    return problems


# ---------------------------------------------------------------------------------------------
# THE ALLOCATOR. There is no renumber function, and there is no legacy-mint function.
# ---------------------------------------------------------------------------------------------
def allocate(rows, inventory, commit_oid, magic=None, allocated_to=None):
    """One new GLOBAL reservation. Returns the row; raises `Refused` rather than returning it.

    `magic=None` picks the next free number above everything the store and the inventory already
    know about. Handing one in is allowed and checked -- the caller who knows which number they
    want is usually right, and always worth refusing when they are not.
    """
    if not HEX40_RE.match(str(commit_oid)):
        raise Refused('allocated_at_commit %r is not a 40-hex oid' % (commit_oid,))
    if allocated_to is not None and not CAND_ID_RE.match(str(allocated_to)):
        raise Refused('allocated_to %r is not a candidate_id' % (allocated_to,))
    taken = set(S.normalize_numbers(r['magic']) for r in rows)
    used = set(r['magic'] for r in inventory)
    if magic is None:
        magic = max(taken | used | set([0])) + 1
    magic = S.normalize_numbers(magic)
    if not isinstance(magic, int) or isinstance(magic, bool) or magic < 1:
        raise Refused('magic %r is not an integer >= 1' % (magic,))
    if magic in taken:
        prior = [r for r in rows if S.normalize_numbers(r['magic']) == magic][0]
        # RETIRED is named separately because it is the one that reads as free and is not:
        # design 4.6, a reused magic silently re-attributes historical deals.
        raise Refused('magic %d is already allocated (%s/%s)%s'
                      % (magic, prior['scope'], prior['status'],
                         ' -- and RETIRED is never re-issued' if prior['status'] == 'RETIRED'
                         else ''))
    if magic in used:
        raise Refused('magic %d is already on account(s) %s in %s -- allocating it would attribute '
                      'two EAs to one number' % (magic, accounts_by_magic(inventory)[magic],
                                                 INVENTORY_REL))
    row = {
        'entity': 'MagicAllocation', 'magic': magic, 'scope': 'GLOBAL',
        'legacy_exception': False,
        'allocated_to': allocated_to,
        'status': 'ASSIGNED' if allocated_to else 'RESERVED',
        'allocated_at_commit': commit_oid,
    }
    problems = validate_allocation(row)
    if problems:
        raise Refused('the allocator produced an invalid row: %s' % '; '.join(problems))
    return row


def cutover_import(inventory, commit_oid):
    """THE ONE PLACE a LEGACY_ACCOUNT_SCOPED row is ever produced. Run once.

    Every distinct magic in the inventory gets a row: the collisions as frozen exceptions, the
    rest as GLOBAL/ASSIGNED. Importing the non-colliding magics too is not tidiness -- the
    allocator's "next free number" question is answerable from ONE file only if that file knows
    every number already spent.

    `deployment_ref` is deliberately NOT populated. It is optional in the contract, and pinning
    every row to a blob of DEPLOYMENTS.csv would make an ordinary inventory edit stale 60 rows at
    once -- a toll with no reader, which is the shape `approval-pinning-self-invalidates` cost a
    session to learn. DEPLOYMENTS.csv already owns the deployment side of this relationship.
    """
    observed = accounts_by_magic(inventory)
    rows = []
    for magic in sorted(observed):
        accts = observed[magic]
        if len(accts) > 1:
            rows.append({
                'entity': 'MagicAllocation', 'magic': magic, 'scope': 'LEGACY_ACCOUNT_SCOPED',
                'legacy_exception': True, 'legacy_accounts': accts,
                'imported_in_cutover': True, 'allocated_to': None, 'status': 'ASSIGNED',
                'allocated_at_commit': commit_oid,
            })
        else:
            rows.append({
                'entity': 'MagicAllocation', 'magic': magic, 'scope': 'GLOBAL',
                'legacy_exception': False, 'allocated_to': None, 'status': 'ASSIGNED',
                'allocated_at_commit': commit_oid,
            })
    return rows


# ---------------------------------------------------------------------------------------------
# DISK
# ---------------------------------------------------------------------------------------------
def store_path(root=None):
    return os.path.join(root or ROOT, STORE_REL.replace('/', os.sep))


def inventory_path(root=None):
    return os.path.join(root or ROOT, INVENTORY_REL.replace('/', os.sep))


def read_store(path):
    if not os.path.exists(path):
        return []
    out = []
    with io.open(path, 'r', encoding='utf-8-sig') as fh:
        for n, raw in enumerate(fh, 1):
            raw = raw.strip()
            if not raw:
                continue
            try:
                out.append(json.loads(raw))
            except ValueError as exc:
                raise ValueError('%s line %d is not JSON: %s' % (path, n, exc))
    return out


def append_allocation(path, row, inventory, root=None):
    """Append one row after re-reading the store from disk, for the reason `attestation` does:
    uniqueness is a claim about the file, not about the caller's snapshot.

    This is at the impure edge, so it READS the declared legacy set rather than taking it: a
    writer that could be handed a set is a writer that could be handed the wrong one.
    """
    rows = read_store(path)
    if row['scope'] == 'LEGACY_ACCOUNT_SCOPED':
        raise Refused('M6 a legacy exception may only be created by the cutover import -- the set '
                      'is closed (schemas.json RE-AUDIT P1)')
    problems = validate_allocation(row)
    problems.extend(store_problems(rows + [row], declared_legacy_magics(root)))
    problems.extend(inventory_problems(inventory, rows + [row]))
    if problems:
        raise Refused('; '.join(problems))
    d = os.path.dirname(path)
    if d and not os.path.isdir(d):
        os.makedirs(d)
    with io.open(path, 'a', encoding='utf-8', newline='\n') as fh:
        fh.write(S.canonical(row) + '\n')
    return row['magic']


# ---------------------------------------------------------------------------------------------
# The vocabulary must be the SCHEMA's.
# ---------------------------------------------------------------------------------------------
def assert_vocabulary_matches_schema(root=None):
    path = os.path.join(root or ROOT, '_triage', 'factory_os', 'schemas.json')
    with io.open(path, 'r', encoding='utf-8-sig') as fh:
        schema = json.load(fh)
    d = schema['$defs']['MagicAllocation']
    problems = []
    if tuple(sorted(ALLOC_FIELDS)) != tuple(sorted(d['required'])):
        problems.append('ALLOC_FIELDS %s != schema required %s'
                        % (sorted(ALLOC_FIELDS), sorted(d['required'])))
    known = tuple(sorted(ALLOC_FIELDS + OPTIONAL_FIELDS))
    if known != tuple(sorted(d['properties'])):
        problems.append('the known field set %s != schema properties %s'
                        % (list(known), sorted(d['properties'])))
    for name, mine, theirs in (('SCOPES', SCOPES, d['properties']['scope']['enum']),
                               ('STATUSES', STATUSES, d['properties']['status']['enum'])):
        if tuple(mine) != tuple(theirs):
            problems.append('%s %s != schema %s' % (name, list(mine), list(theirs)))
    return problems


# ---------------------------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------------------------
def _emit(obj, code=0):
    sys.stdout.write(S.canonical(obj) + '\n')
    return code


def main(argv):
    if not argv or argv[0] in ('-h', '--help'):
        sys.stdout.write(__doc__)
        return 0
    cmd = argv[0]
    args = {}
    for a in argv[1:]:
        if a.startswith('--') and '=' in a:
            k, v = a[2:].split('=', 1)
            args[k.replace('-', '_')] = v
    root = args.get('root') or ROOT

    if cmd == '--self-test':
        return _selftest()

    try:
        rows = read_store(args.get('store') or store_path(root))
        inventory = read_inventory(args.get('inventory') or inventory_path(root))
    except (IOError, OSError, ValueError) as exc:
        sys.stderr.write('%s\n' % exc)
        return 2
    except Refused as exc:
        # ORDER-1260 #5: an inventory row that says something is RUNNING and does not say under
        # which magic. Exit 2 (unreadable input), not 1 (a refusal about the store's contents) --
        # the store was never reached, and saying "the magic rule failed" would name the wrong file.
        sys.stderr.write('%s\n' % exc)
        return 2

    if cmd == 'verify':
        problems = store_problems(rows, declared_legacy_magics(root)) \
            + inventory_problems(inventory, rows)
        if problems:
            return _emit({'action': 'REFUSE', 'why': problems}, 1)
        return _emit({'action': 'VERIFIED', 'allocations': len(rows),
                      'inventory_rows_with_a_magic': len(inventory),
                      'legacy_exceptions': sorted(S.normalize_numbers(r['magic']) for r in rows
                                                  if r['scope'] == 'LEGACY_ACCOUNT_SCOPED')})

    if cmd == 'exceptions':
        return _emit({'action': 'EXCEPTIONS',
                      'legacy': dict((str(S.normalize_numbers(r['magic'])),
                                      sorted(r.get('legacy_accounts') or []))
                                     for r in rows if r['scope'] == 'LEGACY_ACCOUNT_SCOPED')})

    if cmd == 'next':
        try:
            row = allocate(rows, inventory, args.get('commit', '0' * 40))
        except Refused as exc:
            return _emit({'action': 'REFUSE', 'why': str(exc)}, 1)
        return _emit({'action': 'NEXT', 'magic': row['magic']})

    sys.stderr.write('unknown command %r\n' % cmd)
    return 2


def _selftest():
    problems = assert_vocabulary_matches_schema()
    for p in problems:
        sys.stdout.write('  [FAIL] %s\n' % p)
    sys.stdout.write('magic self-test: %s\n' % ('FAILED' if problems else 'ok'))
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
