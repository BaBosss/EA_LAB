<#
run_setfile_tests.ps1 - ORDER-1020 (slice S7), wrapping the ratified old-.set policy cage.

WHAT IT GUARDS. The owner ratified on 2026-08-01 (design section 11 decision 4) that an unknown
or removed key in a .set is a REFUSAL THAT NAMES THE KEY, never a skipped line and never a
default substituted underneath, and that migration is a separate tool writing a NEW file with a
full report. _triage\factory_os\setfile.py implements that; this suite is what makes the policy
survive the next edit to it.

MEASURED before adding, because the ORDER-673 budget means a new cage DISPLACES something:
run_setfile_tests.py --mutate is 0.4s in the hook tier, measured on the commit that added it.
Almost all of that is one parse of the real Inputs.mqh to build the build-14 surface its cases
attack. Measured in-session per ORDER-673 N1, not carried over from this comment.

--mutate is passed HERE rather than left to a human, for the reason run_preset_tests.ps1 gives:
without it the suite proves the criteria are green; with it, each one is proven able to go RED for
its own reason.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_setfile_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$py = Join-Path $RepoRoot 'tools\python312\python.exe'
$suite = Join-Path $RepoRoot '_triage\factory_os\run_setfile_tests.py'

if (-not (Test-Path -LiteralPath $py)) {
    Write-Host "[setfile] FAIL: interpreter not found at $py" -ForegroundColor Red
    exit 2
}
if (-not (Test-Path -LiteralPath $suite)) {
    # A MISSING SUITE IS A TOOL FAILURE, NOT A PASS. Exit 2, not 0.
    Write-Host "[setfile] FAIL: suite not found at $suite" -ForegroundColor Red
    exit 2
}

$out = & $py $suite '--mutate' 2>&1
$code = $LASTEXITCODE
$out | ForEach-Object { Write-Host $_ }

if ($code -ne 0) {
    Write-Host "[setfile] the old-.set policy cage FAILED (exit $code)" -ForegroundColor Red
    exit 1
}
# Assert the mutation half actually ran. `--mutate` could be silently dropped by an edit to the
# suite's argument handling, and the criteria would still print green -- the suite passing while
# proving strictly less than its own name claims.
if (($out -join "`n") -notmatch 'mutation probes') {
    Write-Host "[setfile] FAIL: the run produced no mutation probes -- --mutate did not take effect, so no criterion was shown able to fail" -ForegroundColor Red
    exit 1
}
Write-Host '[setfile] old-.set policy cage green, mutation probes included' -ForegroundColor Green

# =============================================================================================
# PART 2 -- ORDER-1268: the SAME policy at the other end, on the RUN PATH.
#
# WHY IT LIVES IN THIS WRAPPER RATHER THAN A 28TH SUITE. The tier is over its pinned 120.0s
# already (measured 141.8s / 132.2s under load, 95.1s idle, same day) and ORDER-673 means a new
# cage displaces something. This is the same subject as PART 1 -- what a .set is allowed to be --
# so it is one suite guarding both ends rather than two suites guarding one policy each. Measured
# addition: see the [setfile] line at the end of this run.
#
# WHAT IT COVERS THAT NOTHING DID. All THREE launchers -- scripts\mt5_run.ps1,
# scripts\mt5_optimize.ps1 and scripts\run_backtest.ps1 -- were guarded by NO suite in
# $SUITE_GUARDS before this: a commit touching any of them ran no cage at all, which is a fair
# part of the answer to how they came to accept any file at all for as long as they did.
# run_backtest.ps1 was not in ORDER-1268's text; it was found while wiring the other two and is
# the worst of the three -- its Get-SetInputs returns an EMPTY LIST for a missing path and prints
# nothing, so a typo in -SetFilePath produced a run configured entirely from the tester cache.
# The judging is in scripts\lib\setfile_surface.ps1 precisely so it can be driven here without an
# MT5 terminal -- the launchers themselves cannot be run in a cage, and a policy that can only be
# observed by launching a real backtest is a policy nobody re-checks.
#
# EVERY ATTACK HAS ITS CONTROL, on the same fixture with one thing changed, because a function
# that returned Refuse=$true for everything would make the attacks green and is exactly what the
# specificity rows below are for.
# =============================================================================================
. (Join-Path $RepoRoot 'scripts\lib\setfile_surface.ps1')

