# ZABgoldpending — money-mode semantic probe — 2026-09-23

Status: `PREREGISTERED_NOT_RUN / SEMANTIC_DIAGNOSTIC_ONLY`.

This contract resolves only the activation/precedence question between `Risk_Percent` and `Fixed_Lot_Size`. It grants no performance, optimization, HOLDOUT, Candidate/Grade/KINT, deployment, runtime or LIVE authority.

## Frozen parent

- EX5 SHA256: `f75e6d11f298765521d0bbcb7ce37c0e2fdacec3136315dd48047ee2249c9c90`
- Home carrier: `XAUUSD M5`
- Model: `M1_M1_OHLC_RESEARCH`
- Semantic window: `2023-01-01..2023-03-31` (MAIN subwindow only)
- Tester deposit: `10000 USD`
- Tester leverage: `1:100`
- Owner value: `Risk_Percent = 1.0` (1%)
- All non-money inputs stay at the exact recovered defaults.

## Prospective A/B/C

| Variant | Risk_Percent | Fixed_Lot_Size | One change vs A |
|---|---:|---:|---|
| A_OWNER | 1.0 | 0.1 | none |
| B_FIXED_ONLY | 1.0 | 0.2 | Fixed_Lot_Size only |
| C_RISK_ONLY | 2.0 | 0.1 | Risk_Percent only |

Only the first entry is admissible evidence: timestamp, side and requested/executed volume, plus init/dependency errors. PF, net, DD, ending balance, win rate, exits and later trade path are forbidden evidence for this contract.

Comparability requires the same exact EX5, isolated MT5 build/account identity, symbol, M5, Model-1, window and all non-money inputs. First entry timestamp and side must match across variants.

Decision rule is fail-closed:

- **RISK mode active:** changing Fixed_Lot_Size alone does not change first-entry volume, while changing Risk_Percent alone does.
- **FIXED mode active:** changing Risk_Percent alone does not change first-entry volume, while changing Fixed_Lot_Size alone does.
- **UNKNOWN:** both axes change, neither changes, first signal differs, no first entry appears, or any init/dependency failure occurs.

No P/L or later trade result may be used to break a tie. HOLDOUT `2026H1` stays unspent; optimization remains unauthorized.