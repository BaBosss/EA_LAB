# PARAM_INACTIVE_AUDIT.md — ORDER-191(c)

**Report only. No code changes proposed. No `.mqh` file touched.**

Source: `docs/PARAM_REGISTRY.csv` (184 rows, `powershell -File scripts\param_registry_check.ps1`
confirms 170 identifiers / 184 rows / CLEAN as of this audit). Override-pair data is taken from
the generated `docs/PARAM_LINKAGE.md` → "Override pairs" section (11 pairs, produced by
`scripts/gen_param_linkage.ps1`).

Three findings, in the order the task asked for them:

1. Every row whose `classification` is not exactly `ACTIVE`.
2. Every row whose `classification_note` or `active_when` says it is inert / has no effect /
   is dead at the default profile on some build.
3. Every override pair from PARAM_LINKAGE.md, flagged **SILENT** when the losing input's own
   row carries no note warning the reader it can be overridden.

---

## 1. Rows not classified exactly `ACTIVE` (7 of 184)

| parameter | classification | inert on | why it matters |
|---|---|---|---|
| `StackMode[LAB_ENTRY_16]` | INACTIVE | build 16, always, any `.set` value | Kangaroo (`Kangaroo_OnTick`) unconditionally short-circuits `LabCore.mqh`'s `OnTick` before `Stack_DecideAdd` is ever called. **Wasted optimize dimension**: a user who sweeps `StackMode[LAB_ENTRY_16]` on build 16 is burning optimizer passes on a dial with literally zero effect on any output. |
| `StackConfirm[LAB_ENTRY_16]` | INACTIVE | build 16, always, any `.set` value | Same root cause as above (`Stack_ConfirmOK` never reached). Same wasted-dimension risk. |
| `_17_UseStructLevels` | OVERRIDE | n/a (this is the *winner* row, not inert itself) | Declared here because it is the row that silently supersedes `SLMode` and `ExitMode` on build 17 — see §3. |
| `_2_BasketTP_ATRmult` | OVERRIDE | n/a (winner) | Supersedes `_2_BasketTP_Money` whenever set > 0 — see §3. |
| `_2_SuppressLegTP` | OVERRIDE | n/a (winner) | Blanks whatever `ExitMode` would have set as the per-leg TP whenever true — see §3. |
| `_33_SL_MaxATRmult` | OVERRIDE | n/a (winner) | Supersedes `_33_SL_MaxPips` whenever set > 0 — see §3. |
| `RC_MaxLevelsOverride` | OVERRIDE | n/a (winner) | Supersedes `ProtectLevel`'s implicit `RC_MaxRecSteps` depth cap whenever set > 0 — see §3. |

No row in the registry is classified `COMPATIBILITY` (the registry's own legend note confirms
none exist in this codebase).

---

## 2. Rows whose own note/active_when declares inert / no-effect / dead-at-default (13 rows)

This is a stricter list than "has a conditional `active_when`" — nearly every one of the 184
rows is conditional on *something* (that is normal branching, not a finding). The rows below are
the ones where the registry author specifically flagged a **build-level dead zone**: either
permanently unreachable regardless of `.set`, or dead under every build's *default* profile even
though the enum/switch it belongs to is live elsewhere.

