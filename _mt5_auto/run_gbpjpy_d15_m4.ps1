$ErrorActionPreference='Stop'; $root='D:\EA_LAB'
$set="$root\_mt5_auto\ab_sets\order106_fine\GJf_d1.5_tp150.set"
$out="$root\_mt5_auto\GBPJPY_D15_M4.csv"
$wins=@(@{t='MAIN';f='2023.01.01';to='2026.07.01'},@{t='BWD';f='2020.01.01';to='2023.01.01'})
function P($h){$x=(Get-Content $h -Raw)-replace'<[^>]+>','|';$p=($x-split'\|')|%{$_.Trim()}|?{$_};$o=@{};$k=@{'Total Net Profit:'='net';'Profit Factor:'='pf';'Total Trades:'='trades';'Equity Drawdown Maximal:'='eqdd'};for($i=0;$i-lt$p.Count-1;$i++){if($k.ContainsKey($p[$i])){$o[$k[$p[$i]]]=($p[$i+1]-replace'\s','')}};return $o}
$rows=@()
foreach($w in $wins){$rep="GJd15_M4_$($w.t)";Write-Host ">> $rep";& "$root\scripts\mt5_run.ps1" -Expert 'EALabTpl\Boss_14_GridLog' -Symbol GBPJPY -Period H4 -FromDate $w.f -ToDate $w.to -Model 4 -Deposit 10000 -Leverage 100 -SetFile $set -ReportName $rep|Out-Null;$h="$root\_mt5_auto\reports\$rep.htm";if(-not(Test-Path $h)){Write-Host "[FAIL] $rep";continue};$m=P $h;$rows+=[pscustomobject]@{window=$w.t;net=$m['net'];pf=$m['pf'];trades=$m['trades'];eqdd=$m['eqdd']};Write-Host ("   net={0} pf={1} n={2}" -f $m['net'],$m['pf'],$m['trades'])}
$rows|Export-Csv $out -NoTypeInformation -Encoding utf8;Write-Host "DONE -> $out"
