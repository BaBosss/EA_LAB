# ORDER-147 — S1 TrendRider symbol expansion (locked demo set 992004 center, no tuning).
# Phase 1: 5 cells (XAGUSD H1+H4, GBPJPY/USDJPY/EURJPY H4) x MAIN+BWD, Model 1 = 10 runs.
# Phase 2: M4 repeat (MAIN+BWD) only for cells with M1 PF>=1.0 in BOTH windows.
# Resumable: skips a run when its report already exists and parses. CSV = _mt5_auto\ORDER147_S1X.csv
$ErrorActionPreference = "Continue"
$root="D:\EA_LAB"; $run="$root\scripts\mt5_run.ps1"
$setf="$root\_vps_deploy\W2_S1_TRENDRIDER_XAU\S1_TrendRider_XAU_deploy.set"
$py="$root\tools\python312\python.exe"
$csv="$root\_mt5_auto\ORDER147_S1X.csv"
if (-not (Test-Path $csv)) { "sym,tf,win,model,PF,net,eqDDpct,trades,winpct,report" | Out-File $csv -Encoding utf8 }
$cells=@(
  @{S="XAGUSD";TF="H1"},@{S="XAGUSD";TF="H4"},
  @{S="GBPJPY";TF="H4"},@{S="USDJPY";TF="H4"},@{S="EURJPY";TF="H4"}
)
$wins=@(@{N="MAIN";F="2023.01.01";T="2025.12.31"},@{N="BWD";F="2020.01.01";T="2022.12.31"})

function Invoke-Cell([string]$sym,[string]$tf,[hashtable]$w,[int]$model){
  $rn = "S1X_${sym}_${tf}_$($w.N)_M$model"
  $rep="$root\_mt5_auto\reports\$rn.htm"
  if (Select-String -Path $csv -Pattern ",$rn$" -Quiet) { Write-Output "SKIP $rn (done)"; return }
  if (-not (Test-Path $rep)) {
    Write-Output "=== RUN $rn ==="
    & $run -Expert "(TRND)_TrendRider_XAU" -Symbol $sym -Period $tf -FromDate $w.F -ToDate $w.T -SetFile $setf -Model $model -ReportName $rn -Force | Out-Null
  }
  $mPF="";$mNet="";$mDD="";$mTr="";$mWp=""
  if (Test-Path $rep) {
    try { $o=& $py "$root\scripts\parse_mt5_report.py" $rep --json 2>$null | ConvertFrom-Json
      $mPF=$o.profit_factor;$mNet=$o.net_profit;$mDD=$o.equity_drawdown_relative_pct;$mTr=$o.total_trades;$mWp=$o.profit_trades_pct
    } catch {}
  }
  Add-Content $csv ('{0},{1},{2},M{3},{4},{5},{6},{7},{8},{9}' -f $sym,$tf,$w.N,$model,$mPF,$mNet,$mDD,$mTr,$mWp,$rn)
  Write-Output "DONE $rn PF=$mPF n=$mTr"
}

# Phase 1 — M1
foreach($c in $cells){ foreach($w in $wins){ Invoke-Cell $c.S $c.TF $w 1 } }

# Phase 2 — M4 for survivors (M1 PF>=1.0 both windows)
$rows = Import-Csv $csv | Where-Object { $_.model -eq "M1" }
foreach($c in $cells){
  $main = $rows | Where-Object { $_.sym -eq $c.S -and $_.tf -eq $c.TF -and $_.win -eq "MAIN" } | Select-Object -First 1
  $bwd  = $rows | Where-Object { $_.sym -eq $c.S -and $_.tf -eq $c.TF -and $_.win -eq "BWD"  } | Select-Object -First 1
  $pfM=0.0; $pfB=0.0
  if ($main -and $main.PF -ne "") { $pfM=[double]$main.PF }
  if ($bwd  -and $bwd.PF  -ne "") { $pfB=[double]$bwd.PF }
  if ($pfM -ge 1.0 -and $pfB -ge 1.0) {
    Write-Output "SURVIVOR $($c.S) $($c.TF) (M1 MAIN=$pfM BWD=$pfB) -> M4"
    foreach($w in $wins){ Invoke-Cell $c.S $c.TF $w 4 }
  }
}
Write-Output "ORDER147 SWEEP COMPLETE -> $csv"
