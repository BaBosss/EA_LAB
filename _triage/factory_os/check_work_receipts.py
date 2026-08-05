"""S14 Work Receipts -- the guard that makes the WRITER GRANT true.

WHY THIS EXISTS. `AGENTS.md` section 2 was amended on 2026-08-01 to let every agent APPEND to
`factory/work_receipts.jsonl`. A permission row is prose; prose does not refuse anything. The grant
was written as a NARROW one on purpose, and every clause of it is checked here -- otherwise the
narrow grant is indistinguishable from the wide one nobody agreed to.

WHAT IT ASSERTS -- each id is emitted verbatim so a failure names its own rule:

  W1  every non-blank line parses as JSON, and is an OBJECT. "The tool broke" and "the file is
      wrong" must not share an outcome, so a scalar is reported, never raised.
  W2  APPEND-ONLY: the bytes committed at HEAD must be a byte PREFIX of the bytes being STAGED.
      Appending passes; editing or deleting anything already committed fails. Same rule and same
      reasoning as `s2a_attestations.jsonl` (policy G5), including CRLF normalisation on BOTH sides
      before the comparison -- a Windows checkout must not read as a rewrite.
  W3  a row carries a non-blank `order_id`.
  W4  a row carries ONLY allowed fields (`ALLOWED_FIELDS`, a CLOSED allow-list), and hides no
      judgement key at any depth (`BANNED_ANYWHERE`). This is the clause that keeps the grant
      narrow: an agent may record THAT it did work and where the output went, never what the work
      was worth. Verdicts stay `Claude / the user only`. It is an allow-list because a deny-list
      over an open key space cannot be complete -- probing the deny-list version found two evasions
      immediately (a nested `verdict`, and `pf`, which was never on it).
  W5  one row per order id -- a duplicate `order_id` is refused. Two receipts for one order is two
      answers to one question, and nothing downstream could choose between them.
  W0  an absent or header-only file is VALID, not an error: it means no receipt has been written
      yet. (Same shape as the attestation log's G0. A guard that fails on an empty artifact makes
      the artifact impossible to create.)
  W6  the GRANT ITSELF has not moved: `AGENTS.md`'s section 2 row for this file must be byte-for-byte
      the pinned text, and must appear exactly once.
  W7  no OTHER line of `AGENTS.md` speaks about the receipts file, unless it is in the closed
      `ALLOWED_EXTRA_MENTIONS` declaration.

WHY W6/W7 EXIST (round-3 review, M6 -- the one finding the previous two rounds left open).
`AGENTS.md` was declared in `$SUITE_GUARDS` for this suite, so editing it RUNS this guard. That is
only half a mechanism: nothing here READ the file, so the suite ran, passed, and the widened
permission row landed green. Declaring a file as a TRIGGER and never reading it is the same shape as
memory `citation-guard-satisfied-by-a-universal-file` -- the guard fires on the right commit and then
has no question to ask about it. W1-W5 police what agents WRITE under the grant; W6/W7 police the
grant's own text, which is the sentence W1-W5 are derived from.

WHAT W6 CAN AND CANNOT DO, stated rather than discovered. It cannot PREVENT a widening: the pin
lives in this file, which any agent may edit, so a commit that widens the row and moves the pin
together passes. What it removes is the SILENT widening -- the change now has to appear in a diff of
this checker, under a constant whose only purpose is to be that signal, and the refusal text below
names the owner requirement. Putting the digest somewhere an agent cannot edit means an owner-signed
surface (the S2a bundle), which costs a signature; it is queued onto the next signature batch rather
than taken here, and this paragraph is the record that the difference is known and not claimed away.

WHAT IT DOES NOT ASSERT, stated rather than discovered:
  * it does not check that the order id EXISTS on a board. A receipt for a typo'd order is a
    dangling receipt, not a permission breach, and the boards are not this guard's inputs.
  * it does not stop an agent writing a receipt for someone else's order. That needs an identity
    this repo does not have -- everything commits under one git identity (Codex audit 8's point
    about the attestation log applies here unchanged). The grant SAYS own-order-only; what is
    mechanically enforced is the shape, and this paragraph is why the two differ.

USAGE  tools\\python312\\python.exe _triage/factory_os/check_work_receipts.py
EXIT   0 valid  |  1 a rule was broken  |  2 tool failure (could not read what it must judge)
"""
from __future__ import annotations

