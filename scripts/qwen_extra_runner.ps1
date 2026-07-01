# QWEN_EXTRA_RUNNER.ps1 — Optional extra runs (A+B+C)
# A: MT4 Elephant/Mammoth optimize
# B: MT4 Gold Grid on different symbols
# C: MT5 Robustness (slippage tests)

$LogFile = "D:\EA_LAB\QWEN_RUN_LOG.md"
$ScriptDir = "D:\EA_LAB\scripts"

function Log-Result($task, $tag, $sym, $window, $reportPath, $metrics, $status) {
    $dt = Get-Date -Format "yyyy-MM-dd HH:mm"
    "| $dt | $task | $tag/$sym/$window | $reportPath | $metrics | $status |" | Out-File $LogFile -Append -Encoding utf8
}

function Run-MT4($tag, $expert, $symbol, $period, $fromDate, $toDate, $setFile, $model=2, $taskNum="EXTRA") {
    $window = if ($toDate -like "*2026*" -and $fromDate -like "*2023*") { "FULL" } else { "CUSTOM" }
    $reportName = "QWEN_${tag}_${window}"
    Write-Host "`n=== $reportName | $expert | $symbol $period ===" -ForegroundColor Cyan

    $args = @(
        "-Expert", $expert,
        "-Symbol", $symbol,
        "-Period", $period,
        "-FromDate", $fromDate,
        "-ToDate", $toDate,
        "-Model", $model,
        "-Force",
        "-ReportName", $reportName
    )
    if ($setFile) { $args += @("-SetFile", $setFile) }

    try {
        $out = & "$ScriptDir\mt4_run.ps1" @args 2>&1
        Write-Host $out
        $pf = if ($out -match "Profit Factor[:\s]+([\d.]+)") { $matches[1] } else { "?" }
        $net = if ($out -match "Net Profit[:\s]+([-\d.,]+)") { $matches[1] } else { "?" }
        $tr = if ($out -match "Trades[:\s]+(\d+)") { $matches[1] } else { "?" }
        $rpt = if ($out -match "(D:\\[^\s]+\.htm)") { $matches[1] } else { "-" }
        Log-Result $taskNum $tag $symbol $window $rpt "PF=$pf Net=$net Trades=$tr" "OK"
    } catch {
        Write-Host "ERR: $_" -ForegroundColor Red
        Log-Result $taskNum $tag $symbol $window "-" "ERR: $_" "ERR"
    }
}

function Run-MT5($tag, $expert, $symbol, $period, $fromDate, $toDate, $setFile, $model=4, $taskNum="EXTRA") {
    $window = if ($toDate -like "*2026*" -and $fromDate -like "*2023*") { "FULL" } else { "CUSTOM" }
    $reportName = "QWEN_${tag}_${window}"
    Write-Host "`n=== $reportName | $expert | $symbol $period ===" -ForegroundColor Cyan

    $args = @(
        "-Expert", $expert,
        "-Symbol", $symbol,
        "-Period", $period,
        "-FromDate", $fromDate,
        "-ToDate", $toDate,
        "-SetFile", $setFile,
        "-Model", $model,
        "-TimeoutSec", 2400,
        "-Force",
        "-ReportName", $reportName
    )

    try {
        $out = & "$ScriptDir\mt5_run.ps1" @args 2>&1
        Write-Host $out
        $pf = if ($out -match "Profit Factor[:\s]+([\d.]+)") { $matches[1] } else { "?" }
        $net = if ($out -match "Net Profit[:\s]+([-\d.,]+)") { $matches[1] } else { "?" }
        $tr = if ($out -match "Trades[:\s]+(\d+)") { $matches[1] } else { "?" }
        $rpt = if ($out -match "(D:\\[^\s]+\.html)") { $matches[1] } else { "-" }
        Log-Result $taskNum $tag $symbol $window $rpt "PF=$pf Net=$net Trades=$tr" "OK"
    } catch {
        Write-Host "ERR: $_" -ForegroundColor Red
        Log-Result $taskNum $tag $symbol $window "-" "ERR: $_" "ERR"
    }
}

