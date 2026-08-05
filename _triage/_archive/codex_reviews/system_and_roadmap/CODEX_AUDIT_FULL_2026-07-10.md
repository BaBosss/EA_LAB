# Independent Systems Audit — EA_LAB

**Audit date:** 2026-07-10 (completed 2026-07-11)  
**Role:** Codex, independent systems auditor; not the author and not the verdict owner  
**Scope:** full-system audit across live risk, verdict integrity, doctrine/docs, automation/cages, and missing controls  
**Method:** repository/document/code/report inspection and arithmetic recomputation only; **no backtests were run**  
**Mutation:** this report is the only repository file created by the audit

## Executive summary (≤15 lines)

1. **P0: the live dashboard cannot observe live equity risk.** Its “DD” is reconstructed from closed-deal P&L, so floating basket loss, margin level, free margin, open ladder depth, and pending exposure are invisible.
2. Three cent accounts are real-money accounts, not one demo portfolio; several rejected/unvalidated/no-SL systems share accounts and one VPS. The canonical invariant still says 9 EA / one 10,000-cent account / judge 2026-09-22.
3. `check_state.ps1 -Strict` reports CLEAN because it tests whether stale strings exist, not whether one structured deployment state agrees across owners.
4. The daily monitor can report task success after failed collection, dashboard, news, gist, or commit steps; it also republishes stale exporter files under today’s date.
5. NewsGuard is not attached to the trading VPS cohort, its feed is copied only to the lab PC, and the MT4 port remains open. Therefore it currently provides **zero live protection**.
6. NewsGuard also has restart-stuck-block, pending-order, flat-magic relevance, malformed-empty-feed, DST/offset, reopen-churn, and remote-alert gaps not covered by its tests.
7. Regression/test cages can pass stale `.htm`, `.ex5`, or journal output; Boss 15/16 and conditional risk paths are outside the regression baseline.
8. ST03’s flat-lot no-edge diagnosis is numerically supported, but “closed permanently” is procedurally invalid: the predeclared spacing axis was never run and the Stage-2 bar appeared in the result commit.
9. Boss 16’s backward result supports continued validation, not deployment: entry parameter stability is weak and spacing/TP/holdout/MC remain open.
10. Oracle’s exclusion from the main portfolio is sound on no-SL/nonbinding-cap risk; top-5 concentration alone is not proof of no entry edge without a true flat-lot rerun.
11. RSI-MR is the clearest doctrine breach: fixed-lot PF 0.78, profitability comes from recovery sizing, yet it was placed on a shared **real** cent account.
12. EA-SCORE can authorize real-cent exposure without unused holdout, MC, adequate sample size, or live evidence, and does not encode the premium-track isolation requirements.
13. The system has strong raw evidence habits and several correctly conservative demo-only verdicts, but control-plane truth and live telemetry lag behind research throughput.
14. **Immediate recommendation:** freeze new real-cent attachments/promotions until P0 telemetry, deployment truth, and NewsGuard transport/behavior are corrected and independently exercised.

## Audit basis and interpretation

The audit treated `VISION.md`, `PROJECT_STATE.md`, `AGENT_TASKBOARD.md`, `AGENTS.md`, `CLAUDE.md`, `DEMO_DEPLOYMENT_PLAN.md`, `EA_SCORECARD_AND_REGISTRY.md`, and `MASTER_BACKLOG.md` as the governing record, then traced claims into scripts, MQL source, sets, CSVs, HTML reports, git chronology, scheduled-task configuration, and generated monitoring output. “CONFIRMED-ERROR” means the claim/control is contradicted by directly inspectable evidence; “SUSPECT” means the risk is credible but requires a live exercise or new controlled run to close; “VERIFIED-OK” means the inspected claim survived falsification within the available evidence.

## Layer A — Live risk and deployment safety

### CONFIRMED-ERROR

#### A1 — The dashboard’s green/red state is not live drawdown

`scripts/live_dashboard.ps1:209-254` starts from a constant base equity, adds closed-deal profit/swap/commission, and derives drawdown from that cumulative series. The UI itself admits this at `scripts/live_dashboard.ps1:526-528`. Exporters supply transaction history, not current positions/account equity. Consequently a no-SL grid can approach a margin call while the dashboard remains green until losses are closed. This is a safety-control failure, not merely a display limitation.

Missing live fields: account equity, balance, margin, free margin, margin level, per-magic floating P&L, open lots, basket depth, oldest position age, pending orders, and distance to broker stop-out.

