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

import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import evidence  # noqa: E402

RECEIPTS_PATH = 'factory/work_receipts.jsonl'
TAG = '[work-receipts]'

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


def check(staged_text, head_text, problems):
    """The whole rule set, over TEXT -- so the cage can drive it without a git repo."""
    # W2 first: it is a claim about the file as a whole, and a rewrite makes every row suspect.
    if head_text is not None:
        head_n, staged_n = _norm(head_text), _norm(staged_text)
        if not staged_n.startswith(head_n):
            problems.append(
                'W2 %s is APPEND-ONLY and this change is not an append: the bytes at HEAD are no '
                'longer a prefix of the staged bytes. An existing receipt was edited or deleted. '
                'Add a new row instead -- history is the point of the file.' % RECEIPTS_PATH)

    rows, seen = [], {}
    for n, raw in enumerate(_norm(staged_text).split('\n'), start=1):
        if not raw.strip():
            continue
        try:
            obj = json.loads(raw)
        except ValueError as exc:
            problems.append('W1 %s line %d is not valid JSON: %s' % (RECEIPTS_PATH, n, exc))
            continue
        if not isinstance(obj, dict):
            problems.append('W1 %s line %d is a %s, not an object'
                            % (RECEIPTS_PATH, n, type(obj).__name__))
            continue
        if list(obj.keys()) == ['_comment']:
            continue          # W0: the header line is not a receipt
        rows.append((n, obj))

    for n, obj in rows:
        oid = str(obj.get('order_id') or '').strip()
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


def main(argv=None):
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)
    src = _src()
    problems = []

    # HEAD is resolved FIRST, and that ordering is the fix for a hole found by PROBING this guard
    # rather than reading it: the first version asked "is the file in the index?" and, on
    # `git rm --cached factory/work_receipts.jsonl`, answered no, printed "does not exist yet" and
    # exited 0. An APPEND-ONLY guard that permitted deleting the entire log -- every receipt gone in
    # one commit, silently. W0 means "nobody has written one yet"; it does NOT mean "somebody
    # removed them all", and only HEAD can tell those two apart.
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