| parameter | inert on (builds) | why it matters |
|---|---|---|
| `FirstLotMode` | build 16 | Kangaroo owns entry-16's lot law; `MM_ConfigValid` prints an OnInit WARN but does not fail the attach. **Misleading dial**: a user could sweep 41/42/43 on a build-16 chart believing they're changing sizing when nothing changes. |
| `TradeDir` | builds 14, 16, 17, 18 | Those 4 builds encode direction their own way (`_14_Direction`/`_16_Direction`/`_18_Direction`, or bidirectional-by-design on 17). **Wasted optimize dimension** on 4 of 8 builds. |
| `TrendFilter` | builds 14, 15, 16, 17, 18 | Only wired into 3 of 8 entry modules (11/12/13). **Wasted optimize dimension** on the majority (5/8) of builds. |
| `StackConfirm[LAB_ENTRY_12]` | build 12, at the compiled default (`StackMode=90`) | Reachable only via `.set` override to 91/92. Dead at every out-of-the-box run. |
| `StackConfirm[LAB_ENTRY_15]` | build 15, at the compiled default (`StackMode=90`) | Same shape as build 12. |
| `StackMode[LAB_ENTRY_16]` | build 16, unconditionally | *(also listed in §1 as INACTIVE — permanently dead, not just default-dead.)* |
| `StackConfirm[LAB_ENTRY_16]` | build 16, unconditionally | *(also listed in §1 as INACTIVE.)* |
| `StackConfirm[LAB_ENTRY_17]` | build 17, at the compiled default (`StackMode=90`) | Dead at default **and** overriding it breaks the documented naked-probe guard (ORDER-082 guard G4) — this is a case where "fixing" the dead dial is actively dangerous, not just a free optimize win. |
| `_9_PA_MinBodyRatio` | all 8 builds, at every compiled default | Never a default anywhere in the codebase; only reachable via `.set StackConfirm=4`. **Wasted dimension unless the user specifically knows to flip StackConfirm first** — easy to sweep this and get a flat response surface for the wrong reason (the gate, not the value, is closed). |
| `_17_DivergTrail` | build 17, at the global default `ExitMode=EXIT_ATR_TP(22)` | Only live when a `.set` sets `ExitMode=23` (EXIT_TRAIL) for build 17. **Misleading dial**: a user could tune the RSI-divergence trail-tighten input while running the default ATR-TP exit and see zero effect, and reasonably (but wrongly) conclude the feature doesn't work. |
| `_2_MaxHoldBars` | build 16, specifically | `LabCore.mqh` prints an explicit WARN if this is set nonzero on build 16, but does not block the attach. **Safety-adjacent dial that looks tunable but is a no-op on exactly the build (grid/martingale) where a vertical-barrier time-stop matters most** — see Top Findings below. |
| `_43_LotPerAnchor` | FirstLotMode 41/42 (inert), **and** build 16 unconditionally (Kangaroo lot law) | Two independent inert conditions stacked on one input: normal mode-gating (expected) plus an unconditional build-16 dead zone (less expected, easy to miss). |
| `_43_BalanceAnchor` | same as `_43_LotPerAnchor` | Paired with the row above; same double-inert shape. |

---

## 3. Override pairs — silent flag (11 pairs; source: `docs/PARAM_LINKAGE.md` → Override pairs)

**SILENT** = the *losing* input's own `classification_note` contains none of `overridden` /
`superseded` / `OVERRIDDEN` — i.e. nothing on that row itself warns the reader it can be beaten.
A reader would have to already know to go read the *winner's* row.

