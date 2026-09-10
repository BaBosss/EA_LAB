# B14 GridLog EURUSD/H1 Fixed-Configuration Model1 Control Contract — 2026-09-10

Status: `PREREGISTERED / RESEARCH_ONLY / FIXED_CONFIG / NO_MT5_YET`
Hypothesis ID: `HYP-B14-EURUSD-H1-FIXED-CONTROL-01`
Canonical base/head: `389159d960d312a2a4f304f5becfee699b127b01`
Runtime lineage: `D:\Meta 5c` only.
Model: `1 / 1 Minute OHLC` (`M1_M1_OHLC_RESEARCH`).
Optimization: `0`; Forward: `0`.
Deposit: `USD 10,000`; leverage: `1:100`.
HOLDOUT: `UNSPENT / FORBIDDEN`.

## Question and direct consumer

Does the accepted source-native B14 GridLog control show a useful, participation-qualified positive pulse on its frozen Home (`EURUSD/H1`) in both the prospective MAIN and validation-only BWD windows when all native mechanics and non-native test controls are held fixed?

The direct consumer is one exact-identity B14 fixed-control result record applying the prospective classification in this contract. `USEFUL_CONTROL_PULSE` may unlock only the authoring of a **new, separately preregistered, one-change causal consumer**. `DUAL_POSITIVE_BELOW_USEFUL_BAR` or `NO_USEFUL_CONTROL_PULSE` closes this fixed control honestly at its present scope. No classification here directly unlocks optimization, HOLDOUT, Candidate, deployment, runtime attachment, or a default/risk change.

Execution can be performed by a deterministic local executor or bounded Hermes/batch lane under this exact contract; suggested executor: deterministic local runner/parser. Interpretation and any later causal experiment design remain with the Control Tower under existing authority.

## Frozen identity package

The execution and result are admissible only when every identity below matches `factory/runs/b14_gridlog_model1_control_20260910/prereg_identity.json` (`ea-lab-b14-gridlog-model1-prereg-identity/1`). Hashes are SHA256.

| Identity | Frozen value |
|---|---|
| EA | `EALabTpl\Boss_14_GridLog` |
| Wrapper source | `ea_template/Boss_14_GridLog.mq5` — `69eec0c51b7df5190a3fe0364d11a13629bc16372fcda93513a2882af9076c28` |
| Full-surface set | `factory/runs/b14_gridlog_model1_control_20260910/B14_GRIDLOG_MODEL1_CONTROL.set` |
| Full-surface coverage | exactly `154/154` assignments |
| Full-surface set SHA256 | `3d0a7fc43e3445c9a3a5c574af8a927a192aa10dacf53f2e2cabdb682d00fb43` |
| Effective config fingerprint | `e1a9d05bcab4a84467ef30ac8f58a5fbf46258ed4dd1264f59a55d8f9f86079c` (`surface+constants`) |
| Overlay provenance | `factory/runs/b14_gridlog_model1_control_20260910/B14_GRIDLOG_MODEL1_CONTROL_OVERLAY.set` — `801274e8578a27a831087b1411997cd03dd9049ca111bf64fad9c8d194f5f6ff` |
| EX5 SHA256 | `a270629a769583db23ca22964323b6f86393676ed0e038866271973260f62a77` |
| Build receipt | `br-53ed22eb601a4393bfa7399cc8824bfe` |
| Build-receipt registry | `factory/runs/b14_gridlog_model1_control_20260910/build_receipt.jsonl` — `6d8bd2fbb7b16212d339654132808d0f9237f388566ad5fd0315abaa596ad34e` |
| Source graph | `factory/runs/b14_gridlog_model1_control_20260910/build_source_graph.json` — `5904e6b49ce75d72b4685ef8688fccf47ca1ae5c8df743b91b8c647cce4eecf2` |
| Source-graph coverage | `83` static source files, bound to canonical SHA `389159d960d312a2a4f304f5becfee699b127b01` |
| Terminal | `D:\Meta 5c\terminal64.exe`, version `5.0.0.6140`, SHA256 `dfd977c2885ea3c92bb4e3a5a33faf677283f4c51c2baa0142c393a4ee11b8f2` |
| Compiler | `D:\Meta 5c\metaeditor64.exe`, version `5.0.0.6140`, SHA256 `05718f3fa55f3f59fd2f024d8c433b457fbd58fcf39e947a16ccdad00a614ec7` |

