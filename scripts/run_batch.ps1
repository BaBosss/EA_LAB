<#
run_batch.ps1 — ORDER-100 Contract B: MVP-0 blocking execution harness.

Runs a manifest of jobs by INVOKING the repo's EXISTING runner scripts
(mt5_run.ps1 / mt4_run.ps1 / mt5_optimize.ps1 / mt4_optimize.ps1 / mass_smoke_*
/ mt5_batch_shortlist.ps1 / qwen_batch_runner.ps1 / or the test mock_runner.ps1)
— it never reimplements tester logic, never edits those scripts, and never
kills any process. Each runner already owns its own timeout / self-kill
behavior scoped to the ONE process IT launches (see
docs/memory_control/RUNNER_INVENTORY.md) — this wrapper adds ONLY: blocking
sequential execution in manifest order, per-lane advisory locking so two jobs
on the same install/lane never run concurrently, fail-visible stop-on-failure,
and idempotent resume via a JSON state file.

Usage:
  powershell -File scripts\run_batch.ps1 -Manifest <path-to-manifest.json> -StateDir <path>

Manifest JSON shape (array of job objects):
  [
    {
      "id":     "job1",              # unique string id, required
      "runner": "D:\\...\\some_runner.ps1",   # path to an EXISTING runner or the mock, required
      "args":   ["-Foo", "bar"],      # array (preferred) or a whitespace-split string, required
      "lane":   "M5-1",               # lane name — jobs sharing a lane never run concurrently, required
      "model":  4                     # int or string; "4" means Model-4 (every-tick) — must sit on a
    }                                  # lane-1/serial-style lane ("1", "lane1", or anything ending "-1")
  ]

State file (StateDir\state.json), one record per manifest job, in manifest order:
  { id, runner, lane, model, state (pending|running|done|failed), start, end, exit_code }

Resume: re-run with the SAME -Manifest and -StateDir. Jobs already "done" are
skipped (never re-invoked — proven via the mock runner's frozen marker file);
only "pending"/"failed" jobs execute.

No process-termination calls of any kind live in this file (this wrapper never
ends a running process — each invoked runner owns that decision for the one
process it launches). The only "-Force" usages below are on New-Item
(directory scaffolding) and Remove-Item (advisory lock FILE cleanup) — never
on a process.
#>
param(
  [Parameter(Mandatory)][string]$Manifest,
  [Parameter(Mandatory)][string]$StateDir,
  [int]$LaneLockTimeoutSec = 300,   # bounded poll ceiling while waiting for a busy lane
  [int]$LaneLockPollMs = 200
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Manifest)) {
  Write-Output "ABORT: manifest not found: $Manifest"
  exit 2
}

# StateDir may not exist yet on first run — dir scaffold, not process-related.
New-Item -ItemType Directory -Force $StateDir | Out-Null

# --- helpers ----------------------------------------------------------------

function ConvertFrom-JsonArray {
  # Read a JSON file and always return it as a PowerShell array, even when the
  # file contains a single object / a 1-element array (Windows PowerShell 5.1
  # quirk: ConvertFrom-Json of a 1-element JSON array already returns Object[],
  # but wrapping with @() makes the "single bare object" case safe too).
  param([string]$Path)
  if (-not (Test-Path $Path)) { return @() }
  $raw = Get-Content $Path -Raw
  if (-not $raw -or $raw.Trim() -eq "") { return @() }
  return @($raw | ConvertFrom-Json)
}

function Write-StateFile {
  param([array]$Records, [string]$Path)
  # -InputObject (not pipeline) is required in Windows PowerShell 5.1 so a
  # single-record array still serializes as a JSON array, not a bare object.
  $json = ConvertTo-Json -InputObject $Records -Depth 8
  Set-Content -Path $Path -Value $json -Encoding utf8
}

function Test-Model4LaneOk {
  # model==4 (every-tick) jobs must sit on a lane-1 / serial-style lane, never
  # a parallel "b"/"2"-style lane. Accepts "1", "lane1", or anything ending "-1".
  param([string]$Lane)
  if (-not $Lane) { return $false }
  return ($Lane -match '(?i)^(1|lane ?1)$') -or ($Lane -match '(?i)-1$')
}

function Get-LaneLockPath {
  param([string]$StateDir, [string]$Lane)
  $safeLane = ($Lane -replace '[^A-Za-z0-9_\-]', '_')
  return Join-Path $StateDir "lane_$safeLane.lock"
}

function Enter-LaneLock {
  # Advisory exclusive lock file per lane. CreateNew fails with IOException if
  # the file already exists, giving atomic exclusive-create semantics without
  # any process-level primitive. Blocks (bounded poll) rather than failing.
  param([string]$LockPath, [string]$Lane, [int]$TimeoutSec, [int]$PollMs)
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $waited = $false
  while ($true) {
    try {
      $fs = [System.IO.File]::Open($LockPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write)
      $fs.Close()
      if ($waited) { Write-Output "LANE-LOCK ACQUIRE lane=$Lane file=$LockPath (after wait)" }
      else { Write-Output "LANE-LOCK ACQUIRE lane=$Lane file=$LockPath" }
      return
    } catch [System.IO.IOException] {
      $waited = $true
      if ($sw.Elapsed.TotalSeconds -ge $TimeoutSec) {
        throw "Timed out after ${TimeoutSec}s waiting for lane lock '$Lane' ($LockPath) to free up."
      }
      Start-Sleep -Milliseconds $PollMs
    }
  }
}

