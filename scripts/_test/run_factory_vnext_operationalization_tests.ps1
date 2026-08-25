[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
. (Join-Path $RepoRoot 'scripts\use_python.ps1')
$PythonExe = Assert-PortablePython -Root $RepoRoot
$runner = Join-Path $RepoRoot 'scripts\run_factory_vnext_pilot.ps1'
if (-not (Test-Path -LiteralPath $runner)) { throw "missing runner: $runner" }

$tmp = Join-Path $env:TEMP ('factory_vnext_operationalization_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
  $source = Join-Path $tmp '(TRD)_SuperTrendFlip_rev05.mq5'
  $preset = Join-Path $tmp 'STF_BTC_H4_rev05_off.set'
  $report = Join-Path $tmp 'HOLDOUT26H1_rev05_off.htm'
  Copy-Item -LiteralPath (Join-Path $RepoRoot 'ea_projects\(TRD)_SuperTrendFlip\(TRD)_SuperTrendFlip_rev05.mq5') -Destination $source
  Copy-Item -LiteralPath (Join-Path $RepoRoot '_mt5_auto\ab_sets\genstanding_stf\STF_BTC_H4_rev05_off.set') -Destination $preset
  $manifest = Get-Content -Raw (Join-Path $RepoRoot 'factory\vnext\pilots\supertrend_rev05_btcusd_h4_holdout26h1\pilot_manifest.json') | ConvertFrom-Json
  $summary = $manifest.RawReportSummary
  $fromDate = ($summary.from_date -replace '-', '.')
  $toDate = ($summary.to_date -replace '-', '.')
  $window = $manifest.RunManifest
  $reportText = @"
Build $($summary.report_build)
<html><body><table>
<tr><td>Expert:</td><td>$($manifest.HomeContract.ConceptID)_$($manifest.HomeContract.StrategyVersion)</td></tr>
<tr><td>Symbol:</td><td>$($manifest.RunManifest.PhysicalSymbol)</td></tr>
<tr><td>Company:</td><td>$($manifest.RunManifest.BrokerDataEnvironment.Split('|')[0])</td></tr>
<tr><td>Period:</td><td>$($manifest.RunManifest.ExecutionTF) ($fromDate - $toDate)</td></tr>
<tr><td>History Quality:</td><td>$($summary.history_quality)</td></tr>
<tr><td>Bars:</td><td>$([int]$summary.bars)</td></tr>
<tr><td>Ticks:</td><td>$([int64]$summary.ticks)</td></tr>
<tr><td>Total Net Profit:</td><td>$($summary.net_profit)</td></tr>
<tr><td>Profit Factor:</td><td>$($summary.profit_factor)</td></tr>
<tr><td>Equity Drawdown Relative:</td><td>$($summary.equity_drawdown_relative_pct)%</td></tr>
<tr><td>Total Trades:</td><td>$([int]$summary.total_trades)</td></tr>
<tr><td>Total Deals:</td><td>$([int]$summary.total_deals)</td></tr>
</table></body></html>
"@
  [IO.File]::WriteAllText($report, $reportText, (New-Object System.Text.UnicodeEncoding($false, $false)))
  $reportFixtureBytes = [IO.File]::ReadAllBytes($report)
  $out = Join-Path $tmp 'out'
  $sourceCommit = '4511ee136b5d9cfdcc7294c2afb3a4ccb5b3803a'

  function Invoke-Runner([string]$ReportFile, [string]$OutputDir) {
    $stdout = Join-Path $OutputDir 'stdout.txt'
    $stderr = Join-Path $OutputDir 'stderr.txt'
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    $proc = Start-Process -FilePath 'powershell' -ArgumentList @(
      '-ExecutionPolicy', 'Bypass',
      '-File', $runner,
      '-SourcePath', $source,
      '-PresetPath', $preset,
      '-ReportPath', $ReportFile,
      '-SourceCommit', $sourceCommit,
      '-OutputRoot', $OutputDir,
      '-PythonExe', $PythonExe
    ) -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $text = ''
    if (Test-Path -LiteralPath $stdout) { $text += (Get-Content -Raw $stdout) }
    if (Test-Path -LiteralPath $stderr) { if ($text) { $text += "`n" }; $text += (Get-Content -Raw $stderr) }
    return @{ Exit=$proc.ExitCode; Text=$text.Trim(); Raw=@($text) }
  }

  function Get-PublishedPilotDir([string]$OutputDir) {
    $children = @(Get-ChildItem -LiteralPath $OutputDir -Directory -ErrorAction Stop | Where-Object { $_.Name -notlike '*.staging' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'pilot_manifest.json')) })
    if ($children.Count -ne 1) {
      $names = ($children | ForEach-Object { $_.FullName }) -join ' | '
      throw "expected one published pilot directory under $OutputDir, found $($children.Count): $names"
    }
    return $children[0].FullName
  }

  $first = Invoke-Runner $report (Join-Path $out 'first')
  if ($first.Exit -ne 0) { throw "T01 runner failed: $($first.Text)" }
  $pilotDir = Get-PublishedPilotDir (Join-Path $out 'first')
  $pilotId1 = Split-Path -Leaf $pilotDir
  $runId1 = (Get-Content -Raw (Join-Path $pilotDir 'pilot_manifest.json') | ConvertFrom-Json).RunManifest.RunID
  $manifestPath = Join-Path $pilotDir 'pilot_manifest.json'
  $indexPath = Join-Path $pilotDir 'artifact_index.json'
  $htmlPath = Join-Path $pilotDir 'report.html'
  foreach ($path in @($manifestPath,$indexPath,$htmlPath)) { if (-not (Test-Path -LiteralPath $path)) { throw "T01 missing $path" } }
  $manifestJson = Get-Content -Raw $manifestPath | ConvertFrom-Json
  $indexJson = Get-Content -Raw $indexPath | ConvertFrom-Json
  if ($manifestJson.RangeEvidence.status -ne 'SEMANTICS_REQUIRED') { throw 'T01 range semantics not preserved' }
  if ($null -ne $manifestJson.GradeEvidence.top_level.QUALITY_GRADE -or $null -ne $manifestJson.GradeEvidence.top_level.EVIDENCE_CONFIDENCE) { throw 'T01 grade/confidence invented' }
  if ($manifestJson.authority -ne 'NON_AUTHORITATIVE_SIDECAR') { throw 'T01 authority changed' }
  if ((Get-Content -Raw $manifestPath) -match 'D:\\|C:\\|file://') { throw 'T01 absolute path leak in manifest' }
  if ((Get-Content -Raw $indexPath) -match 'D:\\|C:\\|file://') { throw 'T01 absolute path leak in index' }
  if ($indexJson.PilotID -ne $manifestJson.PilotID -or $indexJson.RunID -ne $manifestJson.RunManifest.RunID) { throw 'T01 id mismatch' }

  $second = Invoke-Runner $report (Join-Path $out 'repeat')
  if ($second.Exit -ne 0) { throw "T02 repeat failed: $($second.Text)" }
  $pilotId2 = Split-Path -Leaf (Get-PublishedPilotDir (Join-Path $out 'repeat'))
  $runId2 = (Get-Content -Raw (Join-Path (Join-Path (Join-Path $out 'repeat') $pilotId2) 'pilot_manifest.json') | ConvertFrom-Json).RunManifest.RunID
  if ($pilotId2 -ne $pilotId1 -or $runId2 -ne $runId1) { throw 'T02 identity changed on repeat' }
  $sameRoot = Invoke-Runner $report (Join-Path $out 'first')
  if ($sameRoot.Exit -ne 0) { throw "T02b identical collision rerun failed: $($sameRoot.Text)" }
  $samePublished = Get-PublishedPilotDir (Join-Path $out 'first')
  if ((Split-Path -Leaf $samePublished) -ne $pilotId1) { throw 'T02b identical collision changed PilotID' }
  if (@(Get-ChildItem -LiteralPath (Join-Path $out 'first') -Directory | Where-Object { $_.Name -like '*.staging' }).Count -ne 0) { throw 'T02b successful runner left staging directory behind' }

  $wrongSymbol = Join-Path $tmp 'wrong_symbol.htm'
  [IO.File]::WriteAllText($wrongSymbol, $reportText.Replace('BTCUSD','XAUUSD'), (New-Object System.Text.UnicodeEncoding($false, $false)))
  $badSymbol = Invoke-Runner $wrongSymbol (Join-Path $out 'bad_symbol')
  if ($badSymbol.Exit -eq 0 -or $badSymbol.Text -notmatch 'OUTSIDE_VALIDATED_CONTRACT') { throw "T03 wrong symbol did not fail for contract reason: $($badSymbol.Text)" }

  $wrongTf = Join-Path $tmp 'wrong_tf.htm'
  [IO.File]::WriteAllText($wrongTf, $reportText.Replace('H4','H1'), (New-Object System.Text.UnicodeEncoding($false, $false)))
  $badTf = Invoke-Runner $wrongTf (Join-Path $out 'bad_tf')
  if ($badTf.Exit -eq 0 -or $badTf.Text -notmatch 'OUTSIDE_VALIDATED_CONTRACT') { throw "T04 wrong timeframe did not fail for contract reason: $($badTf.Text)" }

  $zeroBar = Join-Path $tmp 'zero_bar.htm'
  $reportText.Replace("<tr><td>Bars:</td><td>$([int]$summary.bars)</td></tr>","<tr><td>Bars:</td><td>0</td></tr>") | Set-Content -Encoding Unicode $zeroBar
  if ((Invoke-Runner $zeroBar (Join-Path $out 'bad_zero')).Exit -eq 0) { throw 'T05 zero-bar unexpectedly passed' }

  foreach ($kind in @('source','preset','report')) {
    $argsOk = $true
    switch ($kind) {
      'source' {
        Remove-Item -LiteralPath $source -Force
        $argsOk = ((Invoke-Runner $report (Join-Path $out 'missing_source')).Exit -ne 0)
        Copy-Item -LiteralPath (Join-Path $RepoRoot 'ea_projects\(TRD)_SuperTrendFlip\(TRD)_SuperTrendFlip_rev05.mq5') -Destination $source
      }
      'preset' {
        Remove-Item -LiteralPath $preset -Force
        $argsOk = ((Invoke-Runner $report (Join-Path $out 'missing_preset')).Exit -ne 0)
        Copy-Item -LiteralPath (Join-Path $RepoRoot '_mt5_auto\ab_sets\genstanding_stf\STF_BTC_H4_rev05_off.set') -Destination $preset
      }
      'report' {
        Remove-Item -LiteralPath $report -Force
        $argsOk = ((Invoke-Runner $report (Join-Path $out 'missing_report')).Exit -ne 0)
        [IO.File]::WriteAllBytes($report, $reportFixtureBytes)
      }
    }
    if (-not $argsOk) { throw "T06 missing $kind unexpectedly passed" }
  }

  $manifestBackup = [IO.File]::ReadAllBytes($manifestPath)
  (Get-Content -Raw $manifestPath).Replace('SEMANTICS_REQUIRED','BROKEN') | Set-Content -Encoding UTF8 $manifestPath
  if ((Invoke-Runner $report (Join-Path $out 'first')).Exit -eq 0) { throw 'T07 collision mismatch unexpectedly passed' }
  [IO.File]::WriteAllBytes($manifestPath, $manifestBackup)

  $dashboardRoot = Join-Path $tmp 'dashboard'
  New-Item -ItemType Directory -Path $dashboardRoot -Force | Out-Null
  Copy-Item -LiteralPath $pilotDir -Destination (Join-Path $dashboardRoot $pilotId1) -Recurse
  Copy-Item -LiteralPath $pilotDir -Destination (Join-Path $dashboardRoot ($pilotId1 + '.staging')) -Recurse
  $dash = & powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\control_dashboard.ps1') -RepoRoot $RepoRoot -RuntimeRoot (Join-Path $tmp 'runtime') -LaneDir (Join-Path $tmp 'lanes') -FactoryPilotRoot $dashboardRoot -AsOfUtc '2026-08-25T00:00:00Z' -NoOneDriveCopy 2>&1
  if ($LASTEXITCODE -ne 0) { throw "T08 dashboard failed: $($dash -join "`n")" }
  $runtimeJson = Join-Path (Join-Path $tmp 'runtime') 'EA_LAB_CONTROL.json'
  $runtimeHtml = Join-Path (Join-Path $tmp 'runtime') 'EA_LAB_CONTROL.html'
  $snap = Get-Content -Raw $runtimeJson | ConvertFrom-Json
  if ($snap.factory_vnext.status -ne 'GREEN') { throw "T08 factory dashboard status not GREEN: $(($snap.factory_vnext | ConvertTo-Json -Depth 6))" }
  if ($snap.factory_vnext.pilot_count -ne 1 -or @($snap.factory_vnext.rows).Count -ne 1) { throw 'T08 staging directory was not ignored' }
  if ($snap.factory_vnext.rows[0].PilotID -ne $pilotId1) { throw 'T08 deterministic pilot row missing' }
  if ($snap.factory_vnext.rows[0].details.RangeStatus -ne 'SEMANTICS_REQUIRED') { throw 'T08 range status not visible' }
  if ((Get-Content -Raw $runtimeHtml) -notmatch 'Factory vNext') { throw 'T08 html section missing' }

  $brokenRoot = Join-Path $tmp 'broken-dashboard'
  New-Item -ItemType Directory -Path (Join-Path $brokenRoot $pilotId1) -Force | Out-Null
  Copy-Item -LiteralPath $manifestPath -Destination (Join-Path (Join-Path $brokenRoot $pilotId1) 'pilot_manifest.json')
  Copy-Item -LiteralPath $indexPath -Destination (Join-Path (Join-Path $brokenRoot $pilotId1) 'artifact_index.json')
  Copy-Item -LiteralPath $htmlPath -Destination (Join-Path (Join-Path $brokenRoot $pilotId1) 'report.html')
  Add-Content -LiteralPath (Join-Path (Join-Path $brokenRoot $pilotId1) 'report.html') -Value 'CORRUPT' -Encoding UTF8
  $dashBroken = & powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\control_dashboard.ps1') -RepoRoot $RepoRoot -RuntimeRoot (Join-Path $tmp 'runtime2') -LaneDir (Join-Path $tmp 'lanes2') -FactoryPilotRoot $brokenRoot -AsOfUtc '2026-08-25T00:00:00Z' -NoOneDriveCopy 2>&1
  if ($LASTEXITCODE -ne 0) { throw "T09 broken dashboard run failed unexpectedly: $($dashBroken -join "`n")" }
  $snapBroken = Get-Content -Raw (Join-Path (Join-Path $tmp 'runtime2') 'EA_LAB_CONTROL.json') | ConvertFrom-Json
  if ($snapBroken.factory_vnext.status -ne 'RED') { throw 'T09 corrupt artifact directory not surfaced as RED' }

  $badWindowRoot = Join-Path $tmp 'bad-window-dashboard'
  Copy-Item -LiteralPath $pilotDir -Destination (Join-Path $badWindowRoot $pilotId1) -Recurse
  $badWindowManifest = Join-Path (Join-Path $badWindowRoot $pilotId1) 'pilot_manifest.json'
  $badWindowIndex = Join-Path (Join-Path $badWindowRoot $pilotId1) 'artifact_index.json'
  $badWindow = Get-Content -Raw $badWindowManifest | ConvertFrom-Json
  $badWindow.WindowContract.EndDate = 'NOT-A-DATE'
  [IO.File]::WriteAllText($badWindowManifest, ($badWindow | ConvertTo-Json -Depth 20), (New-Object System.Text.UTF8Encoding($false)))
  $badIndex = Get-Content -Raw $badWindowIndex | ConvertFrom-Json
  $manifestEntry = $badIndex.files.'pilot_manifest.json'
  $manifestEntry.bytes = (Get-Item -LiteralPath $badWindowManifest).Length
  $manifestEntry.sha256 = (Get-FileHash -LiteralPath $badWindowManifest -Algorithm SHA256).Hash.ToLowerInvariant()
  [IO.File]::WriteAllText($badWindowIndex, ($badIndex | ConvertTo-Json -Depth 20), (New-Object System.Text.UTF8Encoding($false)))
  $dashBadWindow = & powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\control_dashboard.ps1') -RepoRoot $RepoRoot -RuntimeRoot (Join-Path $tmp 'runtime3') -LaneDir (Join-Path $tmp 'lanes3') -FactoryPilotRoot $badWindowRoot -AsOfUtc '2026-08-25T00:00:00Z' -NoOneDriveCopy 2>&1
  if ($LASTEXITCODE -ne 0) { throw "T10 malformed window aborted dashboard: $($dashBadWindow -join "`n")" }
  $snapBadWindow = Get-Content -Raw (Join-Path (Join-Path $tmp 'runtime3') 'EA_LAB_CONTROL.json') | ConvertFrom-Json
  if ($snapBadWindow.factory_vnext.status -ne 'RED' -or $snapBadWindow.factory_vnext.issues[0].issue -notmatch 'window date') { throw 'T10 malformed window date not surfaced as per-pilot RED' }

  Write-Host 'RUNNER TESTS: ALL PASS'
} finally {
  if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
}
