# MacroGate independent QA review

Scope: `master` at `92f8dbab`; changes `bf09b729`, `9a38b1e4`.

1. **BLOCKER — a watchdog crash can strand a gate indefinitely.** `ea_template/core/MacroGate_Core.mqh:297-298,313-315`; `ea_template/core/Execution.mqh:77-101`. Input: `STRESS` sets `MACROGATE_BLOCK_990201=1` and `MACROGATE_LOTMULT_990201=0.5`; then the watchdog/terminal dies before `MG_Deinit`. The reader's repeated `GlobalVariableGet` keeps the persistent GV alive, so a restarted carry EA can remain vetoed/throttled indefinitely if the watchdog is not restarted. Normal deinit clears configured magics, but crashes do not. Minimal fix: give the protocol a watchdog heartbeat/expiry and have both Execution readers fail open when stale (or use session-temporary GVs plus startup reconciliation).

2. **BLOCKER — required shared-core regression evidence is missing.** `ea_template/core/Execution.mqh:77-107,225-230`; `ea_template/core/LabCore.mqh:13,54-145`. Input: any existing default-off template build. `bf09b729`/`9a38b1e4` changed `ea_template/core/*`, while their commit messages explicitly defer the mandatory `tpl_regression` run. This violates `AGENTS.md` §3.1 and leaves core behavior unproven. Minimal fix: run `powershell -File scripts\tpl_regression.ps1` and require CLEAN before promotion.

3. **MAJOR — file staleness/missing status is only observed at reload, not every watchdog pass.** `ea_projects/(Boss)_MacroGate/(Boss)_MacroGate.mq5:46-55`; `ea_template/core/MacroGate_Core.mqh:259-289`. Input: file is 47.9 h old and `RISK_OFF` when loaded; at 48.1 h `MG_Tick` runs before the default 240-minute reload. Cached `mg_ok` remains true and it continues to set GVs, contrary to the stated `StaleMaxHours` fail-safe. Deleting/replacing the file has the same up-to-reload delay. Minimal fix: stat/reload/validate every timer pass, or guarantee reload before the remaining stale deadline.

4. **MAJOR — an unsorted CSV silently misses a valid as-of STRESS row.** `ea_template/core/MacroGate_Core.mqh:200-214,223-231`. Input rows: `2024.07.17 00:00,RISK_ON`; `2024.07.20 00:00,NEUTRAL`; `2024.07.18 00:00,STRESS`; now `2024.07.18 12:00`. The lookup breaks at the future 07-20 row and returns 07-17, permitting orders despite the valid 07-18 STRESS row. No future row leaks for ascending input; equal timestamps deterministically select the final equal row. Minimal fix: reject non-ascending input (`mg_ok=false` then clear), or sort and explicitly deduplicate.

5. **MAJOR — a residual block survives lot-only mode.** `ea_template/core/MacroGate_Core.mqh:295-303`; `ea_template/core/Execution.mqh:77-89`. Input: pre-existing `MACROGATE_BLOCK_990201=1`, then run the same magic with `InpBlockNew=false` on a STRESS row. The tick updates lotmult but never deletes the block, so `Exec_MacroBlocked()` still vetoes new orders. Minimal fix: explicitly delete the block GV whenever `mg_blockNew==false`, and check/log failure.

6. **MINOR — invalid numeric GV values can propagate NaN to lot sizing.** `ea_template/core/Execution.mqh:95-101`. Input: malformed/external `MACROGATE_LOTMULT_990201=NaN`; both comparisons are false, so NaN reaches `Exec_NormalizeLot(lot*m)`. Minimal fix: return `1.0` unless `MathIsValidNumber(m)` and `0<m<1`; validate `mg_lotMult` before setting too.

7. **MINOR — CSV datetime parsing accepts malformed dates permissively.** `ea_template/core/MacroGate_Core.mqh:194-197`. Input: `datetime,state` then `2026,STRESS`; `StringToTime` can coerce partial input rather than reject it, potentially gating from a malformed source. Minimal fix: validate exact `yyyy.MM.dd HH:mm` shape and round-trip it before accepting the row.

Verified safe paths: multiplier is used only by `Exec_Open:107` and `Exec_PlacePending:229`; `Exec_ClosePartialFraction:292` uses raw `vol*frac`. Setter/reader GV names match exactly (`MACROGATE_{BLOCK,LOTMULT}_` + magic). Cached-invalid/no-as-of/row-gap paths and ordinary `MG_Deinit` clear configured GVs. Ascending input has `time <= now` no-lookahead semantics; scan is bounded and timer/M1 cadence is acceptable.

Verdict: **fix-then-ship**.
