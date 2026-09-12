# Research preflight: offline contract consistency

This opt-in tool checks a frozen contract against preserved INI/config/build identity and expected evidence. It never starts MT5, edits files, claims a lane, approves a contract, changes verdicts, or selects strategy thresholds. It reuses the repository report parser and report-package path/image helpers.

**PASS means OFFLINE_CONTRACT_CONSISTENCY_ONLY.** Every result keeps `authority_granted:false` and successful inspections keep `live_lane_eligibility:UNKNOWN`. A copied identity receipt is an assertion to compare, not authenticated evidence of current account/lane ownership. Continue to use the existing runtime, build, full-surface and research gates.

## Invocation

From the isolated checkout, first dot-source `scripts/use_python.ps1`. The source repository must have HEAD equal to the contract's source SHA; it may be a different, pinned checkout from the one containing this tool. Hashes below must come from the frozen, reviewed contract/envelope, not be silently regenerated to accept changed bytes.

```powershell
python tools/research_preflight/preflight.py pre-run --contract D:/package/contract.json --contract-sha256 <frozen-sha256> --source-repo D:/pinned-source --artifact-root D:/package
python tools/research_preflight/preflight.py post-run --contract D:/package/contract.json --contract-sha256 <frozen-sha256> --source-repo D:/pinned-source --artifact-root D:/package --observations D:/package/observation.json --observations-sha256 <frozen-sha256>
python tools/research_preflight/test_preflight.py
python tools/research_preflight/test_preflight.py --benchmark
```

Output is JSON on stdout. Exit codes: `0 PASS`, `2 REFUSE`, `3 UNKNOWN`. Invalid CLI syntax uses argparse's exit 2. Reason codes are emitted per cell; structural failures may stop a cell before later problems are checked. REFUSE outranks UNKNOWN. UNKNOWN is never an implicit pass.

## Contract `research-preflight/1`

Top-level fields are closed: `schema`, `contract_id`, `source_sha` (40 lowercase hex), `source_path` (repository relative), `hypothesis`, `revision`, `parent`, `holdout`, `cells`. Identity strings must be nonempty. HOLDOUT has inclusive `from_date`/`to_date` in `YYYY.MM.DD`; every declared MAIN/BWD interval must be disjoint from it. No discovery access to HOLDOUT is supported.

Each cell has exactly:

| Field | Required meaning |
|---|---|
| `cell_id`, `pair_id`, `window` | Unique cell, within-install comparison group, MAIN or BWD. At most one of each window per pair. The reviewed contract must declare the complete planned population; this checker cannot detect an omitted experiment. |
| `expected` | String fields: symbol, tf, leverage (`1:N`), model (`0`,`1`,`4`), from_date, to_date, optimization (`0`,`1`,`2`), forward (`0`), deposit, currency, expert, installation, installation_lineage, account_identity, lane, report_name, tester_report_path, launch_ini_path. Last two and installation are absolute Windows paths; lane1 Model4 uses `MT5-lane1` and `D:\Meta 5`. This only encodes the existing static restriction, not live exclusivity. |
| `parameters` | Exact full contract-approved raw string key/value surface, including any `||` optimization syntax. INI and SET must both match it exactly. Unknown means unknown to this contract, not source-type discovery. Reuse the existing source compiler/full-surface check first. |
| `effective_config` | Explicit expected effective-config object, compared to the bound identity receipt. Empty/missing proof remains UNKNOWN; normalization semantics must be supplied by the existing config guard. |
| `inputs` | Six bindings: ini, set, ex5, build_receipt, source_manifest, identity. Each is exactly `{path,sha256}`, paths relative to artifact root. |
| `outputs` | Planned package-relative paths for report, log, year_split, metrics, truncation. `expected.report_name` is the exact raw INI Report value; `tester_report_path` is the original tester output location; collected package path is separate. Never rewrite an old INI to fit the package. |
| `native_graph_required`, `graph_paths` | Boolean and nonempty array of planned package-relative native graph files. Missing mandatory graph REFUSE; optional missing graph UNKNOWN. Unsafe graph always REFUSE. |
| `end_condition` | `FULL_WINDOW`. Other end policies are unsupported, not guessed. |