import hashlib
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import evidence  # noqa: E402

RECEIPTS_PATH = 'factory/work_receipts.jsonl'
GRANT_PATH = 'AGENTS.md'
TAG = '[work-receipts]'

# THE PIN (W6). sha256 of the section 2 row for RECEIPTS_PATH, stripped of leading/trailing space,
# CRLF folded to LF, encoded utf-8. Taken from the row the owner confirmed verbatim in chat on
# 2026-08-01 before it was written -- the same bytes `AGENTS.md` line 86 carries at `d2f85d8c`.
#
# The clauses this digest is standing guard over, so a reader knows what a mismatch means without
# reconstructing it: APPEND ONLY, one row per order -- never edit or delete an existing row -- a row
# may cite only the writing agent's own order id -- no verdict, no order status, no field that feeds
# a decision. Every one of them is a limit W1-W5 implement; widening any of them widens this guard.
#
# TO RE-PIN, and it is deliberately a two-hand operation: a WIDENING needs the owner (AGENTS.md
# section 2 is explicit that Claude may not widen its own permissions), and only then does the
# digest move. A typo or formatting fix needs no owner but still needs this constant edited in the
# same commit, which is what makes the change visible in a diff instead of invisible in prose.
GRANT_ROW_SHA256 = '348c10aecc9118ed026e27ac59c84dd664515c47412d3d83433f506eb31f6cbf'

# W7's closed declaration -- normalised, stripped lines of AGENTS.md that are allowed to mention the
# receipts file BESIDES the pinned row. Empty today, and that is a measured fact, not a hope: at
# `d2f85d8c` exactly one line of AGENTS.md mentions it. It is a tuple rather than a "count <= 1"
# rule because a permission can be widened by a sentence somewhere else in the file just as easily
# as by editing the row, and a rule that allows N mentions without saying WHICH cannot tell the two
# apart. Adding a legitimate mention means adding it here, in a diff.
ALLOWED_EXTRA_MENTIONS = ()

# What counts as "speaking about the receipts file" for W7. The stem, not the full path, because
# `work_receipts.jsonl` and `factory/work_receipts.jsonl` are the same subject and a rule that only
# matched the long form would be evaded by dropping a directory.
GRANT_SUBJECT = 'work_receipts'

# An ALLOW-LIST, and the switch from a deny-list is the whole point. The first version listed
# banned names -- and probing it found two evasions in one minute: `{"result": {"verdict": "PASS"}}`
# passed because only top-level keys were read, and `pf` / `net_profit` were not on the list at all,
# though PF is the single most decision-bearing number this project has (the whole VERDICT GATE bar
# table is PF). A deny-list over an open key space can never be complete: any new name evades it.
# For a NARROW grant the correct instrument is a CLOSED declaration of what IS allowed -- the same
# reasoning as the attestation policy's closed vocabularies (R5/R7) and memory
# `citation-guard-satisfied-by-a-universal-file`.
#
# The rule these keys encode: an agent may record THAT work happened and where its output went.
# Anything that says what the work was WORTH is a judgement and belongs to the owner and the seat.
ALLOWED_FIELDS = (
    'order_id', 'agent', 'artifact', 'artifacts', 'started_at', 'finished_at',
    'seconds', 'command', 'note', 'lane', 'host', 'exit_code', 'rows', 'files',
)

