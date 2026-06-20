$base = "D:\EA_LAB\_mt5_auto\reports"
$GATE = 1.40

Write-Host "=== BATCH4 FRESH 3M RESULTS (2026.01 - 2026.04) ===" -ForegroundColor Cyan
Write-Host ""

$reports = Get-ChildItem $base -Filter "B4_FRESH_*.htm" | Sort-Object Name
if ($reports.Count -eq 0) { Write-Host "No reports found yet."; exit }

$pass = @(); $reject = @()

foreach ($f in $reports) {
    $html = Get-Content $f.FullName -Raw -Encoding UTF8

    $pf = "?"; $np = "?"; $dd = "?"; $tr = "?"
    if ($html -match '(?s)Profit Factor:.*?<b>([\d.]+)</b>') { $pf = $matches[1] }
    if ($html -match '(?s)Total Net Profit:.*?<b>([^<]+)</b>') { $np = $matches[1].Trim() }
    if ($html -match '(?s)Equity Drawdown Maximal:.*?<b>([^<]+)</b>') { $dd = $matches[1].Trim() }
    if ($html -match '(?s)Total Trades:.*?<b>(\d+)</b>') { $tr = $matches[1] }

    $pfVal = [double]0
    $ok = [double]::TryParse($pf, [ref]$pfVal)
    $verdict = if ($ok -and $pfVal -ge $GATE -and $tr -ne "0" -and $tr -ne "?") { "PASS" } else { "REJECT" }
    $color = if ($verdict -eq "PASS") { "Green" } else { "Red" }

    $name = $f.BaseName -replace "^B4_FRESH_",""
    Write-Host ("{0,-35} PF={1,5}  NP={2,10}  DD={3,15}  Trades={4,4}  [{5}]" -f $name,$pf,$np,$dd,$tr,$verdict) -ForegroundColor $color

    if ($verdict -eq "PASS") { $pass += $name } else { $reject += $name }
}

Write-Host ""
Write-Host "PASS ($($pass.Count)): $($pass -join ', ')" -ForegroundColor Green
Write-Host "REJECT ($($reject.Count)): $($reject -join ', ')" -ForegroundColor Red
