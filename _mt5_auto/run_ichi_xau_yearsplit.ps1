# ORDER-112D: XAUUSD Ichimoku (med + slow periods) surfaced both-window >=1.2 in multi-home
# sweep, overturning the default-period "XAU ceiling 1.13". Year-split to test whether the
# strong MAIN (medH4 3.94) is 2023-26 gold-bull carry or a durable all-years edge. Model-4.
$ErrorActionPreference='Continue'; $root='D:\EA_LAB'
$setDir="$root\_mt5_auto\ab_sets\ichi_kumo"; $out="$root\_mt5_auto\ICHI_XAU_YEARSPLIT.csv"
$cands=@(
  @{n='medH4'; tf='H4'; set='KUMO_med_H4.set'},
  @{n='slowH1';tf='H1'; set='KUMO_slow_H1.set'}
)
$years=@('2020','2021','2022','2023','2024','2025')
function P($h){$x=(Get-Content $h -Raw)-replace'<[^>]+>','|';$p=($x-split'\|')|%{$_.Trim()}|?{$_};$o=@{};$k=@{'Total Net Profit:'='net';'Profit Factor:'='pf';'Total Trades:'='trades';'Equity Drawdown Maximal:'='eqdd'};for($i=0;$i-lt$p.Count-1;$i++){if($k.ContainsKey($p[$i])){$o[$k[$p[$i]]]=($p[$i+1]-replace'\s','')}};return $o}
$rows=@()
foreach($c in $cands){$sp=Join-Path $setDir $c.set
  foreach($y in $years){ $f="$y.01.01"; $to="$([int]$y+1).01.01"; $rep="XAUYS_{0}_{1}" -f $c.n,$y; Write-Host ">> $rep"
    try{& "$root\scripts\mt5_run.ps1" -Expert '(EXP)_IchiADX_Naked_rev00' -Symbol XAUUSD -Period $c.tf -FromDate $f -ToDate $to -Model 4 -ReportName $rep -SetFile $sp | Out-Null}catch{Write-Host "  ERR $_"}
    $h="$root\_mt5_auto\reports\$rep.htm"; if(-not(Test-Path $h)){Write-Host "  [no report]"; continue}
    $m=P $h; $rows+=[pscustomobject]@{cand=$c.n;year=$y;pf=$m['pf'];net=$m['net'];trades=$m['trades'];eqdd=$m['eqdd']}
    Write-Host ("   pf={0} net={1} n={2}" -f $m['pf'],$m['net'],$m['trades'])}}
$rows|Export-Csv $out -NoTypeInformation -Encoding utf8; Write-Host "DONE $($rows.Count) rows"
