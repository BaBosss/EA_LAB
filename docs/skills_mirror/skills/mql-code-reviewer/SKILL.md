---
name: mql-code-reviewer
description: >
  MQL5-specific code review for a standalone or framework EA before compile/
  deploy — checks the bug classes that backtest green but break live or silently
  stop: bar-open gate, tester-gate, digit-aware pip size, broker-aware lot
  normalize, magic-number scoping, hard risk caps, and recompile-reset hazards.
  Use when the user has written or modified MQL5 EA code and wants it reviewed
  before compiling, smoking, or shipping. Trigger on /mql-review. For general
  (non-MQL) code review use the scrutinize skill instead.
---

# MQL5 Code Reviewer

MQL5 has a specific set of bugs that pass every backtest and then bite live or place zero trades. A general code review misses them because they're domain rules, not logic errors. This skill is the **MQL5-specific gate** — run it on EA source before compile/smoke/deploy. For broader "should this change exist / does it do what it claims" review, use **scrutinize**; this skill is narrow and mechanical.

## Core stance
- **Backtest-green is not review-pass.** The worst MQL5 bugs (tight-TP fill, missing bar-open gate, tester-gate, hard-coded pip size) produce *beautiful* backtests. Review the code, not the equity curve.
- **Silent failure is the default failure mode.** Most of these bugs throw no error — the EA just trades wrong or not at all. Each check below maps to a real silent failure.
- **Every finding carries the mechanism + the fix line.** Not "looks risky" — name what breaks, when, and the corrected code.

## Architecture and paths
- Boss V2 / `ea_template/core` is the chassis-first default, with routing owned by
  `docs/PIPELINE.md`.
- A standalone path requires a stated reason and belongs under
  `D:\EA_LAB\ea_projects\<EA>\`.
- `EA_CORE` is a read-only archive, not an active authoring path.

---

## The review checklist (run every item)

### A — Will it trade at all? (silent-zero-trade bugs)
```
[A1] TESTER-GATE present and correct?
     const bool allow = _06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
     Missing the MQL_TESTER half → backtest places 0 trades (silent).
     Present but live .set has _06_AllowLive=false → live places 0 trades.

[A2] BAR-OPEN GATE present (for bar-open EAs)?
     static datetime g_last_bar=0;
     if(cur_bar==g_last_bar) return; g_last_bar=cur_bar;
     Missing → entry logic fires every TICK → duplicate orders, wrong counts,
     and optimize/backtest results that don't reproduce live.

[A3] LOT can be below broker min?
     A requested lot below SYMBOL_VOLUME_MIN must be rejected as invalid/0 and skipped;
     never increase it to the broker minimum. Invalid/non-positive min/max/step values
     also fail closed. Valid requests are floored to SYMBOL_VOLUME_STEP, with precision
     derived from the step. This applies to balance-derived and %risk lots alike.

[A4] SIGNAL reads CLOSED bars, not the forming one?
     Use index [1] (last closed) for signal/indicator values, not [0].
     Reading [0] = repainting signal, backtest≠live.
```

### B — Will it trade CORRECTLY? (wrong-but-not-zero bugs)
> **Source of truth for B1/B2 code:** the `PipSize`/`NormalizeLot` patterns live in
> **mql-code-generator → CODE SAFETY RULES**. Don't re-derive them here — check the
> EA's code matches those patterns. Findings below name the symptom; the canonical
> fix is in that skill.
```
[B1] PIP SIZE digit-aware — never _Point*10 hard-coded?
     FX 5/3-digit → point*10; 4/2-digit FX → point. Hard-coded *10 → SL/TP off
     by 10× on 2-digit symbols. NON-FX (XAU, indices, crypto) "pip" is ambiguous
     → for those, require distances expressed in POINTS via input, NOT a pip
     formula. Use mql-code-generator's PipSize() verbatim for the FX case.

[B2] LOT NORMALIZATION to broker step/min/max — never NormalizeDouble(lot,2)?
     Must use the generator's exact semantics: reject invalid/non-positive
     SYMBOL_VOLUME_MIN/MAX/STEP; reject requestedLot <= 0 or requestedLot < minLot
     with invalid/0; never clamp a sub-minimum request upward; floor to step; derive
     decimal precision from the step; then reject any result outside min/max. The
     reviewer must flag NormalizeDouble(lot,2) and any clamp-up-to-min implementation.