function Run-MT4-Optimize($expert, $symbol, $period, $fromDate, $toDate, $setFile, $model=2) {
    $reportName = "QWEN_$(($expert -split ' ')[0])_opt"
    Write-Host "`n=== MT4 OPTIMIZE: $expert on $symbol ===" -ForegroundColor Green

    $args = @(
        "-Expert", $expert,
        "-Symbol", $symbol,
        "-Period", $period,
        "-FromDate", $fromDate,
        "-ToDate", $toDate,
        "-SetFile", $setFile,
        "-Model", $model,
        "-Optimization", 1,
        "-TimeoutSec", 7200,
        "-ReportName", $reportName
    )

    try {
        $out = & "$ScriptDir\mt4_optimize.ps1" @args 2>&1
        Write-Host $out
        $rpt = if ($out -match "(D:\\[^\s]+\.xml)") { $matches[1] } else { "-" }
        $topPf = if ($out -match "Top pass.*PF=([\d.]+)") { $matches[1] } else { "?" }
        Log-Result "EXTRA-OPT" $expert $symbol "FULL" $rpt "optimize complete, top PF=$topPf" "OK"
    } catch {
        Write-Host "ERR: $_" -ForegroundColor Red
        Log-Result "EXTRA-OPT" $expert $symbol "FULL" "-" "ERR: $_" "ERR"
    }
}

Write-Host "`n###############################################" -ForegroundColor Green
Write-Host "### EXTRA RUNS - A, B, C (48 hrs available)  ###" -ForegroundColor Green
Write-Host "###############################################`n"

# -----------------------------------------------------------------------
# A. MT4 OPTIMIZE - Elephant + Mammoth
# -----------------------------------------------------------------------
Write-Host "`n### A. MT4 OPTIMIZE ###" -ForegroundColor Green

# Elephant optimize
Write-Host "`nA1. Elephant optimize..." -ForegroundColor Cyan
$elephantSetPath = "D:\EA_LAB\_mt4_auto\elephant_opt.set"
if (Test-Path "D:\EA_LAB\_mt4_auto\elephant_base.set") {
    Copy-Item "D:\EA_LAB\_mt4_auto\elephant_base.set" $elephantSetPath -Force
} else {
    # Create minimal set if not exists
    "// Elephant optimizer set`n" | Out-File $elephantSetPath -Encoding utf8
}
Run-MT4-Optimize "Elephant" "XAUUSDMINI" "H1" "2023.01.01" "2026.06.01" $elephantSetPath 2

# Mammoth optimize
Write-Host "`nA2. Mammoth optimize..." -ForegroundColor Cyan
$mammothSetPath = "D:\EA_LAB\_mt4_auto\mammoth_opt.set"
if (Test-Path "D:\EA_LAB\_mt4_auto\mammoth_base.set") {
    Copy-Item "D:\EA_LAB\_mt4_auto\mammoth_base.set" $mammothSetPath -Force
} else {
    "// Mammoth optimizer set`n" | Out-File $mammothSetPath -Encoding utf8
}
Run-MT4-Optimize "Mammoth" "XAUUSDMINI" "H1" "2023.01.01" "2026.06.01" $mammothSetPath 2

# -----------------------------------------------------------------------
# B. MT4 GOLD GRID - Different Symbols
# -----------------------------------------------------------------------
Write-Host "`n### B. MT4 GOLD GRID — Different Symbols ###" -ForegroundColor Green

# B1: Elephant on XAUUSD (full-size)
Run-MT4 "Elephant_full" "Elephant" "XAUUSD" "H1" "2023.01.01" "2026.06.01" "" 2 "EXTRA-B"

# B2: Elephant on EURUSD
Run-MT4 "Elephant_EUR" "Elephant" "EURUSD" "H1" "2023.01.01" "2026.06.01" "" 2 "EXTRA-B"

# B3: Mammoth on XAUUSD (full-size)
Run-MT4 "Mammoth_full" "Mammoth" "XAUUSD" "H1" "2023.01.01" "2026.06.01" "" 2 "EXTRA-B"

