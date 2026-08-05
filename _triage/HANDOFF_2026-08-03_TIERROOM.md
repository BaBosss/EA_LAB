# HANDOFF — lane `S-2026-08-03-TIERROOM` (2026-08-03)

> Opened on `_triage/PROMPT_NEXT_SESSION_S13.md`, whose own opening line orders `ORDER-1130`
> (tier headroom) closed before slice S13. That is what happened. **S13 was not started** — see
> the last section, which says so plainly rather than leaving it to be discovered.

---

## What closed

**`ORDER-1130` — DONE.** The tier had ~1–7s of hook-mode headroom depending on machine load, and
S12's cage was sitting outside it. It now has **13.0s** with S12's cage **inside** it.

Every number below is `-Hook` (`EA_LAB_EVIDENCE=index`), the way `.githooks/pre-commit:220`
launches the tier, three samples each. Memory `tier-number-needs-its-invocation`.

| state | samples | median | headroom |
|---|---|---|---|
| before | 114.4 / 113.1 / 112.4s (25 suites) | 113.1 | 6.9s |
| after the fix | 105.3 / 102.9 / 103.1s (25 suites) | 103.1 | 16.9s |
| **after + `run_s12_tests.ps1` registered** | **107.0 / 108.9 / 106.8s (26 suites)** | **107.0** | **13.0s** |

`ORDER-1180`'s stated partial is therefore closed too: the suite and its `$SUITE_GUARDS` entry are
uncommented **together**, `.githooks/fast_tier_pathspec` is regenerated (135 entries), the key sets
agree and `run_guard_trigger_tests` is green.

## The finding, and it was not what the row suspected

The `ORDER-1130` row named a suspect — the S2a bundle digest — and told the next reader to measure
before believing it. **The measurement refuted it.** `run_s2a_gate.py` is 4.19s and flat.

The growth was **`gen_locked_constants._strip_comment`**: a pure `str -> str` called **2,438,476
times over ~6,500 DISTINCT lines**, because `_walk` re-strips the whole `#include` closure once per
build tag per case. It was **73%** of `run_input_surface_tests.py --mutate`. ORDER-830 had measured
that same entry at **0.18s** four days earlier — it had grown **41x** while every handoff in the
chain quoted the old table.

Memoising it (`functools.lru_cache`): `--mutate` **7.42s → 2.53s**, `check_input_surface_gen.py`
**2.65s → 1.55s**, and the run-to-run variance collapsed with the CPU-bound term.

**The two questions a "made it faster" claim owes were driven, not argued:**
- *Did any answer change?* A differential probe compared memoised against unmemoised output over
  **6,517 distinct real closure lines plus 13 crafted adversarial ones** (quoted `//`, unterminated
  string, unterminated block comment, escaped quote, tail comment): **0 mismatches**.
- *Can it still fail?* Neutralising the `//` cut **inside the memoised function** and re-running the
  suite through its own mutation machinery → **exit 1**.

Cheaper to DRIVE, not cheaper to CARE. No case dropped, no budget raised.

## The durable part is the instrumentation, not the numbers

The disease was never one slow function — it was that `run_contract_binding_tests.ps1` carried a
**hand-typed per-entry table whose measuring harness had been thrown away**, so nobody could
re-derive it. Two of its lines were wrong by **4x and 42x** by the time ORDER-830 re-measured, and
this order found a third wrong by 41x.

So all three heavy suites now take **`-Timing`** and print their own phase table:

```bash
EA_LAB_EVIDENCE=index powershell -NoProfile -File scripts/_test/run_contract_binding_tests.ps1 -Timing
```

**Re-measure. Do not quote this file.** That is the deliverable.

<sub>The instrumentation's own first run caught a defect in itself: it read `EA_LAB_EVIDENCE` at
report time, and `run_guard_trigger_tests` PART 6 unsets that variable in a `finally` block — so it
labelled an `index` run `worktree (default)`. A number labelled with a mode that was not the mode is
worse than an unlabelled one, because it is quotable. The mode is now captured at start in all
three.</sub>

## 🔴 Read this before quoting any tier total, including the ones above

`run_front_guard_evidence_tests.ps1` costs **~13s when nothing it guards is staged** and **~21s when
`AGENT_TASKBOARD.md` is staged** — and `AGENT_TASKBOARD.md` is one of its **declared guards**, so the
suite is *selected exactly when it is expensive*. Ten runs at staged=0 gave 12.7–13.4s; the two runs
that staged the board gave **21.2s and 21.0s**.

I called the row's old `21.2s` "stale high" on the strength of the cheap samples, and **the commit
that closed the order reproduced 21.2s in its own hook**. The old number was never stale — it was
measured in a state I had not reproduced. The row carries that correction.

