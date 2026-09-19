# EA Research Workbook -> EA Template / Factory Bridge V1

Status: `PROSPECTIVE / NON-EXECUTABLE / NON-TRADING / NO NEW AUTHORITY`

This bridge converts an accepted owner-editable Research Workbook draft into deterministic planning artifacts. It does **not** convert browser input into an MT5 `.set`, run the tester, freeze Home/Symbol/TF/settings, authorize optimization, spend HOLDOUT, change risk/defaults, deploy, or trade.

Canonical design base for V1: `018ed2f7379ebaf404444f0d203711379e8f2f22`. The accepted Workbook source remains the independently reviewed `ce5f057c1f5472a686fb1e9006551a9e402c617b`; this bridge is a later separate prospective tooling milestone and does not rewrite Workbook repair history.

## 1. Authority-preserving flow

```text
Workbook Draft
  -> accepted Workbook structural validator
  -> WORKBOOK_PLAN_EXPORT
  -> exact Git source/family/Factory reconciliation
  -> EXECUTION_PROPOSAL (non-executable by default)
  -> canonical/owner freeze gate
  -> existing EA Template / Factory consumers
  -> future approved preset/manifest
  -> deterministic tester execution
  -> accepted evidence
  -> RESULT_BINDING
  -> Workbook/Monitor presentation
```

V1 stops before the owner/canonical freeze. It has no UI or command that launches MT5.

### Exact-byte validation binding
The bridge reads Workbook bytes once, sends that exact immutable payload to the CommonJS validator compiled from the exact Git blob `<ref>:mobile_report_hub/research_workbook.js`, verifies both payload and validator SHA256 receipts, and builds the planning export from the same already-bound payload bytes. A validation receipt cannot be paired with later-mutated Workbook bytes; that mismatch fails closed. No mutable worktree copy of the accepted Workbook validator is treated as canonical.

## 2. Typed artifacts

### WORKBOOK_PLAN_EXPORT
Schema id: `EA_LAB_WORKBOOK_PLAN_EXPORT_V1`.

Carries the validated Workbook revision, exact identity/provenance fields, strategy text, parameter classifications, Symbol/TF proposals, optimization/filter proposals, windows and unresolved owner decisions. Every universe value remains `OWNER_PROPOSAL_UNVERIFIED`. Parameter classification is one of:

- `LOCKED`
- `FIXED`
- `SEARCHABLE`
- `OWNER_REQUIRED`
- `UNKNOWN`

Blank/unrecognized classification becomes `UNKNOWN`; ranges are copied only when supplied and are never manufactured.

### EXECUTION_PROPOSAL
Schema id: `EA_LAB_EXECUTION_PROPOSAL_V1`.

Deterministically reconciles the planning export with exact canonical Git bytes and existing Factory vNext sidecars. It records source/factory/set references and blockers. V1 deliberately emits:
- `authority = NON_EXECUTABLE_PROPOSAL_ONLY`;
- `optimization.authority = NOT_GRANTED`;
- `set_output.generated_from_workbook = false`;
- `holdout.spend_authorized = false`.

`can_execute` stays false while any canonical identity, Home/TF/settings, build, parameter or optimization authority is unresolved.

### RESULT_BINDING
Schema id: `EA_LAB_RESULT_BINDING_V1`.

Defines the future link from an accepted run to a Workbook revision: run/cell identity, manifest/set/source/build hashes, install/model/window, Symbol/TF, metrics, year split, report/graph/evidence locators and verification state. The V1 fixture emits `UNAVAILABLE_NO_ACCEPTED_RUN` with null metrics; it never fabricates results.

Machine-readable structural contracts live in `tools/research_workbook_bridge/artifact_schemas.json`.

## 3. Canonical mapping

