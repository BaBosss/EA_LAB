"""Cage for check_work_receipts.py -- every clause of the AGENTS.md section 2 grant, both ways.

The grant is NARROW. A guard for a narrow grant has to be driven in both directions or it is
indistinguishable from a guard for a wide one: ATTACK cases prove each limit refuses, CONTROL cases
prove the permitted act still LANDS. The second half is the one this repo has repeatedly got wrong
-- a guard that refuses everything passes every attack test and rebuilds the trap it replaced
(memory `ledger-cell-is-prose-and-parser-input`, and ORDER-731 item 1's CONTROL case).

Criteria named in string literals on purpose: `run_guard_shape_lint.py` L2 requires the suite that
pairs with a checker to name every criterion that checker can emit -- W0, W1, W2, W3, W4, W5, and
(round 3, M6) W6 and W7, the two that judge the GRANT TEXT rather than what is written under it.
"""
from __future__ import annotations

import hashlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_work_receipts as wr  # noqa: E402

NL = chr(10)
HDR = '{"_comment": "header"}'
R1 = '{"order_id": "ORDER-880", "agent": "qwen", "artifact": "reports/x.csv"}'
R2 = '{"order_id": "ORDER-881", "agent": "sonnet", "artifact": "reports/y.csv"}'

# W6/W7 fixtures. A SYNTHETIC grant row with the pin patched to match it, not the real AGENTS.md
# line -- copying 813 real bytes in here would make this suite a second place the grant text lives,
# and two copies of one sentence drift. What the fixtures prove is that the RULE discriminates; that
# the rule is APPLIED to the real file is proven by the wrapper running the checker against the repo
# (run_work_receipts_tests.ps1 line ~64), which exits 1 the moment AGENTS.md and the pin disagree.
FAKE_ROW = ('| `factory/work_receipts.jsonl` (S14) | every agent -- APPEND ONLY, one row per '
            'order. No verdict, no order status. |')
FAKE_SHA = hashlib.sha256(FAKE_ROW.encode('utf-8')).hexdigest()
AGENTS_FIXTURE = ('## 2. who may write what' + NL + NL + '| path | who |' + NL + '|---|---|' + NL
                  + FAKE_ROW + NL + '| `MASTER_BACKLOG.md` | the owner |' + NL)

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


def run_grant(agents_text, extra=()):
    """W6/W7 against a fixture, with the pin patched to the fixture's own row.

    The patch is scoped and restored: it makes the fixture's UNMODIFIED row the pinned one, so every
    case below is a statement about what the rule does to a CHANGE, which is the only thing W6 has
    an opinion about.
    """
    saved_sha, saved_extra = wr.GRANT_ROW_SHA256, wr.ALLOWED_EXTRA_MENTIONS
    problems = []
    try:
        wr.GRANT_ROW_SHA256, wr.ALLOWED_EXTRA_MENTIONS = FAKE_SHA, tuple(extra)
        wr.check_grant(agents_text, problems)
    finally:
        wr.GRANT_ROW_SHA256, wr.ALLOWED_EXTRA_MENTIONS = saved_sha, saved_extra
    return problems


