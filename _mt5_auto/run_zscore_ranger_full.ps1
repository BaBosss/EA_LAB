$ErrorActionPreference='Continue'; $root='D:\EA_LAB'
$base="$root\_mt5_auto\ab_sets\rescue1_sets\ZSCORE_default.set"
$setDir="$root\_mt5_auto\ab_sets\zscore_sets"; $out="$root\_mt5_auto\ZSCORE_RESCUE_RANGER.csv"
$pairs=@('AUDNZD','EURGBP','EURCHF'); $tfs=@('H4','H1'); $thrs=@('2.0','2.5','3.0')
$wins=@(@{t='MAIN';f='2023.01.01';to='2026.07.01'},@{t='BWD';f='2020.01.01';to='2023.01.01'})
function P($h){$x=(Get-Content $h -Raw)-replace'<[^>]+>','|';$p=($x-split'\|')|%{$_.Trim()}|?{$_};$o=@{};$k=@{'Total Net Profit:'='net';'Profit Factor:'='pf';'Total Trades:'='trades';'Equity Drawdown Maximal:'='eqdd'};for($i=0;$i-lt$p.Count-1;$i++){if($k.ContainsKey($p[$i])){$o[$k[$p[$i]]]=($p[$i+1]-replace'\s','')}};return $o}
$rows=@()
foreach($pr in $pairs){foreach($tf in $tfs){foreach($thr in $thrs){
  $sp=Join-Path $setDir ("ZR_{0}_{1}_t{2}.set" -f $pr,$tf,$thr)
  $ct=Get-Content $base | Where-Object {$_ -notmatch '_01_ZThreshold'}; $ct+="_01_ZThreshold=$thr"; Set-Content $sp $ct -Encoding utf8
  foreach($w in $wins){$rep="ZR_{0}_{1}_t{2}_{3}" -f $pr,$tf,$thr,$w.t;Write-Host ">> $rep"
    try{& "$root\scripts\mt5_run.ps1" -Expert 'EA_ZSCORE' -Symbol $pr -Period $tf -FromDate $w.f -ToDate $w.to -Model 1 -ReportName $rep -SetFile $sp|Out-Null}catch{Write-Host "  ERR"}
    $h="$root\_mt5_auto\reports\$rep.htm";if(-not(Test-Path $h)){Write-Host "  [no report/skip]";continue}
    $m=P $h;$rows+=[pscustomobject]@{pair=$pr;tf=$tf;threshold=$thr;window=$w.t;pf=$m['pf'];net=$m['net'];trades=$m['trades'];eqdd=$m['eqdd']}
    Write-Host ("   pf={0} net={1} n={2}" -f $m['pf'],$m['net'],$m['trades'])}}}}
$rows|Export-Csv $out -NoTypeInformation -Encoding utf8;Write-Host "DONE $($rows.Count) rows"
