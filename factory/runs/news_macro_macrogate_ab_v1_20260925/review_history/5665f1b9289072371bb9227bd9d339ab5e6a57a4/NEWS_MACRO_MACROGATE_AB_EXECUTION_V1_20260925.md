# MacroGate A/B Execution V1 — 2026-09-25

Status: `PREPARED_WAITING_TESTER_RESOURCE_AND_FRESH_BUILD_IDENTITY / NO PERFORMANCE RUN`.

Lane: `ct-news-macro-mg-ab-exec-v1-20260925`.
Direct consumer: accepted preregistration `ct-news-macro-mg-ab-prereg-v1-20260925`, canonical head `3d6941ab0f0edbacffbb60022cd84113d6a288b6`. This document binds execution identity only and does not modify preregistered semantics.

## Frozen parent

- EA: `Boss_15_ST03`
- Home: `GBPUSD / H4`
- wrapper: `ea_template/Boss_15_ST03.mq5`
- current/preregistered wrapper SHA256: `e235105deac8c975093a920b34b84565d2d6e355fa64a7802b05dd6592c1d88f`
- parent full-surface set: `ea_template/sets/regression/Boss_15_ST03_defaults.set`
- set SHA256: `ca1415f1f7d855faa51a39e79631b0ad1914ce3ee4d0b0508802d251de239c3c`
- current canonical at Phase-A freeze: `e2f8a8e2eb2efa67aa1efa642b8e49b8f0697ee5`

The accepted prereg head is an ancestor of current canonical, and wrapper/set, LabCore, MacroGate core, macro placebo source, machine prereg and prereg contract bytes are unchanged since accepted prereg integration.

Fresh current-source EX5 SHA256, build receipt, tester installation/build/account and runtime reservation are intentionally `PENDING`. `can_execute=false` until those identities are frozen before any tester outcome.

## Frozen windows and tester controls

- MAIN: `[2023-01-01T00:00:00Z, 2026-01-01T00:00:00Z)`
- BWD: `[2020-01-01T00:00:00Z, 2023-01-01T00:00:00Z)`; validation only, no retuning
- HOLDOUT: `LOCKED_UNSPENT`
- model: Model1 / 1 Minute OHLC
- deposit: USD 10,000
- leverage: 1:100
- evaluation unit: `BASKET_EPISODE`
- primary metric: native maximal equity DD percent

No trade-count floor is added.

## Frozen arms

`BASE_OFF`: `_MG_SelfGate=false`; no feed consumed.

`REAL_GUARD`: `_MG_SelfGate=true`, `_MG_OffsetHours=0`, `_MG_LotMult=0.5`, `_MG_BlockNew=true`, `_MG_TriggerRiskOff=true`; trigger states `RISK_OFF` and `STRESS`.

`PLACEBO`: identical MacroGate policy to REAL_GUARD with exactly the five accepted synthetic schedules:
- `2026092501 -> +38 weeks`
- `2026092502 -> -23 weeks`
- `2026092503 -> -8 weeks`
- `2026092504 -> -32 weeks`
- `2026092505 -> +36 weeks`

All accepted placebo native/provenance artifacts are bound by `factory/runs/news_macro_macrogate_ab_v1_20260925/EXECUTION_CONTRACT.json`. Accepted placebo manifest SHA256: `95caa20a890e2ad0561a5ccf41b0ac83bce7795f9cf22c3577e3e547197e4dea`; rehash mismatch count at Phase-A preparation: zero.

REAL_GUARD native feed SHA256: `6aba7e1e7bd01e82469db580ae666c9903803c4fb8d206f4cc44f8aab8afbb2a`. Accepted transition quarantine SHA256: `545c4e5f684ea8a5c4b231bf57360e65551f2acb8ef4bf3fd685dd211faa59d9`.

Tester feed files must be staged only inside the reserved tester terminal's `MQL5/Files` with `_MG_InCommon=false` and unique experiment filenames. No live/Common feed is overwritten. This is the prereg-authorized mechanical feed-location identity, not a strategy change.

## Resource gate

At Phase-A freeze, durable job `ct-fb-g01-opt01-r1-stage-a1-run-recovery2-20260925` is genuinely RUNNING and owns `MT5-lane1`. MacroGate does not compile, launch MetaEditor, reserve a tester lane or start MT5 while that resource conflict remains. No force, kill or eviction is allowed.

