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
  [string]$Lane1Terminal = 'D:\Meta 5\terminal64.exe',  # physical lane-1 install; model==4 jobs that
                                                         # carry an explicit -Terminal arg must match this
  [switch]$SimulateActiveNativeProcess                   # offline negative-control test hook (ORDER-1708)
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
    # KNOWN MVP-0 LIMITATION (Codex r3, accepted by lead): GetFullPath collapses
    # "." / ".." / slash / case / trailing-sep spellings, but NOT filesystem
    # ALIASES that point at the same exe by a different name — a UNC admin share
    # (\\localhost\d$\Meta 5\...), a mapped drive, a junction, or an 8.3 short
    # name would yield a DIFFERENT lock key for the same physical install. This
    # is not closed here because (a) run_batch is gated OFF from real MT4/MT5 for
    # now and (b) manifests use the canonical D:\Meta 5\... lane paths per
    # AGENTS.md §3.2. The full fix (reject/allowlist -Terminal to the 5 canonical
    # lane exes) is deferred to when the harness actually drives real runs.
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
# Reliable runners are matched by EXACT RESOLVED PATH, not basename (Codex r3):
# a rogue script named "mt5_run.ps1" living outside this repo must NOT be
# auto-trusted on its exit code. Paths resolve relative to THIS script's own
# location so the whitelist survives the repo being moved/renamed.
$script:ExitReliablePaths = @(
  (Join-Path $PSScriptRoot 'mt5_run.ps1'),
  (Join-Path $PSScriptRoot '_test\mock_runner.ps1')
) | ForEach-Object { try { ([System.IO.Path]::GetFullPath($_)).ToLowerInvariant() } catch { "$_".ToLowerInvariant() } }

