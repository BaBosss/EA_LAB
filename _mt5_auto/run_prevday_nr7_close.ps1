# ORDER-084 rescue-queue closer: NR7 (#105) + PREVDAY (#9/#30) — sweep their untouched lever
# x TF x both-window Model-4 on XAU (their best documented home). If XAU doesn't clear
# both-window >=1.2, they're validly dead (XAU was their strongest cell).
$ErrorActionPreference='Continue'; $root='D:\EA_LAB'
$setDir="$root\_mt5_auto\ab_sets\prevday_nr7"; New-Item -ItemType Directory -Force $setDir | Out-Null
$out="$root\_mt5_auto\PREVDAY_NR7_CLOSE.csv"
$wins=@(@{t='MAIN';f='2023.01.01';to='2026.07.01'},@{t='BWD';f='2020.01.01';to='2023.01.01'})
function P($h){$x=(Get-Content $h -Raw)-replace'<[^>]+>','|';$p=($x-split'\|')|%{$_.Trim()}|?{$_};$o=@{};$k=@{'Total Net Profit:'='net';'Profit Factor:'='pf';'Total Trades:'='trades';'Equity Drawdown Maximal:'='eqdd'};for($i=0;$i-lt$p.Count-1;$i++){if($k.ContainsKey($p[$i])){$o[$k[$p[$i]]]=($p[$i+1]-replace'\s','')}};return $o}
$rows=@()
# --- NR7: sweep NR_Period {4,7,10,14} ---
foreach($np in @(4,7,10,14)){foreach($tf in @('H1','H4')){
  $sp=Join-Path $setDir ("NR7_p{0}_{1}.set" -f $np,$tf)
  @("_01_NR_Period=$np","_01_ATRPeriod=14","_01_TrendEMA=200","_02_SL_ATR_mult=2.0","_02_TP_ATR_mult=0.0","_04_TrailATR=2.0","_05_FixedLot=0.10","_06_Magic=990080") | Set-Content $sp -Encoding utf8
  foreach($w in $wins){$rep="CLOSE_NR7_p{0}_{1}_{2}" -f $np,$tf,$w.t; Write-Host ">> $rep"
    try{& "$root\scripts\mt5_run.ps1" -Expert 'EA_NR7' -Symbol XAUUSD -Period $tf -FromDate $w.f -ToDate $w.to -Model 4 -ReportName $rep -SetFile $sp | Out-Null}catch{Write-Host "  ERR"}
    $h="$root\_mt5_auto\reports\$rep.htm"; if(-not(Test-Path $h)){Write-Host "  [no report]";continue}
    $m=P $h; $rows+=[pscustomobject]@{ea='NR7';lever="p$np";tf=$tf;window=$w.t;pf=$m['pf'];net=$m['net'];trades=$m['trades'];eqdd=$m['eqdd']}
    Write-Host ("   pf={0} n={1}" -f $m['pf'],$m['trades'])}}}
# --- PREVDAY: sweep BreakBuffer {0.1,0.3,0.5} ---
foreach($bb in @('0.1','0.3','0.5')){foreach($tf in @('H1','H4')){
  $sp=Join-Path $setDir ("PD_b{0}_{1}.set" -f ($bb -replace '\.',''),$tf)
  @("_01_BreakBuffer=$bb","_01_ATRPeriod=14","_02_SL_ATR_mult=1.5","_02_TP_ATR_mult=0.0","_03_UseEmaFilter=true","_03_EMAPeriod=200","_04_TrailATR=1.5","_05_FixedLot=0.10","_06_Magic=990050") | Set-Content $sp -Encoding utf8
  foreach($w in $wins){$rep="CLOSE_PD_b{0}_{1}_{2}" -f ($bb -replace '\.',''),$tf,$w.t; Write-Host ">> $rep"
    try{& "$root\scripts\mt5_run.ps1" -Expert 'EA_PREVDAY' -Symbol XAUUSD -Period $tf -FromDate $w.f -ToDate $w.to -Model 4 -ReportName $rep -SetFile $sp | Out-Null}catch{Write-Host "  ERR"}
    $h="$root\_mt5_auto\reports\$rep.htm"; if(-not(Test-Path $h)){Write-Host "  [no report]";continue}
    $m=P $h; $rows+=[pscustomobject]@{ea='PREVDAY';lever="b$bb";tf=$tf;window=$w.t;pf=$m['pf'];net=$m['net'];trades=$m['trades'];eqdd=$m['eqdd']}
    Write-Host ("   pf={0} n={1}" -f $m['pf'],$m['trades'])}}}
$rows|Export-Csv $out -NoTypeInformation -Encoding utf8; Write-Host "DONE $($rows.Count) rows"
