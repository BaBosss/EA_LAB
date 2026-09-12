# Optimization region audit — fixture tooling

Status: FIXTURE_ONLY / NO_MT5 / NO_CANDIDATE_AUTHORITY.

This sidecar fills the reusable optimizer result-grid validation gap. It does not
replace parameter metadata surfaces, existing parsers/runners, or the Factory
Candidate gate. The [pipeline audit](../../docs/audits/EA_LAB_OPTIMIZATION_PIPELINE_AUDIT_20260912.md)
records the evidence and boundaries.

## Direct consumer

Control Tower can exercise a proposed surface contract before assigning expensive
tester work. Hermes can consume the JSON diagnostics in its existing fixture batch
workflow. Production wiring requires a separate exact contract and qualification;
nothing here makes a real experiment READY.

From this worktree in PowerShell:

~~~powershell
. ./scripts/use_python.ps1
Assert-PortablePython -Root (Get-Location).Path -Provision
python tools/optimization_region_audit/test_audit.py
python tools/optimization_region_audit/fixtures.py build/region-fixtures
python tools/optimization_region_audit/audit.py preflight build/region-fixtures/stable_plateau/contract.json
python tools/optimization_region_audit/audit.py audit build/region-fixtures/stable_plateau/contract.json --surface build/region-fixtures/stable_plateau/surface.json
python tools/optimization_region_audit/audit.py freeze build/region-fixtures/stable_plateau/contract.json --surface build/region-fixtures/stable_plateau/surface.json --output build/region-center.json
~~~

Exporter requires a new directory; output files use exclusive creation. Choose a
fresh name for another run. No overwrite, tester subprocess, set output, network,
scheduler or runtime adapter exists in the validator. Its Python API is also
importable as tools.optimization_region_audit.audit when the repository root is
on sys.path. The portable Python direct-script bootstraps are included.

For the fixed-MAIN/BWD example:

~~~powershell
$fixture = 'build/region-fixtures/bwd_temptation'
$pin = (Get-Content "$fixture/freeze-pin.txt" -Raw).Trim()
python tools/optimization_region_audit/audit.py verify-bwd "$fixture/contract.json" --surface "$fixture/surface.json" --frozen "$fixture/frozen.json" --freeze-sha256 $pin --fixed-main "$fixture/fixed-main.json" --bwd "$fixture/bwd.json"
# Using tempting-bwd.json instead refuses FROZEN_CENTER_CHANGED.
~~~

The expected freeze pin must come from a trusted, previously frozen contract
record. It is a SHA256 of **canonical JSON** (sorted keys, compact separators,
UTF-8, no trailing newline), not a hash of pretty-printed file bytes.

## Contract and interpretation

The stable_plateau function in fixtures.py is an executable schema example.
Strict key checks reject missing/extra fields instead of discarding semantics.

- Scope must be FIXTURE_ONLY on both contract and rows. This string is a boundary
  declaration, not proof that a caller's data is synthetic.
- logical_change records one declared logical experimental change. Its causal
  meaning remains Control Tower work; the validator cannot infer it.
- identity pins declared source/build/locked-config SHA256 plus installation,
  symbol, timeframe and model. fixture_config_sha256 binds that identity to the
  exact parameter dictionary. These are **synthetic object identities**, never MT5
  set hashes. They detect mismatches; they do not authenticate external EA bytes,
  run receipts, tester results, chronology or ownership.
- axes declares the entire ordered numeric lattice using exact decimal strings.
  Decimal aliases and unordered axes refuse. Row spelling must match exactly;
  parameter names, additional parameters, and locked identity cannot drift.
  Rectangular grids may have nonuniform declared steps; neighbours mean adjacent
  lattice indices. Nothing infers ranges from observed results.
- search declares Complete versus Fast Genetic, COARSE versus LOCAL_GRID, and
  the contract's small-grid cell budget. Small grids require Complete. Genetic
  always returns REGION_MAP_ONLY, even if it visited all coordinates. A bounded
  local Complete contract is needed before center freeze; the tool never widens
  a range or launches missing cells.
- windows uses inclusive ISO dates for MAIN/BWD/HOLDOUT. BWD must precede MAIN;
  MAIN/BWD may not overlap HOLDOUT. MAIN-only rows enter selection. HOLDOUT labels
  and date overlap both refuse. Undeclared prior use or mislabeled external data
  cannot be discovered from these fixtures.
