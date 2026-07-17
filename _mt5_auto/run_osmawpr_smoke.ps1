# #1 TSD probe naked smoke — OsMA+WPR breakout, both-window Model-4 on momentum homes.
$ErrorActionPreference='Continue'; $root='D:\EA_LAB'
$out="$root\_mt5_auto\OSMAWPR_SMOKE.csv"
$syms=@('XAUUSD','GBPJPY','USDJPY','GBPUSD'); $tfs=@('H4','H1')
$wins=@(@{t='MAIN';f='2023.01.01';to='2026.07.01'},@{t='BWD';f='2020.01.01';to='2023.01.01'})
function P($h){$x=(Get-Content $h -Raw)-replace'<[^>]+>','|';$p=($x-split'\|')|%{$_.Trim()}|?{$_};$o=@{};$k=@{'Total Net Profit:'='net';'Profit Factor:'='pf';'Total Trades:'='trades';'Equity Drawdown Maximal:'='eqdd'};for($i=0;$i-lt$p.Count-1;$i++){if($k.ContainsKey($p[$i])){$o[$k[$p[$i]]]=($p[$i+1]-replace'\s','')}};return $o}
$rows=@()
foreach($sym in $syms){foreach($tf in $tfs){foreach($w in $wins){
  $rep="OW_{0}_{1}_{2}" -f $sym,$tf,$w.t; Write-Host ">> $rep"
  try{& "$root\scripts\mt5_run.ps1" -Expert '(EXP)_OsmaWpr_Naked_rev00' -Symbol $sym -Period $tf -FromDate $w.f -ToDate $w.to -Model 4 -ReportName $rep | Out-Null}catch{Write-Host "  ERR"}
  $h="$root\_mt5_auto\reports\$rep.htm"; if(-not(Test-Path $h)){Write-Host "  [no report]";continue}
  $m=P $h; $rows+=[pscustomobject]@{sym=$sym;tf=$tf;window=$w.t;pf=$m['pf'];net=$m['net'];trades=$m['trades'];eqdd=$m['eqdd']}
  Write-Host ("   pf={0} n={1}" -f $m['pf'],$m['trades'])
  $rows|Export-Csv "$out.tmp" -NoTypeInformation -Encoding utf8; Move-Item -Force "$out.tmp" $out}}}
Write-Host "DONE $($rows.Count)"
