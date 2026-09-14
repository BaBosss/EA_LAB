# Forward Alpha Discovery V1

Authority: `RESEARCH_ONLY` / `DISCOVERY_ONLY`, `REAL_TRADING_OFF`,
`NO_PROMOTION_AUTHORITY`. Repository-only Python sidecar for Control Tower intake.
Implementation base: `aec3dd24160e8e79c9ec42d1145a6f0fa1189df3`;
branch/lane: `ct/forward-alpha-v1-20260914` / `ct-forward-alpha-v1-20260914`.

This module retains source-bound forward observations and later market outcomes.
Its descriptive groups and hypothesis proposals do not own strategy truth,
verdicts, Candidate selection, experiments, or any trading/risk/runtime policy.
The existing observation contracts, research catalog, Control Center modular
plan, EA R&D Protocol and EA Report Schema remain unchanged owners. Forward
market returns are not trade PF, execution evidence, or strategy profitability.

## Source and observation contract

The public API is `tools.control_center.forward_alpha`. A `Ledger(directory)`
may write only inside a descendant directory of this module, for example
`tools/control_center/forward_alpha/data/my-contract`. It uses `events.jsonl`;
the module creates no database, external registry, UI, service or scheduler.

`observe(raw, expected_source=...)` and `settle(raw, expected_source=...)` take
exact UTF-8 JSON source bytes. The caller supplies a separately pinned descriptor:

```json
{"source_id":"market-feed","ref":"evidence/market.json","sha256":"<64 lowercase hex>","canonical_sha":"<40 lowercase hex or null>"}
```

The source bytes contain exactly this envelope:

```json
{"source_id":"market-feed","ref":"evidence/market.json","canonical_sha":"<40 lowercase hex or null>","available_at":"2026-01-01T00:00:00Z","payload":{}}
```

`ref` is a safe relative repository evidence reference, never a URL or absolute
path. No source path is automatically opened. Source ID, ref and canonical SHA
must match the descriptor, and SHA256 must match the exact supplied bytes.
`canonical_sha: null` explicitly means non-Git source; applicability is the
intake caller's responsibility. A canonical source must carry its actual pin.
The source provider/adapter must produce the envelope; wrapping unrelated bytes
and calculating a new hash does not establish external provenance.

Observation payload fields (all required, no extra fields):

| Field | V1 semantics |
| --- | --- |
| `schema`, `observation_id` | `forward_observation/1`, safe opaque unique ID |
| `observed_at` | UTC `YYYY-MM-DDTHH:MM:SSZ`; source `available_at <= observed_at` |
| `symbol`, `timeframe` | Source-bound opaque labels |
| `strategy`, `family`, `variant`, `regime` | Required opaque research identities; `UNKNOWN` refused |
| `direction` | `UP`, `DOWN` or `UNSIGNED`; no inferred direction |
| `horizon` | Exactly `{"kind":"ELAPSED_SECONDS","seconds":3600}`; positive integer |
| `config_sha256` | Exact SHA256 or explicit `UNKNOWN` |
| `authority` | Exactly `RESEARCH_ONLY` |
| `snapshot_sha256` | Exact SHA256 of the frozen feature/context bytes, retained by source owner |
| `reference_price` | Positive finite source price at the observation, in the same price basis as settlement |

V1 chooses the hash-only context alternative. Source confidence/components may
be retained in those frozen source-owned context bytes; this module never
calculates or invents confidence. Context availability and the correspondence
between its hash and external retained bytes are the caller's evidence duty.

## Settlement and ledger behavior

Settlement payload requires `schema: forward_settlement/1`, `observation_id`,
`observation_sha256` (the exact hash returned by `observe`), `end_at` and
`end_price`. Optional `high_price` and `low_price` must be provided together.
The endpoint must equal `observed_at + horizon.seconds` and be strictly later
than observation. Outcome source `available_at` must be at or after endpoint.
No nearest-bar selection, rounding, trading calendar, timezone inference or
HOLDOUT selector exists. Bar/session horizons need a future explicit contract.

Forward return is `(end_price - reference_price) / reference_price`, in fractional
units. Signed return multiplies by +1 for UP or -1 for DOWN. A directional hit
means signed return > 0; zeros count in the denominator and as zero evidence.
UNSIGNED records retain forward returns but have no hit or signed statistic.
Supplied high/low prices must cover the start and endpoint. MFE is the maximum
signed price excursion and MAE the minimum (nonpositive), using the same start
denominator; V1 trusts the source assertion that extrema cover the whole horizon.
Missing extrema stay null. No commissions, execution, spread, PF or trade metrics
are synthesized. Nonfinite numbers and overflowing results refuse.

Each event retains base64 exact source bytes, descriptor, previous event hash
and canonical event hash. Reads revalidate the entire chain, source binding,
observation and settlement contracts. An exact duplicate returns its existing
hash without changing bytes. Different source bytes, including whitespace,
under the same observation/settlement identity refuse. Negative records have
the identical acceptance and retention path as positive records.

