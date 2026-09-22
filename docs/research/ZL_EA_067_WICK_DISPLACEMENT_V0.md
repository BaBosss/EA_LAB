# ZL-EA-067 Wick Displacement — EA_LAB Independent Child V0

> **Forward-only status supersession — source accepted 2026-09-19.** The current canonical owner is
> [`ZL_EA_067_SOURCE_ACCEPTANCE_20260919.md`](ZL_EA_067_SOURCE_ACCEPTANCE_20260919.md):
> `B22 / LAB_ENTRY_22 / Boss_22_WickDisplacement` is **SOURCE_ACCEPTED / REVIEWED / CANONICAL / REPO_ONLY /
> NO_PERFORMANCE_SCREEN** at exact accepted and reviewed source
> `57aed8a5235f871fcdaf198433dd66f2c4ebaa11`. This supersedes the bounded-author pending-gate status below
> for current routing only. The V0 design, original author-stage status, and acceptance evidence remain preserved
> as historical source-bound evidence. Source acceptance selects no performance, Home/TF/settings, runtime,
> deployment, DEMO/LIVE, Candidate/Grade/KINT, risk/default, or trading authority.

## Historical bounded-author snapshot — superseded for active status

Status: `B22 IDENTITY-ONLY IMPLEMENTED / AUTHOR DETERMINISTIC+COMPILE GATES PASS / CONTROL-TOWER RUNTIME+REGRESSION+HOOKS+SCRUTINY PENDING / RESEARCH_ONLY / NO_ORIGINAL_ZIPLOR_FIDELITY_CLAIM`
Canonical implementation base: `5c85eba937968f80e558f11d583be85a2969c41e`
Historical B20 canary head: `14b3181af77c52cb66b4cd30db132239d826f1ef` (technical evidence only; non-integratable under B20)
Frozen external contract SHA256: `D63FBF5572C3F9F446E7E86E4046C52758C1A093E8716758D198DEDDF59B2A51`
Current identity contract: `docs/research/ZL_EA_067_IDENTITY_REALLOCATION_CONTRACT_20260918.md`
Target: `LAB_ENTRY_22 / Boss_22_WickDisplacement / Entry_WickDisplacement`

## Provenance classes

### SOURCE-DOCUMENTED FACT
The owner-prepared Ziplor integration program names `ZL-EA-067 — Wick Displacement` as the first canary and classifies it as OHLC-only, minimal-dependency, no-grid, no-recovery, and independent of proprietary data. The preparation pack itself is not present in the current local/file evidence, so no exact proprietary formula is imported.

### EA_LAB INDEPENDENT DERIVATION
V0 is deliberately a small two-closed-candle mechanism defined prospectively by the external contract above. It is an EA_LAB research child, not a clone or reconstruction of inaccessible TradingView/Ziplor source.

### UNKNOWN / SOURCE REQUIRED
The original Ziplor entry formula, thresholds, filters, exits, and implementation details are unknown. A later source recovery may motivate a separate variant, but it must not retroactively relabel this V0 as faithful.
## Frozen V0 mechanics

Use only closed bars: rejection candle `shift=2`, confirmation/displacement candle `shift=1`.

BUY requires:
1. valid non-doji rejection candle;
2. lower wick is dominant and at least `_22_WickBodyRatio × body`;
3. next candle is bullish;
4. its body/range is at least `_22_DisplacementBodyFraction`;
5. it closes strictly above the rejection high.

SELL is the exact mirror: dominant upper wick followed by a bearish displacement candle closing strictly below the rejection low.

Inputs are limited to:
- `_22_WickBodyRatio = 2.0`;
- `_22_DisplacementBodyFraction = 0.65`.

Both defaults are EA_LAB-derived preregistration values, not source claims. Invalid thresholds, malformed OHLC, zero-body rejection, insufficient wick ratio, weak displacement, or missing breakout all return `NONE`.
## Chassis boundary

The scaffold is explicitly `STACK_SINGLE / CONF_DISTANCE`. Strategy code returns `EntrySignal` only. It owns no order placement, pending-order lifecycle, position management, recovery, hedge, exit, money-management, or risk-cage logic. Shared defaults are not changed by this V0.

## Acceptance and direct consumer

Source acceptance requires deterministic unit/adversarial fixtures, input/fingerprint regeneration, MetaEditor compile, applicable template tests, `tpl_regression` after core changes, no existing Boss regression, an exact clean frozen head, and separate read-only acceptance-grade GPT Scrutiny under the current canonical review contract. The author job cannot self-approve.

### Historical review-policy note

The original B20 canary recorded: "The current ChatGPT/Codex/GPT-Hermes family cannot satisfy that final core review. The currently available Gemini route is not qualified for this core task and its API billing/free-tier authority is unresolved." That wording is retained only as historical provenance. It is superseded by current `AGENTS.md` and `docs/research/EA_MILESTONE_SCRUTINY_CHECKLIST.md`: procedural/evidentiary independence controls, provider qualification cannot block core review, and the required final path is separate exact-head read-only GPT Scrutiny after all deterministic, adversarial, compile, fixture, and regression gates.

## B22 bounded-author result — 2026-09-19

The bounded author implemented exactly the reserved B22 identity on base `5c85eba937968f80e558f11d583be85a2969c41e`, without committing or pushing. Normalized historical-B20-to-current-B22 comparison passed for the wrapper, entry, nine-case fixture bytes, Stack/Confirm scaffold, defaults, closed-bar shifts, signal logic, invalid-input behavior, provenance sections and the two registry rows. All 244 base registry rows remain identical apart from generated `Inputs.mqh:<line>` citation movement; B20 GoldTimeBomb and B21 GridFibo deterministic preservation gates passed. InputSurface, LockedConstants, registry/linkage, wrapper, parameter-surface and scaffold/adversarial cages passed. Direct MetaEditor compilation from the unique external evidence staging tree produced `0 errors / 0 warnings` for both `Boss_22_WickDisplacement` and `WickDisplacement_Test`.

The author did not start MT5 or a Strategy Tester. The nine-case runtime fixture, adjacent Boss regression, staged normal hooks, clean committed/frozen-head verification and separate acceptance-grade GPT Scrutiny remain Control Tower gates. Structural `tpl_regression.ps1 -ValidateOnly` could not certify the uncommitted author worktree: baseline mode correctly refused the already-diverged current B20/B21 source identity, while adjacent-control mode requires its control to be the immediate parent of a committed HEAD. Neither refusal is a runtime PASS or a strategy failure.

Only after reviewed source integration may the next consumer preregister one fixed-config MT5 Model1 / 1 Minute OHLC MAIN+BWD screen. That screen asks only whether the independent signal has a measurable pulse in its preregistered home. No optimization, HOLDOUT use, Candidate, DEMO/LIVE, deployment, trading, or risk/default authority follows from this V0.