#### A2 — The declared deployment invariant is obsolete and the checker masks it

The deployment reality lists five active accounts, including three real cent accounts, at `DEMO_DEPLOYMENT_PLAN.md:252-281`; for example account 159503454 is explicitly real and carries five MT5 systems (`DEMO_DEPLOYMENT_PLAN.md:259`). By contrast, `scripts/check_state.ps1:27-31` hardcodes judge 2026-09-22, start 2026-06-22, one 10,000-cent account, 9 EA, and seven magics. Its checks only require those strings to appear somewhere (`scripts/check_state.ps1:48-75`). Therefore contradictory newer truth can coexist and `-Strict` still exits CLEAN (`scripts/check_state.ps1:77-80`).

#### A3 — The daily automation is fail-open and can falsely report success

`scripts/daily_monitor.ps1:8-28` invokes rotation, collection, calendar, dashboard, gist publishing, staging, and commit without `$ErrorActionPreference = 'Stop'`, child exit-code checks, or a final non-zero status. The registered task showed `LastTaskResult=0`, no restart attempts, `StartWhenAvailable=False`, and `WakeToRun=False`. A broken early step therefore does not prevent publishing/committing later artifacts or task-level “success.” There is no out-of-band alert.

#### A4 — Stale exporter output is relabeled as today’s snapshot

`scripts/collect_live_deals.ps1:19-30` enumerates matching source CSVs and copies them to a destination named with the current date, without validating source `LastWriteTime`, embedded export time, row recency, or account clock. During inspection, a source last updated 2026-07-06 had been copied as a `20260710` snapshot. This destroys the operational meaning of the filename and can conceal a dead exporter/VPS connection.

#### A5 — Highest-risk live magics are unmapped or weakly mapped

The static map at `scripts/live_dashboard.ps1:97-120` omits the real MT4 account 141049900’s Kangaroo 1112–1115 and Zeus 7777 described at `DEMO_DEPLOYMENT_PLAN.md:261`, and does not fully represent the user-mix magics on the real MT5 account. Unmapped rows receive no EA-specific warn/kill criteria (`scripts/live_dashboard.ps1:21`, `:261-313`). Thus the most dangerous no-SL/user-experiment positions are precisely those without an enforceable dashboard threshold.

#### A6 — Portfolio concentration is governed per EA, not per failure domain

All active cohorts are reported on one VPS and one broker family. Account 159503454 alone has four XAU-facing systems (`DEMO_DEPLOYMENT_PLAN.md:259`), while another real account includes additional XAU and recovery systems. No control aggregates simultaneous XAU/USD news exposure, directional delta, open lots, margin consumption, or correlated basket loss across accounts. Per-magic DD limits cannot bound a broker/VPS/news/common-symbol event.

#### A7 — RSI-MR violates the documented “edge before money management” doctrine

`_mt5_auto/RSIMR_LOTLAW.csv:2` shows fixed-lot PF 0.78, net −588.02; profitable configurations arise only after recovery sizing (`:3-10`). Its own robustness record describes capped recovery as the mechanism and calls for demo-first isolation, yet it was attached to shared **real** account 159503454 (`DEMO_DEPLOYMENT_PLAN.md:259`). This contradicts the factory doctrine and exposes other strategies to shared-equity risk.

### SUSPECT

- The secret gist is unlisted rather than private; `scripts/publish_dashboard_gist.ps1` publishes account identifiers and P&L to anyone with the URL. The gist was verified as `public=false`, so this is an access-control/privacy risk, not evidence of an actual leak.
- Investor credentials and terminal configurations are intentionally outside git, but there is no complete credential inventory, owner, rotation date, recovery procedure, or least-privilege attestation in the repository.
- Manual kill guidance (for example floating DD 40% on Zeus) is not technically enforceable and depends on continuous human observation of data the current dashboard does not collect.

### VERIFIED-OK

- The GitHub repository was verified private, reducing exposure of tracked monitoring CSVs.
- Exporters are designed read-only; the audit found no trade function in the monitoring exporter path.
- Account cutover dates in the dashboard reduce contamination from old closed trades, although they do not solve floating-risk blindness.

## Layer B — Verdict integrity

### Mandatory case 1: ST03 family

#### CONFIRMED-ERROR — finality exceeds the executed experiment

