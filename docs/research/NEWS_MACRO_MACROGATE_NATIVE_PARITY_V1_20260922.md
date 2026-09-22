# News/Macro — MacroGate Native Parity V1 — 2026-09-22

Status: **TOOLING_COMPLETE / NATIVE_PARITY_BLOCKED_CORE_SEAM_REQUIRED / NO_PERFORMANCE**.

Authority: research/native-parity preparation only. This artifact does not authorize MT5, A/B performance, HOLDOUT, runtime activation, Monitor mutation, deployment, sizing, risk/default changes, or trading.

## Scope and ownership

Lane: `ct-news-macro-mg-native-parity-v1-20260922`.

This lane owns only:

- `tools/news_macro_lab/macrogate_native.py`
- `tools/news_macro_lab/tests/test_macrogate_native.py`
- this document.

The active Boss23 lane owns `ea_template/core`; this milestone deliberately does not modify MacroGate/LabCore/Inputs/Execution. Monitor paths are also separately owned and unchanged.

## Accepted upstream identity

The input is the already accepted compact causal MacroGate research replay:

- causal timeline SHA256: `44ed3c16451bf9d8e9066d1f552939c62d3c0bfcb1c9059613ad4150d963ed5f`
- causal manifest SHA256: `436baeeb45d1aba7d5176473dbc462963e43d1b31937e3fcbdf16ad76771d3e1`
- source intervals: 2,192
- upstream performance: `NOT_RUN`
- upstream `can_execute=false`
- probability: null.

The native tool also binds the exact accepted clock/core sources at the author base:

- `MacroGate_Core.mqh` SHA256 `80a71cb73a54bfcfaae49857c2d977f5a6e120e553428035178043dd5717de93`
- `LabCore.mqh` SHA256 `e4b89caf9c2ea725127fa7b34bdfc3484f242651f82aa7eb4850b7cb485e8301`
- historical broker-clock contract SHA256 `ce472070a96b970ea280aa672988bc8c05207b9ded9234c86b08e49703737a37`
- accepted P4B normalizer SHA256 `cad32322e70fed379dc1ee8e19755d8256b29828fd4ccc3ea022fde19b1a34dd`.

Any drift in those identities refuses the source-bound parity build instead of silently inheriting changed semantics.

## ThinkMarkets server-clock mapping

The accepted research clock is broker-lineage specific:

- stable standard-time server dates: UTC+2;
- stable DST server dates: UTC+3;
- U.S.-DST transition server dates (second Sunday in March, first Sunday in November): `UNKNOWN_DST_TRANSITION`;
- no guessed switch instant.

For every stable causal row, the tool converts UTC -> server time and verifies server time -> UTC round-trip exactly. Native candidate rows are written already in server time, so the proposed native candidate uses `_MG_OffsetHours=0`; it does not combine a date-varying conversion with the current constant input.

## Source-bound result

Actual run over 2020-01-01 .. 2026-01-01:

- causal intervals: **2,192**
- stable native rows: **2,180**
- round-trip clock checks: **2,180 / 2,180**
- UTC+2 rows: **758**
- UTC+3 rows: **1,422**
- transition/quarantine rows: **12**
- native candidate SHA256: `9a960be151838156c36efaa5075899e072ffe4ce2eb8700faff9191b637b9840`
- quarantine SHA256: `1578fd75476b414a501633e6a9d0b00623e034c5c4ac6637c7a484138179dd69`
- source-bound manifest SHA256: `4960ead105dc9f8c00f4fcc2b50ca7afb7b904137f98cb59ec74b6fb3bec95d6`.

The native CSV is a **candidate only**. It is not a qualified tester feed.

## Exact transition blocker

Current `MacroGate_Core.mqh` maps any unrecognized/UNKNOWN state to `MG_ST_UNKNOWN` and then skips that row during `MG_LoadRegime`:

`if(st == MG_ST_UNKNOWN) { skipped++; continue; }`

`MG_RowAsOf` then selects the most recent retained valid row `<= nowServer`. The self-gate sets `RowStaleMaxHours=168`.

Therefore simply omitting a transition row, or writing an `UNKNOWN` row that the current loader skips, does **not** quarantine the day. The preceding real state persists. At a 12:00 server-time probe on every transition date the retained row is only 33–34 hours old, so the 168-hour stale guard does not clear it.

All 12 accepted transition dates are therefore semantic mismatches against the clock contract, even where the prior and source label happen to have the same text.

A concrete action-level mismatch exists on **2024-11-03**:

- causal source row: `RISK_OFF` (triggering under the current default `_MG_TriggerRiskOff=true`);
- previous retained native row: `NEUTRAL` (non-triggering);
- current core would therefore expose a different gate behavior on that transition date.

This makes the blocker operational, not cosmetic.

## Required bounded core/test seam

A later core-owning milestone may implement only a separately reviewed seam. The intended behavior is:

1. distinguish the explicit token `UNKNOWN` from malformed/unrecognized state text;
2. malformed state remains rejected/skipped — it must not become a valid clear instruction;
3. explicit `UNKNOWN` is retained as a real timeline marker;
4. when the selected row is explicit `UNKNOWN`, MacroGate clears/inactivates its own gate for the quarantined interval, consistent with current missing/stale-data inactive behavior;
5. the exporter may place a provenance-labelled quarantine marker at the start of the known transition **server date**, without assigning a guessed DST switch instant or a fabricated macro state;
6. the next accepted non-transition causal row resumes normal state selection;
7. negative tests must prove no stale block/lot multiplier remains, malformed states still fail closed at load, rows remain ascending, and live/runtime behavior is unchanged unless the self-gate/test path is explicitly enabled.

The exact marker timestamp and end-of-quarantine semantics must be frozen prospectively in that core seam contract before implementation. This document does not silently choose them.

## Why segmentation is not accepted as a performance workaround

Splitting Strategy Tester runs around every DST transition would reset EA/tester path state. For grids, baskets, recovery, hedges, persistent halts or open positions, that can change later outcomes. Post-hoc aggregation of such segments is not equivalent to one continuous MAIN/BWD engine path. It may be useful for a parser fixture, but it is not accepted here as an unbiased performance substitute.

Likewise, writing `NEUTRAL` or `RISK_ON` on transition dates would fabricate a macro state and is prohibited.

## Output and next gate

Current machine conclusion:

- `native_parity_qualified=false`
- blocker: `CORE_SEAM_REQUIRED_UNKNOWN_TRANSITION_CANNOT_CLEAR_GATE`
- `can_execute=false`
- performance: `NOT_RUN`
- HOLDOUT: unspent.

After this tooling milestone is independently accepted, the next consumer is a **separate core/test-seam milestone** only after current `ea_template/core` ownership is released. That milestone must compile/test parity only. A later A/B contract must still separately freeze parent/Home/config, MAIN/BWD, policy, placebo seeds and metrics before any MT5 performance execution.
