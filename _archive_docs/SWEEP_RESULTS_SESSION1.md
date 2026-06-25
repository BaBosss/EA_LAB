# Session 1 Results

## Summary

| Symbol | IS PF | IS DD% | OOS PF | OOS DD% | OOS T | M4 PF | Verdict |
|--------|-------|--------|--------|---------|-------|-------|---------|
| US30   | N/A   | N/A    | N/A    | N/A     | N/A   | N/A   | UNAVAILABLE |
| NAS100 | N/A   | N/A    | N/A    | N/A     | N/A   | N/A   | UNAVAILABLE |

**Session 1 Verdict: BLOCKED — No symbols available for testing.**

---

## Execution Log

### US30

| Step | Status | Detail |
|------|--------|--------|
| Step 1 — Optimize (IS) | FAIL | `US30`: history check timeout, no history data from 2020.01.01 to 2023.12.31 |
| Alt 1: DJ30 | FAIL | Symbol not exist |
| Alt 2: DOW30 | FAIL | Symbol not exist |
| Alt 3: US30.cash | FAIL | Symbol not exist |
| Step 2 — Select robust params | SKIPPED | No XML produced |
| Step 3 — Write locked .set | SKIPPED | No robust params |
| Step 4 — IS backtest | SKIPPED | — |
| Step 5 — OOS backtest | SKIPPED | — |
| Step 6 — Model=4 | SKIPPED | — |

### NAS100

| Step | Status | Detail |
|------|--------|--------|
| Step 1 — Optimize (IS) | FAIL | `NAS100`: history synchronization error, no XML produced |
| Alt 1: US100 | FAIL | Symbol not exist |
| Alt 2: NAS100.cash | FAIL | Symbol not exist |
| Step 2 — Select robust params | SKIPPED | No XML produced |
| Step 3 — Write locked .set | SKIPPED | No robust params |
| Step 4 — IS backtest | SKIPPED | — |
| Step 5 — OOS backtest | SKIPPED | — |
| Step 6 — Model=4 | SKIPPED | — |

---

## Root Cause

The MT5 terminal connected to **ThinkMarkets-Live** does not have historical data available for US30 or NAS100 index symbols. 

- EURUSD works fine (history available from 2017, full backtest completed previously)
- US30: history check timed out during download
- NAS100: history synchronization error
- All alternate symbol names (DJ30, DOW30, US30.cash, US100, NAS100.cash) were rejected as non-existent

This indicates these index CFDs are either:
1. Not subscribed to in this broker account
2. Not available in this broker's offering
3. Require manual subscription/download in MT5 Market Watch before they can be tested

---

## Recommendation

Before running Sessions 2 and 3, one of the following must be done:

1. **Subscribe to index symbols in MT5:** Open Market Watch → right-click → Show All → find US30/NAS100 equivalents → right-click → Subscribe → then download history (Edit → History Center or Ctrl+H)
2. **Use a different broker terminal** that offers US30 and NAS100 CFDs with historical data
3. **Substitute with available symbols** — check what index/commodity symbols are available in this terminal (e.g., check if XAU/USD, GBPUSD, or other instruments work)

---

## Files Generated

| File | Size | Notes |
|------|------|-------|
| `D:\EA_LAB\_mt5_auto\optimizations\OPT_US30_IS.xml` | 2.5 KB | Empty (header only, 0 passes) — deleted |
| `D:\EA_LAB\_mt5_auto\optimizations\OPT_NAS100_IS.xml` | — | Not produced |
| `D:\EA_LAB\_mt5_auto\EARUN_US30_candidate.set` | — | Not created |
| `D:\EA_LAB\_mt5_auto\EARUN_NAS100_candidate.set` | — | Not created |

---

*Session 1 completed: 2026-06-20*
*Symbols tested: US30 (4 names), NAS100 (3 names)*
*Result: 0/2 symbols available. Sessions 2-3 blocked until resolution.*
