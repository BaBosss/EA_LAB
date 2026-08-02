<#
run_s11_tests.ps1 - ORDER-1131 (slice S11), wrapping the cage for the Control Center shell and
the SafeProjection DTO.

WHAT IT GUARDS. _triage\factory_os\control_center.py (the four page models) and
safe_projection.py (the online/Telegram DTO, its recursive scan and the sender boundary). Both
are PURE, so the python suite drives every scenario in process and costs under a second.

WHAT THIS FILE ADDS ON TOP OF THE PYTHON, AND WHY IT IS THE POINT OF IT. control_center.py
declares the reader vocabulary -- OK / REFUSED / UNAVAILABLE and the Code beneath it -- and
copies it from scripts\lib\snapshot_reader.ps1, which is the reader every PowerShell consumer
actually uses. Two spellings of one vocabulary is the drift this repo keeps paying for, and no
pure-python cage can see it. So PART B drives the REAL PowerShell reader, takes the states it
really emits, and feeds those states to the REAL python shell, asserting it renders UNKNOWN and
never ALL CLEAR. That is a claim about the seam, which is the only claim worth a subprocess.

  WHY NOT MORE END-TO-END CASES. The S10 lesson: make the cage cheaper to DRIVE, not cheaper to
  CARE. B1 costs nothing (the reader answers a missing path before it spawns anything); B2 spawns
  the validator once; B3 spawns python once for both cross-checks. Everything else is fixtures.

  NO WORKTREE MUTATION. Every fixture lives under $env:TEMP. The real snapshot is read and never
  written; PART B asserts its bytes are unchanged at the end.

MEASURED three times, not once, per memory phantom-regression-from-two-single-samples: 1.4s / 1.4s
/ 1.3s at registration, and 1.6s / 1.6s / 1.6s after the three /scrutinize rounds added WIRE3
(which drives the CLI end to end). The same numbers are in run_fast_cages.ps1's registration
comment, where the tier's own budget argument lives.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_s11_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$py       = Join-Path $RepoRoot 'tools\python312\python.exe'
$suite    = Join-Path $RepoRoot '_triage\factory_os\run_s11_tests.py'
$reader   = Join-Path $RepoRoot 'scripts\lib\snapshot_reader.ps1'
$snapshot = Join-Path $RepoRoot 'portfolio\control_room_snapshot.json'

if (-not (Test-Path -LiteralPath $py))     { Write-Host "[s11] FAIL: interpreter not found at $py" -ForegroundColor Red; exit 2 }
# A MISSING SUITE IS A TOOL FAILURE, NOT A PASS. Exit 2, not 0.
if (-not (Test-Path -LiteralPath $suite))  { Write-Host "[s11] FAIL: suite not found at $suite" -ForegroundColor Red; exit 2 }
if (-not (Test-Path -LiteralPath $reader)) { Write-Host "[s11] FAIL: snapshot_reader.ps1 not found at $reader" -ForegroundColor Red; exit 2 }

# ---------------------------------------------------------------------------------------
# PART A -- the python cage
# ---------------------------------------------------------------------------------------
# ORDER-1180 (S12) FIX TO A LATENT S11 DEFECT, found when the S12 slice's own commit went red and
# took this suite down with it. Every message in this repo is Thai, and python takes its stdout
# encoding from the console codepage: interactively that is UTF-8, but a CHILD OF THE PRE-COMMIT
# HOOK gets a pipe under the ANSI codepage, where the first Thai character raises
# UnicodeEncodeError. The traceback goes to stderr, and `2>&1` below under
# $ErrorActionPreference='Stop' turns any stderr line into a TERMINATING error -- so the tier
# printed `run_s11_tests.ps1  0.3s (exit -1)  SUITE THREW` with the cause swallowed, while every
# interactive run of the same suite was green. Reproduced with `chcp 1252`.
$env:PYTHONIOENCODING = 'utf-8'
$out  = & $py $suite 2>&1
$code = $LASTEXITCODE
$out | ForEach-Object { Write-Host $_ }
if ($code -ne 0) { Write-Host "[s11] the S11 cage FAILED (exit $code)" -ForegroundColor Red; exit 1 }

# Assert the COMPLETENESS half actually ran. A green run whose roll-ups quietly stopped being
# computed proves less than yesterday's and says nothing in its exit code.
$joined = ($out -join "`n")
if ($joined -notmatch 'scenario\(s\), 0 failed, 0 roll-up problem\(s\)') {
    Write-Host "[s11] FAIL: the run never printed its roll-up line, so its claims rest on whatever subset happened to run" -ForegroundColor Red
    exit 1
}
foreach ($needle in @('WIRE1', 'WIRE2', 'SB01', 'SB03')) {
    if ($joined -notmatch ("\s" + [regex]::Escape($needle) + "\s")) {
        Write-Host "[s11] FAIL: case $needle did not appear in the run" -ForegroundColor Red
        exit 1
    }
}

