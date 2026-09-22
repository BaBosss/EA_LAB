# OFP Native Fixture Runtime Contract — 2026-09-22

Status: `PROSPECTIVE / ONE SYNTHETIC STRATEGY-TESTER DIAGNOSTIC ONLY / NO PERFORMANCE AUTHORITY`

Lane: `ct-ofp-native-fixture-exec-v1-20260922`
Runtime contract ID: `OFP-NATIVE-FIXTURE-PARITY-20260922-001`

## Objective

Execute exactly one MT5 Strategy Tester run whose only research purpose is to prove native MQL parity against the already accepted 24-case synthetic fixture ledger. The run is not a market backtest. It must not be used for PF/net/DD/trade-count claims, historical-data qualification, fill fidelity, optimization, Model4, HOLDOUT, Candidate/Grade/KINT, DEMO/LIVE, deployment or trading.

The accepted source/package is `4e44e7a2e5302200f4ea88e348b762a3f8d64f7c`. Current contract base is `6e73c7f8ef0c5d3664a263510a2ee57163e81cd0`; targeted diff confirms no Order Flow/native-fixture source drift between those refs.

## Accepted synthetic identity

- package manifest SHA256: `a4195efa72d7aee7f35bc319ec61bd4e765f9b4b6f996ae5a4f2ee152904a24e`
- synthetic fixture SHA256: `55ad678178f4606da64091cb5853b043fb76a89b9ea799970db5c847212f2732`
- expected Python ledger SHA256: `60da74d8f5c1516f749d577f03b99c5a0d9e402ed033a28cde19824cc19b7a3e`
- source graph SHA256: `7361de6148638cb85e28d15a962e98e4266a5077e2fdc443189660d7f35f5b3a`
- EA source SHA256: `e014dfcaf35b5e5a710e7e9769144840905f57fdb51f301296f45577c01b9ce5`
- accepted compile receipt SHA256: `ab81ee676f2d89ccbdd9f0264fc882eae6860fe8082c39d726086d58817d9b7e`
- accepted EX5 SHA256: `e0f7cc00c6b2cf41a7fa72f4e2ac08d56ec70238f7dbd40410057f48a7e3a800`, 358,526 bytes
- case count: exactly 24

The accepted compile receipt binds the same current MetaEditor binary SHA256 `197ca3dd8d1971831366f54cb57bf3f120b420700e573135509d406e4e23709e` and reports 0 errors / 0 warnings. Do not recompile merely to consume this contract when all accepted bytes remain exact.
## Frozen Strategy Tester carrier

The carrier is plumbing only. The EA consumes embedded synthetic fixtures and does not derive the 24 expected decisions from carrier market data.

- runtime lane: `MT5_PRIMARY_EXCLUSIVE`
- terminal: `D:\Meta 5\terminal64.exe`
- terminal SHA256: `f61ecfad618a4577df6743eb10e21cfeb2c374ea66ba8d4813c2c0ccca784d33`
- terminal version: `5.0.0.6182`
- portable mode: true; data dir `D:\Meta 5`
- runner: `scripts/mt5_run.ps1`, SHA256 `122bb936f4452957e68c935832b493ddf5a1151778465a640a1629275c707d03`
- Expert relative path: `EALabOFP\OFPNativeFixtureParity`
- runtime target: `D:\Meta 5\MQL5\Experts\EALabOFP\OFPNativeFixtureParity.ex5`
- target did not exist at contract preparation; the controller may copy the exact accepted EX5 for the single run and must remove it afterward if no prior target existed
- symbol / period: `XAUUSD / H1`
- model: `1` (1 Minute OHLC carrier)
- window: `2025.01.02 .. 2025.01.03`
- deposit/currency: `USD 10000`
- leverage: `1:100`
- Optimization=0, ForwardMode=0, ExecutionMode=0, Visual=0
- timeout: 180 seconds; reserve 4 logical cores
- report name: `OFP_NATIVE_FIXTURE_20260922_001`

These carrier values cannot be interpreted as Order Flow strategy settings or market-performance settings. A native result is accepted only from the fixture journal/sentinel and exact identity checks, not from the HTML tester performance report.

## Frozen input surface

Set file: `factory/runs/ofp_native_fixture_20260922/OFP_NATIVE_FIXTURE_20260922.set`

- declared full surface: 1/1
- only input: `InpEmitCompletionSentinel=true`
- effective config hash: `b71a174adc27b284089ab83f5c4f028041147648c68db037d66c71545a495a5a`
- set SHA256: `2d3a5320d493de1b83e07bfd317a07bc6fe55dd82df537feb3e4edc4fd536be4`

No input may be added, omitted, optimized or changed after freeze.
## Preflight and execution gate

Before launch the controller must prove all of the following at the frozen contract head:

1. `origin/master == ls-remote` and any canonical movement is checked for overlap with the accepted OFP/native-fixture source graph.
2. No other live Registry owner holds `MT5_PRIMARY_EXCLUSIVE`.
3. No `terminal64.exe` / `MetaTester*` process is live for the reserved primary install.
4. accepted source/fixture/ledger/manifest/EX5/terminal/runner/set hashes match this contract.
5. set-file surface reports `FULL`, 1/1.
6. the exact accepted EX5 is installed to the frozen target; any prior target must be backed up and restored byte-for-byte.
7. the tester log pre-state is captured before launch.
8. no existing matching durable execution job is live or terminal-unconsumed.

Only then may one durable execution job invoke the frozen runner once.

## Required native evidence

A valid run must preserve a source-bound tester-journal slice containing:

- exactly 24 `[OFP_NATIVE] {json}` records;
- case IDs 1..24 exactly once;
- expected variant counts: OFPR-00/01/02 and OFPC-00/01/02 each 4;
- one `[OFP_NATIVE_COMPLETE]` sentinel with `cases=24`;
- no malformed or duplicate native record;
- exact source/EX5/terminal/runner/set/contract identities in the controller receipt.

The existing accepted parser `parse_native_ledger.py` must compare the observed native ledger against `generated/expected_python_ledger.json`. Parser/native parity may be called PASS only when the accepted comparison semantics report zero mismatch.

The trusted controller receipt and its SHA256 must be written outside the source tree under `D:\EA_LAB_CONTROL\evidence\ct-ofp-native-fixture-exec-v1-20260922`. A separate controller-owned binding receipt must pin that receipt digest out-of-band; self-supplied names/hashes inside the native process are not sufficient proof of execution.

## Stop conditions

Stop without retry if identity, source, target restoration, journal ownership, completion sentinel, record count, parser comparison, runtime-lane exclusivity or controller receipt binding is ambiguous. Do not launch a second fixture variant or rerun merely to obtain a PASS. A transport/wrapper failure before MT5 launch may be reconciled from process/job/postconditions before any retry decision.

## Authority ceiling

This contract authorizes exactly one synthetic fixture-parity Strategy Tester diagnostic. It creates no market-data qualification, historical performance, fill fidelity, PF/net/DD/trade-count verdict, optimization, Model4, HOLDOUT, Candidate/Grade/KINT, risk/default, deployment, DEMO/LIVE or trading authority.
