# ORDER-022 driver: plateau-sensitivity test, 6 demo EAs x 8 variants = 48 full-window backtests
# Run manually (foreground call already scopes timeout) - this script itself loops sequentially.
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1

$autoDir = "D:\EA_LAB\_mt5_auto"
$abDir = "$autoDir\ab_sets"
New-Item -ItemType Directory -Force $abDir | Out-Null
$resultsCsv = "$autoDir\ORDER022_SENSITIVITY.csv"
"symbol,variant,param_changed,value,pf,trades,eqdd_pct,net_profit,report" | Out-File -FilePath $resultsCsv -Encoding utf8

$symbols = @(
  @{Sym="USDJPY"; Step=1.4; Dist=3.0; TP=100},
  @{Sym="AUDNZD"; Step=1.4; Dist=1.4; TP=175},
  @{Sym="EURJPY"; Step=2.2; Dist=1.4; TP=250},
  @{Sym="AUDCAD"; Step=1.4; Dist=1.4; TP=250},
  @{Sym="CADJPY"; Step=3.0; Dist=2.2; TP=175},
  @{Sym="EURUSD"; Step=1.4; Dist=3.0; TP=100}
)

function Set-SetValue {
  param($lines, $key, $val)
  $out = @()
  $found = $false
  foreach ($l in $lines) {
    if ($l -match "^\s*$([regex]::Escape($key))\s*=") {
      $out += "$key=$val"
      $found = $true
    } else {
      $out += $l
    }
  }
  if (-not $found) { $out += "$key=$val" }
  return $out
}

$total = $symbols.Count * 8
$done = 0

foreach ($s in $symbols) {
  $sym = $s.Sym
  $demoSet = "D:\EA_LAB\ea_template\sets\Boss14_GridLog_${sym}_DEMO.set"
  $baseLines = Get-Content $demoSet

  $variants = @(
    @{N=1; Key="_9_StepATRmult"; Val=[math]::Round($s.Step*0.8,2)},
    @{N=2; Key="_9_StepATRmult"; Val=[math]::Round($s.Step*1.2,2)},
    @{N=3; Key="_14_DistAtrMult"; Val=[math]::Round($s.Dist*0.8,2)},
    @{N=4; Key="_14_DistAtrMult"; Val=[math]::Round($s.Dist*1.2,2)},
    @{N=5; Key="_2_BasketTP_Money"; Val=[math]::Round($s.TP*0.8,0)},
    @{N=6; Key="_2_BasketTP_Money"; Val=[math]::Round($s.TP*1.2,0)},
    @{N=7; Key="_33_SL_ATRmult"; Val=3.0},
    @{N=8; Key="_33_SL_ATRmult"; Val=5.0}
  )

  foreach ($v in $variants) {
    $done++
    $setPath = "$abDir\Boss14_GridLog_${sym}_SENS_V$($v.N).set"
    $newLines = Set-SetValue -lines $baseLines -key $v.Key -val $v.Val
    [IO.File]::WriteAllLines($setPath, $newLines)

    $reportName = "SENS_${sym}_V$($v.N)"
    Write-Output "[$done/$total] RUN $reportName ($($v.Key)=$($v.Val))"

    powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol $sym -Period H1 -FromDate 2023.01.01 -ToDate 2026.07.01 -Model 1 -SetFile $setPath -ReportName $reportName -TimeoutSec 900

    $reportHtm = "$autoDir\reports\$reportName.htm"
    if (Test-Path $reportHtm) {
      $jsonTxt = python D:\EA_LAB\scripts\parse_mt5_report.py $reportHtm --json 2>$null | Out-String
      try {
        $obj = $jsonTxt | ConvertFrom-Json
        $pf = $obj.profit_factor
        $trades = $obj.total_trades
        $eqdd = $obj.equity_drawdown_maximal_pct
        $net = $obj.net_profit
      } catch {
        $pf = "PARSE_ERR"; $trades=""; $eqdd=""; $net=""
      }
      "$sym,V$($v.N),$($v.Key),$($v.Val),$pf,$trades,$eqdd,$net,$reportName.htm" | Add-Content -Path $resultsCsv
    } else {
      "$sym,V$($v.N),$($v.Key),$($v.Val),NO_REPORT,,,," | Add-Content -Path $resultsCsv
    }
  }
}

Write-Output "ORDER-022 driver complete. Results: $resultsCsv"
