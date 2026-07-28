# =============================== HOLDOUT-BURNED ===============================
# ORDER-238 (2026-07-27). One or more test windows in this file end after
# 2025.12.31 -- that is, inside the 2026H1 holdout. They are deliberately LEFT
# AS-IS: they record what past runs actually did, and rewriting them would
# misrepresent that history.
#
# Therefore: do NOT re-run this script to produce selection evidence, and do NOT
# copy its window into new work. A holdout is spent the first time it is touched.
# The current MAIN window is pinned in the VERDICT GATE section of CLAUDE.md.
# ==============================================================================
# QWEN_BATCH_RUNNER.ps1 — runs TASK 1-4 from QWEN_RUN_PLAN.md
# Log: D:\EA_LAB\QWEN_RUN_LOG.md
# Rules: log ERR + skip, no git, no judgment, report names start with QWEN_

param(
    # ORDER-238. Nothing else in this file changed: the windows below still end at
    # 2026.06.01 because that is what the original runs did. What changed is that
    # you can no longer touch the holdout by accident just by invoking the driver.
    [switch]$SpendHoldout2026H1
)

# ORDER-238 invoke-time guard. This file is the dangerous one of the burned set:
# it is a BATCH DRIVER, so an agent lane can pick it up and run the whole plan
# without a human reading the banner above. A printed warning would not have
# stopped that -- an automated lane does not read warnings. So the default path
# refuses and explains, and spending the holdout requires saying so out loud.
if (-not $SpendHoldout2026H1) {
    Write-Host ''
    Write-Host '  REFUSED: qwen_batch_runner.ps1 runs windows that end 2026.06.01.' -ForegroundColor Red
    Write-Host '  That is inside the 2026H1 holdout, and a holdout is spent the first' -ForegroundColor Red
    Write-Host '  time it is touched. These windows are kept as a record of past runs.' -ForegroundColor Red
    Write-Host ''
    Write-Host '  If you want fresh evidence, do NOT use this driver -- write the run' -ForegroundColor Yellow
    Write-Host '  against the current MAIN window (see the VERDICT GATE in CLAUDE.md).' -ForegroundColor Yellow
    Write-Host '  If you genuinely intend to spend the holdout, re-invoke with:' -ForegroundColor Yellow
    Write-Host '      -SpendHoldout2026H1' -ForegroundColor Yellow
    Write-Host '  and say so in the order block, because it cannot be taken back.' -ForegroundColor Yellow
    Write-Host ''
    exit 3
}
Write-Host '[holdout] -SpendHoldout2026H1 given: proceeding INTO the 2026H1 holdout deliberately.' -ForegroundColor Magenta

$LogFile = "D:\EA_LAB\QWEN_RUN_LOG.md"
$ScriptDir = "D:\EA_LAB\scripts"

# Create log header if missing
if (-not (Test-Path $LogFile)) {
    "# QWEN RUN LOG`n| datetime | task | tag/sym/window | report_path | metrics | status |`n|---|---|---|---|---|---|" | Out-File $LogFile -Encoding utf8
}

function Log-Result($task, $tag, $sym, $window, $reportPath, $metrics, $status) {
    $dt = Get-Date -Format "yyyy-MM-dd HH:mm"
    "| $dt | $task | $tag/$sym/$window | $reportPath | $metrics | $status |" | Out-File $LogFile -Append -Encoding utf8
}

