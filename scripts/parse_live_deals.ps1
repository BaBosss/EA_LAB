<#
.SYNOPSIS
  Roll up the live/demo deal CSV (from report_deals.mq5) into a per-EA
  scorecard grouped by (magic, symbol). Pairs with the ea-live-monitor skill.

.DESCRIPTION
  report_deals.mq5 writes a CSV with per-deal magic numbers (the MT5 account
  HTML report drops magic, which is why we use the HistoryDeal API instead).
  This script groups realized (OUT/INOUT) deals by (magic, symbol) and computes
  the live metrics ea-live-monitor judges against the backtest expectation:
  net, trades, PF, win%, avg win:loss, max consecutive losses, realized DD.

.PARAMETER Path
  Path to the CSV produced by report_deals.mq5 (default: the Common\Files copy).

.PARAMETER Csv
  Optional path to also write the per-EA summary as a CSV.

.EXAMPLE
  .\parse_live_deals.ps1 -Path "$env:APPDATA\..\Common\Files\live_deals.csv"
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Path,
  [string]$Csv
)

if(-not (Test-Path $Path)) { Write-Error "CSV not found: $Path"; exit 1 }

$rows = Import-Csv -Path $Path
if($rows.Count -eq 0) { Write-Error "CSV is empty: $Path"; exit 1 }

# realized deals only (report_deals.mq5 with InpClosedOnly already filters, but
# guard here too so a full-history export still rolls up correctly).
$deals = $rows | Where-Object { $_.entry -eq 'OUT' -or $_.entry -eq 'INOUT' }

# balance / non-trade deals (deposits, corrections) reported separately, not per-EA.
$nonTrade = $rows | Where-Object { $_.type -in @('BALANCE','CREDIT','CHARGE','CORRECTION') }
if($nonTrade.Count -gt 0){
  $depo = ($nonTrade | Measure-Object -Property net -Sum).Sum
  Write-Host ("Note: {0} non-trade deals (deposits/corrections), net {1:N2} - excluded from per-EA PnL." -f $nonTrade.Count, $depo) -ForegroundColor DarkGray
}

# ⚠️ group by the (magic,symbol) PAIR — magic alone merges EAs that share a magic
# (e.g. LondonConsoBreakout CB_GBP + CB_EUR both use 990005).
$groups = $deals | Group-Object { "$($_.magic)|$($_.symbol)" }

$summary = foreach($g in $groups){
  $items = $g.Group | Sort-Object { [datetime]$_.time }
  $nets  = $items | ForEach-Object { [double]$_.net }

  $n        = $nets.Count
  $netSum   = ($nets | Measure-Object -Sum).Sum
  $wins     = @($nets | Where-Object { $_ -gt 0 })
  $losses   = @($nets | Where-Object { $_ -lt 0 })
  $grossW   = ($wins   | Measure-Object -Sum).Sum
  $grossL   = [math]::Abs((($losses | Measure-Object -Sum).Sum))
  $pf       = if($grossL -gt 0){ [math]::Round($grossW / $grossL, 2) } else { "Inf" }  # no losing trades yet
  $winPct   = if($n -gt 0){ [math]::Round(100.0 * $wins.Count / $n, 1) } else { 0 }
  $avgW     = if($wins.Count   -gt 0){ [math]::Round(($wins   | Measure-Object -Average).Average, 2) } else { 0 }
  $avgL     = if($losses.Count -gt 0){ [math]::Round([math]::Abs(($losses | Measure-Object -Average).Average), 2) } else { 0 }
  $wlRatio  = if($avgL -gt 0){ [math]::Round($avgW / $avgL, 2) } else { 0 }

  # max consecutive losses
  $maxConsec = 0; $cur = 0
  foreach($x in $nets){ if($x -lt 0){ $cur++; if($cur -gt $maxConsec){$maxConsec=$cur} } else { $cur = 0 } }

  # realized drawdown of this EA's own running equity contribution
  $run = 0.0; $peak = 0.0; $maxDD = 0.0
  foreach($x in $nets){ $run += $x; if($run -gt $peak){$peak=$run}; $dd = $peak - $run; if($dd -gt $maxDD){$maxDD=$dd} }

  $parts = $g.Name -split '\|'
  [pscustomobject]@{
    magic        = $parts[0]
    symbol       = $parts[1]
    trades       = $n
    net          = [math]::Round($netSum,2)
    PF           = $pf
    win_pct      = $winPct
    avg_win      = $avgW
    avg_loss     = $avgL
    win_loss     = $wlRatio
    max_consec_L = $maxConsec
    realized_DD  = [math]::Round($maxDD,2)
  }
}

$summary = $summary | Sort-Object { [double]$_.net } -Descending

Write-Host ""
Write-Host "=== Per-EA scorecard (by magic, symbol) ===" -ForegroundColor Cyan
$summary | Format-Table -AutoSize

$totNet = ($summary | Measure-Object -Property net -Sum).Sum
Write-Host ("Portfolio realized net (trades only): {0:N2}  across {1} EA groups, {2} deals" -f $totNet, $summary.Count, $deals.Count) -ForegroundColor Green

if($Csv){
  $summary | Export-Csv -Path $Csv -NoTypeInformation -Encoding UTF8
  Write-Host "Wrote summary CSV: $Csv"
}
