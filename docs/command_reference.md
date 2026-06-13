# Telegram Command Reference

These commands are scaffolded for a local placeholder router. Live trading,
real-account connection, live deployment, and automatic lot-size changes are not
implemented.

## Commands

`/status`

Show bot status, current queue count, and whether the configured MT5 path exists.

`/list_ea`

List EA projects inside `ea_projects/`.

`/run_backtest <project> <symbol> <timeframe>`

Create a backtest placeholder job and call `scripts/run_backtest.ps1`. The
requested broker/server/account are context only. Backtest environment
validation is broker-agnostic and should capture `broker_server`,
`account_currency`, `leverage`, `symbol_name`, `symbol_path`, `tick_value`,
`tick_size`, `contract_size`, `profit_currency`, `margin_currency`, and
`tester_profit_valid`.

Fail only with `ENVIRONMENT_ACCOUNTING_FAIL` when MT5 creates closed deals at
different open/close prices but `DEAL_PROFIT` is zero for all or nearly all
closed deals and final balance/equity does not change. Use
`BROKER_CONTEXT_DIFFERENT_FROM_USER_DEFAULT` as warning only for differences
from user preferences.

`/import_manual_run <project> <run_id>`

Create a placeholder job for `MANUAL_MT5_RUN_IMPORT`. Telegram file upload is
not implemented yet, so use the PowerShell script directly for the actual
import:

```powershell
.\scripts\import_manual_run.ps1 `
  -Project XAU_HT_M15_H1_Pilot01 `
  -RunId run_001 `
  -ReportPath C:\path\to\manual_report.html `
  -TradeListPath C:\path\to\manual_trade_list.csv `
  -SetPath C:\path\to\baseline.set `
  -Symbol XAUUSD `
  -Timeframe M15 `
  -StartDate 2025-01-01 `
  -EndDate 2026-05-29
```

The script creates `ea_projects/<project>/backtest/manual_runs/<run_id>/`,
copies `report.html`, optional `trade_list.csv`, optional `set_used.set`,
creates `run_context.yaml`, and writes `import_summary.txt`. It does not launch
MT5, modify EA source, optimize, or change strategy logic.

Manual import is valid when the imported MT5 Strategy Tester artifacts come
from the operator's working manual MT5 environment and show normal balance/P&L
changes. The importer sets `tester_profit_valid=true` only when the trade list
proves non-zero closed trade P/L and changing balance; otherwise it keeps the
run imported but marks `tester_profit_valid=false`.

`/collect_reports <project> <run_id> <baseline|risk_cap_validation|optimization|oos>`

Create a placeholder job for `AUTO_MT5_REPORT_COLLECTOR` and call
`scripts/collect_mt5_reports.ps1`. This command does not launch MT5 and does
not run optimization. It copies artifacts from configured MT5 report/log/common
folders into the appropriate project run folder.

PowerShell example:

```powershell
.\scripts\collect_mt5_reports.ps1 `
  -Project "Gold SMC continuous" `
  -RunId run_003_counter_validation `
  -RunType risk_cap_validation `
  -Symbol XAUUSD `
  -Timeframe H1 `
  -Notes "Manual MT5 run after diagnostic counter patch"
```

Optional explicit source example:

```powershell
.\scripts\collect_mt5_reports.ps1 `
  -Project "Gold SMC continuous" `
  -RunId pass_1_raw `
  -RunType optimization `
  -SourceFolder "C:\Users\patip\Documents\MT5 exports" `
  -Force
```

Destination rules:

- `baseline` and `risk_cap_validation`: `ea_projects/<project>/backtest/manual_runs/<run_id>/`
- `optimization`: `ea_projects/<project>/optimization/raw_results/<run_id>/`
- `oos`: `ea_projects/<project>/optimization/oos/<run_id>/`

The script creates `import_summary.txt` and `run_context.yaml`. It never deletes
original MT5 files. It refuses to reuse an existing run folder unless `-Force`
is provided.

`/latest_report <project>`

Return the newest files under `ea_projects/<project>/reports/latest/`.

`/latest_opt <project>`

Return the newest optimization raw-results folder under
`ea_projects/<project>/optimization/raw_results/`.

`/run_opt <project> <macro|micro|robustness>`

Create an optimization placeholder job and call `scripts/run_optimization.ps1`.

`/optimize EA_NAME SYMBOL TIMEFRAME PRESET`

Start optimization plan design for an EA. This is a scaffolded command specification only.

`/analyze_opt EA_NAME REPORT_PATH`

Analyze an MT5 optimization CSV/report path and validate required result columns.

`/select_candidates EA_NAME TOP=5`

Select the top N candidate sets from analyzed optimization results.

`/run_oos EA_NAME SET_IDS=...`

Run or register out-of-sample validation for PRELIMINARY candidate sets.

`/compare_sets EA_NAME SET_IDS=...`

Compare selected candidate sets side by side by score, PF, DD, RF, OOS status, and cluster.

`/send_to_robustness EA_NAME SET_IDS=...`

Prepare a robustness handoff package for APPROVED OOS-passed candidate sets only.
PRELIMINARY candidates must be refused by default.

`/export <project>`

Call `scripts/export_reports.ps1` and collect available artifacts into
`ea_projects/<project>/reports/latest/`.

`/summary <project>`

Call `scripts/summarize_results.py` for `reports/latest/` and write `summary.json`.

`/queue`

Show queued, running, completed, failed, and stop-requested jobs known to the bot process.

`/stop <job_id>`

Mark a job as stop requested. This is a safe placeholder and does not kill external processes yet.

`/approve <job_id>`

Record a placeholder approval for a future manual gate. There is no deployment command.

`/report latest`

Return the newest `summary.json` path under `ea_projects/*/reports/latest/`.