function Run-MT5($tag, $expert, $symbol, $period, $fromDate, $toDate, $setFile, $model=4, $taskNum="TASK1") {
    $window = if ($toDate -le "2025.01.02") { "IS" } elseif ($fromDate -ge "2025.01.01" -and $toDate -le "2025.07.02") { "OOS_half1" } elseif ($fromDate -ge "2025.07.01") { "OOS_half2" } else { "OOS" }
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

    $retries = 0
    $ok = $false
    $fallbackNote = ""
    while ($retries -lt 2 -and -not $ok) {
        try {
            $out = & "$ScriptDir\mt5_run.ps1" @args 2>&1
            $runnerExit = $LASTEXITCODE
            Write-Host $out
            # Parse PF/Net/Trades from output
            $pf = if ($out -match "Profit Factor[:\s]+([\d.]+)") { $matches[1] } else { "?" }
            $net = if ($out -match "Net Profit[:\s]+([-\d.]+)") { $matches[1] } else { "?" }
            $tr = if ($out -match "Trades[:\s]+(\d+)") { $matches[1] } else { "?" }
            # Find report path
            $rpt = if ($out -match "(D:\\[^\s]+\.html)") { $matches[1] } else { "-" }
            # ORDER-372: this lane cannot read a STALE report (every value above is derived from
            # THIS run's captured output, not from a filename), but it used to log status "OK"
            # unconditionally - so an aborted run was recorded as a completed one carrying "?" for
            # every metric. A row that says OK is the thing downstream readers trust, so the exit
            # code decides the status.
            $status = if ($runnerExit -eq 0) { "OK" }
                      elseif ($runnerExit -eq 3) { "LEVERAGE_MISMATCH" }
                      else { "FAILED_EXIT$runnerExit" }
            Log-Result $taskNum $tag $symbol $window $rpt "PF=$pf Net=$net Trades=$tr$fallbackNote" $status
            $ok = $true
        } catch {
            $retries++
            Write-Host "ERR retry $retries : $_" -ForegroundColor Yellow
            if ($retries -eq 1 -and $model -eq 4) {
                # fallback to Model 2
                $args[-1] = $reportName  # keep reportName
                $modelIdx = $args.IndexOf("-Model") + 1
                if ($modelIdx -gt 0) { $args[$modelIdx] = 2 }
                $fallbackNote = " M2fallback"
            }
        }
    }
    if (-not $ok) {
        Log-Result $taskNum $tag $symbol $window "-" "PF=? Net=? Trades=?" "ERR"
    }
    return $ok
}

# ── TASK 1: IS + OOS for all deployed EAs ──────────────────────────────────
Write-Host "`n### TASK 1 — RE-CONFIRM OOS ###" -ForegroundColor Green

$eas = @(
    @{tag="ST03rep"; expert="EA_RUNNER_ST03";                              sym="GBPUSD"; tf="H1";  set="D:\EA_LAB\_vps_deploy\ST03_GBPUSD\ST03_GBPUSD_live_v1.set"},
    @{tag="BRK55";   expert="EA_BREAKOUT_XAU";                             sym="XAUUSD"; tf="H1";  set="D:\EA_LAB\_vps_deploy\BRK_XAU_live_v3.set"},
    @{tag="BRK8";    expert="EA_BREAKOUT_XAU";                             sym="XAUUSD"; tf="H1";  set="D:\EA_LAB\_vps_deploy\BRK_XAU_Bars8\BRKXAUH4_Bars8_demo_v1.set"},
    @{tag="CBGBP";   expert="(Boss)_LondonConsoBreakout_rev01";            sym="GBPUSD"; tf="H1";  set="D:\EA_LAB\_vps_deploy\CB_GBP\CB_GBP_H1_live_v1.set"},
    @{tag="NUII";    expert="(NuiIndy) Dynamic RSI+ADX Style (4)";         sym="EURUSD"; tf="H1";  set="D:\EA_LAB\_mt5_auto\NuiIndy_EURUSD_robust.set"},
    @{tag="MACDg";   expert="(ST) EA03 Count MACD v1";                     sym="GBPUSD"; tf="H1";  set="D:\EA_LAB\_mt5_auto\MACD_GBPUSD_locked.set"},
    @{tag="MACDc";   expert="(ST) EA03 Count MACD v1";                     sym="USDCAD"; tf="H1";  set="D:\EA_LAB\_mt5_auto\MACD_USDCAD_locked.set"},
    @{tag="GR";      expert="The Gold Reaper MT5_4.3_fix_@FundedMillionAiress"; sym="XAUUSD"; tf="H1"; set="D:\EA_LAB\_mt5_auto\GoldReaper_cent_v1.set"},
    @{tag="MG";      expert="Matchagrid";                                   sym="CHFJPY"; tf="M15"; set="D:\EA_LAB\_mt5_auto\MG_CHFJPY_v1_locked.set"}
)

$st03ok = $false
foreach ($ea in $eas) {
    $r1 = Run-MT5 $ea.tag $ea.expert $ea.sym $ea.tf "2023.01.01" "2025.01.01" $ea.set 4 "TASK1"
    $r2 = Run-MT5 $ea.tag $ea.expert $ea.sym $ea.tf "2025.01.01" "2026.06.01" $ea.set 4 "TASK1"
    if ($ea.tag -eq "ST03rep" -and $r1 -and $r2) { $st03ok = $true }
}

