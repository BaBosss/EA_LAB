# EA_LAB Operating Context / Control Tower Rotation — 2026-09-14

REPLACE ENTIRE CONTENT when copying this Operating Context into the Project. This is BOOT_SNAPSHOT_ONLY, not a second status owner, work queue, or authority grant.

Verified pre-rotation canonical: `1ff95c92ed12caaf75493e4140502320748bca69`. The documentation commit containing this file is later; resolve pushed `origin/master` afresh rather than pinning forever to this historical SHA.
Owner request: refresh context, prepare the next-chat prompt with all carried work, and record/correct/update lessons. This rotation does not reopen exhausted work or authorize runtime activation.

## 1. Boot and authority

Host = `BaBoss`; deviceId = `bbb88aa0-1598-43f6-b56c-a7db22af086a`; expected origin = `https://github.com/BaBosss/EA_LAB.git`.
Fetch `origin master`, record the exact pushed SHA, and read `START_HERE.md` at that ref. Then read `PROJECT_STATE.md`, `AGENTS.md`, `AGENT_TASKBOARD.md`, `EA_RND_DIGEST.md`, and the relevant `taskboards/active/*` owner.
Use `scripts/lane_registry.ps1` with BOTH explicit `-RegistryRoot D:\EA_LAB_CONTROL\lanes\registry-v1` and `-RepoRoot <isolated-worktree>`. Verify Get/List/readback before transitions; use expected-state checks. Do not infer a writer from old chat text.
One active Main Control Tower; old tower becomes ARCHIVE/READ_ONLY after this rotation closes. Workers are bounded and have no push/deploy/owner-decision authority. Do not start a second Monitor or PROJECT_STATE writer.
Preserve dirty `D:\EA_LAB`, all unrelated work, blocked branches and negative reviews. No reset/clean/stash/rebase/amend/force/no-verify. Use canonical bootstrap, portable Python provisioning and file-backed PowerShell.
ChatGPT = Control Tower; Codex = default bounded author; qualified Gemini = possible different-family reviewer. ChatGPT/Codex/GPT Hermes are one family. Claude is cancelled, not a quota-reset wait. Gemini's historical task-scoped reviews do not establish general core-review/provider-M2 qualification.
Owner approval remains necessary for deployment/runtime attach-detach-reattach, trading/real money, LIVE/DEMO-to-LIVE, risk/default or consequential strategy semantics, attestation/signature, consequential governance/scope changes, QI-2+, destructive nonfixture cleanup, history rewrite and irreversible decisions. Eligible normal FF push remains standing-authorized.

## 2. Completed and canonical — consume, do not repeat

| Delivered scope | Exact accepted lineage | Owner / limit |
|---|---|---|
| Arxon Second Brain intake | `8dd0a3951a391288a03363464d6813741ca8e94c` | `knowledge/10_synthesis/ARXON_TRADE_BACKTEST_PLAN_20260913.md`; backlog only, no test authorization |
| Forward Alpha Discovery V1 | `93557cf207f5d6d1201da870f99f0b5334bd3bf1` | `docs/research/FORWARD_ALPHA_DISCOVERY_MODULE_V1.md`; RESEARCH_ONLY / DISCOVERY_ONLY / REAL_TRADING_OFF / NO_PROMOTION_AUTHORITY |
| Forward Alpha state convergence | `758ff8006346df9a6370ffa7636519a4eff1c854` | PROJECT_STATE entry; no real-source qualification by implication |
| Reporting durable package | `75c4f9104a48e774d495368278077fcb85c2d8d3` | `portfolio/REPORTING_STANDARD_V1_DURABLE_ARTIFACTS_20260914.json`; external binaries + Git manifest |
| Forward Alpha source-gap contract | `f2946e98520993cd753a7e32206613647b6c6e1c` | `docs/research/FORWARD_ALPHA_REAL_SOURCE_ADAPTER_CONTRACT_V1.md`; real adapter/panel remain BLOCKED |
| Control Dashboard capability into existing Monitor | source `e88ed119a56c4e7ea1781d872202333149f3ea76`; state `1ff95c92ed12caaf75493e4140502320748bca69` | `docs/workflows/EA_LAB_MONITOR_CONTROL_DASHBOARD_INTEGRATION_V1.md`; REPO_ONLY / READ_ONLY_PRESENTATION |

