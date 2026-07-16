$ErrorActionPreference='Stop'; $root='D:\EA_LAB'
$set="$root\_vps_deploy\BOSS14_GBPJPY\Boss14_GridLog_GBPJPY_H4_demo_leg8.set"
$out="$root\_mt5_auto\GBPJPY_YEARSPLIT.csv"
$years=@(
 @{y='2020';f='2020.01.01';to='2021.01.01'},@{y='2021';f='2021.01.01';to='2022.01.01'},
 @{y='2022';f='2022.01.01';to='2023.01.01'},@{y='2023';f='2023.01.01';to='2024.01.01'},
 @{y='2024';f='2024.01.01';to='2025.01.01'},@{y='2025';f='2025.01.01';to='2026.01.01'},
 @{y='2026';f='2026.01.01';to='2026.07.01'})
function P($h){$x=(Get-Content $h -Raw)-replace'<[^>]+>','|';$p=($x-split'\|')|%{$_.Trim()}|?{$_};$o=@{};$k=@{'Total Net Profit:'='net';'Profit Factor:'='pf';'Total Trades:'='trades'};for($i=0;$i-lt$p.Count-1;$i++){if($k.ContainsKey($p[$i])){$o[$k[$p[$i]]]=($p[$i+1]-replace'\s','')}};return $o}
$rows=@()
foreach($yr in $years){$rep="GJYS_$($yr.y)";Write-Host ">> $rep";& "$root\scripts\mt5_run.ps1" -Expert 'EALabTpl\Boss_14_GridLog' -Symbol GBPJPY -Period H4 -FromDate $yr.f -ToDate $yr.to -Model 4 -ReportName $rep -SetFile $set|Out-Null;$h="$root\_mt5_auto\reports\$rep.htm";if(-not(Test-Path $h)){Write-Host "[FAIL] $rep";continue};$m=P $h;$rows+=[pscustomobject]@{year=$yr.y;net=$m['net'];pf=$m['pf'];trades=$m['trades']};Write-Host ("   net={0} pf={1} n={2}" -f $m['net'],$m['pf'],$m['trades'])}
$rows|Export-Csv $out -NoTypeInformation -Encoding utf8;Write-Host "DONE"
