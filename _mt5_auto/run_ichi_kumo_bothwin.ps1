# ORDER-112 ICHIMOKU rescue: sweep the UNTOUCHED core lever = Ichimoku/Kumo periods
# (Tenkan/Kijun/Senkou) x TF, BOTH windows, Model-4. Prior 2026-07-11 probe swept only
# ADX+exit+symbol on Model-2 recent-only -> USDJPY marginal 1.13-1.25 = not yet judgeable.
# Home = USDJPY (only survivor; momentum on JPY-trender). Isolate period lever: hold
# ExitMode=2 trail, AdxMin=20, SlAtrMult=2.0.
$ErrorActionPreference='Continue'; $root='D:\EA_LAB'
$setDir="$root\_mt5_auto\ab_sets\ichi_kumo"; New-Item -ItemType Directory -Force $setDir | Out-Null
$out="$root\_mt5_auto\ICHI_KUMO_BOTHWIN.csv"
$sym='USDJPY'; $tfs=@('H1','H4')
# coupled Ichimoku presets (Tenkan/Kijun/Senkou): fast / default / med / slow
$presets=@(
  @{n='fast';   t=6;  k=17; s=34},
  @{n='def';    t=9;  k=26; s=52},
  @{n='med';    t=12; k=34; s=68},
  @{n='slow';   t=20; k=60; s=120}
)
$wins=@(@{t='MAIN';f='2023.01.01';to='2026.07.01'},@{t='BWD';f='2020.01.01';to='2023.01.01'})
function P($h){$x=(Get-Content $h -Raw)-replace'<[^>]+>','|';$p=($x-split'\|')|%{$_.Trim()}|?{$_};$o=@{};$k=@{'Total Net Profit:'='net';'Profit Factor:'='pf';'Total Trades:'='trades';'Equity Drawdown Maximal:'='eqdd'};for($i=0;$i-lt$p.Count-1;$i++){if($k.ContainsKey($p[$i])){$o[$k[$p[$i]]]=($p[$i+1]-replace'\s','')}};return $o}
$rows=@()
foreach($pp in $presets){foreach($tf in $tfs){
  $sp=Join-Path $setDir ("KUMO_{0}_{1}.set" -f $pp.n,$tf)
  @("TenkanPeriod=$($pp.t)","KijunPeriod=$($pp.k)","SenkouPeriod=$($pp.s)","AdxMin=20.0","ExitMode=2","SlAtrMult=2.0","TrailAtrMult=2.5","FixedLot=0.10","MagicNo=990066") | Set-Content $sp -Encoding utf8
  foreach($w in $wins){$rep="KUMO_{0}_{1}_{2}" -f $pp.n,$tf,$w.t; Write-Host ">> $rep (T$($pp.t)/K$($pp.k)/S$($pp.s))"
    try{& "$root\scripts\mt5_run.ps1" -Expert '(EXP)_IchiADX_Naked_rev00' -Symbol $sym -Period $tf -FromDate $w.f -ToDate $w.to -Model 4 -ReportName $rep -SetFile $sp | Out-Null}catch{Write-Host "  ERR $_"}
    $h="$root\_mt5_auto\reports\$rep.htm"; if(-not(Test-Path $h)){Write-Host "  [no report/skip]"; continue}
    $m=P $h; $rows+=[pscustomobject]@{preset=$pp.n;tenkan=$pp.t;kijun=$pp.k;senkou=$pp.s;tf=$tf;window=$w.t;pf=$m['pf'];net=$m['net'];trades=$m['trades'];eqdd=$m['eqdd']}
    Write-Host ("   pf={0} net={1} n={2} dd={3}" -f $m['pf'],$m['net'],$m['trades'],$m['eqdd'])}}}
$rows|Export-Csv $out -NoTypeInformation -Encoding utf8; Write-Host "DONE $($rows.Count) rows -> $out"
