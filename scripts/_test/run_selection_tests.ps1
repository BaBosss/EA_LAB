<#
run_selection_tests.ps1 -- the cage for scripts\pilot_probe_select.py (ORDER-1273).

Two halves, and the second is the one that catches drift the fixtures cannot see:

  PART 1  fixture cases (run_selection_tests.py). Sixteen, each an attack on one way the selection
          rule could be wrong, each paired with a control that must come out the other way.
          PROVEN ABLE TO FAIL: six one-line mutations of the module -- plateau becomes top-1, the
          H1 floor drops from 100 to 99, the grid snap is dropped, BOUNDARY never fires, the
          artefact-vs-store count check is removed, the missing-dimension refusal is removed --
          each redden EXACTLY ONE case and name which end broke.

  PART 2  drive the real module over the real repository with --check. A cage that only ever sees
          its own fixtures proves only the half it can reach (memory
          `pure-cage-proves-only-the-pure-half`), and the impure half here is real: the coverage
          store, the registry subprocess, and sixteen 3-4 MB artefacts on disk.

  🔴 PART 2 IS OPPORTUNISTIC AND SAYS SO, and that was a defect found by audit rather than by
  design. `_mt5_auto/optimizations/` is GITIGNORED (.gitignore:74) and each surface is 3-4 MB, so a
  clone legitimately does not carry them -- while this suite sits on the PRE-COMMIT PATH. Measured
  by hiding one artefact: the suite exited 1, which blocks every commit touching
  `factory/coverage.jsonl`, and it did so via a PowerShell `NativeCommandError` -- so none of the
  named failure messages below ever printed. Two bugs in one line: a machine-dependent assertion on
  the commit path, and `$ErrorActionPreference = 'Stop'` plus a child writing to stderr, which is
  trap #5 in this slice's own handoff. Exit 2 from the module now means "the surfaces are not on
  this machine", which is REPORTED and skipped -- never silently, and never as a pass.

🚫 This suite asserts NOTHING about which configuration comes out. The selection is evidence for a
human; asserting a value here would freeze one reading of a surface into a test, and re-running a
probe would then have to be argued with a cage.

ASCII-only (Windows PowerShell 5.1 decodes a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_selection_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$python = Join-Path $RepoRoot 'tools\python312\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    # A missing interpreter is a FAILURE, not a skip: a cage that opts out when its tool is absent
    # is this repo's most repeated defect class.
    Write-Host "[selection] FAIL: interpreter not found at $python" -ForegroundColor Red
    exit 1
}

# REQUIRED, not boilerplate. python takes its stdout encoding from the console codepage, so a child
# of the pre-commit hook gets an ANSI pipe and the first non-ASCII character raises
# UnicodeEncodeError, which the tier surfaces as `exit -1 SUITE THREW` with the cause swallowed
# (memory `thai-output-kills-a-suite-inside-the-hook`).
$prevEnc = $env:PYTHONIOENCODING
$env:PYTHONIOENCODING = 'utf-8'
try {
    $out = & $python (Join-Path $RepoRoot 'scripts\_test\run_selection_tests.py') 2>&1
    $rc = $LASTEXITCODE
    Write-Host ($out | Out-String).TrimEnd()
    if ($rc -ne 0) {
        Write-Host "[selection] FAIL: the fixture cage exited $rc" -ForegroundColor Red
        exit 1
    }
    $text = ($out | Out-String)
    # The roll-up must be present. A run that printed cases and then died before summarising looks
    # like a pass from the exit code alone.
    if ($text -notmatch '\[selection-cage\] \d+ case\(s\), \d+ failed') {
        Write-Host '[selection] FAIL: the fixture cage emitted no roll-up line' -ForegroundColor Red
        exit 1
    }

    # PART 2 -- the real repository, read-only.
    # EAP=Continue around the child: under 'Stop', a native command writing ANYTHING to stderr
    # raises NativeCommandError and this script dies before it can diagnose anything. That is how
    # the machine-dependence above stayed invisible -- the failure never reached a message.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $global:LASTEXITCODE = 0
    $real = & $python (Join-Path $RepoRoot 'scripts\pilot_probe_select.py') '--check' 2>&1
    $realRc = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    $realText = ($real | Out-String)

    # 2 = the probe surfaces are not on this machine. Reported and skipped: a clone does not carry
    # gitignored 3-4 MB artefacts, and blocking its commits over that would be this suite lying
    # about what it found. PART 1 above still ran and is the half that guards the RULE.
    if ($realRc -eq 2) {
        Write-Host '[selection] PART 2 SKIPPED -- the probe surfaces are not on this machine:' -ForegroundColor Yellow
        Write-Host ($realText.TrimEnd() -split "`n" | Select-Object -Last 1) -ForegroundColor Yellow
        Write-Host '[selection] the 16 fixture cases above DID run; only the real-repository'
        Write-Host '            re-derivation was skipped, and it says so rather than passing quietly.'
        exit 0
    }
    if ($realRc -eq 1) {
        Write-Host '[selection] FAIL: the committed selection record does not match what the' -ForegroundColor Red
        Write-Host '       surfaces now generate. The record is GENERATED -- re-run' -ForegroundColor Red
        Write-Host '       scripts/pilot_probe_select.py, or explain the row it cannot derive.' -ForegroundColor Red
        Write-Host '       Do not hand-edit a selection record.' -ForegroundColor Red
        Write-Host $realText.TrimEnd()
        exit 1
    }
    if ($realRc -ne 0) {
        Write-Host "[selection] FAIL: pilot_probe_select returned an undeclared exit code $realRc" -ForegroundColor Red
        Write-Host $realText.TrimEnd()
        exit 1
    }
    if ($realText -notmatch 'holds exactly the \d+ row\(s\)') {
        Write-Host '[selection] FAIL: the real run exited 0 without stating what it checked' -ForegroundColor Red
        Write-Host $realText.TrimEnd()
        exit 1
    }
    # 🚫 no verdict vocabulary leaves this path. design section 10 stops the slice at
    # EVIDENCE_COMPLETE, and the module's own record is checked for the same words by case 16 --
    # this checks the CONSOLE surface, which is a different one and is what a human reads.
    foreach ($w in @('DEAD-STRUCTURAL', 'DEAD-OPTIMIZED', 'VALIDATED CANDIDATE', 'BUILD-ON', 'PARKED-VERIFY')) {
        if ($realText -match [regex]::Escape($w)) {
            Write-Host "[selection] FAIL: the real run printed the verdict word '$w'" -ForegroundColor Red
            exit 1
        }
    }
    Write-Host ($realText.TrimEnd() -split "`n" | Select-Object -Last 1)
    Write-Host '[selection] cage green; the selection itself is evidence for a human, not an assertion here'
}
finally {
    $env:PYTHONIOENCODING = $prevEnc
}
exit 0
