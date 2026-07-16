# ORDER-112 ICHIMOKU rescue — year-by-year holdout on the 2 both-window >=1.2 candidates.
# Purpose: kill the "USDJPY 2022-bull carried it" artifact. all-years-positive = real edge
# (same validation GBPJPY leg-8 passed, user-approved). Model-4.
$ErrorActionPreference='Continue'; $root='D:\EA_LAB'
$setDir="$root\_mt5_auto\ab_sets\ichi_kumo"; $out="$root\_mt5_auto\ICHI_YEARSPLIT.csv"
$sym='USDJPY'
$cands=@(
  @{n='medH4'; tf='H4'; t=12; k=34; s=68},
  @{n='slowH1';tf='H1'; t=20; k=60; s=120}
)
$years=@('2020','2021','2022','2023','2024','2025')
function P($h){$x=(Get-Content $h -Raw)-replace'<[^>]+>','|';$p=($x-split'\|')|%{$_.Trim()}|?{$_};$o=@{};$k=@{'Total Net Profit:'='net';'Profit Factor:'='pf';'Total Trades:'='trades';'Equity Drawdown Maximal:'='eqdd'};for($i=0;$i-lt$p.Count-1;$i++){if($k.ContainsKey($p[$i])){$o[$k[$p[$i]]]=($p[$i+1]-replace'\s','')}};return $o}
$rows=@()
foreach($c in $cands){
  $sp=Join-Path $setDir ("YS_{0}.set" -f $c.n)
  @("TenkanPeriod=$($c.t)","KijunPeriod=$($c.k)","SenkouPeriod=$($c.s)","AdxMin=20.0","ExitMode=2","SlAtrMult=2.0","TrailAtrMult=2.5","FixedLot=0.10","MagicNo=990066") | Set-Content $sp -Encoding utf8
  foreach($y in $years){ $f="$y.01.01"; $to="$([int]$y+1).01.01"; $rep="YS_{0}_{1}" -f $c.n,$y; Write-Host ">> $rep"
    try{& "$root\scripts\mt5_run.ps1" -Expert '(EXP)_IchiADX_Naked_rev00' -Symbol $sym -Period $c.tf -FromDate $f -ToDate $to -Model 4 -ReportName $rep -SetFile $sp | Out-Null}catch{Write-Host "  ERR $_"}
    $h="$root\_mt5_auto\reports\$rep.htm"; if(-not(Test-Path $h)){Write-Host "  [no report]"; continue}
    $m=P $h; $rows+=[pscustomobject]@{cand=$c.n;tf=$c.tf;year=$y;pf=$m['pf'];net=$m['net'];trades=$m['trades'];eqdd=$m['eqdd']}
    Write-Host ("   pf={0} net={1} n={2}" -f $m['pf'],$m['net'],$m['trades'])}}
$rows|Export-Csv $out -NoTypeInformation -Encoding utf8; Write-Host "DONE $($rows.Count) rows -> $out"
