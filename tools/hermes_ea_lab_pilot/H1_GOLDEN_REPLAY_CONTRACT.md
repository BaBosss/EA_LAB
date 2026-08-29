# Hermes H1 — Boss19-0 Golden Replay Contract

Status: READY AFTER THIS MILESTONE IS CANONICAL
Mode: OBSERVE / NO NEW MT5 RUN
Authority: mechanical evidence reproduction only.

## Objective

Using existing canonical Boss19 `19-0` evidence only, reproduce a deterministic research report that matches accepted facts and preserves interpretation boundaries. This qualifies Hermes for evidence-factory work; it does not qualify Hermes as a strategy architect.

## Inputs
Read only current pushed canonical bytes needed from:
- `EA_RND_DIGEST.md`;
- `docs/research/EA_RND_PROTOCOL.md`;
- `docs/research/EA_REPORT_SCHEMA.md`;
- `docs/research/BOSS19_EVOLUTION_LEDGER.md`;
- `docs/concepts/BOSS19_ADAPTIVE_TREND_GRID_SPEC.md`;
- `docs/concepts/BOSS19_ADAPTIVE_TREND_GRID_ACCEPTANCE.md`;
- `ea_template/sets/probe/Boss_19_AdaptiveTrendGrid_V0_STOP_VALIDATION_CENTER.set`;
- `ea_template/core/RiskControl.mqh` and `ea_template/core/Inputs.mqh` for the executable risk-cage depth and protection-profile mapping;
- immediate Boss19 source only if needed to verify mechanics.

Do not search broadly once these sources answer the field.

## Required output
Return one deterministic text report with sections:
1. IDENTITY;
2. MECHANICS;
3. GRID / POSITION STRUCTURE;
4. LOT / EXPOSURE;
5. EXIT / RISK;
6. MAIN;
7. BWD;
8. FLAT-LOT FALSIFIER;
9. LIMIT BOUNDARY CONDITION;
10. HOLDOUT STATE;
11. REGIME EVIDENCE STATE;
12. VERDICT / KNOWN UNKNOWNS / NEXT CONSUMER.

## Golden facts that must reproduce

At minimum:
- lineage: `19-0`, parent `NONE`, base/reference Adaptive Grid;
- tested accepted home so far: XAUUSD H1 only;
- reference center: StepATR `0.30`, Fast `20`, Slow `50`, TP_ATR `1.50`;
- configured `_9_MaxLevels = 5`, but executable depth is `3`: `ProtectLevel=PROTECT_NORMAL=2` -> `RC_MaxRecSteps()=3`, `RC_MaxLevelsOverride=0`, therefore `RiskControl_MaxLevels()=3` and `min(3,5)=3`;
- executable ladder/exposure must use L1-L3 only; farthest executable target is `3 * 0.30 = 0.90 D1 ATR` from the reference (not 1.50 ATR), with UP raw lots `0.010/0.015/0.020` and cumulative raw UP exposure `0.045` lots;
- configured five-level values may be reported only when explicitly labeled **configured/non-executable under the locked risk cage**;
- reference-center meaning: historical surface center, **not global optimum**;
- MAIN 2023-2025: PF `4.64`, 100 trades, net `+4486.59`, report equity-relative DD `7.58%` (maximal-equity-DD line `6.62%`);
- BWD 2020-2022: PF `0.34`, 49 trades, net `-2095.59`, equity-relative DD `25.02%`;
- flat-lot MAIN: PF `5.78`, 97 trades, net `+3477.35`;
- flat-lot BWD: PF `0.30`, 37 trades, net `-1873.43`, equity DD `25.04%`, hard-DD cage fired;
- LIMIT first 500-row surface selected StepATR `0.20` on the lower boundary and TP `1.75` on the upper boundary; one allowed expansion moved the bounds `StepATR 0.20 -> 0.15` and `TP 1.75 -> 2.00`; the resulting 720-row surface selected StepATR `0.15` on the new lower boundary; repeated same-boundary pressure stopped automatic widening;
- LIMIT first-surface StepATR must not be reported as `0.15`; `0.15` is the expanded-surface selected lower boundary;
- LIMIT: repeated StepATR lower-boundary after one bounded expansion; automatic widening stopped;
- HOLDOUT `2026H1 = UNSPENT`;
- current working verdict: `PARKED-VERIFY(user)`;
- broad Symbol x TF matrix: NOT RUN;
- frozen-timeline regime affinity: NOT ESTABLISHED;
- `QUALITY_GRADE = UNRATIFIED` unless an exact ratified mapping is subsequently canonical;
- `EVIDENCE_CONFIDENCE = UNRATIFIED / DESCRIPTIVE ONLY` unless exact ratified thresholds are subsequently canonical;
- `BUILD_POTENTIAL = UNRATIFIED / DESCRIPTIVE ONLY` unless exact ratified thresholds are subsequently canonical.

## Interpretation boundaries

Hermes must not claim:
- all symbols/TFs were tested;
- 0.30 ATR is globally optimal;
- `19-0` is structurally dead;
- a regime gate is validated/active;
- 2026H1 was tested;
- flat-lot proves the entry is universally robust;
- a star rating is an authoritative Quality Grade;
- any candidate/DEMO/LIVE/deployment authority.

Mechanical/environment failures must remain visibly separate from strategy evidence.

## H1 PASS

PASS only when:
- all required sections are present;
- deterministic values above match canonical evidence;
- mechanics/config fields match exact source/set;
- evidence and interpretation are separated;
- every unavailable item is explicit rather than guessed;
- no workspace mutation occurs;
- no new MT5/tester run occurs;
- all forbidden authority claims are absent.

Any numeric mismatch, missing boundary, invented field, hidden mechanical failure, or unauthorized strategy conclusion = H1 FAIL with exact mismatch list.

## Ready-to-run launch shape

Use a clean exact-current-canonical worktree. Do not use dirty `D:\EA_LAB`.

```powershell
$repo = 'D:\EA_LAB'
git -C $repo fetch origin --prune
$head = (git -C $repo rev-parse origin/master).Trim()
$wt = "D:\EA_LAB_worktrees\hermes-h1-golden-$($head.Substring(0,8))"
git -C $repo worktree add --detach $wt $head
powershell -NoProfile -ExecutionPolicy Bypass -File "$wt\tools\hermes_ea_lab_pilot\scripts\run_profile_task.ps1" `
  -Role ea-researcher `
  -SafeWorkspace $wt `
  -ExpectedHead $head `
  -PromptFile "$wt\tools\hermes_ea_lab_pilot\H1_GOLDEN_REPLAY_CONTRACT.md" `
  -Mode observe `
  -RunBudgetSeconds 180
```

H1 itself is not launched by this convergence milestone. H2/H3 remain dependency-blocked until H1 passes and a separate exact execution contract exists.