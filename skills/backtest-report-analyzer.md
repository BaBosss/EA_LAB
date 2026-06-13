# backtest-report-analyzer

Purpose: read MT5 backtest artifacts and summarize what is actually present.

Inputs:
- MT5 HTML report
- Trade list or CSV export
- Equity curve file or screenshot
- Run context
- Imported manual run folder:
  `ea_projects/<project>/backtest/manual_runs/<run_id>/`

Manual run import:
- Accept `MANUAL_MT5_RUN_IMPORT` artifacts when EA_LAB automated launch context
  differs from the operator's working manual MT5 Strategy Tester environment.
- Read `report.html`, optional `trade_list.csv`, and `run_context.yaml`.
- Treat `tester_profit_valid: true` in `run_context.yaml` as evidence that the
  imported artifacts showed changing balance and non-zero closed trade P/L.
- If `tester_profit_valid: false`, analyze structure and signal metrics only,
  but block optimization readiness until valid accounting artifacts are supplied.

Outputs:
- Summary JSON
- Notes on missing artifacts
- Follow-up questions for deeper review

Safety:
- Do not invent metrics.
- If a metric is not present in source files, mark it missing.