| winner beats loser | silent? | why it matters |
|---|---|---|
| `_17_UseStructLevels` beats `SLMode` | **no** — `SLMode`'s own note says "overridden per-order by `_17_UseStructLevels`..." | Self-documented; low risk. |
| `_17_UseStructLevels` beats `ExitMode` | **yes** — `ExitMode`'s `classification_note` is empty | See Top Findings #1 below. |
| `_2_BasketTP_ATRmult` beats `_2_BasketTP_Money` | **yes** — `_2_BasketTP_Money`'s note is empty | A user could optimize a fixed-$ basket TP that a nonzero ATR-mult sibling has already superseded. |
| `_2_BasketTP_BalPct` beats `_2_BasketTP_ATRmult` | **yes** — `_2_BasketTP_ATRmult`'s own note only talks about *it* overriding `_2_BasketTP_Money`; it never mentions that `_2_BasketTP_BalPct` can override *it* | Subtlest case in the file: the note exists, reads authoritative, and is simply incomplete — it documents this row as an always-winner when it is also sometimes a loser. |
| `_2_BasketTP_BalPct` beats `_2_BasketTP_Money` | **yes** — empty note | Third dial in the same 3-way basket-TP precedence chain (`BalPct > ATRmult > Money`); see Top Findings #2. |
| `_2_SuppressLegTP` beats `ExitMode` | **yes** — same empty `ExitMode` note as above | Second, independent way `ExitMode` gets silently blanked (see Top Findings #1). |
| `_32_SL_BalPct` beats `_32_SL_Money` | **yes** — `_32_SL_Money`'s note discusses the unrelated `SLMode`/`SL_MONEY(32)` split-brain, never mentions `_32_SL_BalPct` | Safety-relevant: a basket money-stop a user believes is live (via `_32_SL_Money`) can be silently replaced by a %-of-balance version. |
| `_33_SL_MaxATRmult` beats `_33_SL_MaxPips` | **no** — `_33_SL_MaxPips`'s own note says "superseded by `_33_SL_MaxATRmult`..." | Self-documented; low risk. |
| `_57_DynCloseBalPct` beats `_57_DynCloseBase` | **yes** — empty note | Optimize-dimension risk only (dynamic-close base $ target); not safety-critical. |
| `_8_DDRefBalPct` beats `_8_DDRefMoney` | **yes** — empty note | Feeds an ENGINE-EDGE (RecoveryMode 82) escalation formula — see Top Findings #3. |
| `RC_MaxLevelsOverride` beats `ProtectLevel` | **yes** — `ProtectLevel`'s note is empty | Safety-relevant: `ProtectLevel` is the one-dropdown safety-cage preset (TIGHT/NORMAL/LOOSE) that bakes in a depth cap (2/3/5 steps); a user picking a preset for its depth cap can have that specific component of the preset silently overridden with zero indication on the `ProtectLevel` row itself. |

**9 of 11 pairs (82%) are silent** — the registry's override relationships are almost always
documented one-directionally, from the winner's side only.

---

## Top 3 findings most worth a human's attention

1. **`ExitMode` is silently beaten twice, and its own row carries zero warning.** Both
   `_17_UseStructLevels` (build 17, when a valid structural SL exists) and `_2_SuppressLegTP`
   (any build, whenever true) can blank whatever `ExitMode` would have produced as the per-order
   TP — yet `ExitMode`'s `classification_note` is empty. `ExitMode` is one of the most-tuned
   dials in the whole registry (it's the enum that selects fixed-pip vs ATR-TP vs trailing vs
   run-trend); anyone optimizing it on build 17 or with `_2_SuppressLegTP=true` could burn an
   entire sweep on a dimension two other switches have already made irrelevant, with nothing in
   the doc pointing them at the reason.

2. **The basket-TP input has a 3-way silent precedence chain, and the two lower rungs both look
   independently tunable.** `_2_BasketTP_BalPct > _2_BasketTP_ATRmult > _2_BasketTP_Money`
   (highest precedence wins) — but `_2_BasketTP_ATRmult`'s note only advertises that *it* beats
   `_2_BasketTP_Money`; nothing on any of the three rows says `_2_BasketTP_BalPct` (a %-of-balance,
   cent/USD-portable target added later) can silently override both. A user who inherited an
   older `.set` tuned on `_2_BasketTP_Money`/`_2_BasketTP_ATRmult` and later adopted the newer
   `_2_BasketTP_BalPct` convention (per-account portability) would see their basket-TP tuning
   silently stop mattering with no error, no note, and no log line pointing at why.

3. **`_2_MaxHoldBars` (the vertical-barrier time-stop, ORDER-125) is a safety-adjacent dial that
   is a total no-op on exactly the build where a time-stop is most needed.** It has zero effect
   on build 16 (Kangaroo/martingale grid) — `LabCore.mqh` prints an explicit WARN but does not
   fail the attach or the backtest. Grid/martingale baskets are precisely the case where "force
   the basket closed after N bars regardless of P&L" earns its keep as a backstop; a user who
   believes they've capped Kangaroo's maximum hold time by setting this input has, in fact, capped
   nothing, and the only evidence is a log line at OnInit that is easy to miss in a batch run.

*(Honorable mention: `RC_MaxLevelsOverride` silently overriding `ProtectLevel`'s baked-in depth
cap with no note on `ProtectLevel`'s own row is the closest thing to a **safety**-relevant silent
override in the set — worth a look if `ProtectLevel`'s TIGHT/NORMAL/LOOSE presets are ever relied
on for their depth-cap component specifically, e.g. when reasoning about worst-case-loss math per
the CLAUDE.md ENGINE-EDGE cage rules.)*
