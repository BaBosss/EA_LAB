# INSTRUMENT SCALE REFERENCE — which params transfer across symbols, which silently break

**Owner:** this file. **Written 2026-07-23** (user request during ORDER-142/150: *"คอนเฟิร์ม distance pip สำหรับ btc, eth, xauusd, eurusd ให้ทีมันเป็น ATR หรือ fixed pip ไม่งั้นค่าเพี้ยน"*).

**Read this before reusing ANY .set across instrument classes.** Two live examples of this exact bug, both caught the same week:
- **ORDER-150 (2026-07-23):** XAU-tuned `_01_RoundStep=25` ($ per level) reused on EURUSD → 11 trades in 3 years instead of ~40. $25 is ~1.1% of gold's price but ~2400% of EURUSD's. The first PF (1.41) was a starved-sample artifact; correctly rescaled it was 1.08.
- **ORDER-036 / skill catalog:** same class of failure repeatedly — "a symbol killed under a mis-scaled $-axis is a scale artifact, not a dead edge."

---

## 1. The mechanical facts (certain — from `Stack_PipSize()` + broker symbol specs)

The chassis defines pip in `ea_template/core/Stack.mqh`:
```
digits == 3 or 5  ->  pip = point * 10
otherwise         ->  pip = point          <-- BTC, ETH, XAU all land here
```

| Symbol | Digits | Point | **Pip (chassis)** | "100 pips" actually means |
|---|---|---|---|---|
| **BTCUSD** | 2 | 0.01 | **0.01** (pip = point) | **$1.00** |
| **ETHUSD** | 2 | 0.01 | **0.01** (pip = point) | **$1.00** |
| **XAUUSD** | 2 | 0.01 | **0.01** (pip = point) | **$1.00** |
| **EURUSD** | 5 | 0.00001 | **0.0001** (pip = 10×point) | **0.0100 = 100 real FX pips** |

⚠️ **The trap:** "100 pips" on EURUSD is a normal-sized move (~1.4 × daily ATR). "100 pips" on BTC is **$1.00** — which is ~0.2% of one day's range. The same number is a sane distance on one and effectively zero on the other. **Pip-denominated params do NOT transfer between FX and non-FX.**

Note BTC/ETH/XAU behave the *same* as each other here (all digits=2), so pip params transfer between THOSE three by unit — but still not by *magnitude*, because their ATRs differ ~25× (see §3).

---

## 2. Param audit — portable vs non-portable

### ✅ PORTABLE (ATR-relative / unitless — safe to transfer across all 4 symbols)
| Param | Meaning |
|---|---|
| `_9_StepATRmult` | grid step = mult × Signal-ATR |
| `_14_DistAtrMult` | arm/grid distance = mult × Signal-ATR |
| `_16_AtrMultFirst4` / `_16_AtrMultAfter` | Kangaroo spacing |
| `_22_TP_ATRmult` | TP = mult × Risk-ATR |
| `_33_SL_ATRmult` | SL = mult × Risk-ATR |
| `_33_SL_MaxATRmult` | portable SL ceiling |
| `_2_BasketTP_ATRmult` | basket TP scaled by ATR × lots |
| `_01_SpacingAtrMult` (AdaptGridMC) | grid spacing = 0.3 × ATR(D1,30) |
| all `*Pct` / `*Mult` / ratio inputs | unitless by construction |

### ⚠️ NON-PORTABLE — price-denominated (must be rescaled per symbol)
| Param | Default | Why it breaks |
|---|---|---|
| `_9_StepPoints` | 300 | 300 pts = **$3.00** on BTC/ETH/XAU, **30 pips** on EURUSD. On BTC that is 0.6% of daily ATR — a degenerate grid. Only used when `_9_StepUseATR=false` (default true ✅) |
| `_9_StepMinPips` | 0 (off ✅) | floor under the ATR step |
| `_14_MinDistPips` | 20 | = $0.20 on BTC/XAU, = 20 FX pips on EURUSD |
| `_16_MinDistPips` | 150 | = $1.50 on XAU (intended), meaningless on BTC (ATR ~$517) |
| `_16_MaxSlPips` | 9000 | = $90 on XAU (intended) |
| `_21_TP_Pip` | 500 | = $5 on metals/crypto, 50 pips on EURUSD |
| `_31_SL_Pip` | 1000 | = $10 on metals/crypto, 100 pips on EURUSD |
| `_33_SL_MaxPips` | 0 (off ✅) | prefer `_33_SL_MaxATRmult` instead |
| `_23_TrailStart` / `_23_TrailStep` | 300 / 100 | pip-denominated trail |
| `_01_RoundStep` (SweepReversal) | 25 | **the ORDER-150 bug** — $ per round-number level |
| `_01_ZoneLo` / `_01_ZoneHi` (AdaptGridMC) | — | absolute prices, symbol-specific **and** time-specific by design (regenerate, never copy) |

### ⚠️ NON-PORTABLE — money-denominated (breaks across cent/USD *accounts*, not just symbols)
`_2_BasketTP_Money` · `_32_SL_Money` · `_57_DynCloseBase` · `_8_DDRefMoney` · `_41_FixedLot`

