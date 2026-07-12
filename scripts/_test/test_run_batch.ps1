<#
test_run_batch.ps1 — ORDER-100 Phase 3 acceptance driver for scripts\run_batch.ps1.

Runs every acceptance scenario against the MOCK runner only (scripts\_test\mock_runner.ps1)
— never real MT4/MT5 — and prints one PASS/FAIL line per criterion. All scratch
manifests/state/markers live under $env:TEMP\run_batch_test (plus the global lane-lock
dir under $env:TEMP\ealab_run_batch_locks), never in the repo.
#>
$ErrorActionPreference = "Stop"

$RepoRoot   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # scripts\_test -> scripts -> repo root
$RunBatch   = Join-Path $RepoRoot "scripts\run_batch.ps1"
$MockRunner = Join-Path $RepoRoot "scripts\_test\mock_runner.ps1"
$TestRoot   = Join-Path $env:TEMP "run_batch_test"
$GlobalLockDir = Join-Path $env:TEMP "ealab_run_batch_locks"

if (Test-Path $TestRoot) {
  # Clean scratch dir from a previous run — TEMP scratch only, not the repo, not a process.
  Remove-Item -Path $TestRoot -Recurse -Force
}
New-Item -ItemType Directory -Force $TestRoot | Out-Null   # scratch dir scaffold, not process-related

if (Test-Path $GlobalLockDir) {
  # Clean stale lane-lock files from a previous (possibly interrupted) test run — TEMP only.
  Remove-Item -Path $GlobalLockDir -Recurse -Force
}

$script:allResults = New-Object System.Collections.Generic.List[object]

function Report {
  param([string]$Name, [bool]$Pass, [string]$Detail = "")
  $status = if ($Pass) { "PASS" } else { "FAIL" }
  $line = "[$status] $Name"
  if ($Detail) { $line += " -- $Detail" }
  Write-Output $line
  $script:allResults.Add([PSCustomObject]@{ name = $Name; pass = $Pass })
}

function New-ManifestFile {
  param([string]$Path, [array]$Jobs)
  $json = ConvertTo-Json -InputObject $Jobs -Depth 8
  Set-Content -Path $Path -Value $json -Encoding utf8
}

function Invoke-RunBatch {
  param([string]$ManifestPath, [string]$StateDirPath)
  $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $RunBatch -Manifest $ManifestPath -StateDir $StateDirPath 2>&1 | Out-String
  return @{ Output = $out; ExitCode = $LASTEXITCODE }
}

function Get-StateRecords {
  param([string]$StateDirPath)
  $stateFile = Join-Path $StateDirPath "state.json"
  if (-not (Test-Path $stateFile)) { return @() }
  return @(Get-Content $stateFile -Raw | ConvertFrom-Json)
}

Write-Output "=== ORDER-100 run_batch.ps1 acceptance tests ==="
Write-Output "RepoRoot   : $RepoRoot"
Write-Output "RunBatch   : $RunBatch"
Write-Output "MockRunner : $MockRunner"
Write-Output "TestRoot   : $TestRoot"
Write-Output ""

# ============================================================================
# Criterion 1: all-success manifest => run_batch exit 0 AND every job state == done
# ============================================================================
$c1 = Join-Path $TestRoot "case1"
New-Item -ItemType Directory -Force $c1 | Out-Null
$c1Markers = Join-Path $c1 "markers"
$c1State   = Join-Path $c1 "state"

$c1Jobs = @(
  @{ id = "job1"; runner = $MockRunner; lane = "A"; model = 1;
     args = @("-MarkerFile", (Join-Path $c1Markers "m1.marker"), "-ExitCode", 0, "-JobId", "job1") },
  @{ id = "job2"; runner = $MockRunner; lane = "B"; model = 1;
     args = @("-MarkerFile", (Join-Path $c1Markers "m2.marker"), "-ExitCode", 0, "-JobId", "job2") },
  @{ id = "job3"; runner = $MockRunner; lane = "C"; model = 1;
     args = @("-MarkerFile", (Join-Path $c1Markers "m3.marker"), "-ExitCode", 0, "-JobId", "job3") }
)
$c1Manifest = Join-Path $c1 "manifest.json"
New-ManifestFile -Path $c1Manifest -Jobs $c1Jobs

$r1 = Invoke-RunBatch -ManifestPath $c1Manifest -StateDirPath $c1State
$rec1 = Get-StateRecords -StateDirPath $c1State
$allDone1 = ($rec1.Count -eq 3) -and (-not ($rec1 | Where-Object { $_.state -ne "done" }))
Report "1. all-success manifest -> exit0 + all done" `
  (($r1.ExitCode -eq 0) -and $allDone1) `
  ("exit=$($r1.ExitCode) states=[" + (($rec1 | ForEach-Object { "$($_.id)=$($_.state)" }) -join ",") + "]")

# ============================================================================
# Criterion 2: job 2 of 3 fails => job 3 never runs, run_batch exit != 0, job2 state == failed
# ============================================================================
$c2 = Join-Path $TestRoot "case2"
New-Item -ItemType Directory -Force $c2 | Out-Null
$c2Markers = Join-Path $c2 "markers"
$c2State   = Join-Path $c2 "state"

$c2M3 = Join-Path $c2Markers "m3.marker"
$c2Jobs = @(
  @{ id = "job1"; runner = $MockRunner; lane = "A"; model = 1;
     args = @("-MarkerFile", (Join-Path $c2Markers "m1.marker"), "-ExitCode", 0, "-JobId", "job1") },
  @{ id = "job2"; runner = $MockRunner; lane = "B"; model = 1;
     args = @("-MarkerFile", (Join-Path $c2Markers "m2.marker"), "-ExitCode", 5, "-JobId", "job2") },
  @{ id = "job3"; runner = $MockRunner; lane = "C"; model = 1;
     args = @("-MarkerFile", $c2M3, "-ExitCode", 0, "-JobId", "job3") }
)
$c2Manifest = Join-Path $c2 "manifest.json"
New-ManifestFile -Path $c2Manifest -Jobs $c2Jobs

