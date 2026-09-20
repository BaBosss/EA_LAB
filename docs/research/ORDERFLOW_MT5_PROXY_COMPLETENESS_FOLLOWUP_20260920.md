# ORDER-OFP-SCR002-FOLLOWUP-20260920 — prospective owner-authorized completion guard

Owner approval: current conversation, 2026-09-20, "Approved; continue to completion" after the explicit OFP-SCR-002 follow-up request.
Can do: Codex Primary author; deterministic controller; separate read-only GPT Scrutiny reviewer. Suggested: one bounded Codex author, one reviewer.
Canonical verified base: 7348a40b2e42e20d5864eccdc64550efa7eae5b3.
Rejected local source parent: 471cd701fcc1b08d77f44b0af3de853eedc6b8d1; initial source ac32b0ffb5b444e64648cce0225e1298e7f623d4.
Historical Repair1=1/1_EXHAUSTED and targeted recheck=1/1_CONSUMED remain unchanged. This is a separately approved prospective child, not a renamed repair or retrospective PASS.
Author lane: ct-ofp-scr002-followup-20260920. Worktree: D:\EA_LAB_CONTROL\w\ofp-c2-0920. No duplicate active author/control tower.
Objective: close remaining OFP-SCR-002: missing/partial/errored or unbound exact tick copies cannot support data-readiness claims.
Direct consumer: acceptance of the existing source-only OFPR/OFPC package; then a separately qualified data/Template research consumer, not automatic MT5 execution.

## Exact source allowlist
- docs/research/ORDERFLOW_MT5_PROXY_V1.md
- docs/research/ORDERFLOW_MT5_PROXY_COMPLETENESS_FOLLOWUP_20260920.md (copy this prospective contract / source-only closeout)
- tools/orderflow_proxy/offline_reference.py (availability audit and directly necessary helpers only)
- tools/orderflow_proxy/tests/test_orderflow_proxy.py
- tools/orderflow_proxy/mt5_audit/OrderFlowProxyAvailabilityAudit.mq5
- tools/orderflow_proxy/mt5_audit/OrderFlowProxyCopyEvidence.mqh (optional shared pure validator)
- tools/orderflow_proxy/mt5_audit/OrderFlowProxyCopyEvidence_Test.mq5 (optional compile-only harness)
No other source, strategy cards, components, existing component harness, wrappers, FamilyID/LAB_ENTRY, core, risk, defaults, PARAM_REGISTRY, adapter or runtime files may change.
External validation evidence: this directory; author may write validation subdirectories here, never overwrite historical evidence.
No PROJECT_STATE/P03/digest author writes. Controller will serialize factual status convergence after acceptance, under a separate exact state contract.

## Preserved invariants
OFP-SCR-001 lifecycle and OFP-SCR-003 provenance are already closed: retain their tests and exact component bytes.
All six variants, entry/exit geometry, ATR/wick/activity/imbalance thresholds, completed-bar timing, one-change lineage and explicit PROXY labels stay unchanged.
No TRUE_ORDERFLOW/Delta/executed-volume equivalence, no performance inference, no market data fabrication.
No Terminal/Tester/service execution, live collection, backtest, optimization, HOLDOUT, risk/defaults, deployment, chart/service/task activation, trading, DEMO/LIVE or provider/broker configuration changes.

## Completion evidence, not a permissive count shortcut
1. Before each native CopyRates/CopyTicksRange call reset last error; capture it immediately afterward. Nonzero error, negative/zero result or count/array disagreement cannot be treated as a complete positive-volume interval, even when partial records exist. Preserve returned count, requested half-open interval, error code, reason and expected native rate count.
2. D1 and every one of the 21 completed M5 intervals must independently reconcile returned ticks against their corresponding positive MqlRates.tick_volume. Detect under/over-count, missing bars, nonmonotonic/out-of-window timestamps, invalid prices, wrong source/symbol/boundary, changed pre/post rate snapshots, unsynchronized/stale intervals. Never compensate one empty interval with extra ticks elsewhere.
3. A successful API call, stable snapshots, matching counts or first/last tick timestamps alone are not proof of market-wide completeness. CopyTicksRange(COPY_TICKS_ALL) and MqlRates.tick_volume are not presumed universally equivalent. Record count basis explicitly; unexplained mismatch is UNQUALIFIED/BLOCKED, never scaled, filtered ad hoc, tolerated by a percentage or silently overridden.
4. No provider-specific complete-count contract exists in this scope. The native audit must therefore withhold P0/P1/P2_READY when completeness is unqualified; report raw observed capability and precise blockers instead. A conservative BLOCKED_DATA with useful per-interval receipts is valid source behavior, not source failure. Do not add a user-toggle or caller boolean that falsely self-certifies a provider. Deterministic positive fixtures can prove count-consistency logic, but never qualify real data.
5. Empty previous-20 tick copies plus a two-tick candidate must never produce P2_READY. Constant-price bars with complete positive tick counts are not missing data: do not invent a new per-history-bar directional filter. Preserve the existing candidate-only nonzero directional denominator rule separately from completeness.
6. Mirror the native audit evidence validation in Python. Naked lists/omitted completion evidence remain unqualified rather than gaining implicit success. Reject bool as count/time/error, fractional/negative/nonfinite counts and malformed evidence. Keep existing strategy replay helpers unchanged except necessary availability-only helpers.
7. Exercise the actual shared native completeness predicate from an external-copy compile-only MQL harness, not a disconnected reimplementation. Compiled-only means not executed; no native runtime parity claim.

