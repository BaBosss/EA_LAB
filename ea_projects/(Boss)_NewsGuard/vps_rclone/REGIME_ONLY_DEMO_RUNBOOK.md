# MacroGate DEMO regime-only VPS transport readiness

## Authority boundary

Purpose: keep `EA_LAB_mris_regime.csv` fresh for the accepted DEMO MacroGate without publishing, scheduling, attaching, or modifying NewsGuard/REAL runtime.

This file is a repository readiness contract only. It does **not** authorize Windows Task creation, VPS mutation, runtime attachment, trading, risk/default changes, or NewsGuard task edits. Actual scheduling requires a separately owner-authorized runtime lane.

Repository-proven entrypoint: `C:\rclone\pull_regime.cmd` beside `pull_guard_feeds.ps1`. The entrypoint invokes the worker with `-RegimeOnly`, so the fetch allowlist contains only `EA_LAB_mris_regime.csv`.

The worker validates the selected regime file, preserves the existing `Common\Files` copy on failure, and atomically replaces only `EA_LAB_mris_regime.csv` after validation. In RegimeOnly mode it must not create, replace, delete, validate, or fetch `EA_LAB_news_week.csv`.

## Proposed Windows Task Scheduler contract

- Task name: `EA_LAB_MacroGate_RegimeOnly_Pull`
- Program: `C:\Windows\System32\cmd.exe`
- Arguments: `/d /c ""C:\rclone\pull_regime.cmd""`
- Start in: `C:\rclone`
- Trigger: daily at `00:17` VPS-local time, repeat every **4 hours** for 1 day; `Start when available = true`.
- Multiple instances: `Do not start a new instance`.
- Execution time limit: **15 minutes**; a timeout is failure, not GREEN.
- Run whether the user is logged on or not.

The `00:17` phase is a deterministic proposal, not proof of collision safety. Deployment must run the collision precondition below against the actual VPS task inventory before registration.

## Cadence and freshness proof

Repository-proven upstream publication uses `scripts\publish_guard_feeds_to_vps.ps1` with default `RegimeMaxAgeHours=30`. The VPS worker uses default `RegimeMaxAgeHours=36`.
A 4-hour pull cadence means a regime file that was still valid at the upstream 30-hour publication boundary is normally fetched by the VPS before about 34 hours of source age, leaving 2 hours before the VPS 36-hour refusal boundary. This is the reason for 4 hours; it is not an arbitrary convenience interval.

If a run is missed, delayed long enough to consume that margin, or the staged source is already stale, the worker must refuse it and return non-zero. Do not widen `RegimeMaxAgeHours=36` to hide scheduler failures.

## Run-as requirements

`FUTURE RUNTIME PRECONDITION`: resolve the actual Windows identity at deployment time. The repository does not prove the current VPS account name.

The selected identity must have:

- read/execute on `C:\rclone\pull_regime.cmd`, `pull_guard_feeds.ps1`, and `rclone.exe`;
- read access to `C:\rclone\rclone.conf` without exposing its OAuth token;
- read/write/delete/rename access to `C:\rclone\staging\lab-to-vps\news`;
- read/write/rename access to the terminal's **actual** shared `Common\Files` directory;
- append access to `C:\rclone\logs\pull_guard_feeds.log`;
- outbound network access required by rclone/OneDrive;
- no requirement for broker credentials or interactive broker-login authority.

Do not assume `Administrator`, `SYSTEM`, or any historical account string. At deployment, verify the resolved identity can access the rclone config and the actual terminal Common folder before task creation.

## pull_news collision / non-overlap contract

Simultaneous `pull_news.cmd` and `pull_regime.cmd` execution is **PROHIBITED**. Both invoke the same worker, staging directory, regime target, and log. The non-RegimeOnly path removes selected staged targets including `EA_LAB_mris_regime.csv` before fetch, so overlap can create a delete/fetch/validate race even though final publication is atomic.
`FUTURE RUNTIME PRECONDITION`: before creating the proposed task, enumerate all Windows scheduled-task actions and identify any enabled or running task whose action/arguments reference `pull_news.cmd` or `pull_guard_feeds.ps1` without `-RegimeOnly`.

Activation rule:

1. If no such enabled/running task exists, continue only after the run-as/filesystem checks pass.
2. If such a task exists, **STOP**. Do not disable, reschedule, edit, or replace it from this MacroGate lane because that would modify NewsGuard runtime. Escalate that runtime coordination as a separate owner-authorized action.
3. A same-task `Do not start a new instance` setting is not sufficient cross-task serialization and must not be treated as collision proof.
4. Scheduler registration is not GREEN until one complete regime-only run passes the fail-visible checks below.