The INI must be UTF-8 or BOM-marked UTF-16, with exactly `[Tester]` and `[TesterInputs]`, no DEFAULT inheritance or external `ExpertParameters` override. Required Tester keys use exact MT5 spelling from `INI_KEYS` in the tool; auxiliary Tester keys remain governed by the existing runner. The SET accepts semicolon comments and exact `key=value` lines. Binary/graph/config hashes bind raw bytes. Relative artifact paths reject escape/reparse components. No paths are dereferenced from web content.

Input identity JSON has exactly `source_sha`, `source_path`, `identity` (equal to expected), `lane_state` (`RUNNING`), `runtime_legal` (true or UNKNOWN), `requested_config` (equal to parameters), `effective_config`. `launch_ini_path` is a *bound claimed launch location*, while returned `ini_resolved_path` proves the actual preserved file read. A historical launch path absent from preserved evidence must not be invented to satisfy this schema.

Build receipt uses existing `build_receipt/1`: nonempty build_receipt ID, artifact_sha256 equal to EX5 binding and source_sha256 equal to wrapper source hash. Select the exact existing receipt row, rather than invent one. Source manifest has `source_sha`, `source_path`, `files` mapping each declared repository path to SHA-256. Each is read from `git show SHA:path`. This verifies declared files, not include-graph completeness; the existing build/source-surface checks remain required.

## Post-run envelope

Schema `research-preflight-observation/1`, with `contract_sha256` matching the separately pinned raw contract and `cells` mapping exactly every contract cell ID. Each cell contains `{path,sha256}` bindings for report, log, year_split, metrics, truncation, plus `graphs` as an array of bindings. Paths must equal the predeclared output plan. Metrics JSON must exactly equal `scripts/parse_mt5_report.py` output. Reports must be compatible with that parser; unsupported/localized formats refuse or remain UNKNOWN, never inferred.

Truncation consumes existing schema_version 2: CHECK_PASS + integer checker_exit_code 0 + truncated false. True/TRUNCATED refuses; any unproven checker outcome remains UNKNOWN. It does not independently establish that a quiet strategy ran to the end. Use the existing truncation checker and preserve its output.

## Deliberate limits / integration boundary

- No new MT5 adapter, no integration into hooks/runners, no batch scheduling. The current runner writes INI immediately before launch and has no generic prepare-only handoff; a future reviewed adapter must expose immutable prepared inputs before the launch step. Do not run a tester merely to obtain an INI for this tool.
- Hash binding proves byte consistency, not that an arbitrary receipt is truthful. No current live lane, account login, source graph completeness, strategy semantics or reviewer authority is authenticated.
- Logs and year splits are checked for bound nonempty presence. Year arithmetic, basket-unit provenance, chart meanings, R1/R2/R3/R4 report completeness and research acceptance remain with existing consumers.
- Image path closure, signature and hash cannot prove a curve is the native MT5 Balance/Equity graph. Never recreate missing native graphs. Fixtures contain signature bytes only and are explicitly synthetic.
- Optimization INI is checked pre-run. Optimizer XML post-run acceptance is unsupported and reports `OPTIMIZER_XML_POSTRUN_UNSUPPORTED`; the existing optimizer guard and selected-point validation remain necessary. No full optimizer acceptance claim.
- All files should be immutable while inspected. HEAD is checked before/after; this is not an atomic filesystem snapshot or a remote-origin watcher. The worker must separately enforce the moving-origin freeze rule.

The fixture factory in `test_preflight.py` is the executable complete schema example. It creates only temporary synthetic evidence and never represents a preregistered experiment.
