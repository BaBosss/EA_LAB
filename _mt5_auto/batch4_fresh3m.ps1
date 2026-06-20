$ErrorActionPreference = "Continue"
$s    = "D:\EA_LAB\scripts"
$base = "D:\EA_LAB\_mt5_auto\reports"
$log  = "D:\EA_LAB\_mt5_auto\batch4_fresh3m.log"
$FROM = "2026.01.01"
$TO   = "2026.04.01"
$GATE_PF = 1.40

function Log($msg) {
    $line = "$((Get-Date -Format 'HH:mm:ss')) $msg"
    Write-Output $line
    Add-Content -Path $log -Value $line -Encoding UTF8
}

function ParseReport($rpt) {
    $dst = "$base\$rpt.htm"
    if (-not (Test-Path $dst)) { Log "  NO REPORT -- skip"; return }
    $html = Get-Content $dst -Raw -Encoding UTF8

    $pf = "?"
    $np = "?"
    $dd = "?"
    $tr = "?"

    if ($html -match '(?s)Profit Factor:.*?<b>([\d.]+)</b>') { $pf = $matches[1] }
    if ($html -match '(?s)Total Net Profit:.*?<b>([^<]+)</b>') { $np = $matches[1].Trim() }
    if ($html -match '(?s)Equity Drawdown Maximal:.*?<b>([^<]+)</b>') { $dd = $matches[1].Trim() }
    if ($html -match '(?s)Total Trades:.*?<b>(\d+)</b>') { $tr = $matches[1] }

    $pfVal = [double]0
    $pfParsed = [double]::TryParse($pf, [ref]$pfVal)
    $verdict = if ($pfParsed -and $pfVal -ge $GATE_PF -and $tr -ne "0" -and $tr -ne "?") { "PASS" } else { "REJECT" }

    $resultLine = "RESULT $rpt PF=$pf NP=$np DD=$dd Trades=$tr $verdict"
    Log "  $resultLine"
}

function RunFresh($expert, $label, $symbol) {
    $rpt = "B4_FRESH_${label}_${symbol}"
    $dst = "$base\$rpt.htm"
    if (Test-Path $dst) { Log "SKIP (exists) $rpt"; ParseReport $rpt; return }
    Log "START $rpt -- $expert / $symbol"
    try {
        & "$s\mt5_run.ps1" -Expert $expert -Symbol $symbol -Period H1 -Model 1 `
            -FromDate $FROM -ToDate $TO -ReportName $rpt -TimeoutSec 300
    } catch {
        Log "ERROR $rpt : $($_.Exception.Message)"
    }
    Stop-Process -Name terminal64 -Force -EA SilentlyContinue
    Start-Sleep 3
    ParseReport $rpt
}

Set-Content -Path $log -Value "" -Encoding UTF8
Log "=== BATCH4 FRESH 3M START ($FROM -> $TO) ==="

$eas = @(
    @{Expert="Ghost Bot 01 G07 (1)";           Label="GhostBot_G07";   Symbol="EURUSD"},
    @{Expert="Ghost Bot 01 G07 (1)";           Label="GhostBot_G07";   Symbol="XAUUSD"},
    @{Expert="Ghost by JOMHOD MA5";            Label="Ghost_JOMHOD";   Symbol="EURUSD"},
    @{Expert="Winning Pro 2.5 (Update)";       Label="WinningPro25";   Symbol="EURUSD"},
    @{Expert="EA TREND V2";                    Label="EA_TREND_V2";    Symbol="EURUSD"},
    @{Expert="EA TREND V2";                    Label="EA_TREND_V2";    Symbol="XAUUSD"},
    @{Expert="Grizzy[BUY]v1.0";               Label="Grizzy_BUY";     Symbol="EURUSD"},
    @{Expert="(Boss) Hedging Balance";          Label="Boss_Hedging";   Symbol="EURUSD"},
    @{Expert="Grid Profit-2-way  RV1[LOCK]V3"; Label="GridProfit2way"; Symbol="EURUSD"}
)

foreach ($ea in $eas) {
    RunFresh $ea.Expert $ea.Label $ea.Symbol
}

Log "=== ALL DONE ==="
