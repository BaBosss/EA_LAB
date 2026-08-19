<#
run_make_ea_map_tests.ps1 - ORDER-8-recovery (EA_LAB_MAP.html port from stale PR #8).

WHY THIS EXISTS
  scripts\make_ea_map.py regenerates EA_LAB_MAP.html (visual canvas map of the whole lab) from
  EA_MASTER_INDEX.csv. It was carried forward from a stale draft PR (#8, authored 2026-08-05)
  onto current canonical master. This suite proves the acceptance bars from that recovery task
  WITHOUT ever touching the real EA_MASTER_INDEX.csv or the real EA_LAB_MAP.html: everything runs
  against a throwaway fixture checkout under a scratch temp dir.

  A. the generator reads EA_MASTER_INDEX.csv and never writes to it (byte-hash unchanged).
  B. the DATA payload (rows/counts) is deterministic across two runs on identical input -- the
     embedded "generated" wall-clock timestamp is expected to vary and is excluded from the
     comparison, same convention STATUS.md/STATUS.html already use for their own timestamps.
  C. the output HTML is self-contained: no http(s):// resource reference, no external <script src=
     or <link href=, viewable offline.
  D. an annotated/suffixed status string ("DEMO -- attached 2026-07-26 (...)") buckets to its
     verdict-word prefix (DEMO), not to UNTESTED -- the exact defect the PR's own bucket_status()
     docstring names as its reason for existing (an exact-match lookup silently miscategorized
     ~30 annotated statuses as UNTESTED).
  E. a genuinely unrecognized status string is NOT silently rewritten to look like a known one --
     its verbatim text survives into the JSON payload (statusRaw) so it stays visible/inspectable
     even though its funnel bucket falls back to UNTESTED.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_make_ea_map_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if ($RepoRoot -eq '') { $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) }

$script:pass = 0
$script:fail = 0
function Assert-True([string]$name, $cond) {
    if ($cond) { $script:pass++; Write-Host "   [PASS] $name" }
    else { $script:fail++; Write-Host "   [FAIL] $name" }
}
function Assert-Equal([string]$name, $expected, $actual) {
    if ("$expected" -eq "$actual") { $script:pass++; Write-Host "   [PASS] $name" }
    else {
        $script:fail++
        Write-Host "   [FAIL] $name"
        Write-Host "          expected: $expected"
        Write-Host "          actual  : $actual"
    }
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("eamap_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null

Write-Host "[1] Building throwaway fixture checkout under $work"
# make_ea_map.py resolves REPO as dirname(dirname(this file)) -- mirror the real scripts\ layout
# (fixture/scripts/make_ea_map.py, fixture/EA_MASTER_INDEX.csv) so that resolution lands on $work.
New-Item -ItemType Directory -Path (Join-Path $work 'scripts') -Force | Out-Null
Copy-Item (Join-Path $RepoRoot 'scripts\make_ea_map.py') (Join-Path $work 'scripts\make_ea_map.py') -Force

# Fixture CSV: real header, four rows covering the D/E bucketing cases plus one ordinary row.
$csv = @'
"name","origin","file_path","lang","home_cell","strategy","risk_mech","status","score","confidence","best_result","note","next_action","detail_ref","updated"
"FixtureAnnotatedDemo","test","ea\fixture_demo.mq5","MQL5","XAUUSDm H1","trend","fixed","DEMO -- attached 2026-07-26 (magic 990016, flat preset)","0","0.5","PF 1.3 MAIN","note","next","ref","2026-08-01"
"FixtureNovelStatus","test","ea\fixture_novel.mq5","MQL5","EURUSDm M15","reversion","fixed","ZORBLAX-PENDING-REVIEW","0","0.5","PF 1.1 MAIN","note","next","ref","2026-08-01"
"FixtureUntested","test","ea\fixture_untested.mq5","MQL5","-","-","-","UNTESTED","0","0","-","-","-","-","2026-08-01"
"FixtureDead","test","ea\fixture_dead.mq5","MQL5","EURGBP H1","reversion","grid","DEAD-STRUCTURAL (static-zone)","0","0","-","-","-","-","2026-08-01"
'@
Set-Content -Path (Join-Path $work 'EA_MASTER_INDEX.csv') -Value $csv -Encoding UTF8 -NoNewline

# repo-local portable python: reuse the real checkout's tools\python312, self-provisioning if the
# fixture's own copy is missing its (gitignored) stdlib archive -- same mechanism the real
# make_status.ps1 -> make_ea_map.py integration now uses.
. (Join-Path $RepoRoot 'scripts\use_python.ps1')
New-Item -ItemType Directory -Path (Join-Path $work 'tools') -Force | Out-Null
$pyLink = Join-Path $work 'tools\python312'
if (-not (Test-Path $pyLink)) {
    Copy-Item (Join-Path $RepoRoot 'tools\python312') $pyLink -Recurse -Force
}
$pyExe = Assert-PortablePython -Root $work -Provision

$csvPath = Join-Path $work 'EA_MASTER_INDEX.csv'
$outPath = Join-Path $work 'EA_LAB_MAP.html'

Write-Host "[2] Test A -- generator does not mutate EA_MASTER_INDEX.csv"
$csvHashBefore = (Get-FileHash $csvPath -Algorithm SHA256).Hash
$r1 = & $pyExe (Join-Path $work 'scripts\make_ea_map.py') 2>&1
$exit1 = $LASTEXITCODE
Assert-Equal "run 1 exits 0" 0 $exit1
$csvHashAfter = (Get-FileHash $csvPath -Algorithm SHA256).Hash
Assert-Equal "EA_MASTER_INDEX.csv byte-hash unchanged after generation" $csvHashBefore $csvHashAfter

Write-Host "[3] Test B -- deterministic data payload across two runs"
$html1 = Get-Content $outPath -Raw
Start-Sleep -Milliseconds 200
& $pyExe (Join-Path $work 'scripts\make_ea_map.py') | Out-Null
$html2 = Get-Content $outPath -Raw

function Get-Payload([string]$html) {
    # payload is the single JSON literal that replaces the /*__EA_DATA__*/null marker
    if ($html -match '(?s)const DATA\s*=\s*(\{.*?\});') { return $Matches[1] }
    return $null
}
$payload1 = Get-Payload $html1
$payload2 = Get-Payload $html2
Assert-True "payload extracted from generated HTML" ($null -ne $payload1 -and $null -ne $payload2)
# strip the "generated": "<timestamp>" field (expected to vary) before comparing
$norm1 = $payload1 -replace '"generated":\s*"[^"]*"', '"generated":"X"'
$norm2 = $payload2 -replace '"generated":\s*"[^"]*"', '"generated":"X"'
Assert-Equal "data payload identical across two runs (generated timestamp excluded)" $norm1 $norm2

Write-Host "[4] Test C -- output is self-contained / offline"
Assert-True "no http:// or https:// resource reference" ($html2 -notmatch 'https?://')
Assert-True "no external <script src=" ($html2 -notmatch '<script[^>]+src=')
Assert-True "no external <link href=" ($html2 -notmatch '<link[^>]+href=')

Write-Host "[5] Test D -- annotated status buckets by verdict-word prefix, not UNTESTED"
# "full" carries the verbatim CSV "name" column (short_name() only trims a path-like value; these
# fixture names have no slash, so full == name == the fixture identifier below).
Assert-True "annotated DEMO status maps to DEMO bucket" ($payload2 -match '"status":\s*"DEMO"[^}]*"full":\s*"FixtureAnnotatedDemo"' -or $payload2 -match '"full":\s*"FixtureAnnotatedDemo"[^}]*"status":\s*"DEMO"')
Assert-True "annotated DEAD-STRUCTURAL status maps to DEAD bucket, not UNTESTED" ($payload2 -match '"full":\s*"FixtureDead"[^}]*"status":\s*"DEAD"' -or $payload2 -match '"status":\s*"DEAD"[^}]*"full":\s*"FixtureDead"')

Write-Host "[6] Test E -- unrecognized status is fail-visible (verbatim raw text survives), not silently rewritten"
Assert-True "unrecognized status ZORBLAX-PENDING-REVIEW appears verbatim in payload (statusRaw)" ($payload2 -match 'ZORBLAX-PENDING-REVIEW')
Assert-True "genuine UNTESTED row still buckets UNTESTED (no false positive)" ($payload2 -match '"full":\s*"FixtureUntested"[^}]*"status":\s*"UNTESTED"' -or $payload2 -match '"status":\s*"UNTESTED"[^}]*"full":\s*"FixtureUntested"')

Write-Host ""
Write-Host "==================================================================="
Write-Host ("  RESULT: {0} passed, {1} failed" -f $script:pass, $script:fail)
Write-Host "==================================================================="

Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue

if ($script:fail -gt 0) { exit 1 } else { exit 0 }
