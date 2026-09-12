<# Offline deterministic cage for VPS return transport and RuntimeIdentity import. #>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$push = Join-Path $RepoRoot 'ea_projects\(Boss)_NewsGuard\vps_rclone\push_snap.cmd'
$runbook = Join-Path $RepoRoot 'ea_projects\(Boss)_NewsGuard\VPS_TRANSPORT_AND_ATTACH.md'
$publisher = Join-Path $RepoRoot 'scripts\publish_guard_feeds_to_vps.ps1'
$transport = Join-Path $RepoRoot 'scripts\collect_vps_transport.ps1'
$resolver = Join-Path $RepoRoot 'scripts\lib\onedrive_paths.ps1'
$script:pass=0; $script:fail=0
function Check([string]$Name,[bool]$Condition,[string]$Detail='') {
  if($Condition){$script:pass++; Write-Host "[PASS] $Name"}
  else{$script:fail++; Write-Host "[FAIL] $Name :: $Detail" -ForegroundColor Red}
}

# Preserve the VPS worker contract: this lane changes only the lab-side consumer.
$text = Get-Content -LiteralPath $push -Raw
$doc = Get-Content -LiteralPath $runbook -Raw
$copyLines=@($text -split "`r?`n" | Where-Object {$_ -match '^"%RCLONE%" copy '})
Check 'transport has exactly two scoped rclone copy commands' ($copyLines.Count -eq 2) "count=$($copyLines.Count)"
$snapshot=@($copyLines | Where-Object {$_ -match 'EA_LAB_snapshot_\[1-9\]\*\.csv'})
$identity=@($copyLines | Where-Object {$_ -match 'EA_LAB_identity_\[1-9\]\*_\[1-9\]\*\.json'})
Check 'snapshot transport remains present' ($snapshot.Count -eq 1) "count=$($snapshot.Count)"
Check 'runtime identity transport remains present' ($identity.Count -eq 1) "count=$($identity.Count)"
if($snapshot.Count -eq 1){ Check 'snapshot freshness stays 1h' ($snapshot[0] -match '--max-age 1h') $snapshot[0] }
if($identity.Count -eq 1){ Check 'runtime identity freshness aligns to 30h validator' ($identity[0] -match '--max-age 30h') $identity[0] }
Check 'transport uses no mixed include/exclude filters' (-not ($copyLines -match '\s--exclude\s')) 'unexpected --exclude on copy command'
Check 'aggregate return code initialized' ($text -match '(?m)^set RC=0\r?$') 'missing set RC=0'
$guards=[regex]::Matches($text,'(?m)^if errorlevel 1 set RC=1\r?$').Count
Check 'both rclone calls feed aggregate failure state' ($guards -eq 2) "guards=$guards"
Check 'batch exits with aggregate return code' ($text -match '(?m)^exit /b %RC%\r?$') 'missing aggregate exit'
Check 'runbook documents runtime identity sidecar return path' ($doc -match 'EA_LAB_identity_\*\.json') 'identity sidecar transport absent from runbook'
Check 'runbook keeps collector as lab-side consumer' ($doc -match 'collect_live_deals\.ps1') 'collector path absent'
Check 'runbook distinguishes snapshot transport health from identity freshness' ($doc -match 'transport PASS') 'missing distinction'
Check 'publisher no longer carries the stale profile-root default' (-not ((Get-Content -LiteralPath $publisher -Raw) -match 'C:\\Users\\patip\\OneDrive\\EA_LAB_VPS_SYNC')) 'legacy default remains'

