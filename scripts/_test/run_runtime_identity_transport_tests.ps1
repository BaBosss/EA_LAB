[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if($RepoRoot -eq '') { $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) }
$push = Join-Path $RepoRoot 'ea_projects\(Boss)_NewsGuard\vps_rclone\push_snap.cmd'
$runbook = Join-Path $RepoRoot 'ea_projects\(Boss)_NewsGuard\VPS_TRANSPORT_AND_ATTACH.md'
$text = Get-Content -LiteralPath $push -Raw
$doc = Get-Content -LiteralPath $runbook -Raw
$pass=0; $fail=0
function Check([string]$Name,[bool]$Condition,[string]$Detail='') {
  if($Condition){$script:pass++; Write-Host "[PASS] $Name"}
  else{$script:fail++; Write-Host "[FAIL] $Name :: $Detail" -ForegroundColor Red}
}
$copyLines=@($text -split "`r?`n" | Where-Object {$_ -match '^"%RCLONE%" copy '})
Check 'transport has exactly two scoped rclone copy commands' ($copyLines.Count -eq 2) "count=$($copyLines.Count)"
$snapshot=@($copyLines | Where-Object {$_ -match 'EA_LAB_snapshot_\[1-9\]\*\.csv'})
$identity=@($copyLines | Where-Object {$_ -match 'EA_LAB_identity_\[1-9\]\*_\[1-9\]\*\.json'})
Check 'snapshot transport remains present' ($snapshot.Count -eq 1) "count=$($snapshot.Count)"
Check 'runtime identity transport is present' ($identity.Count -eq 1) "count=$($identity.Count)"
if($snapshot.Count -eq 1){ Check 'snapshot freshness stays 1h' ($snapshot[0] -match '--max-age 1h') $snapshot[0] }
if($identity.Count -eq 1){ Check 'runtime identity freshness aligns to 30h validator' ($identity[0] -match '--max-age 30h') $identity[0] }
Check 'transport uses no mixed include/exclude filters' (-not ($copyLines -match '\s--exclude\s')) 'unexpected --exclude on copy command'
Check 'aggregate return code initialized' ($text -match '(?m)^set RC=0\r?$') 'missing set RC=0'
$guards=[regex]::Matches($text,'(?m)^if errorlevel 1 set RC=1\r?$').Count
Check 'both rclone calls feed aggregate failure state' ($guards -eq 2) "guards=$guards"
Check 'batch exits with aggregate return code' ($text -match '(?m)^exit /b %RC%\r?$') 'missing aggregate exit'
Check 'runbook documents runtime identity sidecar return path' ($doc -match 'EA_LAB_identity_\*\.json') 'identity sidecar transport absent from runbook'
Check 'runbook keeps collector as lab-side consumer' ($doc -match 'collect_live_deals\.ps1') 'collector path absent'
if($fail -gt 0){ Write-Host "FAIL $fail/$($pass+$fail)"; exit 1 }
Write-Host "PASS $pass/$pass"
exit 0