The build receipt points to the isolated staging root `D:\EA_LAB_CONTROL\builds\b14_gridlog_model1_control_20260910_389159d9`. The executable, wrapper, receipt registry, and source graph are one indivisible build identity. Do not rebuild, substitute an EX5, regenerate the set, omit an input, or accept terminal-side defaults for this experiment.

## Frozen mechanics and configuration

### Source-native B14 controls

- Home and direction: `EURUSD/H1`, BUY only (`_14_Direction=1`).
- Source-cadence compatibility: `_0_BarOpenOnly=true`; the accepted template behavior still permits the GridLog resting-level trigger check intrabar while bar-gating open-basket management/add behavior.
- ATR: period `14`, `PERIOD_CURRENT` (`_0_ATR_TF=0`).
- Native first-entry arm: ATR at shift `1`, multiplier `1.5`, with a `20.0` pip floor (`_14_DistAtrMult=1.5`, `_14_MinDistPips=20.0`).
- Lot progression: `LOG_POWER` (`LotProg=55`), factor `1.3`, using natural log `ln(orderN)` (`_55_LogPowerFactor=1.3`, `_55_UseLnNotLog10=true`).
- Profit exit: fixed account-currency basket target `$20.00`; ATR and balance-percent basket targets are disabled (`_2_BasketTP_Money=20.0`, `_2_BasketTP_ATRmult=0.0`, `_2_BasketTP_BalPct=0.0`).
- Basket target owns the profit exit; per-leg TP is suppressed (`_2_SuppressLegTP=true`).
- Shared generic add chassis, kept distinct from the native arm: `GRID_AGAINST` (`StackMode=92`), ATR distance `2.0` on `PERIOD_CURRENT`, `DISTANCE` confirmation (`StackConfirm=0`).
- Recovery OFF (`RecoveryMode=80`) and Hedge OFF (`HedgeMode=0`).
- EA-owned basket balance stop: `10%` of current account balance (`SLMode=32`, `_32_SL_Money=0.0`, `_32_SL_BalPct=10.0`).

### Prospective non-native test controls

These values are frozen solely as `TEST_CONTROL_ONLY` source-compatibility/execution controls. They are **not** B14 native semantics, family defaults, risk-default authority, or a recommendation for later variants:

- `FirstLotMode=FIXED` (`FirstLotMode=41`) and `_41_FixedLot=0.02`.
- `_9_MaxLevels=6` and `RC_MaxLevelsOverride=6`, making the effective maximum depth exactly `6`.
- `_9_StepATRShift=1`.

Every other tester input remains frozen exactly by the full-surface `154/154` set. The overlay is provenance for materialization only; the full-surface set, its SHA, and its `surface+constants` fingerprint are the execution authority. Historical H01 sets, optimized sets, terminal defaults, or values from another B14 run may not fill or replace any field.

## Frozen execution matrix

Exactly two serial Strategy Tester cells may be run, both on the same `D:\Meta 5c` installation lineage:

1. MAIN: `EURUSD/H1`, `2023.01.01..2025.12.31`, Model `1 / 1 Minute OHLC`.
2. BWD: `EURUSD/H1`, `2020.01.01..2022.12.31`, Model `1 / 1 Minute OHLC`.

Both cells use the same exact EX5 and full-surface set, `Optimization=0`, `Forward=0`, USD `10,000`, and leverage `1:100`. HOLDOUT is not part of either window and must remain unqueried and unspent.

BWD is validation/falsification only. It cannot select a value, alter the configuration, trigger a rerun for reassurance, or serve as optimizer round two. No automatic optimization follows any result.

## Mechanical acceptance

A cell is mechanically valid only if deterministic evidence proves all of the following:

