# EA_LAB optimization pipeline audit — 2026-09-12

Status: BOUNDED TOOLING / FIXTURE_ONLY / NO_MT5.
Task contract: owner PROMPT 3, QRESET-03-OPTIMIZATION-TOOLING, 2026-09-12.
Can do: bounded tooling engineer · Suggested: Codex.
Reviewer: separate read-only GPT tooling reviewer; no different-family trading
review or production acceptance is claimed.

## Anchor, scope and method

Fetched origin/master at boot. **BASE_SHA =
74dac79aadd1210c09b77e644f507a42bae1f570**. All existing implementation findings below
refer to those canonical bytes, not the unrelated dirty primary worktree.
Final implementation HEAD is the commit containing this report (resolve with
git log for this path); no moving origin ref or self-referential hash is used.

Final detached worktree:
D:\EA_LAB_WORKSPACE\worktrees\qreset03-opt-tooling-20260912.

Lane Registry read through scripts/lane_registry.ps1 against
D:\EA_LAB_CONTROL\lanes\registry-v1. Only QRESET-01-HARNESS-PERF was an active writer
at the initial compact inspection; its critical paths were disjoint.
QRESET-03 initially used an incorrectly nested workspace path; it was paused and
superseded by QRESET-03-OPTIMIZATION-TOOLING-R2 after a checked git worktree move to
the exact owner path. Same BASE, files and task scope; no tester lane claimed.
The registry preserves that correction. Existing dirty/staged primary work was
not used as source or reset, stashed, cleaned or staged.

Boot owners read: START_HERE.md, PROJECT_STATE.md, AGENTS.md,
AGENT_TASKBOARD.md and targeted active-board entries, EA_RND_PROTOCOL.md,
EA_REPORT_SCHEMA.md, OPTIMIZATION_PROCEDURE_V2.md. CLAUDE.md was used for current
production verdict/fidelity semantics only. H05/H08 were read as accepted workflow
examples, never as permission for a new search. No new taskboard or governance
contract was invented; the direct owner prompt bounds this lane.

Audit method: targeted source search across scripts, tools, Factory OS/vNext and
accepted B16 run packages, followed by implementation reads. Independent read-only
source audit confirmed the reusable gap. No web research was needed for this
repository-only implementation audit.

## Current pipeline

Every row distinguishes existing machinery from the manual responsibility.
File references identify evidence owners; none of the proposed opportunities
grant execution or selection authority.

