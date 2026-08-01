"""Cage for check_work_receipts.py -- every clause of the AGENTS.md section 2 grant, both ways.

The grant is NARROW. A guard for a narrow grant has to be driven in both directions or it is
indistinguishable from a guard for a wide one: ATTACK cases prove each limit refuses, CONTROL cases
prove the permitted act still LANDS. The second half is the one this repo has repeatedly got wrong
-- a guard that refuses everything passes every attack test and rebuilds the trap it replaced
(memory `ledger-cell-is-prose-and-parser-input`, and ORDER-731 item 1's CONTROL case).

Criteria named in string literals on purpose: `run_guard_shape_lint.py` L2 requires the suite that
pairs with a checker to name every criterion that checker can emit -- W0, W1, W2, W3, W4, W5.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_work_receipts as wr  # noqa: E402

NL = chr(10)
HDR = '{"_comment": "header"}'
R1 = '{"order_id": "ORDER-880", "agent": "qwen", "artifact": "reports/x.csv"}'
R2 = '{"order_id": "ORDER-881", "agent": "sonnet", "artifact": "reports/y.csv"}'

_bad = []


def case(kind, name, ok, detail=''):
    print('  [%s] %-11s %s' % ('OK ' if ok else 'BAD', kind, name))
    if not ok:
        if detail:
            print('        -> %s' % detail)
        _bad.append(name)


def run(staged, head=None):
    problems = []
    wr.check(staged, head, problems)
    return problems


def main():
    print('=== WORK RECEIPTS: the section 2 grant, driven both ways ===\n')

    # ---- W0 / CONTROL: the permitted act must LAND ----------------------------------------
    base = HDR + '\n' + R1 + '\n'
    case('CONTROL', 'W0 a header-only file is valid, not an error',
         run(HDR + '\n') == [], run(HDR + '\n'))
    case('CONTROL', 'appending a NEW row to an existing file is permitted',
         run(base + R2 + '\n', head=base) == [], run(base + R2 + '\n', head=base))
    case('CONTROL', 'W2 CRLF at HEAD vs LF staged is not a rewrite',
         run(base + R2 + '\n', head=base.replace('\n', '\r\n')) == [],
         run(base + R2 + '\n', head=base.replace('\n', '\r\n')))

    # ---- W2 ATTACK: edit and delete ---------------------------------------------------------
    edited = HDR + '\n' + R1.replace('qwen', 'TAMPERED') + '\n'
    p = run(edited, head=base)
    case('ATTACK', 'W2 editing an existing row is refused',
         any(x.startswith('W2') for x in p), p)
    p = run(HDR + '\n', head=base)
    case('ATTACK', 'W2 deleting an existing row is refused',
         any(x.startswith('W2') for x in p), p)

    # ---- W1 ---------------------------------------------------------------------------------
    p = run(HDR + '\nnot json\n')
    case('ATTACK', 'W1 a line that is not JSON is refused by name',
         any(x.startswith('W1') for x in p), p)
    p = run(HDR + '\n[1,2,3]\n')
    case('ATTACK', 'W1 a JSON array is refused -- a receipt is an object',
         any(x.startswith('W1') for x in p), p)

    # ---- W3 ---------------------------------------------------------------------------------
    p = run(HDR + '\n{"agent": "qwen"}\n')
    case('ATTACK', 'W3 a row with no order_id is refused',
         any(x.startswith('W3') for x in p), p)

    # ---- W4: THE clause that keeps the grant narrow ------------------------------------------
    for field, val in (('verdict', 'PASS'), ('status', 'DONE'), ('judge_date', '2026-10-09'),
                       ('approved', True)):
        row = '{"order_id": "ORDER-882", "%s": %s}' % (
            field, ('"%s"' % val) if isinstance(val, str) else 'true')
        p = run(HDR + '\n' + row + '\n')
        case('ATTACK', 'W4 a row carrying %-10s is refused' % field,
             any(x.startswith('W4') for x in p), p)
    # SPECIFICITY: the closed list must not swallow innocent fields, or agents cannot record work.
    p = run(HDR + '\n{"order_id": "ORDER-883", "artifact": "a.csv", "seconds": 12, "agent": "qwen"}\n')
    case('SPECIFICITY', 'W4 stays SILENT on ordinary work fields',
         p == [], p)
    # The two evasions that killed the deny-list version, found by probing it. Both must now fail,
    # plus an invented name -- which is precisely what a deny-list can never cover.
    p = run(HDR + NL + '{"order_id": "ORDER-884", "result": {"verdict": "PASS"}}' + NL)
    case('ATTACK', 'W4 a NESTED verdict is refused (the deny-list missed it)',
         any(x.startswith('W4') for x in p), p)
    p = run(HDR + NL + '{"order_id": "ORDER-885", "pf": 2.1, "net_profit": 900}' + NL)
    case('ATTACK', 'W4 pf / net_profit are refused (never on the deny-list at all)',
         any(x.startswith('W4') for x in p), p)
    p = run(HDR + NL + '{"order_id": "ORDER-886", "made_up_field": 1}' + NL)
    case('ATTACK', 'W4 an INVENTED field is refused -- that is what an allow-list buys',
         any(x.startswith('W4') for x in p), p)

    # ---- W5 ---------------------------------------------------------------------------------
    p = run(HDR + '\n' + R1 + '\n' + R1 + '\n')
    case('ATTACK', 'W5 a second receipt for the same order is refused',
         any(x.startswith('W5') for x in p), p)
    p = run(HDR + '\n' + R1 + '\n' + R2 + '\n')
    case('SPECIFICITY', 'W5 two DIFFERENT orders are fine',
         p == [], p)

    # ---- ENGAGEMENT: the guard must be able to fail on the REAL file ------------------------
    # If check() were inert, every case above would pass and so would this -- so the mutation is
    # what makes the suite load-bearing: neutralise the append-only comparison and the ATTACK
    # cases must go red.
    real_head, real_staged = base, HDR + '\n'      # a deletion, the clearest breach
    saved = wr._norm
    try:
        wr._norm = lambda t: ''                     # mutation: every comparison becomes trivially true
        mutated = run(real_staged, head=real_head)
    finally:
        wr._norm = saved
    case('ENGAGEMENT', 'the W2 mutation is DETECTED (suite is load-bearing)',
         mutated == [] and any(x.startswith('W2') for x in run(real_staged, head=real_head)),
         'mutated=%r' % (mutated,))

    # ---- W2 on the FILE, not just its rows. Found by probing main(), not by reading it: the
    # ---- first version answered "is it in the index?", so `git rm --cached` printed "does not
    # ---- exist yet" and exited 0 -- an append-only guard that permitted deleting the whole log.
    # ---- check() never saw this because the hole was in main()'s early return, which is exactly
    # ---- why a cage that only drives the pure function is not enough.
    class _Src(object):
        def __init__(self, present):
            self.present = present

        def exists_committed(self, rel):
            return self.present

        def read_committed(self, rel):
            return HDR + NL

    saved_head, saved_src = wr._head_text, wr._src
    try:
        wr._head_text = lambda: HDR + NL + R1 + NL      # HEAD HAS receipts
        wr._src = lambda: _Src(False)                     # ...and the snapshot does not
        rc_del = wr.main([])
        wr._head_text = lambda: None                      # no history at all
        wr._src = lambda: _Src(False)
        rc_new = wr.main([])
    finally:
        wr._head_text, wr._src = saved_head, saved_src
    case('ATTACK', 'W2 DELETING the whole file is refused, not read as "no file yet"',
         rc_del == 1, 'main() returned %r' % rc_del)
    case('CONTROL', 'W0 a file that never existed still passes (the two are told apart)',
         rc_new == 0, 'main() returned %r' % rc_new)

    print()
    if _bad:
        print('=== %d CASE(S) DID NOT BEHAVE AS DECLARED ===' % len(_bad))
        return 1
    print('=== the grant is enforced, and the permitted act still lands ===')
    return 0


if __name__ == '__main__':
    sys.exit(main())
