# EA_LAB Workflow

EA_LAB is a local scaffold for command-based MT5 Expert Advisor research.
It contains starter scripts only. It is not a fully autonomous trading system.

## Flow

1. Idea
   - Start with a plain-language trading idea.
   - Define market, symbol, timeframe, entry, exit, and invalidation logic.

2. strategy-and-risk
   - Convert the idea into a structured strategy and risk spec.
   - Define fixed risk limits and optimization boundaries.

3. mql-code-generator
   - Generate or revise MQL5 source from the approved spec.
   - Keep source code in `ea_projects/<project>/source/`.

4. MT5 backtest/optimization
   - Use `scripts/run_backtest.ps1` for tester runs.
   - Use `MANUAL_MT5_RUN_IMPORT` when automated launcher context differs from the user's working MT5 Strategy Tester environment.
   - Import manual MT5 artifacts with `scripts/import_manual_run.ps1`.
   - Use `scripts/collect_mt5_reports.ps1` after manual MT5 tests or optimizations to auto-collect generated reports, tester graphs, set files, logs, and EA diagnostics.
   - Use `scripts/run_optimization.ps1` for macro, micro, or robustness jobs.
   - Do not force portable mode, broker, account currency, or leverage for pass/fail purposes.

5. backtest-report-analyzer
   - Use exported reports and `scripts/summarize_results.py`.
   - Summaries must mark missing data clearly and must not fake metrics.

6. ea-optimization-orchestrator
   - Plan optimization passes after the baseline backtest is analyzed.
   - Design safe parameter ranges, analyze optimization CSV results, rank candidate sets, track OOS status, and prepare approved candidates for robustness validation.
   - Store optimization artifacts under `ea_projects/<project>/optimization/`.

7. robustness-validator
   - Review approved OOS-passed candidate sets using Monte Carlo, walk-forward where available, OOS validation, spread/slippage stress, and regime checks.

8. portfolio-selector
   - Compare candidates and correlations.
   - Place selected manual-review candidates in `portfolio/port_01/selected/`.

9. live-deployment-controller
   - Placeholder only.
   - Any future deployment must stay manual-approval only.

## Full Skill Pipeline

```text
strategy-and-risk.md
-> mql-code-generator.md
-> backtest-report-analyzer.md
-> ea-optimization-orchestrator.md
-> robustness-validator.md
-> portfolio-selector.md
-> live-deployment-controller.md
```

## Skill Responsibility Table

| Skill | Responsibility | Primary Output | Next Gate |
|---|---|---|---|
| `strategy-and-risk.md` | Turns the trading idea into a validated EA Spec Card with risk score, complexity, and user approval. | `validated_ea_spec_card` | `mql-code-generator.md` |
| `mql-code-generator.md` | Generates compile-ready MQL5 code for supported complexity levels and documents parameters. | `.mq5` source and build handoff metadata | `backtest-report-analyzer.md` |
| `backtest-report-analyzer.md` | Analyzes baseline MT5 backtest reports, verifies identity, scores statistical quality, and determines whether optimization is allowed. | Baseline verdict, metrics, weakness map | `ea-optimization-orchestrator.md` |
| `ea-optimization-orchestrator.md` | Handles optimization planning, parameter range design, optimization result analysis, candidate ranking, OOS status, and handoff to robustness validation. | Approved OOS-passed candidate sets plus OOS/candidate metadata | `robustness-validator.md` |
| `robustness-validator.md` | Validates approved candidate sets with Monte Carlo, WFA where available, OOS, spread/slippage, and market regime checks. | `ROBUST`, `MARGINAL`, `NOT_ROBUST`, or portfolio candidate verdict | `portfolio-selector.md` or `live-deployment-controller.md` |
| `portfolio-selector.md` | Selects multi-EA portfolios using correlation, DD overlap, symbol exposure, crisis months, and weight allocation. | Portfolio verdict and composition | `live-deployment-controller.md` only if `APPROVED` |
| `live-deployment-controller.md` | Final manual approval gate and deployment checklist placeholder. | `DEPLOY_APPROVED`, `HOLD`, or `REJECT` | Manual operator action only |

## EA Project Folder Structure

Each real EA project should be copied from `_template` and keep this structure:

```text
ea_projects/EA_NAME/
  spec/
  source/
  set/
  backtest/
    manual_runs/
      run_001/
        report.html
        trade_list.csv
        set_used.set
        run_context.yaml
        notes.txt
  optimization/
    plans/
    raw_results/
    analyzed/
    candidates/
    oos/
  reports/
  handoff/
  logs/
```

## Handoff Schema

### From `backtest-report-analyzer.md` to `ea-optimization-orchestrator.md`

```yaml
baseline_handoff:
  baseline_verdict: "PASS | CONDITIONAL | FAIL"
  baseline_metrics:
    profit_factor: 0.0
    net_profit: 0.0
    max_drawdown_percent: 0.0
    total_trades: 0
    recovery_factor: 0.0
    expected_payoff: 0.0
  optimization_allowed_status: "Full | Restricted | No"
  recommended_optimization_focus: []
  report_path: ""
```

### From `ea-optimization-orchestrator.md` to `robustness-validator.md`

```yaml
optimization_handoff:
  approved_candidate_sets_only: true
  preliminary_candidates:
    forwarded: false
    set_ids: []
    note: "PRELIMINARY candidates are listed for tracking only and are not forwarded."
  candidates:
    - set_id: ""
      oos_status: "STRONG | ACCEPTABLE | CONDITIONAL | REJECT | PRELIMINARY"
      candidate_score: 0.0
      set_file_path: ""
      required_robustness_tests:
        - "Monte Carlo trade order shuffle"
        - "Walk-forward analysis if window reports are available"
        - "OOS validation using separate data"
        - "Spread stress 1.5x and 2x"
        - "Slippage stress"
        - "Different date range validation"
        - "Different market regime check"
```