# Belt and braces, because an allow-list only guards the keys it can see: these names are refused
# ANYWHERE in the row, including nested, so a permitted key cannot smuggle a judgement inside its
# own value. Not the primary defence -- ALLOWED_FIELDS is -- but it makes the nesting evasion that
# was actually found impossible rather than merely unlikely.
BANNED_ANYWHERE = (
    'verdict', 'decision', 'approved', 'signoff', 'signoff_state', 'promote',
    'rating', 'judge', 'judge_date', 'kill_rule', 'pf', 'profit_factor',
    'net_profit', 'drawdown', 'score', 'status', 'order_status',
)


def _src():
    mode = os.environ.get('EA_LAB_EVIDENCE', 'worktree')
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    return evidence.EvidenceSource(mode, root=root)


def _is_append(head_n, staged_n):
    """The append-only comparison, as its OWN seam -- and that is a testability decision.

    Round-2 review, M7: the cage's mutation neutralised `_norm`, which every criterion runs
    through, so W1/W3/W4/W5 died with W2 and the case proved only "the checker is not entirely
    inert" -- something any other case already proved. A mutation that kills everything
    discriminates nothing. Mutating THIS function turns W2 off and leaves the rest firing, which
    is what makes the case evidence about append-only specifically.
    """
    return staged_n.startswith(head_n)


def _banned_anywhere(node, found=None):
    """Every BANNED_ANYWHERE key reachable from `node`, at any depth."""
    found = set() if found is None else found
    if isinstance(node, dict):
        for k, v in node.items():
            if str(k).lower() in BANNED_ANYWHERE:
                found.add(str(k))
            _banned_anywhere(v, found)
    elif isinstance(node, (list, tuple)):
        for v in node:
            _banned_anywhere(v, found)
    return found


def _norm(text):
    return (text or '').replace('\r\n', '\n')


def _git_is_sane():
    """Can we talk to git at all? Round-2 review, M2.

    `evidence.exists_committed` returns `rc == 0` and never raises, and the HEAD read maps every
    failure to None -- so a BROKEN git produced "no file yet" / "no history yet" and the guard
    printed OK. The previous comment argued the conflation was confined to a harmless branch; that
    argument was circular, because the thing doing the confining runs the SAME git. Two readers
    failing in the same direction cannot be each other's cross-check. This asks a question whose
    answer does not depend on the receipts file at all, so a broken git is visible as a broken git.
    """
    try:
        import subprocess
        p = subprocess.run(['git', 'rev-parse', '--git-dir'], capture_output=True)  # snapshot: none
        return p.returncode == 0
    except Exception:
        return False


def _head_text():
    """HEAD's content, or None when the path has no history yet.

    A DIRECT git call rather than importing check_s2a_migration, and that is a deliberate
    narrowing: the declaration cage (run_guard_trigger_tests PART 4b) walks the import closure, and
    importing that module dragged check_s2a_migration and gen_design_contracts into this suite's
    guarded set -- two bundle-adjacent files this guard has no business being coupled to. Two lines
    of subprocess buy a closure of exactly {evidence.py}.

    None means "no history", which is the only case where append-only has nothing to protect
    (the attestation policy's G6 reasoning).
    """
    try:
        import subprocess
        p = subprocess.run(['git', 'cat-file', 'blob', 'HEAD:' + RECEIPTS_PATH],
                           capture_output=True)  # snapshot: HEAD
        if p.returncode == 0:
            return p.stdout.decode('utf-8')
    except Exception:
        pass
    return None


