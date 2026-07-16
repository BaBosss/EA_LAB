# Phase 3: Wave5 USDJPY year-split (the one new both-window home from Phase 1). Model-4.
$ErrorActionPreference='Continue'; $root='D:\EA_LAB'
$out="$root\_mt5_auto\WAVE5_USDJPY_YS.csv"; $set="$root\_vps_deploy\WAVE5_XAU\WAVE5_XAU_H1_demo_v1.set"
$years=@('2020','2021','2022','2023','2024','2025')
function P($h){$x=(Get-Content $h -Raw)-replace'<[^>]+>','|';$p=($x-split'\|')|%{$_.Trim()}|?{$_};$o=@{};$k=@{'Total Net Profit:'='net';'Profit Factor:'='pf';'Total Trades:'='trades'};for($i=0;$i-lt$p.Count-1;$i++){if($k.ContainsKey($p[$i])){$o[$k[$p[$i]]]=($p[$i+1]-replace'\s','')}};return $o}
$rows=@()
foreach($y in $years){ $f="$y.01.01"; $to="$([int]$y+1).01.01"; $rep="W5YS_USDJPY_$y"; Write-Host ">> $rep"
  try{& "$root\scripts\mt5_run.ps1" -Expert 'Boss_17_Wave5' -Symbol USDJPY -Period H1 -FromDate $f -ToDate $to -Model 4 -ReportName $rep -SetFile $set | Out-Null}catch{Write-Host "  ERR"}
  $h="$root\_mt5_auto\reports\$rep.htm"; if(-not(Test-Path $h)){Write-Host "  [no report]";continue}
  $m=P $h; $rows+=[pscustomobject]@{year=$y;pf=$m['pf'];net=$m['net'];trades=$m['trades']}
  Write-Host ("   pf={0} net={1} n={2}" -f $m['pf'],$m['net'],$m['trades'])}
$rows|Export-Csv $out -NoTypeInformation -Encoding utf8; Write-Host "DONE"