| Workbook surface | Canonical owner / resolver | Workbook write status | Required validation | Downstream consumer | Block condition |
|---|---|---|---|---|---|
| schema / revision / owner draft | `mobile_report_hub/research_workbook.js` | editable proposal | accepted Workbook parser/validator bytes must match exact ref | bridge | malformed/authority-forging draft |
| family / EA / variant / parent | Factory family/variant artifacts + exact source | proposal until reconciled | exact IDs + Git source hash | EA Template / Factory | missing/mismatched family/variant/source |
| strategy / BUY / SELL / mechanics | canonical EA source, strategy card/family contract | proposal/description only | no semantic inference | family implementation contract | unresolved or conflicting semantics |
| source ref / SHA | pushed Git exact ref | proposal must match fact | regular Git blob + SHA256 | Factory/build gate | missing/mismatch/symlink |
| build / EX5 | accepted compile/build evidence | proposal only | exact artifact/hash | tester manifest | absent/unbound build identity |
| parameters | Factory parameter surface + PARAM_REGISTRY + source input surface | proposal only | name/class/value/range consistency | preset compiler after authority | UNKNOWN/OWNER_REQUIRED/conflict/incomplete range |
| Home Symbol / TF | owner/canonical family contract + TestUniverse/LogicalSymbol | proposal only | exact frozen record | TestUniverse / tester manifest | no accepted freeze / no canonical universe |
| broker symbol | `LogicalSymbol.broker_map` | not inferred | exact lane mapping | tester profile | mapping absent/ambiguous |
| profile/environment | `factory/instrument_profiles.jsonl` + exact contract | proposal only | profile id/version/hash/layer | preset compiler/tester | absent/mismatched profile |
| optimization proposal | EA_RND_PROTOCOL + OPTIMIZATION_PROCEDURE + exact experiment contract | proposal only | preregistered MAIN-only ranges/stage | optimizer only after authority | no authority, missing range, BWD/HOLDOUT selection |
| MAIN/BWD/HOLDOUT windows | exact experiment contract | planning declaration | role/state/date validation | tester manifest | HOLDOUT not locked / unapproved role |
| filters/modules | canonical source/family semantic contract | proposal only | qualified formula/version/role/timing | implementation/experiment contract | semantic gate unresolved |
| owner-entered result rows | Workbook only | editable UNVERIFIED | never accepted as evidence | presentation only | always unverified until result binding |
| accepted run evidence | report package / run manifest / evidence owners | read-only link | hashes + install/model/window identity | RESULT_BINDING / Monitor | missing or conflicting evidence |

## 4. Existing Factory reuse and explicit exclusions

V1 reuses current Factory vNext artifacts instead of creating another Factory:
- `variant_build_package.json`;
- `parameter_surface.json`;
- `mt5_set_compat_manifest.json`;
- `artifact_index.json`;
- existing full-surface preset compiler contract.

The B11 fixture references `factory/vnext/pilots/boss11_h01_first_green` only as a deterministic compatibility/provenance specimen. Those files are `NON_AUTHORITATIVE_SIDECAR`; their existence is not execution authority.

The bridge does **not** call `scripts/gen_plan_set.py`. Its generic A-E ranges are not a lawful source of Workbook search ranges. It also does not call `run_factory_vnext_pilot.ps1`, MT5, optimizer launchers, Hermes execution, or report collectors.

## 5. TestUniverse / LogicalSymbol blocker

The current schema declares `TestUniverse` and `LogicalSymbol` under the canonical owner path `factory/universe.jsonl`. At the V1 base, that store is intentionally absent/blocked by current registry governance. Therefore a Workbook symbol or timeframe cannot become an executable Home merely because it was typed into the browser.

The synthetic `TestUniverse` fixture only proves the required/enumerated shape can be read from the existing schema. The execution proposal still reports `CANONICAL_TEST_UNIVERSE_UNAVAILABLE` and `can_execute=false`.

## 6. Non-trading fixture acceptance

Fixture path:
`tools/research_workbook_bridge/fixtures/workbook_plan_b11_fixture.json`

Expected proof:
1. canonical Workbook validator accepts the plan as planning-only;
2. B11 source ref/SHA is retained and matches exact Git bytes;
3. existing Factory package/set identities are read, not regenerated;
4. `LOCKED`, `OWNER_REQUIRED` and `UNKNOWN` parameter states are retained;
5. no Home Symbol/TF is invented;
6. no optimizer range is invented;
7. HOLDOUT stays `LOCKED_UNSPENT`;
8. execution proposal returns `can_execute=false`;
9. result binding stays `UNAVAILABLE_NO_ACCEPTED_RUN`;
10. two runs produce byte-identical output package files.

This fixture is `NON_TRADING_FIXTURE_ONLY` and is not permission to backtest B11 or any other EA.

## 7. Future transition condition

A later real execution proposal may become eligible only after the existing canonical owners supply all required facts: exact family/source/build, frozen Home/Symbol/TF/settings, accepted parameter classifications and values/ranges, exact MAIN/BWD contract, tester installation/model/data identity and explicit optimization authority where applicable. The downstream implementation must then use the existing Factory/preset/tester/report paths and preserve BWD/HOLDOUT rules. Workbook UI alone can never satisfy that gate.
