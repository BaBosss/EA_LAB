# Monitor source adapters V1 — initial author continuation

Lane: `ea-observation-adapters-v1-20260923`. Owner: `EA_LAB-MONITOR-CONSOLIDATION-20260921`.
Continuation authority: owner amendment of 2026-09-24 and the original `AUTHOR_CONTRACT.md`.
Implementation base: `1df924b1ac7e112148dd8a70773c8c63b0b9a893`.

This is scoped source WIP for CT intake, freeze and one separate GPT Scrutiny. It is not acceptance,
deployment, runtime qualification or a UI delivery. The historical unsuccessful jobs and artifacts are
unchanged. At initial delivery the prospective post-review source repair was 0/1 used; the Repair1 record
below supersedes that budget status. Monitor truth is already canonical;
the historical Wave2A blocker is not a dependency of these readers.

## Consumer and boundary

### Bounded post-review Repair1, 2026-09-24

Same lane, with Repair1 **1/1 consumed**. Reviewed candidate
`4fa15d48acc239b655266377f96ae64a548afbb9` was byte-reanchored onto parent
`5bce751a8e092bf0515c3ce57549c3a90cdcc983`. The initial acceptance result was
`SCRUTINY_REPAIR_REQUIRED / HIGH / BLOCK_INTEGRATION`; targeted recheck remains pending CT freeze.

The bounded changes address OA-001/002/003 only: malformed filename suffixes retain an unambiguous
account association solely for withholding, never source acceptance; affected snapshots withhold latest
and ledger aggregates, and rejected ledger files withhold aggregates regardless of discovery order.
Snapshot row account-binding conflicts propagate to ledger eligibility with the explicit reason
`SNAPSHOT_ACCOUNT_BINDING_CONFLICT`. List/object identity-state values return the existing fixed
`CONTROL_ROOM_IDENTITY_STATE_INVALID` refusal and leave unaffected observation sections available.
No schema authority, UI hookup, upstream source, runtime or qualification change is introduced.

Six exported-builder regressions were run RED before implementation changes. External repair evidence,
native exits, source inventory and delivery result live under
`D:\EA_LAB_CONTROL\evidence\ct-clearance-20260924\adapter-repair1`.
Repair validation: impacted suite 52/52 passed; complete suite 73 run, 72 passed and one native symlink
privilege skip, including all original 67 tests. The reused 16-test contract receipt is bound to unchanged
dependency bytes. Historical real-source output is preserved and was not regenerated for this repair.
This is unstaged WIP for CT-owned hooks/freeze and one targeted independent recheck, not self-acceptance.

The direct consumer is `build_observations(BuildRequest(...))`, returning a typed `Observations` dataclass
with typed `Section` envelopes. `to_dict()` produces the versioned JSON observation payload. The eventual
integration owner is the existing `tools.mobile_report_hub.owner_webapp.model.Model.snapshot` pipeline.
There is no import, UI wiring, scheduler, exporter, capture, service or runtime activation in this package.

| Priority | Delivered responsibility | Explicit remaining qualification |
|---|---|---|
| 1 | Reference existing Collector/Monitor ownership | Work/job/state/freshness truth stays with those accepted owners |
| 2 | Full-history dedup, conflict quarantine, Decimal component attribution | Fee, cycle IDs, full lifetime coverage, UTC and runtime attribution unavailable |
| 3 | Per-field snapshot observations, latest partial values, intervals and conflicts | Existing exporter and account owner omit broker/server identity; qualified broker series unavailable |
| 4–5 | Config/context provenance and existing identity diagnostics; null effective signals | No accepted identity-bound effective guard event schema exists in inspected producers |
| 6–7 | Per-deployment expected/observed identity comparisons and declarative mapping | Source/binary evidence and runtime qualification remain with existing identity authority |
| 8 | Source ownership, deterministic diagnostic IDs and access-mode distinctions | Alerts/storage remain existing Monitor surfaces; no access qualification or activation |

Unavailable real data is an explicit result, not an invented positive fixture or an implementation claim.
No guard input envelope is introduced that could supersede `runtime_identity/1`. A future effective-state
producer requires its own accepted source schema and qualified identity/event contract before an adapter
extension may interpret it. The current callable consumes the existing `ControlRoomSnapshotV5` diagnostics;
even exact matching identity fields do not promote effective state or attribution eligibility.

## Calling and isolation

Use the CT-provisioned portable Python. Dot-source `scripts/use_python.ps1`, call
`Assert-PortablePython -Root $resolvedRepoRoot -Provision`, and insert the resolved repository root into
`sys.path` exactly once in an isolated launcher. No `PYTHONPATH`, global Python, installation or extra model
is needed. Example launcher code, after the launcher has resolved its explicit repository argument:

```python
sys.path.insert(0, str(resolvedRepoRoot))
from tools.mobile_report_hub.source_adapters import BuildRequest, build_observations

observations = build_observations(BuildRequest(
    repo=resolvedRepoRoot,
    ref=exact_commit_sha,
    ledgers=declared_export_root,
    snapshots=declared_snapshot_root,
    runtime=declared_existing_runtime_root,
))
payload = observations.to_dict()
```

CLI module: `tools.mobile_report_hub.source_adapters`. Required arguments:
`--repo`, `--ref` (full 40-character commit), `--ledgers`, `--snapshots`, `--runtime`.
Optional `--as-of` accepts strict UTC `YYYY-MM-DDTHH:MM:SSZ` for deterministic observation comparisons.
Without it, read time is the current UTC clock. It is not a producer timestamp or broker clock conversion.
Optional `--output` creates exactly one new JSON file beneath the existing
`build/ea_observation_adapters_v1/continuation-20260924/` directory. It refuses overwrites and other paths.
Without `--output`, stdout contains only the masked JSON. CLI input errors emit fixed codes and exit 2;
a successfully built observation may contain unavailable sections and source errors and exits 0.
Exit 0 is neither real-data qualification nor acceptance.

For isolated tests the generated `run_tests.py` records the exact resolved-root launcher. Run the module
`tools.mobile_report_hub.source_adapters.test_adapters` through that launcher. It exercises the exported
builder, actual filesystem readers, and a populated native CLI subprocess against immutable canonical
metadata. Temporary fixtures remain under this continuation run root. No fixture creates Git commits.

## Source and safety contracts

Canonical account, deployment and runtime-identity metadata are read from regular Git blobs at the explicit
commit, never from a dirty primary checkout. Parser lineage is pinned in `builder.PARSER_CONTRACTS` to the
exact exporter, snapshot header, canonical enum-owner and shared JSON/UTC-contract bytes inspected at the
base. A changed producer/schema fails closed and needs an explicit reader-contract update. Parsing uses
the existing pure JSON/UTC helpers and canonical deal enum constants. Existing broad Monitor builders and
the identity validator are not called: those have incompatible mappings, additional path insertion, or
receipt-driven disk reads outside this reader's declared source boundary.

MT4 account snapshots use the same pinned column/row contract from
`tools/AccountSnapshot/AccountSnapshotExporter.mq4`; their platform remains distinct in output. This does
not interpret MT4 order-history exports as MT5 deal events. Missing MT4 deal history remains unavailable.

Local reads are nonrecursive and limited to declared roots. File grammar, exact exporter columns, duplicate
CSV/JSON fields, numeric syntax, enums and currency/account bindings are checked. Unknown added deal columns
(including a newly introduced fee schema) are refused; only the already-known optional `time_unix` is allowed.
UTF-8/UTF-8-BOM is supported; unsupported encoding is unavailable, not silently repaired.

The default hard ceilings are 800 files, 8 MB per file, 128 MB total, 1,000,000 CSV rows and 2,000 entries in
each explicit directory listing. Callers may lower these ceilings, never raise them. These are input resource
budgets, not trading or risk thresholds. Files are read twice with identity/size/mtime/link-count checks and
equal bytes; path and handle ctimes are each compared through their own API because this Windows Python 3.12
build gives `stat` and `fstat` different ctime semantics. Source hashes bind the bytes actually parsed.
Traversal, UNC/device paths, alternate streams, hardlinks, symlinks and reparse ancestors are refused.
The tests include a real Windows junction and a privilege-dependent native symlink test.

Output identifiers are domain-separated opaque SHA256 keys. There are no raw account/ticket IDs, source
private paths, input comments, arbitrary producer reasons or credentials in the output. Source references
contain opaque IDs, byte sizes and SHA256 hashes. Error/finding IDs are deterministic projections of fixed
codes, ownership and source keys; their suggested next action is nonexecuting. These are reader diagnostics,
not a second alert engine. No notifications or storage scans occur.

## Accounting and time semantics

`tools/DealsExporter/DealsExporter.mq5` emits the numeric MT5 `DEAL_TYPE` and `DEAL_ENTRY` values owned by
`_triage/factory_os/runtime_identity.py`. Trading component aggregation includes BUY/SELL types 0/1 with
entries 0/1/2/3, including entry-side costs. Types 2–17 are excluded as non-trading cashflow; an unknown type
is invalid. Reversals and partial closes remain deal events. `deal_count` is not a count of completed cycles.

