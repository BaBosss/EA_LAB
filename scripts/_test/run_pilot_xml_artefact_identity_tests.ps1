<#
run_pilot_xml_artefact_identity_tests.ps1 - M1 LANE A / finding A-F7.

WHY THIS EXISTS
  pilot_probe.ps1 used to decide whether a produced optimizer XML was THIS run's evidence purely
  from `(Get-Item $xmlPath).LastWriteTime -ge $started` -- mtime, and nothing else. mt5_optimize.ps1
  quarantines its destination XML before every launch (A-F2), which closes most of the stale-read
  risk on the WRITER side, but the READER's own freshness test still trusted one coarse, spoofable
  signal: a copy tool that preserves timestamps, a filesystem with second-level resolution, or a
  quarantine move landing in the same tick as a fresh write can all make mtime say the wrong thing.

  REPAIR UNDER TEST: scripts\lib\pilot_run.ps1's `Get-PilotXmlArtefactVerdict` requires mtime AND a
  SHA256 byte digest to AGREE before calling an artefact fresh -- mtime advanced to >= the run's
  start time, AND the bytes differ from whatever was at the path before the run started. When the
  two signals DISAGREE (most importantly: mtime looks unchanged but the bytes are in fact
  different), that is not resolved by trusting either signal; it comes back Inconsistent, and
  pilot_probe.ps1 flags it on the console and records xml_present=false rather than guessing.

  SCOPE, DELIBERATELY NOT WIDENED: this is for the optimizer XML artefact only.
  check_stale_binaries.ps1 already documents that a compiled MQL5 .ex5's SHA256 is ADVISORY ONLY,
  because MQL5 compilation is not byte-reproducible (memory `mql5-compile-not-byte-reproducible`,
  measured 5/5 distinct hashes from identical source) -- extending byte-equality there would flag
  every clean rebuild as a mismatch. This suite does not touch that path and pins that the new
  function's own docstring states the scope boundary, so a future edit cannot widen it silently.

METHOD
  Get-PilotXmlArtefactVerdict is dot-sourced directly and called on REAL files with REAL mtimes and
  REAL SHA256 digests under a %TEMP% fixture directory -- no mocking of the filesystem, no MT5, no
  process launch, nothing written under D:\EA_LAB. A second block statically scans pilot_probe.ps1
  to prove the bare `LastWriteTime -ge $started` one-liner this replaces is actually gone, not just
  that the new function exists unused beside it.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\_test\run_pilot_xml_artefact_identity_tests.ps1
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

. (Join-Path $RepoRoot 'scripts\lib\pilot_run.ps1')

