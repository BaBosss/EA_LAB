<#
run_batch.ps1 — ORDER-100 Contract B: MVP-0 blocking execution harness.

Runs a manifest of jobs by INVOKING the repo's EXISTING runner scripts
(mt5_run.ps1 / mt4_run.ps1 / mt5_optimize.ps1 / mt4_optimize.ps1 / mass_smoke_*
/ mt5_batch_shortlist.ps1 / qwen_batch_runner.ps1 / or the test mock_runner.ps1)
— it never reimplements tester logic, never edits those scripts, and never
kills any process. Each runner already owns its own timeout / self-kill
behavior scoped to the ONE process IT launches (see
docs/memory_control/RUNNER_INVENTORY.md) — this wrapper adds: blocking
sequential execution in manifest order, per-lane advisory locking (GLOBAL,
fixed location — independent of -StateDir, so two run_batch invocations
targeting the same physical lane from different -StateDir values still
mutually exclude), fail-visible stop-on-failure with real failure detection
(exit code AND stdout-keyword scan AND optional expected-artifact check —
some runners exit 0 even when the underlying test produced nothing), atomic
state writes (crash-safe resume), duplicate-job-id pre-flight validation, and
a model==4 (every-tick) physical-lane check that looks at the job's actual
-Terminal argument, not just its lane label.

Usage:
  powershell -File scripts\run_batch.ps1 -Manifest <path-to-manifest.json> -StateDir <path>

Manifest JSON shape (array of job objects):
  [
    {
      "id":     "job1",              # unique string id, required — duplicates abort pre-flight
      "runner": "D:\\...\\some_runner.ps1",   # path to an EXISTING runner or the mock, required
      "args":   ["-Foo", "bar"],      # array (preferred) or a whitespace-split string, required
      "lane":   "M5-1",               # lane name — jobs sharing a lane never run concurrently, required
      "model":  4,                    # int or string; "4" means Model-4 (every-tick) — must sit on a
                                       # lane-1/serial-style lane ("1", "lane1", or anything ending "-1"),
                                       # OR (if the job's args carry a "-Terminal" value) that value must
                                       # equal -Lane1Terminal exactly (physical check wins over label).
      "expect_artifact": "D:\\...\\reports\\*.htm",  # OPTIONAL path or glob; if given, at least one
                                       # matching file must exist with mtime >= this job's start time,
                                       # or the job is marked failed even if exit code is 0.
      "exit_reliable": true           # OPTIONAL bool; overrides the built-in exit-unreliable-basename
                                       # guess (mt4_run.ps1/mt4_optimize.ps1/mt5_optimize.ps1) for THIS
                                       # job. Omit to use the built-in guess.
    }
  ]

Lane locking key: the lock a job takes is keyed by its PHYSICAL terminal install when known, not its
lane LABEL — if the job's args carry a "-Terminal <path>" value, the lock key is that path
(trim+lowercased); otherwise the lock key falls back to the lane label. This means two manifests using
different lane labels (e.g. "M5-1" vs "primary") that both point -Terminal at the SAME install still
mutually exclude, because a label is just a human name and two different callers could pick two
different labels for the one physical terminal.

State file (StateDir\state.json), one record per manifest job, in manifest order:
  { id, runner, lane, model, state (pending|running|done|failed), start, end, exit_code, fail_reason }
Written atomically: state.json.tmp is written then Move-Item -Force'd over state.json, so a crash
mid-write can never leave a truncated/corrupt state.json behind. On load: a missing or empty state.json
means a fresh run (returns no prior records); a state.json that EXISTS but fails to parse as JSON is
treated as corruption and aborts loudly (exit 2) rather than silently discarding resume history.