## Workflow Rules

- No OOS means `PRELIMINARY` only.
- `PRELIMINARY` candidates must not go to live deployment.
- `PRELIMINARY` candidates must not be sent to robustness final validation.
- Only `APPROVED` OOS-passed candidates can go to `robustness-validator.md`.
- Only robustness-passed candidates can go to `portfolio-selector.md`.
- Only portfolio-selected candidates can go to `live-deployment-controller.md`.
- `PRECHECK` mode is intentionally not part of the default master workflow; using it later must be explicit and must remain blocked from portfolio/live advancement until OOS passes.

## Broker-Agnostic Environment Validation

EA_LAB is broker-agnostic and symbol-agnostic. Broker, server, account currency,
leverage, and symbol suffix are run context only. They are not pass/fail
criteria unless profit/loss accounting fails.

Environment validation should record:

```yaml
environment_context:
  broker_server: ""
  account_currency: ""
  leverage: ""
  symbol_name: ""
  symbol_path: ""
  tick_value: 0.0
  tick_size: 0.0
  contract_size: 0.0
  profit_currency: ""
  margin_currency: ""
  tester_profit_valid: false
```

Fail only with `ENVIRONMENT_ACCOUNTING_FAIL` when all of these are true:

- Closed deals exist.
- Open and close prices differ.
- `DEAL_PROFIT` is zero for all or nearly all closed deals.
- Final balance/equity does not change.

Use `BROKER_CONTEXT_DIFFERENT_FROM_USER_DEFAULT` as a warning only when the
server, leverage, account currency, or symbol differs from a user preference.
Do not automatically recommend switching brokers. Recommend verifying symbol
economics, verifying profit calculation, testing another symbol only as a
diagnostic comparison, or manually choosing a broker/symbol if the user wants.

## MANUAL_MT5_RUN_IMPORT Mode

Use `MANUAL_MT5_RUN_IMPORT` when EA_LAB automated launch does not reliably attach
to the same MT5 tester context that the operator uses manually. This mode is
valid when the imported MT5 Strategy Tester report or trade list comes from a
manual run where balance and closed trade P/L update normally.

Manual run artifacts live under:

```text
ea_projects/<project>/backtest/manual_runs/<run_id>/
  report.html
  trade_list.csv
  set_used.set
  run_context.yaml
  notes.txt
  import_summary.txt
```

Import example:

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
  -BrokerServer "operator-selected" `
  -AccountCurrency "operator-selected"
```

The import script must not launch MT5, modify EA source, or optimize. It should
mark `tester_profit_valid: true` only when imported artifacts show both changing
balance and non-zero closed trade P/L. Otherwise it must mark
`tester_profit_valid: false` and preserve the artifacts for review.

`backtest-report-analyzer.md` should accept either direct baseline artifacts or
an imported manual run folder as its baseline input.

## AUTO_MT5_REPORT_COLLECTOR Mode

Use `AUTO_MT5_REPORT_COLLECTOR` after the operator manually runs an MT5
backtest, risk-cap validation, optimization, or OOS test in the working MT5
terminal. The collector does not launch MT5, does not optimize, and does not
modify EA code. It only copies discovered artifacts into the correct EA_LAB run
folder.

For button-style usage, use:

```text
EA_LAB_REPORT_CENTER.cmd
START_REPORT_WATCHER.cmd
```

The watcher monitors:

```text
_mt5_report_drop/
  single/
  optimization/
  oos/
```

PowerShell prompts and watcher output must stay English-only to avoid console
encoding problems.

Collector example:

```powershell
.\scripts\collect_mt5_reports.ps1 `
  -Project "Gold SMC continuous" `
  -RunId run_003_counter_validation `
  -RunType risk_cap_validation `
  -Symbol XAUUSD `
  -Timeframe H1 `
  -Notes "Manual MT5 run after diagnostic counter patch"
```

Destination rules:

```text
baseline | risk_cap_validation -> ea_projects/<project>/backtest/manual_runs/<run_id>/
optimization                    -> ea_projects/<project>/optimization/raw_results/<run_id>/
oos                             -> ea_projects/<project>/optimization/oos/<run_id>/
```

The collector scans configured MT5 tester/report folders, MT5 Common Files,
project `reports/latest`, and any supplied `-SourceFolder`, `-ReportPath`, or
`-SetPath`. It copies matching `.html`, `.htm`, `.xml`, `.csv`, `.png`, `.gif`,
`.set`, `.log`, `testergraph*.csv`, `ReportTester*.html`,
`risk_cap_summary.txt`, and `risk_cap_diagnostics.csv`.

Safety rules:

- Never delete original MT5 files.
- Never overwrite an existing run folder unless `-Force` is supplied.
- Duplicate file names get a timestamp suffix.
- If no report is found, still create `import_summary.txt` with a warning.

Each collection creates:

```text
import_summary.txt
run_context.yaml
```

## Audit Trail

Every stage should preserve and append these identifiers:

```yaml
audit_trail:
  chain_id: ""
  strategy_spec_id: ""
  code_build_id: ""
  baseline_report_id: ""
  optimization_plan_id: ""
  optimization_result_id: ""
  candidate_set_id: ""
  oos_report_id: ""
  robustness_report_id: ""
  portfolio_selection_id: ""
  live_deployment_id: ""
```

## Safety Rules

- No command places live trades.
- No command changes lot size automatically.
- No command connects to a real account.
- No deployment command is implemented.
- Deployment-related behavior must remain manual approval only.
