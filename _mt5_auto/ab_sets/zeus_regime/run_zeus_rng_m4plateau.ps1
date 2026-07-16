$ErrorActionPreference='Stop'; $root='D:\EA_LAB'
$setDir=Join-Path $root '_mt5_auto\ab_sets\zeus_regime'
$base=Join-Path $root 'ea_projects\(Boss)_ZeusInspired_GridLog\set_files\ZeusInspired_AUDJPY_lot8x.set'
$ea='(Boss)_ZeusInspired_GridLog_rev01'; $outCsv=Join-Path $root '_mt5_auto\ZEUS_AUDJPY_M4PLATEAU.csv'
$windows=@(@{tag='MAIN';from='2023.01.01';to='2026.07.01'},@{tag='BWD';from='2020.01.01';to='2023.01.01'})
$cfgs=[ordered]@{
 'm1rng20'=@('_50_RegimeMode=1','_50_AllowRange=true','_50_AllowTrendUp=false','_50_AllowTrendDown=false','_50_ADX_TrendMin=20.0')
 'm1rng30'=@('_50_RegimeMode=1','_50_AllowRange=true','_50_AllowTrendUp=false','_50_AllowTrendDown=false','_50_ADX_TrendMin=30.0')
}
function P($h){$t=(Get-Content $h -Raw)-replace'<[^>]+>','|';$p=($t-split'\|')|%{$_.Trim()}|?{$_};$o=@{};$k=@{'Total Net Profit:'='net';'Profit Factor:'='pf';'Total Trades:'='trades';'Equity Drawdown Maximal:'='eqdd'};for($i=0;$i-lt$p.Count-1;$i++){if($k.ContainsKey($p[$i])){$o[$k[$p[$i]]]=($p[$i+1]-replace'\s','')}};return $o}
$rows=@()
foreach($c in $cfgs.Keys){$sp=Join-Path $setDir ("ZM4_{0}.set" -f $c);$ct=Get-Content $base;$ct+='';$ct+='; m4plateau '+$c;$ct+=$cfgs[$c];Set-Content $sp $ct -Encoding utf8
 foreach($w in $windows){$rep="ZM4_{0}_{1}" -f $c,$w.tag;Write-Host ">> $rep";& (Join-Path $root 'scripts\mt5_run.ps1') -Expert $ea -Symbol AUDJPY -Period H1 -FromDate $w.from -ToDate $w.to -Model 4 -ReportName $rep -SetFile $sp|Out-Null;$h=Join-Path $root ("_mt5_auto\reports\{0}.htm" -f $rep);if(-not(Test-Path $h)){Write-Host "[FAIL] $rep";continue};$m=P $h;$rows+=[pscustomobject]@{config=$c;window=$w.tag;net=$m['net'];pf=$m['pf'];trades=$m['trades'];eqdd=$m['eqdd']};Write-Host ("   net={0} pf={1} n={2}" -f $m['net'],$m['pf'],$m['trades'])}}
$rows|Export-Csv $outCsv -NoTypeInformation -Encoding utf8;Write-Host "DONE -> $outCsv"
