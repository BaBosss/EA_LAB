# B16 USDJPY/H1 Exit Concentration Diagnostic

Status: `PASS_READ_ONLY / RETAIN_CURRENT_EXITS_FROZEN / RESEARCH_ONLY`  
Base SHA: `c0e9f5123883e67e7692c702efeefd00318ca781`  
MT5 rerun: `NONE`; Optimization: `NONE`; HOLDOUT: `UNSPENT`.

## Executive answer

The previously attractive aggregate results from disabling B16 USDJPY/H1 Single TP or Basket TP are not representative of the accepted parent-like participation pattern. Both exit-off children concentrate most profit into one or a few extremely long-lived cycles and leave whole calendar years with zero closures. The direct consumer is therefore closed as `RETAIN_CURRENT_EXITS_FROZEN`: current exits remain the research reference before any future prospective entry/robustness work. This diagnostic does not authorize an exit redesign, parameter search, strategy default, HOLDOUT use, Candidate, DEMO or LIVE transition.

## Evidence boundary

Exact accepted parent aggregate metrics are available from canonical `parent_contexts.json`: MAIN PF 1.53 / net +252.53 / 275 trades / EqDD 3.85%; BWD PF 1.11 / net +44.10 / 267 trades / EqDD 2.40%. The corresponding parent raw report bytes are not tracked in the current canonical evidence package, so this diagnostic does **not** fabricate parent cycle statistics.

For behavior-only comparison, canonical `DEEP_SPACING_EQUAL` is used as `MATCHED_OUTPUT_CONTROL`. Its raw reports reproduce the parent's headline MAIN and BWD net/PF/trades/EqDD exactly. That makes it a useful holding/concentration proxy, but it is explicitly **not asserted to be byte-identical parent evidence**. Exact raw canonical reports are used for `SINGLETP_OFF` and `BASKETTP_OFF`.

## Holding and concentration

| Variant / window | Trades | Cycles | Active-time share | Median hold | P90 hold | Max hold | Top-1 GP share | Top-3 GP share |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| matched-output control MAIN | 275 | 239 | 21.7% | 40.7 min | 1.30 d | 85.6 d | 12.5% | 30.2% |
| matched-output control BWD | 267 | 243 | 23.9% | 43.7 min | 1.78 d | 71.2 d | 16.6% | 38.4% |
| SingleTP off MAIN | 4 | 2 | 73.9% | 539.3 d | 958.5 d | 1063.3 d | 82.0% | 100.0% |
| SingleTP off BWD | 15 | 5 | 73.4% | 67.6 d | 529.7 d | 835.4 d | 69.9% | 91.4% |
| BasketTP off MAIN | 10 | 9 | 74.2% | 44.3 min | 216.9 d | 1083.1 d | 97.8% | 98.5% |
| BasketTP off BWD | 21 | 17 | 72.0% | 53.7 min | 5.6 d | 1036.8 d | 98.6% | 98.8% |

The control closes hundreds of trades/cycles with median holds measured in minutes and P90 holds under two days. In contrast, SingleTP-off MAIN has only 2 cycles across the entire three-year MAIN window, with a maximum hold above 1,063 days; 82.0% of gross profit comes from one cycle. BasketTP-off MAIN is even more concentrated economically: one cycle supplies 97.8% of gross profit, with a maximum hold above 1,083 days.

## Calendar participation

- `SINGLETP_OFF`: 2024 has 0 closures; 2021 has 0 closures. MAIN 2025 is only 1 closed trade / 1 cycle producing +227.06. BWD 2022 is only 2 trades / 1 cycle producing +247.19.
- `BASKETTP_OFF`: 2024 and 2021 again have 0 closures. MAIN 2025 is 2 trades / 1 cycle producing +466.79. BWD 2022 is 5 trades / 1 cycle producing +448.39.
- The matched-output control remains broadly active: MAIN yearly trades 104 / 90 / 81; BWD 98 / 76 / 93.

These are descriptive evidence, not a newly invented sample-floor rule. The causal issue here is concentration and holding-path distortion, not a numeric Grade mapping.

## PF handling

`SINGLETP_OFF` MAIN and `BASKETTP_OFF` MAIN contain zero gross loss. MT5 displays PF as `0.00`, but the mathematically meaningful state is `UNDEFINED_NO_GROSS_LOSS`; this diagnostic preserves the raw MT5 field separately and does not interpret it as PF=0.

## Interpretation and routing

Disabling either exit can improve aggregate net/DD, but the mechanism changes the realized strategy into a handful of long-lived episodes whose profits dominate the full window. That is not evidence that the existing exits are harmful in a reusable, distributed sense. It is evidence that they control holding duration and profit concentration materially.

Decision: `RETAIN_CURRENT_EXITS_FROZEN / EXIT_OFF_AGGREGATE_IMPROVEMENTS_CONCENTRATED_LONG_HOLD_PATHS`. Do not open SingleTP/BasketTP redesign from these ablations alone. A later exit redesign would require a separate prospective strategy-semantic hypothesis with an explicit direct consumer and owner boundary as applicable.

The next B16 continuation may investigate a different prospective consumer on the stronger-participation USDJPY/H1 parent, but any optimization lattice/range must be independently preregistered for the BUY direction and this Symbol×TF. Numeric ranges from the GBPUSD/H4 SELL H05 search are not universal authority and must not be copied automatically.

## Artifacts

- `diagnostic.json` — machine-readable evidence and exact aggregate parent reference.
- `diagnostic_summary.csv` — cycle/holding/concentration table.
- `year_participation.csv` — calendar participation.
- `diagnostic_acceptance.json` — deterministic scope/authority result.
- `source_reconciliation.txt` — parent/raw/proxy provenance boundary.
- `artifacts.sha256` — package integrity.
