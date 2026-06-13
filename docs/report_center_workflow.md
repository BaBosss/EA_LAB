# EA_LAB Report Center Workflow

## Goal

Make manual MT5 report handling project-agnostic. The workflow must continue to
work when the EA/project changes.

## Folder Preparation

EA_LAB created these folders:

```text
_mt5_report_drop/
  single/
  optimization/
  oos/
  _needs_project/
  _logs/
```

Use them like this:

- `single/`: MT5 single backtest reports such as `ReportTester*.html`
- `optimization/`: MT5 optimizer exports such as `ReportOptimizer*.xml`
- `oos/`: OOS reports
- `_needs_project/`: files the watcher cannot map to a project
- `_logs/`: watcher state

## Recommended Workflow

1. Run MT5 manually.
2. Save/export the MT5 artifact into the right drop folder.
3. Double-click `START_REPORT_WATCHER.cmd`.
4. The watcher detects the file, infers project if possible, and copies files to:

```text
baseline/risk-cap -> ea_projects/<project>/backtest/manual_runs/<run_id>/
optimization      -> ea_projects/<project>/optimization/raw_results/<run_id>/
oos               -> ea_projects/<project>/optimization/oos/<run_id>/
```

5. It then creates summary files under:

```text
ea_projects/<project>/reports/collected/single/
ea_projects/<project>/reports/collected/optimization/
```

## Project-Agnostic Rules

- Buttons do not hardcode `Gold SMC continuous`.
- If multiple projects exist, the quick collector asks you to select a project.
- The watcher tries to infer the project from the EA name in the MT5 report.
- If it cannot infer the project, it writes a note to `_needs_project/`.

## Button Files

```text
EA_LAB_REPORT_CENTER.cmd
START_REPORT_WATCHER.cmd
GET_LATEST_SINGLE_REPORT.cmd
GET_LATEST_OPTIMIZATION_REPORT.cmd
```

## Console Language

All PowerShell prompts and watcher output are English-only to avoid broken
console encoding.

## Naming Convention

Single summary:

```text
SINGLE_<EA>_tr<trades>_profit<profit>_dd<dd>_sharpe<sharpe>_<timestamp>.md
```

Optimization summary:

```text
OPT_<EA>_tests<tests>_maxprofit<profit>_sharpe<sharpe>_<timestamp>.md
```
