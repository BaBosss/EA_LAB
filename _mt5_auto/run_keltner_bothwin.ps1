# ORDER-113 KELTNER (#62) rescue: prior "DEAD 2026-06-27" = 4 sym x H4 x DEFAULT only,
# channel-def lever (EMAPeriod/KeltMult) + TF never swept. Mirror ICHIMOKU rescue:
# USDJPY (home where ICHIMOKU just revived) x channel presets x both-window Model-4.
# Isolate channel lever: hold TrendEMA200, AdxFilter off, SL2.0, Trail2.0 (TP=0=trail).
$ErrorActionPreference='Continue'; $root='D:\EA_LAB'
$setDir="$root\_mt5_auto\ab_sets\kelt_ch"; New-Item -ItemType Directory -Force $setDir | Out-Null
$out="$root\_mt5_auto\KELT_CH_BOTHWIN.csv"
$sym='USDJPY'; $tfs=@('H1','H4')
# coupled channel presets (EMAPeriod / KeltMult)
$presets=@(
  @{n='tight'; ema=10; mult='1.5'},
  @{n='def';   ema=20; mult='2.0'},
  @{n='mid';   ema=34; mult='2.5'},
  @{n='wide';  ema=50; mult='3.0'}
)
$wins=@(@{t='MAIN';f='2023.01.01';to='2026.07.01'},@{t='BWD';f='2020.01.01';to='2023.01.01'})
function P($h){$x=(Get-Content $h -Raw)-replace'<[^>]+>','|';$p=($x-split'\|')|%{$_.Trim()}|?{$_};$o=@{};$k=@{'Total Net Profit:'='net';'Profit Factor:'='pf';'Total Trades:'='trades';'Equity Drawdown Maximal:'='eqdd'};for($i=0;$i-lt$p.Count-1;$i++){if($k.ContainsKey($p[$i])){$o[$k[$p[$i]]]=($p[$i+1]-replace'\s','')}};return $o}
$rows=@()
foreach($pp in $presets){foreach($tf in $tfs){
  $sp=Join-Path $setDir ("KCH_{0}_{1}.set" -f $pp.n,$tf)
  @("_01_EMAPeriod=$($pp.ema)","_01_ATRPeriod=14","_01_KeltMult=$($pp.mult)","_01_TrendEMA=200","_02_SL_ATR_mult=2.0","_02_TP_ATR_mult=0.0","_03_UseAdxFilter=false","_04_TrailATR=2.0","_05_FixedLot=0.10","_06_Magic=990062") | Set-Content $sp -Encoding utf8
  foreach($w in $wins){$rep="KCH_{0}_{1}_{2}" -f $pp.n,$tf,$w.t; Write-Host ">> $rep (EMA$($pp.ema)/x$($pp.mult))"
    try{& "$root\scripts\mt5_run.ps1" -Expert 'EA_KELTNER' -Symbol $sym -Period $tf -FromDate $w.f -ToDate $w.to -Model 4 -ReportName $rep -SetFile $sp | Out-Null}catch{Write-Host "  ERR $_"}
    $h="$root\_mt5_auto\reports\$rep.htm"; if(-not(Test-Path $h)){Write-Host "  [no report]"; continue}
    $m=P $h; $rows+=[pscustomobject]@{preset=$pp.n;ema=$pp.ema;mult=$pp.mult;tf=$tf;window=$w.t;pf=$m['pf'];net=$m['net'];trades=$m['trades'];eqdd=$m['eqdd']}
    Write-Host ("   pf={0} net={1} n={2}" -f $m['pf'],$m['net'],$m['trades'])}}}
$rows|Export-Csv $out -NoTypeInformation -Encoding utf8; Write-Host "DONE $($rows.Count) rows -> $out"