- policy.neighborhood=ORTHOGONAL_STEP_1 requires center plus both adjacent values
  on every axis. Every cell must be mechanically accepted and satisfy every
  supplied eligibility predicate (gt/ge/lt/le).
- policy.rank is a declarative scoring function: ordered metric min/max
  aggregates across the whole neighbourhood, each ascending/descending.
  coordinate_tie_break explicitly orders every axis for a deterministic final
  tie. No executable expressions/callbacks, PF/DD/trade defaults, grade mappings or
  implicit tie-break are accepted. This v1 DSL does **not** implement baseline
  Manhattan-distance ranking or arbitrary callbacks. It cannot exactly replay
  B16 H05/H08 contracts. Unsupported policies need a separately reviewed extension,
  never silent approximation.
- Metrics must be finite JSON numbers (boolean/string/null refused). Metric domain
  rules, such as nonnegative integer trade counts, are not universal here;
  external normalized-input validation and the experiment contract own meaning.
  No strategy grade or KINT sample floor is inferred.

A Complete surface with any missing coordinate refuses all freezing, even when
one cross is present. This conservative design avoids selection from an
incompletely evaluated declared grid. Diagnostics include missing count and up to
ten coordinate-index tuples; they are not a tester job manifest.

FIXTURE_ACCEPTED means only that a complete synthetic grid has at least one
interior cross satisfying the supplied policy. It is neither stable-strategy
proof nor an EA verdict. Policy criteria must express intended stability:
a permissive criterion cannot turn adjacency into economic robustness.

## Freeze and BWD limits

Freeze binds the whole contract, order-independent MAIN surface, exact selected
center and declared identity. Retaining the output hash externally is required.
verify-bwd recomputes the MAIN freeze, checks the external pin, then checks both
fixed MAIN and BWD use that center/identity. BWD must reference the exact
fixed-MAIN receipt hash. A different BWD winner, altered contract/surface/freeze,
cross-install/source/config drift, or mechanical failure refuses.

This proves **fixture lineage consistency only**. It does not compare fixed MAIN
metrics to optimizer metrics, prove chronological execution, or assess whether
BWD validates the strategy. Losing BWD can have valid lineage and returns
strategy_verdict=NOT_ASSESSED. No BWD metric enters center ranking. Authorized
reproduction tolerances and BWD interpretation stay with the future experiment.
It cannot prevent a malicious caller inventing a whole new contract and pin.

The existing _triage/factory_os/candidate.py remains the owner of the frozen
Model4 MAIN+BWD same-install Candidate gate. This helper does not compare M1/M4,
issue Candidate manifests, close KINT-001, spend HOLDOUT, or authorize
risk/default/deployment changes.

## Diagnostics, tests and performance

CLI exit 0: valid fixture preflight/audit/freeze/lineage.
CLI exit 2: refusal **or** a Genetic map that cannot be selected.
Both result and refusal JSON explicitly set candidate_authority=false.

Named fixtures cover stable plateau, isolated spike, boundary winner, missing
neighbour, sparse Genetic, BWD temptation, HOLDOUT contamination, duplicate
coordinates, malformed metric, and mismatched source/config. Tests also cover
row-order determinism, three dimensions, policy direction, aliases, freeze
tampering, diagnostic models, mechanical failures and CLI preservation.

~~~powershell
python tools/optimization_region_audit/benchmark.py --sides 100 200 400 --repeats 3 --output build/region-benchmark-new.json
~~~

[Measured evidence](performance_20260912.json): 10k/40k/160k cells, median audits
0.125/0.509/2.116 seconds. Generation excluded; identity checks included.
Audit uses a coordinate dictionary and O(n*d) neighbour probes for fixed policy
size (no pairwise survivor scan). Freeze also sorts rows for input-order-independent
hashing, O(n log n). Memory is O(n*d); the technical ceiling is one million cells
and sixteen axes. Timings are machine observations, not deterministic outputs or
a universal performance guarantee. Repeated result hashes and exact neighbour
operation counts provide deterministic checks; fixture tests also verify
order-independent freeze hashes.
