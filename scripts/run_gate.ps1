# =============================== HOLDOUT-BURNED ===============================
# ORDER-238 (2026-07-27). One or more test windows in this file end after
# 2025.12.31 -- that is, inside the 2026H1 holdout. They are deliberately LEFT
# AS-IS: they record what past runs actually did, and rewriting them would
# misrepresent that history.
#
# Therefore: do NOT re-run this script to produce selection evidence, and do NOT
# copy its window into new work. A holdout is spent the first time it is touched.
# The current MAIN window is pinned in the VERDICT GATE section of CLAUDE.md.
#
# THIS FILE: the 2026.06.01-2026.06.02 window is a one-day RUNTIME harness for the
#   EA_CORE unit-test EAs -- it counts PASS/FAIL assertions in the tester journal
#   and produces no edge or selection evidence. It does not spend the holdout in
#   the sense that matters, but it does run inside it, so it is labelled openly
#   rather than quietly special-cased.
# ==============================================================================
<#
run_gate.ps1 — EA_CORE_V1 Phase 4 runtime gate.
Runs each test EA in MT5 Strategy Tester (headless), then parses the Tester
journal for PASS/FAIL counts.  Results are printed and saved to GATE_RESULT.txt.

Usage:
  & .\run_gate.ps1
#>
$ErrorActionPreference = "Stop"

$SCRIPTS     = "D:\EA_LAB\scripts"
$DATA_DIR    = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355"
$EXPERTS_SUB = "EA_CORE_V1_CURRENT_BUILD_TESTS"
$OUT         = "D:\EA_LAB\scripts\GATE_RESULT.txt"

# 5 gate tests: EA name → expected pass count (0 = unknown, check for FAIL=0 only)
$GATE = [ordered]@{
    "Logging_v1_Test"             = 12
    "Diagnostics_v1_Test"         = 53
    "RiskEngine_v1_Test"          = 72
    "EA_TEMPLATE_Test"            = 215
    "StrategySignal_v4_Test"      = 85
    "StrategySignal_v5_Test"      = 26
    "PortfolioGuardian_v1_Test"   = 29
}

function Get-TesterLog {
    Join-Path $DATA_DIR "Tester\logs\$(Get-Date -Format 'yyyyMMdd').log"
}

$results = [System.Collections.Generic.List[psobject]]::new()
$allPassed = $true

foreach ($name in $GATE.Keys) {
    $expert = "$EXPERTS_SUB\$name"
    Write-Host ""
    Write-Host "=== $name ===" -ForegroundColor Cyan

    # Run — all tests use XAUUSD H1 (v5 needs real bars; others work on any symbol)
    & "$SCRIPTS\mt5_run.ps1" -Expert $expert `
        -Symbol XAUUSD -Period H1 `
        -FromDate 2026.06.01 -ToDate 2026.06.02 `
        -Model 2 -ReportName "GATE_$name"

    # Small sleep so tester log is fully flushed before we read it
    Start-Sleep -Seconds 3

    # Search entire tester log for this test's summary line (take last occurrence)
    $testerLog = Get-TesterLog
    $totalLine = $null
    if (Test-Path $testerLog) {
        $totalLine = Get-Content $testerLog -Encoding Unicode |
                     Where-Object { $_ -match [regex]::Escape($name) -and $_ -match "= \d+ PASS / \d+ FAIL" } |
                     Select-Object -Last 1
    }

    $pass = 0; $fail = 0
    if ($totalLine) {
        if ($totalLine -match "= (\d+) PASS / (\d+) FAIL") {
            $pass = [int]$Matches[1]
            $fail = [int]$Matches[2]
        }
    }

    $expected = $GATE[$name]
    $passOk   = ($pass -gt 0)
    $failOk   = ($fail -eq 0)
    $countOk  = ($expected -eq 0) -or ($pass -eq $expected)
    $verdict  = if ($passOk -and $failOk -and $countOk) { "PASS" } else { "FAIL" }
    if ($verdict -eq "FAIL") { $allPassed = $false }

    $row = [pscustomobject]@{
        Name     = $name
        Pass     = $pass
        Fail     = $fail
        Expected = $expected
        Verdict  = $verdict
    }
    $results.Add($row)
    $color = if ($verdict -eq "PASS") { "Green" } else { "Red" }
    Write-Host "  $name : $pass PASS / $fail FAIL  -> $verdict" -ForegroundColor $color
}

Write-Host ""
Write-Host "=== GATE SUMMARY ===" -ForegroundColor Yellow
$results | Format-Table -AutoSize

$gateVerdict = if ($allPassed) { "GATE PASSED" } else { "GATE FAILED" }
$gateColor   = if ($allPassed) { "Green" } else { "Red" }
Write-Host $gateVerdict -ForegroundColor $gateColor

# Save result file
$header = "EA_CORE_V1 Phase 4 Runtime Gate -- " + (Get-Date -Format 'yyyy-MM-dd HH:mm')
$body   = $results | ForEach-Object {
    ("{0,-35} {1,3} PASS / {2} FAIL  -> {3}" -f $_.Name, $_.Pass, $_.Fail, $_.Verdict)
}
[IO.File]::WriteAllLines($OUT, @($header, "") + $body + @("", $gateVerdict))
Write-Host "Result saved to: $OUT"
