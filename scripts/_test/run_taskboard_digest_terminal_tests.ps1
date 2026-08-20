<#
    run_taskboard_digest_terminal_tests.ps1 -- D-F10 (Audit D, 2026-08-20). Lane 3.

    Proves scripts/make_taskboard_digest.ps1's STRONGEST-TERMINAL verb classification:
    a compound status `DONE(attr) + REVIEWED(attr)` must classify as `DONE + REVIEWED`,
    not collapse to a bare `DONE` because the primary-verb regex stops at the first '('.

    HARVESTED, NOT HAND-AUTHORED. Both fixture header lines are pulled live from the real
    ARCHIVE_TASKBOARD_2026-07A.md by pattern, not typed here -- a hand-authored literal that
    happens to look like the defect is not evidence the real file contains it
    (cage-baseline-must-not-be-a-photo-of-the-repo is the adjacent trap; this is its mirror:
    a fixture invented from imagination instead of the real document is just as blind).
    If the pattern is not found, this suite REFUSES rather than falling back to a literal
    (unreadable-input-must-refuse-not-skip).

    Measured 2026-08-20 at canonical-plus-Lane-3: 14 real headers in
    ARCHIVE_TASKBOARD_2026-07A.md carry the `VERB(...) + REVIEWED(...)` shape; ORDER-098-C's
    second header (the MM-parts-library one) is the harvested ATTACK case below. ORDER-068
    is the harvested CONTROL: a genuine bare `DONE(...)` with no REVIEWED anywhere on the
    line, to prove the fix does not fabricate a REVIEWED that was never there.

    Also exercises D-F9 (-Check path-selection / staleness) against the SAME fixture root,
    so this suite covers both make_taskboard_digest.ps1 findings without a second fixture.

    NOT WIRED into the fast tier -- see its row in scripts/_test/SUITE_TIER_REGISTRY.txt.
    ASCII-only output on purpose (a suite that ever runs inside the hook must never raise
    UnicodeEncodeError -- thai-output-kills-a-suite-inside-the-hook is a real prior incident).
#>
[CmdletBinding()]
param([string]$RepoRoot)

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) {
    $d = $PSScriptRoot
    if (-not $d -and $MyInvocation.MyCommand.Path) { $d = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $d) { throw 'cannot resolve script directory; pass -RepoRoot' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $d)
}

$script:fail = 0
function Bad([string]$m) { Write-Host "  [FAIL] $m" -ForegroundColor Red; $script:fail++ }
function Good([string]$m) { Write-Host "  [ok]   $m" }
function Sect([string]$m) { Write-Host ''; Write-Host $m }

$digestScript = Join-Path $RepoRoot 'scripts\make_taskboard_digest.ps1'
$archivePath  = Join-Path $RepoRoot 'ARCHIVE_TASKBOARD_2026-07A.md'
if (-not (Test-Path -LiteralPath $digestScript)) { Bad "missing target: $digestScript"; exit 1 }
if (-not (Test-Path -LiteralPath $archivePath))  { Bad "missing source: $archivePath"; exit 1 }

$ps = (Get-Process -Id $PID).Path
if (-not $ps) { $ps = 'powershell.exe' }

# ---- HARVEST: pull the two real header lines by pattern, refuse if either is absent -------
$archiveLines = Get-Content -LiteralPath $archivePath -Encoding UTF8

$attackLine = $null
foreach ($l in $archiveLines) {
    if ($l -match '^##\s+ORDER-098-C\b' -and $l -match '`DONE\([^)]*\)\s*\+\s*REVIEWED\(') {
        $attackLine = $l
        break
    }
}
if (-not $attackLine) {
    Bad 'HARVEST could not find the ORDER-098-C compound DONE(...)+REVIEWED(...) header in ARCHIVE_TASKBOARD_2026-07A.md -- refusing rather than falling back to a hand-authored literal'
    exit 1
}
Good 'HARVEST found the real ORDER-098-C compound header (ATTACK fixture)'

$controlLine = $null
foreach ($l in $archiveLines) {
    if ($l -match '^##\s+ORDER-068\b' -and $l -match '`DONE\(' -and $l -notmatch 'REVIEWED') {
        $controlLine = $l
        break
    }
}
if (-not $controlLine) {
    Bad 'HARVEST could not find the ORDER-068 bare-DONE (no REVIEWED) header in ARCHIVE_TASKBOARD_2026-07A.md -- refusing rather than falling back to a hand-authored literal'
    exit 1
}
Good 'HARVEST found the real ORDER-068 bare-DONE header (CONTROL fixture)'

