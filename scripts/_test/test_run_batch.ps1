<#
test_run_batch.ps1 — ORDER-100 Phase 3 acceptance driver for scripts\run_batch.ps1.

Runs every acceptance scenario against the MOCK runner only (scripts\_test\mock_runner.ps1)
— never real MT4/MT5 — and prints one PASS/FAIL line per criterion. All scratch
manifests/state/markers live under $env:TEMP\run_batch_test, never in the repo.
#>
$ErrorActionPreference = "Stop"

$RepoRoot   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # scripts\_test -> scripts -> repo root
$RunBatch   = Join-Path $RepoRoot "scripts\run_batch.ps1"
$MockRunner = Join-Path $RepoRoot "scripts\_test\mock_runner.ps1"
$TestRoot   = Join-Path $env:TEMP "run_batch_test"

if (Test-Path $TestRoot) {
  # Clean scratch dir from a previous run — TEMP scratch only, not the repo, not a process.
  Remove-Item -Path $TestRoot -Recurse -Force
}
New-Item -ItemType Directory -Force $TestRoot | Out-Null   # scratch dir scaffold, not process-related

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
  ("exit=$($r2.ExitCode) job2.state=$($job2Rec.state) job3.state=$($job3Rec.state) marker3_absent=$marker3Absent")

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
# Criterion 4: lane collision -> two same-lane jobs' [start,end] never overlap in
# the state file (sequential/lane-safe); lane lock file created then removed.
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
$c4LockPath = Join-Path $c4State "lane_$safeLaneName.lock"
$lockAbsentAfter = -not (Test-Path $c4LockPath)
$lockAcquiredSeen = ($r4.Output -match [regex]::Escape("LANE-LOCK ACQUIRE lane=$c4Lane"))
$lockReleasedSeen = ($r4.Output -match [regex]::Escape("LANE-LOCK RELEASE lane=$c4Lane"))
$acquireCount = ([regex]::Matches($r4.Output, [regex]::Escape("LANE-LOCK ACQUIRE lane=$c4Lane"))).Count
$releaseCount = ([regex]::Matches($r4.Output, [regex]::Escape("LANE-LOCK RELEASE lane=$c4Lane"))).Count

$pass4 = ($r4.ExitCode -eq 0) -and $noOverlap -and $lockAbsentAfter -and ($acquireCount -eq 2) -and ($releaseCount -eq 2)
Report "4. lane collision -> same-lane jobs never overlap, lock created+removed" `
  $pass4 `
  ("job1=[$($j1.start)..$($j1.end)] job2=[$($j2.start)..$($j2.end)] noOverlap=$noOverlap lockAbsentAfter=$lockAbsentAfter acquireCount=$acquireCount releaseCount=$releaseCount")

# ============================================================================
# Criterion 5: self-scan -> no Stop-Process/taskkill, and no -Force on a process.
# ============================================================================
$scanPaths = @((Join-Path $RepoRoot "scripts\run_batch.ps1"), (Join-Path $RepoRoot "scripts\_test\mock_runner.ps1"))
$killHits = Select-String -Pattern 'Stop-Process|taskkill' -Path $scanPaths -ErrorAction SilentlyContinue
$noKillHits = ($null -eq $killHits) -or (@($killHits).Count -eq 0)

# any line with "-Force" that ALSO looks process-related (Get-Process / $proc / Kill / Stop-Process/taskkill) would be a violation
$forceLines = Select-String -Pattern '-Force' -Path $scanPaths -ErrorAction SilentlyContinue
$processyForceHits = @($forceLines | Where-Object { $_.Line -match '(?i)(Stop-Process|taskkill|Get-Process|\$proc\b|\.Kill\(\))' })
$noProcessyForce = (@($processyForceHits).Count -eq 0)

Report "5. self-scan: no Stop-Process/taskkill, no -Force on a process" `
  ($noKillHits -and $noProcessyForce) `
  ("killHits=$(@($killHits).Count) processyForceHits=$(@($processyForceHits).Count)")

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
