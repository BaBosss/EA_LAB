# Monitor V3 operationalization

Implementation contract: 2026-09-10, base `327d01f7a4074b93b824a7b9bec9bc48aa02eea7`.
Scope: read-only presentation tooling. Independent review is required. No runtime activation,
Scheduled Task change, collector invocation, hosting, trading, or owner attestation is included.

## Timestamp/provenance migration (V3.1 bounded repair)

**Dependency expansion authorized (2026-09-11).** The prior hook rejection identified two
required dependencies, now included in the same bounded repair: `snapshot_build.py::_apply_git_head`
derives the producer's verified full lowercase 40-hex Git HEAD and retains refusal of
unverifiable or mismatched claims; `_triage/factory_os/CONTRACTS.md` is regenerated from the
SafeProjection schema using `gen_design_contracts.py`. Independent review remains required;
this continuation does not authorize push or runtime activation.


The Control Room producer emits UTC RFC3339 seconds with Z and a full lowercase 40-hex
Git commit SHA. Git resolution failure leaves the snapshot head null; no identity is invented.
SafeProjection still copies only the verified snapshot's allowlisted fields. Its schema accepts
UTC-Z seconds and legacy timezone-less seconds. The sender boundary retains its shape and
secret checks; no fields or authority are added.

V3 evaluates qualified projection timestamps against the pinned as-of clock using the existing
26-hour freshness bar and five-minute future tolerance. Legacy timestamps remain UNKNOWN;
missing/malformed input remains unavailable/invalid and future observations remain FUTURE.
Refresh never substitutes file mtime or its own clock for the source observation. Missing,
malformed, abbreviated or mismatched snapshot revisions cannot qualify monitoring as CURRENT.
Global `DEGRADED_MONITORING` remains the canonical Git statement. This repair requires independent
review and does not activate runtime, replace a worktree, or change a Scheduled Task.

## Read-only refresh

Run the implementation script with explicit inputs. Use a new output directory for each build:

```powershell
$sha = (git -C $repo rev-parse --verify 'origin/master^{commit}').Trim()
& "$repo/scripts/mobile_monitor_refresh.ps1" `
  -RepoRoot $repo -CanonicalRef $sha -ExpectedSha $sha `
  -OutputDirectory $newOutput -LaneRegistryPath $registryDirectory `
  -SafeProjectionPath $projectionFile -MonitoringSourceRoot $runtimeRoot
```

The caller supplies these paths; there is no implicit runtime checkout, collector, public
target, or Scheduled Task discovery. `CanonicalRef` resolves to exactly `ExpectedSha` or
the build refuses before creating output. This is an exact-pin check, not an attestation
that the supplied SHA was independently accepted. `AsOf` may pin the health/report evaluation
clock for fixtures; a live registry audit retains its actual observation clock.

The entrypoint snapshots registry JSON bytes into private temporary storage, checks the
source file set and hashes before/after, then calls the existing Lane Registry Audit there.
Its lock file never touches the observed registry. Malformed/racing registries refuse;
a missing registry is visibly UNAVAILABLE. This is a bounded file observation, not a
transactional history or a guarantee against changes after the observation.

Monitor health reads the supplied monitoring source, including its actual Git HEAD.
Different or unknown runtime HEAD stays DEGRADED. Snapshot `meta.git_head` is separately
reported and must be an exact full SHA to qualify; legacy abbreviated revisions remain
UNKNOWN, never silently expanded or replaced by current checkout identity. A timestamp
alone does not prove runtime canonicality. Qualified FUTURE observations remain visible.

`build_index.py` reads canonical statements using the exact SHA and sanitizes monitoring
inputs. Static assets are exported from that same Git commit. The executing implementation
tooling may be newer than that data/asset pin; use its frozen reviewed commit for repeatable
tool behavior. Raw Lane Registry exports and monitoring source files remain private and are
removed with the temporary workspace. Output contains the existing report artifacts,
sanitized `report_index.json`, and Git static assets. There is no second source of truth.
Missing monitoring/SafeProjection inputs remain degraded/unavailable. An existing output
directory is refused so an older index cannot masquerade as a successful new refresh.

## Freshness and compatibility

| Input | Machine contract | Legacy handling |
| --- | --- | --- |
| Control Room `meta.generated_at` | Health accepts valid qualified RFC3339 timestamps, normalized to UTC seconds; current <=26h, future >5min | Unqualified INVALID; new producer writes UTC-Z |
| DailyMonitor success file | New writes use `YYYY-MM-DDTHH:MM:SSZ`, only after the existing full-green terminal branch | Old content INVALID for health; existing DateTime parser still accepts new UTC writes |
| SafeProjection `generated_at` | UTC-Z seconds qualify CURRENT/STALE/FUTURE against pinned as-of | Local seconds accepted; freshness UNKNOWN |
| Live evidence filenames | Calendar date only | DATE_ONLY, never invented hourly freshness |

The success marker still means full green. A degraded completion leaves its previous bytes
unchanged. No separate success-like run-observation marker is introduced: the snapshot's
own timestamp already represents its observation.

Consumer audit covered `snapshot_reader.ps1`, snapshot builder/validator tests,
`monitor_health_snapshot.ps1`, `monitor_coverage.ps1`, audit-C fixtures, `safe_projection.py`
shape validation/read-for-send, notifier/sender, S11/S12 fixtures, and Mobile Monitor's
builder, UI and fixtures. The schema migration is covered by S11/S12 and schema fixtures; no consumer
was found that requires the success file's old human/local formatting.

## Validation

Run `scripts/_test/run_mobile_monitor_operationalization_tests.ps1`,
`scripts/_test/run_monitor_health_snapshot_tests.ps1`, the existing Mobile Monitor data and
static UI suites, and `tools/mobile_report_hub/tests/browser_v3.cjs` at 390x844. The new
operational fixture runs only the actual terminal success/failure branch of DailyMonitor,
never its collectors. It covers exact-pin refusal, runtime mismatch, missing inputs,
private registry locks, input byte preservation, UTC green-only success, and output privacy.
Data regressions exercise reported DEGRADED preservation, FUTURE observations and sanitized
revision provenance. Independent review remains required before timestamp migration acceptance.