# ---- BUILD the fixture root: two harvested lines, nothing invented -------------------------
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("digestfx_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root -Force | Out-Null
$fxActive  = Join-Path $root 'AGENT_TASKBOARD.md'
$fxArchive = Join-Path $root 'ARCHIVE_TASKBOARD_2026-07A.md'
Set-Content -LiteralPath $fxActive -Value @('# fixture active board (D-F10, harvested)', '') -Encoding UTF8
Set-Content -LiteralPath $fxArchive -Value @(
    '# fixture archive board (D-F10, harvested from the real file, not hand-authored)',
    '',
    $attackLine,
    '',
    $controlLine,
    ''
) -Encoding UTF8

try {
    Sect '[digest-terminal] D-F10 -- strongest-terminal verb classification'

    & $ps -NoProfile -ExecutionPolicy Bypass -File $digestScript -Root $root | Out-Null
    if ($LASTEXITCODE -ne 0) { Bad "digest generation against the fixture root failed (exit $LASTEXITCODE)"; exit 1 }

    $outDigest = Join-Path $root 'TASKBOARD_DIGEST.md'
    if (-not (Test-Path -LiteralPath $outDigest)) { Bad 'TASKBOARD_DIGEST.md was not written into the fixture root'; exit 1 }
    $digestLines = Get-Content -LiteralPath $outDigest -Encoding UTF8

    $row098 = $digestLines | Where-Object { $_ -match '^\|\s*ORDER-098-C\s*\|' } | Select-Object -First 1
    if (-not $row098) {
        Bad 'ATTACK no digest row was produced for the harvested ORDER-098-C header'
    } else {
        $cells = $row098.Split('|')
        # | order | closed | verb | title | outcome | location |  -> cells[0]='' cells[1]=order ... cells[3]=verb
        $verbCell = $cells[3].Trim()
        if ($verbCell -eq 'DONE + REVIEWED') {
            Good "ATTACK harvested DONE(...)+REVIEWED(...) classifies as 'DONE + REVIEWED' (was truncating to 'DONE' before D-F10)"
        } else {
            Bad "ATTACK expected verb 'DONE + REVIEWED', got '$verbCell'"
        }
    }

    $row068 = $digestLines | Where-Object { $_ -match '^\|\s*ORDER-068\s*\|' } | Select-Object -First 1
    if (-not $row068) {
        Bad 'CONTROL no digest row was produced for the harvested ORDER-068 header'
    } else {
        $cells = $row068.Split('|')
        $verbCell = $cells[3].Trim()
        if ($verbCell -eq 'DONE') {
            Good "CONTROL harvested bare DONE(...) with no REVIEWED stays 'DONE' -- the fix does not fabricate REVIEWED"
        } else {
            Bad "CONTROL expected verb 'DONE' unchanged, got '$verbCell' -- the fix is over-firing"
        }
    }

    Sect '[digest-terminal] D-F9 -- -Check is a real staleness gate against this same fixture'

    & $ps -NoProfile -ExecutionPolicy Bypass -File $digestScript -Check -Root $root | Out-Null
    if ($LASTEXITCODE -eq 0) { Good 'CONTROL -Check on a freshly generated fixture digest is OK (exit 0)' }
    else { Bad "CONTROL -Check on a fresh fixture digest was not OK (exit $LASTEXITCODE)" }

    # ATTACK: mutate the on-disk digest (simulating "someone edited it by hand, or the boards
    # moved on without regenerating it") and prove -Check catches the drift, fail-closed.
    Add-Content -LiteralPath $outDigest -Value '| ORDER-999999 | 2026-01-01 | DONE | hand-edited row that was never generated |  | ARCHIVE:1 |' -Encoding UTF8
    & $ps -NoProfile -ExecutionPolicy Bypass -File $digestScript -Check -Root $root | Out-Null
    if ($LASTEXITCODE -eq 1) { Good 'ATTACK a hand-edited digest is caught as STALE by -Check (exit 1)' }
    else { Bad "ATTACK a hand-edited digest was NOT caught by -Check (exit $LASTEXITCODE)" }
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
if ($script:fail -gt 0) {
    Write-Host "[digest-terminal] $($script:fail) FAILURE(S)" -ForegroundColor Red
    exit 1
}
Write-Host '[digest-terminal] all cases green -- D-F10 strongest-terminal fires on the harvested real defect, stays quiet on the harvested control; D-F9 -Check catches drift'
exit 0
