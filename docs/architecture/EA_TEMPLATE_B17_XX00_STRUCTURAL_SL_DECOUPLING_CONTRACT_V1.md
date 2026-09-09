# B17 xx-00 Structural-SL Decoupling Contract V1

Status: `CONTRACT_ONLY / OWNER_SEMANTICS_ALREADY_RATIFIED / CORE_IMPLEMENTATION_BLOCKED_PENDING_DIFFERENT_FAMILY_REVIEW`
Date: 2026-09-09
Canonical parent: `fecad6daa3da9eaa00cc8420ecb77311566ded43`

## Objective

Make current B17 source capable of representing the already owner-ratified `B17-00` semantics: Wave-1 structural invalidation SL is native, `SINGLE_WHEN_STRUCTURAL` is native, while structural target/TP/Exit ownership is not native-ratified and the generic research Exit remains `ATR_BASED`.

This contract does not ratify a new strategy idea. It exists because current source couples the ratified structural SL to a structural TP path that the owner explicitly did not ratify as native.

## Source-bound problem

`Entry_Wave5.mqh` currently creates both `g_wave5_sl_price` and `g_wave5_tp_price` for a valid Wave5 signal. `ExitManager.mqh` can return the structural TP when `_17_UseStructLevels=true` and ExitMode is not Trail/RunTrend. Therefore parameter selection alone cannot express native structural SL plus generic `ATR_BASED` Exit without source-level separation.

## Required post-change semantics

- Structural SL calculation and validation remain available exactly as a B17-native mechanism.
- B17 structural mode remains compatible only with `STACK_SINGLE`; Recovery remains OFF and Hedge remains OFF under the existing safety compatibility rules.
- Generic `ATR_BASED` Exit must be able to operate without a structural-TP override when the `B17-00` reference selects generic Exit.
- A future separately ratified structural-target mode may exist, but this contract must not create or silently authorize one.
- No historical H01 ExitMode, target value, EntryFib value, or risk/default number is inherited into `B17-00` by this contract.
## Implementation boundary

A future implementation lane may touch only the minimum B17/Exit source and focused tests needed to separate structural-SL ownership from structural-TP ownership. It must not change entry detection, wave construction, lot sizing, shared Stack semantics, Recovery/Hedge semantics, basket risk, default risk numbers, or other families.

Expected source candidates, to be re-verified at implementation dispatch:
- `ea_template/core/entries/Entry_Wave5.mqh`
- `ea_template/core/ExitManager.mqh`
- the smallest focused B17 test fixture(s) required to prove the seam

Any need to modify broader execution/risk code is scope expansion and returns to the Control Tower.

## Acceptance gates for any future implementation

1. Compile affected B17 wrapper/tests with 0 errors; warnings must be reviewed.
2. Positive fixture: structural SL remains active and valid while generic ATR Exit is selected without structural-TP override.
3. Negative/adversarial fixture: a structural TP cannot leak into the generic ATR Exit path.
4. Existing B17 structural safety invariants (`SINGLE`, Recovery OFF, Hedge OFF where applicable) remain fail-closed.
5. Impacted B17 regression plus mandatory project cages pass on one frozen exact HEAD.
6. No H01/config/Home/Package identity is relabelled as `B17-00`.
7. Independent competent DIFFERENT-MODEL-FAMILY review is mandatory because this touches strategy/execution semantics. ChatGPT, Codex, and GPT Hermes cannot fill that seat.

## Authority / hard stops

This contract authorizes no source implementation by itself, no MT5 backtest, no optimization, no HOLDOUT, no Candidate/Grade/KINT, no risk/default change, no runtime/deployment/trading/LIVE action, and no owner attestation.

If a qualified different-family reviewer is unavailable, implementation acceptance remains `BLOCKED`; no same-family substitute or PASS-shopping is allowed.

Direct consumer after an accepted implementation: owner parameter/Home ratification for `B17-00`, followed only then by a separately preregistered Model1 MAIN+BWD screen contract.