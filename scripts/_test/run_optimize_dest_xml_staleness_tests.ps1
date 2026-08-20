<#
run_optimize_dest_xml_staleness_tests.ps1 - M1 LANE A / finding A-F2.

WHY THIS EXISTS
  scripts\mt5_optimize.ps1 clears the SOURCE side before launching:

      Get-ChildItem $DataDir -Filter "$ReportName*" -File | Remove-Item -Force

  ...and never touches the DESTINATION, `_mt5_auto\optimizations\<ReportName>.xml`, which is the
  path every downstream consumer reads (scripts\pilot_probe.ps1 records it as the run's `xml`;
  scripts\pilot_probe_select.py loads surfaces from that directory). The collection step is
  conditional -- `if (Test-Path $srcXml) { Move-Item ... }` -- so a run that produces nothing
  leaves the PREVIOUS run's XML sitting at the consumer path, byte for byte, under this run's
  report name.

  That is not theoretical: pilot_probe.ps1's own comment records a smoke run where a cell whose
  launcher aborted found the XML from that cell's earlier successful run at the same path and
  recorded xml_present=true. pilot_probe.ps1 was hardened with an mtime freshness test; the
  LAUNCHER was not, so the stale artefact is still there for every other reader, and the NO-XML
  branch tells the operator "check the $ReportName files" while a full, wrong surface sits at the
  destination.

  REPAIR UNDER TEST: the destination for THIS report name is quarantined BEFORE launch (renamed to
  <ReportName>.xml.superseded-<utc>, never deleted -- an artefact that might be someone's evidence
  is not silently destroyed), so the no-XML path leaves the consumer path ABSENT rather than
  stale. The scope is exactly the one bounded destination file plus its own quarantine siblings;
  nothing else in _mt5_auto\optimizations is read, moved or removed.