$r2 = Invoke-RunBatch -ManifestPath $c2Manifest -StateDirPath $c2State
$rec2 = Get-StateRecords -StateDirPath $c2State
$job2Rec = $rec2 | Where-Object { $_.id -eq "job2" } | Select-Object -First 1
$job3Rec = $rec2 | Where-Object { $_.id -eq "job3" } | Select-Object -First 1
$marker3Absent = -not (Test-Path $c2M3)
$pass2 = ($r2.ExitCode -ne 0) -and $marker3Absent -and ($job2Rec.state -eq "failed") -and ($job3Rec.state -eq "pending")
Report "2. mid-job failure -> job3 never runs, exit!=0, job2=failed" `
  $pass2 `
  ("exit=$($r2.ExitCode) job2.state=$($job2Rec.state) job3.state=$($job3Rec.state) marker3_absent=$marker3Absent job2.fail_reason=$($job2Rec.fail_reason)")

# ============================================================================
# Criterion 3: resume after an interrupted/failed run -> only not-done jobs execute;
# done jobs' markers keep their original timestamp/content (idempotent).
# ============================================================================
$c3 = Join-Path $TestRoot "case3"
New-Item -ItemType Directory -Force $c3 | Out-Null
$c3Markers = Join-Path $c3 "markers"
$c3State   = Join-Path $c3 "state"
$c3ExitCodeFile = Join-Path $c3 "job2_exitcode.txt"
"5" | Set-Content -Path $c3ExitCodeFile -Encoding utf8   # first attempt: job2 fails

$c3M1 = Join-Path $c3Markers "m1.marker"
$c3M2 = Join-Path $c3Markers "m2.marker"
$c3M3 = Join-Path $c3Markers "m3.marker"
$c3Jobs = @(
  @{ id = "job1"; runner = $MockRunner; lane = "A"; model = 1;
     args = @("-MarkerFile", $c3M1, "-ExitCode", 0, "-JobId", "job1") },
  @{ id = "job2"; runner = $MockRunner; lane = "B"; model = 1;
     args = @("-MarkerFile", $c3M2, "-ExitCode", 0, "-ExitCodeFile", $c3ExitCodeFile, "-JobId", "job2") },
  @{ id = "job3"; runner = $MockRunner; lane = "C"; model = 1;
     args = @("-MarkerFile", $c3M3, "-ExitCode", 0, "-JobId", "job3") }
)
$c3Manifest = Join-Path $c3 "manifest.json"
New-ManifestFile -Path $c3Manifest -Jobs $c3Jobs

# --- first (interrupted/failed) run ---
$r3a = Invoke-RunBatch -ManifestPath $c3Manifest -StateDirPath $c3State
$rec3a = Get-StateRecords -StateDirPath $c3State
$job1After1st = $rec3a | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
$job3AbsentAfterFirstRun = -not (Test-Path $c3M3)
$firstRunOk = ($r3a.ExitCode -ne 0) -and $job3AbsentAfterFirstRun -and ($job1After1st.state -eq "done")

$m1ContentBefore = Get-Content $c3M1 -Raw
$m1TimeBefore    = (Get-Item $c3M1).LastWriteTimeUtc

# flip job2 to succeed on the next attempt, WITHOUT touching the manifest
"0" | Set-Content -Path $c3ExitCodeFile -Encoding utf8

# --- resume run (same manifest + same StateDir) ---
$r3b = Invoke-RunBatch -ManifestPath $c3Manifest -StateDirPath $c3State
$rec3b = Get-StateRecords -StateDirPath $c3State

$m1ContentAfter = Get-Content $c3M1 -Raw
$m1TimeAfter    = (Get-Item $c3M1).LastWriteTimeUtc
$job1Unchanged  = ($m1ContentBefore -eq $m1ContentAfter) -and ($m1TimeBefore -eq $m1TimeAfter)

$allDone3 = ($rec3b.Count -eq 3) -and (-not ($rec3b | Where-Object { $_.state -ne "done" }))
$job3RanNow = Test-Path $c3M3

