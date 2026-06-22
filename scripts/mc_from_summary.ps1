# mc_from_summary.ps1 — simplified Monte Carlo from report summary stats.
# Bootstrap with replacement: samples (n_trades) from the win/loss pool.
# NOTE: assumes avg_win / avg_loss (no magnitude variation) — underestimates tail risk.
# Use only when per-trade CSV is unavailable. Still catches ruin probability and PF distribution.
param(
  [int]$NTrades   = 189,
  [int]$WinCount  = 90,
  [double]$AvgWin = 2.73,
  [double]$AvgLoss= 1.97,   # absolute value
  [double]$Deposit= 10000,
  [int]$Iter      = 3000,
  [double]$RuinDD = 50       # ruin threshold %
)
$LossCount = $NTrades - $WinCount
# build the trade pool
$pool = @()
for($i=0;$i -lt $WinCount; $i++){ $pool += $AvgWin }
for($i=0;$i -lt $LossCount;$i++){ $pool += -$AvgLoss }
$rng = [System.Random]::new()
$pfs=@(); $dds=@(); $ruins=0
for($it=0;$it -lt $Iter;$it++){
  # bootstrap sample with replacement
  $eq = $Deposit; $peak=$Deposit; $maxdd=0.0; $gp=0.0; $gl=0.0
  for($t=0;$t -lt $NTrades;$t++){
    $trade = $pool[$rng.Next($pool.Count)]
    $eq += $trade
    if($trade -gt 0){$gp+=$trade}else{$gl+=[Math]::Abs($trade)}
    if($eq -gt $peak){$peak=$eq}
    $dd_pct=if($peak -gt 0){($peak-$eq)/$peak*100}else{0}
    if($dd_pct -gt $maxdd){$maxdd=$dd_pct}
  }
  $pf=if($gl -gt 0){[Math]::Round($gp/$gl,4)}else{999}
  $pfs+=$pf; $dds+=$maxdd
  if($maxdd -ge $RuinDD){$ruins++}
}
$sorted_pf  = $pfs  | Sort-Object
$sorted_dd  = $dds  | Sort-Object
$p5_idx     = [int]($Iter*0.05)
$p50_idx    = [int]($Iter*0.50)
$p95dd_idx  = [int]($Iter*0.95)
[PSCustomObject]@{
  Iter      = $Iter
  Trades    = $NTrades
  WinPct    = [Math]::Round($WinCount/$NTrades*100,1)
  PF_5th    = [Math]::Round($sorted_pf[$p5_idx],3)
  PF_median = [Math]::Round($sorted_pf[$p50_idx],3)
  PF_95th   = [Math]::Round($sorted_pf[$Iter-$p5_idx],3)
  DD_95th   = [Math]::Round($sorted_dd[$p95dd_idx],2)
  Ruin_pct  = [Math]::Round($ruins/$Iter*100,2)
  Note      = "simplified: avg_win=$AvgWin avg_loss=$AvgLoss (no magnitude variation)"
} | Format-List