## Historical diagnostic correction required
Existing external audit root: D:\EA_LAB_CONTROL\evidence\ct-orderflow-proxy-data-audit-ro-20260920.
Its ALL_8_P2_READY_AT_AUDITED_INTERVALS assertion was stronger than retained evidence: multiple CopyTicks counts differ from candidate tick_volume; GBPUSD D1 is later than its M5 candidate; BTC/ETH D1 record gaps are unresolved; all-21-bar completion receipts are absent.
Preserve those JSONs verbatim. Document them as DATA_PRESENT_NOT_QUALIFIED / NOT_ACCEPTANCE_EVIDENCE. Do not regenerate them or use their P2 label to start a backtest. The controller will write an append-only corrective receipt and supply it to the final reviewer.

## Mandatory gates and bounded lifecycle
Read AGENTS.md, exact initial/recheck findings, source contract and EA_MILESTONE_SCRUTINY_CHECKLIST.md before edits. Tests already green do not supersede the open finding.
Preserve red-first reproduction (20 empty copies + 2 candidate ticks; partial D1; positive count + error), then run full focused Python suite, 24-case mirrored replay, targeted malformed/boundary/partial/excess/missing/duplicate-record/stale/changed-snapshot tests and positive consistency controls.
External-copy compile of existing component harness, audit service and shared-predicate harness if added: each 0 errors / 0 warnings. Capture before/after process identity and source-copy hashes. No Terminal/Tester invocation.
Run exact allowlist, git diff --check, original components/strategy cards/TRUE_ORDERFLOW byte equality. Keep commands, exits, logs and outputs under immutable validation paths.
Freeze one clean committed head, require one separate exact-head read-only GPT Scrutiny of the inherited package plus this scoped follow-up and corrected claims. Author cannot self-approve or push.
This new follow-up permits ONE bounded source repair only if that review finds an in-scope defect, followed by ONE targeted recheck. Historical Repair1/recheck budgets remain exhausted. Failure after this follow-up's targeted recheck stops the line; no PASS-shopping.
After accepted source, controller may safely re-anchor, run impacted normal hooks, FF push and verify fetch + ls-remote, then converge status/P03/digest through the single writer. A source-accepted result is not whole-EA/pipeline PASS.
Runtime forecast: source/test/compile 15-30 minutes, review 5-15; main bottleneck source/evidence correctness. WIP <=4; author and reviewer sequential, no shared source writes. Dependency DAG: new approval -> source guard + independent existing-evidence correction -> deterministic freeze -> scrutiny -> conditional repair/recheck -> eligible source/state sync -> separate data/Template gate.

## Official API references read for this follow-up
- https://www.mql5.com/en/docs/series/copyticksrange — inclusive millisecond bounds, partial returns on history timeout, other retrieval errors, ALL versus INFO/TRADE event classes.
- https://www.mql5.com/en/docs/series/copyticks — synchronization can continue after a partial return; success count alone is insufficient.
- https://www.mql5.com/en/docs/constants/structures/mqlrates — tick_volume is tick volume and real_volume is trade volume; no provider-specific ALL-event equality contract is supplied here.
- https://www.mql5.com/en/docs/series/seriesinfointeger — query series state; synchronization flags do not by themselves prove full delivery of an arbitrary historical interval.
Do not invent API/count equivalence from these references. No new market request or paid provider is authorized.

## Author validation status (2026-09-20; not acceptance)

Implementation and author-side deterministic gates are complete in lane `ct-ofp-scr002-followup-20260920`; result is `COMMIT_REQUIRED`, not source acceptance. Source parent and current uncommitted HEAD remain `471cd701fcc1b08d77f44b0af3de853eedc6b8d1` because this contract forbids the author from committing or pushing.

- Red-first parent-bound reproducer exited `1`: 20 empty completed-M5 copies plus a two-tick directional candidate returned `P2_READY`; a one-of-two partial D1 copy returned `P2_READY`; positive-count-plus-error evidence was unrepresentable by the old API. Preserved at `author_validation/red_first/03_parent_exact_reproducer.*` in the external follow-up evidence directory.
- Portable Python `-B` focused suite passed `47/47`, exit `0`; the mirrored fixture replay passed `24/24`, exit `0`. Exact commands/stdout/stderr/exits are preserved under `author_validation/green/03_full_python_suite_final.*` and `04_fixture_replay_final.*`.
- External-copy MetaEditor compilation passed `0 errors / 0 warnings` for the unchanged original component harness, availability audit, and shared-predicate compile-only harness. Exact commands, compiler process exits, logs, copied sources, EX5 files, and hashes are preserved under `author_validation/compile/final2/` and `author_validation/external_copy/final2/`. Nothing was attached or executed.
- Final allowlist, diff-check, protected-scope byte equality, process, and hash receipts are preserved under `author_validation/`. Strategy components, cards, the original component harness, and accepted TRUE_ORDERFLOW paths remained byte-identical.

No separate scrutiny ran in this author lane. `self_approval=false`; the controller must commit/freeze the exact head and dispatch the contract-required separate read-only GPT Scrutiny before any acceptance or integration claim.