$pass3 = $firstRunOk -and $job1Unchanged -and $allDone3 -and $job3RanNow -and ($r3b.ExitCode -eq 0)
Report "3. resume -> only pending/failed jobs re-run, done jobs' markers frozen (idempotent)" `
  $pass3 `
  ("firstRun: exit=$($r3a.ExitCode) job1=done:$($job1After1st.state -eq 'done') job3-absent:$job3AbsentAfterFirstRun; " + `
   "resume: exit=$($r3b.ExitCode) job1MarkerUnchanged=$job1Unchanged allDone=$allDone3 job3Ran=$job3RanNow")

# ============================================================================
# Criterion 4: lane collision (same process, same StateDir) -> two same-lane jobs'
# [start,end] never overlap in the state file (sequential/lane-safe); the GLOBAL
# lane lock file is created then removed.
# ============================================================================
$c4 = Join-Path $TestRoot "case4"
New-Item -ItemType Directory -Force $c4 | Out-Null
$c4Markers = Join-Path $c4 "markers"
$c4State   = Join-Path $c4 "state"
$c4Lane    = "M5-1"

$c4Jobs = @(
  @{ id = "job1"; runner = $MockRunner; lane = $c4Lane; model = 1;
     args = @("-MarkerFile", (Join-Path $c4Markers "m1.marker"), "-ExitCode", 0, "-JobId", "job1", "-SleepMs", 300) },
  @{ id = "job2"; runner = $MockRunner; lane = $c4Lane; model = 1;
     args = @("-MarkerFile", (Join-Path $c4Markers "m2.marker"), "-ExitCode", 0, "-JobId", "job2", "-SleepMs", 300) }
)
$c4Manifest = Join-Path $c4 "manifest.json"
New-ManifestFile -Path $c4Manifest -Jobs $c4Jobs

$r4 = Invoke-RunBatch -ManifestPath $c4Manifest -StateDirPath $c4State
$rec4 = Get-StateRecords -StateDirPath $c4State
$j1 = $rec4 | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
$j2 = $rec4 | Where-Object { $_.id -eq "job2" } | Select-Object -First 1

$j1Start = [DateTime]$j1.start; $j1End = [DateTime]$j1.end
$j2Start = [DateTime]$j2.start; $j2End = [DateTime]$j2.end
$noOverlap = ($j1End -le $j2Start) -or ($j2End -le $j1Start)

$safeLaneName = ($c4Lane -replace '[^A-Za-z0-9_\-]', '_')
$c4LockPath = Join-Path $GlobalLockDir "lane_$safeLaneName.lock"   # GLOBAL location (fix #2), not under StateDir
$lockAbsentAfter = -not (Test-Path $c4LockPath)
$acquireCount = ([regex]::Matches($r4.Output, [regex]::Escape("LANE-LOCK ACQUIRE lane=$c4Lane"))).Count
$releaseCount = ([regex]::Matches($r4.Output, [regex]::Escape("LANE-LOCK RELEASE lane=$c4Lane"))).Count

$pass4 = ($r4.ExitCode -eq 0) -and $noOverlap -and $lockAbsentAfter -and ($acquireCount -eq 2) -and ($releaseCount -eq 2)
Report "4. lane collision (same process) -> same-lane jobs never overlap, global lock created+removed" `
  $pass4 `
  ("job1=[$($j1.start)..$($j1.end)] job2=[$($j2.start)..$($j2.end)] noOverlap=$noOverlap lockPath=$c4LockPath lockAbsentAfter=$lockAbsentAfter acquireCount=$acquireCount releaseCount=$releaseCount")

# ============================================================================
# Criterion 5: self-scan -> no Stop-Process/taskkill, and no -Force on a process.
# Scoped to run_batch.ps1 + the mock_runner.ps1 fixture (the two files that ship /
# execute logic). test_run_batch.ps1 itself is deliberately EXCLUDED: it necessarily
# contains the literal string 'Stop-Process|taskkill' as its OWN Select-String pattern
# text below, so scanning the scanner against itself would always self-match and is
# not a meaningful finding.
# ============================================================================
$scanPaths = @(
  (Join-Path $RepoRoot "scripts\run_batch.ps1"),
  (Join-Path $RepoRoot "scripts\_test\mock_runner.ps1")
)
$killHits = Select-String -Pattern 'Stop-Process|taskkill' -Path $scanPaths -ErrorAction SilentlyContinue
$noKillHits = ($null -eq $killHits) -or (@($killHits).Count -eq 0)

# any line with "-Force" that ALSO looks process-related (Get-Process / $proc / Kill / Stop-Process/taskkill) would be a violation
$forceLines = Select-String -Pattern '-Force' -Path $scanPaths -ErrorAction SilentlyContinue
$processyForceHits = @($forceLines | Where-Object { $_.Line -match '(?i)(Stop-Process|taskkill|Get-Process|\$proc\b|\.Kill\(\))' })
$noProcessyForce = (@($processyForceHits).Count -eq 0)

Report "5. self-scan: no Stop-Process/taskkill, no -Force on a process (run_batch.ps1 + mock_runner.ps1 fixture)" `
  ($noKillHits -and $noProcessyForce) `
  ("killHits=$(@($killHits).Count) processyForceHits=$(@($processyForceHits).Count)")

# ============================================================================
# Criterion 6 (fix #1 / false-green): mock EXITS 0 but prints "NO REPORT" on stdout
# (mimics mt4_run.ps1's real behavior) -> run_batch must mark the job FAILED, not done,
# and stop the batch, even though $LASTEXITCODE was 0.
# ============================================================================
$c6 = Join-Path $TestRoot "case6"
New-Item -ItemType Directory -Force $c6 | Out-Null
$c6Markers = Join-Path $c6 "markers"
$c6State   = Join-Path $c6 "state"

$c6Jobs = @(
  @{ id = "job1"; runner = $MockRunner; lane = "A"; model = 1;
     args = @("-MarkerFile", (Join-Path $c6Markers "m1.marker"), "-ExitCode", 0, "-JobId", "job1",
              "-StdoutText", "NO REPORT: nothing found") }
)
$c6Manifest = Join-Path $c6 "manifest.json"
New-ManifestFile -Path $c6Manifest -Jobs $c6Jobs

$r6 = Invoke-RunBatch -ManifestPath $c6Manifest -StateDirPath $c6State
$rec6 = Get-StateRecords -StateDirPath $c6State
$job1Rec6 = $rec6 | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
$pass6 = ($r6.ExitCode -ne 0) -and ($job1Rec6.state -eq "failed") -and ($job1Rec6.exit_code -eq 0) -and `
         ($job1Rec6.fail_reason -match "stdout matched failure pattern")
Report "6. FALSE-GREEN FIX: exit=0 + stdout 'NO REPORT' -> job marked FAILED (not done)" `
  $pass6 `
  ("exit=$($r6.ExitCode) job1.state=$($job1Rec6.state) job1.exit_code=$($job1Rec6.exit_code) job1.fail_reason=$($job1Rec6.fail_reason)")

# ============================================================================
# Criterion 7 (fix #1 / expect_artifact, negative control): exit=0, clean stdout,
# but the job's expect_artifact glob matches NOTHING -> job marked FAILED anyway.
# ============================================================================
$c7 = Join-Path $TestRoot "case7"
New-Item -ItemType Directory -Force $c7 | Out-Null
$c7Markers = Join-Path $c7 "markers"
$c7State   = Join-Path $c7 "state"
$c7ExpectGlob = Join-Path $c7 "reports\*.htm"   # directory doesn't even exist -> never matches

$c7Jobs = @(
  @{ id = "job1"; runner = $MockRunner; lane = "A"; model = 1;
     args = @("-MarkerFile", (Join-Path $c7Markers "m1.marker"), "-ExitCode", 0, "-JobId", "job1");
     expect_artifact = $c7ExpectGlob }
)
$c7Manifest = Join-Path $c7 "manifest.json"
New-ManifestFile -Path $c7Manifest -Jobs $c7Jobs

$r7 = Invoke-RunBatch -ManifestPath $c7Manifest -StateDirPath $c7State
$rec7 = Get-StateRecords -StateDirPath $c7State
$job1Rec7 = $rec7 | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
$pass7 = ($r7.ExitCode -ne 0) -and ($job1Rec7.state -eq "failed") -and ($job1Rec7.exit_code -eq 0) -and `
         ($job1Rec7.fail_reason -match "expect_artifact")
Report "7. expect_artifact MISSING -> job marked FAILED despite exit=0 + clean stdout" `
  $pass7 `
  ("exit=$($r7.ExitCode) job1.state=$($job1Rec7.state) job1.fail_reason=$($job1Rec7.fail_reason)")

# ============================================================================
# Criterion 8 (fix #1 / expect_artifact, positive control): exit=0, clean stdout,
# expect_artifact points at the marker file the mock runner itself just wrote -> done.
# ============================================================================
$c8 = Join-Path $TestRoot "case8"
New-Item -ItemType Directory -Force $c8 | Out-Null
$c8Markers = Join-Path $c8 "markers"
$c8State   = Join-Path $c8 "state"
$c8Marker  = Join-Path $c8Markers "m1.marker"

$c8Jobs = @(
  @{ id = "job1"; runner = $MockRunner; lane = "A"; model = 1;
     args = @("-MarkerFile", $c8Marker, "-ExitCode", 0, "-JobId", "job1");
     expect_artifact = $c8Marker }
)
$c8Manifest = Join-Path $c8 "manifest.json"
New-ManifestFile -Path $c8Manifest -Jobs $c8Jobs

$r8 = Invoke-RunBatch -ManifestPath $c8Manifest -StateDirPath $c8State
$rec8 = Get-StateRecords -StateDirPath $c8State
$job1Rec8 = $rec8 | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
$pass8 = ($r8.ExitCode -eq 0) -and ($job1Rec8.state -eq "done")
Report "8. expect_artifact PRESENT (fresh mtime) -> job succeeds normally" `
  $pass8 `
  ("exit=$($r8.ExitCode) job1.state=$($job1Rec8.state)")

# ============================================================================
# Criterion 9 (fix #4): duplicate job id in manifest -> abort exit 2 BEFORE anything runs.
# ============================================================================
$c9 = Join-Path $TestRoot "case9"
New-Item -ItemType Directory -Force $c9 | Out-Null
$c9Markers = Join-Path $c9 "markers"
$c9State   = Join-Path $c9 "state"
$c9M1 = Join-Path $c9Markers "m1.marker"
$c9M2 = Join-Path $c9Markers "m2.marker"

$c9Jobs = @(
  @{ id = "dup1"; runner = $MockRunner; lane = "A"; model = 1;
     args = @("-MarkerFile", $c9M1, "-ExitCode", 0, "-JobId", "dup1a") },
  @{ id = "dup1"; runner = $MockRunner; lane = "B"; model = 1;
     args = @("-MarkerFile", $c9M2, "-ExitCode", 0, "-JobId", "dup1b") }
)
$c9Manifest = Join-Path $c9 "manifest.json"
New-ManifestFile -Path $c9Manifest -Jobs $c9Jobs

$r9 = Invoke-RunBatch -ManifestPath $c9Manifest -StateDirPath $c9State
$noMarkers9 = (-not (Test-Path $c9M1)) -and (-not (Test-Path $c9M2))
$noState9   = -not (Test-Path (Join-Path $c9State "state.json"))
$pass9 = ($r9.ExitCode -eq 2) -and $noMarkers9 -and $noState9 -and ($r9.Output -match "duplicate job id")
Report "9. DUP-ID FIX: duplicate job id -> abort exit 2, nothing runs, no state written" `
  $pass9 `
  ("exit=$($r9.ExitCode) noMarkers=$noMarkers9 noState=$noState9 outputMentionsDup=$($r9.Output -match 'duplicate job id')")

# ============================================================================
# Criterion 10 (fix #5): model=4 job with a MISLEADING lane label ("fake-1", passes the
# label-only check) but a -Terminal arg pointing at the lane-2 install -> abort exit 2.
# ============================================================================
$c10 = Join-Path $TestRoot "case10"
New-Item -ItemType Directory -Force $c10 | Out-Null
$c10Markers = Join-Path $c10 "markers"
$c10State   = Join-Path $c10 "state"
$c10M1 = Join-Path $c10Markers "m1.marker"

$c10Jobs = @(
  @{ id = "job1"; runner = $MockRunner; lane = "fake-1"; model = 4;
     args = @("-MarkerFile", $c10M1, "-ExitCode", 0, "-JobId", "job1", "-Terminal", "D:\Meta 5b\terminal64.exe") }
)
$c10Manifest = Join-Path $c10 "manifest.json"
New-ManifestFile -Path $c10Manifest -Jobs $c10Jobs

$r10 = Invoke-RunBatch -ManifestPath $c10Manifest -StateDirPath $c10State
$noMarker10 = -not (Test-Path $c10M1)
$pass10 = ($r10.ExitCode -eq 2) -and $noMarker10 -and ($r10.Output -match "lane-1 install")
Report "10. MODEL-4 PHYSICAL FIX: lane label 'fake-1' but -Terminal=lane-2 install -> abort exit 2" `
  $pass10 `
  ("exit=$($r10.ExitCode) noMarker=$noMarker10 outputMentionsLane1Install=$($r10.Output -match 'lane-1 install')")

# ============================================================================
# Criterion 11 (fix #5, positive control): model=4 job whose -Terminal DOES match
# -Lane1Terminal (default 'D:\Meta 5\terminal64.exe') -> allowed to run and succeed,
# even though the lane label itself is nonstandard.
# ============================================================================
$c11 = Join-Path $TestRoot "case11"
New-Item -ItemType Directory -Force $c11 | Out-Null
$c11Markers = Join-Path $c11 "markers"
$c11State   = Join-Path $c11 "state"
$c11M1 = Join-Path $c11Markers "m1.marker"

$c11Jobs = @(
  @{ id = "job1"; runner = $MockRunner; lane = "fake-1"; model = 4;
     args = @("-MarkerFile", $c11M1, "-ExitCode", 0, "-JobId", "job1", "-Terminal", "D:\Meta 5\terminal64.exe") }
)
$c11Manifest = Join-Path $c11 "manifest.json"
New-ManifestFile -Path $c11Manifest -Jobs $c11Jobs

$r11 = Invoke-RunBatch -ManifestPath $c11Manifest -StateDirPath $c11State
$rec11 = Get-StateRecords -StateDirPath $c11State
$job1Rec11 = $rec11 | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
$pass11 = ($r11.ExitCode -eq 0) -and ($job1Rec11.state -eq "done")
Report "11. MODEL-4 PHYSICAL FIX (positive control): -Terminal matches lane-1 install -> runs fine" `
  $pass11 `
  ("exit=$($r11.ExitCode) job1.state=$($job1Rec11.state)")

# ============================================================================
# Criterion 12 (fix #3): state.json exists but is CORRUPT (not valid JSON) -> abort
# loudly (exit 2), nothing runs.
# ============================================================================
$c12 = Join-Path $TestRoot "case12"
New-Item -ItemType Directory -Force $c12 | Out-Null
$c12Markers = Join-Path $c12 "markers"
$c12State   = Join-Path $c12 "state"
New-Item -ItemType Directory -Force $c12State | Out-Null
"{ this is not valid json !!" | Set-Content -Path (Join-Path $c12State "state.json") -Encoding utf8
$c12M1 = Join-Path $c12Markers "m1.marker"

$c12Jobs = @(
  @{ id = "job1"; runner = $MockRunner; lane = "A"; model = 1;
     args = @("-MarkerFile", $c12M1, "-ExitCode", 0, "-JobId", "job1") }
)
$c12Manifest = Join-Path $c12 "manifest.json"
New-ManifestFile -Path $c12Manifest -Jobs $c12Jobs

$r12 = Invoke-RunBatch -ManifestPath $c12Manifest -StateDirPath $c12State
$noMarker12 = -not (Test-Path $c12M1)
$pass12 = ($r12.ExitCode -eq 2) -and $noMarker12 -and ($r12.Output -match "not valid JSON")
Report "12. ATOMIC-STATE FIX: corrupt state.json -> abort loudly exit 2, nothing runs" `
  $pass12 `
  ("exit=$($r12.ExitCode) noMarker=$noMarker12 outputMentionsInvalidJson=$($r12.Output -match 'not valid JSON')")

# ============================================================================
# Criterion 13 (fix #3): after a normal successful run, no leftover state.json.tmp
# file remains (proves the write-tmp-then-move pattern cleans up after itself).
# ============================================================================
$c13 = Join-Path $TestRoot "case13"
New-Item -ItemType Directory -Force $c13 | Out-Null
$c13Markers = Join-Path $c13 "markers"
$c13State   = Join-Path $c13 "state"

$c13Jobs = @(
  @{ id = "job1"; runner = $MockRunner; lane = "A"; model = 1;
     args = @("-MarkerFile", (Join-Path $c13Markers "m1.marker"), "-ExitCode", 0, "-JobId", "job1") }
)
$c13Manifest = Join-Path $c13 "manifest.json"
New-ManifestFile -Path $c13Manifest -Jobs $c13Jobs

$r13 = Invoke-RunBatch -ManifestPath $c13Manifest -StateDirPath $c13State
$noTmpLeftover = -not (Test-Path (Join-Path $c13State "state.json.tmp"))
$stateJsonExists = Test-Path (Join-Path $c13State "state.json")
$pass13 = ($r13.ExitCode -eq 0) -and $noTmpLeftover -and $stateJsonExists
Report "13. ATOMIC-STATE FIX: no leftover state.json.tmp after a normal run" `
  $pass13 `
  ("exit=$($r13.ExitCode) noTmpLeftover=$noTmpLeftover stateJsonExists=$stateJsonExists")

# ============================================================================
# Criterion 14 (fix #2 / real cross-process test): launch TWO run_batch.ps1 PROCESSES
# concurrently (Start-Process), same lane, DIFFERENT -StateDir. If the lane lock were
# still keyed under -StateDir (the old bug), both would acquire "independent" locks and
# their mock-runner [start,end] intervals (each ~1s sleep) would overlap. With the fix
# (lock keyed by a GLOBAL fixed path), the two runs must serialize -> no overlap.
# ============================================================================
$c14 = Join-Path $TestRoot "case14"
New-Item -ItemType Directory -Force $c14 | Out-Null
$c14A = Join-Path $c14 "A"; $c14B = Join-Path $c14 "B"
New-Item -ItemType Directory -Force $c14A | Out-Null
New-Item -ItemType Directory -Force $c14B | Out-Null
$c14MarkersA = Join-Path $c14A "markers"; $c14StateA = Join-Path $c14A "state"
$c14MarkersB = Join-Path $c14B "markers"; $c14StateB = Join-Path $c14B "state"
$c14Lane = "CONC-1"

$c14JobsA = @(
  @{ id = "jobA"; runner = $MockRunner; lane = $c14Lane; model = 1;
     args = @("-MarkerFile", (Join-Path $c14MarkersA "mA.marker"), "-ExitCode", 0, "-JobId", "jobA", "-SleepMs", 1000) }
)
$c14ManifestA = Join-Path $c14A "manifest.json"
New-ManifestFile -Path $c14ManifestA -Jobs $c14JobsA

$c14JobsB = @(
  @{ id = "jobB"; runner = $MockRunner; lane = $c14Lane; model = 1;
     args = @("-MarkerFile", (Join-Path $c14MarkersB "mB.marker"), "-ExitCode", 0, "-JobId", "jobB", "-SleepMs", 1000) }
)
$c14ManifestB = Join-Path $c14B "manifest.json"
New-ManifestFile -Path $c14ManifestB -Jobs $c14JobsB

$c14OutA = Join-Path $c14 "outA.txt"; $c14ErrA = Join-Path $c14 "errA.txt"
$c14OutB = Join-Path $c14 "outB.txt"; $c14ErrB = Join-Path $c14 "errB.txt"

$argStrA = "-NoProfile -ExecutionPolicy Bypass -File `"$RunBatch`" -Manifest `"$c14ManifestA`" -StateDir `"$c14StateA`""
$argStrB = "-NoProfile -ExecutionPolicy Bypass -File `"$RunBatch`" -Manifest `"$c14ManifestB`" -StateDir `"$c14StateB`""

$procA = Start-Process -FilePath "powershell" -ArgumentList $argStrA -RedirectStandardOutput $c14OutA -RedirectStandardError $c14ErrA -NoNewWindow -PassThru
$procB = Start-Process -FilePath "powershell" -ArgumentList $argStrB -RedirectStandardOutput $c14OutB -RedirectStandardError $c14ErrB -NoNewWindow -PassThru

# Touch .Handle on each process object WHILE IT IS STILL RUNNING — a documented
# .NET/PowerShell quirk where Start-Process -PassThru's Process object otherwise
# fails to retain proper access rights to read .ExitCode after the process exits
# (it silently reads back as $null rather than throwing). Not a kill/signal of
# any kind, just touching a property to force the handle to be opened early.
$procA.Handle | Out-Null
$procB.Handle | Out-Null

$procA.WaitForExit()
$procB.WaitForExit()

$recA14 = Get-StateRecords -StateDirPath $c14StateA
$recB14 = Get-StateRecords -StateDirPath $c14StateB
$jA14 = $recA14 | Where-Object { $_.id -eq "jobA" } | Select-Object -First 1
$jB14 = $recB14 | Where-Object { $_.id -eq "jobB" } | Select-Object -First 1

$aStart14 = [DateTime]$jA14.start; $aEnd14 = [DateTime]$jA14.end
$bStart14 = [DateTime]$jB14.start; $bEnd14 = [DateTime]$jB14.end
$noOverlap14 = ($aEnd14 -le $bStart14) -or ($bEnd14 -le $aStart14)

$pass14 = ($procA.ExitCode -eq 0) -and ($procB.ExitCode -eq 0) -and `
          ($jA14.state -eq "done") -and ($jB14.state -eq "done") -and $noOverlap14
Report "14. GLOBAL LANE LOCK FIX: 2 concurrent PROCESSES, same lane, different StateDir -> serialized (no overlap)" `
  $pass14 `
  ("procA.exit=$($procA.ExitCode) procB.exit=$($procB.ExitCode) jobA=[$($jA14.start)..$($jA14.end)] jobB=[$($jB14.start)..$($jB14.end)] noOverlap=$noOverlap14")

# ============================================================================
# Criterion 15 (fix #A regression): job marked exit_reliable=$false (simulating an
# exit-unreliable runner like mt4_optimize.ps1) exits 0 but prints "NO OPT REPORT"
# (mt4_optimize.ps1's real wording, which does NOT contain the contiguous substring
# "NO REPORT") -> must still be caught as FAILED by the broadened regex. Under the
# OLD narrower pattern ('NO REPORT|NO XML|ABORT|ERROR|FATAL') this stdout would NOT
# match, and with no expect_artifact given the job would be silently marked done.
# ============================================================================
$c15 = Join-Path $TestRoot "case15"
New-Item -ItemType Directory -Force $c15 | Out-Null
$c15Markers = Join-Path $c15 "markers"
$c15State   = Join-Path $c15 "state"

$c15Jobs = @(
  @{ id = "job1"; runner = $MockRunner; lane = "A"; model = 1; exit_reliable = $false;
     args = @("-MarkerFile", (Join-Path $c15Markers "m1.marker"), "-ExitCode", 0, "-JobId", "job1",
              "-StdoutText", "NO OPT REPORT (nothing found)") }
)
$c15Manifest = Join-Path $c15 "manifest.json"
New-ManifestFile -Path $c15Manifest -Jobs $c15Jobs

$r15 = Invoke-RunBatch -ManifestPath $c15Manifest -StateDirPath $c15State
$rec15 = Get-StateRecords -StateDirPath $c15State
$job1Rec15 = $rec15 | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
$pass15 = ($r15.ExitCode -ne 0) -and ($job1Rec15.state -eq "failed") -and ($job1Rec15.exit_code -eq 0) -and `
          ($job1Rec15.fail_reason -match "stdout matched failure pattern")
Report "15. FIX-A REGRESSION: unreliable runner exit=0 + stdout 'NO OPT REPORT' -> FAILED (old regex missed this)" `
  $pass15 `
  ("exit=$($r15.ExitCode) job1.state=$($job1Rec15.state) job1.exit_code=$($job1Rec15.exit_code) job1.fail_reason=$($job1Rec15.fail_reason)")

# ============================================================================
# Criterion 16 (fix #A / no-success-evidence): exit_reliable=$false job exits 0 with
# CLEAN stdout (no negative marker) but also NO positive marker and no expect_artifact
# -> must be FAILED ("no success evidence"), since exit==0 alone is not trustworthy
# for an unreliable runner.
# ============================================================================
$c16 = Join-Path $TestRoot "case16"
New-Item -ItemType Directory -Force $c16 | Out-Null
$c16Markers = Join-Path $c16 "markers"
$c16State   = Join-Path $c16 "state"

$c16Jobs = @(
  @{ id = "job1"; runner = $MockRunner; lane = "A"; model = 1; exit_reliable = $false;
     args = @("-MarkerFile", (Join-Path $c16Markers "m1.marker"), "-ExitCode", 0, "-JobId", "job1") }
)
$c16Manifest = Join-Path $c16 "manifest.json"
New-ManifestFile -Path $c16Manifest -Jobs $c16Jobs

$r16 = Invoke-RunBatch -ManifestPath $c16Manifest -StateDirPath $c16State
$rec16 = Get-StateRecords -StateDirPath $c16State
$job1Rec16 = $rec16 | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
$pass16 = ($r16.ExitCode -ne 0) -and ($job1Rec16.state -eq "failed") -and ($job1Rec16.exit_code -eq 0) -and `
          ($job1Rec16.fail_reason -match "unreliable runner: no success evidence")
Report "16. FIX-A NO-EVIDENCE: unreliable runner exit=0, clean stdout, no marker, no expect_artifact -> FAILED" `
  $pass16 `
  ("exit=$($r16.ExitCode) job1.state=$($job1Rec16.state) job1.fail_reason=$($job1Rec16.fail_reason)")

# ============================================================================
# Criterion 17 (fix #A / positive marker): exit_reliable=$false job exits 0 and prints
# "OK REPORT" -> positive success evidence present -> done, even with no expect_artifact.
# ============================================================================
$c17 = Join-Path $TestRoot "case17"
New-Item -ItemType Directory -Force $c17 | Out-Null
$c17Markers = Join-Path $c17 "markers"
$c17State   = Join-Path $c17 "state"

$c17Jobs = @(
  @{ id = "job1"; runner = $MockRunner; lane = "A"; model = 1; exit_reliable = $false;
     args = @("-MarkerFile", (Join-Path $c17Markers "m1.marker"), "-ExitCode", 0, "-JobId", "job1",
              "-StdoutText", "OK REPORT: report_20260712.htm") }
)
$c17Manifest = Join-Path $c17 "manifest.json"
New-ManifestFile -Path $c17Manifest -Jobs $c17Jobs

$r17 = Invoke-RunBatch -ManifestPath $c17Manifest -StateDirPath $c17State
$rec17 = Get-StateRecords -StateDirPath $c17State
$job1Rec17 = $rec17 | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
$pass17 = ($r17.ExitCode -eq 0) -and ($job1Rec17.state -eq "done")
Report "17. FIX-A POSITIVE MARKER: unreliable runner exit=0 + stdout 'OK REPORT' -> done" `
  $pass17 `
  ("exit=$($r17.ExitCode) job1.state=$($job1Rec17.state)")

# ============================================================================
# Criterion 18 (fix #A / expect_artifact substitutes for marker): exit_reliable=$false
# job exits 0, no positive/negative marker, but expect_artifact points at the marker
# file the mock runner itself just wrote (fresh mtime) -> done.
# ============================================================================
$c18 = Join-Path $TestRoot "case18"
New-Item -ItemType Directory -Force $c18 | Out-Null
$c18Markers = Join-Path $c18 "markers"
$c18State   = Join-Path $c18 "state"
$c18Marker  = Join-Path $c18Markers "m1.marker"

$c18Jobs = @(
  @{ id = "job1"; runner = $MockRunner; lane = "A"; model = 1; exit_reliable = $false;
     args = @("-MarkerFile", $c18Marker, "-ExitCode", 0, "-JobId", "job1");
     expect_artifact = $c18Marker }
)
$c18Manifest = Join-Path $c18 "manifest.json"
New-ManifestFile -Path $c18Manifest -Jobs $c18Jobs

$r18 = Invoke-RunBatch -ManifestPath $c18Manifest -StateDirPath $c18State
$rec18 = Get-StateRecords -StateDirPath $c18State
$job1Rec18 = $rec18 | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
$pass18 = ($r18.ExitCode -eq 0) -and ($job1Rec18.state -eq "done")
Report "18. FIX-A EXPECT_ARTIFACT AS EVIDENCE: unreliable runner, no marker, expect_artifact fresh -> done" `
  $pass18 `
  ("exit=$($r18.ExitCode) job1.state=$($job1Rec18.state)")

# ============================================================================
# Criterion 19 (fix #B / physical-terminal lock, real cross-process test): launch TWO
# run_batch.ps1 PROCESSES concurrently (Start-Process), with DIFFERENT lane LABELS
# ("M5-1" and "primary") but the SAME -Terminal value in their job args (the mock
# accepts and ignores -Terminal, per its documented contract). If the lock were still
# keyed by lane LABEL (the old bug), these two different labels would get two
# independent lock files and NOT mutually exclude -> their ~1s-sleep [start,end]
# intervals would overlap. With the fix (lock keyed by the normalized -Terminal path),
# the two runs must serialize -> no overlap, even though every lane label differs.
# ============================================================================
$c19 = Join-Path $TestRoot "case19"
New-Item -ItemType Directory -Force $c19 | Out-Null
$c19A = Join-Path $c19 "A"; $c19B = Join-Path $c19 "B"
New-Item -ItemType Directory -Force $c19A | Out-Null
New-Item -ItemType Directory -Force $c19B | Out-Null
$c19MarkersA = Join-Path $c19A "markers"; $c19StateA = Join-Path $c19A "state"
$c19MarkersB = Join-Path $c19B "markers"; $c19StateB = Join-Path $c19B "state"
$c19Terminal = 'D:\Meta 5\terminal64.exe'

$c19JobsA = @(
  @{ id = "jobA"; runner = $MockRunner; lane = "M5-1"; model = 1;
     args = @("-MarkerFile", (Join-Path $c19MarkersA "mA.marker"), "-ExitCode", 0, "-JobId", "jobA",
              "-SleepMs", 1000, "-Terminal", $c19Terminal) }
)
$c19ManifestA = Join-Path $c19A "manifest.json"
New-ManifestFile -Path $c19ManifestA -Jobs $c19JobsA

$c19JobsB = @(
  @{ id = "jobB"; runner = $MockRunner; lane = "primary"; model = 1;
     args = @("-MarkerFile", (Join-Path $c19MarkersB "mB.marker"), "-ExitCode", 0, "-JobId", "jobB",
              "-SleepMs", 1000, "-Terminal", $c19Terminal) }
)
$c19ManifestB = Join-Path $c19B "manifest.json"
New-ManifestFile -Path $c19ManifestB -Jobs $c19JobsB

$c19OutA = Join-Path $c19 "outA.txt"; $c19ErrA = Join-Path $c19 "errA.txt"
$c19OutB = Join-Path $c19 "outB.txt"; $c19ErrB = Join-Path $c19 "errB.txt"

$argStrA19 = "-NoProfile -ExecutionPolicy Bypass -File `"$RunBatch`" -Manifest `"$c19ManifestA`" -StateDir `"$c19StateA`""
$argStrB19 = "-NoProfile -ExecutionPolicy Bypass -File `"$RunBatch`" -Manifest `"$c19ManifestB`" -StateDir `"$c19StateB`""

$procA19 = Start-Process -FilePath "powershell" -ArgumentList $argStrA19 -RedirectStandardOutput $c19OutA -RedirectStandardError $c19ErrA -NoNewWindow -PassThru
$procB19 = Start-Process -FilePath "powershell" -ArgumentList $argStrB19 -RedirectStandardOutput $c19OutB -RedirectStandardError $c19ErrB -NoNewWindow -PassThru

# See criterion 14's comment re: .Handle -- forces the handle open early so
# .ExitCode reads back correctly after the process exits. Not a kill/signal.
$procA19.Handle | Out-Null
$procB19.Handle | Out-Null

$procA19.WaitForExit()
$procB19.WaitForExit()

$recA19 = Get-StateRecords -StateDirPath $c19StateA
$recB19 = Get-StateRecords -StateDirPath $c19StateB
$jA19 = $recA19 | Where-Object { $_.id -eq "jobA" } | Select-Object -First 1
$jB19 = $recB19 | Where-Object { $_.id -eq "jobB" } | Select-Object -First 1

$aStart19 = [DateTime]$jA19.start; $aEnd19 = [DateTime]$jA19.end
$bStart19 = [DateTime]$jB19.start; $bEnd19 = [DateTime]$jB19.end
$noOverlap19 = ($aEnd19 -le $bStart19) -or ($bEnd19 -le $aStart19)

$pass19 = ($procA19.ExitCode -eq 0) -and ($procB19.ExitCode -eq 0) -and `
          ($jA19.state -eq "done") -and ($jB19.state -eq "done") -and $noOverlap19
Report "19. FIX-B PHYSICAL-TERMINAL LOCK: different lane labels, SAME -Terminal -> serialized (no overlap)" `
  $pass19 `
  ("procA.exit=$($procA19.ExitCode) procB.exit=$($procB19.ExitCode) jobA=[$($jA19.start)..$($jA19.end)] jobB=[$($jB19.start)..$($jB19.end)] noOverlap=$noOverlap19")

# ============================================================================
# Criterion 20 (fix #A / mt5_optimize.ps1's REAL positive-marker wording): mt5_optimize.ps1's
# actual success text is "OK OPTIMIZER XML: ..." which is NOT the contiguous substring "OK XML" —
# a naive 'OK XML' pattern would miss it and misclassify a genuinely successful optimization as
# FAILED once the unreliable-runner evidence gate applies. Confirms the positive-marker regex
# recognizes this real wording (not just the generic 'OK REPORT' used in criterion 17).
# ============================================================================
$c20 = Join-Path $TestRoot "case20"
New-Item -ItemType Directory -Force $c20 | Out-Null
$c20Markers = Join-Path $c20 "markers"
$c20State   = Join-Path $c20 "state"

$c20Jobs = @(
  @{ id = "job1"; runner = $MockRunner; lane = "A"; model = 1; exit_reliable = $false;
     args = @("-MarkerFile", (Join-Path $c20Markers "m1.marker"), "-ExitCode", 0, "-JobId", "job1",
              "-StdoutText", "OK OPTIMIZER XML: opt_20260712.xml") }
)
$c20Manifest = Join-Path $c20 "manifest.json"
New-ManifestFile -Path $c20Manifest -Jobs $c20Jobs

$r20 = Invoke-RunBatch -ManifestPath $c20Manifest -StateDirPath $c20State
$rec20 = Get-StateRecords -StateDirPath $c20State
$job1Rec20 = $rec20 | Where-Object { $_.id -eq "job1" } | Select-Object -First 1
$pass20 = ($r20.ExitCode -eq 0) -and ($job1Rec20.state -eq "done")
Report "20. FIX-A REAL-WORDING: unreliable runner exit=0 + stdout 'OK OPTIMIZER XML' (mt5_optimize's real text) -> done" `
  $pass20 `
  ("exit=$($r20.ExitCode) job1.state=$($job1Rec20.state)")

# ============================================================================
Write-Output ""
$totalPass = @($script:allResults | Where-Object pass).Count
$total = $script:allResults.Count
Write-Output "=== SUMMARY: $totalPass / $total PASS ==="
foreach ($r in $script:allResults) {
  $st = if ($r.pass) { "PASS" } else { "FAIL" }
  Write-Output ("  [{0}] {1}" -f $st, $r.name)
}

if ($totalPass -eq $total) { exit 0 } else { exit 1 }