Dedup identity is bound account plus ticket. All normalized shared exporter fields must agree. Optional
`time_unix` absence/presence does not make another financial event. Known conflicting values or an invalid
copy quarantine that ticket across the whole supplied export set. Known text/epoch time values must agree
in the same naive broker coordinate; this check grants no UTC interpretation. A malformed file or unkeyed
row withholds that account's aggregates. Quarantined items carry opaque deal keys and exact fixed reasons.

Money is parsed as finite fixed-point `Decimal`; the accumulation precision covers the bounded input width
and row count. Results separate profit, swap, commission and their reported-components subtotal. Fee remains
null and cost completeness false. There is no all-cost net-profit claim, PF, win rate, deposits-adjusted
return, per-EA equity inference, performance verdict, score or new risk policy. USD and USC remain separate.
An absent ledger has null deal count; a valid header-only ledger has observed count zero. Exported history
does not prove lifetime completeness.

Deployment attribution requires one exact eligible `ACTIVE` account+magic+symbol declaration. Ambiguous,
multi-symbol and missing mappings are explicit. Canonical identity pins and mapping-source hashes are
referenced independently. Declarative mapping does not establish current runtime attribution eligibility.

Snapshot values retain AVAILABLE/MISSING/INVALID/CONFLICT per field. Latest incomplete observations remain
latest; they are never replaced with older complete values. Invalid files that might hide the latest value
withhold `latest`. Identical timestamps merge provenance; conflicting same-time observations have null
metrics and are excluded from calculations. Current floating values come only from that exact snapshot.
No MAGIC rows is explicitly not zero-floating proof. Multi-symbol floating baskets are not split or inferred.
An observed snapshot/canonical currency conflict also withholds ledger aggregates for that account.

Snapshots and deals use `BROKER_TIME_UNQUALIFIED`. Neither `TimeCurrent()`, `DEAL_TIME`, `time_unix`, file mtime
nor the date in a filename establishes UTC or freshness. First/latest source times and elapsed intervals
are descriptive; every interval is marked unobserved between samples, without interpolation or a new gap
threshold. Since broker/server is absent from both current snapshot and account schemas, samples remain
explicitly unqualified source observations: `qualified_series`, broker and server are null. They are not a
broker-qualified account history, calculation input or chart product.

## Guard and deployment evidence

The dated NewsGuard runbook hash is configuration context only. Calendar and MRIS sources receive separate
hash/time provenance; they cannot become effective NewsGuard/MacroGate state. Missing and observed false are
not interchangeable: no supported source currently supplies the effective boolean, so it remains null.
Unplanned geopolitical news is not synthesized. No filter policy or pre/post window is changed.

Returned ControlRoom identity FAIL remains FAIL. Expected map pins are compared with existing returned
`runtime_identity/1` records by exact account/magic and identity fields, including binary/config receipt,
symbol/timeframe and attach epoch. Missing, duplicated, mismatched, future or unqualified-clock observations
remain gaps. The identity timestamp age check references the existing owner's age constant; no new TTL is
defined. ControlRoom generation age itself is descriptive and has no adapter freshness threshold.
Matching fields never substitute for complete source/artifact/accepted freshness evidence. Neither first
trade nor judge date is derived or rewritten, including ORDER-353 semantics.

## Evidence and handoff

New evidence is confined to `build/ea_observation_adapters_v1/continuation-20260924/`:
durable checkpoints, raw native stdout/stderr and exits, focused tests, reused-contract tests, compile/diff
checks, one explicit existing-source observation build, masked before/after manifests and privacy checks,
`AUTHOR_RESULT.json`, and `delivery_manifest.json` with per-file hashes. See the result for final counts,
native exits, limitations and the hash of the actual output. Historical intermediate failures are preserved.

Final author gates: 67 focused tests (66 passed, one native symlink privilege skip), 16 reused contract
tests passed, source compile and whitespace checks passed. The real Windows junction test passed. The first
existing-source build exposed the compatible MT4 snapshot gap; its output is preserved as `observations.json`.
The targeted author-phase compatibility recheck is `observations-final.json`: six snapshot accounts, two
accounts without deal ledgers, no quarantined shared-field deal conflicts, and three unbound-metadata source
errors. It retains producer runtime identity FAIL and all guard/access qualification gaps. Both reads have
equal before/after source manifests and no private-identifier matches. This ordinary initial-author test
correction does not consume or reset the prospective post-review repair budget.

Only `tools/mobile_report_hub/source_adapters/**` and this document are source WIP. The worker does not stage,
commit or push. CT owns normal hooks, exact-head freeze, the one separate acceptance review, and eligible
fast-forward integration. The source package carries no self-review receipt or acceptance claim.
