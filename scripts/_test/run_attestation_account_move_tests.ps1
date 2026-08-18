# run_attestation_account_move_tests.ps1
#
# CR-002 attestation lookup regression: proves that the account|magic keying in
# scripts\control_room_snapshot.ps1 fails VISIBLY when a deployment moves to a
# new account while portfolio\ATTESTATION_MAP.csv stays stale.
#
#   S1 control    : deployment A|magic with a matching map row -> HASHED (A hashes)
#   S2 attack     : deployment B|magic (same magic, new account), map still A-only
#                   -> B must be NO_MAP (or another defined non-HASHED state),
#                      with null ex5/set/confidence/note and NO A-hash inheritance
#   S3 specificity: deployment B|magic with a correct B|magic map row -> HASHED (B hashes)
#
# Deterministic, isolated temp fixtures, each initialized as its OWN standalone
# git repo: the ps1's `git -C $Root` calls must succeed with no stderr, because
# PS 5.1 throws native-command stderr as a terminating error under EAP=Stop
# (even with 2>$null). A toplevel check guarantees the fixture does not walk
# up into D:\EA_LAB. No runtime/VPS operations. Invokes the REAL
# scripts\control_room_snapshot.ps1 end to end (2-arg builder path; the builder
# derives reconciliation from the fixture root).
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\_test\run_attestation_account_move_tests.ps1

[CmdletBinding()]
param(
  [string]$RepoRoot = ''
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) {
  $RepoRoot = (Split-Path (Split-Path (Split-Path $PSCommandPath -Parent) -Parent) -Parent)
}

$script:pass = 0
$script:fail = 0

function Assert-True([string]$name, $cond) {
  if ($cond) {
    $script:pass++
    Write-Host "[PASS] $name"
  } else {
    $script:fail++
    Write-Host "[FAIL] $name"
  }
}

function Assert-Equal([string]$name, $expected, $actual) {
  if ($expected -eq $actual) {
    $script:pass++
    Write-Host "[PASS] $name"
  } else {
    $script:fail++
    Write-Host ("[FAIL] {0}  expected=<{1}> actual=<{2}>" -f $name, $expected, $actual)
  }
}

function New-Junction([string]$Link, [string]$Target) {
  if (Test-Path $Link) { return }
  $out = & cmd /c "mklink /J `"$Link`" `"$Target`"" 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "mklink /J failed for $Link -> $Target : $out"
  }
}

function New-Fixture([string]$RepoRoot, [string]$DeploysCsv, [string]$MapCsv) {
  $fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("attmove_" + [guid]::NewGuid().ToString('N').Substring(0, 8))
  foreach ($d in @('portfolio', 'factory', '_vps_deploy', '_triage', 'scripts', 'tools')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $fixture $d) | Out-Null
  }
  New-Junction (Join-Path $fixture 'tools\python312') (Join-Path $RepoRoot 'tools\python312')
  New-Junction (Join-Path $fixture 'scripts\lib') (Join-Path $RepoRoot 'scripts\lib')
  New-Junction (Join-Path $fixture '_triage\factory_os') (Join-Path $RepoRoot '_triage\factory_os')
  # The ps1 under test runs `git -C $Root ...` and, under its EAP=Stop, any git
  # stderr (e.g. "fatal: not a git repository") becomes a terminating error.
  # So the fixture must be a standalone git repo whose git calls succeed clean.
  # Every git call is wrapped in `2>&1 | Out-String`: in PS 5.1 native stderr
  # throws under EAP=Stop even with 2>$null; merging it into the success stream
  # keeps it as data.
  $initOut = & git -C $fixture init 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) { throw "git init failed in $fixture : $initOut" }
  $commitOut = & git -C $fixture -c user.name=fixture -c user.email=fixture@test commit --allow-empty -m fixture 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) { throw "git commit --allow-empty failed in $fixture : $commitOut" }
  $topOut = (& git -C $fixture rev-parse --show-toplevel 2>&1 | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) { throw "git rev-parse --show-toplevel failed in $fixture : $topOut" }
  if ((Resolve-Path $topOut).Path -ne (Resolve-Path $fixture).Path) {
    throw "fixture root $fixture is not a standalone git repo (toplevel=$topOut); it must not walk up into a parent repo"
  }
  Set-Content -LiteralPath (Join-Path $fixture 'portfolio\DEPLOYMENTS.csv') -Value $DeploysCsv -Encoding ASCII
  Set-Content -LiteralPath (Join-Path $fixture 'portfolio\LIVE_DASHBOARD.html') -Value '<html><body>fixture stub</body></html>' -Encoding ASCII
  Set-Content -LiteralPath (Join-Path $fixture 'portfolio\ATTESTATION_MAP.csv') -Value $MapCsv -Encoding ASCII
  Set-Content -LiteralPath (Join-Path $fixture 'AGENT_TASKBOARD.md') -Value '# fixture taskboard (no orders)' -Encoding ASCII
  Set-Content -LiteralPath (Join-Path $fixture 'ARCHIVE_TASKBOARD_2026-07A.md') -Value '# fixture archive taskboard (no orders)' -Encoding ASCII
  [System.IO.File]::WriteAllText((Join-Path $fixture 'factory\coverage.jsonl'), '')
  Set-Content -LiteralPath (Join-Path $fixture '_vps_deploy\TEST_EX_A.ex5') -Value 'EX5-A' -Encoding ASCII
  Set-Content -LiteralPath (Join-Path $fixture '_vps_deploy\TEST_SET_A.set') -Value 'SET-A' -Encoding ASCII
  Set-Content -LiteralPath (Join-Path $fixture '_vps_deploy\TEST_EX_B.ex5') -Value 'EX5-B' -Encoding ASCII
  Set-Content -LiteralPath (Join-Path $fixture '_vps_deploy\TEST_SET_B.set') -Value 'SET-B' -Encoding ASCII
  return $fixture
}