def check(staged_text, head_text, problems, grandfather=True):
    """The whole rule set, over TEXT -- so the cage can drive it without a git repo.

    GRANDFATHERING (round-2 review, M4). W2 judges the FILE and must see everything. The row-level
    criteria judge only rows this change ADDS, because the log is append-only and a row already at
    HEAD can never be repaired: one non-conforming row -- arrived via --no-verify, or made
    non-conforming later when a rule is TIGHTENED -- would otherwise freeze the artifact forever,
    since every legal remedy (edit it, delete it, delete the file) is refused by W2. A guard
    blocking its own repair is the family this repo has paid for repeatedly, and this session made
    it concrete: `pf` was a legal receipt field an hour before the allow-list landed.

    Duplicates still cross the boundary -- old order ids stay in `seen`, so a NEW row re-using one
    is refused. Only the old rows themselves stop being re-judged.
    """
    # W2 first: it is a claim about the file as a whole, and a rewrite makes every row suspect.
    if head_text is not None:
        head_n, staged_n = _norm(head_text), _norm(staged_text)
        if not _is_append(head_n, staged_n):
            problems.append(
                'W2 %s is APPEND-ONLY and this change is not an append: the bytes at HEAD are no '
                'longer a prefix of the staged bytes. An existing receipt was edited or deleted. '
                'Add a new row instead -- history is the point of the file.' % RECEIPTS_PATH)

    # Everything up to and including HEAD's last line is history: counted, never re-judged.
    # `.rstrip(chr(10))` matters: a file ending in a newline splits to a trailing EMPTY element,
    # and counting it made frozen_upto one too high -- which silently grandfathered the FIRST
    # NEW row, i.e. the exact row the guard exists to judge. Caught by probing, not by reading.
    _head_n = _norm(head_text).rstrip(chr(10)) if (grandfather and head_text is not None) else ''
    frozen_upto = len(_head_n.split(chr(10))) if _head_n else 0

    rows, seen = [], {}
    for n, raw in enumerate(_norm(staged_text).split('\n'), start=1):
        if not raw.strip():
            continue
        try:
            obj = json.loads(raw)
        except ValueError as exc:
            if n <= frozen_upto:
                continue
            problems.append('W1 %s line %d is not valid JSON: %s' % (RECEIPTS_PATH, n, exc))
            continue
        if not isinstance(obj, dict):
            if n <= frozen_upto:
                continue
            problems.append('W1 %s line %d is a %s, not an object'
                            % (RECEIPTS_PATH, n, type(obj).__name__))
            continue
        if list(obj.keys()) == ['_comment'] and n == 1:
            # LINE 1 ONLY (round-2 review, N9): allowing it anywhere made an unchecked
            # free-text channel -- a _comment row carrying a full verdict was accepted,
            # uncounted, at any position.
            continue
        rows.append((n, obj))

    for n, obj in rows:
        oid = str(obj.get('order_id') or '').strip()
        if n <= frozen_upto:
            if oid:
                seen.setdefault(oid, n)   # history still blocks a NEW duplicate
            continue
        if not oid:
            problems.append('W3 %s line %d carries no order_id, so nothing can be attributed to it'
                            % (RECEIPTS_PATH, n))
        else:
            if oid in seen:
                problems.append(
                    'W5 %s line %d is a SECOND receipt for %s (the first is line %d). One order, '
                    'one receipt -- two would be two answers to one question.'
                    % (RECEIPTS_PATH, n, oid, seen[oid]))
            else:
                seen[oid] = n
        bad = sorted(k for k in obj if k.lower() not in ALLOWED_FIELDS)
        if bad:
            problems.append(
                'W4 %s line %d carries field(s) %s that are not in the allowed set %s. The '
                'AGENTS.md section 2 grant is APPEND a record of work, never a judgement of it -- '
                'anything describing what the work was WORTH stays with the owner and the Claude '
                'seat.' % (RECEIPTS_PATH, n, ', '.join(bad), ', '.join(ALLOWED_FIELDS)))
        nested = sorted(_banned_anywhere(obj))
        if nested:
            problems.append(
                'W4 %s line %d hides judgement field(s) %s inside its values. A permitted key must '
                'not smuggle a verdict in its payload -- this is refused at any depth.'
                % (RECEIPTS_PATH, n, ', '.join(nested)))
    return len(rows)


