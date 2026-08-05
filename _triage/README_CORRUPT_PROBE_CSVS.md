# Corrupt probe result CSVs (ORDER-372, 2026-07-28)

These files look like data and are not. Do not read numbers out of them.

| file | state |
|---|---|
| `ORDER215_probe_stage0.csv` | CORRUPT |
| `ORDER215_probe_stage1.csv` | CORRUPT |
| `ORDER215_probe_stage2.csv` | CORRUPT |
| `ORDER222_probe_stage0.csv` | CORRUPT |
| `ORDER222_probe_stage1.csv` | CORRUPT |
| `ORDER222_probe_stage2.csv` | CORRUPT |
| `ORDER222_probe_stage2_ld125000.csv` | **REBUILT and good** (ORDER-372) |

## What is wrong with them

Every one carries a `Length` column of string byte counts where `pf` / `trades` / `net` /
`eqdd_pct` belong. That is `Export-Csv` serialising the `.Length` property of **strings**.

Cause: `Invoke-Probe` in both probe scripts called `mt5_run.ps1` without capturing its output. A
PowerShell function returns everything its body writes to the success stream, so the runner's own
console lines became the function's return value, and `$results` filled with text instead of result
objects. `Where-Object { $_ }` drops `$null` but not strings, so the text reached `Export-Csv`.

The bug was silent on runs that succeeded and only crashed on runs that failed, which is why it
survived: the crash was rare, the corruption was every time.

## Why they are not reconstructed

Their source `.htm` reports are gone. `ORDER222_probe_stage2_ld125000.csv` is the exception — its
two reports survived, so it was rebuilt from them and is trustworthy.

Inventing numbers for the other six would be worse than a visibly broken file. They are kept as
evidence that the bug was real and long-running.

## Does this invalidate the ORDER-215 / ORDER-222 verdicts?

No. Those verdicts were written from the scripts' console output (`Write-Host`, which was never
affected) and from the `.htm` reports directly — not from these CSVs. What was lost is the
machine-readable backing, not the finding.

Fixed in `scripts/order222_cutloss_probe.ps1`, `scripts/order215_matchagrid_cutloss_probe.ps1`.
Cage: `scripts/tests/test_runner_output_capture.ps1`.