Recomputed raw results support the narrow diagnosis: lab flat-lot GBP PF 0.68/net −10,054.49/561 trades; CAD PF 0.40/net −9,941.62/350 trades; the best naked/gated GBP result was PF 0.99/net approximately −58/623 trades. `LOT_Repeat=999999` is a valid practical disable for escalation in the tested horizon; source tracing shows escalation only when the repeat bucket is reached.

However, ORDER-071 rev02 explicitly predeclared gate × spacing (fixed, ATR, progressive) at `AGENT_TASKBOARD.md:2830-2837`. The result contains only gate variants (`AGENT_TASKBOARD.md:2872-2885`); spacing was neither built nor run. Git chronology also shows the Stage-2 PF≥1.05/trades≥300 bar first appearing with the result commit rather than in the prior order commit. The review nevertheless says “ปิดถาวร” at `AGENT_TASKBOARD.md:2981-2994`.

**Audit disposition:** flat-lot ST03 under the tested exit/gate configurations is no-edge; recommendation to remove it from real exposure is supported. “All axes exhausted / permanently closed” is not supported. The missing spacing axis must be recorded as unswept, not silently treated as falsified.

### Mandatory case 2: Boss 16 Kangaroo

#### SUSPECT — reasonable research candidate, premature if interpreted as deploy candidate

Backward 2020–2022 for RSI 21/30 produced PF 1.31, net +596, equity DD 9.58%, 276 trades; the current-regime surface reports PF 1.57 with 285 trades. This is useful independent-regime evidence and falsifies the strongest “current regime only” objection. But the entry surface is peaky, and the governing review itself records spacing/TP as unswept (`AGENT_TASKBOARD.md:3192-3205`). Holdout, MC, and full funnel remain open.

**Audit disposition:** retain as **candidate for continued validation only**. No real-cent promotion until spacing/TP plateau, unused holdout, tail/margin stress, and portfolio overlap are complete.

### Mandatory case 3: SuperTrend

#### CONFIRMED-ERROR — current score/proposed promotion path overstates evidence

The arithmetic spread stress is reproducible: M0 PF 2.93, net 1,690.49, 56 trades; 30 points of added XAU cost at 0.01 lot is about $0.30/trade, or $16.80 total, leaving PF about 2.88. The earlier MT5 INI spread A/B was correctly recognized as a no-op. High top-5 concentration is not by itself disqualifying for a trend follower.

The current deployed BRK-XAU set uses the compiled Bars40 defaults, so comparing against a Bars40 portfolio baseline is legitimate for the current account. But the historical Bars55 raw report/correlation provenance is no longer reproducible from preserved artifacts, and 56 trades is too thin for an automatic real-cent gate. The review acknowledges it remains parked at about 6/10 (`AGENT_TASKBOARD.md:3824-3845`).

**Audit disposition:** remain reserve/validation. Do not let BWD+plateau alone lift it to real cent; require an unused holdout or live paper evidence and a reproducible portfolio series.

### Mandatory case 4: Oracle EA

#### CONFIRMED-ERROR — causal claim is stronger than the evidence

The original report contains 1,333 closes, net +5,775.45, PF 1.4312. The top five closes sum to +5,822.54 (100.82% of total), and they carry the largest escalated lots. Static lot-normalization to 0.10 produces approximately net −316.49/PF 0.9707, but this is **not** a true flat-lot rerun because changed basket sizing would alter exit timing.

**Audit disposition:** exclusion from the main portfolio is supported by no hard SL and a cap that did not bind in the observed path. The statement “no entry edge” is not proven by top-5 concentration or static normalization alone. A true flat-lot run would be required for that causal claim; otherwise label the concentration as a risk fingerprint, not proof.

### Mandatory case 5: sample of older verdicts

#### CONFIRMED-ERROR

- **RSI-MR:** fixed-lot PF 0.78 but deployed on shared real cent; verdict/deployment mismatch as described in A7.
- **Gold Reaper / LondonConso / ST_EA03:** the old scorecard still labels them CORE/CANDIDATE (`EA_SCORECARD_AND_REGISTRY.md:131-135`) while the current deployment record describes structural no-edge/rejected constituents in real user cohorts. The registry is no longer a reliable current deployment authority.
- **Keltner/Ichimoku:** closure used default Model-2 screens across a few symbols on one TF, despite `CLAUDE.md:10` declaring source-available verdicts with fewer than three swept levers invalid. Calling the concepts closed across all classes is procedurally invalid.
- **ZSCORE AUDCAD:** final backward PF 0.77/net −50.46/104 trades supports closing that configuration. But “full rescue ladder completed” is inaccurate because round 3 was recorded N/A; the evidence supports rejection of the tested center, not a universal concept proof.