| Step | Existing implementation at BASE | Manual step | Failure mode | Evidence owner | Automation opportunity | Risk of automation |
|---|---|---|---|---|---|---|
| Preregister | Research protocol §1/4; taskboard H05/H08 exact hypotheses, frozen mechanics and lattices | Control Tower declares causal question, one logical change, authorized stage, rules and stopping branch before results | Hindsight rules, mixing parent/child mechanics, using an old range as authority | [Research protocol](../research/EA_RND_PROTOCOL.md), [taskboard H05/H08](../../AGENT_TASKBOARD.md) lines 193–198 | Validate required fields and exact contract pin before dispatch | A well-formed manifest does not prove preregistration or authorization |
| Search manifest | H05 run_opt01.ps1 lines 7–20,53 binds hypothesis/build/set/output receipts; Factory metadata surfaces and optimize guard exist | Translate the exact contract into sweep dimensions and fixed identities | Implicit ranges, wrong hypothesis binding, extra mutable parameters | [H05 runner](../../factory/runs/b16_opt01_20260831/gbp_sell_h4/run_opt01.ps1), [parameter metadata](../../_triage/factory_vnext/parameter_surface.py) lines 87–166 | Explicit lattice cardinality and method preflight | Do not replace parameter roles or treat a surface as a READY execution contract |
| Tester input | mt5_optimize.ps1 lines 147–160 identity checks, 188–190 INI fields; optimize_guard.ps1 lines 633–737 binding/UNBOUND refusal | Resolve approved lane/model/window and serialize exact optimizer flags/set | Caller model/date mistakes; wrong installation or stale binary | [MT5 optimizer launcher](../../scripts/mt5_optimize.ps1), [optimization guard](../../scripts/optimize_guard.ps1) | Reuse canonical runner guards under a future real-adapter contract | Launcher accepts an integer Model at line 30; it alone does not encode every current research restriction |
| Results parse | H05 analyze_opt01.py lines 9–34; H08 analyzer lines 10–37 preserve SpreadsheetML indexed cells and convert fields | Check native units/schema, rejected runs, source-report provenance | Malformed/nonfinite metrics, conflated parameter identity, dropped fields | [H05 analyzer](../../factory/runs/b16_opt01_20260831/gbp_sell_h4/analyze_opt01.py), [H08 analyzer](../../factory/runs/b16_h08_20260831/usdjpy_buy_h1/analyze_h08_opt01.py) | Strict normalized JSON input for fixtures; future parser adapter can feed it | No raw XML/report authentication is supplied by this new module |
| Surface completeness | H05 lines 36–39 checks all 20 coordinates, duplicates/extras; H08 lines 38–49 emits missing cells | Compare observed results against preregistered lattice, not observed axes | Sparse Genetic mistaken for Complete; duplicate rows hide a missing cell | Same experiment analyzers and optimizer_surface.csv artifacts | Reusable exact coordinate index, missing count/sample, duplicate/off-lattice refusal | Never infer full coverage from row count alone |
| Plateau/region detection | H05 lines 48–62 and H08 lines 51–65 inspect interior orthogonal crosses, minimum net/trades, maximum DD and contract tie-breaks | Supply experiment-specific eligibility and ranking; interpret boundary pressure | Top-1 spike, boundary winner, permissive policy mislabeled robust | Same analyzers plus selection.json/plateau_candidates.csv | Generic contract-supplied predicates/aggregate ranking and eligible interior enumeration | Local geometric eligibility is not proof of economic robustness or a grade |
| Neighbour completion | H05 contract permits bounded Complete completion within original lattice; H08 emits missing coordinates and refuses selection | Obtain exact bounded completion contract and run only missing authorized cells | Widening by habit; new search disguised as completion | [H05 contract](../research/B16_GBP_SELL_H4_OPT01_CONTRACT.md) §54-line context; H08 missing-cell artifacts | Missing diagnostics before a future executor spends tester time | This helper prints diagnostics only; never launches, expands or approves cells |
| Center freeze | H05 build_validation_package.py lines 17–21 binds selection and fixed-set hash, search-closed lock | Preserve the selected center and trustworthy pre-BWD pin | Mutable selected JSON or regenerated center after BWD | [H05 package builder](../../factory/runs/b16_opt01_20260831/gbp_sell_h4/build_validation_package.py) | Immutable output with contract/surface/config hash | Hash declarations cannot prove external provenance or temporal order |
| Fixed MAIN reproduction | H05 run_center_validation.ps1 lines 17–38 checks clean HEAD/lane/hash/values/ancestry; lines 49–51 fixed runs | Interpret reproduction tolerances and native metric/path differences | Same label with different binary/config/install; bad reproduction hidden by optimizer result | [Fixed-center runner](../../factory/runs/b16_opt01_20260831/gbp_sell_h4/run_center_validation.ps1) | Fixture receipt linkage; preserve existing real wrapper for future qualification | The helper does not compare optimizer and fixed-MAIN metric values |
| BWD | Same runner fixes MAIN then BWD on same set; lock declares validation-only | Validate/falsify the frozen hypothesis, preserve failure and stop/park under contract | Retuning to a tempting BWD alternative; cross-install comparison | Same fixed-center runner and experiment validation lock/results | Refuse center/source/config/install changes and require fixed-MAIN receipt hash | Valid lineage is not successful BWD; no BWD metric may rank centers |
| Reporting | Canonical schema fields, report ladder and B16 aggregate surface/year/validation summaries | Separate facts, interpretation, verdict and known unknowns; explain paths/exposure | PF/DD-only report, invented grade, omitted failed rows | [Report schema](../research/EA_REPORT_SCHEMA.md) §§6–10, experiment result owners | JSON diagnostics and hashes reusable by Control Tower/Hermes reports | A green tool badge cannot substitute for the full research evidence chain |
| Model4 gate | candidate.py new_candidate_gate_problems lines 527–600 resolves distinct Model4 MAIN/BWD, installation/config identity and no-retuning; enforced at write line 821 and CLI build line 932 | Assess current fidelity/verdict criteria and other required evidence | Candidate before M4, one run relabeled twice, missing or changed lineage | [Candidate implementation](../../_triage/factory_os/candidate.py), [production gate](../../CLAUDE.md) lines 63–81 | **Already implemented; reuse, do not duplicate** | No new Candidate gate/threshold/default is authorized here |

