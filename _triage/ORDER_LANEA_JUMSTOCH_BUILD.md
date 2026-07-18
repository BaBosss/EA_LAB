# Lane A — JUMSTOCH entry → Boss V2 (entry 18) — BUILD + CAGE (2026-07-18)

## Built
- `ea_template/core/entries/Entry_JumStoch.mqh` — seed signal only (LWMA displacement + Stoch filter).
  Grid/DCA/SL/TP/BEP/trail all come from the chassis (StackMode=92), not the standalone.
- `ea_template/Boss_18_JumStoch.mq5` — wrapper (`#define LAB_ENTRY_18`).
- Wiring: `Indicators.mqh` (g_hLWMA18/g_hStoch18 + Indi_LWMA18/Indi_StochJum18), `Inputs.mqh`
  (`_18_` input group + StackMode=92 default + fallback-nest `#ifndef LAB_ENTRY_18`), `LabCore.mqh`
  (include + Init), `deploy.ps1` (added Boss_18 to compile targets).

## Direction A/B (user decision 2026-07-18 = "build & A/B both")
`_18_DirMode`: **1 = FAITHFUL momentum-join** (the standalone's actual call-site mapping that produced the
EURUSD-H1 PF1.18 baseline — BUY above LWMA / SELL below) · **2 = REVERSION** (Lane-A brief as written —
BUY below LWMA / SELL above; exact BUY↔SELL mirror). The brief's directions contradict the validated source;
rather than guess, both are switchable and the A/B measures them empirically. `_18_Direction` (1/2) fixes the
per-instance direction (Boss_14/16 pattern; bidirectional = two instances w/ own magic).

## Cage — GREEN (with documented benign exception)
- **compile 0 errors / 0 warnings** — Boss_18 AND all 6 baseline EAs.
- **run_tests: ALL PASS** (AcctGate/AcctSnapshot/NewsGuard/Persist/StackStep).
- **tpl_regression: RED-benign** — all 6 EAs drift <2% net but **trade-counts identical** (168/164/107/56/216/73
  = baseline exactly). This is the pre-existing stale-baseline (Jul 11) condition the re-settle framework
  documents (Part 1 rule 3), NOT this change: every addition is `#ifdef LAB_ENTRY_18`-gated, so Boss_11–16
  preprocess byte-identically (their builds short-circuit at the first `#ifndef LAB_ENTRY_11` before the 18
  check). Neutrality is structural. ⚠️ user should refresh the regression baseline; until then RED-benign stands.

## NEXT = A/B run phase (see taskboard ORDER-LANEA-AB) — NOT yet run.
