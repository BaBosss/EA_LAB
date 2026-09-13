# Control Tower Handoff — Norton / PowerShell Execution Hardening — 2026-09-13

## Intake identity

- Host/device: `BaBoss` / `bbb88aa0-1598-43f6-b56c-a7db22af086a`.
- Repository: `https://github.com/BaBosss/EA_LAB.git`.
- Canonical source implementation: `373e0bd0e42fbed3563bbfd3f2dd57e3a4193aec`.
- Final converged canonical state at packaging start: `cb530b5c8b2ac18dff3555cd3f2277af220e64da`.
- Current status: `ACCEPTED / REVIEWED / CANONICAL / TOOLING_ONLY / CLOSED`.
- Direct consumer: the one active EA_LAB Control Tower and every bounded local PowerShell execution that elects to use the watchdog.

## Why this work was opened

Norton reported `IDP.HELU.PSE90` and was observed terminating `powershell.exe` / deleting `__PSScriptPolicyTest_*.ps1`. This can cause a child process to disappear while a parent runner waits for output, postconditions, or timeout, making automation appear hung. The incident is an environment/interference risk, not evidence that every PowerShell failure is caused by Norton.

## What is now canonical

The bounded watchdog is under `scripts/execution_reliability/`:

- `run_powershell.py` — stdlib outer runner and classification policy.
- `windows_job.py` — Windows Job Object containment for the owned process tree.
- `test_run_powershell.py` — integration/negative tests.
- `smoke_temp.ps1` — trusted TEMP/TMP/TMPDIR acceptance probe.
- `POWERSHELL_WATCHDOG.md` — operator runbook and security boundary.
- `VALIDATION.md` — canonical acceptance receipt.

Execution scratch is `D:\EA_LAB_CONTROL\trusted_exec\temp`; sanitized durable diagnostics are under `D:\EA_LAB_CONTROL\trusted_exec\logs`.
## Runtime behavior and failure semantics

The runner sets child `TEMP`, `TMP`, and `TMPDIR` before PowerShell initializes, starts PowerShell suspended, assigns it to an owned non-breakaway Job Object, then resumes it. Timeout terminates only that owned tree. Ordinary script failure is not retried. One retry is allowed only for selected Windows abrupt-termination statuses; unresolved second failure, storage/launch/containment failure, or unconfirmed cleanup fails closed as `BLOCKED_C_ENVIRONMENT_DEPENDENCY`.

The final runner intentionally omits `-ExecutionPolicy Bypass`; the observed user policy remains `RemoteSigned`. It does not persist environment changes and does not change Norton, MT5, Scheduled Tasks, runtime, deployment, trading, risk/defaults, or provider profiles.

## Validation and review

Canonical acceptance recorded in `scripts/execution_reliability/VALIDATION.md`:

- `py_compile`: PASS.
- Trusted-root suite: **11/11 PASS** — 9 tests launch real PowerShell; 2 are pure policy/cleanup tests.
- Trusted TEMP inheritance smoke: PASS / exit 0.
- Final accepted smoke run: `36e40575f5ef4f30b73d84e8d60b18ec`, duration `0.313s`.
- Owned timeout descendant cleanup: PASS; unrelated sibling process preserved.
- Ordinary nonzero failures: no retry.
- Simulated abrupt termination: at most one retry; repeated abrupt termination fails closed.
- Argument handling / output privacy / containment-assignment failure / cleanup-boundary tests: PASS.
- `git diff --check` and normal commit hooks: PASS.

Targeted rereview receipt: `D:\EA_LAB_CONTROL\evidence\norton-powershell-hardening-20260913\TARGETED_REREVIEW.txt`, SHA-256 `4b050334cdb3be28e3445d8a9cb69fb0999b748f72be12dc2ece5359692ee0fe`, verdict `PASS / NONE / ALLOW_FF_PUSH=YES`.

Accepted smoke summary: `D:\EA_LAB_CONTROL\trusted_exec\logs\run-36e40575f5ef4f30b73d84e8d60b18ec\summary.json`, SHA-256 `ab2892f45fab93211111dcc833652aa4788205f8c7e28099003223d11f274b79`.
## Canonical lineage and superseded local lines

Canonical lineage to preserve:

1. `373e0bd0e42fbed3563bbfd3f2dd57e3a4193aec` — source implementation.
2. `243e2fd8...` — accepted evidence-wording repair on the canonical lineage.
3. `cb530b5c8b2ac18dff3555cd3f2277af220e64da` — final convergence; Lane Registry `ct-final-convergence-20260913` is `DONE` and reviewed at that exact head.

Do not promote the abandoned local-only lines `5ab31312...`, `4b5f779a...`, or `05bd1ebe...`; they are not ancestors of the final convergence and were superseded during concurrent-origin reconciliation.

`PROJECT_STATE.md` already owns the accepted current-status statement. `AGENT_TASKBOARD.md` has no new Norton queue item because this lane is closed; do not reopen it without a reproducible regression or a direct consumer.

## Norton exclusion boundary

No Norton exclusion was changed automatically. If the owner/security administrator chooses an exclusion, the runbook recommends only:

`D:\EA_LAB_CONTROL\trusted_exec\temp`

Do **not** exclude the whole repository, all user temp, `powershell.exe`, or the `IDP.HELU.PSE90` signature globally. The exclusion remains a manual owner/security setting unless a supported Norton CLI is separately verified and approved.

## Control Tower intake action

Treat this handoff as a durable locator, not a second source of truth. On intake, fetch current `origin/master`, verify the source commit and `PROJECT_STATE.md`, then reuse `scripts/execution_reliability/run_powershell.py` for bounded jobs where silent PowerShell termination/hang risk matters. No further Norton-hardening work is READY by default.

The machine-local trusted logs are diagnostics, not canonical status. If future PowerShell execution fails, inspect the watchdog classification and corresponding `trusted_exec\logs\run-*` record before retrying. A `C_ENVIRONMENT_DEPENDENCY` failure must not be reinterpreted as an EA/strategy failure.

## Durable closeout receipt

Machine-readable summary: `portfolio/NORTON_POWERSHELL_HARDENING_CLOSEOUT_20260913.json`.