#### SUSPECT

- **BRK-XAU:** strong PF values rely on thin OOS samples, and MC evidence from a Bars8 sibling must not be transferred to Bars40/55. Current real Bars40 provenance is clear, but older correlation claims need artifact restoration.
- **Boss 14:** demo-only is appropriate; selection across a large configuration search plus thin winners creates multiple-testing risk not addressed by ordinary OOS alone.
- **UnNomGuai:** demo-only is appropriate, but a configured 99-layer capacity whose observed history reached far fewer layers leaves tail exposure untested.
- **ClevrFX:** demo experiment is defensible, but compiled-black-box/no-server-SL behavior and deferred monitoring make operational evidence weaker than research evidence.

#### VERIFIED-OK

- **Boss 16 backward result:** arithmetic and report extraction are internally consistent; it is genuine evidence for continued research.
- **Oracle concentration arithmetic:** recomputation agrees with the taskboard values; the issue is interpretation, not arithmetic.
- **ZSCORE backward failure:** the stop decision for the tested AUDCAD H4 center is supported.
- **ClevrFX and UnNomGuai:** the registry limits them to demo experiments and explicitly records no-SL/black-box caveats (`EA_SCORECARD_AND_REGISTRY.md:248`, `:257`).

## Layer C — Doctrine, source-of-truth, and documentation

### CONFIRMED-ERROR

#### C1 — There is no functioning single source of deployment truth

`PROJECT_STATE.md` retains the old one-account/9-EA clock, `DEMO_DEPLOYMENT_PLAN.md` contains the five-account reality, `EA_SCORECARD_AND_REGISTRY.md` retains stale CORE/CANDIDATE labels, and the dashboard carries a fourth hand-maintained cohort map. The anti-drift script validates stale literals rather than semantic equality. This is a control-design failure caused by duplicated state.

#### C2 — EA-SCORE can grant real-money rights without durable evidence

The new rubric awards entry-edge points from PF after basic cost testing but does not bind minimum trade count, confidence interval/effect size, unused holdout, or multiple-testing correction. A score of 7–8 can reach real cent without MC or live tracking. Correlation <0.4 can earn a portfolio point even when stress-window drawdown overlap—the quantity emphasized in `VISION.md`—is unknown. “M0 does not melt” is undefined. Premium-track isolation, no top-up, and principal-withdrawal requirements are not encoded as hard deployment prerequisites.

#### C3 — The verdict process and the new lever rule are inconsistent

`CLAUDE.md:10` requires at least three swept levers for source-available EAs, yet recent Keltner/Ichimoku closure and ST03 finality do not satisfy that rule. The system is applying a stricter doctrine retroactively in prose but not enforcing it in the verdict schema.

#### C4 — Canonical state has material encoding corruption

`PROJECT_STATE.md` contains literal mojibake in a large majority of its lines (examples begin near lines 11, 85, and recur through the decision log). The canonical entry therefore cannot be reliably read by humans or agents without ad-hoc repair. A source of truth that is not deterministically readable is not a source of truth.

#### C5 — MASTER_BACKLOG preserves superseded evidence as actionable-looking truth

The backlog contains old Model-2-based PF conclusions and “do not retest concept” language that conflict with the later Model-1 minimum and rescue-ladder rules. It lacks a machine-readable superseded marker tied to the current verdict record.

### SUSPECT

- Auto-monitor commits use `[auto]`, while `AGENTS.md` defines agent tags and requires `make_status.ps1` after every commit. This may leave mobile status stale and weakens authorship/audit consistency.
- “No grandfathering” is stated, but old CORE rows are not systematically rescored or blocked from deployment. The doctrine is stronger than its migration mechanism.

### VERIFIED-OK

- The repository explicitly distinguishes agent evidence production from Claude/user verdict ownership, reducing unauthorized direction changes.
- Model-2 is now documented as zero-trade/proof-of-concept only, and several later verdicts correctly use Model-1/0 evidence.
- The scorecard frequently records caveats and supersede chains rather than deleting unfavorable history; the failure is synchronization/enforcement, not absence of audit narrative.

## Layer D — Automation, NewsGuard, and test cages

### CONFIRMED-ERROR

#### D1 — NewsGuard is not a live control