## Missing capability and obsolete paths

A reusable strict optimizer-results rectangular-surface validator was not found.
There are working experiment-specific implementations; there is not an absence
of plateau thinking.

The [legacy selector](../../scripts/select_robust_pass.py) embeds historical
PF/DD/RF gates at line 24. Its plateau_center function (84–113) infers varying
axes/steps from observed rows and scans each survivor against all other survivors:
O(n²). It counts neighbours without requiring the complete preregistered lattice.
The public select_robust entrypoint refuses by default without explicit legacy
opt-in (116–125); do not bypass that quarantine.

The vNext parameter_surface module is metadata/identity, not an optimizer outcome
surface. [optimize_next_step.ps1](../../scripts/lib/optimize_next_step.ps1) lines
32–35 routes selection to a hypothesis contract rather than inventing a formula.
[run_optimization.ps1](../../scripts/run_optimization.ps1) lines 29–39 is a
placeholder. [optimize_loop.ps1](../../scripts/optimize_loop.ps1) lines 1–13 records
HOLDOUT-BURNED history and routes to the old selector after launching; it is not a
safe current workflow template.

Historical H05 ran Genetic on 20 cells (run_opt01.ps1 line 35). Preserve that
accepted evidence as history. This lane's explicit small-grid → Complete rule
controls new tooling. OPTIMIZATION_PROCEDURE_V2 contains older stage vocabulary,
numeric example gates and ordering; newer research-method/production owners and
the explicit task invariants prevent interpreting them as authority to select
Genetic Top-1, spend HOLDOUT early or skip the universal pre-Candidate M4 pair.
No policy document was edited to resolve those differences.

## Implemented bounded helper

[tools/optimization_region_audit](../../tools/optimization_region_audit/README.md)
adds only a standard-library Python sidecar, named fixture builders/exporter,
behavioral tests, performance probe and measured JSON.

Actions: preflight, audit, freeze, verify-bwd. All accepted outputs and refusals
declare FIXTURE_ONLY and candidate_authority=false. Unknown fields/policies
refuse. Metrics must be finite numeric values; exact parameter strings retain
identity, numeric aliases and duplicate coordinates refuse.

Complete selection demands the entire declared rectangle, interior centers and
all orthogonal one-step neighbours. The contract supplies every predicate,
ranking aggregate/direction and final coordinate tie-break. There are no universal
PF/DD/trade/grade thresholds in the validator. Example numbers live only in
synthetic fixtures. Small-grid size is supplied by the contract; the one-million
cell/16-axis caps are technical resource limits.

Genetic output is always REGION_MAP_ONLY and cannot freeze, even at full observed
coverage. Sparse/missing-grid diagnostics cannot launch completion or widen
ranges. Freeze binds the whole supplied MAIN surface and policy to a center.
BWD verification accepts only that frozen center, checks declared source/build/
locked-config/install/model identity, and links the fixed-MAIN receipt.

Important limits:

- Synthetic hashes verify consistency of supplied data, not authentic external
  EA/build/config/report bytes, execution chronology or preregistration.
- The v1 scoring DSL supports min/max neighbourhood aggregates and ordered axis
  ties. It does not express B16 baseline-distance ranking or arbitrary callbacks;
  it does not claim exact B16 replay. Unsupported policies require explicit work.
- No raw XML/CSV parser adapter, tester adapter, Candidate manifest, set file,
  strategy interpretation or production integration was added.
- Fixed MAIN metric reproduction and BWD economic validation are not performed.
  A losing BWD may return FIXTURE_LINEAGE_VALID with strategy_verdict=NOT_ASSESSED.
  The reviewer must evaluate the experiment's authorized tolerances and falsifier.
- Scope tags and declared dates cannot detect an external caller lying about
  prior HOLDOUT use. Trustworthy provenance remains an upstream responsibility.

## Required invariants retained

One variant declares one logical change; causal sufficiency remains a human/
Control Tower judgment. Small grids use Complete. Larger MAIN Genetic maps
regions only; no Genetic Top-1 is selected. Complete bounded neighbours precede
center freeze. The frozen center precedes fixed MAIN/BWD; BWD never retunes.
HOLDOUT never enters selection. No universal grade/participation mappings were
invented. **KINT-001 remains OPEN.** Model2/Open Prices/Math are diagnostic only and
refused by this selection helper. New Candidate still requires frozen Model4
MAIN+BWD same-install lineage through the existing gate. This task grants zero
Candidate/risk/deploy authority.