class _Src(object):
    """The ONE stub for main()'s evidence source -- and it answers for every file main() reads.

    That is not tidiness. main() reads two files now (the receipts log and the grant), and a stub
    that answers for one of them makes cases about the FIRST pass or fail on the SECOND. It did:
    see the comment at the W2-deletion cases below.
    """

    def __init__(self, present, grant=None):
        self.present = present                                   # about the RECEIPTS path only
        self.grant = AGENTS_FIXTURE if grant is None else grant

    def marker(self, component):
        return '##EVIDENCE-MODE## %s stub git_index=stub' % component

    def exists_committed(self, rel):
        return self.present

    def read_committed(self, rel, errors='strict'):
        return self.grant if rel == wr.GRANT_PATH else (HDR + NL)


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
    # Round-2 review, M7: the old mutation neutralised `_norm`, which EVERY criterion runs through,
    # so W1/W3/W4/W5 died alongside W2 and the case proved only "not entirely inert" -- something
    # any other case already proves. A mutation that kills everything discriminates nothing. This
    # one turns off the append comparison ALONE and asserts BOTH halves: W2 goes silent, and the
    # row criteria keep firing. The second half is what makes it evidence about append-only.
    row_probe = base + '{"order_id": "ORDER-887", "verdict": "PASS"}' + NL
    saved = wr._is_append
    try:
        wr._is_append = lambda h, s: True        # mutation: scoped to W2 and nothing else
        mutated_w2 = run(real_staged, head=real_head)
        still_firing = run(row_probe, head=base)
    finally:
        wr._is_append = saved
    case('ENGAGEMENT', 'a W2-ONLY mutation silences W2 and leaves the row criteria firing',
         mutated_w2 == [] and any(x.startswith('W4') for x in still_firing)
         and any(x.startswith('W2') for x in run(real_staged, head=real_head)),
         'w2=%r rows=%r' % (mutated_w2, still_firing))

    # ---- W2 on the FILE, not just its rows. Found by probing main(), not by reading it: the
    # ---- first version answered "is it in the index?", so `git rm --cached` printed "does not
    # ---- exist yet" and exited 0 -- an append-only guard that permitted deleting the whole log.
    # ---- check() never saw this because the hole was in main()'s early return, which is exactly
    # ---- why a cage that only drives the pure function is not enough.
    # ---- The stub answers for BOTH files main() reads. When W6 landed, this stub returned the
    # ---- receipts header for AGENTS.md too, so `rc == 1` below arrived from the GRANT check and
    # ---- the W2 case went green for a reason that had nothing to do with W2 -- a false green
    # ---- produced by adding a rule, inside the suite that exists to stop exactly that. With the
    # ---- grant fixture valid and the pin patched to it, W6/W7 pass first and `rc == 1` can only
    # ---- come from the append-only branch these two cases are about.
    saved_head, saved_src, saved_sha = wr._head_text, wr._src, wr.GRANT_ROW_SHA256
    try:
        wr.GRANT_ROW_SHA256 = FAKE_SHA
        wr._head_text = lambda: HDR + NL + R1 + NL      # HEAD HAS receipts
        wr._src = lambda: _Src(False)                     # ...and the snapshot does not
        rc_del = wr.main([])
        wr._head_text = lambda: None                      # no history at all
        wr._src = lambda: _Src(False)
        rc_new = wr.main([])
    finally:
        wr._head_text, wr._src, wr.GRANT_ROW_SHA256 = saved_head, saved_src, saved_sha
    case('ATTACK', 'W2 DELETING the whole file is refused, not read as "no file yet"',
         rc_del == 1, 'main() returned %r' % rc_del)
    case('CONTROL', 'W0 a file that never existed still passes (the two are told apart)',
         rc_new == 0, 'main() returned %r' % rc_new)

    # ---- M4 grandfathering: a rule tightened later must not freeze the log forever -----------
    old_head = HDR + NL + '{"order_id": "ORDER-890", "pf": 9}' + NL     # legal before the allow-list
    case('CONTROL', 'W4 a legal append on top of a now-ILLEGAL HEAD row still lands',
         run(old_head + R2 + NL, head=old_head) == [],
         run(old_head + R2 + NL, head=old_head))
    p = run(old_head + '{"order_id": "ORDER-891", "pf": 1}' + NL, head=old_head)
    case('ATTACK', 'W4 still judges a NEW row -- grandfathering is not an amnesty',
         any(x.startswith('W4') for x in p), p)
    p = run(old_head + '{"order_id": "ORDER-890", "agent": "q"}' + NL, head=old_head)
    case('ATTACK', 'W5 a new row re-using a GRANDFATHERED order id is still refused',
         any(x.startswith('W5') for x in p), p)

    # ---- N9: the _comment exemption is line 1 only ------------------------------------------
    p = run(HDR + NL + '{"_comment": "ORDER-900 verdict PASS, promote to live"}' + NL)
    case('ATTACK', 'N9 a _comment row below line 1 is judged, not waved through',
         p != [], p)

    # ---- W6 / W7: the GRANT TEXT itself (round 3, M6) ---------------------------------------
    # The finding: AGENTS.md was declared in $SUITE_GUARDS, so editing it RAN this suite -- and
    # nothing here read it, so a widened permission row passed a guard that fired on it. Declaring
    # a file as a trigger without asking it a question is memory
    # `citation-guard-satisfied-by-a-universal-file` in a different costume.
    case('CONTROL', 'W6 the pinned grant row passes unchanged',
         run_grant(AGENTS_FIXTURE) == [], run_grant(AGENTS_FIXTURE))
    widened = AGENTS_FIXTURE.replace('APPEND ONLY', 'FULL WRITE')
    p = run_grant(widened)
    case('ATTACK', 'W6 widening APPEND ONLY -> FULL WRITE is refused',
         any(x.startswith('W6') for x in p), p)
    p = run_grant(AGENTS_FIXTURE.replace('No verdict, no order status. ', ''))
    case('ATTACK', 'W6 DELETING a clause from the row is refused',
         any(x.startswith('W6') for x in p), p)
    p = run_grant(AGENTS_FIXTURE.replace(FAKE_ROW + NL, ''))
    case('ATTACK', 'W6 removing the grant row entirely is refused',
         any(x.startswith('W6') for x in p), p)
    # A SECOND row is the evasion a digest alone cannot see: the pinned row stays byte-identical
    # while a wider permission for the same file sits on the line below it.
    p = run_grant(AGENTS_FIXTURE.replace(
        FAKE_ROW, FAKE_ROW + NL + '| `factory/work_receipts.jsonl` | anyone, any edit |'))
    case('ATTACK', 'W6 a SECOND row for the same file is refused',
         any(x.startswith('W6') for x in p), p)
    # W7: the same widening, done in prose next to the table instead of inside the row.
    prose = AGENTS_FIXTURE + NL + 'Agents may also rewrite factory/work_receipts.jsonl freely.' + NL
    p = run_grant(prose)
    case('ATTACK', 'W7 a widening written as PROSE elsewhere is refused',
         any(x.startswith('W7') for x in p), p)
    # ...and the declared escape hatch must actually work, or the only way past W7 is to weaken it.
    case('SPECIFICITY', 'W7 a mention DECLARED in ALLOWED_EXTRA_MENTIONS passes',
         run_grant(prose, extra=('Agents may also rewrite factory/work_receipts.jsonl freely.',))
         == [],
         run_grant(prose, extra=('Agents may also rewrite factory/work_receipts.jsonl freely.',)))

    # ---- WIRING: main() must actually CONSULT the grant --------------------------------------
    # Without this case, deleting the check_grant() call from main() leaves every case above green
    # -- which is M6's defect exactly: a rule that exists and is never read. The stub answers for
    # BOTH files, so the receipts half stays valid and the only variable is the grant text.
    saved_sha2, saved_src2, saved_head2 = wr.GRANT_ROW_SHA256, wr._src, wr._head_text
    try:
        wr.GRANT_ROW_SHA256 = FAKE_SHA
        wr._head_text = lambda: HDR + NL
        wr._src = lambda: _Src(True, widened)
        rc_widened = wr.main([])
        wr._src = lambda: _Src(True, AGENTS_FIXTURE)
        rc_pinned = wr.main([])
    finally:
        wr.GRANT_ROW_SHA256, wr._src, wr._head_text = saved_sha2, saved_src2, saved_head2
    case('WIRING', 'main() REFUSES a widened grant, so the rule is read not just written',
         rc_widened == 1, 'main() returned %r' % rc_widened)
    case('CONTROL', 'main() returns 0 when the grant is the pinned one',
         rc_pinned == 0, 'main() returned %r' % rc_pinned)

    print()
    if _bad:
        print('=== %d CASE(S) DID NOT BEHAVE AS DECLARED ===' % len(_bad))
        return 1
    print('=== the grant is enforced, and the permitted act still lands ===')
    return 0


if __name__ == '__main__':
    sys.exit(main())
