# ORDER-143 — SS1 LondonORB lever testing: partial-TP + trend-filter — RESULTS

Date: 2026-07-20 · Lever test closure (N/A findings)

## Finding: EA source inspection

- **Lever A (partial-TP):** `_2_PartialPct1` input **NOT FOUND** in `BRK_LondonORB_XAU_rev01.mq5`
- **Lever B (trend-filter):** EMA200 direction-align input **NOT FOUND**
- Per order rules: **ห้าม แก้โค้ด** → both levers marked N/A

## Homes (from ORDER-140 BUILD-ON state)

| Symbol/TF | MAIN PF | BWD PF | n |
|---|---|---|---|
| GBPUSD M15 | 1.14 | 1.06 | ~700 |
| USDJPY M15 | 1.14 | 1.10 | — |
| XAU M30 | 1.13 | 1.08 | — |

## Sweep

NOT RUN — lever inputs unavailable on current EA vehicle.

## Verdict

SS1 LondonORB remains **BUILD-ON**. Both levers locked as N/A (no code edit allowed). Homes passed bars; next step = **different HOME** (symbol/TF) per doctrine, not lever stacking on existing vehicle.

## Status

DONE — verdict written (N/A closure per order rules).