# ---------------------------------------------------------------------------------------
# PART B -- the seam: the REAL PowerShell reader, feeding the REAL python shell
# ---------------------------------------------------------------------------------------
$partB = 0
$partBFail = 0
function B($label, $cond, $detail) {
    $script:partB++
    if ($cond) { Write-Host "  [OK ] $label" -ForegroundColor Green }
    else { Write-Host "  [FAIL] $label" -ForegroundColor Red; if ($detail) { Write-Host "        -> $detail" -ForegroundColor Red }; $script:partBFail++ }
}

Write-Host ''
Write-Host 'PART B -- scripts\lib\snapshot_reader.ps1 driven for real, then handed to control_center.py'

. $reader
$before = $null
if (Test-Path -LiteralPath $snapshot) { $before = [System.IO.File]::ReadAllBytes($snapshot) }
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("s11_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    # B1 -- a path that is not there. The reader answers before it spawns anything, so this
    #       case is free, and it is the state a fresh clone is actually in.
    $r1 = Get-VerifiedSnapshot -SnapshotPath (Join-Path $tmp 'nope.json') -RepoRoot $RepoRoot
    B 'B1 a missing snapshot is UNAVAILABLE/MISSING -- about the instrument, not the fleet' `
      ($r1.State -eq 'UNAVAILABLE' -and $r1.Code -eq 'MISSING') "$($r1.State)/$($r1.Code)"
    B 'B1 ...and it hands back NO document, so no number can be read off it' ($null -eq $r1.Document) "$($r1.Document)"

    # B2 -- bytes that are not a document. One spawn, and the distinction it proves (a REFUSED
    #       document versus an UNAVAILABLE instrument) is the one the shell renders differently.
    $bad = Join-Path $tmp 'bad.json'
    [IO.File]::WriteAllText($bad, '{ this is not json', (New-Object System.Text.UTF8Encoding $false))
    $r2 = Get-VerifiedSnapshot -SnapshotPath $bad -RepoRoot $RepoRoot
    B 'B2 unparseable bytes are REFUSED/MALFORMED -- a statement about the DOCUMENT' `
      ($r2.State -eq 'REFUSED' -and $r2.Code -eq 'MALFORMED') "$($r2.State)/$($r2.Code)"
    B 'B2 ...and REFUSED is not collapsed into UNAVAILABLE' ($r2.State -ne $r1.State) "$($r1.State) vs $($r2.State)"

    # B3 -- THE SEAM. The states above are the REAL reader's, not typed here. Hand each to the
    #       REAL python shell and require UNKNOWN with numbers suppressed. If control_center.py
    #       ever learns a fourth state, or stops recognising one of these, this goes red -- and
    #       nothing inside either language could have told us.
    $probe = @"
import sys, os
sys.path.insert(0, os.path.join(r'$RepoRoot', '_triage', 'factory_os'))
import control_center as cc
bad = []
for state, codepair in (('$($r1.State)', '$($r1.Code)'), ('$($r2.State)', '$($r2.Code)')):
    read = cc.SnapshotRead(state, codepair, 'driven by run_s11_tests.ps1', None)
    pages = cc.project(read)
    h = pages['today']['health']
    if h['headline'] != 'UNKNOWN' or not h['numbers_suppressed']:
        bad.append('%s/%s -> %s' % (state, codepair, h['headline']))
    if pages['live']['exception_count'] != 0 or not pages['work']['unknown']:
        bad.append('%s/%s leaked numbers onto LIVE/WORK' % (state, codepair))
print('SEAM_BAD=' + ('|'.join(bad) if bad else 'NONE'))
"@
    $probeFile = Join-Path $tmp 'seam.py'
    [IO.File]::WriteAllText($probeFile, $probe, (New-Object System.Text.UTF8Encoding $false))
    $r3 = (& $py $probeFile 2>&1) -join "`n"
    B 'B3 SEAM every state the real reader emits renders UNKNOWN in the real shell, numbers suppressed' `
      ($r3 -match 'SEAM_BAD=NONE') $r3
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    # "I did not modify it" is exactly the claim a cage should not be trusted on.
    if ($null -ne $before) {
        $after = [System.IO.File]::ReadAllBytes($snapshot)
        if ([Convert]::ToBase64String($after) -ne [Convert]::ToBase64String($before)) {
            Write-Host '[s11] FAIL: portfolio\control_room_snapshot.json CHANGED during the run' -ForegroundColor Red
            exit 1
        }
        Write-Host '  [OK ] the real snapshot is byte-identical to before the run'
    }
}

if ($partBFail -gt 0) {
    Write-Host "[s11] PART B: $partBFail of $partB check(s) FAILED -- the two languages do not agree" -ForegroundColor Red
    exit 1
}
Write-Host "[s11] S11 cage green; the reader/shell seam fired on $partB driven check(s)" -ForegroundColor Green
exit 0