The taskboard records NewsGuard built/tested but still awaiting attachment and leaves the MT4 port open around ORDER-083/083B (`AGENT_TASKBOARD.md:3384` onward). All trading terminals are on the VPS, while `scripts/daily_monitor.ps1:11-15` copies the CSV only to the lab PC’s MT5 Common Files. Even after attachment, the present transport does not deliver the automatic feed to the live VPS terminals.

#### D2 — NewsGuard has uncovered state-machine failures

- **Restart-stuck block:** `ng_blockSet[]` resets false in memory, while the terminal GlobalVariable persists. Outside the window, clearing is conditional on `ng_blockSet` (`NewsGuard_Core.mqh:352-371`, `:402-409`), so a crash/restart can leave `NEWSGUARD_BLOCK_<magic>` set indefinitely. Graceful deinit clears it (`:418-429`), but crashes are the case that matters.
- **Fresh empty/malformed feed arms the guard:** after parsing, `ng_newsOK=true` regardless of `ng_evCount` (`:227-277`). A format change can silently produce zero protected events.
- **Flat non-USD magic is unprotected:** relevance for non-USD news is inferred only from currently held positions (`:293-307`). A flat EUR/CAD/etc EA can open during the event window.
- **Pending orders survive:** `Execution.mqh:52-69` and `:188-205` veto new market/pending sends but do not cancel already placed GTC pending orders; those can trigger inside the blocked window.
- **CLOSE_ALL churn:** the watchdog recloses on every timer pass while active (`NewsGuard_Core.mqh:395-399`) but does not block owner re-entry, enabling repeated open/close churn.
- **Manual time offset:** default Bangkok=server+4 (`NewsGuard_Core.mqh:46`) has no broker-DST reconciliation; a one-hour error can move the protection window.
- **Fail-open alerting:** missing/stale data releases blocks and only emits terminal `Print/Alert` (`:365-381`); there is no remote delivery or escalation.

#### D3 — `mt5_run.ps1` can leave a stale destination report looking valid

The runner deletes source-side reports only (`scripts/mt5_run.ps1:58-60`), not `_mt5_auto/reports/$ReportName.htm`. If no new report appears it prints “NO REPORT” but exits success (`:112-120`). A caller that merely checks destination existence can parse an older run.

#### D4 — `tpl_regression.ps1` can accept stale evidence and has narrow coverage

It checks only whether the destination HTML exists (`scripts/tpl_regression.ps1:58-60`), so it inherits D3. It covers Boss 11–14 only (`:28-31`), one XAU H1 six-month Model-1 window, and compares net/PF/trades but not the parsed equity DD (`:33-43`, `:74-83`). Boss 15/16, pending-order paths, persist/restart behavior, SL/TP correctness, and floating risk are outside the cage. `-UpdateBaseline` is unguarded (`:65-68`), and baseline changes have occurred alongside implementation work.

#### D5 — Unit smoke harness can pass stale binaries and stale journal verdicts

`ea_template/tests/run_tests.ps1:38-40` compiles a test but accepts any existing `.ex5`, even if the current compile failed. It then selects the newest tester journal globally and the last matching PASS/FAIL (`:47-50`) without proving the line belongs to the just-started process/run. Combined with D3, a previous PASS can produce a false green.

#### D6 — Deployment compile does not fail closed

`ea_template/deploy.ps1:29-44` prints selected compile-log lines but does not require a zero-error result, delete/verify each preexisting `.ex5`, compare binary timestamp/hash to source, or exit non-zero on compile failure. It can then mirror stale binaries into lane 2 (`:46-53`).

### SUSPECT

- Regression baselines are not tied to tester build, broker history snapshot, symbol specification, or data hash; identical code can legitimately drift after history refresh, while changed data can be mistaken for code behavior.
- The monitor rotation force-terminates a path-scoped terminal after timeout. It avoids a global kill but still risks incomplete exporter flush without a post-close integrity check.

### VERIFIED-OK

- The Execution GlobalVariable bridge is inert when the variable is absent or below 0.5 (`ea_template/core/Execution.mqh:52-69`). This default-off behavior is correct.
- `mt5_run.ps1` scopes its live-terminal guard to the selected install and applies priority/affinity freeze protection (`scripts/mt5_run.ps1:38-52`, `:83-110`).
- NewsGuard close operations are magic-scoped and log individual failures (`NewsGuard_Core.mqh:325-347`); the defect is escalation/state handling, not cross-magic closure.

## Layer E — Missing controls, ranked

### P0 — required before any new real-cent attachment or promotion

