# EA_LAB Report Center

All PowerShell prompts are English-only to avoid broken Thai text in the console.

## Folder You Should Use

Save or copy MT5 exports into this drop folder:

```text
C:\Users\patip\OneDrive\.Codex\EA_LAB\_mt5_report_drop\
```

Recommended subfolders:

```text
_mt5_report_drop\
  single\          # single backtest reports, ReportTester*.html
  optimization\    # optimizer exports, ReportOptimizer*.xml or optimizer CSV
  oos\             # out-of-sample reports
  _needs_project\  # files that cannot be matched to a project
  _logs\           # watcher state
```

You do not need to create these folders manually. EA_LAB already created them.

## Buttons

Double-click these files in Windows Explorer:

`EA_LAB_REPORT_CENTER.cmd`

- Selects project from `ea_projects\`
- Menu: single summary, optimization summary, or both
- Does not hardcode one EA

`START_REPORT_WATCHER.cmd`

- Watches `_mt5_report_drop\`
- Auto-collects new MT5 reports into the matching project folder
- Creates summaries after collection
- Does not delete original files

`GET_LATEST_SINGLE_REPORT.cmd`

- Selects project
- Creates latest single-test summary

`GET_LATEST_OPTIMIZATION_REPORT.cmd`

- Selects project
- Creates latest optimization summary

## Normal Workflow

1. Run the test manually in MT5.
2. Save the single report or optimizer export into:

```text
_mt5_report_drop\single\
```

or:

```text
_mt5_report_drop\optimization\
```

3. Double-click `START_REPORT_WATCHER.cmd`.
4. The watcher copies files into the project:

```text
baseline/risk-cap -> ea_projects\<project>\backtest\manual_runs\<run_id>\
optimization      -> ea_projects\<project>\optimization\raw_results\<run_id>\
oos               -> ea_projects\<project>\optimization\oos\<run_id>\
```

5. Summary files are created in:

```text
ea_projects\<project>\reports\collected\single\
ea_projects\<project>\reports\collected\optimization\
```

## If Project Cannot Be Detected

The watcher writes a note under:

```text
_mt5_report_drop\_needs_project\
```

Then run manually with the target project:

```powershell
.\scripts\collect_mt5_reports.ps1 `
  -Project "PROJECT_NAME" `
  -RunId run_manual `
  -RunType baseline `
  -SourceFolder "C:\Users\patip\OneDrive\.Codex\EA_LAB\_mt5_report_drop\single"
```

## Direct PowerShell Use

```powershell
.\scripts\quick_report_collector.ps1 -Mode menu
.\scripts\watch_report_drop.ps1 -RunType auto -AllowSingleProjectFallback
```

## Recommendation

For new EAs, keep the EA project folder name close to the EA file/name used in
MT5 reports. This helps auto-detection route reports to the right project.
