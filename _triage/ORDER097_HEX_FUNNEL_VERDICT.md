# ORDER-097 HexaGrid funnel — coarse sweep verdict (Opus lead, 2026-07-14)

Prior baseline (2026-07-11, default config, both windows, XAU H1 Model 1):
recent PF 0.97 / BWD PF 0.88, DD 57-65%, 9-12k trades. Not yet a verdict (0 lever swept,
1 symbol, 1 TF per VERDICT GATE). This batch runs the funnel the order prescribed:
"sweep spacing×SL×system-count → both-regime → ถ้าโผล่ PF>1 ค่อย Model-4".

## (A) Spacing × SL coarse grid, both windows, XAU H1 Model 1, MaxLevels=10 (default)
`_mt5_auto/order097_hex_funnel_results.csv`

| config | spacing×ATR | SL×ATR | MAIN PF | BWD PF | trades |
|---|---|---|---|---|---|
| S3_SL20 | 3 | 20 | 0.93 | 0.84 | 11355/8347 |
| S5_SL20 | 5 | 20 | 0.87 | 0.80 | 11144/8192 |
| S3_SL30 | 3 | 30 | (run failed — 22KB stub report, re-run needed) | 0.82 | -/8349 |

**Widening spacing 2-3x and SL 1.7-2.5x barely moved trade count (11-11.4k vs baseline 12.4k)
and PF stayed <1.0 in every cell tested.** The overtrading hypothesis (spacing too tight) does
NOT explain the failure — even much wider spacing keeps PF under 1.

## (B) Flat-lot entry-edge probe (doctrine 5 mandatory check) — MaxLevels=1, baseline spacing/SL
| window | PF | Trades | Win% |
|---|---|---|---|
| MAIN 2023-26 | **0.67** | 16831 | 22.01 |
| BWD 2020-22 | **0.15** | 6 | 33.33 |

With grid escalation OFF (single order per basket, no martingale averaging), the combined
6-system signal has **no edge — PF<1 in both windows**, and win rate collapses from the
grid-averaged ~57-60% down to 22-33% raw. The martingale multiplier (1.33x, cap 10) in the
default config was doing the work of averaging bad entries into occasional basket wins, not
compensating for a real signal.

## VERDICT (lead)
**Flat-lot PF<1 in BOTH windows = STRUCTURAL-death criterion** per CLAUDE.md's explicit
auto-kill list (flat-lot PF<1 / uncapped-ruin / cracked — any one kills regardless of tune).
Combined with spacing/SL widening not rescuing PF, **the default 6-system-combined XAU H1
engine is STRUCTURAL DEAD as shipped — grid/martingale escalation was masking a losing base
signal, not amplifying a winning one.**

**Scope of this kill — narrower than the whole HexaGrid concept:**
The flat-lot probe tested all 6 systems firing together (S1-S6 all enabled). It does NOT tell
us whether any INDIVIDUAL system (e.g. S1 trend-EMA14-H1, or S4 DI-flip/ADX regime) has its own
edge in isolation — that lever (system-count / per-system flat-lot) was in-scope per the order
but not yet run. Per VERDICT GATE + BUILD-ON doctrine: **tag PARKED-VERIFY(user)**, not a full
concept kill — user spec'd 6 independent systems deliberately and may have hand-tested some of
them separately before. Flagging per doctrine ("ตัวที่ idea ดีแต่ไม่ผ่าน ห้ามปล่อยของดีตายเงียบ").

**Recommendation:** do NOT continue tuning the combined-6-system grid math (spacing/SL) — that
funnel branch is closed, it does not fix a no-edge base signal. If pursuing further: isolate
each S1-S6 flat-lot individually (6 more runs, cheap) to find which (if any) subsystem carries
real edge before deciding whether HexaGrid is worth rebuilding around just that one system.
Re-run S3_SL30 MAIN (failed this batch, stub report) if that combo specifically is wanted later
— does not change the verdict (BWD leg of the same combo still failed at 0.82).

**Not run (deferred, cheap if wanted):** per-system flat-lot isolation (S1..S6 individually,
MaxLevels=1, both windows = 12 runs) — would directly answer "which system, if any, has edge."
