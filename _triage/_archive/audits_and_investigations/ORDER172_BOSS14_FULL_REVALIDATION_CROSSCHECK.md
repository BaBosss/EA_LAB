# ORDER-168 — Boss_14_GridLog full-surface re-validation: 990201 (USDJPY) + 990204 (AUDCAD)

**Status: DATA ONLY — no verdict language (keep/kill/promote/demote/dead/PASS/FAIL) below. The
orchestrator judges. This resolves the ambiguity ORDER-166's first pass left open for these two
legs: does pinning the FULL 116-line input surface (zero cache exposure) bring the numbers back
toward the original recorded evidence, or does the divergence persist even with everything pinned?**

All tester runs used `scripts/mt5_run.ps1`, MT5 lane 1 only (`D:\Meta 5\terminal64.exe`, default —
`-Terminal`/`-Portable` never passed), `-Leverage 100` with the post-run assertion, foreground /
synchronous, one at a time (Model 4 never run parallel with anything). Every run's
`<name>.leverage_check.json` sidecar is cited below and shows `"status":"MATCH"`.

## 1. Full-surface `.set` construction + overlay verification

**Method (identical to ORDER-165's harvested-defaults method, used exactly as documented):**
start from `ea_template/sets/regression/Boss_14_GridLog_defaults.set` (116 real `name=value` lines,
the compiled-defaults surface harvested by ORDER-165), then overlay every `name=value` line the
deployed partial `.set` explicitly specifies, keeping the defaults' key order. Output = one
complete 116-line surface per leg, zero inputs left unlisted (nothing can fall back to a
per-terminal tester-profile cache).

**Files written:**
- `_mt5_auto/ab_sets/ORDER168_990201_USDJPY_full.set` (116 lines) — overlay of
  `ea_template/sets/Boss14_GridLog_USDJPY_DEMO.set` (52 real `name=value` lines, ignoring comments/
  blanks — the file's 88 total lines include ~36 comment/blank lines) onto the defaults surface.
- `_mt5_auto/ab_sets/ORDER168_990204_AUDCAD_full.set` (116 lines) — overlay of
  `ea_template/sets/Boss14_GridLog_AUDCAD_DEMO.set` (52 real `name=value` lines out of 87 total)
  onto the defaults surface.

**Overlay verification (per task step 1 — every partial-set name checked against the full
surface):** parsed both partial sets programmatically (comment/blank lines stripped) and checked
every resulting key against the 116-key defaults surface.
- USDJPY partial: **52/52 names found in the full surface. 0 mismatches.**
- AUDCAD partial: **52/52 names found in the full surface. 0 mismatches.**

No name in either deployed partial `.set` was specifying something that no longer exists — the
overlay is clean, both files are genuinely complete 116-line surfaces with zero cache exposure.

**Cross-check:** a prior same-day session (ORDER-166 revalidate campaign) had independently built
equivalent full-surface sets at `_mt5_auto/ab_sets/order166_revalidate/B14_USDJPY_full.set` and
`B14_AUDCAD_full.set` using the same documented method. `diff` against the files built for this
task shows **byte-identical output (0 differences)** for both legs — an independent confirmation
that the overlay method is deterministic and correctly applied, not a coincidence of one session's
arithmetic.

## 2. Funnel runs

**Windows used — per CLAUDE.md's canonical VERDICT GATE pins (this task's instructions explicitly
said to defer to those if they differ from the literal dates given, and they do):**
- **MAIN = 2023.01.01–2025.12.31** (CLAUDE.md: "36 เดือนล่าสุดที่ไม่กิน HOLDOUT ... วันนี้ =
  2023.01–2025.12"), NOT the 2023.01.01–2026.07.01 window the original historical evidence was run
  on. This is a deliberate, instructed change — flagged as a confound below, not hidden.
- **BWD = 2020.01.01–2023.01.01** (CLAUDE.md: "2020–2022 (trend/stress regime)").
- H1, `EALabTpl\Boss_14_GridLog`, Deposit 10000, `-Leverage 100` asserted on every run.

**MAIN M4 cells were already run same-day by a concurrent part of the ORDER-166 campaign on the
byte-identical full-surface set** (confirmed above) at the same window/leverage — reused rather
than re-run to spend the Model-4 time budget on the BWD cells that did not yet exist. Both are
cited by their actual report path and both show `leverage_check.json` `"status":"MATCH"`. The four
other cells (MAIN M1, BWD M1, BWD M4 ×2 legs = 6 runs) were run fresh for this task, synchronously,
serially.

| Leg | Cell | PF | Net | Trades | eqDD | Report | Leverage |
|---|---|---|---|---|---|---|---|
| 990201 USDJPY | MAIN M1 | 0.92 | -396.46 | 298 | 11.56% | `ORDER168_990201_USDJPY_MAIN_M1.htm` | MATCH 1:100 |
| 990201 USDJPY | MAIN M4 (reused) | 1.19 | 614.81 | 252 | 7.76% | `O166_B14_USDJPY_M4.htm` | MATCH 1:100 |
| 990201 USDJPY | BWD M1 | 1.06 | 217.13 | 198 | 12.77% | `ORDER168_990201_USDJPY_BWD_M1.htm` | MATCH 1:100 |
| 990201 USDJPY | BWD M4 | 1.39 | 954.85 | 162 | 12.15% | `ORDER168_990201_USDJPY_BWD_M4.htm` | MATCH 1:100 |
| 990204 AUDCAD | MAIN M1 | 1.25 | 397.20 | 97 | 6.50% | `ORDER168_990204_AUDCAD_MAIN_M1.htm` | MATCH 1:100 |
| 990204 AUDCAD | MAIN M4 (reused) | 1.09 | 162.33 | 93 | 8.78% | `O166_B14_AUDCAD_M4.htm` | MATCH 1:100 |
| 990204 AUDCAD | BWD M1 | 0.85 | -471.18 | 151 | 15.14% | `ORDER168_990204_AUDCAD_BWD_M1.htm` | MATCH 1:100 |
| 990204 AUDCAD | BWD M4 | 1.45 | 727.99 | 96 | 6.87% | `ORDER168_990204_AUDCAD_BWD_M4.htm` | MATCH 1:100 |

(eqDD = Equity Drawdown Maximal, matching the metric ORDER-166's first-pass table used.)

## 3. Three-way comparison

### 990201 — Boss_14_GridLog, USDJPYm

| | PF | Net | Trades | eqDD | Window | Model | Set |
|---|---|---|---|---|---|---|---|
| **(a) Original** | **1.51** | **841.72** | **138** | **6.15%** | 2023.01.01–2026.07.01 | 1 | `Boss14_GridLog_USDJPY_ISpick.set` (source: `_mt5_auto/reports/BOSS14_USDJPY_FULL_ISPICK_M1.htm`) |
| **(b) Partial-set rerun** | **0.98** | **-113.76** | **337** | **11.56%** | 2023.01.01–2026.07.01 | 1 | deployed partial (`Boss14_GridLog_USDJPY_DEMO.set`, 52/116 params) — `ORDER166_990201_USDJPY.htm` (cited, not rerun) |
| **(c1) Full-surface MAIN M1** | **0.92** | **-396.46** | **298** | **11.56%** | 2023.01.01–2025.12.31 | 1 | full 116-line overlay |
| **(c2) Full-surface MAIN M4** | **1.19** | **614.81** | **252** | **7.76%** | 2023.01.01–2025.12.31 | 4 | full 116-line overlay (reused) |
| **(c3) Full-surface BWD M1** | **1.06** | **217.13** | **198** | **12.77%** | 2020.01.01–2023.01.01 | 1 | full 116-line overlay |
| **(c4) Full-surface BWD M4** | **1.39** | **954.85** | **162** | **12.15%** | 2020.01.01–2023.01.01 | 4 | full 116-line overlay |

**Reading:** none of the four fully-pinned cells reproduce (a)'s PF 1.51 / 138 trades. The
apples-to-apples-on-model comparison is (a) vs (c1) — both Model 1, both starting 2023.01.01
(c1's window ends 6 months earlier, 2025.12.31 vs 2026.07.01). (c1) trade count (298) is more than
**double** (a)'s 138, on a *shorter* window — a shorter window should reduce trade count if
anything, not double it, so the missing 6 months cannot explain the gap. (c2), the Model-4
MAIN cell, comes closest of the four (PF 1.19, trades 252) but is still far from 1.51/138 and its
trade count is still +83% over the original. Every fully-pinned cell's trade count (298/252/198/162)
sits far above the original's 138 — the same direction of drift the partial-set rerun showed
(337), not a correction of it. **Pinning the full input surface does not bring the numbers back
toward the original for this leg — the divergence persists (and on the MAIN M1 cell, the most
directly comparable one, it is larger, not smaller, than the partial-set rerun's divergence).**

### 990204 — Boss_14_GridLog, AUDCADm

| | PF | Net | Trades | eqDD | Window | Model | Set |
|---|---|---|---|---|---|---|---|
| **(a) Original** | **1.88** | **1491.31** | **146** | **6.38%** | 2023.01.01–2026.07.01 | 1 | `Boss14_GridLog_AUDCAD_ISpick.set`-equivalent (source: `_mt5_auto/reports/BOSS14_AUDCAD_FULL_ISPICK_M1.htm`) |
| **(b) Partial-set rerun** | **1.35** | **644.09** | **110** | **6.50%** | 2023.01.01–2026.07.01 | 1 | deployed partial (`Boss14_GridLog_AUDCAD_DEMO.set`, 52/116 params) — `ORDER166_990204_AUDCAD.htm` (cited, not rerun) |
| **(c1) Full-surface MAIN M1** | **1.25** | **397.20** | **97** | **6.50%** | 2023.01.01–2025.12.31 | 1 | full 116-line overlay |
| **(c2) Full-surface MAIN M4** | **1.09** | **162.33** | **93** | **8.78%** | 2023.01.01–2025.12.31 | 4 | full 116-line overlay (reused) |
| **(c3) Full-surface BWD M1** | **0.85** | **-471.18** | **151** | **15.14%** | 2020.01.01–2023.01.01 | 1 | full 116-line overlay |
| **(c4) Full-surface BWD M4** | **1.45** | **727.99** | **96** | **6.87%** | 2020.01.01–2023.01.01 | 4 | full 116-line overlay |

**Reading:** same pattern, more pronounced. Every fully-pinned cell's PF (1.25 / 1.09 / 0.85 / 1.45)
sits below (a)'s 1.88, and three of the four sit below even (b)'s already-diverged 1.35 — full
pinning moves AUDCAD's MAIN-window numbers *further* from the original, not closer. The BWD M1 cell
crosses below breakeven (0.85) on a window that overlaps none of the original's data at all, which
is a separate regime-dependence question, not evidence either way about cache pollution — but the
MAIN-window cells (the ones directly comparable to (a) and (b)) both moved away from (a), not
toward it. **Pinning the full input surface does not bring the numbers back toward the original for
this leg either — the divergence persists and, on MAIN, deepens.**

## 4. Plain factual statement per leg

- **990201 USDJPY:** the divergence between the original recorded evidence (PF 1.51/138t) and the
  first-pass partial-set rerun (PF 0.98/337t) **does not resolve when the input surface is fully
  pinned**. All four fully-pinned cells (MAIN M1, MAIN M4, BWD M1, BWD M4) diverge from the
  original, and the model-matched cell (MAIN M1, PF 0.92/298t) diverges by more than the partial-set
  rerun did, not less. The data supports the reading that the original recorded evidence itself
  cannot be reproduced under a configuration with zero cache exposure.

- **990204 AUDCAD:** same conclusion. The divergence between the original (PF 1.88/146t) and the
  partial-set rerun (PF 1.35/110t) **persists under full pinning** — all four fully-pinned cells sit
  at or below the partial-set rerun's already-lower PF, with the MAIN-window cells (1.25, 1.09)
  moving further from the original than the partial-set rerun did. The data supports the same
  reading: the original recorded evidence cannot be reproduced under a fully-pinned configuration.

## 5. Surprises / caveats worth flagging

- **Full pinning made things worse, not better, on both legs' MAIN windows.** Going in, either
  outcome was plausible; the actual result (full-surface PF *lower* than the partial-set rerun's
  already-lower PF, on both legs' MAIN M1 cells) means the partial-set's cache-filled inputs were
  not, on net, more favorable than the leg's real deployed config — if anything the reverse. This
  argues against a simple "cache got lucky, real config is worse" story and toward "the *original*
  1.51/1.88 numbers were themselves produced under some input state that neither the partial-set
  rerun nor the fully-pinned real-config rerun can reach" — i.e., a third, unrecoverable cache state
  from whenever the historical `BOSS14_*_FULL_ISPICK_M1.htm` runs actually happened, not just "the
  deployed leg's cache" that ORDER-166's first pass probed.
- **Window confound, stated plainly:** (a) and (b) both ran 2023.01.01–2026.07.01; my (c) MAIN cells
  ran 2023.01.01–2025.12.31 per the CLAUDE.md canonical MAIN pin, per this task's own instruction to
  prefer that over the literal date I was given. This means (c1)/(c2) have ~6 fewer months of data
  than (a)/(b). This makes the comparison not perfectly apples-to-apples on window length — but the
  direction of the effect (trade count roughly doubling on a *shorter* window) is the opposite of
  what a shorter window alone would produce, so the window difference cannot be the explanation for
  the divergence; if anything it means the "true" gap on a matched window could be even larger.
- **eqDD coincidence:** 990201's MAIN M1 full-surface eqDD (11.56%) is numerically identical to the
  partial-set rerun's eqDD (11.56%) despite trades/PF/net all differing (298 vs 337 trades, 0.92 vs
  0.98 PF). Checked both `.htm` files directly — both genuinely report 11.56%, not a copy-paste
  artifact. Likely coincidence (same worst-drawdown episode dominates both runs' equity curve) but
  flagged rather than silently noted.
- **Model 4 runs were unexpectedly fast** (each completed in well under the 1800s timeout budgeted)
  — no timeout/freeze issues, no need to background anything, consistent with the memory-documented
  freeze-guard (priority/affinity throttling) working as intended.

## Files touched (all uncommitted, left for review; no `git add`/`git commit` run)

- `_mt5_auto/ab_sets/ORDER168_990201_USDJPY_full.set` (new, 116 lines)
- `_mt5_auto/ab_sets/ORDER168_990204_AUDCAD_full.set` (new, 116 lines)
- `_mt5_auto/reports/ORDER168_990201_USDJPY_MAIN_M1.htm` (+ `.png`, `.leverage_check.json`)
- `_mt5_auto/reports/ORDER168_990201_USDJPY_BWD_M1.htm` (+ sidecars)
- `_mt5_auto/reports/ORDER168_990201_USDJPY_BWD_M4.htm` (+ sidecars)
- `_mt5_auto/reports/ORDER168_990204_AUDCAD_MAIN_M1.htm` (+ sidecars)
- `_mt5_auto/reports/ORDER168_990204_AUDCAD_BWD_M1.htm` (+ sidecars)
- `_mt5_auto/reports/ORDER168_990204_AUDCAD_BWD_M4.htm` (+ sidecars)
- `_mt5_auto/ini/ORDER168_*.ini` (6 new, byproduct of `mt5_run.ps1`)
- This file.

Reused, not modified: `_mt5_auto/reports/O166_B14_USDJPY_M4.htm`, `O166_B14_AUDCAD_M4.htm` (and
their sidecars) from a concurrent same-day part of the ORDER-166 campaign — verified byte-identical
full-surface `.set` inputs and `leverage_check.json` `"status":"MATCH"` before reuse.

No file under `portfolio/DEPLOYMENTS.csv`, `EA_SCORECARD_AND_REGISTRY.md`, `EA_MASTER_INDEX.csv`,
`ea_template/core/*`, `ea_template/sets/regression/*`, `scripts/mt5_run.ps1`, or
`scripts/tpl_regression.ps1` was modified.