function Exit-LaneLock {
  param([string]$LockPath, [string]$Lane)
  if (Test-Path $LockPath) {
    # Lock FILE cleanup (not a process) — always release via try/finally.
    Remove-Item -Path $LockPath -Force -ErrorAction SilentlyContinue
  }
  Write-Output "LANE-LOCK RELEASE lane=$Lane file=$LockPath"
}

function Get-ArgsArray {
  param($JobArgs)
  if ($null -eq $JobArgs) { return @() }
  if ($JobArgs -is [string]) {
    if ($JobArgs.Trim() -eq "") { return @() }
    # Simple whitespace split fallback for the string form — the array form is
    # preferred by the manifest contract precisely to avoid quoting ambiguity.
    return ($JobArgs -split '\s+')
  }
  return @($JobArgs)
}

# --- load manifest + prior state ---------------------------------------------

$manifestJobs = ConvertFrom-JsonArray -Path $Manifest
if ($manifestJobs.Count -eq 0) {
  Write-Output "ABORT: manifest has no jobs: $Manifest"
  exit 2
}

$stateFile = Join-Path $StateDir "state.json"
$priorRecords = ConvertFrom-JsonArray -Path $stateFile
$priorById = @{}
foreach ($r in $priorRecords) { $priorById[$r.id] = $r }

# Pre-flight validation: every model==4 job must be on a serial/lane-1 style lane.
# Checked for the WHOLE manifest before any job runs, so a bad manifest never
# partially executes.
foreach ($job in $manifestJobs) {
  if ("$($job.model)" -eq "4" -and -not (Test-Model4LaneOk -Lane "$($job.lane)")) {
    Write-Output "ABORT: job '$($job.id)' has model=4 (every-tick) but lane '$($job.lane)' is not a lane-1/serial-style lane. Model-4 jobs must run serial (e.g. lane '1', 'lane1', or '...-1')."
    exit 2
  }
}

# Build the working record list in MANIFEST ORDER, reusing prior state for
# jobs already known (this is what makes "done" jobs skip on resume).
$records = New-Object System.Collections.Generic.List[object]
foreach ($job in $manifestJobs) {
  if ($priorById.ContainsKey($job.id)) {
    $records.Add($priorById[$job.id])
  } else {
    $records.Add([PSCustomObject]@{
      id        = $job.id
      runner    = $job.runner
      lane      = $job.lane
      model     = $job.model
      state     = "pending"
      start     = $null
      end       = $null
      exit_code = $null
    })
  }
}
Write-StateFile -Records $records -Path $stateFile

# --- run jobs sequentially, blocking, lane-aware, fail-visible --------------

$failed = $false
$failReason = ""

foreach ($rec in $records) {
  if ($rec.state -eq "done") {
    Write-Output "SKIP (already done): $($rec.id)"
    continue
  }

  $job = $manifestJobs | Where-Object { $_.id -eq $rec.id } | Select-Object -First 1
  $lane = "$($job.lane)"
  $lockPath = Get-LaneLockPath -StateDir $StateDir -Lane $lane

  Enter-LaneLock -LockPath $lockPath -Lane $lane -TimeoutSec $LaneLockTimeoutSec -PollMs $LaneLockPollMs
  try {
    $rec.state     = "running"
    $rec.start     = (Get-Date).ToString("o")
    $rec.exit_code = $null
    Write-StateFile -Records $records -Path $stateFile

    $argsArray = Get-ArgsArray -JobArgs $job.args
    Write-Output "RUN: id=$($rec.id) runner=$($job.runner) lane=$lane model=$($job.model) args=$($argsArray -join ' ')"

    & powershell -NoProfile -ExecutionPolicy Bypass -File $job.runner @argsArray
    $exitCode = $LASTEXITCODE

    $rec.end       = (Get-Date).ToString("o")
    $rec.exit_code = $exitCode

    if ($exitCode -eq 0) {
      $rec.state = "done"
      Write-StateFile -Records $records -Path $stateFile
      Write-Output "OK: id=$($rec.id) exit=0"
    } else {
      $rec.state = "failed"
      Write-StateFile -Records $records -Path $stateFile
      $failReason = "job '$($rec.id)' (runner=$($job.runner)) exited $exitCode"
      Write-Output "FAIL: $failReason -- stopping all remaining jobs."
      $failed = $true
    }
  } finally {
    Exit-LaneLock -LockPath $lockPath -Lane $lane
  }

  if ($failed) { break }
}

Write-StateFile -Records $records -Path $stateFile

if ($failed) {
  Write-Output "run_batch STOPPED early: $failReason"
  exit 1
}

Write-Output "run_batch: all jobs done."
exit 0
