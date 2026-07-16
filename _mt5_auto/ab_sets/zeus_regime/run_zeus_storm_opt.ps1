$ErrorActionPreference='Stop'; $root='D:\EA_LAB'
$setDir=Join-Path $root '_mt5_auto\ab_sets\zeus_regime'
$base=Join-Path $root 'ea_projects\(Boss)_ZeusInspired_GridLog\set_files\ZeusInspired_AUDJPY_lot8x.set'
$ea='(Boss)_ZeusInspired_GridLog_rev01'; $outCsv=Join-Path $root '_mt5_auto\ZEUS_AUDJPY_STORM.csv'
# m1rng25 base + storm sweep (default was 2.0). Test if tighter storm cuts the 2023 trend-year loss.
$storms=[ordered]@{ 's0'='0.0'; 's15'='1.5'; 's25'='2.5' }
$wins=@(@{t='MAIN';f='2023.01.01';to='2026.07.01'},@{t='BWD';f='2020.01.01';to='2023.01.01'},@{t='Y2023';f='2023.01.01';to='2024.01.01'})
function P($h){$x=(Get-Content $h -Raw)-replace'<[^>]+>','|';$p=($x-split'\|')|%{$_.Trim()}|?{$_};$o=@{};$k=@{'Total Net Profit:'='net';'Profit Factor:'='pf';'Total Trades:'='trades';'Equity Drawdown Maximal:'='eqdd'};for($i=0;$i-lt$p.Count-1;$i++){if($k.ContainsKey($p[$i])){$o[$k[$p[$i]]]=($p[$i+1]-replace'\s','')}};return $o}
$rows=@()
foreach($s in $storms.Keys){
 $cfg=@('_50_RegimeMode=1','_50_AllowRange=true','_50_AllowTrendUp=false','_50_AllowTrendDown=false','_50_ADX_TrendMin=25.0',"_50_StormATRmult=$($storms[$s])")
 $sp=Join-Path $setDir ("ZST_{0}.set" -f $s);$ct=Get-Content $base;$ct+='';$ct+='; storm '+$s;$ct+=$cfg;Set-Content $sp $ct -Encoding utf8
 foreach($w in $wins){$rep="ZST_{0}_{1}" -f $s,$w.t;Write-Host ">> $rep";& "$root\scripts\mt5_run.ps1" -Expert $ea -Symbol AUDJPY -Period H1 -FromDate $w.f -ToDate $w.to -Model 4 -ReportName $rep -SetFile $sp|Out-Null;$h="$root\_mt5_auto\reports\$rep.htm";if(-not(Test-Path $h)){Write-Host "[FAIL] $rep";continue};$m=P $h;$rows+=[pscustomobject]@{storm=$storms[$s];window=$w.t;net=$m['net'];pf=$m['pf'];trades=$m['trades'];eqdd=$m['eqdd']};Write-Host ("   net={0} pf={1} n={2}" -f $m['net'],$m['pf'],$m['trades'])}}
$rows|Export-Csv $outCsv -NoTypeInformation -Encoding utf8;Write-Host "DONE -> $outCsv"