# ── TASK 2: Gold Reaper optimize ───────────────────────────────────────────
Write-Host "`n### TASK 2 — GR OPTIMIZE ###" -ForegroundColor Green
try {
    Copy-Item "D:\EA_LAB\_mt5_auto\GoldReaper_cent_v1.set" "D:\EA_LAB\_mt5_auto\GR_opt.set" -Force
    $content = Get-Content "D:\EA_LAB\_mt5_auto\GR_opt.set"
    $lotLine = $content | Where-Object { $_ -match "^(StartLots|Lots|LotSize|lot)=" }
    if ($lotLine) {
        $paramName = ($lotLine -split "=")[0]
        $content = $content -replace "^${paramName}=.*", "${paramName}=0.01||0.01||0.01||0.05||Y"
        $content | Set-Content "D:\EA_LAB\_mt5_auto\GR_opt.set" -Encoding utf8
        $out = & "$ScriptDir\mt5_optimize.ps1" -Expert "The Gold Reaper MT5_4.3_fix_@FundedMillionAiress" `
            -Symbol XAUUSD -Period H1 -FromDate "2023.01.01" -ToDate "2026.06.01" `
            -SetFile "D:\EA_LAB\_mt5_auto\GR_opt.set" -Model 1 -Optimization 2 -TimeoutSec 7200 `
            -ReportName "QWEN_GR_opt" 2>&1
        Write-Host $out
        $rpt = if ($out -match "(D:\\[^\s]+\.xml)") { $matches[1] } else { "-" }
        Log-Result "TASK2" "GR_opt" "XAUUSD" "FULL" $rpt "optimize done" "OK"
        # parse
        $parseOut = & "$ScriptDir\parse_opt_xml.ps1" 2>&1
        Write-Host $parseOut
    } else {
        Log-Result "TASK2" "GR_opt" "XAUUSD" "FULL" "-" "GR param name unknown skip TASK2" "ERR"
    }
} catch {
    Log-Result "TASK2" "GR_opt" "XAUUSD" "FULL" "-" "ERR: $_" "ERR"
}

# ── TASK 3: ST03 coarse grid ───────────────────────────────────────────────
if ($st03ok) {
    Write-Host "`n### TASK 3 — ST03 GRID ###" -ForegroundColor Green
    try {
        Copy-Item "D:\EA_LAB\_vps_deploy\ST03_GBPUSD\ST03_GBPUSD_live_v1.set" "D:\EA_LAB\_mt5_auto\ST03_grid.set" -Force
        $sc = Get-Content "D:\EA_LAB\_mt5_auto\ST03_grid.set"
        $rangeMap = @{
            "InpTp3Pts"    = "50||30||10||120||Y"
            "InpNearbyPip" = "100||50||50||150||Y"
            "InpLotRepeat" = "3||2||1||3||Y"
            "InpPendingMode" = "2||2||1||3||Y"
        }
        $missing = @()
        foreach ($k in $rangeMap.Keys) {
            if ($sc -match "^${k}=") {
                $sc = $sc -replace "^${k}=.*", "${k}=$($rangeMap[$k])"
            } else { $missing += $k }
        }
        if ($missing.Count -gt 0) {
            Log-Result "TASK3" "ST03GRID" "GBPUSD" "OPT" "-" "param mismatch: $($missing -join ',') skip" "ERR"
        } else {
            $sc | Set-Content "D:\EA_LAB\_mt5_auto\ST03_grid.set" -Encoding utf8
            $out = & "$ScriptDir\optimize_loop.ps1" -Expert "EA_RUNNER_ST03" -Symbol GBPUSD -Period H1 `
                -Model 1 -BaseSet "D:\EA_LAB\_mt5_auto\ST03_grid.set" -Code ST03GRID `
                -OptFrom "2023.01.01" -OptTo "2025.01.01" -OosFrom "2025.01.01" -OosTo "2026.06.01" 2>&1
            Write-Host $out
            $rpt = if ($out -match "(D:\\[^\s]+)") { $matches[1] } else { "-" }
            Log-Result "TASK3" "ST03GRID" "GBPUSD" "IS+OOS" $rpt "grid done" "OK"
        }
    } catch {
        Log-Result "TASK3" "ST03GRID" "GBPUSD" "IS+OOS" "-" "ERR: $_" "ERR"
    }
} else {
    Log-Result "TASK3" "ST03GRID" "GBPUSD" "SKIP" "-" "skipped ST03rep TASK1 failed" "SKIP"
}

# ── TASK 4: MT4 gold-grid ──────────────────────────────────────────────────
Write-Host "`n### TASK 4 — MT4 GOLD-GRID ###" -ForegroundColor Green
$ggPlan = "D:\EA_LAB\MT4_GOLDGRID_RETEST_PLAN.md"
if (Test-Path $ggPlan) {
    $planContent = Get-Content $ggPlan -Raw
    # Try to extract expert names from the plan
    $mt4eas = @()
    if ($planContent -match "Elephant") { $mt4eas += @{name="Elephant"; expert="Elephant"; set=""} }
    if ($planContent -match "Mammoth")  { $mt4eas += @{name="Mammoth";  expert="Mammoth";  set=""} }
    if ($planContent -match "Gold Stuff V7|GoldStuffV7") { $mt4eas += @{name="GoldStuffV7"; expert="Gold Stuff v.7"; set=""} }
    foreach ($mt4ea in $mt4eas) {
        try {
            $args2 = @("-Expert", $mt4ea.expert, "-Symbol", "XAUUSD", "-Period", "H1",
                       "-FromDate", "2023.01.01", "-ToDate", "2026.06.01",
                       "-Model", 2, "-ReportName", "QWEN_GG_$($mt4ea.name)", "-Force")
            if ($mt4ea.set -ne "") { $args2 += @("-SetFile", $mt4ea.set) }
            $out = & "$ScriptDir\mt4_run.ps1" @args2 2>&1
            Write-Host $out
            $rpt = if ($out -match "(D:\\[^\s]+\.html)") { $matches[1] } else { "-" }
            Log-Result "TASK4" "GG_$($mt4ea.name)" "XAUUSD" "FULL" $rpt "PF=? Net=? Trades=?" "OK"
        } catch {
            Log-Result "TASK4" "GG_$($mt4ea.name)" "XAUUSD" "FULL" "-" "ERR: $_" "ERR"
        }
    }
} else {
    Log-Result "TASK4" "GG" "XAUUSD" "FULL" "-" "MT4_GOLDGRID_RETEST_PLAN.md not found" "ERR"
}

# ── ROUND 2: Model 2 comparison ────────────────────────────────────────────
Write-Host "`n### ROUND 2 — MODEL 2 COMPARISON ###" -ForegroundColor Green
foreach ($ea in $eas) {
    Run-MT5 "$($ea.tag)_M2" $ea.expert $ea.sym $ea.tf "2023.01.01" "2025.01.01" $ea.set 2 "TASK1R2"
    Run-MT5 "$($ea.tag)_M2" $ea.expert $ea.sym $ea.tf "2025.01.01" "2026.06.01" $ea.set 2 "TASK1R2"
}

# ── ROUND 3: OOS halves for PF>1.5 EAs ────────────────────────────────────
Write-Host "`n### ROUND 3 — OOS HALVES ###" -ForegroundColor Green
$logContent = Get-Content $LogFile -Raw
foreach ($ea in $eas) {
    # check if PF > 1.5 in log for this tag OOS
    if ($logContent -match "$($ea.tag)/[^|]+/OOS[^|]*\|[^|]*PF=([\d.]+)" -and [float]$matches[1] -gt 1.5) {
        Run-MT5 "$($ea.tag)_half1" $ea.expert $ea.sym $ea.tf "2025.01.01" "2025.07.01" $ea.set 4 "TASK1R3"
        Run-MT5 "$($ea.tag)_half2" $ea.expert $ea.sym $ea.tf "2025.07.01" "2026.06.01" $ea.set 4 "TASK1R3"
    }
}

# Done
$dt = Get-Date -Format "yyyy-MM-dd HH:mm"
"| $dt | DONE | QUEUE DRAINED idle until Claude review | - | - | OK |" | Out-File $LogFile -Append -Encoding utf8
Write-Host "`nAll tasks complete. Results in $LogFile" -ForegroundColor Green
