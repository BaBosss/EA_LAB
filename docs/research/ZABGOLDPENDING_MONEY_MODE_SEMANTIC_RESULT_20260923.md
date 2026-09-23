# ZABgoldpending — money-mode semantic probe result — 2026-09-23

Status: `SEMANTICS_UNRESOLVED / BLOCKED_C_DEPENDENCY_TRUST_DLL_REQUIRED_OPAQUE_BINARY / READY_FOR_TEST=false`.

Authority: `SEMANTIC_DIAGNOSTIC_ONLY_NO_PERFORMANCE_VERDICT`. This result does not authorize performance testing, optimization, HOLDOUT, Candidate/Grade/KINT, deployment, runtime or LIVE trading.

## Frozen contract

Canonical preregistration: `38da78a2f4d46496093e76945af28bf5e5b437db`.

The accepted A/B/C contract allowed only first-entry timestamp/side/volume plus init/dependency errors. PF, net, DD, win rate, exits and later trade path were forbidden evidence.

## Execution

Only `A_OWNER` was attempted, exactly as preregistered:

- `Risk_Percent=1.0` (owner-selected 1%)
- `Fixed_Lot_Size=0.1`
- `XAUUSD M5`
- Model-1 / 1 Minute OHLC
- MAIN subwindow `2023-01-01..2023-03-31`
- tester deposit `10000 USD`
- tester leverage `1:100`
- exact selected EX5 SHA256 `f75e6d11f298765521d0bbcb7ce37c0e2fdacec3136315dd48047ee2249c9c90`
- MT5 build `6182`
- private account/tester identity bound only in external local evidence, not Git

Strategy Tester invocation started and loaded the exact 12 inputs, but the EA failed during global initialization with:

`DLL loading is not allowed`

The log then records global initialization failure and tester stop. No first entry occurred (`first_entry_evidence_count=0`).

Per the preregistered fail-closed rule, `B_FIXED_ONLY` and `C_RISK_ONLY` were **not run**. Therefore no precedence inference is permitted.

## Dependency triage

- No `.dll` artifact exists in the accepted Facebook intake.
- Static printable-string inspection of the opaque EX5 did not recover a trustworthy DLL name or native API identity.
- The exact Facebook post/comments and accepted source corpus do not provide a DLL enable/import instruction for this EA.
- DLL execution was **not enabled**. The binary is opaque and the required native dependency is not identified/trusted.

Enabling an unknown DLL for an opaque downloaded EX5 would cross a separate trust/security boundary and is not silently authorized by this semantic experiment.

## Decision

`Risk_Percent` versus `Fixed_Lot_Size` precedence remains `UNKNOWN`.

This is an environment/dependency/trust blocker, not a strategy failure and not evidence for either money mode. `READY_FOR_TEST=false` remains binding.

No performance metric was consumed for this decision. HOLDOUT `2026H1` remains unspent and optimization remains unauthorized.

## Next gate

Obtain trustworthy dependency identity/source/vendor guidance for the required DLL, or a separate explicit owner trust decision for a sandboxed DLL-enabled semantic probe. Until then, do not run B/C and do not open fixed-config MAIN/BWD performance testing.

External execution receipt: `D:/EA_LAB_CONTROL/evidence/zabgoldpending-mm-semantic-20260923/SEMANTIC_EXECUTION_RECEIPT.json`.