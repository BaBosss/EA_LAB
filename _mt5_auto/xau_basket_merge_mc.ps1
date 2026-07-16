# XAU Ichimoku basket: merge medH4 (CORR_ICHI_XAU_medH4) + slowH1 (CORR_ICHI_XAU) deal lists
# -> true combined equity, max-DD, MC bootstrap. (space-thousands-aware.)
$ErrorActionPreference='Stop'; $rp='D:\EA_LAB\_mt5_auto\reports'
function Get-Trades($f){
  $raw=[IO.File]::ReadAllText("$rp\$f.htm",[Text.Encoding]::Unicode)
  $out=@()
  foreach($m in [regex]::Matches($raw,'<tr[^>]*>(.*?)</tr>','Singleline')){
    $cells=[regex]::Matches($m.Groups[1].Value,'<td[^>]*>(.*?)</td>','Singleline') | %{ ($_.Groups[1].Value -replace '<[^>]+>','').Trim() }
    if($cells.Count -lt 12){continue}; if($cells[4] -ne 'out'){continue}
    $out+=[pscustomobject]@{t=[datetime]::ParseExact($cells[0],'yyyy.MM.dd HH:mm:ss',$null); p=[double](($cells[10]) -replace '[\s ,]','')}
  }
  return $out
}
$a=Get-Trades 'CORR_ICHI_XAU_medH4'; $b=Get-Trades 'CORR_ICHI_XAU'
Write-Host ("medH4 n=$($a.Count) net=$([math]::Round(($a|Measure-Object p -Sum).Sum,0)) | slowH1 n=$($b.Count) net=$([math]::Round(($b|Measure-Object p -Sum).Sum,0))")
$all=@($a)+@($b) | Sort-Object t
$eq=10000.0;$peak=$eq;$maxdd=0.0;$gp=0.0;$gl=0.0
foreach($tr in $all){$eq+=$tr.p; if($tr.p-gt0){$gp+=$tr.p}else{$gl+=[math]::Abs($tr.p)}; if($eq-gt$peak){$peak=$eq}; $dd=($peak-$eq)/$peak*100; if($dd-gt$maxdd){$maxdd=$dd}}
Write-Host ("COMBINED XAU basket: n=$($all.Count) PF=$([math]::Round($gp/$gl,3)) net=$([math]::Round($eq-10000,0)) maxDD=$([math]::Round($maxdd,2))%")
$profits=$all|%{$_.p}; $N=$profits.Count; $iter=2000; $pfs=@();$dds=@();$ruin=0; $rng=New-Object System.Random(777)
for($k=0;$k-lt$iter;$k++){$e=10000.0;$pk=$e;$mdd=0.0;$g=0.0;$l=0.0
  for($j=0;$j-lt$N;$j++){$p=$profits[$rng.Next($N)];$e+=$p; if($p-gt0){$g+=$p}else{$l+=[math]::Abs($p)}; if($e-gt$pk){$pk=$e}; $d=($pk-$e)/$pk*100; if($d-gt$mdd){$mdd=$d}}
  $ipf=99.0; if($l-gt0){$ipf=$g/$l}; $pfs+=$ipf;$dds+=$mdd; if($mdd-ge30){$ruin++}}
$ps=$pfs|Sort-Object; $ds=$dds|Sort-Object
Write-Host ("MC (n=$iter N=$N): PF_5th=$([math]::Round($ps[[int]($iter*0.05)],3)) DD_95th=$([math]::Round($ds[[int]($iter*0.95)],2))% Ruin=$([math]::Round($ruin/$iter*100,2))%")
