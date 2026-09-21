# B11-00 Fixed-Reference Model1 Screen Contract — 2026-09-21

Status: `PROSPECTIVE_PREREGISTRATION / NO_MT5_UNTIL_CANONICAL_REVIEW / HOLDOUT_UNSPENT`
Lane: `ct-b11-00-model1-screen-20260921`
Preregistration base: `2f3770b279a173141ea051124d72110be261fde3`
Authority: B11 research only; no runtime/deployment/trading/default authority.

## Objective

Run one exact owner-frozen B11-00 reference on one Home through Model1 MAIN+BWD without retuning.
This is the first prospective performance screen for B11-00, not a rerun of H01/H02/BT8 or the example conveyor.
The owner explicitly authorized an initial experiment and autonomous continuation only through lawful downstream gates.

## Frozen B11-00 identity

- Family / logical variant: `B11 / B11-00`.
- Source: `ea_template/Boss_11_GridTrend.mq5`, SHA256 `59c51ad12ecc0450c19bffa373f836a95c0c3fe6808a2029fcc946f28c29f672`.
- Entry module SHA256: `c6f61f1574dc5956aca79d21c14840baea815add26042f5d362781854ca6c898`.
- Home: `XAUUSD / H1`.
- Entry: FastMA `20`, SlowMA `50`, MAMethod `EMA/1`, MA_TF `PERIOD_CURRENT/0`.
- Entry semantics: fast MA versus slow MA directional state at shift0; not a crossover detector.
- Signal ATR: period `14`, timeframe `PERIOD_CURRENT/0`.
- Native map: `NONE`.

## Generic xx-00 chassis and explicit screen controls

- Position engine: `GRID_AGAINST / StackMode=92`.
- Stack confirmation: `DISTANCE / StackConfirm=0`.
- Stack distance: ATR x `2.0`, current TF, ATR shift `0`, min-pips floor `0`.
- Requested stack max: `_9_MaxLevels=5`; effective cage max is `3` under `PROTECT_NORMAL` with no override.
- Exit: `ATR_BASED / ExitMode=22`; explicit test-control TP multiplier `3.0 ATR`.
- Basket protection: `SL_MONEY / SLMode=32` with `_32_SL_BalPct=10.0`; absolute `_32_SL_Money=0` remains inert.
- First lot: `FIXED / 0.10`.
- Progression: `PLUS / +0.01 per level`.
- Direction: `BOTH`.
- Trend filter, regime mode/add gate, Recovery, Hedge, MacroGate self-gate, Heat, MiddlePath, SMC veto, dynamic close and spread guard: OFF.
- BarOpenOnly: `false`; do not rewrite shift0 timing semantics.

Protection cage is held at current declared `PROTECT_NORMAL`: kill-DD 25%, max deposit load 30%, recovery-step cage 3, `RC_MaxLot=0.20`, `RC_MaxLevelsOverride=0`, account-DD gate OFF.
The 10% EA-owned basket balance stop is intended to fire before the 25% cage when attributable to this EA.
A cage fire/truncation is mechanical/path evidence; do not enlarge the cage after seeing it.

## Full effective configuration

Set: `factory/runs/b11_00_model1_20260921/B11_00_FIXED.set`.
Set SHA256: `fe5a94806694c2342acb21c40d9e8618ddd550b2d0bb1c2e11306c82fbe604ca`.
Surface: `LAB_ENTRY_11 151/151 FULL`.
Effective config hash: `9411859142dcad9364d712f5d4348e32c70699139d57666d2c2908d84751e29b` (`surface+constants`).

Machine classification: `factory/runs/b11_00_model1_20260921/control_resolution.json`.
It records 38 explicit screen controls and every remaining current declared input as `SOURCE_DECLARED_TEST_CONTROL`.
Unchanged declared defaults are held fixed for reproducibility only; they do not become B11 family semantics or production defaults.

## Tester / account profile

Owner research reference: `10,000 cent`, fixed 0.10, additive +0.01.
Current canonical `scripts/mt5_run.ps1` freezes tester currency to USD, so this experiment prospectively uses:
- effective tester currency/deposit: `USD 100` as the economic proxy for 10,000 cent;
- leverage: `1:1000`, an experiment-only runtime/margin control, not a strategy or production leverage default;
- fixed lots and the balance-percentage basket stop are preserved under the 100x account-unit proxy;
- denomination-specific absolute-money fields are kept inactive.

