# Control Tower Relay MVP contract

`ControlTowerRelay` is the backend seam. A future MCP frontend should import it
and expose only these bounded operations:

- `dispatch_codex(task_id, prompt, timeout_seconds=None)` creates a new random
  `job_id`, stores the exact UTF-8/byte prompt and SHA-256, and starts one fixed
  `codex exec --json --sandbox read-only --cd <cwd> -`
  invocation. On Windows the installed `codex.cmd` shim is invoked through the
  fixed `cmd.exe /d /s /c` wrapper because the packaged Store executable is not
  directly launchable by this user. It returns immediately with `RUNNING` or a
  clear `FAILED` state.
- `get_codex_status(job_id)` polls one job and returns its explicit state.
- `get_codex_result(job_id)` performs one bounded read of the persisted latest
  terminal result plus complete raw stdout/stderr. Repeated reads are
  idempotent; they never select or overwrite another job's evidence.
- `continue_codex(job_id, prompt)` starts `codex exec resume <session-id>` for
  the same logical job, preserving the same `job_id` and adding a new attempt
  directory. It refuses when no session identity is available.
- `cancel_codex(job_id)` cancels only the in-memory process handle created by
  this relay. A reloaded process cannot kill a PID it did not create; it marks
  the job `FAILED: PROCESS_LOST` instead.

Persisted terminal states are `DONE`, `BLOCKED`, `FAILED`, and `CANCELLED`.
Intermediate states are `QUEUED`, `RUNNING`, and `CONTINUING`. Each job has an
independent directory under `state_dir/jobs/<job_id>/`; each attempt has its
own prompt and raw stdout/stderr/result files. Metadata and result JSON are
written through a temp file followed by `os.replace`, and hashes are checked on
result retrieval.

The relay is not an authority layer. It does not expose shell commands, choose
arbitrary executables, deploy or attach EAs, trade, alter risk defaults, or
promote DEMO/LIVE state.