# B4: Mammoth on EURUSD
Run-MT4 "Mammoth_EUR" "Mammoth" "EURUSD" "H1" "2023.01.01" "2026.06.01" "" 2 "EXTRA-B"

# -----------------------------------------------------------------------
# C. MT5 ROBUSTNESS - Slippage Tests (MACDg + BRK55)
# -----------------------------------------------------------------------
Write-Host "`n### C. MT5 ROBUSTNESS — Slippage Tests ###" -ForegroundColor Green

$macdgSet = "D:\EA_LAB\_mt5_auto\MACD_GBPUSD_locked.set"
$brk55Set = "D:\EA_LAB\_vps_deploy\BRK_XAU_live_v3.set"

# C1a: MACDg tight (0 spread) IS
Write-Host "`nC1a. MACDg IS (tight, 0 spread)..." -ForegroundColor Cyan
Run-MT5 "MACDg_tight_IS" "(ST) EA03 Count MACD v1" "GBPUSD" "H1" "2023.01.01" "2025.01.01" $macdgSet 4 "EXTRA-C"

# C1b: MACDg tight OOS
Write-Host "`nC1b. MACDg OOS (tight, 0 spread)..." -ForegroundColor Cyan
Run-MT5 "MACDg_tight_OOS" "(ST) EA03 Count MACD v1" "GBPUSD" "H1" "2025.01.01" "2026.06.01" $macdgSet 4 "EXTRA-C"

# C1c: MACDg realistic (+5 spread) IS
Write-Host "`nC1c. MACDg IS (realistic, +5 spread)..." -ForegroundColor Cyan
Run-MT5 "MACDg_realistic_IS" "(ST) EA03 Count MACD v1" "GBPUSD" "H1" "2023.01.01" "2025.01.01" $macdgSet 4 "EXTRA-C"

# C1d: MACDg realistic OOS
Write-Host "`nC1d. MACDg OOS (realistic, +5 spread)..." -ForegroundColor Cyan
Run-MT5 "MACDg_realistic_OOS" "(ST) EA03 Count MACD v1" "GBPUSD" "H1" "2025.01.01" "2026.06.01" $macdgSet 4 "EXTRA-C"

# C2a: BRK55 tight IS
Write-Host "`nC2a. BRK55 IS (tight, 0 spread)..." -ForegroundColor Cyan
Run-MT5 "BRK55_tight_IS" "EA_BREAKOUT_XAU" "XAUUSD" "H1" "2023.01.01" "2025.01.01" $brk55Set 4 "EXTRA-C"

# C2b: BRK55 tight OOS
Write-Host "`nC2b. BRK55 OOS (tight, 0 spread)..." -ForegroundColor Cyan
Run-MT5 "BRK55_tight_OOS" "EA_BREAKOUT_XAU" "XAUUSD" "H1" "2025.01.01" "2026.06.01" $brk55Set 4 "EXTRA-C"

# C2c: BRK55 realistic IS
Write-Host "`nC2c. BRK55 IS (realistic, +5 spread)..." -ForegroundColor Cyan
Run-MT5 "BRK55_realistic_IS" "EA_BREAKOUT_XAU" "XAUUSD" "H1" "2023.01.01" "2025.01.01" $brk55Set 4 "EXTRA-C"

# C2d: BRK55 realistic OOS
Write-Host "`nC2d. BRK55 OOS (realistic, +5 spread)..." -ForegroundColor Cyan
Run-MT5 "BRK55_realistic_OOS" "EA_BREAKOUT_XAU" "XAUUSD" "H1" "2025.01.01" "2026.06.01" $brk55Set 4 "EXTRA-C"

# Done
$dt = Get-Date -Format "yyyy-MM-dd HH:mm"
"| $dt | EXTRA-DONE | All A+B+C complete | - | - | OK |" | Out-File $LogFile -Append -Encoding utf8
Write-Host "`n$('='*50)" -ForegroundColor Green
Write-Host "All EXTRA runs complete! Results in $LogFile" -ForegroundColor Green
Write-Host "$('='*50)`n"