def grant_rows(agents_text):
    """Every section 2 table row whose FIRST cell names the receipts file, as (line_no, text).

    The first cell only, and that is the point of the extraction: the row's subject is what makes it
    a grant for THIS file. A row about something else that happens to mention the receipts file in
    its prose is W7's business, not W6's, and conflating them would let a real second grant hide
    inside a first cell this function never looked at.
    """
    out = []
    for n, raw in enumerate(_norm(agents_text).split('\n'), start=1):
        line = raw.strip()
        if not line.startswith('|'):
            continue
        cells = line.split('|')
        if len(cells) > 1 and RECEIPTS_PATH in cells[1]:
            out.append((n, line))
    return out


def check_grant(agents_text, problems):
    """W6 + W7 over TEXT, so the cage can drive both directions without touching the real file.

    The digest actually seen is in the W6 failure text, not just in the return value: a pin failure
    that does not hand back the new digest makes a legitimate re-pin a guessing game, and a guard
    that is annoying to satisfy correctly gets satisfied incorrectly. The return value is for
    callers that want it without parsing prose (probes, and a future re-pin helper); it is None when
    the row is missing or duplicated, which are the two cases where no single digest exists.
    """
    rows = grant_rows(agents_text)
    seen_digest = None

    if not rows:
        problems.append(
            'W6 %s carries NO section 2 row for %s. The grant that authorises this log was removed '
            'or renamed. Removing the grant is the owner\'s call, not an agent\'s -- and every limit '
            'W1-W5 enforces is written in that row, so the checker would go on enforcing a sentence '
            'the repo no longer contains.' % (GRANT_PATH, RECEIPTS_PATH))
    elif len(rows) > 1:
        problems.append(
            'W6 %s carries %d section 2 rows for %s (lines %s). One file, one grant: a second row '
            'is a second permission, and the pinned one staying intact proves nothing about it.'
            % (GRANT_PATH, len(rows), RECEIPTS_PATH, ', '.join(str(n) for n, _ in rows)))
    else:
        n, text = rows[0]
        seen_digest = hashlib.sha256(text.encode('utf-8')).hexdigest()
        if seen_digest != GRANT_ROW_SHA256:
            problems.append(
                'W6 the %s section 2 grant row (line %d) is not the pinned text.\n'
                '       pinned: %s\n'
                '       staged: %s\n'
                '     If this is a WIDENING of what agents may write, it needs the owner -- section '
                '2 says Claude may not widen its own permissions, and the narrow grant is the only '
                'reason this log was allowed to exist. If it is a typo or formatting fix, move '
                'GRANT_ROW_SHA256 in check_work_receipts.py to the staged digest above, in this '
                'same commit, so the change is in the diff rather than in the prose.'
                % (GRANT_PATH, n, GRANT_ROW_SHA256, seen_digest))

    pinned_lines = set(text for _n, text in rows)
    for n, raw in enumerate(_norm(agents_text).split('\n'), start=1):
        line = raw.strip()
        if GRANT_SUBJECT not in line or line in pinned_lines:
            continue
        if line in ALLOWED_EXTRA_MENTIONS:
            continue
        problems.append(
            'W7 %s line %d speaks about %s outside the pinned grant row: %s\n'
            '     A permission can be widened by a sentence next to the row as easily as by editing '
            'it. If this mention is legitimate, declare it in ALLOWED_EXTRA_MENTIONS.'
            % (GRANT_PATH, n, RECEIPTS_PATH, line[:120] + ('...' if len(line) > 120 else '')))
    return seen_digest