function Invoke-Snapshot([string]$RepoRoot, [string]$fixture) {
  $outFile = Join-Path $fixture 'out.json'
  $ps1 = Join-Path $RepoRoot 'scripts\control_room_snapshot.ps1'
  & $ps1 -Root $fixture -OutFile $outFile
  if (-not (Test-Path $outFile)) { throw "out.json was not produced at $outFile" }
  return ([System.IO.File]::ReadAllText($outFile) | ConvertFrom-Json)
}

function Run-Scenario([string]$name, [string]$RepoRoot, [string]$DeploysCsv, [string]$MapCsv) {
  $fixture = $null
  $result = @{ snap = $null; hExA = $null; hSetA = $null; hExB = $null; hSetB = $null }
  try {
    $fixture = New-Fixture $RepoRoot $DeploysCsv $MapCsv
    $result.hExA = (Get-FileHash (Join-Path $fixture '_vps_deploy\TEST_EX_A.ex5') -Algorithm SHA256).Hash.ToLower()
    $result.hSetA = (Get-FileHash (Join-Path $fixture '_vps_deploy\TEST_SET_A.set') -Algorithm SHA256).Hash.ToLower()
    $result.hExB = (Get-FileHash (Join-Path $fixture '_vps_deploy\TEST_EX_B.ex5') -Algorithm SHA256).Hash.ToLower()
    $result.hSetB = (Get-FileHash (Join-Path $fixture '_vps_deploy\TEST_SET_B.set') -Algorithm SHA256).Hash.ToLower()
    $result.snap = Invoke-Snapshot $RepoRoot $fixture
  } catch {
    Assert-True ("$name snapshot build succeeded: " + $_.Exception.Message) $false
  } finally {
    if ($fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue }
  }
  return $result
}

$deployHeader = 'account,account_name,type,platform,host,ea_name,magic,symbol,status,kill_rule,judge_date,start_date,notes'
$mapHeader = 'account,magic,bundle_dir,ex5_file,set_file,confidence,notes'
$rowA = '1000001,AcctA,DEMO,MT5,local,TESTEA,990001,EURUSD,ACTIVE,closedDD 10%,2026-10-09,2026-01-01,fixture control row'
$rowB = '1000002,AcctB,DEMO,MT5,local,TESTEA,990001,EURUSD,ACTIVE,closedDD 10%,2026-10-09,2026-01-01,fixture moved row'
$mapRowA = '1000001,990001,_vps_deploy,TEST_EX_A.ex5,TEST_SET_A.set,high,fixture map A'
$mapRowB = '1000002,990001,_vps_deploy,TEST_EX_B.ex5,TEST_SET_B.set,high,fixture map B'

