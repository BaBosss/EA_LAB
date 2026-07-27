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
     Balance-derived lot (balance/Lots_divided or %risk) must be normalized AND
     checked against SYMBOL_VOLUME_MIN. On a cent account this silently rounds
     to 0 / below-min → no fills. (ST_EA03 10k cent incident.)

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

[B2] LOT normalized to broker step/min/max — never NormalizeDouble(lot,2)?
     Must use mql-code-generator's NormalizeLot() (floor-to-step + clamp min/max).

[B3] OWN positions identified by MAGIC, never by comment equality?
     Brokers truncate/rewrite comments. Sub-groups → encode in magic.

[B4] Multi-symbol binary scopes by symbol?
     If one .ex5 runs on several charts sharing a magic, every position loop
     must filter PositionGetString(POSITION_SYMBOL)==_Symbol, or EAs cannibalize
     each other's trades. (CB_GBP/CB_EUR share magic 990005 — safe only because
     of this filter.)

[B5] HEDGING account checked before any hedge logic?
     ACCOUNT_MARGIN_MODE==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING in OnInit, else
     fail INIT.

[B6] GMT/session offset — session-based EAs must not assume the backtest
     broker's server time equals the VPS broker's. Document the assumed offset.
```

### C — Is it safe? (risk-cap bugs)
```
[C1] Hard caps enforced before EVERY OrderSend, not only OnInit:
     max_positions, max_total_lot, daily_loss_limit, emergency_exit_dd.
[C2] No L5 (Grid+Martingale+Hedge combined). L4 only with explicit user
     risk acceptance recorded.
[C3] Return codes checked after OrderSend/trade.Position* — a failed send that
     isn't checked = the EA thinks it has a position it doesn't.
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