Monitor accepted evidence: data 87/87, static UI PASS, Agent Graph 17 groups, mobile 390x844 and desktop browser PASS, output-path redaction regression and stale/cached/offline/future/malformed checks. Factory acceptance snapshot = 9 pilot directories / 1 complete package / 8 missing-artifact issues, NOT nine qualified strategies. DONE/CLOSED history is retained separately from current work; cumulative lanes are not concurrent agents. Current counts must be regenerated, not copied from historical 651/663/673 observations.
The state-only review for `1ff95c92...` actually reports PASS with **medium-high confidence**, based on existing records; raw post-repair test/hook logs were unavailable to that reviewer. Earlier chat shorthand HIGH was inaccurate. Preserve the review wording and limitation; do not relabel it as an independent full-suite rerun.
Reporting V4 dossier = 9/9 pages visually inspected; optimization template = 3/3. Accepted native equity imagery remains UNAVAILABLE. Dossier reproduction had 9/9 identical rendered pages; optimization reproduction had identical normalized text and 3 pages with disclosed Word pagination jitter. Binary equality between reproductions is not claimed.
B15 self-contained provenance remains accepted at `28b8db50cb6935ead6526f5d0ce0e5722d3e28f0`; closure at `57b4e49db6e4e1b975beb1e4a22f9ab391c30588`. Native images remain 8 MISSING/INCOMPLETE and baskets/episodes UNKNOWN for that package. The original XX00 screen remains blocked; packaging acceptance does not repair its experiment acceptance.

## 3. All carried work — routing snapshot, not a duplicate queue

The next intake contract is `ORDER-CT-POSTMONITOR-INTAKE-20260914` in `taskboards/active/P03.md`. Its first step is read-only reconciliation. Existing canonical task/family owners and current Lane Registry take precedence over every row below.

| Work | State at this rotation | Exact next gate / owner |
|---|---|---|
| Master Research Registry V1 + dependent Second Brain V2 graph/reground/contradiction pilot | BLOCKED / A_PRODUCT_DEFECT; LOCAL_UNPUSHED; repair exhausted | Preserve local head `4f9cdd583dffde907191d721e93dcc6498e59f0d`, branch `ct/master-registry-v1-r3-20260913`; no further repair or integration under this contract |
| Arxon Stochastic Dual Zone | PLANNING_LEAD_ONLY / WAITING_PARENT_AND_PREREGISTRATION | Inspect qualified canonical parent/home compatibility with zero new MT5; source role, direction, timing and all indicator settings must be resolved prospectively; unknown/owner-reserved semantics block the branch |
| Arxon RSI / MFI+ / OBV+ | SEMANTICS_REQUIRED | Preserve unresolved marker timing / numeric / detector semantics; no invented parity or automatic experiments |
| Forward Alpha real-source adapter and Alpha Monitor panel | BLOCKED_C_ENVIRONMENT_DEPENDENCY / SOURCE_GAP | Require independently bound price/quote/OHLC observations and settlements with truthful available_at; no fake/fixture-only UI |
| Demo EA assessment + same-period backtest report, requested in another chat | OWNER_REQUEST / INTAKE_REQUIRED; current completion not verified here | Reconcile that chat's handoff, real monitor login/export evidence and active lane first; compare only identity/window/source-qualified evidence; no runtime/input/trade changes |
| User-authored EA Template / MQL5 / strategy-card inventory, requested in another chat | OWNER_REQUEST / INTAKE_REQUIRED; current completion not verified here | Deduplicate against existing Template/catalog/card owners; distinguish EA source, include/indicator, compiled build and strategy card; no new strategy implementation by inventory |
| Drive D and EA_LAB_CONTROL retirement | READ_ONLY_COORDINATION / RECONCILE_EXISTING_EVIDENCE | Reuse root-retirement and newer dashboard-retirement receipts; verify current consumers, recovery and explicit deletion authority; no broad re-audit/backup or new deletion by this handoff |
| Audit C01 netting/core candidate | EXTERNAL_INTAKE / CORE_GATE_REMAINS | Preserve audit workspace and uncommitted follow-up; owner semantics + qualified different-family review + mandatory core/regression gates before integration |
| ORDER-353 evidence monitoring | FORWARD_TEST_UNTRUSTED / evidence-only | Fresh epoch-2 identity plus later qualifying trade; first_trade_epoch and judge_date stay null until canonical gates pass |
| Report V3.1 remaining presentation gaps | CONDITIONAL_PLATFORM_BACKLOG | Owner Recipe Requested/Effective/State/Reason, same-record Chat Report Card, source-qualified exposure; only separate bounded consumer and free single-writer slot |
| Gemini full M2 / B17 structural-SL decoupling / ZL-EA-067 core integration | BLOCKED at canonical provider/semantic/core gates | Reuse exact owners in PROJECT_STATE; scoped historical Gemini PASS is not general qualification; no same-family substitute |
| Hermes V2-B real adapter | UNOPENED | Separate no-MT5 adapter-qualification contract; V2-A fixture PASS is not real tester authority |