METHOD
  Self-contained fixture checkout under %TEMP% (real copies of the script under test and its
  dot-source dependencies), and `hostname.exe` as a harmless, instantly-exiting stand-in
  "terminal" -- the same technique run_mt5_optimize_launcher_hardening_tests.ps1 case F uses. It
  produces no optimizer XML by design, which is precisely the branch under test. No MT5, no
  tester wall-clock, no write anywhere under D:\EA_LAB.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\_test\run_optimize_dest_xml_staleness_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if ($RepoRoot -eq '') { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$script:pass = 0
$script:fail = 0
function Assert-True([string]$name, $cond, [string]$detail = '') {
  if ($cond) { $script:pass++; Write-Output "   [PASS] $name" }
  else { $script:fail++; Write-Output "   [FAIL] $name$(if ($detail) { ' -- ' + $detail })" }
}

# A child `powershell ... 2>&1` merges stderr into our pipeline, and under our own
# $ErrorActionPreference='Stop' each merged stderr line becomes a terminating ErrorRecord. Run
# children under a local 'Continue'; $LASTEXITCODE is unaffected.
function Invoke-Child([string[]]$ArgList) {
  $saved = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { $out = & powershell @ArgList 2>&1; return [pscustomobject]@{ Output = $out; ExitCode = $LASTEXITCODE } }
  finally { $ErrorActionPreference = $saved }
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ('optdestxml_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null

function New-Fixture([string]$tag) {
  $root = Join-Path $work $tag
  New-Item -ItemType Directory -Path (Join-Path $root 'scripts\lib') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $root 'docs') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $root '_triage') -Force | Out-Null
  Copy-Item (Join-Path $RepoRoot 'scripts\mt5_optimize.ps1') (Join-Path $root 'scripts\mt5_optimize.ps1') -Force
  Copy-Item (Join-Path $RepoRoot 'scripts\optimize_guard.ps1') (Join-Path $root 'scripts\optimize_guard.ps1') -Force
  foreach ($lib in @('symbol_preflight.ps1','setfile_surface.ps1','build_receipt.ps1',
                     'binary_staleness.ps1','param_registry_csv.ps1','optimize_next_step.ps1')) {
    Copy-Item (Join-Path $RepoRoot "scripts\lib\$lib") (Join-Path $root "scripts\lib\$lib") -Force
  }
  Copy-Item (Join-Path $RepoRoot 'docs\PARAM_REGISTRY.csv') (Join-Path $root 'docs\PARAM_REGISTRY.csv') -Force
  Copy-Item (Join-Path $RepoRoot 'docs\PARAM_LINKAGE.md') (Join-Path $root 'docs\PARAM_LINKAGE.md') -Force
  Copy-Item (Join-Path $RepoRoot '_triage\PARAM_INACTIVE_AUDIT.md') (Join-Path $root '_triage\PARAM_INACTIVE_AUDIT.md') -Force
  return $root
}

try {
  $fx = New-Fixture 'fx'
  $capabilityFile = Join-Path $work 'capability.json'
  Set-Content -LiteralPath $capabilityFile -Encoding UTF8 -Value '{"symbols":["EURUSD"]}'
  $dataDir = Join-Path $work 'datadir'
  New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
  $setFile = Join-Path $work 'undeclared.set'
  Set-Content -LiteralPath $setFile -Encoding ASCII -Value '_1_Test=1'
  $dummyTerminal = Join-Path $work 'dummy_terminal.exe'
  Set-Content -LiteralPath $dummyTerminal -Encoding ASCII -Value 'leaf only, never launched'
  $hostnameExe = Join-Path $env:WINDIR 'System32\hostname.exe'
  $commonArgs = @('-Expert','FixtureExpert','-Symbol','EURUSD','-FromDate','2023.01.01','-ToDate','2023.02.01')

  $optDir = Join-Path $fx '_mt5_auto\optimizations'
  New-Item -ItemType Directory -Path $optDir -Force | Out-Null

  # A stale surface from an EARLIER, successful run of the same report name. Distinctive bytes so
  # "is this the stale file" is answered by content, not by existence.
  $staleXml = '<?xml version="1.0"?><Workbook><STALE_SURFACE_FROM_A_PREVIOUS_RUN/></Workbook>'

  Write-Output '=== A-F2 case 1: NO-XML run must not leave the previous run report at the consumer path ==='
  if (-not (Test-Path -LiteralPath $hostnameExe -PathType Leaf)) {
    Assert-True 'precondition: hostname.exe stand-in terminal exists' $false
  } else {
    $report = 'AF2TEST_' + [guid]::NewGuid().ToString('N').Substring(0,12)
    $dest = Join-Path $optDir ($report + '.xml')
    Set-Content -LiteralPath $dest -Encoding ASCII -Value $staleXml
    $staleHash = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash
    Assert-True 'setup: a stale destination XML exists for this report name before launch' (Test-Path -LiteralPath $dest)

    $r = Invoke-Child (@('-NoProfile','-File', (Join-Path $fx 'scripts\mt5_optimize.ps1')) + $commonArgs + @(
      '-SetFile', $setFile, '-ReportName', $report, '-Terminal', $hostnameExe, '-DataDir', $dataDir,
      '-CapabilityFile', $capabilityFile, '-AllowLegacyIdentity', '-Force', '-TimeoutSec', '30'))
    $txt = ($r.Output -join "`n")

    Assert-True 'the run reached the OPTIMIZE launch line (so the branch under test was exercised)' `
      ($txt -match 'OPTIMIZE:') 'launcher never reached the launch line'
    Assert-True 'the run closed on the NO-XML path (exit 4)' ($r.ExitCode -eq 4) ("exit=" + $r.ExitCode)
    # THE DEFECT. Before the repair this file was still sitting there, byte-identical.
    Assert-True 'consumer path is ABSENT after a run that produced no XML' `
      (-not (Test-Path -LiteralPath $dest)) 'the previous run report is still readable as this run'
    # ...and it was not silently destroyed either: it must be findable as a quarantined sibling.
    $quarantined = @(Get-ChildItem -LiteralPath $optDir -Filter ($report + '.xml.superseded-*') -File -ErrorAction SilentlyContinue)
    Assert-True 'the stale artefact was quarantined, not deleted' (@($quarantined).Count -eq 1) `
      ("quarantine files found: " + @($quarantined).Count)
    if (@($quarantined).Count -eq 1) {
      Assert-True 'the quarantined copy is byte-identical to what was there before launch' `
        ((Get-FileHash -LiteralPath $quarantined[0].FullName -Algorithm SHA256).Hash -eq $staleHash) ''
    }
    Assert-True 'the launcher SAYS it quarantined a pre-existing destination artefact' `
      ($txt -match 'STALE DEST XML') 'no quarantine line in launcher stdout'
    Assert-True 'the NO-XML message states the destination is absent, not merely that no XML came back' `
      ($txt -match 'destination is ABSENT') 'no consumer-path statement in the NO-XML message'

    Write-Output ''
    Write-Output '=== A-F2 case 2: HEALTHY CONTROL -- no pre-existing destination, nothing invented ==='
    $report2 = 'AF2CLEAN_' + [guid]::NewGuid().ToString('N').Substring(0,12)
    $dest2 = Join-Path $optDir ($report2 + '.xml')
    $r2 = Invoke-Child (@('-NoProfile','-File', (Join-Path $fx 'scripts\mt5_optimize.ps1')) + $commonArgs + @(
      '-SetFile', $setFile, '-ReportName', $report2, '-Terminal', $hostnameExe, '-DataDir', $dataDir,
      '-CapabilityFile', $capabilityFile, '-AllowLegacyIdentity', '-Force', '-TimeoutSec', '30'))
    $txt2 = ($r2.Output -join "`n")
    Assert-True 'clean run still closes on the NO-XML path (exit 4)' ($r2.ExitCode -eq 4) ("exit=" + $r2.ExitCode)
    Assert-True 'clean run does NOT claim to have quarantined anything (the guard is not inert-by-always-firing)' `
      ($txt2 -notmatch 'STALE DEST XML') 'quarantine line printed with nothing to quarantine'
    Assert-True 'clean run created no quarantine sibling' `
      (@(Get-ChildItem -LiteralPath $optDir -Filter ($report2 + '.xml.superseded-*') -File -ErrorAction SilentlyContinue).Count -eq 0) ''
    Assert-True 'clean run left no destination XML behind' (-not (Test-Path -LiteralPath $dest2)) ''

    Write-Output ''
    Write-Output '=== A-F2 case 3: SCOPE -- an UNRELATED report name in the same directory is untouched ==='
    $bystander = Join-Path $optDir 'AF2_BYSTANDER_DO_NOT_TOUCH.xml'
    Set-Content -LiteralPath $bystander -Encoding ASCII -Value $staleXml
    $bystanderHash = (Get-FileHash -LiteralPath $bystander -Algorithm SHA256).Hash
    $report3 = 'AF2SCOPE_' + [guid]::NewGuid().ToString('N').Substring(0,12)
    Set-Content -LiteralPath (Join-Path $optDir ($report3 + '.xml')) -Encoding ASCII -Value $staleXml
    $r3 = Invoke-Child (@('-NoProfile','-File', (Join-Path $fx 'scripts\mt5_optimize.ps1')) + $commonArgs + @(
      '-SetFile', $setFile, '-ReportName', $report3, '-Terminal', $hostnameExe, '-DataDir', $dataDir,
      '-CapabilityFile', $capabilityFile, '-AllowLegacyIdentity', '-Force', '-TimeoutSec', '30'))
    Assert-True 'scope run closed on the NO-XML path' ($r3.ExitCode -eq 4) ("exit=" + $r3.ExitCode)
    Assert-True 'the unrelated bystander XML still exists' (Test-Path -LiteralPath $bystander) ''
    Assert-True 'the unrelated bystander XML is byte-unchanged' `
      ((Test-Path -LiteralPath $bystander) -and (Get-FileHash -LiteralPath $bystander -Algorithm SHA256).Hash -eq $bystanderHash) ''
  }

  Write-Output ''
  Write-Output '=== A-F2 case 4: static -- the destination clear must sit BEFORE the launch, not after ==='
  $src = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot 'scripts\mt5_optimize.ps1')
  $iClear  = $src.IndexOf('STALE DEST XML')
  $iLaunch = $src.IndexOf('Start-Process -FilePath $Terminal')
  Assert-True 'source contains the destination-quarantine step' ($iClear -ge 0) ''
  Assert-True 'source launches the terminal' ($iLaunch -ge 0) ''
  Assert-True 'the quarantine step precedes Start-Process' ($iClear -ge 0 -and $iLaunch -gt $iClear) `
    ("clear at $iClear, launch at $iLaunch")
}
finally {
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output ''
if ($script:fail -gt 0) {
  Write-Output ("FAIL  {0}/{1} passed, {2} failed" -f $script:pass, ($script:pass + $script:fail), $script:fail)
  exit 1
}
Write-Output ("PASS  {0}/{0}" -f $script:pass)
exit 0