Resume: re-run with the SAME -Manifest and -StateDir. Jobs already "done" are
skipped (never re-invoked — proven via the mock runner's frozen marker file);
only "pending"/"failed" jobs execute.

Failure detection (a job is "done" only if ALL of these hold):
  (a) $LASTEXITCODE -eq 0 from the invoked runner, AND
  (b) the runner's captured stdout+stderr does NOT match
      /NO( OPT)? REPORT|NO XML|ABORT|ERROR|FATAL/i (PowerShell's -match is already case-insensitive;
      the "( OPT)?" catches mt4_optimize.ps1's "NO OPT REPORT" wording, which does NOT contain the
      contiguous substring "NO REPORT" and slipped past the older, narrower pattern), AND
  (c) if the job specifies "expect_artifact", at least one file matching that path/glob exists with
      LastWriteTime >= the job's start timestamp, AND
  (d) reliability gate — for a runner whose exit code is known to be UNTRUSTWORTHY (see the built-in
      exit-unreliable basename set + optional per-job "exit_reliable" manifest override, below),
      exit-code==0 plus "no bad word" is NOT enough on its own: the job also needs POSITIVE success
      evidence — either the stdout matches /OK( OPT)? REPORT|OK OPTIMIZER XML/i, or the job supplied
      "expect_artifact" and it was satisfied. An unreliable runner that exits 0 with clean-but-silent
      stdout and no expect_artifact is marked FAILED ("no success evidence"), not done. Exit-reliable
      runners (mt5_run.ps1, the mock, and anything not on the unreliable list / not overridden) keep
      the plain (a)+(b)+(c) logic — no positive-marker requirement.
This matters because real runners are NOT uniformly reliable: mt5_run.ps1 exits 1 on "NO REPORT", but
mt4_run.ps1 / mt4_optimize.ps1 / mt5_optimize.ps1 PRINT their failure text and fall through to exit 0 —
exit-code-only detection would silently report that failed backtest/optimization as success. See
docs/memory_control/RUNNER_INVENTORY.md for the reliability of each runner's exit code.

No process-termination calls of any kind live in this file (this wrapper never
ends a running process — each invoked runner owns that decision for the one
process it launches). The only "-Force" usages below are on New-Item
(directory scaffolding), Remove-Item (advisory lock FILE cleanup), and
Move-Item (atomic state-file rename over an existing FILE) — never on a
process.
#>
param(
  [Parameter(Mandatory)][string]$Manifest,
  [Parameter(Mandatory)][string]$StateDir,
  [int]$LaneLockTimeoutSec = 300,   # bounded poll ceiling while waiting for a busy lane
  [int]$LaneLockPollMs = 200,
  [string]$Lane1Terminal = 'D:\Meta 5\terminal64.exe'   # physical lane-1 install; model==4 jobs that
                                                         # carry an explicit -Terminal arg must match this
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

function Read-StateFile {
  # State file loader: tolerant of missing/empty (fresh run => no prior
  # records), but FAILS LOUDLY if the file exists with content that isn't
  # valid JSON (treat as corruption, never silently discard resume history).
  param([string]$Path)
  if (-not (Test-Path $Path)) { return @() }
  $raw = Get-Content $Path -Raw
  if (-not $raw -or $raw.Trim() -eq "") { return @() }
  try {
    return @($raw | ConvertFrom-Json)
  } catch {
    Write-Output "ABORT: state file exists but is not valid JSON, refusing to guess: $Path -- $($_.Exception.Message)"
    exit 2
  }
}

function Write-StateFile {
  param([array]$Records, [string]$Path)
  # -InputObject (not pipeline) is required in Windows PowerShell 5.1 so a
  # single-record array still serializes as a JSON array, not a bare object.
  $json = ConvertTo-Json -InputObject $Records -Depth 8
  # Atomic write: write to a sibling .tmp file then rename over the real path,
  # so a crash mid-write can never leave state.json truncated/corrupt.
  $tmpPath = "$Path.tmp"
  Set-Content -Path $tmpPath -Value $json -Encoding utf8
  Move-Item -Path $tmpPath -Destination $Path -Force   # atomic rename over an existing FILE, not a process
}

function Test-Model4LaneOk {
  # model==4 (every-tick) jobs must sit on a lane-1 / serial-style lane, never
  # a parallel "b"/"2"-style lane. Accepts "1", "lane1", or anything ending "-1".
  # This is the LABEL-only fallback check, used only when a job's args don't
  # carry an explicit -Terminal value (see the physical check at the manifest
  # pre-flight loop below, which wins whenever -Terminal IS present).
  param([string]$Lane)
  if (-not $Lane) { return $false }
  return ($Lane -match '(?i)^(1|lane ?1)$') -or ($Lane -match '(?i)-1$')
}

function Get-ArgValue {
  # Find the value following a named flag (e.g. "-Terminal") in an args array.
  # Case-insensitive flag match. Returns $null if the flag isn't present.
  param([array]$ArgsArray, [string]$Name)
  for ($i = 0; $i -lt $ArgsArray.Count; $i++) {
    if ("$($ArgsArray[$i])" -ieq $Name) {
      if ($i + 1 -lt $ArgsArray.Count) { return "$($ArgsArray[$i + 1])" }
      return $null
    }
  }
  return $null
}

function Get-LaneLockKey {
  # Fix #2 (physical-terminal locking): the lock key for a job is its PHYSICAL
  # terminal install when known, not its lane LABEL. If the job's args carry a
  # "-Terminal <path>" value, that value (trimmed + lowercased, so path case/
  # whitespace differences between two manifests don't create two "different"
  # keys for the same install) IS the key. Only when no -Terminal arg is
  # present do we fall back to the lane label — jobs that never say which
  # physical install they target can only be deduplicated by their label.
  param([string]$Lane, [array]$ArgsArray)
  $terminalVal = Get-ArgValue -ArgsArray $ArgsArray -Name "-Terminal"
  if ($terminalVal) {
    # Canonicalize so two spellings of the SAME install collapse to one key:
    # GetFullPath resolves "." / ".." and normalizes / vs \ separators; then
    # lowercase and strip any trailing separator. Fall back to the raw trimmed
    # value if GetFullPath throws on a malformed path (still better than nothing).
    $t = $terminalVal.Trim().Trim('"')
    try { $t = [System.IO.Path]::GetFullPath($t) } catch { }
    return $t.TrimEnd('\','/').ToLowerInvariant()
  }
  return $Lane
}

function Get-LaneLockPath {
  # GLOBAL fixed location, independent of -StateDir — this is what makes two
  # run_batch.ps1 invocations pointed at the SAME physical lane but DIFFERENT
  # -StateDir values actually mutually exclude (a per-StateDir lock file would
  # not: two different callers, two different lock files, no exclusion at all).
  # $Key is whatever Get-LaneLockKey resolved (a normalized -Terminal path, or
  # a bare lane label when no -Terminal was given) — sanitized to a filename.
  param([string]$Key)
  $globalLockDir = Join-Path $env:TEMP "ealab_run_batch_locks"
  if (-not (Test-Path $globalLockDir)) {
    New-Item -ItemType Directory -Force $globalLockDir | Out-Null   # dir scaffold, not process-related
  }
  $safeKey = ($Key -replace '[^A-Za-z0-9_\-]', '_')
  return Join-Path $globalLockDir "lane_$safeKey.lock"
}

# Fix #1 (false-green / reliability model) — FAIL-CLOSED DEFAULT (Codex r2):
# a runner is trusted on its exit code ONLY if we have verified from its source
# that it exits non-zero on the failure path. That verified set is a small
# WHITELIST; everything else — mt4_run, every optimizer, every batch runner
# (mass_smoke_*, mt5_batch_shortlist, qwen_batch_runner), and any unknown/new
# runner — is treated as exit-UNRELIABLE and must produce positive success
# evidence (an OK marker or a satisfied expect_artifact). Default-reliable was
# unsafe: a batch runner that exits 0 after an internal failure would false-green.
# mock_runner.ps1 is whitelisted so tests that aren't about the reliability model
# keep exercising the plain path; reliability tests set exit_reliable=$false to
# force the strict path regardless.
$script:ExitReliableBasenames = @('mt5_run.ps1', 'mock_runner.ps1')

function Test-IsExitUnreliable {
  # Per-job reliability: an explicit "exit_reliable" manifest field (bool) always
  # wins when present (=$false forces the strict evidence requirement even for a
  # whitelisted runner; =$true trusts the exit code even for a non-whitelisted
  # one). Absent that override: whitelisted basename => reliable, otherwise =>
  # UNRELIABLE (fail-closed default).
  param($Job, [string]$RunnerPath)
  if ($null -ne $Job.exit_reliable) {
    return -not [bool]$Job.exit_reliable
  }
  $basename = Split-Path -Leaf "$RunnerPath"
  foreach ($r in $script:ExitReliableBasenames) {
    if ($basename -ieq $r) { return $false }
  }
  return $true
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

function Test-ExpectArtifact {
  # Optional post-run check: at least one file matching $Pattern (a literal
  # path or a simple glob — Get-Item resolves both) must exist with
  # LastWriteTime >= $Since (the job's start time). No pattern => vacuously ok
  # (the check simply isn't requested for this job).
  param([string]$Pattern, [datetime]$Since)
  if (-not $Pattern) { return $true }
  $items = @(Get-Item -Path $Pattern -ErrorAction SilentlyContinue)
  if ($items.Count -eq 0) { return $false }
  foreach ($it in $items) {
    if ($it.LastWriteTime -ge $Since) { return $true }
  }
  return $false
}

# --- load manifest ------------------------------------------------------------

$manifestJobs = ConvertFrom-JsonArray -Path $Manifest
if ($manifestJobs.Count -eq 0) {
  Write-Output "ABORT: manifest has no jobs: $Manifest"
  exit 2
}

# Pre-flight validation: job ids must be unique (the lookup below picks the
# FIRST match by id, so a duplicate would silently run the WRONG runner for
# one of the two ids). Checked before anything runs, before state is even
# loaded.
$idCounts = @{}
foreach ($job in $manifestJobs) {
  $jid = "$($job.id)"
  if ($idCounts.ContainsKey($jid)) { $idCounts[$jid]++ } else { $idCounts[$jid] = 1 }
}
$dupIds = @($idCounts.Keys | Where-Object { $idCounts[$_] -gt 1 })
if ($dupIds.Count -gt 0) {
  Write-Output "ABORT: duplicate job id(s) in manifest (ids must be unique): $($dupIds -join ', ')"
  exit 2
}

# --- load prior state ---------------------------------------------------------

$stateFile = Join-Path $StateDir "state.json"
$priorRecords = Read-StateFile -Path $stateFile
$priorById = @{}
foreach ($r in $priorRecords) { $priorById[$r.id] = $r }

# Pre-flight validation: every model==4 job must be on a serial/lane-1 style
# lane. Prefer the PHYSICAL check (the job's own -Terminal arg, if present)
# over the lane LABEL, since a manifest could set lane="fake-1" but pass
# -Terminal pointed at a parallel-lane install. Checked for the WHOLE
# manifest before any job runs, so a bad manifest never partially executes.
foreach ($job in $manifestJobs) {
  if ("$($job.model)" -eq "4") {
    $argsArrCheck = Get-ArgsArray -JobArgs $job.args
    $terminalVal = Get-ArgValue -ArgsArray $argsArrCheck -Name "-Terminal"
    if ($terminalVal) {
      if ($terminalVal -ne $Lane1Terminal) {
        Write-Output "ABORT: job '$($job.id)' has model=4 (every-tick) but -Terminal '$terminalVal' != lane-1 install '$Lane1Terminal'. Model-4 jobs must run on the physical lane-1 install, regardless of what the lane label says."
        exit 2
      }
    } elseif (-not (Test-Model4LaneOk -Lane "$($job.lane)")) {
      Write-Output "ABORT: job '$($job.id)' has model=4 (every-tick) but lane '$($job.lane)' is not a lane-1/serial-style lane, and no -Terminal arg was given to check physically. Model-4 jobs must run serial (e.g. lane '1', 'lane1', or '...-1')."
      exit 2
    }
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
      id          = $job.id
      runner      = $job.runner
      lane        = $job.lane
      model       = $job.model
      state       = "pending"
      start       = $null
      end         = $null
      exit_code   = $null
      fail_reason = $null
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
  # Fix #2: args must be resolved BEFORE locking, since the lock key itself
  # depends on whether the job's args carry a -Terminal value (physical
  # install) — falls back to the lane label only when no -Terminal is given.
  $argsArray = Get-ArgsArray -JobArgs $job.args
  $lockKey  = Get-LaneLockKey -Lane $lane -ArgsArray $argsArray
  $lockPath = Get-LaneLockPath -Key $lockKey

  Enter-LaneLock -LockPath $lockPath -Lane $lockKey -TimeoutSec $LaneLockTimeoutSec -PollMs $LaneLockPollMs
  try {
    $startDt = Get-Date
    $rec.state       = "running"
    $rec.start       = $startDt.ToString("o")
    $rec.exit_code   = $null
    $rec.fail_reason = $null
    Write-StateFile -Records $records -Path $stateFile

    Write-Output "RUN: id=$($rec.id) runner=$($job.runner) lane=$lane lock_key=$lockKey model=$($job.model) args=$($argsArray -join ' ')"

    # Capture stdout+stderr (Out-String) so we can scan it for failure
    # keywords below — some runners exit 0 even when nothing was produced.
    # $LASTEXITCODE still reflects the invoked powershell.exe (the last
    # NATIVE command in the pipeline), NOT the Out-String cmdlet.
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $job.runner @argsArray 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    if ($out) { Write-Output $out.TrimEnd() }

    $rec.end       = (Get-Date).ToString("o")
    $rec.exit_code = $exitCode

    # Fix #1: broadened negative pattern catches mt4_optimize.ps1's "NO OPT
    # REPORT" wording (the old 'NO REPORT' literal did not, since "NO OPT
    # REPORT" doesn't contain the contiguous substring "NO REPORT").
    $stdoutBad  = $out -match 'NO( OPT)? REPORT|NO XML|ABORT|ERROR|FATAL'
    # Positive success marker — only load-bearing for exit-UNRELIABLE runners
    # (see below); exit-reliable runners never need it. Covers every real
    # success wording in the fleet: mt5_run.ps1/mt4_run.ps1 print "OK REPORT",
    # mt4_optimize.ps1 prints "OK OPT REPORT", mt5_optimize.ps1 prints
    # "OK OPTIMIZER XML" (NOT "OK XML" contiguously, hence the separate
    # alternative — a plain 'OK XML' pattern would miss it).
    $stdoutGood = $out -match 'OK( OPT)? REPORT|OK OPTIMIZER XML'
    $hasExpectArtifact = [bool]$job.expect_artifact
    $artifactOk = Test-ExpectArtifact -Pattern $job.expect_artifact -Since $startDt
    $isUnreliable = Test-IsExitUnreliable -Job $job -RunnerPath $job.runner

    $jobReasons = New-Object System.Collections.Generic.List[string]
    if ($exitCode -ne 0) { $jobReasons.Add("exit_code=$exitCode") }
    if ($stdoutBad) { $jobReasons.Add("stdout matched failure pattern (NO REPORT/NO OPT REPORT/NO XML/ABORT/ERROR/FATAL)") }
    if ($hasExpectArtifact -and -not $artifactOk) { $jobReasons.Add("expect_artifact not found/stale: $($job.expect_artifact)") }

    # Fix #1 core: for an exit-UNRELIABLE runner, exit==0 + "no bad word" is
    # NOT enough on its own — require POSITIVE success evidence too (a
    # matching stdout marker, or a satisfied expect_artifact). Without this,
    # a failed optimization that exits 0, prints nothing alarming, and was
    # never given an expect_artifact would otherwise be marked done.
    if ($isUnreliable -and $exitCode -eq 0 -and -not $stdoutBad -and -not $stdoutGood -and -not ($hasExpectArtifact -and $artifactOk)) {
      $jobReasons.Add("unreliable runner: no success evidence (no OK marker, no expect_artifact)")
    }

    if ($jobReasons.Count -eq 0) {
      $rec.state       = "done"
      $rec.fail_reason = $null
      Write-StateFile -Records $records -Path $stateFile
      Write-Output "OK: id=$($rec.id) exit=0"
    } else {
      $rec.state       = "failed"
      $rec.fail_reason = ($jobReasons -join "; ")
      Write-StateFile -Records $records -Path $stateFile
      $failReason = "job '$($rec.id)' (runner=$($job.runner)) -- $($rec.fail_reason)"
      Write-Output "FAIL: $failReason -- stopping all remaining jobs."
      $failed = $true
    }
  } finally {
    Exit-LaneLock -LockPath $lockPath -Lane $lockKey
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
