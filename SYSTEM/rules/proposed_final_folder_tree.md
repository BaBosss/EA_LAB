# Proposed Final EA_LAB Folder Tree

```text
EA_LAB/
  ACTIVE/
    projects/
      Gold SMC continuous/
        reports/
          latest_backtest.html
          latest_forward.html
          latest_oos.html
        sets/
          Gold_SMC_Continuous_MT5_RiskCapV1_opt1.set
        source/
          Gold_SMC_Continuous_MT5_RiskCapV1.mq5
          Gold_SMC_Continuous_MT5_RiskCapV1.ex5
        candidates/
          Gold_SMC_Run004_OOS_VALIDATED/
            README.md
            set/
            single_test/
            forward_test/
            optimization_snapshot/
            source/
            notes/
        summaries/
          latest_summary.md

  ARCHIVE/
    projects/
      Gold SMC continuous/
        20260605_XXXXXX/
          backtest/
          optimization/
          reports/
          Forward test/
          rejected_candidates/

  SYSTEM/
    rules/
      archive_rules.md
      proposed_final_folder_tree.md
    logs/
    manifests/
      cleanup_manifest_*.csv

  scripts/
    cleanup_project.ps1
    collect_mt5_reports.ps1
    import_manual_run.ps1
    quick_report_collector.ps1
    watch_report_drop.ps1

  ea_projects/
    Gold SMC continuous/
      source/
      set/
      spec/
      portfolio/
        candidates/
          Gold_SMC_Run004_OOS_VALIDATED/
      backtest/
      optimization/
      reports/
      logs/
```

## Human Usage

Open `ACTIVE/projects/<project>/` first.

Use `ea_projects/<project>/` only for development and raw investigation.

Use `ARCHIVE/projects/<project>/` only for historical audit.

Use `SYSTEM/` only for rules, manifests, and cleanup automation.

