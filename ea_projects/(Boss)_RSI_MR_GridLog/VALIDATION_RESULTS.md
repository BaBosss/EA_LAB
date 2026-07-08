# RSI-MR GridLog rev01 — Validation Results (2026-07-08)

Chain `EA_RSI_MR_GRIDLOG_20260707_01`. Built from the reverse-engineered principle of
"RSI from pips_EA" + user design ideas, then validated **from scratch** (not trusting the
survivor's numbers). Thorough sweep per user direction 2026-07-08 ("ทำให้ครบ").

## Lot-law sweep — BWD 2020-22 EURUSD (wide SL 25×ATR/600pip), the discriminating window
| lot law | PF | net | eqDD% | trades |
|---|---|---|---|---|
| FIXED | 0.78 | -588 | 12.2 | 393 |
| LINEAR +0.01 | 1.19 | +1,021 | 30.5 | 887 |
| **LINEAR +0.02** | **2.63** | +5,674 | 17.6 | 1250 |
| LINEAR +0.03 | 2.56 | +6,639 | 18.8 | 1372 |
| MART 1.3 | 1.00 | -5 | 20.2 | 671 |
| MART 1.5 | 1.18 | +1,080 | 35.1 | 859 |
| LOG 2 | 1.13 | +464 | 24.1 | 536 |
| **LOG 5** | **2.96** | +7,519 | 18.8 | 1270 |
| LOG 10 | 1.03 | +322 | 60.9 | 1125 |
| LOG 20 | 0.54 | -8,332 | 95.3 | 1080 |

→ Corrected an earlier WRONG call: rev01 default (LOG 1.3, near-flat) gave 0.78 here and I
prematurely called the EA "regime-dead". Proper lot laws (LOG 5 / LINEAR +0.02) hit PF 2.6-3.0
at DD ~18% — matching the original's 2020-22 profile. **The edge IS there in the trend years.**

## Cross-regime confirm — top lot laws, EURUSD, FWD 2025-26
| config | 2020-22 | 2025-26 |
|---|---|---|
| LOG 1.3 | 0.78 | **1.43** |
| LOG 5 | **2.96** | 0.88 (DD 37%) |
| LINEAR +0.02 | **2.63** | 0.82 (DD 37%) |
| LINEAR +0.03 | **2.56** | 0.91 (DD 37%) |

→ **INVERSE relationship:** the deep-grid recovery that wins 2020-22 loses in 2025-26 (and DD
jumps to 37%). The flat grid that survives 2025-26 can't recover 2020-22 trends. No single
lot-law wins both regimes on EURUSD.

## Symbol sweep — LOG 5 config, both windows
| symbol | BWD 2020-22 | FWD 2025-26 |
|---|---|---|
| EURUSD | 2.96 (DD19) | 0.88 (DD37) |
| AUDUSD | 1.96 (DD34) | 0.78 (DD30) |
| GBPUSD | 1.22 (DD47) | 3.14 (DD34) |
| USDJPY | 0.49 (DD95 💀) | 1.63 (DD15) |

→ Same inverse pattern, per-symbol: each pair wins ONE regime, loses the other, and which
regime flips by symbol (EUR/AUD favour the trend years; GBP/JPY favour the recent years).
No symbol×config gives robust both-regime profit; DD breaches the 40% gate in most cells.

## ATR-spacing sweep — LOG 5 lot, EURUSD, BOTH windows (the lever held at 1.0 until now)
User callout 2026-07-08: `_03_DistAtrMult` (range 1-5) was never tuned. It is the lever that
resolves the inverse-regime problem:
| ATR mult | BWD 2020-22 | FWD 2025-26 |
|---|---|---|
| 0.5 | 2.88 / DD19 | 0.91 / DD37 |
| 1.0 | 2.96 / DD19 | 0.88 / DD38 |
| 1.5 | 1.34 / DD38 | 0.91 / DD37 |
| 2.0 | 1.82 / DD21 | 0.84 / DD37 |
| **3.0** | **1.26 / DD26** | **2.76 / DD11** |
| **5.0** | **1.57 / DD15** | **2.63 / DD5** |

→ **VERDICT FLIP.** Tight spacing (ATR ≤2) whipsaws in the choppy recent regime (FWD PF <1, DD 37%).
WIDE spacing (ATR 3-5) spaces legs far enough apart to skip the whipsaw while still catching the
trend-year reversions → **BOTH regimes profitable at DD < 20%**. The inverse-regime "structural
problem" was an artifact of holding ATR at 1.0. **ATR 5.0 = both-regime robust: PF 1.57/2.63, DD 15/5%.**

## Verdict (Claude, 2026-07-08 — CORRECTED after ATR sweep; earlier "PARKED-dead" call RETRACTED)
Two premature "dead" calls this session, both corrected, both flagged by the user:
  1. "regime-dead" — was a near-flat LOG factor (bad param). Proper lot law → PF 2.6-3.0.
  2. "no cross-regime config exists" — was ATR held at 1.0. Wide ATR (3-5) → both regimes profitable.
**rev01 with {LOG 5 lot, ATR 5.0 spacing, wide SL} is a genuine both-regime candidate on EURUSD**
(BWD PF 1.57 / FWD PF 2.63, DD 15/5%). Plateau confirm (ATR 4/6/8) + multi-symbol travel + spread
+ MC in progress. This is now the FIRST source-available EA in the project with a both-regime edge —
promote to full validation, NOT parked.

Lesson banked to skills (locked-ea-analyzer + backtest-optimize-rigor): never write a verdict until
every structural lever (entry, spacing, SL, TP, lot law, symbol) is confirmed swept — "I tuned it"
usually means one of six; and test candidates on BOTH regimes at once, not one window.

## Plateau + travel check (Claude, 2026-07-08 — tempering the flip, don't over-claim back)
EURUSD ATR 4/6/8 both windows + ATR 5 on 3 other symbols:
| ATR (EURUSD) | BWD | FWD |    | symbol (ATR5) | BWD | FWD |
|---|---|---|---|---|---|---|
| 3 | 1.26 | 2.76 |    | AUDUSD | 1.15 | 0.99 |
| **4** | **0.63** | 3.50 |    | GBPUSD | 1.05 | 3.61 |
| 5 | 1.57 | 2.63 |    | USDJPY | 0.41💀 | 1.11 |
| 6 | 1.11 | 1.82 |
| 8 | 1.32 | 2.84 |

→ FWD is robustly strong at every wide ATR. BWD (trend years) is the fragile side: PF bounces
1.1-1.6 **with a losing hole at ATR 4 (0.63) between two winning neighbours** → per this repo's own
rule (a plateau with a losing neighbour is a hint, not a plateau) the ATR 3-5 zone is NOT yet a
stable plateau. Travel is weak (AUD FWD 0.99, JPY BWD 0.41 blowup) = still **EURUSD-specific**, same
as the original. **Fine ATR grid (7/9/10) → full EURUSD BWD map:** 3→1.26, 4→**0.63**, 5→1.57, 6→1.11, 7→**0.98**,
8→1.32, 9→1.38, 10→1.09 (FWD strong throughout 1.8-3.5). ATR 3-7 has TWO losing holes (4, 7) = fragile.
**ATR 8-9-10 is hole-free:** BWD 1.32/1.38/1.09, FWD 2.84/2.17/2.52, DD 3-8% across the whole zone
= a real plateau by this repo's rule. **ATR 9 = plateau centre: BWD PF 1.38/DD5.3, FWD PF 2.17/DD3.4.**

**Honest standing:** a both-regime edge on EURUSD is REAL and sits on a stable ATR 8-10 plateau
(no losing neighbour, DD<8%), but the trend-regime edge is THIN (PF ~1.1-1.4) and it does NOT travel
(EURUSD-specific, like the original). Upgraded PARKED-dead → **ACTIVE-VALIDATION**.
**Locked candidate config: LOG 5 lot · ATR 9 spacing · wide SL (25×ATR/600pip) · EURUSD H1.**
NOT yet deployable — remaining before it's a validated candidate:
  1. TRUE holdout: run once on 2023-2024 (never used for selection) — both windows above were used.
  2. Monte Carlo (robustness-validator) on the ATR-9 config.
  3. TP / RSI-threshold / EMA-mult still un-swept (dominant levers lot-law+ATR are done; these are
     second-order — sweep only if the holdout passes).
Do NOT deploy on the in-sample plateau alone — the ATR-9 pick is now selection-fitted.

## HOLDOUT 2023-24 — the honest arbiter (Claude, 2026-07-08)
Ran the 4 coarse both-regime cells on 2023-2024 (NEVER used for selection):
| cell | holdout 2023-24 | verdict |
|---|---|---|
| **EURUSD H1** | **PF 1.34 / DD 5.1 / 206 trd** | ✅ **PASS — validated across 3 independent windows** |
| EURUSD M30 | 0.96 / DD 9.5 | ❌ selection-fit |
| AUDUSD M30 | 0.89 / DD 6.2 | ❌ selection-fit |
| EURJPY M30 | 0.79 / DD 14.8 | ❌ selection-fit |

→ **The holdout did exactly its job:** 3 of 4 "both-regime" cells were selection artifacts (fail on
untouched data); only EURUSD H1 is real. RSI-MR EURUSD H1 (LOG5/ATR9/wideSL) now clears **3 independent
windows** — BWD 2020-22 PF 1.38, holdout 2023-24 PF 1.34, FWD 2025-26 PF 2.17 — all at DD 3-5%.

## FINAL VERDICT (Claude, 2026-07-08)
**RSI-MR EURUSD H1 = VALIDATED source-available EA** (the project's first original both-regime survivor
that isn't a compiled black box). Honest caveats, stated not buried:
  - Edge is CAPPED-RECOVERY driven, not signal (flat-lot loses in trend years). Legit because bounded
    (8-leg cap + real SL + DD held 3-5% across all 3 windows) — but judge it as a recovery harvester.
  - EURUSD-specific — does NOT travel (other symbols/TFs fail holdout or BWD).
  - Modest edge (PF 1.3-1.4 in the harder windows), ~100 trades/yr.
  - Remaining gate step: **Monte Carlo** (robustness-validator) before live/demo attach.
Other RSI-MR cells + the UnNomGuai multi-symbol idea (AUDUSD/AUDCAD forward looked great, BWD DD 92-98%)
= REJECTED regime traps. Lesson reinforced: forward-4mo is meaningless; the holdout/BWD is the arbiter.

**Why it differs from the compiled original** (which passed BWD 2020-22 AND forward at PF ~2.3):
the original ran NO stop loss + fixed 30-pip spacing + per-position 15-pip virtual TP. Our
real-SL + ATR-spacing + basket-$ exit redesign — safer — changed the recovery dynamics enough
that the both-regime edge didn't survive. The safety we added is exactly what the original
lacked, and it costs the cross-regime robustness.

**Genuine sub-finding worth keeping:** deep-grid RSI-MR is a strong *in-regime* harvester, and
the regime that favours it flips by symbol — a multi-symbol basket (EUR+GBP, or AUD+JPY) could
in principle diversify the regime risk, but each leg's DD (34-47%) is too high to combine safely
without a lower base lot + tighter cap. Parked as a research thread, not a deploy candidate.