[B3] OWN positions identified by MAGIC, never by comment equality?
     Brokers truncate/rewrite comments. Sub-groups → encode in magic.

[B4] Multi-symbol binary scopes by symbol?
     If one .ex5 runs on several charts sharing a magic, every position loop
     must filter PositionGetString(POSITION_SYMBOL)==_Symbol, or EAs cannibalize
     each other's trades. (CB_GBP/CB_EUR share magic 990005 — safe only because
     of this filter.)

[B5] NETTING / HEDGING account semantics explicit?
     Inspect ACCOUNT_MARGIN_MODE when multi-position semantics matter. Hedge modules
     must refuse incompatible netting assumptions; scenario tests must distinguish
     netting from hedging where relevant.

[B6] FILLING policy broker-compatible?
     Inspect SYMBOL_FILLING_MODE and the symbol's execution mode; do not invent one
     universal ORDER_FILLING_* policy. This is a knowledge/cage rule in this milestone,
     not a production behavior change.

[B7] COPYBUFFER / INDICATOR reads safe?
     Handle creation is not data readiness: require CopyBuffer's expected return count,
     make array/series ordering explicit, and document closed-bar [1] versus forming-bar [0].
     Do not use an ambiguous 0.0 failure sentinel when zero is legitimate. A
     protective/risk-path read failure must fail closed where appropriate.
```

### C — Is it safe? (risk-cap bugs)
```
[C1] Hard caps enforced before EVERY OrderSend, not only OnInit:
     max_positions, max_total_lot, daily_loss_limit, emergency_exit_dd.
[C2] No L5 (Grid+Martingale+Hedge combined). L4 only with explicit user
     risk acceptance recorded.
[C3] TRADE RESULT SEMANTICS checked after CTrade calls?
     CTrade::Buy/Sell/etc. returning true only means the request was accepted locally.
     Require the appropriate ResultRetcode()/ResultRetcodeDescription() and resulting
     deal/order/server-state inspection/logging where applicable. Do not edit
     Execution.mqh in this milestone.
[C4] No unbounded recursion of recovery (martingale steps / grid levels capped).
```

### D — Will redeploy break it? (operational bugs)
```
[D1] Param RENAME since the live binary was compiled? Renaming inputs (Inp* →
     _NN_) means the old .set won't map → recompile resets to defaults →
     _06_AllowLive=false → silent stop. Flag any input rename loudly; require a
     matched new .set and a quiet-window re-attach. (EA_BREAKOUT_XAU trap.)
[D2] OnTester present for optimize? double OnTester() returning Sharpe with a
     trade-count floor (<30 → -1) so the optimizer doesn't reward thin samples.
[D3] g_suppress_log gated on MQL_OPTIMIZATION so sweeps aren't slowed by Print.
```

---

## Output format
For each finding:
```
[severity] <check id> — <one-line mechanism: what breaks, when>
  file:line   <the offending code>
  fix:        <the corrected line>
```
Severity: **BLOCKER** (silent-zero-trade or wrong-money — A*, B1, B2, C1) · **HIGH** (B3–B6, C2–C4, D1) · **NOTE** (D2, D3, style).

End with a verdict:
```
PASS         : no BLOCKER, no unresolved HIGH → clear to compile/smoke
FIX-REQUIRED : ≥1 BLOCKER or HIGH → list them, do not compile until fixed
```

## What this skill is NOT
- Not a strategy review (does the edge exist?) → that's **signal-scanner** / **backtest-optimize-rigor**.
- Not a general "should this change exist" review → that's **scrutinize**.
- Not a compile step → that's **vps-deploy-ops**. Review first, then compile.

## One-line reminders
- Tester-gate + bar-open gate + cent-lot-min = the three silent-zero-trade killers.
- Pip size digit-aware; lot broker-aware; positions by magic; multi-symbol filter by _Symbol.
- Hard caps before every OrderSend, not just OnInit.
- Input rename = recompile resets defaults = silent stop — flag loudly.

**This reviewer is a MANDATORY cage stage run on SOURCE before compile — not an optional extra.**
Every generated/modified EA source must PASS this review before it is compiled.

## FINAL RULE
```
NEXT STEP:
PASS → compile 0/0, then forward to backtest-optimize-rigor.
FIX-REQUIRED → return to mql-code-generator / the source to fix the listed
               BLOCKER/HIGH findings, then re-review.
```

> Routing between stages is owned by `docs/PIPELINE.md` — this skill owns its own stage mechanics only.
