# EA_LAB Setup Guide

## 1. Install Python Packages

From `EA_LAB/scripts/` or the project root:

```powershell
python -m pip install PyYAML
```

## 2. Create Local Config

Copy the example config:

```powershell
Copy-Item .\scripts\config.example.yaml .\scripts\config.yaml
```

Edit `scripts/config.yaml` and fill in:

- `mt5_terminal_path`
- `mt5_data_path`
- `mt5_roaming_data_path`
- `mt5_tester_report_paths`
- `mt5_common_files_path`
- `default_manual_import_mode`
- `report_drop_folder`
- `default_broker`
- `default_account_type`
- `telegram_bot_token`
- `telegram_allowed_user_ids`
- `default_project_path`
- `codex_command`
- `max_parallel_jobs`
- `log_level`

Never commit real Telegram tokens or account credentials.

`default_broker`, account type, leverage, and account currency are preferences
only. Broker/server/account are run context and are not pass/fail criteria
unless Strategy Tester profit/loss accounting fails.

## 3. Run Config Check

```powershell
python .\scripts\telegram_bot.py --check-config
```

## 4. Test Placeholder Command Router

```powershell
python .\scripts\telegram_bot.py /status
python .\scripts\telegram_bot.py /list_ea
python .\scripts\telegram_bot.py /import_manual_run XAU_HT_M15_H1_Pilot01 run_001
```

This is a local command scaffold only. It does not connect to Telegram yet.

## 5. Manual MT5 Run Import

Use `MANUAL_MT5_RUN_IMPORT` when EA_LAB automated launching does not attach to
the same MT5 Strategy Tester context that you use manually. Manual import is
the preferred baseline path in that situation because the operator's manual MT5
environment already produces valid profit and balance changes.

Folder shape:

```text
ea_projects/<project>/backtest/manual_runs/
  run_001/
    report.html
    trade_list.csv
    set_used.set
    run_context.yaml
    notes.txt
```

Import a manual tester run:

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
  -EndDate 2026-05-29 `
  -BrokerServer "" `
  -AccountCurrency ""
```

The importer does not launch MT5, modify EA files, or optimize. It copies the
manual artifacts, creates `run_context.yaml`, and sets
`tester_profit_valid=true` only if imported data shows both non-zero closed
trade P/L and changing balance.

After import, run the analyzer against:

```text
ea_projects/<project>/backtest/manual_runs/<run_id>/report.html
ea_projects/<project>/backtest/manual_runs/<run_id>/trade_list.csv
ea_projects/<project>/backtest/manual_runs/<run_id>/run_context.yaml
```

## 6. Auto Report Collector

Use `collect_mt5_reports.ps1` after a manual MT5 backtest or optimization when
you do not want to save and copy each artifact one by one. The collector scans
configured MT5 tester folders, MT5 Common Files, project `reports/latest`, and
optional user-supplied folders, then copies matching reports, graphs, set files,
logs, CSVs, and EA diagnostics into the right project folder.

Example after a manual risk-cap validation:

```powershell
.\scripts\collect_mt5_reports.ps1 `
  -Project "Gold SMC continuous" `
  -RunId run_003_counter_validation `
  -RunType risk_cap_validation `
  -Symbol XAUUSD `
  -Timeframe H1 `
  -Notes "Manual MT5 run after diagnostic counter patch"
```

Example after a manual optimization export:

```powershell
.\scripts\collect_mt5_reports.ps1 `
  -Project "Gold SMC continuous" `
  -RunId pass_1_raw `
  -RunType optimization `
  -SourceFolder "C:\path\to\MT5\exports"
```

Destination rules:

- `baseline` and `risk_cap_validation`: `backtest/manual_runs/<run_id>/`
- `optimization`: `optimization/raw_results/<run_id>/`
- `oos`: `optimization/oos/<run_id>/`

Safety:

- It never launches MT5.
- It never deletes original MT5 files.
- It refuses to reuse an existing run folder unless `-Force` is supplied.
- Duplicate file names get timestamp suffixes.
- If no report is found, it still creates `import_summary.txt` with a warning.

Button/watch workflow:

```text
EA_LAB_REPORT_CENTER.cmd
START_REPORT_WATCHER.cmd
```

Save MT5 exports into:

```text
_mt5_report_drop\single\
_mt5_report_drop\optimization\
_mt5_report_drop\oos\
```

The watcher and menu are project-agnostic. They select or infer the EA project
instead of hardcoding one EA name. Console prompts are English-only.

## 7. Current Limits

- MT5 command execution is a placeholder.
- Telegram commands are scaffolded in a local router.
- No live trading execution exists.
- No real-account connection exists.
- No deployment command exists.
- No automatic lot sizing exists.

Environment validation is broker-agnostic. It should fail only with
`ENVIRONMENT_ACCOUNTING_FAIL` when MT5 creates closed deals at different
open/close prices but `DEAL_PROFIT` remains zero for all or nearly all closed
deals and final balance/equity does not change. Differences from user-preferred
broker, leverage, account currency, or symbol suffix are warnings only.