Closed/parked exclusions: B13/B14 salvage, original XX00 Model1 screen, B15 CountBars and BT9 AUDUSD/H4 rescue, B16 H05/H07/H08 and spacing expansion, Boss19 P4/P5 and Black Tide HYP-SB-005 session rescue remain closed at their documented scopes. Do not rerun completed Episode-unit/Swap-credit diagnostics. Their negative findings remain material; none grants another experiment.
Other deferred work remains owned by PROJECT_STATE §2.3/§5.3: B heartbeat, MacroGate persistent activation, Traycer external authentication, QI-2+, M9/legacy cleanup, Zeus/ExpertMAPSAR/ExpertMAMA and uncontracted low-ROI hardening. This snapshot does not reopen them.

## 4. Evidence locators and limits

Internal management locators below are not public web links. Never publish private recovery archives, credentials or raw local paths through Monitor artifacts.
- Monitor acceptance/review: `D:\EA_LAB_CONTROL\evidence\monitor-dashboard-merge-r3-20260914\`; state reviewer receipt `STATE_REVIEW.txt`; exact source/state reviewed heads are in Lane Registry. Do not start a new product review merely to rewrite a status summary.
- Registry rejected recheck: `D:\EA_LAB_CONTROL\evidence\master-registry-v1-20260913\TARGETED_MODEL_STATE_REVIEW.txt`. 28/28 tests and validator 152/0 passed, yet review FAIL/HIGH found bare RUN falsely marking planned/negated/blocked Model4 as EXECUTED and a stale generator hash in the receipt. Test counts do not override those findings. Original checkpoint `caa6471c69dc0fa508a5ef4500fabf83983ee774` is also preserved, not a canonical Registry.
- Reporting final files/generator/QA/superseded artifacts: `D:\EA_LAB_CONTROL\evidence\reporting-standard-v1-20260914\`; rehash only required artifacts against the canonical manifest before delivery. This rotation does not repeat visual QA or regenerate reports.
- Drive review: `D:\EA_LAB_CONTROL\evidence\root-retirement-20260913\DEEP_RESULTS.md`, `deep_summary.json`, `deep_disposition.csv`, `SUPPLEMENT_RECOVERY.md`. These are dated read-only/recovery findings, not blanket deletion authority or proof that current consumers are gone.
- Newer external dashboard receipt: `D:\EA_LAB_CONTROL\evidence\dashboard-retirement-20260914\post_retirement.json` + `manifest.json`. The receipt observed at 2026-09-14T19:28:53+07:00 reports old task/dashboard removal and Monitor snapshot on `e88ed119...`, still DEGRADED / DIFFERENT_REPO_HEAD. This rotation only read the receipt; it did NOT perform those runtime/deletion actions or independently accept their authority/history. Reconcile before repeating anything.
- The other-chat Demo and strategy-card requests are retained from owner conversation context, not verified as completed repo milestones. The owner's statement that login was performed does not itself establish authentication, data availability or test parity. Obtain the existing lane's exact evidence; do not require duplicate work from the owner unnecessarily.

## 5. Next dependency DAG and acceptance

Fresh canonical + live ownership -> consume completed milestones -> read-only intake of other-chat work -> select independent READY planning tasks -> exact bounded contracts -> evidence/checks -> independent review -> canonical owner/queue convergence -> eligible FF push -> remote verification.
The first research lead is Arxon Stochastic parent/home compatibility, NOT a selected strategy or authorized backtest. The direct consumer is a decision whether exactly one sourced component addresses a qualified parent's unresolved causal question. If parent or semantics cannot be supported, return SEMANTICS_REQUIRED/NO_QUALIFIED_PARENT and stop that branch; do not fill gaps with defaults or choose reversal/continuation semantics silently.
Parallelism: separate read-only intake/source-audit lanes may run safely, normal WIP <=4; use the conservative isolated batch cap <=8. Serialize PROJECT_STATE/taskboard integration and all Monitor edits. No worker pushes. A re-anchor does not reset an exhausted repair budget.
Before any actual research verdict/optimization/Candidate/HOLDOUT work, read CLAUDE.md, EA_RND_PROTOCOL.md, EA_REPORT_SCHEMA.md and the exact family/experiment contract. Model2/Open Prices/Math Calculations are diagnostic-only; research requires Model1 / 1 Minute OHLC minimum. Candidate build/write requires frozen Model4 MAIN+BWD on one installation lineage; D:\Meta 5 is the primary serial Model4 lane, Meta5c has no Model4 authority. BWD is falsification, not search; HOLDOUT is protected. KINT-001 stays OPEN and numeric A/B/C/D mapping UNRATIFIED.
No new MT5, optimization, HOLDOUT, Candidate, risk/default, runtime, hosting, task, OneDrive or trading action is part of this rotation/intake preparation. Follow-up delivery/activation needs its actual contract, even when source code is canonical.

## 6. Lessons, replacement and archive safety

Use `docs/workflows/CONTROL_TOWER_LESSONS_20260914.md`; it distinguishes implemented repairs, documentation corrections, rejected work and unproven causal claims. START_HERE routes future sessions to it; the pending intake has a real queue home rather than living only in this handoff.
Replace the old Project Operating Context completely; do not append competing snapshots. Project Instructions are a boot/rules snapshot: updating their UI is an owner paste action, not something a Git commit performs. No AGENTS.md authority change is made here.
Archive this chat after verified rotation closeout. Preserve dirty primary, old worktrees with unpushed work, failed reviews, accepted binary manifests and recovery archives. DONE lane metadata is not a deletion permission. Do not bulk close or delete other chats' lanes.

## 7. New Main Control Tower prompt

Copy the following block to the new chat after the rotation package is verified pushed. Read the current Git version of this file, not a stale pasted copy.

```text
EA_LAB — NEW MAIN CONTROL TOWER / POST-MONITOR ROTATION / ALL-WORK INTAKE
Owner approves continuation through already-approved bounded work, tests, required review, state sync and eligible normal FF push; AGENTS.md hard stops remain binding.
Take the ONE active Control Tower seat only after verifying no competing active tower/writer. The previous tower is ARCHIVE/READ_ONLY after handoff.
Pin BaBoss / bbb88aa0-1598-43f6-b56c-a7db22af086a. Verify hostname and origin https://github.com/BaBosss/EA_LAB.git.
Fetch origin master and record exact pushed SHA. Pre-rotation milestone was 1ff95c92ed12caaf75493e4140502320748bca69; do not assume it is still current.
At the exact fetched ref read START_HERE.md, PROJECT_STATE.md, AGENTS.md, AGENT_TASKBOARD.md, EA_RND_DIGEST.md, then relevant taskboards/active/*.
Read docs/handoffs/CONTROL_TOWER_ROTATION_20260914.md and docs/workflows/CONTROL_TOWER_LESSONS_20260914.md.
Read ORDER-CT-POSTMONITOR-INTAKE-20260914 in taskboards/active/P03.md. It authorizes read-only reconciliation/planning, not a new experiment.
Inspect Lane Registry with explicit RegistryRoot D:\EA_LAB_CONTROL\lanes\registry-v1 and explicit RepoRoot. Preserve dirty D:\EA_LAB; work only in clean isolated exact-ref worktrees.
Reconcile CURRENT / READY / BLOCKED / PARKED / DONE against actual Git, queue and lane evidence. Do not replay completed work or trust historical READY/DONE labels alone.
Monitor source e88ed119a56c4e7ea1781d872202333149f3ea76 and state 1ff95c92ed12caaf75493e4140502320748bca69 are closed repo-only; do not reintegrate them.
Reporting package 75c4f9104a48e774d495368278077fcb85c2d8d3 is closed; use its canonical external-artifact manifest. Missing accepted native equity remains UNAVAILABLE.
Forward Alpha V1/state/source-gap are canonical. Real adapter and Alpha Monitor panel remain BLOCKED_C_ENVIRONMENT_DEPENDENCY until a qualified pre-outcome price source exists; no fixture/decorative Alpha UI.
Master Registry local head 4f9cdd583dffde907191d721e93dcc6498e59f0d remains BLOCKED/A_PRODUCT_DEFECT after repair exhaustion. Preserve both P2 findings and receipt mismatch; no repair-budget reset, PASS-shopping or integration.
Reconcile other-chat Demo vs same-period backtest reporting, user-authored EA/MQL5/strategy-card inventory, and Drive D/EA_LAB_CONTROL/dashboard-retirement receipts. Some work may already be done. Preserve original ownership; no duplicate writers, broad backup or deletion.
First research planning lead: Arxon Stochastic Dual Zone zero-new-MT5 parent/home compatibility. Use accepted source/plan, not rejected Registry rankings. Require a qualified exact parent, direct consumer and explicit role/direction/timing/settings; unresolved semantics remain blocked. Planning is not backtest authorization.
Keep Arxon RSI/MFI/OBV semantic gates; do not reopen Black Tide HYP-SB-005/Boss19 P5, B13/B14 salvage, exhausted XX00 screen, B15 CountBars/BT9 rescue or closed B16 H05/H07/H08/spacing searches.
ORDER-353 stays evidence-only: fresh epoch-2 identity plus later qualifying trade; no forced trade/reattach; first_trade_epoch and judge_date remain null until canonical gates pass. Transport PASS is not RuntimeIdentity PASS.
Use existing bootstrap/Python/Long Job/review/report tools and file-backed PowerShell; verify installed client/auth/model before invoking a model. No Claude dispatch or silent paid fallback. Same-family Codex review is not core-review qualification.
Build the dependency DAG; dispatch independent READY read-only work within WIP<=4 (<=8 isolated batch), serialize overlapping writes, and reserve one Monitor writer. Stop only the affected blocked branch.
Before any actual research/performance work read CLAUDE.md, EA_RND_PROTOCOL.md, EA_REPORT_SCHEMA.md and the exact experiment/family contract. No Model2 performance claims, BWD retuning, HOLDOUT discovery, invented KINT/grade floors or Candidate without frozen same-lineage Model4 MAIN+BWD.
Freeze clean exact HEAD, complete checks and independent required review, preserve negative findings, re-anchor safely on origin movement, FF push only eligible work, then verify fetch AND ls-remote. Never equate tests/commit/remote visibility with all acceptance gates.
No runtime attach-detach-reattach, hosting/Scheduled Task/OneDrive activation, trading/LIVE, risk/default, consequential strategy semantics, signatures, QI-2+, destructive cleanup or history rewrite without the applicable explicit owner approval.
Return concise Thai: FACT status/result + exact canonical SHA; CURRENT/READY/BLOCKED/PARKED; what is executing; UNCERTAINTY; one NEXT action. Keep detailed evidence in artifacts.
End with CLOSEOUT — FINAL SHORT SUMMARY / STATUS / LESSONS / FILES TO CHANGE / NEXT / NEW CONTROL TOWER. Rotate only after actual durable sync, not a tool-window timeout.
```
