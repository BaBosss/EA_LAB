<# Deterministic acceptance tests for control_dashboard.ps1. ASCII-only. #>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$script = Join-Path $RepoRoot 'scripts\control_dashboard.ps1'
if (-not (Test-Path -LiteralPath $script)) { throw "missing dashboard script: $script" }
$root = Join-Path $env:TEMP ('ea_lab_control_tests_' + [guid]::NewGuid().ToString('N'))
$lanes = Join-Path $root 'lanes'; $od = Join-Path $root 'onedrive'; New-Item -ItemType Directory -Path $lanes,$od -Force | Out-Null
try {
  function Put([string]$Name,[string]$Text) { [IO.File]::WriteAllText((Join-Path $lanes $Name),$Text,(New-Object Text.UTF8Encoding($true))) }
  Put 'lane-b.json' '{"lane":"lane-b","status":"RUNNING","updated_at":"2026-08-13T11:55:00Z","progress":20,"task":"beta","owner":"B"}'
  Put 'lane-a.json' '{"lane":"lane-a","status":"DONE","updated_at":"2026-08-13T11:59:00Z","progress":100,"task":"alpha","owner":"A","detail":"complete"}'
  $args = @{ RepoRoot=$RepoRoot; RuntimeRoot=$root; LaneDir=$lanes; OneDrivePath=(Join-Path $od 'EA_LAB_CONTROL.html'); AsOfUtc='2026-08-13T12:00:00Z'; StaleAfterMinutes=30 }
  & $script @args | Out-Host
  $jsonPath = Join-Path $root 'EA_LAB_CONTROL.json'; $htmlPath = Join-Path $root 'EA_LAB_CONTROL.html'
  if (-not (Test-Path $jsonPath) -or -not (Test-Path $htmlPath)) { throw 'T01 output files were not generated' }
  $firstJson = [IO.File]::ReadAllText($jsonPath); $firstHtml = [IO.File]::ReadAllText($htmlPath)
  $snap = $firstJson | ConvertFrom-Json
  if ($snap.overall -ne 'GREEN') { throw "T01 expected GREEN, got $($snap.overall)" }
  if ($snap.lanes[0].lane -ne 'lane-a' -or $snap.lanes[1].lane -ne 'lane-b') { throw 'T01 lane ordering is not deterministic' }
  if ($firstHtml.IndexOf('lane-a') -gt $firstHtml.IndexOf('lane-b')) { throw 'T01 HTML order is not deterministic' }
  if (-not (Test-Path (Join-Path $od 'EA_LAB_CONTROL.html'))) { throw 'T01 OneDrive copy was not made' }

  & $script @args | Out-Host
  $secondJson = [IO.File]::ReadAllText($jsonPath); $secondHtml = [IO.File]::ReadAllText($htmlPath)
  if ($firstJson -cne $secondJson -or $firstHtml -cne $secondHtml) { throw 'T02 repeated generation changed bytes' }
  Write-Host 'T01 stable projection + OneDrive copy: PASS'
  Write-Host 'T02 repeatability: PASS'

  Put 'lane-b.json' '{"lane":"lane-b","status":"RUNNING","updated_at":"2026-08-13T11:00:00Z","progress":20,"task":"beta"}'
  Put 'bad.json' '{"lane":"lane-x","status":"RUNNING"'
  & $script @args | Out-Host
  $snap = ([IO.File]::ReadAllText($jsonPath) | ConvertFrom-Json)
  if ($snap.overall -ne 'RED' -or @($snap.issues).Count -ne 1) { throw 'T03 malformed input was not surfaced as one issue' }
  if ($snap.lanes[1].display_status -ne 'STALE') { throw 'T03 stale lane was not classified deterministically' }
  Write-Host 'T03 malformed + stale lane visibility: PASS'

  Put 'bad.json' '{"lane":"lane-a","status":"ERROR","updated_at":"2026-08-13T11:59:00Z","progress":0,"task":"duplicate"}'
  & $script @args | Out-Host
  $snap = ([IO.File]::ReadAllText($jsonPath) | ConvertFrom-Json)
  if (@($snap.issues).Count -ne 1 -or $snap.issues[0].issue -notmatch 'duplicate lane') { throw 'T04 duplicate lane was not refused' }
  Write-Host 'T04 duplicate lane refusal: PASS'
  Write-Host 'CONTROL DASHBOARD TESTS: ALL PASS'
} finally { if (Test-Path $root) { Remove-Item -LiteralPath $root -Recurse -Force } }
