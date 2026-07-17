# ORDER-095 / #4 — Boss_14_GridLog EUR-cross symbol-expand verdict (Opus lead, 2026-07-17)

**Scope:** expand the GBPJPY-rescued Boss_14_GridLog grid chassis onto EUR/CHF-family ranger
crosses. Coarse both-window Model-4 sweep (`_14_DistAtrMult` ∈ {1.5,2.0,2.5} × `_2_BasketTP_Money`
∈ {150,250,400}, H4, base = `Boss14_GridLog_GBPJPY_ISpick.set`, GRID → Model-4 mandatory).

## Results

### EURCHF (magic 990201) — NO both-window home → PARKED-VERIFY(user)
- MAIN (2023-26): two isolated spikes only (d1.5/tp150=1.64, d1.5/tp400=1.18); rest <1.0.
- BWD (~2021-23, truncated — no 2020 data): **all 9 cells <1.0** (best 0.81).
- No plateau. Not structural (max DD 21.8%, one grid-collapse cell d2.0/tp400 PF0.34/-1570).
- Sets: `_mt5_auto/ab_sets/order095_eurchf/` · CSV: `_mt5_auto/order095_eurchf_sweep.csv`.

### EURGBP (magic 990202) — NO both-window home → PARKED-VERIFY(user)
- MAIN broadly <1.0; only d2.0/tp150=1.29 but n=8 + trade-count collapse (grid pathology, not edge).
- BWD (2021-23, truncated) all <1.0 (best 0.99).
- No plateau. Sets: `_mt5_auto/ab_sets/order095_eurgbp/` · CSV: `_mt5_auto/order095_eurgbp_sweep.csv`.

## Lead verdict
**PARKED both — Boss_14 grid does NOT expand to EUR-crosses at coarse 2-lever H4.** This is a
per-symbol fit miss, **NOT a concept kill** (Boss_14 lives at GBPJPY leg-8, demo). Confirms the
handoff lesson: grid/naked EAs are symbol-specific (GBPJPY/AUDJPY were the homes; EUR-crosses are not).

## Data blocker (remaining crosses NOT tested — user decision 2026-07-17: stop at EURCHF+EURGBP)
GBPCHF/NZDCAD/AUDNZD history starts 2022 → BWD would be ~1yr (no regime contrast, both-window
invalid). AUDCHF has no history at all. To validly test these, user must load 2020-2022 history
(MT5 History Center) for GBPCHF/NZDCAD/AUDNZD/AUDCHF first — same class as the MT4 history gap.
Until then these stay unopened, not parked-on-evidence.
