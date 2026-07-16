# Wave5 multi-home retry (Expert name fixed = Boss_17_Wave5, now in roaming).
$ErrorActionPreference='Continue'; $root='D:\EA_LAB'
$out="$root\_mt5_auto\WAVE5_MULTIHOME.csv"; $set="$root\_vps_deploy\WAVE5_XAU\WAVE5_XAU_H1_demo_v1.set"
$syms=@('XAUUSD','XAGUSD','USDJPY','GBPJPY','US30')
$wins=@(@{t='MAIN';f='2023.01.01';to='2026.07.01'},@{t='BWD';f='2020.01.01';to='2023.01.01'})
function P($h){$x=(Get-Content $h -Raw)-replace'<[^>]+>','|';$p=($x-split'\|')|%{$_.Trim()}|?{$_};$o=@{};$k=@{'Total Net Profit:'='net';'Profit Factor:'='pf';'Total Trades:'='trades';'Equity Drawdown Maximal:'='eqdd'};for($i=0;$i-lt$p.Count-1;$i++){if($k.ContainsKey($p[$i])){$o[$k[$p[$i]]]=($p[$i+1]-replace'\s','')}};return $o}
$rows=@()
foreach($sym in $syms){foreach($w in $wins){
  $rep="W5_{0}_{1}" -f $sym,$w.t; Write-Host ">> $rep"
  try{& "$root\scripts\mt5_run.ps1" -Expert 'Boss_17_Wave5' -Symbol $sym -Period H1 -FromDate $w.f -ToDate $w.to -Model 4 -ReportName $rep -SetFile $set | Out-Null}catch{Write-Host "  ERR"}
  $h="$root\_mt5_auto\reports\$rep.htm"; if(-not(Test-Path $h)){Write-Host "  [no report]";continue}
  $m=P $h; $rows+=[pscustomobject]@{sym=$sym;window=$w.t;pf=$m['pf'];net=$m['net'];trades=$m['trades'];eqdd=$m['eqdd']}
  Write-Host ("   pf={0} n={1}" -f $m['pf'],$m['trades'])}}
$rows|Export-Csv $out -NoTypeInformation -Encoding utf8; Write-Host "DONE $($rows.Count)"
