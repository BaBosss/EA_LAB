$ErrorActionPreference='Stop'; $root='D:\EA_LAB'
$setDir=Join-Path $root '_mt5_auto\ab_sets\zeus_regime'
$base=Join-Path $root 'ea_projects\(Boss)_ZeusInspired_GridLog\set_files\ZeusInspired_AUDJPY_lot8x.set'
$ea='(Boss)_ZeusInspired_GridLog_rev01'; $outCsv=Join-Path $root '_mt5_auto\ZEUS_AUDJPY_YEARSPLIT.csv'
# canonical candidate config = m1rng25 (plateau centre)
$cfg=@('_50_RegimeMode=1','_50_AllowRange=true','_50_AllowTrendUp=false','_50_AllowTrendDown=false','_50_ADX_TrendMin=25.0')
$sp=Join-Path $setDir 'ZYS_m1rng25.set'; $ct=Get-Content $base;$ct+='';$ct+='; yearsplit m1rng25';$ct+=$cfg;Set-Content $sp $ct -Encoding utf8
$years=@(
 @{y='2020';from='2020.01.01';to='2021.01.01'},@{y='2021';from='2021.01.01';to='2022.01.01'},
 @{y='2022';from='2022.01.01';to='2023.01.01'},@{y='2023';from='2023.01.01';to='2024.01.01'},
 @{y='2024';from='2024.01.01';to='2025.01.01'},@{y='2025';from='2025.01.01';to='2026.01.01'},
 @{y='2026';from='2026.01.01';to='2026.07.01'})
function P($h){$t=(Get-Content $h -Raw)-replace'<[^>]+>','|';$p=($t-split'\|')|%{$_.Trim()}|?{$_};$o=@{};$k=@{'Total Net Profit:'='net';'Profit Factor:'='pf';'Total Trades:'='trades';'Equity Drawdown Maximal:'='eqdd'};for($i=0;$i-lt$p.Count-1;$i++){if($k.ContainsKey($p[$i])){$o[$k[$p[$i]]]=($p[$i+1]-replace'\s','')}};return $o}
$rows=@()
foreach($yr in $years){$rep="ZYS_m1rng25_$($yr.y)";Write-Host ">> $rep";& (Join-Path $root 'scripts\mt5_run.ps1') -Expert $ea -Symbol AUDJPY -Period H1 -FromDate $yr.from -ToDate $yr.to -Model 4 -ReportName $rep -SetFile $sp|Out-Null;$h=Join-Path $root ("_mt5_auto\reports\{0}.htm" -f $rep);if(-not(Test-Path $h)){Write-Host "[FAIL] $rep";continue};$m=P $h;$rows+=[pscustomobject]@{year=$yr.y;net=$m['net'];pf=$m['pf'];trades=$m['trades'];eqdd=$m['eqdd']};Write-Host ("   net={0} pf={1} n={2}" -f $m['net'],$m['pf'],$m['trades'])}
$rows|Export-Csv $outCsv -NoTypeInformation -Encoding utf8;Write-Host "DONE -> $outCsv"
