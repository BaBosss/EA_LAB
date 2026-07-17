# #1 TSD probe optimize on XAU (only home with MAIN>1). Sweep the signal-period lever
# (OsMA preset) + exit (RewardRisk) x both-window Model-4. >=3 levers before any kill.
$ErrorActionPreference='Continue'; $root='D:\EA_LAB'
$setDir="$root\_mt5_auto\ab_sets\osmawpr"; New-Item -ItemType Directory -Force $setDir | Out-Null
$out="$root\_mt5_auto\OSMAWPR_XAU_OPT.csv"
$presets=@(@{n='fast';f=6;s=13;g=5},@{n='def';f=12;s=26;g=9},@{n='slow';f=24;s=52;g=18})
$rrs=@('1.5','2.5'); $wprs=@('15','30')
$wins=@(@{t='MAIN';f='2023.01.01';to='2026.07.01'},@{t='BWD';f='2020.01.01';to='2023.01.01'})
function P($h){$x=(Get-Content $h -Raw)-replace'<[^>]+>','|';$p=($x-split'\|')|%{$_.Trim()}|?{$_};$o=@{};$k=@{'Total Net Profit:'='net';'Profit Factor:'='pf';'Total Trades:'='trades';'Equity Drawdown Maximal:'='eqdd'};for($i=0;$i-lt$p.Count-1;$i++){if($k.ContainsKey($p[$i])){$o[$k[$p[$i]]]=($p[$i+1]-replace'\s','')}};return $o}
$rows=@()
foreach($pp in $presets){foreach($rr in $rrs){foreach($wp in $wprs){
  $sp=Join-Path $setDir ("OW_{0}_rr{1}_w{2}.set" -f $pp.n,($rr -replace '\.',''),$wp)
  @("OsmaFast=$($pp.f)","OsmaSlow=$($pp.s)","OsmaSignal=$($pp.g)","WprPeriod=14","WprMax=$wp","RewardRisk=$rr","FixedLot=0.10","MagicNo=999095") | Set-Content $sp -Encoding utf8
  foreach($w in $wins){$rep="OWX_{0}_rr{1}_w{2}_{3}" -f $pp.n,($rr -replace '\.',''),$wp,$w.t; Write-Host ">> $rep"
    try{& "$root\scripts\mt5_run.ps1" -Expert '(EXP)_OsmaWpr_Naked_rev00' -Symbol XAUUSD -Period H4 -FromDate $w.f -ToDate $w.to -Model 4 -ReportName $rep -SetFile $sp | Out-Null}catch{Write-Host "  ERR"}
    $h="$root\_mt5_auto\reports\$rep.htm"; if(-not(Test-Path $h)){Write-Host "  [no report]";continue}
    $m=P $h; $rows+=[pscustomobject]@{preset=$pp.n;rr=$rr;wpr=$wp;window=$w.t;pf=$m['pf'];net=$m['net'];trades=$m['trades'];eqdd=$m['eqdd']}
    Write-Host ("   pf={0} n={1} dd={2}" -f $m['pf'],$m['trades'],$m['eqdd'])
    $rows|Export-Csv "$out.tmp" -NoTypeInformation -Encoding utf8; Move-Item -Force "$out.tmp" $out}}}}
Write-Host "DONE $($rows.Count)"
