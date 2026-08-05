# ORDER-148 — Wave5 JPY crosses expansion (locked demo set 990301 center, no tuning).
# Phase 1: 8 M1 MAIN runs (GBPJPY/EURJPY/AUDJPY/CHFJPY × H1+H4).
# Phase 2: BWD runs only for MAIN≥1.1 gate.
# Phase 3: M4 repeat (MAIN+BWD) for survivors both-window ≥1.0. Total ~16 runs.
# Resumable: skips a run when its report already exists and parses. CSV = _mt5_auto\ORDER148_W5X.csv
$ErrorActionPreference = "Continue"
$root="D:\EA_LAB"; $run="$root\scripts\mt5_run.ps1"
$setf="$root\_vps_deploy\WAVE5_XAU\WAVE5_XAU_H1_demo_v1.set"
$py="$root\tools\python312\python.exe"
$csv="$root\_mt5_auto\ORDER148_W5X.csv"
if (-not (Test-Path $csv)) { "sym,tf,win,model,PF,net,eqDDpct,trades,winpct,report" | Out-File $csv -Encoding utf8 }
$symbols=@("GBPJPY","EURJPY","AUDJPY","CHFJPY")
$tfs=@("H1","H4")

function Invoke-Cell([string]$sym,[string]$tf,[hashtable]$w,[int]$model){
  $rn = "W5X_${sym}_${tf}_$($w.N)_M$model"
  $rep="$root\_mt5_auto\reports\$rn.htm"
  if (Select-String -Path $csv -Pattern ",$rn$" -Quiet) { Write-Output "SKIP $rn (done)"; return }
  if (-not (Test-Path $rep)) {
    Write-Output "=== RUN $rn ==="
    & $run -Expert "Boss_17_Wave5" -Symbol $sym -Period $tf -FromDate $w.F -ToDate $w.T -SetFile $setf -Model $model -ReportName $rn -Force | Out-Null
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

# Phase 1 — M1 MAIN (8 runs)
$main_gate = @{}
foreach($s in $symbols){ foreach($tf in $tfs){
  $w=@{N="MAIN";F="2023.01.01";T="2025.12.31"}
  Invoke-Cell $s $tf $w 1
  $rows = Import-Csv $csv | Where-Object { $_.sym -eq $s -and $_.tf -eq $tf -and $_.win -eq "MAIN" -and $_.model -eq "M1" }
  if ($rows) {
    $pf = if ($rows[0].PF) { [double]$rows[0].PF } else { 0.0 }
    $main_gate["${s}_${tf}"] = $pf
  }
}}

# Phase 2 — BWD runs (only if M1 MAIN ≥ 1.1)
$w_bwd=@{N="BWD";F="2020.01.01";T="2022.12.31"}
foreach($s in $symbols){ foreach($tf in $tfs){
  $key="${s}_${tf}"
  $pfM = if ($main_gate[$key]) { $main_gate[$key] } else { 0.0 }
  if ($pfM -ge 1.1) {
    Write-Output "BWD-RUN $key (M1 MAIN=$pfM >= 1.1)"
    Invoke-Cell $s $tf $w_bwd 1
  } else {
    Write-Output "BWD-SKIP $key (M1 MAIN=$pfM < 1.1)"
  }
}}

# Phase 3 — M4 for survivors (both-window ≥1.0)
$rows = Import-Csv $csv | Where-Object { $_.model -eq "M1" }
$wins_m4=@(@{N="MAIN";F="2023.01.01";T="2025.12.31"},@{N="BWD";F="2020.01.01";T="2022.12.31"})
foreach($s in $symbols){ foreach($tf in $tfs){
  $main = $rows | Where-Object { $_.sym -eq $s -and $_.tf -eq $tf -and $_.win -eq "MAIN" } | Select-Object -First 1
  $bwd  = $rows | Where-Object { $_.sym -eq $s -and $_.tf -eq $tf -and $_.win -eq "BWD"  } | Select-Object -First 1
  $pfM=0.0; $pfB=0.0
  if ($main -and ($main.PF -ne "") -and ($main.PF -ne $null)) { $pfM=[double]$main.PF }
  if ($bwd  -and ($bwd.PF  -ne "") -and ($bwd.PF  -ne $null)) { $pfB=[double]$bwd.PF }
  if ($pfM -ge 1.0 -and $pfB -ge 1.0) {
    Write-Output "SURVIVOR $s $tf (M1 MAIN=$pfM BWD=$pfB) -> M4"
    foreach($w in $wins_m4){ Invoke-Cell $s $tf $w 4 }
  }
}}
Write-Output "ORDER148 SWEEP COMPLETE -> $csv"
