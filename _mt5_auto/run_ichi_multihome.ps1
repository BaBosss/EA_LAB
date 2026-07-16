# ORDER-112C: apply the USDJPY-validated Ichimoku period configs to OTHER trending homes.
# Prior probe found GBPJPY/AUDJPY "dead" but at DEFAULT periods (9/26/52). Re-test with the
# med (12/34/68 H4) + slow (20/60/120 H1) configs that revived USDJPY. both-window Model-4.
$ErrorActionPreference='Continue'; $root='D:\EA_LAB'
$setDir="$root\_mt5_auto\ab_sets\ichi_kumo"; $out="$root\_mt5_auto\ICHI_MULTIHOME.csv"
$syms=@('GBPJPY','EURJPY','CADJPY','AUDJPY','GBPUSD','XAUUSD')
$cfgs=@(
  @{n='medH4'; tf='H4'; set='KUMO_med_H4.set'},
  @{n='slowH1';tf='H1'; set='KUMO_slow_H1.set'}
)
$wins=@(@{t='MAIN';f='2023.01.01';to='2026.07.01'},@{t='BWD';f='2020.01.01';to='2023.01.01'})
function P($h){$x=(Get-Content $h -Raw)-replace'<[^>]+>','|';$p=($x-split'\|')|%{$_.Trim()}|?{$_};$o=@{};$k=@{'Total Net Profit:'='net';'Profit Factor:'='pf';'Total Trades:'='trades';'Equity Drawdown Maximal:'='eqdd'};for($i=0;$i-lt$p.Count-1;$i++){if($k.ContainsKey($p[$i])){$o[$k[$p[$i]]]=($p[$i+1]-replace'\s','')}};return $o}
$rows=@()
foreach($sym in $syms){foreach($c in $cfgs){$sp=Join-Path $setDir $c.set
  foreach($w in $wins){$rep="MH_{0}_{1}_{2}" -f $sym,$c.n,$w.t; Write-Host ">> $rep"
    try{& "$root\scripts\mt5_run.ps1" -Expert '(EXP)_IchiADX_Naked_rev00' -Symbol $sym -Period $c.tf -FromDate $w.f -ToDate $w.to -Model 4 -ReportName $rep -SetFile $sp | Out-Null}catch{Write-Host "  ERR $_"}
    $h="$root\_mt5_auto\reports\$rep.htm"; if(-not(Test-Path $h)){Write-Host "  [no report]"; continue}
    $m=P $h; $rows+=[pscustomobject]@{sym=$sym;cfg=$c.n;window=$w.t;pf=$m['pf'];net=$m['net'];trades=$m['trades'];eqdd=$m['eqdd']}
    Write-Host ("   pf={0} net={1} n={2}" -f $m['pf'],$m['net'],$m['trades'])}}}
$rows|Export-Csv $out -NoTypeInformation -Encoding utf8; Write-Host "DONE $($rows.Count) rows -> $out"