Write-Host "=== S1 control: deployment A|magic with matching map row ==="
$r1 = Run-Scenario 'S1' $RepoRoot ($deployHeader + "`n" + $rowA) ($mapHeader + "`n" + $mapRowA)
if ($null -ne $r1.snap) {
  Assert-Equal 'S1 entity' 'ControlRoomSnapshotV5' $r1.snap.entity
  $row = @($r1.snap.attestation) | Where-Object { "$($_.account)|$($_.magic)" -eq '1000001|990001' }
  Assert-True 'S1 attestation row exists for 1000001|990001' ($null -ne $row)
  if ($null -ne $row) {
    Assert-Equal 'S1 state' 'HASHED' $row.state
    Assert-Equal 'S1 confidence' 'high' $row.confidence
    Assert-Equal 'S1 ex5 sha256' $r1.hExA $row.ex5.sha256
    Assert-Equal 'S1 set sha256' $r1.hSetA $row.set.sha256
    Assert-Equal 'S1 ex5 missing' $false $row.ex5.missing
    Assert-Equal 'S1 set missing' $false $row.set.missing
  }
  Assert-Equal 'S1 summary.attestation_ok' 1 $r1.snap.summary.attestation_ok
  Assert-Equal 'S1 summary.attestation_gaps' 0 $r1.snap.summary.attestation_gaps
}

Write-Host "=== S2 attack: deployment moved to B|magic, map still A-only (stale) ==="
$r2 = Run-Scenario 'S2' $RepoRoot ($deployHeader + "`n" + $rowB) ($mapHeader + "`n" + $mapRowA)
if ($null -ne $r2.snap) {
  Assert-Equal 'S2 entity' 'ControlRoomSnapshotV5' $r2.snap.entity
  $row = @($r2.snap.attestation) | Where-Object { "$($_.account)|$($_.magic)" -eq '1000002|990001' }
  Assert-True 'S2 attestation row exists for 1000002|990001' ($null -ne $row)
  if ($null -ne $row) {
    Assert-True 'S2 state is a defined non-HASHED state' ($row.state -in @('NO_MAP', 'NO_BUNDLE', 'FILE_MISSING', 'PARTIAL'))
    Assert-Equal 'S2 state is explicitly NO_MAP' 'NO_MAP' $row.state
    Assert-Equal 'S2 confidence is null' $null $row.confidence
    Assert-Equal 'S2 ex5 is null' $null $row.ex5
    Assert-Equal 'S2 set is null' $null $row.set
    Assert-Equal 'S2 note is null' $null $row.note
    $rowJson = ($row | ConvertTo-Json -Depth 8)
    Assert-True 'S2 row does not inherit A ex5 hash' (-not $rowJson.Contains($r2.hExA))
    Assert-True 'S2 row does not inherit A set hash' (-not $rowJson.Contains($r2.hSetA))
  }
  Assert-Equal 'S2 summary.attestation_ok' 0 $r2.snap.summary.attestation_ok
  Assert-Equal 'S2 summary.attestation_gaps' 1 $r2.snap.summary.attestation_gaps
}

Write-Host "=== S3 specificity: correct B|magic map row restores expected state ==="
$r3 = Run-Scenario 'S3' $RepoRoot ($deployHeader + "`n" + $rowB) ($mapHeader + "`n" + $mapRowB)
if ($null -ne $r3.snap) {
  Assert-Equal 'S3 entity' 'ControlRoomSnapshotV5' $r3.snap.entity
  $row = @($r3.snap.attestation) | Where-Object { "$($_.account)|$($_.magic)" -eq '1000002|990001' }
  Assert-True 'S3 attestation row exists for 1000002|990001' ($null -ne $row)
  if ($null -ne $row) {
    Assert-Equal 'S3 state' 'HASHED' $row.state
    Assert-Equal 'S3 confidence' 'high' $row.confidence
    Assert-Equal 'S3 ex5 sha256' $r3.hExB $row.ex5.sha256
    Assert-Equal 'S3 set sha256' $r3.hSetB $row.set.sha256
    Assert-Equal 'S3 ex5 missing' $false $row.ex5.missing
    Assert-Equal 'S3 set missing' $false $row.set.missing
  }
  Assert-Equal 'S3 summary.attestation_ok' 1 $r3.snap.summary.attestation_ok
  Assert-Equal 'S3 summary.attestation_gaps' 0 $r3.snap.summary.attestation_gaps
}

$total = $script:pass + $script:fail
Write-Host ("TOTAL {0}/{1} passed" -f $script:pass, $total)
if ($script:fail -gt 0) { exit 1 }
exit 0