After it releases, the controller must reserve exactly one Model1 tester lane, fresh-compile current canonical Boss_15_ST03, bind EX5/build/install/build/account/leverage/deposit, verify the full effective set, and change `can_execute` only in a new pre-outcome identity-freeze commit.

## BASE hard gate

Execute BASE MAIN then BASE BWD before any guard/placebo outcome. Both must be mechanically full-window eligible, `PF > 1.0` and `net > 0`.

If either fails: `PARENT_NOT_POSITIVE_EXPECTANCY`. Stop. Do not run REAL_GUARD/placebos, retune B15, change parent or use BWD/HOLDOUT for rescue.

## Conditional remaining execution

Only if both BASE windows qualify, freeze the exact arm manifest before remaining outcomes, then serially run REAL_GUARD MAIN+BWD and all five placebo MAIN+BWD cells on the same reserved installation with no retuning.

Mechanism requirements and decision labels are exactly those in the accepted preregistration: `MECHANISM_UNTESTED`, `EXPOSURE_CONFOUND`, `TIMING_VALUE_NOT_SEPARATED_FROM_PLACEBO`, or `TIMING_VALUE_NOT_FALSIFIED`. Blocked-entry share is always `affected_new_entry_attempts / BASE_new_entry_attempts`. No statistical significance is invented.

## Evidence/output contract

Every cell binds source/wrapper SHA, EX5/build receipt, effective set SHA, exact MacroGate/feed delta, symbol/TF, tester identity, exact window, clock receipt, feed/schedule SHA, seed/shift where applicable, report/native receipt hashes, full-window/truncation status, net, PF status, native EqDD amount/percent, trades, basket/episode count, guard firings, affected attempts, blocked-entry share, contact/gated time, time in market, max positions/depth/lots/exposure, hard kills, tail loss, year split, source/state coverage, spread/commission/swap and slippage assumption. Missing evidence remains null/unavailable, never zero-filled.

## Hard stops

No Model4, optimization, HOLDOUT, BWD retuning, parent switching after outcomes, live Boss12/990120 mutation, runtime activation, chart attach/detach, deployment, risk/default change, LIVE/trading, ORDER-211 result reuse, B15 CountBars/BT9 reopening, duplicate execution lane, tester eviction or history rewrite.

The live Boss_12_Breakout USDJPY/H1 magic 990120 remains a DEMO plumbing sensor only and is not a research host.

Final result acceptance requires frozen exact result head/evidence and one independent exact-head GPT Scrutiny after deterministic package completion; no PASS-shopping.

## Phase-A pre-outcome materialization addendum

Before any tester outcome, the execution package materializes two deterministic full-surface sets:

- `B15_BASE_OFF.set`: byte-identical to the accepted parent set, SHA256 `ca1415f1f7d855faa51a39e79631b0ad1914ce3ee4d0b0508802d251de239c3c`.
- `B15_GUARD_ON.set`: full 157-input set generated by the canonical preset compiler; SHA256 `099f2039b430cc340d5c7eaae0c54567c155f78a05de33ec04639d18c5607cec`, declared `effective_config_hash=e95081ded3a8637ec6fd099a010d2b26dbe8da2125cf1f14ef28b9f6ecdfcf70`.

The guarded set differs from BASE on exactly three assignments: `_MG_SelfGate false -> true`, `_MG_InCommon true -> false`, and `_MG_RegimeFile EA_LAB_mris_regime.csv -> EA_LAB_MGAB_ACTIVE.csv`. The latter two are tester-local feed routing only. MacroGate trigger/lot/block policy and every strategy/risk input remain frozen.

`PREOUTCOME_MEASUREMENT_FREEZE.json` binds the exact counting definitions. Guard firings are `gate ON` transitions; affected attempts are explicit MacroGate new-order veto log lines. BASE new-entry attempts require market-entry request lines to reconcile 1:1 with BASE entry deals with zero transport/order failures. If this cannot be proven, blocked-entry share is unavailable and interpretation stops rather than substituting a proxy. Basket episodes are source-bound flat-to-flat directional exposure intervals; ambiguous ownership is unavailable. UNKNOWN quarantine is excluded from gated time.

At this addendum freeze, `can_execute=false`, compile runs = 0, MT5 runs = 0 and HOLDOUT remains `LOCKED_UNSPENT` because FB-G01 still owns the required tester resource.
