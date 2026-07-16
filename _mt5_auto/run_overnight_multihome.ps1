# OVERNIGHT Phase 1 — additive-leg hunt: multi-home the naked single-config validated EAs
# (method that just found the XAU IchiADX leg). both-window Model-4. Judge in the morning.
# MacdDiv_Naked (momentum divergence, XAU-only) + Boss_17_Wave5 (VWAP wave, XAU/XAG-only)
# -> untested trending homes. Deterministic, overnight-safe (per-run try/catch, atomic CSV).
$ErrorActionPreference='Continue'; $root='D:\EA_LAB'
$out="$root\_mt5_auto\OVERNIGHT_MULTIHOME.csv"; $log="$root\_mt5_auto\OVERNIGHT_MH.log"
"[start $(Get-Date -f o)]" | Set-Content $log
$wins=@(@{t='MAIN';f='2023.01.01';to='2026.07.01'},@{t='BWD';f='2020.01.01';to='2023.01.01'})
function P($h){$x=(Get-Content $h -Raw)-replace'<[^>]+>','|';$p=($x-split'\|')|%{$_.Trim()}|?{$_};$o=@{};$k=@{'Total Net Profit:'='net';'Profit Factor:'='pf';'Total Trades:'='trades';'Equity Drawdown Maximal:'='eqdd'};for($i=0;$i-lt$p.Count-1;$i++){if($k.ContainsKey($p[$i])){$o[$k[$p[$i]]]=($p[$i+1]-replace'\s','')}};return $o}
# EA, Expert, set, TF, symbol universe (trending homes; XAU/XAG = reference cells)
$jobs=@(
  @{ea='MacdDiv'; exp='MacdDiv_Naked'; tf='H4'; set="$root\_vps_deploy\MACDDIV_XAU\MacdDiv_XAU_H4_demo_v1.set"; syms=@('XAUUSD','XAGUSD','GBPJPY','EURJPY','USDJPY','US30')},
  @{ea='Wave5';   exp='Boss_17_Wave5'; tf='H1'; set="$root\_vps_deploy\WAVE5_XAU\WAVE5_XAU_H1_demo_v1.set"; syms=@('XAUUSD','XAGUSD','USDJPY','GBPJPY','US30')}
)
$rows=@()
foreach($j in $jobs){ foreach($sym in $j.syms){ foreach($w in $wins){
  $rep="ON_{0}_{1}_{2}" -f $j.ea,$sym,$w.t; "[run $(Get-Date -f o)] $rep" | Add-Content $log
  try{& "$root\scripts\mt5_run.ps1" -Expert $j.exp -Symbol $sym -Period $j.tf -FromDate $w.f -ToDate $w.to -Model 4 -ReportName $rep -SetFile $j.set | Out-Null}catch{ "  ERR $_" | Add-Content $log }
  $h="$root\_mt5_auto\reports\$rep.htm"; if(-not(Test-Path $h)){ "  [no report]" | Add-Content $log; continue }
  $m=P $h; $rows+=[pscustomobject]@{ea=$j.ea;sym=$sym;tf=$j.tf;window=$w.t;pf=$m['pf'];net=$m['net'];trades=$m['trades'];eqdd=$m['eqdd']}
  ("  pf={0} n={1}" -f $m['pf'],$m['trades']) | Add-Content $log
  # atomic incremental save so morning has partial results even if interrupted
  $rows | Export-Csv "$out.tmp" -NoTypeInformation -Encoding utf8; Move-Item -Force "$out.tmp" $out
}}}
"[done $(Get-Date -f o)] $($rows.Count) rows" | Add-Content $log
Write-Host "DONE $($rows.Count) rows -> $out"
