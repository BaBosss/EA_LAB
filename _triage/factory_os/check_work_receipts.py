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
  W4  a row carries NO decision-bearing field. The closed list is DECISION_FIELDS below. This is
      the clause that keeps the grant narrow: an agent may record THAT it did work, never what the
      work was worth. Verdicts stay `Claude / the user only`.
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

# CLOSED list, not a heuristic. A substring test ("anything containing 'verdict'") would be the
# N4 defect this repo has paid for: it refuses `verdict_note` while missing `pf`. Adding a field
# here is a permission change and therefore an AGENTS.md edit, which is the owner's.
DECISION_FIELDS = (
    'verdict', 'decision', 'status', 'order_status', 'approved', 'signoff',
    'signoff_state', 'kill_rule', 'judge', 'judge_date', 'promote', 'rating',
)


def _src():
    mode = os.environ.get('EA_LAB_EVIDENCE', 'worktree')
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    return evidence.EvidenceSource(mode, root=root)


def _norm(text):
    return (text or '').replace('\r\n', '\n')


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
        bad = sorted(k for k in obj if k.lower() in DECISION_FIELDS)
        if bad:
            problems.append(
                'W4 %s line %d carries decision-bearing field(s) %s. The AGENTS.md section 2 grant '
                'is APPEND a record of work, never a judgement of it -- verdicts and order status '
                'stay with the owner and the Claude seat.' % (RECEIPTS_PATH, n, ', '.join(bad)))
    return len(rows)


def main(argv=None):
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)
    src = _src()
    problems = []

    try:
        if not src.exists_committed(RECEIPTS_PATH):
            # W0. Absent is not broken -- it is a file nobody has written to yet.
            print('%s %s does not exist yet -- nothing to judge (W0)' % (TAG, RECEIPTS_PATH))
            return 0
        staged_text = src.read_committed(RECEIPTS_PATH)  # snapshot: index under the hook
    except evidence.ToolFailure as exc:
        # "I could not read it" must never share an outcome with "there is nothing wrong".
        print('%s TOOL FAILURE: %s' % (TAG, exc))
        return 2

    # HEAD is read with a DIRECT git call rather than by importing check_s2a_migration, and that is
    # a deliberate narrowing rather than duplication: the declaration cage (run_guard_trigger_tests
    # PART 4b) walks the import closure, and importing that module dragged check_s2a_migration and
    # gen_design_contracts into this suite's guarded set -- two bundle-adjacent files this guard has
    # no business being coupled to. Two lines of subprocess buy a closure of exactly {evidence.py}.
    head_text = None
    try:
        import subprocess
        p = subprocess.run(['git', 'cat-file', 'blob', 'HEAD:' + RECEIPTS_PATH],
                           capture_output=True)  # snapshot: HEAD
        if p.returncode == 0:
            head_text = p.stdout.decode('utf-8')
    except Exception:
        # A file with no history yet has nothing to protect; append-only is silent (G6's reasoning).
        head_text = None

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
