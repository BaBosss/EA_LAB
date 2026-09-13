# PowerShell outer watchdog

`run_powershell.py` is a Windows-only, Python-stdlib runner for bounded `.ps1`
jobs. It does not configure Norton, install anything, modify global environment
variables, or integrate itself into existing EA_LAB launchers.

## Incident and operator action

The owner reported Norton `IDP.HELU.PSE90` terminating `powershell.exe` and
deleting `__PSScriptPolicyTest_*.ps1` under
`C:\Users\codexsandboxoffline\AppData\LocalLow\Temp`. The owner also reports prior
Norton quarantine interference in canonical history. These are incident inputs,
not proof that a subsequent script failure is caused by Norton.

The narrowly recommended exclusion, if the owner/security administrator approves
it after reviewing Norton Security History, is exactly:

```text
D:\EA_LAB_CONTROL\trusted_exec\temp
```

Keep that directory for approved execution scratch files only. Do not exclude
the whole repository, the whole user temp tree, or `powershell.exe`: those cover
far more scripts and execution than this incident requires. Norton explains that
exclusions reduce protection; see its [product manual](https://support.norton.com/sp/static/ftpdata/english_us_canada/products/norton_security/manuals/Norton_Security_Manual.pdf)
and [incorrect-alert guidance](https://support.norton.com/sp/en/gb/home/current/solutions/kb20100222230832EN).
An exclusion may not resolve every behavior-based termination; correlate any
recurrence with the vendor's history and false-positive submission process.

Norton UI exclusion is a **manual owner/security setting**, unless a supported
CLI is separately verified and approved. No supported Norton CLI is assumed or
used here. This tooling contract does not authorize changing that setting.

## Invocation

Prefer starting Python directly from Command Prompt or an existing launcher, so
the watchdog itself does not depend on a new PowerShell process. From the repo
root, using the existing complete portable Python installation on this machine:

```bat
D:\EA_LAB\tools\python312\python.exe scripts\execution_reliability\run_powershell.py --timeout 120 "C:\approved\job.ps1" -Name "literal value"
```

Options for the watchdog precede the script path. Everything after the script
path is a literal target argument, including tokens resembling runner options.
No shell command string, `Invoke-Expression`, or `-Command` interpolation is
used: `subprocess.Popen` receives an argument array with `shell=False`.
Windows PowerShell `-File` parameter-binding rules still apply.

For Python callers, call `run(script_path, [argument, ...], timeout=120)`.
Use a trusted `.ps1` whose partial execution can safely be repeated once. A
termination can occur after side effects; this runner cannot provide exactly-once
execution. Do not use it to attach runtime, trade, deploy, or start persistent
services under this contract.

The runner uses the absolute system Windows PowerShell executable with
`-NoLogo -NoProfile -NonInteractive -File`. It deliberately does **not** override
execution policy: the machine/user policy continues to apply. This keeps the
command line narrower and avoids weakening a security boundary merely to make
a script run. The working directory and other environment variables are inherited.
Only the child's TEMP, TMP and TMPDIR are replaced.

## Lifetime, retry and diagnostics

Each attempt gets a unique direct child of the fixed trusted temp directory.
All three temp variables equal that attempt root **before** process creation.
PowerShell starts suspended, is assigned to a non-breakaway Windows Job Object,
and only then resumes. The job uses kill-on-close. Timeout and final cleanup
terminate only that job; an unassigned suspended child is terminated through its
own retained process handle. No process-name scan or broad kill is used. See
Microsoft's [Job Objects documentation](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects).

The timeout is per attempt, defaults to 300 seconds, and must be finite, positive
and at most 86400 seconds. Process/tree/output cleanup has separate bounded waits
(up to 20 additional seconds per attempt, plus local OS/filesystem call time).
Descendants are cleaned even if the main script exits successfully. If containment
cannot be established, the target remains suspended and the run fails closed.
Tree cleanup must be confirmed before removing temp. Cleanup refuses reparse
points and paths outside its own attempt; refused/failed cleanup preserves temp
and is recorded. Logs are never removed by the production runner.

| Classification | Meaning |
| --- | --- |
| `SUCCESS` | First attempt exited zero and cleanup completed. |
| `SCRIPT_FAILED` | Ordinary nonzero exit; no automatic retry, even if fast and silent. |
| `TIMEOUT` | First attempt exceeded its deadline and owned tree/output/temp cleanup all confirmed; no retry. |
| `ABRUPT_TERMINATION_SUSPECTED` | Attempt returned one of the selected Windows termination statuses below; suspicion only. |
| `RETRY_SUCCESS_AFTER_ABRUPT_TERMINATION` | The one permitted retry succeeded. |
| `BLOCKED_C_ENVIRONMENT_DEPENDENCY` | Any second-attempt failure, storage/launch/containment failure, or unconfirmed cleanup. |

The allowlist is `0xC0000005` (access violation), `0xC000013A` (control-C exit),
`0xC0000409` (fail-fast/stack-buffer-overrun status), and `0x40000015`
(fatal application exit). Signed and unsigned forms are normalized. Other codes,
including generic exit 1, are not retry candidates. No duration/output-size-only
heuristic is used because it would retry legitimate silent failures. This can
miss Norton terminations reported with an ordinary exit code. Conversely, these
statuses can have non-Norton causes. The final BLOCKED label after a second
failure is a stop condition, not an AV diagnosis; the attempt records retain the
actual SCRIPT_FAILED/TIMEOUT/abrupt classification.

`D:\EA_LAB_CONTROL\trusted_exec\logs\run-<uuid>` contains fsynced lifecycle
`events.jsonl`, `summary.json`, and per-attempt `*.stdout.json` / `*.stderr.json`.
Records include script path, argument count/hash, runner/child PID, UTC timestamps,
duration, exit code, temp/output paths, retry count, classification and cleanup
flags. No arguments, command line, environment dump, or raw exception text is
logged. Output files contain **byte counts and keyed hashes only**, never raw
stdout/stderr, since scripts may echo arguments or secrets. HMAC-SHA256 uses an
ephemeral key shared within a run and never saved, preventing dictionary checks
against low-entropy secrets. Hashes cannot be compared across runs. Full script
output is deliberately unavailable; use separately approved, sanitized script
diagnostics if needed. The target script's own file writes are outside this
redaction boundary. Script paths themselves must be safe to record.

The CLI prints the metadata summary and returns 0 for either success class,
124 for a first-attempt timeout, 125 for blocked runs, and the original ordinary
script exit code when in 1..255 (otherwise 1). Storage failure before logs can be
opened prints sanitized BLOCKED metadata and starts no PowerShell child. An
interrupted runner can leave lifecycle logs without a final summary; inspect the
last event before deciding whether a manual replay is safe. OS/AV forced process
death can leave attempt temp behind, although job-handle closure kills contained
descendants. There is no automatic sweep of old temp or logs.

Implementation requires Windows with nested Job Object support and CPython's
Windows `Popen._handle` (validated with portable CPython 3.12.10). The retained
handle prevents PID-reuse mistakes. Job assignment restrictions imposed by an
outer sandbox are reported as BLOCKED; there is no containment bypass.

## Validation

Run from the repo root in Command Prompt:

```bat
D:\EA_LAB\tools\python312\python.exe -m py_compile scripts\execution_reliability\run_powershell.py scripts\execution_reliability\windows_job.py scripts\execution_reliability\test_run_powershell.py
D:\EA_LAB\tools\python312\python.exe scripts\execution_reliability\test_run_powershell.py
D:\EA_LAB\tools\python312\python.exe scripts\execution_reliability\run_powershell.py --timeout 15 scripts\execution_reliability\smoke_temp.ps1
git diff --check
git status --short --untracked-files=all
```

When invoking Python from an existing PowerShell session, first dot-source
`scripts\use_python.ps1` as required by EA_LAB. If the worktree portable runtime
lacks its stdlib archive, use the complete executable above; do not provision
files outside the write contract. A process-scoped execution policy may be needed
to dot-source that helper; do not change global policy.

The tests start real PowerShell children for temp inheritance, ordinary success,
silent/non-silent failure without retries, literal metacharacter arguments, output
privacy, timeout with a descendant and unaffected sibling, containment failure,
and simulated abrupt exit with bounded retry. The simulation uses
`[Environment]::Exit(-1073741510)`, not Norton or a real crash. Test source fixtures
are created and removed only under this directory. Default test execution retains
production diagnostics in trusted logs.

For a sandbox that cannot write the fixed external roots, the additional
`--local-storage` test flag substitutes storage inside its isolated test fixture.
Those disposable fixture logs are removed with the test fixture. This tests the
same process/cleanup logic but **does not satisfy the trusted-root smoke gate**.
The production CLI has no storage-root override.