**Fixed 2026-07-23** — every one now has a percent-of-balance twin (default 0 = off, legacy behavior untouched): `_2_BasketTP_BalPct` · `_32_SL_BalPct` · `_57_DynCloseBalPct` · `_8_DDRefBalPct`, plus `FirstLotMode=FIRSTLOT_BALANCE (43)` with `_43_LotPerAnchor`/`_43_BalanceAnchor` for lot. See §4.

---

## 3. Magnitude reference — why unit-correctness is not enough

Measured D1 ATR(30, RMA), from the real exports used in ORDER-142 (`_mt5_auto/*_Daily_*.csv`, window ending 2022-12-30):

| Symbol | D1 ATR(30) | as % of price | "300 points" as % of that ATR |
|---|---|---|---|
| **BTCUSD** | **516.66** (@ px 16,556) | 3.1% | $3.00 = **0.6%** ← degenerate |
| **ETHUSD** | **58.33** (@ px 1,190) | 4.9% | $3.00 = **5.1%** ← very tight |
| XAUUSD | *measure before use* (order of $20–35 in the 2023-25 era) | ~1.2% | $3.00 ≈ 10–15% |
| EURUSD | *measure before use* (order of 0.006–0.008) | ~0.7% | 0.0030 ≈ 40% |

⚠️ The XAU/EURUSD ATR figures above are **order-of-magnitude placeholders, not measurements** — measure them for your actual window before sizing anything off them. The BTC/ETH numbers ARE measured (they came out of `adaptgrid_mc_zone.ps1`).

**Takeaway:** BTC's ATR is ~9× ETH's and ~25× gold's. Even a correctly-unit-converted pip value is still wrong by an order of magnitude between them. **Use the ATR-relative params (§2 ✅ list) and this whole problem disappears** — that is the entire reason they exist.

---

## 4. How to make a money param portable (added 2026-07-23)

**The rule: express money as a RATIO, never as an absolute figure.**

A bare `25` means **$25** on a USD account but **$0.25** on a cent account — the same .set silently trades a 100× different target. A ratio is unitless, so it means the same thing on both **and** auto-scales as the account grows (no re-tuning after a deposit).

| Instead of | Use | Notes |
|---|---|---|
| `_2_BasketTP_Money = 25` | `_2_BasketTP_BalPct = 0.25` | 0.25% of balance. Precedence: BalPct > ATRmult > Money |
| `_32_SL_Money = 100` | `_32_SL_BalPct = 1.0` | BalPct wins when > 0 |
| `_57_DynCloseBase = 10` | `_57_DynCloseBalPct = 0.1` | growth divisor already unitless |
| `_8_DDRefMoney = 100` | `_8_DDRefBalPct = 1.0` | keeps the escalation curve constant as the account grows |
| `_41_FixedLot = 0.01` | `FirstLotMode = 43` + `_43_LotPerAnchor=0.01`, `_43_BalanceAnchor=1000` | "0.01 lot per 1000 of account currency" |

**Setting the balance anchor on a cent account:** put it in whatever units *your terminal displays*. Both balance and anchor are in account currency, so the ratio cancels out:
- USD account showing `1000` → anchor `1000`
- Cent account showing `100000` (= $1,000) → anchor `100000`

Both then scale identically. **Do not try to "convert to USD" — that reintroduces the bug.**

### Which lot mode to pick
| Mode | Use when | Caveat |
|---|---|---|
| `FIRSTLOT_FIXED` (41) | pinning a lot for a controlled A/B or a backtest probe | never scales |
| `FIRSTLOT_RISK` (42) | EA has a real per-order SL | **silently falls back to `_41_FixedLot` when there is no SL** — which is why grid/basket EAs never scaled |
| `FIRSTLOT_BALANCE` (43) | want linear scale-up with account size, no SL required | scales with balance, so it scales *into* a losing streak too — the RC cage (`RC_MaxLot`, KillDD, deposit load) still bounds it |

⚠️ **Backtest note:** balance-scaled sizing compounds within a run, so PF stays comparable but **DD% and net are no longer lot-scale invariant**. For screening keep `FIRSTLOT_FIXED` (per the skill's "screen at reduced size" rule); switch to 43 for the deploy .set.

---

## 5. Checklist before reusing a .set on a new symbol
1. Are the distance params on the ✅ ATR list? → transfers, go.
2. Any param from the ⚠️ pip/points list? → recompute: `new = old × (old_pip / new_pip)`, then sanity-check it against the new symbol's ATR (§3).
3. Any absolute money param? → switch to its `*BalPct` twin (§4).
4. Crossing FX ↔ non-FX (digits 5 ↔ 2)? → **every** pip param changes meaning by 10×, on top of the ATR difference.
5. Re-run and **check trade count first**. A collapsed count (ORDER-150: 40 → 11) is the tell that a distance param is mis-scaled — *before* you read the PF, which will be a meaningless small-sample number.