- exact set SHA, `154/154` full config surface, effective config fingerprint, EX5 SHA, build receipt, source graph, terminal hash, compiler hash, symbol, timeframe, requested date window, Model 1, deposit, currency, leverage, installation, `Optimization=0`, and `Forward=0`;
- a fresh report produced by this run, parseable and non-truncated, whose tested interval covers the complete requested window;
- no MAIN/BWD/HOLDOUT overlap and no access to HOLDOUT;
- no unknown, omitted, migrated, or terminal-defaulted config key; and
- exact evidence provenance sufficient to distinguish the report from historical or cross-install evidence.

The result record must retain raw report/config/run receipts and report MAIN and BWD PF, net, closed trades, exact drawdown field/definition, hard-kill events, yearly split, and grid/exposure diagnostics available from the evidence. For this grid strategy it must explicitly report max concurrent positions, realized maximum depth, maximum aggregate lots, maximum grid span in ATR or the exact native normalized unit, and the calculated/normalized `L1..L6` lot ladder; unavailable fields must be `UNKNOWN / UNAVAILABLE`, never guessed.

An empty cell, stale or reused report, truncated interval, config/build/source mismatch, cross-install substitution, unparseable required identity/metric, missing history, runner failure, or other harness/environment defect is `BLOCKED / MECHANICAL`. Mechanical, harness, data, and environment failures are not strategy failures and may not receive a strategy classification.

## Prospective result rule

Apply this precedence only after both cells pass mechanical acceptance:

1. `USEFUL_CONTROL_PULSE` only if all are true:
   - MAIN: PF `>= 1.20`, net `> 0`, closed trades `>= 100`;
   - BWD: PF `>= 1.00`, net `> 0`, closed trades `>= 100`.
2. Otherwise, if both MAIN and BWD have PF `> 1.00` and net `> 0`, classify `DUAL_POSITIVE_BELOW_USEFUL_BAR`.
3. Otherwise classify `NO_USEFUL_CONTROL_PULSE`.

If either cell is empty or mechanically invalid, stop at `BLOCKED / MECHANICAL`; do not fall through to any of the three strategy-result labels.

The classifications are bounded experiment outcomes, not canonical EA verdicts. A weak result closes this exact fixed control without BWD mining, historical-set substitution, parameter rescue, or retrospective threshold changes.

## Exact stop rule and bounded repair

Stop before or during execution when any frozen identity cannot be proven, the requested Meta 5c lineage is unavailable, a report is not fresh/full-window, HOLDOUT would be touched, or continuing would require changing source, mechanics, config, test windows, model, deposit, leverage, or installation.

At most **one bounded mechanical repair** is allowed for a runner, parser, report-packaging, or environment problem. The repair may not change strategy source or any frozen identity/value and may rerun only the mechanically affected cell. Losing or weak valid evidence is not repairable. If the same unresolved question or failure condition is encountered twice—initial attempt plus the single repaired retry—record `BLOCKED / MECHANICAL`, preserve both attempts, and stop. There is no third attempt, alternate install, historical substitution, config adjustment, BWD-driven change, or optimization fallback under this contract.

## Evidence, interpretation, decision, and authority ceiling

- Evidence: exact identity files, tester configuration, fresh reports, run receipts, hashes, parsed metrics, full-window/truncation proof, year splits, hard-kill and exposure diagnostics.
- Interpretation: apply only the prospective classification rule above and state material limitations/unknowns.
- Decision: close this fixed control, or—only after `USEFUL_CONTROL_PULSE`—permit a new separately preregistered one-change causal consumer to be proposed. No downstream experiment is auto-opened.

Authority ceiling: `RESEARCH_ONLY / FIXED_CONFIG_MODEL1_CONTROL_ONLY / NO SOURCE MUTATION / NO CONFIG RETUNING / NO OPTIMIZATION / NO HOLDOUT / NO MODEL4 CLAIM / NO CANDIDATE / NO GRADE-KINT / NO RISK-DEFAULT CHANGE / NO RUNTIME ATTACHMENT / NO DEPLOYMENT / NO TRADING / NO DEMO-LIVE / NO LIVE`.
