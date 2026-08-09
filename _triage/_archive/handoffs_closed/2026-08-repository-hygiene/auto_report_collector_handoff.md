# Auto Report Collector Handoff

Scope: EA_LAB manual MT5 artifact collection  
Status: Implemented  
MT5 launch: Not used  
Optimization execution: Not used

## Files Created

- `scripts/collect_mt5_reports.ps1`
- `handoff/auto_report_collector_handoff.md`

## Files Changed

- `scripts/config.yaml`
- `scripts/config.example.yaml`
- `scripts/telegram_bot.py`
- `docs/workflow.md`
- `docs/command_reference.md`
- `docs/setup_guide.md`

## Config Fields Added

- `mt5_roaming_data_path`
- `mt5_tester_report_paths`
- `mt5_common_files_path`
- `default_manual_import_mode`

## Collector Inputs

- `Project`
- `RunId`
- `RunType`: `baseline`, `risk_cap_validation`, `optimization`, `oos`
- `SourceFolder` optional
- `ReportPath` optional
- `SetPath` optional
- `Symbol` optional
- `Timeframe` optional
- `Notes` optional
- `Force` optional

## Destination Rules

- `baseline` and `risk_cap_validation`: `ea_projects/<Project>/backtest/manual_runs/<RunId>/`
- `optimization`: `ea_projects/<Project>/optimization/raw_results/<RunId>/`
- `oos`: `ea_projects/<Project>/optimization/oos/<RunId>/`

## Safety Rules

- Never launch MT5.
- Never run optimization.
- Never modify EA logic.
- Never delete original MT5 files.
- Refuse existing run folders unless `-Force` is supplied.
- Append timestamp when duplicate file names are copied.
- Create `import_summary.txt` even when no report is found.

## Telegram Placeholder Commands

- `/collect_reports <project> <run_id> <baseline|risk_cap_validation|optimization|oos>`
- `/latest_report <project>`
- `/latest_opt <project>`

## Manual Workflow

1. Run the backtest or optimization manually in MT5.
2. Export/save reports normally if MT5 prompts for a location.
3. Run `collect_mt5_reports.ps1`.
4. Review `import_summary.txt` in the created run folder.
5. Run the appropriate analyzer on that run folder.
