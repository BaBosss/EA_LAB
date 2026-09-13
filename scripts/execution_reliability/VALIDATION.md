# PowerShell watchdog validation — 2026-09-13

Status: **PASS / TRUSTED-ROOT SMOKE PASS / REPO-ONLY**.

Final canonical re-anchor base: `a1a0965b4ca6fef05340b810fdc6b09adbe560f8`.
Final acceptance worktree: `D:\EA_LAB_CONTROL\worktrees\norton-ps-hardening-final-20260913`.
Original six-file author bytes were copied from the prior `45319cd...` worktree with SHA-256 equality before revalidation. `origin/master` had moved, so acceptance was repeated on the fresh base.

## Environment

- Host: `BaBoss`.
- Interpreter: `D:\EA_LAB\tools\python312\python.exe` (CPython 3.12.10).
- Trusted temp: `D:\EA_LAB_CONTROL\trusted_exec\temp`.
- Durable logs: `D:\EA_LAB_CONTROL\trusted_exec\logs`.
- Effective PowerShell policy: `CurrentUser=RemoteSigned`; other scopes observed `Undefined`.
- The watchdog does not override execution policy and does not persist environment changes.
- Norton configuration/exclusions were **not** changed by this repository validation.

## Acceptance evidence

| Check | Result |
| --- | --- |
| Python `py_compile` for runner/job/tests | PASS |
| Default trusted-root integration suite | **11/11 PASS** — 9 tests launch real PowerShell; 2 are pure policy/cleanup tests |
| Trusted-root production smoke | **PASS / SUCCESS / exit 0** |
| Owned timeout descendant cleanup | PASS |
| Ordinary nonzero script failure: no retry | PASS |
| Simulated abrupt termination: at most one retry | PASS |
| Repeated abrupt termination: fail closed | PASS |
| Literal argument handling + output privacy | PASS |
| Containment-assignment failure: target never runs | PASS |
| Cleanup boundary / sibling preservation | PASS |

Final smoke run ID: `36e40575f5ef4f30b73d84e8d60b18ec`.
Its child PowerShell used `D:\EA_LAB_CONTROL\trusted_exec\temp\attempt-36e40575f5ef4f30b73d84e8d60b18ec-0` for TEMP/TMP/TMPDIR, exited `0`, confirmed owned process-tree cleanup, produced complete redacted output digests, and removed only its own attempt temp. Duration: `0.313s`.

The earlier Codex sandbox `PermissionError / WinError 5` against the external trusted log root was an execution-environment limitation, not a product failure. Re-running from the authorized BaBoss RDC execution context closed that blocker without changing ACLs or widening paths.

## Final source set

- `run_powershell.py` — bounded outer runner and classification policy.
- `windows_job.py` — Windows Job Object ownership/cleanup boundary.
- `test_run_powershell.py` — stdlib integration/negative tests.
- `smoke_temp.ps1` — harmless trusted-root inheritance probe.
- `POWERSHELL_WATCHDOG.md` — operator runbook and Norton boundary.
- `VALIDATION.md` — acceptance record.

Canonical source implementation commit: `373e0bd0e42fbed3563bbfd3f2dd57e3a4193aec`.

The final runner intentionally omits `-ExecutionPolicy Bypass`; normal machine/user policy remains in force. No MT5, trading, deployment, risk/default, Scheduled Task, provider profile, or Norton setting changed.
