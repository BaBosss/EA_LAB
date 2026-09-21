# EA_LAB Local Control Collector V1

## Boundary

The collector is a one-shot, read-only observation tool. It performs routine local
inspection before GPT reasoning and emits the closed
`EA_LAB_LOCAL_CONTROL_COLLECTOR_V1` JSON packet. It has no authority to mutate EA
runtime, jobs, the Lane Registry, Codex databases, repository evidence, profiles,
hooks, services, or schedulers. `runtime_mutation` is always `false` and
`installation_actions` is always empty.

The implementation and schema are under `tools/local_control_collector/`. The tool
reuses the canonical interfaces rather than reproducing their decisions:

- Lane Registry: `scripts/lane_registry.ps1 -Command Audit`, followed by exact
  `Get` calls to obtain each lane's allowed and critical paths.
- Long Jobs: `scripts/long_jobs/status_long_job.ps1` and
  `scripts/execution_reliability/inspect_before_retry.ps1`.
- Process inspection occurs only inside those canonical status/retry interfaces to
  resolve recorded identity. The collector does not enumerate processes for work
  discovery.
- Codex counters are read from `state_5.sqlite` and `thread_history_1.sqlite` using
  SQLite URI `mode=ro`, which preserves live WAL visibility while denying writes.
  The collector does not modify
  `tools/codex_budget/usage_reporter.py` or reinterpret its counter semantics.

## Invocation

Select the repository's portable Python first:

```powershell
. scripts/use_python.ps1
python tools/local_control_collector/collector.py `
  --repo-root . `
  --current-lane ct-example `
  --codex-home C:\operator\codex-home
```

Default output is stdout only. Remote master observation is on by default, while
fetch remains opt-in:

- By default the collector runs `git ls-remote origin refs/heads/master`;
  `--skip-remote-observe` explicitly disables it.
- `--fetch` explicitly runs `git fetch origin master` and also observes the remote.

Local `origin/master` is always inspected when present. A disabled or failed remote
lookup remains `UNKNOWN`, never PASS.

Deterministically relevant durable jobs are explicit:

```text
--lane-job LANE_ID=JOB_ID
```

Evidence is explicit with repeated `--evidence FILE`. V1 recognizes only the
closed `EA_LAB_REVIEW_RESULT_V1` and `EA_LAB_SCRUTINY_RESULT_V1` objects containing
exactly `schema_version`, `verdict`, `confidence`, `decision`, `findings`, and
`reviewed_head`. Each accepted object carries its source SHA256. Any other,
missing, or malformed contract is `UNKNOWN`.

## Codex identity and counters

An exact optional mapping has this form:

```text
--thread-identity THREAD_ID=LANE_ID[,MILESTONE[,AUTHOR|REVIEWER]]
```

Only exact thread IDs are mapped. Duplicate conflicting mappings are `AMBIGUOUS`;
there is no fuzzy title or prompt assignment. Labels are bounded to 96 characters,
line-folded, and scrubbed for common secret fields and absolute user paths. Prompts
are never emitted. When no exact mapping supplies a label, the output uses only a
bounded thread-ID label; the initial prompt is not queried or emitted.

`current_lifetime_tokens` is the current lifetime thread counter. It is never a
billing, quota, credits, allowance, cost, savings, or plan-remaining value. Snapshot
comparison produces:

- `INITIAL`: no prior exact thread ID; delta is null.
- `DELTA_OK`: current counter is at least the previous counter; delta is nonnegative.
- `COUNTER_DECREASED_UNKNOWN`: the counter decreased; delta is null.
- `UNKNOWN`: either counter needed for comparison is null/invalid; delta is null.

Daily aggregation uses only `DELTA_OK` rows. It groups by exact lane, deterministic
milestone, model, reasoning effort, and deterministic author/reviewer role. Unknown
identity remains an explicit `UNKNOWN` group. For the recognized V3 database layout,
invocation count is the number of exact-ID rows in canonical `thread_turns`. For the
recognized legacy layout it is the number of local `assistant` history items. It is
not a provider-request, quota, or billing counter. Any other database layout is
unavailable rather than heuristically parsed.

`--observation-threshold LOW --observation-threshold HIGH` changes only the
`WITHIN_OBSERVATION`/`ELEVATED`/`HIGH` descriptive signal. Values must be increasing
nonnegative integers. These signals make no quota or cost claim.

## Optional output and snapshot ledger

`--output-root ABSOLUTE_PATH` creates an exclusively named packet and appends one
snapshot row to `snapshots.jsonl`. The root must be operator supplied and must not
overlap the repository. The Codex databases and evidence inputs are never output
targets. Reusing the same observation timestamp refuses to overwrite the existing
packet. Ledger rows use the closed identity `EA_LAB_LOCAL_CONTROL_SNAPSHOT_V1`.

Each packet binds the collector and packaged schema bytes with SHA256. Recognized
evidence has its own source binding. The JSON schema is closed, and the runtime
validator rejects unknown top-level, section, thread, job, and evidence fields.

## Known limitations

- Remote freshness is unknown unless explicit remote observation succeeds.
- Registry status is unavailable when its canonical Audit/Get interface cannot be
  opened (including lock permission failures).
- Jobs are observed only when exact lane/job pairs are supplied. V1 does not infer
  relevance from names or process listings.
- Review parsing is deliberately limited to the two recognized closed contracts.
- A missing, corrupt, schema-incompatible, or duplicate-thread Codex database is
  unavailable/partial; its data is not guessed.
- Snapshot deltas measure change between successful local observations, not activity
  confined to a civil-day boundary.

## Verification

```powershell
. scripts/use_python.ps1
python tools/local_control_collector/tests/test_collector.py
python -m py_compile tools/local_control_collector/collector.py tools/local_control_collector/tests/test_collector.py
git diff --check
```
