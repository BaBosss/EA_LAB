# Boss11–16 H02 Literal Portability Results

Status: **CLOSED / EVIDENCE COMPLETE / NON-AUTHORITATIVE SCREEN**

Preregistration commit: `40b38ffafc5be5e34abc5070a57fa6049ed5b3b4`
Build/source evidence lineage: `cf32ba8d32a8292e8f7b5ad2ef766e3442b20125`

H02 kept every H01 configuration byte-for-byte unchanged and tested literal portability only. No parameter rescaling, optimization, HOLDOUT use, candidate promotion, risk/default change, or DEMO/LIVE authority was granted.

## Matrix

- Boss families: 11, 12, 13, 15, 16
- Symbols: `XAUUSD`, `EURUSD`, `GBPUSD`, `USDJPY`
- Timeframes: `M15`, `H1`, `H4`
- Windows: MAIN `2023.01.01–2025.12.31`; BWD `2020.01.01–2022.12.31`
- Tester: Model 1, deposit 10,000 USD, leverage 1:100
- H01 `XAUUSD/H1` reused: 10 cells
- H02 newly executed: 110 cells
- Combined screen: 120 cells = 60 MAIN/BWD pairs
- H02 integrity: 110 unique / 110 expected / 0 missing / 0 extra / 0 duplicate
- H02 mechanical rows: 106 PASS, 4 `SUSPECT_TRUNCATED`
- Pair matrix: 58 full-window eligible, 2 ineligible pairs

Full 60-pair matrix: `docs/factory/BOSS11_16_H02_PAIR_MATRIX.csv` (SHA256 `d938d9d7b154226387cde12ef4571d179df00ee1c1a2dace2f626f873c944c47`).
## Dual-window positive PF pulses

These are **screening signals only**, not accepted candidates or optimizer seeds.

| Boss | Symbol / TF | MAIN PF / trades | BWD PF / trades | MAIN EqDD | BWD EqDD |
|---|---|---:|---:|---:|---:|
| B16 | XAUUSD H4 | 4.08 / 79 | 1.44 / 148 | 6.27% | 8.29% |
| B16 | USDJPY H1 | 1.53 / 275 | 1.11 / 267 | 3.85% | 2.40% |
| B16 | XAUUSD M15 | 1.25 / 1577 | 1.10 / 1463 | 11.88% | 14.86% |
| B15 | GBPUSD H4 | 1.10 / 214 | 1.07 / 218 | 0.97% | 1.83% |
| B13 | XAUUSD M15 | 1.06 / 3929 | 1.02 / 3300 | 6.32% | 3.72% |
| B13 | GBPUSD H4 | 1.05 / 256 | 1.02 / 272 | 1.63% | 2.65% |

B16/XAUUSD/H4 is the strongest literal-portability pulse by minimum-window PF, but MAIN participation is only 79 trades. It therefore warrants a new bounded hypothesis/confirmation contract rather than automatic promotion or optimization.

## Fail-closed / exceptional cells

B11 M15 produced four `SUSPECT_TRUNCATED` cells: XAUUSD MAIN/BWD and GBPUSD MAIN/BWD. Each stopped well before the requested window end while equity drawdown was approximately 25%; their metrics are not full-window evidence. Those two MAIN/BWD pairs are the only ineligible pairs in the 60-pair screen.

B13/USDJPY/H1 MAIN completed the full window with zero trades (`PF=0.00`). The report therefore did not record a usable leverage field; the runner's no-trade path skipped the leverage assertion. The BWD counterpart did trade and verified 1:100. This pair is mechanically complete but has no positive portability signal.
## Harness events resolved during execution

One Meta5c terminal residue correctly caused an `already running` refusal before a new cell started; the stale process was verified by exact command line and terminated. One later B13/GBPUSD/H1 MAIN attempt coincided with a Meta5c LiveUpdate/restart: the tester log showed the test finished successfully but the first runner process checked for the report before the restarted terminal flushed it. After update completion the exact cell was rerun and accepted normally. Neither event changed strategy evidence or left an expected H02 cell missing.

## Interpretation / next boundary

Literal cross-symbol portability is not broad. B11 and B12 show no dual-window positive PF pair in this screen. B13 and B15 each show narrow positive pulses. B16 shows three positive pairs and the strongest pulse at XAUUSD/H4.

The next valid step is a **new preregistered confirmation/mechanism hypothesis** for selected pulses. It must define its own consumer and acceptance bar before new evidence is generated. H02 itself grants no optimization ranges, rescaling, HOLDOUT use, selection/promotion, or deployment authority.

HOLDOUT 2026H1: **UNSPENT**. Optimization: **NONE**. Candidate promotion: **NONE**. DEMO/LIVE: **NONE**.