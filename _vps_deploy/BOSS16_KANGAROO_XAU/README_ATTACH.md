# Boss_16_KangarooGrid — XAUUSD H1 — PENDING_ATTACH bundle

Built 2026-07-25 by ORDER-213. Everything below is **pre-registered**: it is written before
the demo starts so the judge cannot be graded against a bar invented after seeing the result.

---

## 🔴 Read this first — the binary that was sitting in `ea_template/` was stale

`ea_template/Boss_16_KangarooGrid.ex5` is dated **2026-07-23, 128,744 bytes**. Seven chassis
files it compiles against were changed on **2026-07-24** — `MoneyManagement.mqh`,
`RiskControl.mqh`, `Inputs.mqh`, `LabCore.mqh`, `ExitManager.mqh`, `Recovery.mqh`, and
`entries/Kangaroo.mqh` — which is when ORDER-187/190/194 landed. The current build is
**134,550 bytes**, 5,806 bytes larger.

**`_16_BaseLotMode` was added by ORDER-190 on 2026-07-24**, i.e. *after* that stale binary was
compiled, so the stale binary does not have that input at all. Attaching it while loading
`Boss16_Kangaroo_XAU_21_30_scaled_demo.set` would have set an input the EA does not have —
MT5 ignores unknown inputs silently (see memory `mt5-tester-cache-nondeterminism`), so the EA
would have run **flat lot mode while the operator believed it was balance-scaled**, and without
the ORDER-187/194 safety fixes.

The `.ex5` in this folder is the **current** build, taken from the tester's own Experts
directory. Both installed tester copies were verified byte-identical to each other:

```
SHA256 B5001606FCBB30FF419A45DB7F9D477185E22DCDB5B6B1B7DCDAEB7CC0127CFC   134,550 bytes
```

`.ex5` is gitignored, so that hash is the record. **Verify it before attaching** — if the file
you are about to drag on a chart does not match, you have the wrong build:

```bash
powershell -NoProfile -Command "Get-FileHash '_vps_deploy/BOSS16_KANGAROO_XAU/Boss_16_KangarooGrid.ex5' -Algorithm SHA256"
```

---

## What to attach

- Chart: **XAUUSD, H1** — the `.set` header says H1, and the ORDER-077/078 funnel that produced
  these numbers ran H1. *(Note: `EA_MASTER_INDEX` lists this EA's home as "XAUUSD D1 (D1g)".
  That row describes a different funnel, ORDER-091C-D1g, which closed no-edge. The H1 candidate
  is this one. If you intended D1, stop and ask — they are not the same evidence.)*
- EA: `Boss_16_KangarooGrid.ex5` (hash above)
- Set: **`Boss16_Kangaroo_XAU_21_30_scaled_demo.set`** — balance-scaled mode (`_16_BaseLotMode=1`)
  - At a **$10,000** starting balance this trades the *identical* first lot (0.01) as the flat
    baseline; it only diverges as balance moves. Starting at a different balance changes the
    lot immediately, which would break the apples-to-apples comparison this demo exists to make.
  - `Boss16_Kangaroo_XAU_21_30.set` (flat, `_16_BaseLotMode=0`) is included as the control.
- Demo account only. **Not real money** — the chassis has never run live or on demo before.

After attaching, in the same session: add the row to `DEPLOYMENTS.csv`, re-pin this exact `.set`
plus the first-tick log as the baseline, and add the `expectations.csv` row.

---

## ⚠️ What the lot-mode cage actually proved (added 2026-07-25 by the ORDER-218 error sweep)

ORDER-190 certified `_16_BaseLotMode` with `mm_lotmode_test.ps1` and recorded "K0/K1 cases CLEAN".
The truncation detector's own sidecar files — written automatically since 2026-07-24 and never
read by anyone until now — say **all four** of the relevant runs stopped early at the 25% DD kill:

