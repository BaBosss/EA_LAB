# #2 Wave5 USDJPY optimize — sweep entry levers (EntryFib x Wave3MinMult) x both-window Model-4.
# Base thin edge = 1.12/1.50; goal = lift it or confirm capped.
$ErrorActionPreference='Continue'; $root='D:\EA_LAB'
$setDir="$root\_mt5_auto\ab_sets\wave5_uj"; New-Item -ItemType Directory -Force $setDir | Out-Null
$out="$root\_mt5_auto\WAVE5_UJ_OPT.csv"
$fibs=@('23.6','38.2','50.0'); $w3=@('0.618','1.0','1.618')
$wins=@(@{t='MAIN';f='2023.01.01';to='2026.07.01'},@{t='BWD';f='2020.01.01';to='2023.01.01'})
function P($h){$x=(Get-Content $h -Raw)-replace'<[^>]+>','|';$p=($x-split'\|')|%{$_.Trim()}|?{$_};$o=@{};$k=@{'Total Net Profit:'='net';'Profit Factor:'='pf';'Total Trades:'='trades';'Equity Drawdown Maximal:'='eqdd'};for($i=0;$i-lt$p.Count-1;$i++){if($k.ContainsKey($p[$i])){$o[$k[$p[$i]]]=($p[$i+1]-replace'\s','')}};return $o}
$rows=@()
foreach($fib in $fibs){foreach($m3 in $w3){
  $sp=Join-Path $setDir ("W5_f{0}_m{1}.set" -f ($fib -replace '\.',''),($m3 -replace '\.',''))
  @("ExitMode=23","_9_MaxLevels=1","_23_TrailStart=2000","_23_TrailStep=800","_17_UseStructLevels=true","_17_DivergTrail=true","_17_EntryFib=$fib","_17_Wave3MinMult=$m3","_0_Magic=990301") | Set-Content $sp -Encoding utf8
  foreach($w in $wins){$rep="W5OPT_f{0}_m{1}_{2}" -f ($fib -replace '\.',''),($m3 -replace '\.',''),$w.t; Write-Host ">> $rep"
    try{& "$root\scripts\mt5_run.ps1" -Expert 'Boss_17_Wave5' -Symbol USDJPY -Period H1 -FromDate $w.f -ToDate $w.to -Model 4 -ReportName $rep -SetFile $sp | Out-Null}catch{Write-Host "  ERR"}
    $h="$root\_mt5_auto\reports\$rep.htm"; if(-not(Test-Path $h)){Write-Host "  [no report]";continue}
    $m=P $h; $rows+=[pscustomobject]@{fib=$fib;wave3=$m3;window=$w.t;pf=$m['pf'];net=$m['net'];trades=$m['trades'];eqdd=$m['eqdd']}
    Write-Host ("   pf={0} net={1} n={2}" -f $m['pf'],$m['net'],$m['trades'])}}}
$rows|Export-Csv $out -NoTypeInformation -Encoding utf8; Write-Host "DONE $($rows.Count)"