$work = Join-Path ([System.IO.Path]::GetTempPath()) ('pilotxmlid_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null

function New-FixtureFile([string]$name, [string]$content, [datetime]$mtime) {
  $p = Join-Path $work $name
  Set-Content -LiteralPath $p -Encoding ASCII -Value $content -NoNewline
  (Get-Item -LiteralPath $p).LastWriteTime = $mtime
  return $p
}
function Sha([string]$path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }

try {
  $t0 = Get-Date '2026-01-01 12:00:00'
  $before = $t0.AddMinutes(-10)   # a pre-existing file's timestamp, well before $Started
  $after  = $t0.AddMinutes(5)     # a genuinely new write, after $Started

  Write-Output '=== A-F7 case 1: no artefact at all -> not fresh, not inconsistent ==='
  $r1 = Get-PilotXmlArtefactVerdict -PreExisted $false -PreMtime $null -PreSha256 '' `
    -PostExists $false -PostMtime $null -PostSha256 '' -Started $t0
  Assert-True 'Fresh is false when nothing exists' (-not $r1.Fresh) ''
  Assert-True 'Inconsistent is false when nothing exists (there is nothing to disagree about)' (-not $r1.Inconsistent) ''

  Write-Output ''
  Write-Output '=== A-F7 case 2: HEALTHY -- brand-new artefact, nothing there before ==='
  $newFile = New-FixtureFile 'new.xml' 'BRAND NEW SURFACE' $after
  $r2 = Get-PilotXmlArtefactVerdict -PreExisted $false -PreMtime $null -PreSha256 '' `
    -PostExists $true -PostMtime (Get-Item -LiteralPath $newFile).LastWriteTime -PostSha256 (Sha $newFile) -Started $t0
  Assert-True 'Fresh is true for a genuinely new artefact (mtime advanced, bytes are new)' $r2.Fresh ''
  Assert-True 'not flagged Inconsistent (both signals agree)' (-not $r2.Inconsistent) ''

  Write-Output ''
  Write-Output '=== A-F7 case 3: HEALTHY -- old artefact, this run produced nothing, both signals agree it is stale ==='
  $staleFile = New-FixtureFile 'stale.xml' 'OLD SURFACE FROM A PREVIOUS RUN' $before
  $staleSha = Sha $staleFile
  $r3 = Get-PilotXmlArtefactVerdict -PreExisted $true -PreMtime $before -PreSha256 $staleSha `
    -PostExists $true -PostMtime $before -PostSha256 $staleSha -Started $t0
  Assert-True 'Fresh is false for an untouched leftover (mtime old, bytes unchanged)' (-not $r3.Fresh) ''
  Assert-True 'not flagged Inconsistent (both signals agree it is stale)' (-not $r3.Inconsistent) ''

  Write-Output ''
  Write-Output '=== A-F7 case 4: HEALTHY -- overwritten in place, mtime advances and bytes differ ==='
  $overFile = New-FixtureFile 'over.xml' 'ORIGINAL CONTENT' $before
  $overPreSha = Sha $overFile
  Set-Content -LiteralPath $overFile -Encoding ASCII -Value 'REPLACED CONTENT FROM THIS RUN' -NoNewline
  (Get-Item -LiteralPath $overFile).LastWriteTime = $after
  $r4 = Get-PilotXmlArtefactVerdict -PreExisted $true -PreMtime $before -PreSha256 $overPreSha `
    -PostExists $true -PostMtime $after -PostSha256 (Sha $overFile) -Started $t0
  Assert-True 'Fresh is true when a stale slot is genuinely overwritten by this run' $r4.Fresh ''
  Assert-True 'not flagged Inconsistent' (-not $r4.Inconsistent) ''

  Write-Output ''
  Write-Output '=== A-F7 THE FIXTURE: mtime says unchanged, bytes actually differ -> must refuse/flag ==='
  # This is the exact case a bare `LastWriteTime -ge $started` check cannot see: a write that
  # changed the file's content but, for whatever reason (a timestamp-preserving copy, a filesystem
  # quirk, a same-tick race), did not advance mtime past $Started. Bytes are the only signal that
  # catches it, and the function must not silently pick a side.
  $ghostFile = New-FixtureFile 'ghost.xml' 'WHAT WAS RECORDED AS PRE-RUN CONTENT' $before
  $ghostPreSha = Sha $ghostFile
  Set-Content -LiteralPath $ghostFile -Encoding ASCII -Value 'DIFFERENT CONTENT, TIMESTAMP NOT ADVANCED' -NoNewline
  (Get-Item -LiteralPath $ghostFile).LastWriteTime = $before   # deliberately NOT advanced past $t0
  $ghostPostSha = Sha $ghostFile
  Assert-True 'fixture setup: the bytes actually differ' ($ghostPreSha -ne $ghostPostSha) ''
  $r5 = Get-PilotXmlArtefactVerdict -PreExisted $true -PreMtime $before -PreSha256 $ghostPreSha `
    -PostExists $true -PostMtime $before -PostSha256 $ghostPostSha -Started $t0
  Assert-True 'Fresh is NOT true (an inconsistent read is never silently accepted as evidence)' (-not $r5.Fresh) ''
  Assert-True 'the mismatch IS flagged as Inconsistent' $r5.Inconsistent ("Reason=" + $r5.Reason)
  Assert-True 'the reason names the mtime-vs-bytes disagreement, not a generic message' `
    ($r5.Reason -match 'mtime' -and $r5.Reason -match 'bytes') $r5.Reason

  Write-Output ''
  Write-Output '=== A-F7 case 6: the OTHER inconsistency -- mtime advances but bytes are identical (a touch) ==='
  $touchFile = New-FixtureFile 'touch.xml' 'UNCHANGED CONTENT' $before
  $touchSha = Sha $touchFile
  (Get-Item -LiteralPath $touchFile).LastWriteTime = $after   # touched, content untouched
  $r6 = Get-PilotXmlArtefactVerdict -PreExisted $true -PreMtime $before -PreSha256 $touchSha `
    -PostExists $true -PostMtime $after -PostSha256 $touchSha -Started $t0
  Assert-True 'Fresh is NOT true for a mtime-only touch with no byte change' (-not $r6.Fresh) ''
  Assert-True 'flagged Inconsistent (a touch is not evidence of a new run)' $r6.Inconsistent ("Reason=" + $r6.Reason)

  Write-Output ''
  Write-Output '=== A-F7 case 7: -ge boundary preserved -- mtime exactly equal to Started still counts as advanced ==='
  $edgeFile = New-FixtureFile 'edge.xml' 'EXACT TICK WRITE' $t0
  $r7 = Get-PilotXmlArtefactVerdict -PreExisted $false -PreMtime $null -PreSha256 '' `
    -PostExists $true -PostMtime $t0 -PostSha256 (Sha $edgeFile) -Started $t0
  Assert-True 'mtime == Started still reads as fresh (the original -ge tolerance is preserved)' $r7.Fresh ''

  Write-Output ''
  Write-Output '=== A-F7 static: the bare mtime-only check pilot_probe.ps1 used to run is actually gone ==='
  $src = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot 'scripts\pilot_probe.ps1')
  Assert-True 'pilot_probe.ps1 dot-sources pilot_run.ps1 (where the new function lives)' `
    ($src -match "lib\\pilot_run\.ps1") ''
  Assert-True 'pilot_probe.ps1 calls Get-PilotXmlArtefactVerdict' `
    ($src -match 'Get-PilotXmlArtefactVerdict') ''
  Assert-True 'the old bare one-liner (LastWriteTime -ge $started assigned straight to $xmlIsFresh) is gone' `
    ($src -notmatch '\$xmlIsFresh\s*=\s*\(\(Get-Item[^\r\n]*LastWriteTime\s*-ge\s*\$started\)\)') ''
  Assert-True 'a byte digest (Get-FileHash) is actually computed for the destination XML' `
    ($src -match 'Get-FileHash -LiteralPath \$xmlPath -Algorithm SHA256') ''
  Assert-True 'the record carries the observed digest for provenance (xml_sha256)' `
    ($src -match 'xml_sha256\s*=\s*\$postXmlSha') ''
  Assert-True 'an inconsistent read is printed to the console, not only recorded' `
    ($src -match 'XML ARTEFACT INCONSISTENT') ''

  Write-Output ''
  Write-Output '=== A-F7 static: scope is pinned to the optimizer XML, not widened to binaries ==='
  $lib = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot 'scripts\lib\pilot_run.ps1')
  Assert-True 'Get-PilotXmlArtefactVerdict exists in pilot_run.ps1' ($lib -match 'function Get-PilotXmlArtefactVerdict') ''
  Assert-True 'its own docstring states the MQL5-binary exclusion, so a future edit cannot widen scope silently' `
    ($lib -match '(?s)MQL5.{0,120}not byte-reproducible') ''
  $binGuard = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot 'scripts\check_stale_binaries.ps1')
  Assert-True 'check_stale_binaries.ps1 (the binaries reader) still treats its own SHA256 as ADVISORY ONLY -- untouched by this change' `
    ($binGuard -match 'ADVISORY ONLY') ''
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
