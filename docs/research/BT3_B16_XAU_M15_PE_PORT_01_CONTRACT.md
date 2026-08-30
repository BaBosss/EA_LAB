# BT3 — B16 XAUUSD/M15 Position-Engine Portability Ablation 01 — Preregistration

Status: `PREREGISTERED / READY_TO_EXECUTE`
Hypothesis ID: `HYP-B16-XAU-M15-PE-PORT-01`
Authority: `RESEARCH_ONLY`
Canonical base SHA: `4ad1b15f26644723f2954a1416f3662b58c0b565`
Runtime: `MT5-lane2 / D:\Meta 5b`
HOLDOUT: `UNSPENT / FORBIDDEN`
Optimization: `NONE`

## Question

Does the accepted B16 XAUUSD/M15 H02 pulse retain an independently positive entry-only component when adverse adds are disabled, or does the entry-only failure already observed prospectively on XAUUSD/H4 repeat at a different timeframe on the same symbol?

This is a new prospective mechanism-portability test. It is not H04, tuning, optimization, redesign, or a rerun of H03/BT1.

## Frozen one-change intervention

- EA: `EALabTpl\Boss_16_KangarooGrid`
- Symbol/TF: `XAUUSD / M15`
- Parent full tester set SHA256: `7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782`
- Child set SHA256: `07670fdd3da9f7b3e0006c6035bd25422257223403d24b885e7176ae5812d736`
- Exactly one parameter change: `_16_MaxOrdersPerSide: 10 -> 1`.
- `_16_OverlapMinUsd` remains `5.0`; every other tester input remains frozen; surface `FULL 173/173`.

## Accepted parent evidence reused — no rerun

| Window | PF | trades | net | EqDD% | report SHA256 | INI SHA256 |
|---|---:|---:|---:|---:|---|---|
| MAIN 2023-2025 | 1.25 | 1577 | +2643.64 | 11.88 | `2aeb5f6c0de9a517b3a49c2ca62b75e87938edc457e7adac2317a0a7b5afb728` | `f62ba42ee7c18c858d22e79a61aa495dc84e3fa54bcbc306fb9c0f620cc2c12a` |
| BWD 2020-2022 | 1.10 | 1463 | +1002.69 | 14.86 | `27149f0074c81e70b086a31dbf722eafa2920c281f05adaaf9022dd8a8bc2644` | `ff9fa92026e8b6057503c1d2e0744cf7beb02c5a6a64802641f812d14ec8e84f` |

Both parent cells are accepted H02 evidence on Meta5b, exact XAUUSD/M15, Model 1, optimization 0, USD 10000, leverage 1:100.

## Evidence basis and direct consumer

Accepted H03/BT1 established that XAUUSD/H4 profitability is position-engine dependent/unknown and that MaxOrders `10 -> 1` leaves MAIN positive but makes BWD net negative. XAUUSD/M15 is a separate accepted dual-window pulse with much higher trade participation.

This same-symbol/different-timeframe ablation directly tests whether the H4 entry-only failure repeats on M15. It is intentionally one-dimensional and does not use any BT2 unpushed result as canonical evidence.

Direct consumer: decide whether future B16 XAU research should treat position-engine dependence as symbol-wide or timeframe-conditional before any new mechanism hypothesis is designed.

## Frozen execution and falsifier

Exactly two new cells on Meta5b, sequential MAIN then BWD: MAIN `2023.01.01..2025.12.31`; BWD `2020.01.01..2022.12.31`. Model 1; optimization 0; Forward 0; deposit USD 10000; leverage 1:100; no HOLDOUT; no other parameter change.

Mechanical acceptance requires exact build/config/symbol/TF/dates, fresh reports, leverage match, explicit truncation/full-window eligibility, and same-install lineage. A losing strategy is evidence, not a mechanical failure.

Primary statement: **the B16 XAUUSD/M15 entry-only component remains positive in both frozen windows**.

Falsified if mechanically accepted full-window net profit is `<= 0` in either MAIN or BWD. If both remain positive, the statement is not falsified; no threshold beyond sign is introduced.

Interpretation must compare prospectively with the accepted XAUUSD/H4 ablation without turning two timeframe observations into a universal B16 verdict. Preserve any contradictory yearly evidence.

Report level: `R2 MECHANISM` with parent/child table, yearly participation, equity/DD views, EVIDENCE / INTERPRETATION / DECISION separation.

Authority ceiling: no H04 naming/unlock, optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, trading, risk/default change, KINT resolution, or Grade authority.