An exclusive lock serializes reads and appends; a busy/stale lock refuses and
is never automatically removed. Writes flush/fsync. An interrupted partial line
refuses; recovery requires a separate authorized reconciliation. There is no
update/delete/repair API. Store resolution must remain inside the module.

## Queries, projections and usage

`summarize(ledger, query)` requires explicit `group_by`, `omitted_dimensions`,
`start_at`, `end_at`, `as_of`, and `filters`. The observation window is half-open
`[start_at, end_at)`, ending no later than `as_of`. A settlement available after
`as_of` counts as open in that projection. Query filters are exact allowed-value
lists on the dimensions; the full request is copied into the output.

All dimensions must occur exactly once across grouping and deliberate omissions:
`symbol`, `timeframe`, `strategy`, `family`, `variant`, `regime`, `direction`,
`horizon_seconds`, `config_sha256`. There is no implicit grouping default.
Omitting all dimensions deliberately requests a pooled group. Group IDs hash
the chosen identity. Source identity may differ within a group: exact coverage
and evidence references remain visible; this is not a portability assertion.

Groups contain settled count, signed sample count, signed positive/negative/zero
counts, open count, hit rate, mean/median signed return, extrema summaries with
their own coverage counts, observation times and source coverage. Every matching
observation appears in the evidence list with its source and event hashes; every
available settlement appears alongside it. Open-only groups remain visible.
An optional `minimum_sample` is labeled `CALLER_SUPPLIED`; both qualifying and
nonqualifying groups remain, with a nullable `caller_minimum_sample_met` flag.

```python
from pathlib import Path
from tools.control_center.forward_alpha import Ledger, canonical, summarize, hypotheses, snapshot
from tools.control_center.forward_alpha.sidecar import DIMENSIONS

ledger = Ledger(Path('tools/control_center/forward_alpha/data/my-contract'))
# Source bytes and descriptor come from the source owner's pinned evidence.
observation_hash = ledger.observe(observation_bytes, expected_source=observation_descriptor)
# Later: settlement bytes bind observation_hash and the exact horizon endpoint.
ledger.settle(settlement_bytes, expected_source=settlement_descriptor)
query = dict(group_by=list(DIMENSIONS), omitted_dimensions=[], filters={},
             start_at='2026-01-01T00:00:00Z', end_at='2026-01-03T00:00:00Z',
             as_of='2026-01-04T00:00:00Z')
table = summarize(ledger, query)
presentation_bytes = canonical(snapshot(ledger, query))
# Selection is an explicit caller research choice, never an automatic threshold.
proposal = hypotheses(ledger, query=query, selected_group_ids=[table['groups'][0]['group_id']])
```

`decay(ledger, prior=..., recent=...)` requires nonoverlapping chronologically
ordered slices with otherwise identical query inputs. It emits raw recent-minus-
prior deltas for count, hit rate and mean signed return; missing sides yield
null, not zero. Both full summaries are retained. No STABLE/DECAY classifier.
Concurrent append between the two reads refuses instead of mixing ledger heads.

`hypotheses` rederives selected groups from the ledger, retaining their complete
evidence, nonpositive counter-evidence IDs and the full queried summary including
unselected groups. It emits proposals for Control Tower intake only. It cannot
write either Master Registry or open an experiment. `snapshot` returns JSON-ready
data headed with the three authority labels above, with no UI integration.

## Limits and validation

This is source-bound chronology, not a trusted timestamp or independent witness
that a human had not already seen future outcomes. Source clocks, price basis,
feature construction and source authenticity require qualified intake outside
V1. The local chain detects ordinary corruption, but cannot detect a complete
rewrite/re-hash or removal of whole trailing events without an externally pinned
head. Keep accepted ledger heads in normal canonical evidence custody. The
module is append-only through its API, not tamper-proof against filesystem owners.
It assumes a trusted repository filesystem, not hostile concurrent junction edits.

All reads scan the full ledger and summaries retain full evidence. This favors
auditability over large-dataset throughput; the presentation snapshot is a simple
JSON seam and is not size-capped. Selection bias, overlapping observations and
multiple comparisons remain research limitations. No inferential significance,
causal claim, universal sample floor or alpha qualification follows.

Validation commands (portable Python, no runtime/MT5):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/_test/run_forward_alpha_tests.ps1
. ./scripts/use_python.ps1
$pythonExe = Assert-PortablePython -Provision
& $pythonExe -B tools/control_center/forward_alpha/run_tests.py --impacted
git diff --check
```

The focused entry point compiles all four Python files in memory (no bytecode
writes to shared owners), runs 40 tests and exits nonzero on failure or empty
discovery. Fixtures cover all ten contracted adversarial cases plus raw-byte
idempotency, time windows, open/unsigned evidence, extrema, invalid query inputs,
lock/corruption refusal, overflow and deterministic output. The impacted runner
loads existing Control Center contract and research-catalog suites unchanged.
Normal-tooling read-only review identified the numeric overflow edge; its repair
and adversarial tests are included. This is not different-family risk review.

No push is authorized. The general post-commit `make_status.ps1` is not run by
this bounded task because its writes to canonical STATUS/OneDrive fall outside
the explicit allowed paths. No shared owner/status/taskboard is changed.