## Fixture evidence

Command, in the isolated worktree:

~~~powershell
. ./scripts/use_python.ps1
Assert-PortablePython -Root (Get-Location).Path -Provision
python tools/optimization_region_audit/test_audit.py
~~~

Final focused run: **37/37 PASS**, 1.416 seconds (portable Python 3.12.10).
An earlier direct-script import failure exposed portable Python's isolated import
path; adding an explicit local-module path in test/fixture entrypoints repaired
it. No runtime/global environment or production source changes were needed.
Separate read-only tooling review independently reproduced the pre-export-test
suite, 36/36 PASS in 0.541s, and found no blocking defects. The final added test
exercises the new exporter and every named scenario through the CLI.

| Synthetic case | Expected/observed behavior |
|---|---|
| Stable plateau | Nine eligible centers on 5×5; declared tie selects (1,1) |
| Isolated spike | No eligible interior center; no freeze |
| Boundary winner | Boundary Top-1 cannot become center |
| Missing neighbour | Complete-grid refusal with exact missing count |
| Sparse Genetic | Region map only; no freeze |
| BWD temptation | Alternative positive BWD center refuses; losing frozen BWD is retained without verdict |
| HOLDOUT contamination | Label or inclusive date overlap refuses |
| Duplicate coordinates | Duplicate coordinate refuses, even with extra row count |
| Malformed metric | String/bool/null/NaN/Infinity refuses |
| Config/source identity mismatch | Fixture hash/source/build/install/config drift refuses |

Additional cages cover changed policy/tie direction, row-order determinism,
three-dimensional crosses, decimal spelling, missing policy, diagnostic models,
tampered freeze/contract/surface, mechanically rejected receipts, duplicate JSON
keys, exclusive output creation, CLI codes and exported-fixture replay.

## Performance

Command: benchmark.py --sides 100 200 400 --repeats 3.
[Raw timing/count/hash evidence](../../tools/optimization_region_audit/performance_20260912.json).

| Cells | Eligible centers | Neighbour probes | Median audit seconds | Freeze seconds |
|---:|---:|---:|---:|---:|
| 10,000 | 9,604 | 38,416 | 0.124762 | 0.172383 |
| 40,000 | 39,204 | 156,816 | 0.509018 | 0.669907 |
| 160,000 | 158,404 | 633,616 | 2.116001 | 2.810540 |

Windows 11, portable Python 3.12.10; 3 audit repetitions/size. Fixture generation
excluded; row identity hashing included. Each 4× cell increase cost approximately
4.08× and 4.16× audit time, consistent with linear scaling rather than an all-pairs
scan. This is observed evidence, not a formal complexity proof or timing SLA.
Dictionary neighbour lookup is O(n*d) for fixed policy size; freezing additionally
sorts rows, O(n log n). Repeated audit hashes match; tests verify shuffled surface
order produces identical freeze bytes. No MT5 lane or strategy performance was
measured.

## Direct consumer and integration boundary

Future Control Tower tasks can run preflight on proposed **fixture** contracts
before expensive runtime dispatch, then audit completed synthetic grids before
interpreting Top-1. Future Hermes fixture batches can ingest the JSON diagnostics;
the existing [Hermes batch executor](../../tools/hermes_ea_lab_pilot/scripts/batch_executor.py)
remains its own authority boundary.

Integrate this as optional fixture-only tooling plus documentation after normal
scoped checks/review. No existing execution or research consumer was switched.
Real source-authenticated parser/runner integration, arbitrary scoring extensions,
fixed MAIN numerical tolerances and production use require a separate contract.

Requested disposition: commit locally, **do not push**. Audit/tooling completion
does not claim canonical integration or whole-system production PASS. Commit
hooks and final clean-worktree status are reported with the exact HEAD in the
handoff; generated status uses the canonical worktree-aware script, without
publishing primary monitoring/OneDrive state.

NO AUTHORITY FOR: choosing a real EA, strategy optimization, MT5 execution,
Candidate/DEMO/LIVE promotion, HOLDOUT spending, Grade/KINT decisions, risk/default
changes, deployment/runtime attachment, trading, governance changes or push.
