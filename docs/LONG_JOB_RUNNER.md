# Long Job Runner

This module provides a detached Windows/PowerShell runner for EA_LAB control flows that need to start a long-running job, return immediately, and inspect the job later.

## What It Does

- `scripts/long_jobs/start_long_job.ps1` creates a job directory first, stages the launch request, starts a detached worker, and returns immediately.
- `scripts/long_jobs/worker_long_job.ps1` starts the requested child process, captures stdout/stderr asynchronously to avoid pipe deadlock, writes heartbeats, enforces timeout, and writes terminal state atomically.
- `scripts/long_jobs/status_long_job.ps1` reports the current durable state and reconciles it with live process state.
- `scripts/long_jobs/wait_long_job.ps1` polls status until terminal or caller timeout.
- `scripts/long_jobs/cancel_long_job.ps1` requests cooperative cancel for the recorded job and only operates on the recorded job-owned process tree.

## State Machine

- `STARTING`
- `RUNNING`
- `COMPLETE`
- `FAILED`
- `TIMED_OUT`
- `CANCEL_REQUESTED`
- `CANCELLED`
- `LOST_PROCESS`

`LOST_PROCESS` is a visible failure mode. A stale heartbeat alone never counts as running.

## Request and State Storage

Each job lives in its own directory under `D:\EA_LAB_CONTROL\jobs` unless `JobsRoot` is overridden.

The start script creates the job directory before launch so duplicate `JobId` values fail closed even if the initiating call crashes immediately after launch.

The launch request is staged in `request.json` only for worker startup. The worker removes that file after reading it. Durable metadata keeps the argument count and hash, not the raw command string.

## Examples

```powershell
& .\scripts\long_jobs\start_long_job.ps1 `
  -FilePath "$PSHOME\powershell.exe" `
  -ArgumentList @('-NoProfile','-Command','Start-Sleep -Seconds 20') `
  -JobId demo-job `
  -TimeoutSec 60 `
  -HeartbeatSec 2 `
  -Json
```

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\long_jobs\status_long_job.ps1 -JobId demo-job -Json
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\long_jobs\wait_long_job.ps1 -JobId demo-job -MaxWaitSec 30 -Json
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\long_jobs\cancel_long_job.ps1 -JobId demo-job -Json
```

## Security And Secret Handling

- Do not pass credentials in arguments.
- The runner does not intentionally persist secrets, but any secrets sent in a child process command line can still be visible to that child and the OS process model.
- Child stdout/stderr is captured durably in the job logs; callers must not emit credentials or other secrets to stdout/stderr.
- Prefer environment-free, file-based inputs for sensitive jobs when possible.

## Recovery Workflow

- If `status` reports `RUNNING`, the worker and child are still active.
- If `status` reports `LOST_PROCESS`, the job metadata exists but the recorded runner or child is gone.
- If `wait` returns `WAIT_TIMEOUT`, the caller timed out, not the job.
- If the worker times out the job, the durable terminal state becomes `TIMED_OUT`.

## Authority Boundary

This module is only an orchestration helper.

- It is not LNWJUD A6.
- It does not grant deployment authority.
- It does not grant trading authority.
- It does not change risk policy, runtime attachment policy, or any strategy semantics.