1. **Real-time risk supervisor on the trading VPS:** collect account equity/margin/free-margin/stop-out level and per-magic floating P&L, lots, position count, basket depth, pending orders; enforce account and portfolio halt/close thresholds independently of EA logic.
2. **One authoritative deployment inventory:** structured file/database with account type, broker/server, host, balance unit, EA build hash, set hash, symbol, magic, attach time, judge date, owner, status, kill rules. Generate DEMO plan, dashboard map, and checker from it.
3. **NewsGuard production completion:** attach attestation, VPS feed transport, MT4 port, remote alerts, restart reconciliation, fresh-zero-event failure, flat-magic symbol configuration, pending cancellation, CLOSE_ALL block, and broker-time/DST validation. Exercise failure modes on demo before live.
4. **Remove/isolate doctrine-violating real systems:** especially RSI-MR and rejected/no-edge user mixes. Premium/recovery experiments must not share equity with validated systems.
5. **Cross-account/global kill plan:** aggregate XAU/USD/event exposure and margin across all real accounts; define automatic and manual actions for VPS loss, broker disconnect, exporter silence, margin breach, and NewsGuard failure.

### P1 — required for trustworthy promotion and ongoing operation

1. Continuous live-vs-backtest drift: trade-rate interval, win/PF uncertainty, spread/slippage, holding time, layer depth, MAE/MFE, and regime drift—not only a distant judge date.
2. Promotion statistics: minimum effective sample, nested/untouched holdout, multiple-testing correction or deflated metric, plateau rules, PBO/WFA where applicable, and explicit effect-size uncertainty.
3. Evidence lineage: hash EA source/binary/set/report/tester build/history range/symbol specification; preserve reports rather than overwrite/gitignore the decisive artifact.
4. Harden every cage: remove old destination first, require non-zero on no report, delete old binary before compile, parse compiler exit/log, bind journal verdict to run ID, include DD/risk-path assertions, and make baseline update separately approved.
5. Backup/restore drills for VPS terminals, `D:\Monitor`, Common Files, ignored reports, sets, credentials, and scheduler configuration.
6. Credential inventory and rotation, least-privilege accounts, gist redaction/token revocation procedure, and incident ownership.
7. Cohort-specific judge criteria and start dates generated from the deployment inventory; prohibit one global clock for deployments started on different dates.

### P2 — resilience and governance maturity

1. Automated attach/config/build attestation from each terminal, including magic collisions and account hedging/netting mode.
2. Independent broker/execution reconciliation against statements and server-side SL presence.
3. Human runbooks with timed escalation and a named backup operator; remove the single-observer bottleneck.
4. Quarterly blind verdict audits and monthly control metrics as already envisioned, with sampled raw evidence preserved and verdict hidden from the auditor.
5. Repair `PROJECT_STATE.md` encoding and introduce schema validation/link checks for canonical documents.

## Five decisions I would make differently

1. **Freeze promotions now.** I would not attach another EA to real cent until floating/margin telemetry and a VPS-resident independent kill control are demonstrably working.
2. **Remove RSI-MR from shared real equity.** Fixed-lot PF 0.78 means recovery sizing, not entry edge, carries the result. If retained at all, it belongs in an isolated demo/premium experiment with a non-replenishment budget.
3. **Downgrade ST03 finality, not its removal recommendation.** I would remove it from real exposure based on current evidence, but record the research state as “no edge under tested exits/gates; spacing unswept,” not “all axes permanently closed.”
4. **Keep Boss 16 and SuperTrend in validation, not promotion.** Boss 16 needs spacing/TP plateau, unused holdout, MC/tail and portfolio tests; SuperTrend needs adequate sample and reproducible portfolio evidence. A score alone would not authorize real money.
5. **Reject Oracle for main-portfolio risk without claiming causal no-edge.** No SL plus a nonbinding cap is sufficient to exclude it; I would require a true flat-lot rerun before asserting the entry has no edge.

## Final audit conclusion

The research process is materially better than a superficial “high PF wins” workflow: it has backward windows, cost stress, raw reports, explicit caveats, and a culture of revisiting bad assumptions. The system nevertheless crossed from research into real-money operation before its control plane matured. The dominant risk is not that every EA verdict is wrong; it is that contradictory deployment truth, closed-trade-only monitoring, fail-open automation, incomplete NewsGuard deployment, and stale-pass cages can all fail in the same optimistic direction. Until the P0 controls are closed, a green dashboard or CLEAN regression must not be interpreted as evidence that live capital is safe.
