# B11-00 Fixed-Reference Model1 Screen Results — 2026-09-21

Status: `EXECUTION_CONSUMED / MECHANICALLY_INELIGIBLE_HARD_KILL_TRUNCATION / REVIEW_PENDING`
Execution contract head: `5becccb5f0316f067d9cfce6e0826dab6ab74c10`
Lane: `ct-b11-00-model1-execution-20260921`
Authority: research evidence only. No optimization, Model4, HOLDOUT, Candidate/Grade/KINT, runtime, deployment or trading authority.

## Fixed execution identity

The executed reference is the preregistered B11-00 XAUUSD/H1 Model1 pair: FastMA 20, SlowMA 50, EMA, current-TF MA, ATR14, full 151/151 input surface, config fingerprint `9411859142dcad9364d712f5d4348e32c70699139d57666d2c2908d84751e29b`, set SHA256 `fe5a94806694c2342acb21c40d9e8618ddd550b2d0bb1c2e11306c82fbe604ca`, build receipt `br-65cf1caf297d4d4cb6588c887a0aaca7`, compiled EX5 SHA256 `1b962dd80af4657da1f72a46fd50c63cf663e4832829ee50c5bff7fd5752341f`, USD100 proxy, leverage 1:1000, Model1, Optimization=0. HOLDOUT was not used.

Durable execution job `ct-b11-00-model1-execution-20260921-20260921T053011Z-43ce3209` completed with exit 0 and postcondition exit 0. MAIN and BWD reports exist and leverage checks both MATCH 1:1000.

## Exact early-stop diagnosis

The original run did not preserve the tester journal into the tracked run package, but the same tester journal still existed at `D:\Meta 5b\Tester\logs\20260921.log`. The existing contract requires logs and permits one bounded mechanical/packaging repair; the journal was therefore copied byte-for-byte without rerunning MT5.

Preserved tester journal SHA256: `761e0c6e292fddb4916c8da5a8df65ec9cbd34997534881fb2049867c289661f`.

MAIN:
- First entry: 2023.01.03 01:01:00, buy 0.10 XAUUSD.
- At 2023.01.03 01:14:40 the tester journal records: `[RISK] HARD KILL: DD 29.58% >= 25.00% (profile 2) -> closing all`.
- The position was closed and the journal then records: `[RISK] HARD KILL complete: broker flat verified -> halt (persisted)`.
- No later entry is possible because the successful hard-kill path sets the shared RiskControl halted state and OnTick returns before entry/stack logic.
- Result: MAIN is `TRUNCATED / MECHANICALLY_INELIGIBLE`, with the remaining ~99.8% of the requested window occurring after the persistent halt.

BWD:
- First entry: 2020.01.02 01:01:00, buy 0.10 XAUUSD.
- At 2020.01.02 01:29:20 the 10% basket stop worked as configured: `[EXIT] basket money-stop (safety, intrabar): net -10.00 <= -10.00 -> close all`.
- A second entry opened at 2020.01.02 01:29:40.
- At 2020.01.02 01:35:40 the tester journal records: `[RISK] HARD KILL: DD 25.46% >= 25.00% (profile 2) -> closing all`.
- The journal then records: `[RISK] HARD KILL complete: broker flat verified -> halt (persisted)`.
- Result: BWD is `TRUNCATED / MECHANICALLY_INELIGIBLE`, with the remaining ~99.9% of the requested window occurring after the persistent halt.

## Source-trace reconciliation

The preserved execution source confirms the observed routing. `PROTECT_NORMAL` resolves to a 25% hard-kill threshold. In shared B11 OnTick, `RiskControl_CheckDD()` runs before `Exit_SafetyMoneyStop()`. When hard kill fires, it closes all positions, verifies broker flatness, sets `g_rc_halted=true`, and subsequent ticks return before entry logic. Therefore the terminal inactivity is not unexplained tester truncation and does not require a repeat performance run.

The BWD first basket demonstrates that the 10% balance stop is active, but it does not prevent a later basket from reaching the 25% hard-kill threshold before the basket stop owns that tick. The MAIN journal shows the 25% cage owning the terminal tick directly.

## Classification

Both requested Model1 cells are mechanically ineligible as full-window performance evidence because the configured hard cage permanently halted the EA near the start of each requested window. The observed PF/net/trade counts are truncated path observations only and are not used for a strategy PASS or FAIL verdict.

The contract permits no cage widening or semantic/config rescue after seeing this result. The owner-preregistered FastMA/SlowMA optimization lattice remains NOT AUTHORIZED because the prerequisite mechanically accepted dual-positive screen does not exist. Model4 and robustness remain NOT AUTHORIZED; HOLDOUT remains UNSPENT; Candidate/Grade/KINT remain NOT ELIGIBLE.

## Evidence

- `factory/runs/b11_00_model1_20260921/diagnostic/MT5_TESTER_20260921.log` — byte-preserved tester journal.
- `factory/runs/b11_00_model1_20260921/diagnostic/EARLY_STOP_EXCERPT.txt` — focused identity/exit/risk lines.
- `factory/runs/b11_00_model1_20260921/diagnostic/TRUNCATION_DIAGNOSTIC.json` — machine diagnosis.
- Durable execution result SHA256: `80da23f2d5e91c5c575acc12bf08b876cdd80460198db74b177dccd8cbc3c850`.
- Durable job result SHA256: `66017cb03a324800e54a66e2186dbd40df6bcbaf52655e4d24c4318c8e6332c2`.
- Diagnostic JSON SHA256: `a6276c475691bc6ddd1753f8f97fdd7e01334216ad5bbad726b00f688d0dc842`.

## Review boundary

Packaging repair usage is 1/1 and is limited to consuming/preserving the existing tester journal and diagnosing the early stop. No MT5 rerun occurred.

Final acceptance still requires a separate exact-head read-only GPT Scrutiny review. No new reviewer lane was created because the owner explicitly instructed this continuation not to create a new lane or duplicate reviewer. Until such review is lawfully available, this result must remain `REVIEW_PENDING` and unintegrated.