def main(argv=None):
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)
    src = _src()
    # Round-2 review, M3: this printed no marker, so nothing could tell whether the mode ARRIVED.
    # Probed: the same staged tamper exits 1 with EA_LAB_EVIDENCE=index and 0 with it unset -- the
    # guard silently judged the DISK while the commit wrote the INDEX. evidence.py's own contract
    # says every consumer prints marker() exactly once; five other checkers do. Now six.
    print(src.marker('work-receipts'))
    problems = []

    # HEAD is resolved FIRST, and that ordering is the fix for a hole found by PROBING this guard
    # rather than reading it: the first version asked "is the file in the index?" and, on
    # `git rm --cached factory/work_receipts.jsonl`, answered no, printed "does not exist yet" and
    # exited 0. An APPEND-ONLY guard that permitted deleting the entire log -- every receipt gone in
    # one commit, silently. W0 means "nobody has written one yet"; it does NOT mean "somebody
    # removed them all", and only HEAD can tell those two apart.
    if not _git_is_sane():
        print('%s TOOL FAILURE: git is not answering, so "absent" and "unreadable" cannot be told '
              'apart -- refusing to report a verdict.' % TAG)
        return 2

    # W6/W7 run FIRST and run ALWAYS -- before the receipts file is even looked for. The grant is
    # the premise of every other rule here, and it is checkable whether or not a single receipt has
    # ever been written; deferring it until after the W0 early returns would leave the widening
    # unguarded in exactly the state the log spends most of its life in (empty).
    try:
        grant_text = src.read_committed(GRANT_PATH)  # snapshot: index under the hook
    except evidence.ToolFailure as exc:
        print('%s TOOL FAILURE reading %s, so the grant could not be checked: %s'
              % (TAG, GRANT_PATH, exc))
        return 2
    check_grant(grant_text, problems)
    if problems:
        for p in problems:
            print('  -> %s' % p)
        print(chr(10) + '=== %d PROBLEM(S) -- the work-receipt GRANT ITSELF moved ===' % len(problems))
        return 1
    # Said on EVERY path, including the W0 early returns below: a guard that only reports what it
    # checked when it also found rows to judge is a guard whose silence is ambiguous.
    print('%s grant row pinned OK (W6/W7) -- %s section 2 still says what W1-W5 enforce'
          % (TAG, GRANT_PATH))

    head_text = _head_text()
    present = src.exists_committed(RECEIPTS_PATH)

    if head_text is not None and not present:
        print('%s 0 receipt row(s); append-only judged against HEAD' % TAG)
        print("  -> W2 %s exists at HEAD and is DELETED by this change. Append-only means the file "
              "itself cannot be removed either -- every receipt recorded so far would go with it. "
              "Moving or retiring it is a permission change, and therefore the owner's "
              "(AGENTS.md section 2)." % RECEIPTS_PATH)
        print(chr(10) + '=== 1 PROBLEM(S) -- the work-receipt grant was exceeded ===')
        return 1

    if not present:
        # W0 proper: absent at HEAD AND absent now -- a file nobody has written to yet.
        # DECLARED LIMIT: `exists_committed` returns `rc == 0` from git (evidence.py:195-200), so a
        # git that FAILS is indistinguishable here from a path that is absent. The conflation is
        # confined to this branch and is harmless in it -- with no such file at HEAD there is
        # nothing an append-only rule could be protecting. Wherever the file DOES exist at HEAD the
        # branch above turns the same ambiguity into a REFUSAL, i.e. it fails closed.
        print('%s %s does not exist yet -- nothing to judge (W0)' % (TAG, RECEIPTS_PATH))
        return 0

    try:
        staged_text = src.read_committed(RECEIPTS_PATH)  # snapshot: index under the hook
    except evidence.ToolFailure as exc:
        # "I could not read it" must never share an outcome with "there is nothing wrong".
        print('%s TOOL FAILURE: %s' % (TAG, exc))
        return 2

    n = check(staged_text, head_text, problems)
    print('%s %d receipt row(s); append-only judged against %s'
          % (TAG, n, 'HEAD' if head_text is not None else 'nothing (no history yet)'))
    if problems:
        for p in problems:
            print('  -> %s' % p)
        print('\n=== %d PROBLEM(S) -- the work-receipt grant was exceeded ===' % len(problems))
        return 1
    print('%s OK -- every row is an append, attributable, and carries no judgement' % TAG)
    return 0


if __name__ == '__main__':
    sys.exit(main())