| run | last deal | idle tail | entry deals | eqDD |
|---|---|---|---|---|
| `MMLOT_K1_scaled_1x` (deposit 10,000) | 2024.05.23 20:56:40 | 38.1 d (20.9%) | 59 | 25.09% |
| `MMLOT_K1_scaled_2x` (deposit 20,000) | 2024.05.23 20:56:40 | 38.1 d (20.9%) | 59 | 25.03% |
| `MMLOT_A_fixed_baseline` | 2024.05.09 16:10:40 | 52.3 d (28.7%) | 115 | 25.09% |
| `MMLOT_E_unit_indep` | 2024.01.08 14:51:40 | **174.4 d (95.8%)** | **6** | 25.01% |

**The deposit-invariance claim survives, and here is why:** the hazard that detector exists to
catch is "truncated at one deposit, complete at another, so two runs that look comparable are
not". The 1x and 2x runs stop at the **same timestamp with the same 59 deals** — they die
identically, which is itself invariance. That specific trap did not spring.

**What is weaker than "CLEAN" sounds:** every case was measured only up to the DD kill, over
roughly five of six months, so nothing was verified about behaviour past that point. And
`MMLOT_E_unit_indep` — the unit-independence case — passed on **6 trades over 8 days**. Treat
that one as unproven rather than proven.

**None of this blocks the attach.** The mode is opt-in, it is deposit-invariant where it was
tested, and at a $10,000 start it trades the identical first lot as flat. But if the demo trips
its 12% kill early, check the lot progression before concluding the *edge* failed — the cage
never watched this mode past a drawdown of that size.

## Pre-registered expectations — CORRECTED, do not use the older figures

ORDER-078's funnel ran `2023.01.01 → 2026.07.01`, six months **inside** the 2026H1 holdout, and
one of its year-split rows was literally labelled `2026H1 … PF 1.75 / 85t`. Every headline from
that funnel is inflated. ORDER-202 re-ran the config on clean windows:

| window | PF | trades | eqDD |
|---|---|---|---|
| MAIN 2023.01–2025.12 (clean) | **1.46** | 205 | 7.39% |
| BWD 2020–2022 | **1.30** | 278 | 9.70% |
| *(archived contaminated headline — do not quote)* | *1.57* | *285* | — |

**The edge is real** — 1.46 clears the 1.2 hard bar and 1.30 clears the 1.0 soft bar
comfortably, which is more than most candidates in this repo manage. That is why it is being
attached rather than parked.

- **Expected PF: 1.46. Not 1.57.**
- **Expected trade rate: ≈68 per year** (205 over three years ≈ **5.7/month**). Not the ~81–90/yr
  the 285-trade contaminated span implied.

## Judge criteria (pre-registered)

- **2026H1 is spent for this EA** — the funnel consumed it. Per the Boss_16 precedent named in
  `CLAUDE.md`'s VERDICT GATE, **the demo forward record IS the holdout.** It is the first
  genuinely independent evidence this config has ever produced.
- **Judge bar:** PF ≥ **1.40** at ≥ **30 closed trades** (repo default for demo → live).
- **⚠️ Judge date must be ~5.5 months after attach, not 3.** At 5.7 trades/month, 30 trades takes
  **≈5.3 months**. A 3-month judge would see ~17 trades and could not clear the trade bar no
  matter how well it performed. Set `judge_date = attach + 5.5 months` when you add the
  DEPLOYMENTS row. *(The old, inflated trade rate would have suggested ~3.9 months — this is a
  concrete example of the contamination reaching the schedule, not just the headline.)*
- **Kill rules (repo default):** eqDD > **12%**, or 3-month PF < **0.8** at ≥ **15 trades**.
  Note BWD eqDD was 9.70%, so a 12% kill leaves modest headroom — that is intentional, not an
  oversight; if it trips early, check whether the balance-scaling grew the lot before concluding
  the edge failed.
- **What would make this informative even if it fails:** it is a *grid*, so record whether a
  losing stretch came from the entry being wrong or from the grid carrying an adverse leg. Those
  are different failures and only the first one kills the concept.