$p2fails = @()
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("setsurf_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $tmp | Out-Null

function New-Fixture {
    param([string]$Name, [string[]]$Body)
    $f = Join-Path $tmp $Name
    [IO.File]::WriteAllLines($f, $Body)
    return $f
}
function P2 {
    param([string]$Label, [string]$Path, [string]$ExpectState, [bool]$ExpectRefuse)
    $r = Get-SetSurfaceState -Path $Path
    if ($r.State -ne $ExpectState) {
        $script:p2fails += ("{0}: State={1}, expected {2}" -f $Label, $r.State, $ExpectState)
        Write-Host ("  [X ] {0}  State={1} expected {2}" -f $Label, $r.State, $ExpectState) -ForegroundColor Red
        return
    }
    if ($r.Refuse -ne $ExpectRefuse) {
        $script:p2fails += ("{0}: Refuse={1}, expected {2}" -f $Label, $r.Refuse, $ExpectRefuse)
        Write-Host ("  [X ] {0}  Refuse={1} expected {2}" -f $Label, $r.Refuse, $ExpectRefuse) -ForegroundColor Red
        return
    }
    if (-not $r.Message) {
        $script:p2fails += ("{0}: no Message -- a state the caller cannot print is a state nobody sees" -f $Label)
        Write-Host ("  [X ] {0}  carries no Message" -f $Label) -ForegroundColor Red
        return
    }
    Write-Host ("  [ok] {0}  -> {1}" -f $Label, $r.State) -ForegroundColor DarkGray
}

Write-Host ''
Write-Host '[setfile] PART 2 -- ORDER-1268: a .set entering a run declares its surface, or the run says it did not'

# The provenance line is preset.render_set's, spelled here EXACTLY as it emits it. If that format
# moves, these fixtures stop matching and this suite goes red -- which is the coupling we want,
# because a launcher parsing a header the compiler no longer writes would silently report
# UNDECLARED for every compiled preset in the repo.
$hdr = '; build=LAB_ENTRY_14 surface=3 effective_config_hash=' + ('a' * 64) + ' (surface_only)'

# CONTROL: declared 3, carries 3.
P2 'CTL a compiled preset whose assignments match its own header' `
   (New-Fixture 'full.set' @($hdr, 'A=1', 'B=2', 'C=3')) 'FULL' $false

# ATTACK: the same file, truncated. One delta from the control above.
P2 'ATK a compiled preset that declares 3 and carries 2 -- edited since it was generated' `
   (New-Fixture 'short.set' @($hdr, 'A=1', 'B=2')) 'MISMATCH' $true

# ATTACK: and the other direction, because a file with MORE lines than it declares is equally
# not the thing its header says it is.
P2 'ATK the same header with an extra assignment appended' `
   (New-Fixture 'long.set' @($hdr, 'A=1', 'B=2', 'C=3', 'D=4')) 'MISMATCH' $true

# SPECIFICITY: a legacy file with no header is RECORDED, never refused. ORDER-700 declined to
# judge the 2,177, and a guard that refuses them is a guard that gets switched off.
P2 'SPC a legacy partial .set with no provenance line is RECORDED, not refused' `
   (New-Fixture 'legacy.set' @('; hand-written', 'A=1')) 'UNDECLARED' $false

# SPECIFICITY: comments and blanks are not assignments, and a value containing '=' is one line.
P2 'SPC comments and blank lines do not count toward the surface' `
   (New-Fixture 'comments.set' @($hdr, '', 'A=1', '; note', 'B=2', '   ', 'C=3')) 'FULL' $false

# ATTACK: unreadable input REFUSES. `unreadable-input-must-refuse-not-skip` -- folding this into
# UNDECLARED would report "declares nothing" about a file that was never opened.
P2 'ATK a -SetFile that does not exist is REFUSED, not treated as absent' `
   (Join-Path $tmp 'no_such_file.set') 'UNREADABLE' $true

# SPECIFICITY: no -SetFile at all is its OWN state and is not refused -- default-capture and
# throwaway probes pass none deliberately, which is why mt5_run.ps1 only warned there.
P2 'SPC no -SetFile at all is NOSETFILE and still allowed, loudly' '' 'NOSETFILE' $false

# THE WIRING, asserted rather than assumed. A perfect library that no launcher dot-sources is the
# BUILT-not-WIRED shape ORDER-1268 exists to end -- setfile.read_set had a correct implementation
# of this exact policy whose only caller was its own test suite.
foreach ($rel in @('scripts\mt5_run.ps1', 'scripts\mt5_optimize.ps1', 'scripts\run_backtest.ps1')) {
    $txt = Get-Content -LiteralPath (Join-Path $RepoRoot $rel) -Raw
    # A DOT-SOURCE STATEMENT, not the filename anywhere in the file. The first version of this
    # line was `-notmatch 'setfile_surface\.ps1'` and it stayed GREEN when the dot-source was
    # deleted from mt5_optimize.ps1, because the comment two lines above it names the library.
    # Found by running the mutation probe rather than by review. That is
    # `text-scan-cannot-tell-read-from-mention`: a scan over a path string cannot distinguish
    # LOADING a file from MENTIONING it, and the mention is what a comment is made of.
    if ($txt -notmatch '(?m)^\s*\.\s+.*setfile_surface\.ps1') {
        $p2fails += ("$rel does not dot-source lib\setfile_surface.ps1")
        Write-Host ("  [X ] WIRING {0} does not dot-source the library" -f $rel) -ForegroundColor Red
    } elseif ($txt -notmatch 'Get-SetSurfaceState') {
        $p2fails += ("$rel dot-sources the library but never calls Get-SetSurfaceState")
        Write-Host ("  [X ] WIRING {0} sources the library and never calls it" -f $rel) -ForegroundColor Red
    } elseif ($txt -notmatch '\$surface\.Refuse') {
        $p2fails += ("$rel calls Get-SetSurfaceState but never acts on Refuse")
        Write-Host ("  [X ] WIRING {0} calls it and ignores Refuse" -f $rel) -ForegroundColor Red
    } else {
        Write-Host ("  [ok] WIRING {0} sources the library, calls it, and acts on Refuse" -f $rel) -ForegroundColor DarkGray
    }
}

Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue

if ($p2fails.Count -gt 0) {
    Write-Host ("[setfile] PART 2 FAILED: {0} case(s)" -f $p2fails.Count) -ForegroundColor Red
    $p2fails | ForEach-Object { Write-Host ("   - " + $_) -ForegroundColor Red }
    exit 1
}
Write-Host '[setfile] PART 2 green -- refuse-or-record holds, and all three launchers are WIRED to it' -ForegroundColor Green
exit 0
