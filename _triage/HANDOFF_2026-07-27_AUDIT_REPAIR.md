# HANDOFF — 2026-07-27 evening · Codex audit: verify, then repair

> ⚠️ canonical entry = `PROJECT_STATE.md` · this file owns: **the shift-change note for the six lanes that ran
> 2026-07-27 18:10–22:50**. It is not a queue — every item below has a home on the board (routing table at the end).

**Lanes:** `AUDITVERIFY` → `MRISFRESH` → `BASKETCORR` → `SCRUTFIX` → `MONEYPATH` → `MONEYPATH-B` (all `CLOSED`
in `docs/SESSION_LEDGER.md`). **20 commits, `1ee2c00d` … `31d3d716`.** No live account touched, no `_vps_deploy`
bundle touched, no EA verdict issued.

---

## 1. What was asked, and what came back

Verify the 14 findings in `_triage/CODEX_AUDIT_RESULTS_2026-07-27.md` (read-only), then — on later instruction —
fix them.

**14 checked: 13 CONFIRMED · 1 CONFIRMED-with-scope-corrected · 0 REFUTED · 1 sub-claim CANNOT-VERIFY.**
Verification table is appended to that same file.

**The line numbers were stale by 0–7, systematically per file** — `crisis_models.json` consistently 5-7 early,
`mris_crisis_backtest.ps1` 1 early, the `.mqh` files 0-6. That reads as Codex having seen a slightly older
revision, not a different file. Nine of ~40 citations landed exactly. **Use the corrected numbers in the
verification table, not the ones in the audit text above it.**

---

## 2. What is now fixed (with what actually proves it)

| what | evidence | commit |
|---|---|---|
| MRIS `asof` = observation time, not fetch time — **both** feeders | cage `run_mris_asof_tests.ps1` **6/23 red → 31/31**; fire count **0/7 possible before → 1/7 now** | `ba889529` `d9face83` |
| Basket units correlate as the **summed two-leg series** | 463666728 **84.372% → 56.641%**; proxy sat 0.41 pts conservative (Codex measured 0.61 on a smaller inventory) — audit reproduced | `40885e34` |
| `unit_keys` coverage validated (silent double-count) | cage 34, **proven able to fail by mutation** | `40885e34` |
| Wave5 refuses an entry on unreadable Risk-ATR | `tpl_regression` CLEAN 8/8 | `c44ca743` |
| Wave5 guard counters (per-reason + `unaccounted`) | `evaluated=2936 signalled=26 unaccounted=0`, and `signalled` matches the 26 trades | `c44ca743` `671783b1` |
| Wave5 entry ref takes the **fill** side | baseline **re-pinned, Boss_17 only**, 26 trades unchanged, 7/8 byte-identical | `e3edd614` |
| Naked-order config refused at init | **0 trades + FATAL** on Codex's exact config; **specificity holds** (SLMode=33 still trades 24) | `e3edd614` |
| Deposit-load cap refuses when it cannot measure | — | `e3edd614` |
| Volume-step guess removed on the **open** path only | the **close** path gets the opposite treatment — returning 0 there means *refuse to close* | `e3edd614` |

---

## 3. Read this part even if you skip the rest

**Three guards were found reading the wrong input.** Same shape as the audit's own headline finding, and the
reason this session kept producing more work than it closed:

1. **MRIS freshness gate** measured the *fetch* clock the feeder stamped — it could never fire on FRED data,
   however old. The gate was not missing; it ran, on the wrong clock.
2. **The fast-cage hook** fired on `scripts/check_*.ps1` and `scripts/_test/*` but **not** `scripts/mris/*`, so
   the new cage would only have run when something *other* than the file it guards was edited.
3. **The ORDER-144 baseline `re-pin` rule** read `.git/COMMIT_EDITMSG` from **pre-commit**, where `git commit -m`
   has not written it yet — so it held the *previous* commit's message and could only pass by accident. It
   blocked two messages that plainly contained the word. Moved to a new `.githooks/commit-msg`, proven both
   directions. Of the eight commits that ever touched the baseline, only one postdates the guard.

**And the most important number this session produced is a zero.** Wave5 **guard G4** — the broker stops-level
check that makes the design "preventive, not detective", and the control the whole ORDER-082 naked-probe
acceptance rests on — **has never been observed firing**: `sl_invalid=0` across 2936 bars, two runs. It was
invisible until counters existed. → **ORDER-490**, which explicitly forbids closing it by running a longer
window and reporting a bigger zero.

**Coverage, stated honestly:** only ORDER-432 **finding 3**'s guard was *demonstrated* firing. Findings 2, 4
and 5 are fail-closed branches on runtime data failures (unreadable ATR / balance / volume step) that **cannot
be forced in the tester** — reachability is argued from source, never shown. By the VERDICT GATE's own guard
clause they are `UNTESTED` and must not be written up as passed.

---

## 4. Two things that are the user's call, not mine