**What it does and does not change.** The T3 totals above are taken at staged=0, so they are the
FLOOR of what a commit pays. They still answer the question they were taken for: Box 1's dangerous
case is a staged path matching **no** guard (a `_mt5_auto/*.csv`), which falls open to running
everything **with the board not staged** — i.e. with front-guard in its cheap state. So the 107.0s
full-tier figure stands for that scenario and the budget conclusion is unaffected. A commit that
stages the board selects ~4 suites, not 26; the closing commit measured **68.6s of the 90.0s
per-path budget** with the expensive 21.2s inside it.

**The mechanism is not known and is deliberately not guessed at.** Two samples name the *condition*,
not the cause. Reproduce at staged=board three times before theorising.

## T4 — the budget was NOT lowered, deliberately

The room was bought to be **spent** on the cage it was blocking, not banked. What is left is bounded
by a measured **same-commit load spread of 6.3s on this one machine**: the identical commit ran
118.7s yesterday and 113.1s today. Any line below ~118.0 puts a **refused commit** inside ordinary
load variation, which is how a tier earns the `--no-verify` it exists to avoid. `PART 7 N1` pins
120.0 as a ratified number; move it on a spread measurement, not on one machine's good afternoon.

## ⚠️ A parallel lane was writing this worktree the whole session

`S-2026-08-03-S12WIRE` (`ORDER-1200`) ran concurrently and correctly — it declared 🚫 on every path
this lane owns. Two things it caused that cost real diagnosis time here, so the next reader gets
them for free:

1. **`run_front_guard_evidence_tests.ps1` went red three times** with `A6 .git/index was rewritten
   by this suite` and `A2 SPECIFICITY expected exit 0`. **Neither was a defect in the suite and
   neither was mine.** The other lane was committing, and separately an `adhd-mode` skill installed
   into the live library from *outside the repo* put `check_state.ps1 -Strict` into skills-mirror
   drift, which fails every commit in the repo until the mirror is synced. The other lane fixed the
   mirror (`9b6a9af1`). The suite cannot tell "someone else committed" from "I damaged the index" —
   worth knowing before diagnosing it in a shared worktree.
2. `AGENT_TASKBOARD.md` carried their uncommitted `ORDER-1200` row for part of the session. This
   lane waited for it to land before touching the board, per ledger rule 3's own warning that
   path-limiting does **not** prevent carrying a co-editor's in-flight lines.

## What was NOT done

- **Slice S13 was not started.** `ORDER-1130` took the session. S13 (`Boss_14 H01/H02 pilot matrix
  end-to-end`, design §10 / §8.6) is untouched, no order number was spent on it, and the reserved
  block `1190-1199` is therefore entirely unused — **do not re-issue those numbers**, treat them as
  buffer per this repo's convention.
- The owner actions from the S12 prompt are still open and neither needs an engineer: **create the
  `EA LAB Control Room` bot** (until it exists every `WARN`/`INFO` alert and the Morning Brief report
  `UNCONFIGURED` by design). The third-party token in `_triage/FXDREEMA_XRAY.md` was **removed by the
  parallel lane** in `c7d97b6a`, so that one is closed.
- No EA verdict, no `.set`, no MT5 lane, no `factory/runs/**`, no attestation event.

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| T1 — all three heavy suites attributed to phases, 3 samples each, hook mode | DONE |
| T1 — attribution made REPRODUCIBLE: `-Timing` on all three, replacing a hand-typed table | DONE |
| the row's suspect (S2a digest) REFUTED by measurement — flat at 4.19s | DONE |
| real cause found: `_strip_comment` called 2,438,476 times over ~6,500 distinct lines | DONE |
| T2 — memoised: `--mutate` 7.42s→2.53s, `check_input_surface_gen` 2.65s→1.55s | DONE |
| T2 — differential probe, 6,517 distinct real lines + 13 adversarial, 0 mismatches | DONE |
| T2 — cage proven still able to fail (mutant inside the memoised function → exit 1) | DONE |
| T3 — tier re-measured 3× and written into the registration comment, not prose | DONE |
| `run_s12_tests.ps1` + its `$SUITE_GUARDS` entry re-registered together; pathspec regenerated | DONE |
| T4 — budget NOT lowered, with the 6.3s same-commit load spread as the stated reason | DONE |
| instrumentation defect caught on its own first run (mode read after PART 6 unset it) | DONE |
| self-correction: the "stale high" 21.2s was reproduced by the closing commit | DONE |
| front-guard costs ~21s when `AGENT_TASKBOARD.md` is staged vs ~13s otherwise — **mechanism unknown, 2 samples name the condition only; reproduce 3× before theorising** | ORDER-1130 (owed) |
| tier totals are a FLOOR: every full-tier sample was taken at staged=0 | ORDER-1130 (owed) |
| **slice S13 (`Boss_14 H01/H02` pilot matrix, design §10 / §8.6) NOT STARTED** | S13 (next lane) |
| block `1190-1199` entirely unused — leave as buffer, do not re-issue | docs/SESSION_LEDGER.md |
| owner creates the `EA LAB Control Room` bot + fills the two config keys | ORDER-1180 (owed) |
| third-party token in `_triage/FXDREEMA_XRAY.md` — **closed by the parallel lane in `c7d97b6a`** | DONE |