This fail-closed rule removes schedule-guessing: the readiness contract never assumes an old `pull_news.cmd` cadence, task name, or run duration that the repository cannot prove.

## Fail-visible contract

The `.cmd` entrypoint propagates `%ERRORLEVEL%`. The PowerShell worker exits non-zero for rclone failure or selected-feed validation/publication failure and writes `FAILED` to `C:\rclone\logs\pull_guard_feeds.log`.

A successful scheduler invocation is **not** sufficient evidence. GREEN requires all of:

- Task Scheduler `LastTaskResult = 0` for the completed run;
- log suffix `guard feed pull COMPLETE: MacroGate regime-only feed validated and published atomically`;
- `EA_LAB_mris_regime.csv` exists in the resolved Common folder and is not older than the 36-hour worker limit;
- no NewsGuard file hash/content change attributable to the regime-only run.
Missing/stale output, non-zero result, missing final success suffix, task timeout, or unresolved collision state is RED. Do not report GREEN from "task started" or rclone invocation alone.

## Last-good behavior

Repository-proven failure behavior is preserve-in-place: validation/fetch failure does not replace the existing Common `EA_LAB_mris_regime.csv`. That existing Common file is the only repository-defined last-good state for a failed attempt.

There is **no repository-defined versioned backup** for restoring a file after a successful atomic replacement is later judged semantically wrong. In that case:

1. disable the proposed regime-only task;
2. do not copy from staging merely because a file exists there;
3. restore only from a separately trusted backup/quarantine copy whose provenance and hash are known;
4. if no trustworthy copy exists, **REFUSE RESTORE** and leave the task disabled rather than fabricate state.

## Rollback procedure

Repository-only rollback before deployment: revert this readiness commit if needed; no VPS state exists to undo.

Future runtime rollback, only after separately authorized deployment:

1. disable `EA_LAB_MacroGate_RegimeOnly_Pull` and capture its last result plus the tail of `pull_guard_feeds.log`;
2. do not disable/edit/delete any pre-existing `pull_news.cmd`/NewsGuard task;
3. leave the current Common regime CSV in place unless a trusted last-good restore is explicitly available;
4. remove the new task only after evidence capture; task-history deletion is not part of first rollback;
5. roll back only files that were explicitly deployed for this regime-only task, using the exact prior hashes/package; do not touch MT4/MT5 attachments or risk/defaults;
6. verify NewsGuard file/task state is unchanged from the pre-deployment capture.

## NewsGuard non-interference proof

Repository evidence proving the boundary:
- `pull_regime.cmd` calls the shared worker with `-RegimeOnly`.
- In `pull_guard_feeds.ps1`, RegimeOnly fetch selection contains only `EA_LAB_mris_regime.csv`.
- `Publish-Staged 'NewsGuard' ...` executes only when `-not $RegimeOnly`.
- The existing guard-feed pipeline test hashes a sentinel NewsGuard Common file and staged NewsGuard file before RegimeOnly execution and asserts both hashes remain unchanged.
- This readiness correction does not edit `(Boss)_NewsGuard` EA source, any NewsGuard task, REAL runtime, MT4/MT5 attachment, strategy semantics, risk/defaults, or deployment inventory.

If a future deployment requires disabling/rescheduling an existing `pull_news.cmd` task, this MacroGate contract does not grant that authority; stop for the separate owner runtime decision.

## Operator readiness checklist before any future activation

- [ ] owner has explicitly authorized actual VPS scheduling/deployment;
- [ ] exact accepted repository/package hashes for `pull_regime.cmd` and `pull_guard_feeds.ps1` are recorded;
- [ ] actual VPS Common folder is resolved from terminal UI/runtime evidence, not inferred from install path;
- [ ] run-as identity and required ACL/network access are verified;
- [ ] no enabled/running conflicting `pull_news.cmd` or non-RegimeOnly shared-worker task exists;
- [ ] proposed task settings exactly match this contract;
- [ ] pre-run NewsGuard file hash/task state is captured read-only;
- [ ] one manual **task invocation** after registration produces exit 0, exact success suffix, fresh Common regime file, and unchanged NewsGuard hash;
- [ ] any failed item leaves the task disabled and is reported RED.

No item above authorizes deployment by itself. The runtime lane must stop before registration unless owner authorization for persistent scheduling exists.