function Test-IsExitUnreliable {
  # Per-job reliability: an explicit "exit_reliable" manifest field (bool) always
  # wins when present (=$false forces the strict evidence requirement even for a
  # whitelisted runner; =$true trusts the exit code even for a non-whitelisted
  # one). Absent that override: the runner's EXACT resolved path must be on the
  # reliable whitelist to be trusted, otherwise => UNRELIABLE (fail-closed).
  param($Job, [string]$RunnerPath)
  if ($null -ne $Job.exit_reliable) {
    return -not [bool]$Job.exit_reliable
  }
  $full = try { ([System.IO.Path]::GetFullPath("$RunnerPath")).ToLowerInvariant() } catch { "$RunnerPath".ToLowerInvariant() }
  if ($script:ExitReliablePaths -contains $full) { return $false }
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

function Get-StringSha256 {
  param([string]$Text)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes("$Text")
    $hashBytes = $sha.ComputeHash($bytes)
    return ([System.BitConverter]::ToString($hashBytes)).Replace("-", "").ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function Get-FileSha256OrStatus {
  param([string]$FilePath)
  if (-not $FilePath) { return $null }
  if (-not (Test-Path -LiteralPath $FilePath)) { return "MISSING" }
  return (Get-FileHash -LiteralPath $FilePath -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-ArtifactSha256 {
  param([string]$Pattern)
  if (-not $Pattern) { return $null }
  $items = @(Get-Item -Path $Pattern -ErrorAction SilentlyContinue | Sort-Object FullName)
  if ($items.Count -eq 0) { return $null }
  if ($items.Count -eq 1) {
    return (Get-FileHash -LiteralPath $items[0].FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  }
  $parts = @()
  foreach ($it in $items) {
    $h = (Get-FileHash -LiteralPath $it.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $parts += "$($it.FullName):$h"
  }
  return (Get-StringSha256 -Text ($parts -join "`n"))
}

function Get-RunnerParamDefault {
  # Resolve a runner's OWN declared parameter default (e.g. mt5_run.ps1 -Terminal / -DataDir)
  # from its AST, so native defaults are never re-typed here (R3-2).
  param([string]$RunnerPath, [string]$ParamName)
  try {
    if (-not (Test-Path -LiteralPath $RunnerPath)) { return $null }
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($RunnerPath, [ref]$null, [ref]$null)
    if (-not $ast.ParamBlock) { return $null }
    foreach ($p in $ast.ParamBlock.Parameters) {
      if ($p.Name.VariablePath.UserPath -ieq $ParamName -and $p.DefaultValue) {
        $v = $p.DefaultValue
        if ($v -is [System.Management.Automation.Language.StringConstantExpressionAst]) { return $v.Value }
        if ($v -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) { return $v.Value }
      }
    }
  } catch { }
  return $null
}

function Test-IsNativeMt5Runner {
  param([string]$RunnerPath)
  $leaf = [System.IO.Path]::GetFileName("$RunnerPath").ToLowerInvariant()
  return ($leaf -eq 'mt5_run.ps1' -or $leaf -eq 'mt5_optimize.ps1')
}

function Get-RunnerDependencySha256 {
  # Behavior-affecting helpers: every lib\*.ps1 beside/under the runner's scripts folder.
  param([string]$RunnerPath)
  if (-not $RunnerPath) { return $null }
  $dir = Split-Path -Parent $RunnerPath
  $libDirs = @((Join-Path $dir 'lib'), (Join-Path (Split-Path -Parent $dir) 'lib')) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -Unique
  $entries = @()
  foreach ($ld in $libDirs) {
    foreach ($f in @(Get-ChildItem -LiteralPath $ld -Filter *.ps1 -File | Sort-Object Name)) {
      $entries += [ordered]@{ name = $f.Name; sha256 = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
  }
  if ($entries.Count -eq 0) { return $null }
  return (Get-StringSha256 -Text (ConvertTo-Json -InputObject @($entries) -Compress -Depth 4))
}

function Get-JobExecutionIdentity {
  # ORDER-1708 / R3-2: execution identity of a job, computed from actual bytes. Canonical
  # serialization is JSON (unambiguous), NOT delimiter concatenation. Native defaults come
  # from the runner's own param block and Get-TesterExpertsDir. Required identities that
  # cannot be resolved are reported in `missing_required`, never pinned as a verified value.
  param($Job)
  $argsArr = @(Get-ArgsArray -JobArgs $Job.args | ForEach-Object { "$_" })
  $runnerPath = if ($Job.runner) { "$($Job.runner)" } else { $null }
  $runnerSha  = Get-FileSha256OrStatus -FilePath $runnerPath
  $isNative   = Test-IsNativeMt5Runner -RunnerPath $runnerPath
  $missing    = New-Object System.Collections.Generic.List[string]
  if (-not $runnerSha -or $runnerSha -eq 'MISSING') { $missing.Add('runner') }

  $setPath = if ($Job.set_file) { "$($Job.set_file)" } else { Get-ArgValue -ArgsArray $argsArr -Name "-SetFile" }
  $setSha  = Get-FileSha256OrStatus -FilePath $setPath
  if ($isNative -and (-not $setPath -or $setSha -eq 'MISSING')) { $missing.Add('set') }

  $expertArg = if ($Job.expert) { "$($Job.expert)" } else { Get-ArgValue -ArgsArray $argsArr -Name "-Expert" }
  $termArg   = Get-ArgValue -ArgsArray $argsArr -Name "-Terminal"
  $dataDir   = Get-ArgValue -ArgsArray $argsArr -Name "-DataDir"
  if ($isNative) {
    if (-not $termArg) { $termArg = Get-RunnerParamDefault -RunnerPath $runnerPath -ParamName 'Terminal' }
    if (-not $dataDir) { $dataDir = Get-RunnerParamDefault -RunnerPath $runnerPath -ParamName 'DataDir' }
  }
  $portable = [bool](@($argsArr | Where-Object { "$_" -ieq '-Portable' }).Count)

  $binPath = if ($Job.binary_path) { "$($Job.binary_path)" } else { $null }
  if (-not $binPath -and $isNative -and $expertArg) {
    . (Join-Path $PSScriptRoot 'lib\binary_staleness.ps1')
    $expDir = Get-TesterExpertsDir -TerminalPath $termArg -DataDir $dataDir -Portable:$portable
    if ($expDir) {
      $relExp = ($expertArg -replace '/', '\').TrimStart('\')
      if (-not $relExp.ToLowerInvariant().EndsWith(".ex5")) { $relExp = "$relExp.ex5" }
      $binPath = Join-Path $expDir $relExp
    }
  }
  $binSha = Get-FileSha256OrStatus -FilePath $binPath
  if ($isNative -and (-not $binPath -or $binSha -eq 'MISSING')) { $missing.Add('binary') }

  $srcPath = if ($Job.source_path) { "$($Job.source_path)" } else { $null }
  if (-not $srcPath -and $expertArg) {
    $leaf = [System.IO.Path]::GetFileNameWithoutExtension(($expertArg -replace '/', '\'))
    $candidateSrc = Join-Path (Split-Path -Parent $PSScriptRoot) ("ea_template\" + $leaf + ".mq5")
    if (Test-Path -LiteralPath $candidateSrc) { $srcPath = $candidateSrc }
  }
  $srcSha = Get-FileSha256OrStatus -FilePath $srcPath
  $depsSha = Get-RunnerDependencySha256 -RunnerPath $runnerPath
  $expectArt = if ($Job.expect_artifact) { "$($Job.expect_artifact)" } else { $null }

  $core = [ordered]@{
    runner = $runnerPath; runner_sha256 = $runnerSha; runner_deps_sha256 = $depsSha
    args = $argsArr; lane = "$($Job.lane)"; model = "$($Job.model)"
    set_path = $setPath; set_sha256 = $setSha
    expert = $expertArg; terminal = $termArg; data_dir = $dataDir; portable = $portable
    binary_path = $binPath; binary_sha256 = $binSha
    source_path = $srcPath; source_sha256 = $srcSha
    expect_artifact = $expectArt
  }
  $canonicalSig = Get-StringSha256 -Text (ConvertTo-Json -InputObject $core -Compress -Depth 6)
  $core['canonical_signature'] = $canonicalSig
  $core['missing_required'] = @($missing)
  return [PSCustomObject]$core
}

function Get-IdentityDiffFields {
  param($PrevIdentity, $CurrIdentity)
  $diffs = New-Object System.Collections.Generic.List[string]
  foreach ($f in @('runner_sha256','runner_deps_sha256','set_sha256','binary_sha256','source_sha256','expect_artifact','terminal','data_dir')) {
    if ("$($PrevIdentity.$f)" -ne "$($CurrIdentity.$f)") { $diffs.Add($f) }
  }
  $prevArgs = ConvertTo-Json -InputObject @($PrevIdentity.args | ForEach-Object { "$_" }) -Compress
  $currArgs = ConvertTo-Json -InputObject @($CurrIdentity.args | ForEach-Object { "$_" }) -Compress
  if ($prevArgs -ne $currArgs) { $diffs.Add('args') }
  if ($diffs.Count -eq 0 -and ("$($PrevIdentity.canonical_signature)" -ne "$($CurrIdentity.canonical_signature)")) {
    $diffs.Add('canonical_signature')
  }
  return @($diffs)
}

function Test-ResumeAdmissionRecord {
  # R3-2 / R4-1 / R4-1B: a legacy done row (no execution_identity) is admitted ONLY when a sidecar
  # RESUME_ADMISSION.json is bound to the CURRENT manifest bytes, exact recorded state row,
  # expect_artifact path, artifact bytes, AND proves matching pinned hashes for all required
  # dependencies (runner, set, and binary/expert). If a job specifies a set file, binary, or expert
  # (or uses a native runner), but the legacy admission record lacks matching pinned hashes
  # (or if on-disk files drifted), it FAILS CLOSED ($false -> UNVERIFIED) to prevent stale/tampered
  # reports being admitted after same-path drift or unpinned native execution.
  param([string]$ManifestPath, $Job, $Rec)
  $admissionFile = Join-Path (Split-Path -Parent $ManifestPath) "RESUME_ADMISSION.json"
  if (-not (Test-Path -LiteralPath $admissionFile)) { return $false }
  try {
    $adm = Get-Content -LiteralPath $admissionFile -Raw | ConvertFrom-Json
    if (-not $adm.done_cases_frozen) { return $false }
    $manifestSha = (Get-FileHash -LiteralPath $ManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ("$($adm.manifest_sha256)".ToLowerInvariant() -ne $manifestSha) { return $false }
    if (-not $Job.expect_artifact -or "$($Job.expect_artifact)" -match '[\*\?\[]') { return $false }
    foreach ($entry in @($adm.done_cases_frozen)) {
      if (-not $entry.state -or "$($entry.state.id)" -ne "$($Rec.id)") { continue }
      $s = $entry.state
      if ("$($s.state)" -ne 'done' -or "$($s.exit_code)" -ne '0') { return $false }
      if ("$($s.runner)" -ne "$($Job.runner)" -or "$($s.lane)" -ne "$($Job.lane)" -or "$($s.model)" -ne "$($Job.model)") { return $false }
      if ("$($s.start)" -ne "$($Rec.start)" -or "$($s.end)" -ne "$($Rec.end)" -or "$($Rec.exit_code)" -ne '0') { return $false }
      $a = try { [System.IO.Path]::GetFullPath("$($entry.raw_path)").ToLowerInvariant() } catch { "" }
      $b = try { [System.IO.Path]::GetFullPath("$($Job.expect_artifact)").ToLowerInvariant() } catch { "x" }
      if (-not $a -or $a -ne $b) { return $false }
      if (-not (Test-Path -LiteralPath "$($entry.raw_path)")) { return $false }
      $actual = (Get-FileHash -LiteralPath "$($entry.raw_path)" -Algorithm SHA256).Hash.ToLowerInvariant()
      if ($actual -ne "$($entry.raw_sha256)".ToLowerInvariant()) { return $false }

      # R4-1 / R4-1B Fail-Closed Pinned Dependency Checks:
      $argsArr = @(Get-ArgsArray -JobArgs $Job.args | ForEach-Object { "$_" })
      $isNative = Test-IsNativeMt5Runner -RunnerPath "$($Job.runner)"

      # 1. Runner pinned hash check (mandatory for all legacy admissions)
      if (-not $entry.runner_sha256) { return $false }
      if (-not (Test-Path -LiteralPath "$($Job.runner)")) { return $false }
      $currRunnerSha = (Get-FileHash -LiteralPath "$($Job.runner)" -Algorithm SHA256).Hash.ToLowerInvariant()
      if ($currRunnerSha -ne "$($entry.runner_sha256)".ToLowerInvariant()) { return $false }

      # 2. Set file resolution & pinned hash check
      $setPath = if ($Job.set_file) { "$($Job.set_file)" } else { Get-ArgValue -ArgsArray $argsArr -Name "-SetFile" }
      if ($setPath) {
        if (-not $entry.set_sha256) { return $false }
        if (-not (Test-Path -LiteralPath $setPath)) { return $false }
        $currSetSha = (Get-FileHash -LiteralPath $setPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($currSetSha -ne "$($entry.set_sha256)".ToLowerInvariant()) { return $false }
      }

      # 3. Binary / Expert resolution & pinned hash check (R4-1 & R4-1B)
      $expertArg = if ($Job.expert) { "$($Job.expert)" } else { Get-ArgValue -ArgsArray $argsArr -Name "-Expert" }
      $binPath = if ($Job.binary_path) { "$($Job.binary_path)" } else { Get-ArgValue -ArgsArray $argsArr -Name "-BinaryPath" }
      if (-not $binPath -and $expertArg) {
        $termArg = Get-ArgValue -ArgsArray $argsArr -Name "-Terminal"
        if (-not $termArg) { $termArg = Get-RunnerParamDefault -RunnerPath "$($Job.runner)" -ParamName 'Terminal' }
        $dataDir = Get-ArgValue -ArgsArray $argsArr -Name "-DataDir"
        if (-not $dataDir) { $dataDir = Get-RunnerParamDefault -RunnerPath "$($Job.runner)" -ParamName 'DataDir' }
        $portable = [bool](@($argsArr | Where-Object { "$_" -ieq '-Portable' }).Count)
        # Worktree-safe (A10 C1a): resolve the staleness library only from this checkout. A missing
        # library refuses the resume instead of loading another checkout's copy.
        $scriptsDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($Job.runner -and (Test-Path -LiteralPath "$($Job.runner)")) { Split-Path -Parent "$($Job.runner)" } else { $null }
        if (-not $scriptsDir) { return $false }
        $stalenessLib = Join-Path $scriptsDir 'lib\binary_staleness.ps1'
        if (-not (Test-Path -LiteralPath $stalenessLib)) { return $false }
        . $stalenessLib
        $expDir = if (Get-Command 'Get-TesterExpertsDir' -ErrorAction SilentlyContinue) {
          Get-TesterExpertsDir -TerminalPath $termArg -DataDir $dataDir -Portable:$portable
        } else { $null }

        $relExp = ($expertArg -replace '/', '\').TrimStart('\')
        if (-not $relExp.ToLowerInvariant().EndsWith(".ex5")) { $relExp = "$relExp.ex5" }

        if ($expDir) {
          # R4-1C: authoritative Terminal/DataDir Experts directory MUST win.
          # NEVER fall back to a decoy beside runner/manifest when authoritative path is known.
          $binPath = Join-Path $expDir $relExp
        } elseif (-not $isNative) {
          # Non-native mock runners only: allow local fallback if no terminal/data directory exists
          $runnerDir = Split-Path -Parent "$($Job.runner)"
          $manDir = Split-Path -Parent $ManifestPath
          if (Test-Path -LiteralPath (Join-Path $runnerDir $relExp)) {
            $binPath = Join-Path $runnerDir $relExp
          } elseif (Test-Path -LiteralPath (Join-Path $manDir $relExp)) {
            $binPath = Join-Path $manDir $relExp
          }
        }
      }

      # Fail closed if a native runner or expert is used, or a binary path is defined:
      # Pinned binary_sha256 is strictly required in the admission record.
      if ($binPath -or $expertArg -or $isNative) {
        if (-not $entry.binary_sha256) { return $false }
        if (-not $binPath -or -not (Test-Path -LiteralPath $binPath)) { return $false }
        $currBinSha = (Get-FileHash -LiteralPath $binPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($currBinSha -ne "$($entry.binary_sha256)".ToLowerInvariant()) { return $false }
      }

      # 4. Runner dependency resolution & pinned hash check (R4-1D)
      $currDepsSha = Get-RunnerDependencySha256 -RunnerPath "$($Job.runner)"
      $entryDepsSha = if ($entry.runner_deps_sha256) { "$($entry.runner_deps_sha256)".ToLowerInvariant() } else { $null }
      if ($currDepsSha) {
        if (-not $entryDepsSha) { return $false }
        if ($currDepsSha -ne $entryDepsSha) { return $false }
      } elseif ($entryDepsSha) {
        return $false
      }

      # 5. Source code resolution & pinned hash check (R4-1D)
      $srcPath = if ($Job.source_path) { "$($Job.source_path)" } else { Get-ArgValue -ArgsArray $argsArr -Name "-SourcePath" }
      if (-not $srcPath -and $expertArg) {
        $leaf = [System.IO.Path]::GetFileNameWithoutExtension(($expertArg -replace '/', '\'))
        $scriptsDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($Job.runner -and (Test-Path -LiteralPath "$($Job.runner)")) { Split-Path -Parent "$($Job.runner)" } else { $null }
        if (-not $scriptsDir) { return $false }
        $repoRoot = Split-Path -Parent $scriptsDir
        $candidateSrc = Join-Path $repoRoot ("ea_template\" + $leaf + ".mq5")
        if (Test-Path -LiteralPath $candidateSrc) { $srcPath = $candidateSrc }
      }
      $entrySrcSha = if ($entry.source_sha256) { "$($entry.source_sha256)".ToLowerInvariant() } else { $null }
      if ($srcPath) {
        if (-not $entrySrcSha) { return $false }
        if (-not (Test-Path -LiteralPath $srcPath)) { return $false }
        $currSrcSha = (Get-FileHash -LiteralPath $srcPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($currSrcSha -ne $entrySrcSha) { return $false }
      } elseif ($entrySrcSha) {
        return $false
      }

      return $true
    }
  } catch { return $false }
  return $false
}

function Test-ActiveNativeLaneProcess {
  param($Job, [switch]$SimulateActive)
  if ($SimulateActive) { return $true }
  $mockPath = try { ([System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '_test\mock_runner.ps1'))).ToLowerInvariant() } catch { "" }
  $runnerFull = try { ([System.IO.Path]::GetFullPath("$($Job.runner)")).ToLowerInvariant() } catch { "$($Job.runner)".ToLowerInvariant() }
  if ($runnerFull -eq $mockPath) { return $false }
  $argsArr = Get-ArgsArray -JobArgs $Job.args
  $termArg = Get-ArgValue -ArgsArray $argsArr -Name "-Terminal"
  $activeProcs = @(Get-Process -Name "terminal64", "metaeditor64" -ErrorAction SilentlyContinue)
  if ($activeProcs.Count -eq 0) { return $false }
  if ($termArg) {
    $termNorm = try { ([System.IO.Path]::GetFullPath($termArg)).ToLowerInvariant() } catch { $termArg.ToLowerInvariant() }
    $termDir  = Split-Path -Parent $termNorm
    foreach ($p in $activeProcs) {
      $pPath = try { ([System.IO.Path]::GetFullPath("$($p.Path)")).ToLowerInvariant() } catch { "" }
      if (-not $pPath -or $pPath.StartsWith($termDir)) { return $true }
    }
    return $false
  }
  return $true
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
    $existingRec = $priorById[$job.id]
    if (-not ($existingRec.PSObject.Properties.Name -contains "execution_identity")) {
      $existingRec | Add-Member -MemberType NoteProperty -Name "execution_identity" -Value $null
    }
    if (-not ($existingRec.PSObject.Properties.Name -contains "artifact_sha256")) {
      $existingRec | Add-Member -MemberType NoteProperty -Name "artifact_sha256" -Value $null
    }
    $records.Add($existingRec)
  } else {
    $records.Add([PSCustomObject]@{
      id                 = $job.id
      runner             = $job.runner
      lane               = $job.lane
      model              = $job.model
      state              = "pending"
      start              = $null
      end                = $null
      exit_code          = $null
      fail_reason        = $null
      execution_identity = $null
      artifact_sha256    = $null
    })
  }
}
Write-StateFile -Records $records -Path $stateFile

# --- run jobs sequentially, blocking, lane-aware, fail-visible --------------

$failed = $false
$failReason = ""

# R3-1: states that must NEVER fall through to execution on a repeated invocation. They keep
# the original record (identity, artifact reference, fail_reason) until an operator reconciles
# explicitly (inspect, then edit/remove that state row). Explicitly "failed" and "pending" rows
# keep their normal retry behavior. "running" at load time is an orphan (a live run is excluded
# by the lane lock / native-process guard) and also needs explicit reconciliation.
$script:RefusalStates = @('IDENTITY_MISMATCH','ARTIFACT_MISMATCH','ARTIFACT_MISSING','UNVERIFIED','running')

foreach ($rec in $records) {
  $job = $manifestJobs | Where-Object { $_.id -eq $rec.id } | Select-Object -First 1

  if (Test-ActiveNativeLaneProcess -Job $job -SimulateActive:$SimulateActiveNativeProcess) {
    Write-Output "ABORT: active native process detected for job '$($rec.id)' on lane '$($job.lane)' -- refusing to launch or resume while terminal64/metaeditor64 is running."
    exit 2
  }

  if ($script:RefusalStates -contains "$($rec.state)") {
    $failReason = "job '$($rec.id)' is in non-runnable state '$($rec.state)' ($($rec.fail_reason)) -- record, identity and artifact left unchanged; reconcile explicitly (inspect the evidence, then edit/remove this state row) before re-running."
    Write-Output "REFUSED-STATE ($($rec.state)): $failReason"
    $failed = $true
    break
  }
  if ("$($rec.state)" -notin @('pending','failed','done')) {
    $failReason = "job '$($rec.id)' has unknown state '$($rec.state)' -- refusing (fail-closed)."
    Write-Output "REFUSED-STATE (unknown): $failReason"
    $failed = $true
    break
  }

  if ($rec.state -eq "done") {
    $currIdentity = Get-JobExecutionIdentity -Job $job
    if ($null -ne $rec.execution_identity) {
      $diffFields = @(Get-IdentityDiffFields -PrevIdentity $rec.execution_identity -CurrIdentity $currIdentity)
      if ($diffFields.Count -gt 0) {
        $rec.state       = "IDENTITY_MISMATCH"
        $rec.fail_reason = "IDENTITY_MISMATCH on resume: changed [$($diffFields -join ', ')]"
        Write-StateFile -Records $records -Path $stateFile
        $failReason = "job '$($rec.id)' -- $($rec.fail_reason)"
        Write-Output "REFUSE-SKIP (IDENTITY_MISMATCH): $failReason -- stopping all remaining jobs."
        $failed = $true
        break
      }
      if ($job.expect_artifact) {
        $artItems = @(Get-Item -Path $job.expect_artifact -ErrorAction SilentlyContinue)
        if ($artItems.Count -eq 0) {
          $rec.state       = "ARTIFACT_MISSING"
          $rec.fail_reason = "ARTIFACT_MISSING on resume: $($job.expect_artifact)"
          Write-StateFile -Records $records -Path $stateFile
          $failReason = "job '$($rec.id)' -- $($rec.fail_reason)"
          Write-Output "REFUSE-SKIP (ARTIFACT_MISSING): $failReason -- stopping all remaining jobs."
          $failed = $true
          break
        }
        $currArtSha = Get-ArtifactSha256 -Pattern $job.expect_artifact
        if (-not $rec.artifact_sha256 -or ("$($rec.artifact_sha256)" -ne "$currArtSha")) {
          $rec.state       = "ARTIFACT_MISMATCH"
          $rec.fail_reason = "ARTIFACT_MISMATCH on resume: expected $($rec.artifact_sha256), actual $currArtSha"
          Write-StateFile -Records $records -Path $stateFile
          $failReason = "job '$($rec.id)' -- $($rec.fail_reason)"
          Write-Output "REFUSE-SKIP (ARTIFACT_MISMATCH): $failReason -- stopping all remaining jobs."
          $failed = $true
          break
        }
      }
      Write-Output "SKIP (already done): $($rec.id)"
      continue
    } else {
      if (Test-ResumeAdmissionRecord -ManifestPath $Manifest -Job $job -Rec $rec) {
        Write-Output "SKIP (already done, legacy RESUME_ADMISSION fully pinned to manifest bytes + state row + artifact bytes + dependency hashes): $($rec.id)"
        continue
      }
      $rec.state       = "UNVERIFIED"
      $rec.fail_reason = "UNVERIFIED on resume: legacy done record lacks execution_identity and no RESUME_ADMISSION.json bound to this manifest/job/state/artifact"
      Write-StateFile -Records $records -Path $stateFile
      $failReason = "job '$($rec.id)' -- $($rec.fail_reason)"
      Write-Output "REFUSE-SKIP (UNVERIFIED): $failReason -- stopping all remaining jobs."
      $failed = $true
      break
    }
  }

  $lane = "$($job.lane)"
  # Fix #2: args must be resolved BEFORE locking, since the lock key itself
  # depends on whether the job's args carry a -Terminal value (physical
  # install) — falls back to the lane label only when no -Terminal is given.
  $argsArray = Get-ArgsArray -JobArgs $job.args
  $lockKey  = Get-LaneLockKey -Lane $lane -ArgsArray $argsArray
  $lockPath = Get-LaneLockPath -Key $lockKey

  # R3-2: capture the REAL execution identity BEFORE launch; refuse (without launching) when a
  # required native identity (runner / set / binary) cannot be resolved.
  $launchIdentity = Get-JobExecutionIdentity -Job $job
  if (@($launchIdentity.missing_required).Count -gt 0) {
    $rec.state       = "failed"
    $rec.fail_reason = "required execution identity unresolved before launch: [$(@($launchIdentity.missing_required) -join ', ')] -- not launched"
    Write-StateFile -Records $records -Path $stateFile
    $failReason = "job '$($rec.id)' -- $($rec.fail_reason)"
    Write-Output "FAIL: $failReason -- stopping all remaining jobs."
    $failed = $true
    break
  }

  Enter-LaneLock -LockPath $lockPath -Lane $lockKey -TimeoutSec $LaneLockTimeoutSec -PollMs $LaneLockPollMs
  try {
    $startDt = Get-Date
    $rec.state       = "running"
    $rec.start       = $startDt.ToString("o")
    $rec.exit_code   = $null
    $rec.fail_reason = $null
    $rec.execution_identity = $null
    $rec.artifact_sha256    = $null
    if (-not ($rec.PSObject.Properties.Name -contains 'launch_identity')) { $rec | Add-Member -MemberType NoteProperty -Name 'launch_identity' -Value $null }
    $rec.launch_identity = $launchIdentity
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

    # R3-2: re-capture identity AFTER the run. Anything that changed while the job ran cannot be
    # stamped as the identity of the output; the job is failed (retryable) with the changed fields.
    if ($jobReasons.Count -eq 0) {
      $postIdentity = Get-JobExecutionIdentity -Job $job
      $changedDuring = @(Get-IdentityDiffFields -PrevIdentity $launchIdentity -CurrIdentity $postIdentity)
      if ($changedDuring.Count -gt 0) {
        $jobReasons.Add("execution identity changed DURING the run [$($changedDuring -join ', ')] -- output not stamped as verified")
      }
    }

    if ($jobReasons.Count -eq 0) {
      $rec.state              = "done"
      $rec.fail_reason        = $null
      $rec.execution_identity = $launchIdentity
      $rec.artifact_sha256    = Get-ArtifactSha256 -Pattern $job.expect_artifact
      Write-StateFile -Records $records -Path $stateFile
      Write-Output "OK: id=$($rec.id) exit=0"
    } else {
      $rec.state              = "failed"
      $rec.fail_reason        = ($jobReasons -join "; ")
      $rec.execution_identity = $null
      $rec.artifact_sha256    = $null
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