Installation: `D:\Meta 5b` in portable mode / runtime lane `MT5-lane2`.
Terminal: build `5.0.0.6090`, SHA256 `20dfefd944ae482781ac1e83a736a976ecf0315661e54b5771e327f1ffb2b35c`.
MetaEditor: build `5.0.0.6090`, SHA256 `64b7335854310bf2f0f84f5e51e12ee28f047de9eefd9f8a70005624f9d1df90`.
Parser SHA256: `b2af79b9f694d1253137a559782db6f48a483a23a33caea7b68829f581e3b16b`.

Tester model: Model 1 / 1 Minute OHLC.
Optimization=0. ForwardMode=0.
MAIN: `2023.01.01 .. 2025.12.31`.
BWD: `2020.01.01 .. 2022.12.31`.
HOLDOUT 2026H1: `UNSPENT / FORBIDDEN`.

## Execution protocol

1. This contract, full set and machine preregistration must be canonical and reviewed before tester execution.
2. Fresh-compile `Boss_11_GridTrend` from the exact contract lineage on Meta5b, stamped with a new build receipt.
3. Preserve the prior Meta5b B11 EX5 and restore it byte-for-byte after the two cells.
4. Execute MAIN then BWD serially on the same install and same EX5/set identity.
5. Run BWD regardless of MAIN outcome; no parameter, Home, leverage, deposit, model or cage change between windows.
6. Verify exact symbol economics, full 151-input surface, build receipt, EX5 hash, config fingerprint, report freshness, requested leverage and requested date span.
7. Preserve raw HTML/native graphs/INI/logs before parsing; use the accepted canonical parser.
8. Produce year split and same-ledger exposure/grid diagnostics when source evidence permits; unavailable native fields remain UNKNOWN/UNAVAILABLE.
9. Restore tester surface and prove zero same-install MT5 process remains.

No retune is allowed after MAIN or BWD. A losing result is a result, not a repair trigger.

## Required evidence package

- raw MAIN/BWD MT5 reports, INIs, runner logs, leverage checks and truncation checks;
- source/build/set/config/install hashes and stamped build receipt;
- corrected parser JSON for both cells;
- year split;
- grid/exposure diagnostics including max concurrent positions, realized depth and aggregate lots where reconstructable;
- native MT5 graphs preserved as native evidence;
- workflow diagram marked visual-only;
- human result report plus machine-readable summary;
- package manifest/hash inventory;
- Monitor-compatible read-only evidence; no new Monitor implementation or runtime deployment.

## Prospective classification and continuation

Use the already accepted H02 screening definition; do not invent a new PF floor here.

- `DUAL_POSITIVE_SCREEN_PULSE`: both mechanically accepted full-window cells have PF > 1.00.
- `NO_DUAL_POSITIVE_SCREEN_PULSE`: mechanically accepted pair does not satisfy that definition.
- `MECHANICALLY_INELIGIBLE`: identity, full-window, leverage, source/config, report freshness or other required mechanical evidence is invalid.

The screening label is research-only. It is not Candidate, Grade, KINT, risk, deployment or trading authority.
If `DUAL_POSITIVE_SCREEN_PULSE` is accepted, the next lawful action is only to author and review a separate prospective optimization contract consuming the owner-preregistered lattice.
If not dual-positive, close/PARK this B11-00 fixed reference honestly; do not optimize it from this contract and do not mine BWD.

Owner-preregistered future lattice, still NOT authorized here:
- FastMA: `5,10,15,20,25,30`;
- SlowMA: `50,60,70,80,90,100`;
- MAMethod EMA, MA_TF current, ATR14 and Home XAUUSD/H1 frozen.
No optimizer may consume this lattice until a separate canonical contract opens it.

## Repair / review policy

One bounded mechanical/packaging repair maximum is permitted only for attributable execution/reporting defects.
It cannot alter strategy semantics, fixed parameters, account proxy, leverage, window, cage, Home or performance criteria.
A strategy loss, DD, low PF, low participation or BWD weakness is never a repair defect.
Final evidence requires separate exact-head read-only GPT Scrutiny; author cannot self-approve and no PASS-shopping is allowed.
