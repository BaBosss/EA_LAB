from pathlib import Path
import json, hashlib

ROOT = Path(__file__).resolve().parents[4]
RUN = Path(__file__).resolve().parent
DOC = ROOT / 'docs/research/B16_USDJPY_H1_EXIT_CONCENTRATION_DIAGNOSTIC.md'
d = json.loads((RUN / 'diagnostic.json').read_text())
rows = {(r['variant'], r['window']): r for r in d['rows']}
accept = {
    'schema': 'ea-lab-b16-usdjpy-exitdiag-acceptance/1',
    'overall': 'PASS_READ_ONLY',
    'base_sha': 'c0e9f5123883e67e7692c702efeefd00318ca781',
    'mt5_rerun': False, 'optimization': 'NONE', 'holdout': 'UNSPENT',
    'parent_exact_aggregate_present': True, 'parent_raw_available': False,
    'matched_output_behavior_control': 'DEEP_SPACING_EQUAL',
    'raw_variants_analyzed': ['SINGLETP_OFF', 'BASKETTP_OFF', 'DEEP_SPACING_EQUAL'],
    'decision': 'RETAIN_CURRENT_EXITS_FROZEN',
    'classification': 'EXIT_OFF_AGGREGATE_IMPROVEMENTS_CONCENTRATED_LONG_HOLD_PATHS',
    'authority': 'RESEARCH_ONLY_NO_STRATEGY_DEFAULT_OR_OPTIMIZATION_OR_HOLDOUT_AUTHORITY'
}
(RUN / 'diagnostic_acceptance.json').write_text(json.dumps(accept, indent=2, sort_keys=True) + '\n')
parser = ROOT / 'scripts/research/b16_h03/parse_h02_reports.py'
recon = '\n'.join([
    'B16 USDJPY/H1 EXIT CONCENTRATION SOURCE RECONCILIATION',
    'base_sha=c0e9f5123883e67e7692c702efeefd00318ca781',
    f'parser_sha256={hashlib.sha256(parser.read_bytes()).hexdigest()}',
    'parent_owner=factory/runs/b16_characterization_20260830/aggregate/parent_contexts.json',
    'parent_main_report_sha=45ac54affa7635cf350ba69492102d58557d54373424d802a3e2b57cdc562c64',
    'parent_bwd_report_sha=745cb0a465fbcb1b864e3e117e4ac1ce3de698606b100eb514adb110739a1893',
    'parent_raw_tracked_in_current_package=false',
    'behavior_control=DEEP_SPACING_EQUAL',
    'behavior_control_reason=canonical R2 plus direct parse reproduce parent headline net/PF/trades/EqDD in both windows; behavior metrics are proxy-only and not byte-identity claims',
    'SINGLETP_OFF_raw=canonical_tracked',
    'BASKETTP_OFF_raw=canonical_tracked',
    'MT5_RERUN=false', 'HOLDOUT=UNSPENT', 'OPTIMIZATION=NONE', 'RESULT=PASS_READ_ONLY'
]) + '\n'
(RUN / 'source_reconciliation.txt').write_text(recon)

m = rows[('MATCHED_OUTPUT_CONTROL', 'MAIN')]
b = rows[('MATCHED_OUTPUT_CONTROL', 'BWD')]
sm = rows[('SINGLETP_OFF', 'MAIN')]
sb = rows[('SINGLETP_OFF', 'BWD')]
bm = rows[('BASKETTP_OFF', 'MAIN')]
bb = rows[('BASKETTP_OFF', 'BWD')]
def minutes(days): return days * 24 * 60
report = f'''# B16 USDJPY/H1 Exit Concentration Diagnostic

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
| matched-output control MAIN | {m['trades']} | {m['cycles']} | {m['active_time_share']*100:.1f}% | {minutes(m['duration_p50_days']):.1f} min | {m['duration_p90_days']:.2f} d | {m['duration_max_days']:.1f} d | {m['top1_gp_share']*100:.1f}% | {m['top3_gp_share']*100:.1f}% |
| matched-output control BWD | {b['trades']} | {b['cycles']} | {b['active_time_share']*100:.1f}% | {minutes(b['duration_p50_days']):.1f} min | {b['duration_p90_days']:.2f} d | {b['duration_max_days']:.1f} d | {b['top1_gp_share']*100:.1f}% | {b['top3_gp_share']*100:.1f}% |
| SingleTP off MAIN | {sm['trades']} | {sm['cycles']} | {sm['active_time_share']*100:.1f}% | {sm['duration_p50_days']:.1f} d | {sm['duration_p90_days']:.1f} d | {sm['duration_max_days']:.1f} d | {sm['top1_gp_share']*100:.1f}% | {sm['top3_gp_share']*100:.1f}% |
| SingleTP off BWD | {sb['trades']} | {sb['cycles']} | {sb['active_time_share']*100:.1f}% | {sb['duration_p50_days']:.1f} d | {sb['duration_p90_days']:.1f} d | {sb['duration_max_days']:.1f} d | {sb['top1_gp_share']*100:.1f}% | {sb['top3_gp_share']*100:.1f}% |
'''
report += f'''| BasketTP off MAIN | {bm['trades']} | {bm['cycles']} | {bm['active_time_share']*100:.1f}% | {minutes(bm['duration_p50_days']):.1f} min | {bm['duration_p90_days']:.1f} d | {bm['duration_max_days']:.1f} d | {bm['top1_gp_share']*100:.1f}% | {bm['top3_gp_share']*100:.1f}% |
| BasketTP off BWD | {bb['trades']} | {bb['cycles']} | {bb['active_time_share']*100:.1f}% | {minutes(bb['duration_p50_days']):.1f} min | {bb['duration_p90_days']:.1f} d | {bb['duration_max_days']:.1f} d | {bb['top1_gp_share']*100:.1f}% | {bb['top3_gp_share']*100:.1f}% |

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
'''
report += '''
Decision: `RETAIN_CURRENT_EXITS_FROZEN / EXIT_OFF_AGGREGATE_IMPROVEMENTS_CONCENTRATED_LONG_HOLD_PATHS`. Do not open SingleTP/BasketTP redesign from these ablations alone. A later exit redesign would require a separate prospective strategy-semantic hypothesis with an explicit direct consumer and owner boundary as applicable.

The next B16 continuation may investigate a different prospective consumer on the stronger-participation USDJPY/H1 parent, but any optimization lattice/range must be independently preregistered for the BUY direction and this Symbol×TF. Numeric ranges from the GBPUSD/H4 SELL H05 search are not universal authority and must not be copied automatically.

## Artifacts

- `diagnostic.json` — machine-readable evidence and exact aggregate parent reference.
- `diagnostic_summary.csv` — cycle/holding/concentration table.
- `year_participation.csv` — calendar participation.
- `diagnostic_acceptance.json` — deterministic scope/authority result.
- `source_reconciliation.txt` — parent/raw/proxy provenance boundary.
- `artifacts.sha256` — package integrity.
'''
DOC.write_text(report, encoding='utf-8')
files = sorted(p for p in RUN.rglob('*') if p.is_file() and p.name != 'artifacts.sha256')
lines = []
for pth in files:
    digest = hashlib.sha256(pth.read_bytes()).hexdigest()
    lines.append(f"{digest}  {pth.relative_to(RUN).as_posix()}")
(RUN / 'artifacts.sha256').write_text('\n'.join(lines) + '\n')
print(f'REPORT={DOC}')
print(f'MANIFEST_COUNT={len(lines)}')