. $resolver
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('ea_vps_transport_' + [guid]::NewGuid().ToString('N'))
try {
  $oneDrive = Join-Path $fixture 'OneDrivePersonal'
  $returnDir = Join-Path $oneDrive 'EA_LAB_VPS_SYNC\vps-to-lab\snapshots'
  $archive = Join-Path $fixture 'archive'
  New-Item -ItemType Directory -Force -Path $returnDir,$archive | Out-Null
  Check 'Personal OneDrive explicit override resolves deterministically' ((Resolve-EaLabPersonalOneDriveRoot -Override $oneDrive) -eq $oneDrive) 'override did not resolve'
  function Get-ItemPropertyValue { param([string]$LiteralPath,[string]$Name) if($LiteralPath -eq 'TEST:\Personal' -and $Name -eq 'UserFolder'){ return $oneDrive }; throw 'unexpected registry read' }
  Check 'Personal OneDrive registry-style resolver uses UserFolder' ((Resolve-EaLabPersonalOneDriveRoot -RegistryPath 'TEST:\Personal') -eq $oneDrive) 'registry-style path did not resolve'
  Remove-Item Function:\Get-ItemPropertyValue -ErrorAction SilentlyContinue
  $unresolved=$false; try { Resolve-EaLabPersonalOneDriveRoot -Override (Join-Path $fixture 'missing') | Out-Null } catch { $unresolved=$true }
  Check 'Personal OneDrive resolver fails closed for missing root' $unresolved 'missing root accepted'
  $newsSource = Join-Path $fixture 'news.csv'
  $regimeSource = Join-Path $fixture 'regime.csv'
  $common = Join-Path $fixture 'common'
  Set-Content -LiteralPath $newsSource -Value @('BkkTime,Currency,Title','2026.09.12 10:00,USD,fixture') -Encoding UTF8
  Set-Content -LiteralPath $regimeSource -Value @('datetime,state,ri','2026.09.12 10:00,NEUTRAL,0.1') -Encoding UTF8
  & $publisher -NewsCsv $newsSource -RegimeCsv $regimeSource -CommonDir $common -PersonalOneDriveRoot $oneDrive
  Check 'publisher default staging resolves from Personal OneDrive override' ($LASTEXITCODE -eq 0 -and
    (Test-Path -LiteralPath (Join-Path $oneDrive 'EA_LAB_VPS_SYNC\lab-to-vps\news\EA_LAB_news_week.csv')) -and
    (Test-Path -LiteralPath (Join-Path $oneDrive 'EA_LAB_VPS_SYNC\lab-to-vps\news\EA_LAB_mris_regime.csv'))) "exit=$LASTEXITCODE"

  $snapshotPath = Join-Path $returnDir 'EA_LAB_snapshot_463666728.csv'
  Set-Content -LiteralPath $snapshotPath -Value 'login,equity' -Encoding ASCII
  $identityPath = Join-Path $returnDir 'EA_LAB_identity_463666728_990026.json'
  $freshIdentity = [ordered]@{ schema='runtime_identity/1'; account_login='463666728'; magic='990026'; evidence_timestamp=(Get-Date).ToString('s') } | ConvertTo-Json
  Set-Content -LiteralPath $identityPath -Value $freshIdentity -Encoding UTF8
  $localSnapshot = Join-Path $archive 'EA_LAB_snapshot_463666728_local.csv'
  Set-Content -LiteralPath $localSnapshot -Value 'LOCAL MONITOR AUTHORITY' -Encoding ASCII
  & $transport -SnapshotDir $returnDir -DestDir $archive
  Check 'fresh snapshot plus fresh identity returns transport PASS' ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"
  $identityArchive = Join-Path $archive ('EA_LAB_identity_463666728_990026_' + (Get-Date -Format 'yyyyMMdd') + '.json')
  Check 'fresh identity is archived' (Test-Path -LiteralPath $identityArchive) 'archive missing'
  Check 'VPS return ingest never overwrites local snapshot archive' ((Get-Content -LiteralPath $localSnapshot -Raw).Trim() -eq 'LOCAL MONITOR AUTHORITY') 'local snapshot changed'
  Check 'VPS snapshot is not copied into live_deals archive' (-not (Test-Path -LiteralPath (Join-Path $archive 'EA_LAB_snapshot_463666728.csv'))) 'VPS snapshot was archived'

  Remove-Item -LiteralPath $identityArchive -Force
  $staleIdentity = [ordered]@{ schema='runtime_identity/1'; account_login='463666728'; magic='990026'; evidence_timestamp=((Get-Date).AddHours(-31)).ToString('s') } | ConvertTo-Json
  Set-Content -LiteralPath $identityPath -Value $staleIdentity -Encoding UTF8
  & $transport -SnapshotDir $returnDir -DestDir $archive
  Check 'fresh snapshot plus stale identity remains transport PASS' ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"
  Check 'stale identity is not archived' (-not (Test-Path -LiteralPath $identityArchive)) 'stale identity copied'

  (Get-Item -LiteralPath $snapshotPath).LastWriteTime = (Get-Date).AddMinutes(-11)
  & $transport -SnapshotDir $returnDir -DestDir $archive
  Check 'stale VPS snapshot is a visible transport failure' ($LASTEXITCODE -ne 0) "exit=$LASTEXITCODE"
  Set-Content -LiteralPath $snapshotPath -Value 'login,equity' -Encoding ASCII
  (Get-Item -LiteralPath $snapshotPath).LastWriteTime = (Get-Date).AddMinutes(6)
  & $transport -SnapshotDir $returnDir -DestDir $archive
  Check 'snapshot more than five minutes in the future is a visible transport failure' ($LASTEXITCODE -ne 0) "exit=$LASTEXITCODE"
  Clear-Content -LiteralPath $snapshotPath
  (Get-Item -LiteralPath $snapshotPath).LastWriteTime = Get-Date
  & $transport -SnapshotDir $returnDir -DestDir $archive
  Check 'zero-byte fresh VPS snapshot is a visible transport failure' ($LASTEXITCODE -ne 0) "exit=$LASTEXITCODE"
  Remove-Item -LiteralPath $snapshotPath -Force
  & $transport -SnapshotDir $returnDir -DestDir $archive
  Check 'missing VPS snapshot is a visible transport failure' ($LASTEXITCODE -ne 0) "exit=$LASTEXITCODE"
} finally {
  Remove-Item Function:\Get-ItemPropertyValue -ErrorAction SilentlyContinue
  if(Test-Path -LiteralPath $fixture){ Remove-Item -LiteralPath $fixture -Recurse -Force }
}
if($fail -gt 0){ Write-Host "FAIL $fail/$($pass+$fail)"; exit 1 }
Write-Host "PASS $pass/$pass"
exit 0