- **`MaxAgeHours` stays 120** — measured, not assumed: 72h false-positives every Monday on a normal Friday
  close, and *firing* drops the component and renormalises the rest, so a tighter gate would delete the credit
  axis during a credit event (finding 5's own mechanism). `age_h` per component was added instead. **If you want
  it tighter anyway, say so** — it is a threshold judgement, and I would not move it silently.
- **463666728 still reads over its 25% budget** (headroom **−31.64**) even after the estimate improved. A better
  measurement is not a licence to size up.

---

## 5. Nothing was marked REVIEWED, and why

All three audit orders stay `OPEN`:

- **ORDER-432** — six findings addressed, but its own prohibition list forbids closing before every High item
  has a test that fails without the fix. Finding 2 does not. Also spun off ORDER-490.
- **ORDER-433** — built and measured, but the audit's own conclusion was that
  `--resolve-single-leg-baskets` should be **retired**, not merely left off. That has not been done.
- **ORDER-434** — finding 1 fixed and the age-gate decided; **findings 2–6 untouched** (point-in-time replay,
  in-sample validation, unbound replay artifacts, the missing 2024 window).

⇒ **no `REVIEWED`, therefore no archive move and no `B1_DATASET.csv` row is owed** for this session.

**Known debt not created here but worth naming:** `_triage/` holds **9** handoff files where the rule says one.
This session archived the one it directly supersedes (`HANDOFF_2026-07-27_QUEUE.md`) after checking every item
in its routing table resolves. The other 8 are older lanes' and were left alone deliberately — the first
big-sweep attempt (2026-07-24) failed outright and had to be restored.

---

## 6. Post-check, 22:45 (`S-2026-07-27-POSTCHECK`) — appended, not a new handoff

A state check was run over everything the six evening lanes produced. **Their work stands** — the
verification table, the four money-path fixes, the basket series, the `asof` fix, the `commit-msg` guard
and ORDER-490 were all re-read and none of it needed correcting. Two loose ends were closed:

**(a) The archive move of `HANDOFF_2026-07-27_QUEUE.md` was half-done.** The copy under
`_triage/_archive/handoffs_closed/` was committed in `5afbb8e3`, but the deletion of the top-level file
was left **staged and uncommitted in the shared index**. Checked before finishing it: the archived copy is
tracked in HEAD and byte-identical to the original, so nothing was at risk. Committed in `71d0c81e`.
<sub>Worth naming: a staged delete in an index every lane shares is exactly what ledger rule 3 is about. A
path-limited commit will not pick it up, so it simply sits there — but it makes `git status` read dirty
for every lane, and any lane reaching for a broad `add` carries it without meaning to. **An archive move
is two operations and is only half-done until both land.**</sub>

**(b) The ledger "numbers used" block was stale a third time — and this time it contradicted itself.**
Bullet 1 read *max = 434* while bullet 3, two lines below it **in the same list**, read
`490-499 ... used ORDER-490 ... next block 500-509`.

That gives `BACKLOG-D29` a clean timeline: repaired 16:55 → stale by 17:40 → repaired 17:55 → stale again
by 22:10, across six lanes. **Three of those lanes updated bullet 3 correctly and left bullet 1 alone**,
which is the diagnosis rather than the symptom: bullet 3 is a *by-product* of reserving your own block, so
it gets written; bullet 1 is the only line in the file that nobody has a reason to touch while doing the
work, so it is the only one that rots. **Stop maintaining it — compute it from the rows or delete it.**
Fixed to **490** in `77e9002a`.

**Nothing else changed. No order was opened, none marked REVIEWED, so no `B1_DATASET.csv` row is owed for
this lane either.** `ORDER-430` and `ORDER-431` (the batch work stocked at 17:00) are still `OPEN` and
untouched — they need an MT5 lane and nobody has taken one.

---

## ปลายทางของทุกรายการ

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| Money-path: findings 1/2/3/6 fixed, 4/5 fixed-but-UNTESTED | ORDER-432 |
| Guard G4 has never been observed firing — prove it can, or stop counting it | ORDER-490 |
| Retire `--resolve-single-leg-baskets` now the true series exists | ORDER-433 |
| MRIS findings 2–6: point-in-time replay, in-sample anchors, unbound artifacts, missing 2024 window | ORDER-434 |
| `asof` clock, both feeders + age-gate decision | DONE |
| Combined two-leg basket series + `unit_keys` validation | DONE |
| Baseline `re-pin` guard moved to `commit-msg` | DONE |
| Fast-cage hook now watches `scripts/mris/*` | DONE |
| Verification table for all 14 findings | DONE |
| Derive the ledger "numbers used" block from the tables instead of hand-maintaining it | BACKLOG-D29 |
| Host search that unblocks the caged lever pair — stocked 17:00, still unrun, needs `D:\Meta 5b` | ORDER-430 |
| MacdDiv_Naked USDJPY H4 optimize — stocked 17:00, still unrun, needs `D:\Meta 5c` | ORDER-431 |
| Post-check: archive move finished, ledger summary corrected the third time | DONE |
