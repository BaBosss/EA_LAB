# ORDER-112B: merge med-H4 + slow-H1 deal lists into ONE equity curve -> true combined
# max-DD, then MC bootstrap on the combined per-trade P&L sequence.
$ErrorActionPreference='Stop'; $rp='D:\EA_LAB\_mt5_auto\reports'
function Get-Trades($f){
  $raw=[IO.File]::ReadAllText("$rp\$f.htm",[Text.Encoding]::Unicode)
  $rows=[regex]::Matches($raw,'<tr[^>]*>(.*?)</tr>','Singleline')
  $out=@()
  foreach($m in $rows){
    $cells=[regex]::Matches($m.Groups[1].Value,'<td[^>]*>(.*?)</td>','Singleline') | %{ ($_.Groups[1].Value -replace '<[^>]+>','').Trim() }
    if($cells.Count -lt 12){continue}
    if($cells[4] -ne 'out'){continue}
    $t=$cells[0]; $profit=[double](($cells[10]) -replace '[\s ,]','')  # profit col, strip space-thousands
    $dt=[datetime]::ParseExact($t,'yyyy.MM.dd HH:mm:ss',$null)
    $out+=[pscustomobject]@{t=$dt; p=$profit}
  }
  return $out
}
$a=Get-Trades 'BASKET_medH4_FULL'; $b=Get-Trades 'BASKET_slowH1_FULL'
Write-Host ("medH4 trades=$($a.Count) net=$([math]::Round(($a|Measure-Object p -Sum).Sum,1)) | slowH1 trades=$($b.Count) net=$([math]::Round(($b|Measure-Object p -Sum).Sum,1))")
$all=@($a)+@($b) | Sort-Object t
# combined equity + true max DD
$eq=10000.0; $peak=$eq; $maxdd=0.0; $gp=0.0; $gl=0.0
foreach($tr in $all){ $eq+=$tr.p; if($tr.p -gt 0){$gp+=$tr.p}else{$gl+=[math]::Abs($tr.p)}; if($eq -gt $peak){$peak=$eq}; $dd=($peak-$eq)/$peak*100; if($dd -gt $maxdd){$maxdd=$dd} }
$pf=[math]::Round($gp/$gl,3); $net=[math]::Round($eq-10000,1)
Write-Host ("`nCOMBINED (chronological merge, both @0.10 lot): trades=$($all.Count) PF=$pf net=$net maxDD=$([math]::Round($maxdd,2))%")
# MC bootstrap on combined per-trade P&L (resample-with-replacement, keep same N)
$profits=$all | %{ $_.p }
$N=$profits.Count; $iter=2000; $pfs=New-Object System.Collections.ArrayList; $dds=New-Object System.Collections.ArrayList; $ruin=0
$rng=New-Object System.Random(12345)
for($k=0;$k -lt $iter;$k++){
  $e=10000.0;$pk=$e;$mdd=0.0;$g=0.0;$l=0.0
  for($j=0;$j -lt $N;$j++){ $p=$profits[$rng.Next($N)]; $e+=$p; if($p -gt 0){$g+=$p}else{$l+=[math]::Abs($p)}; if($e -gt $pk){$pk=$e}; $d=($pk-$e)/$pk*100; if($d -gt $mdd){$mdd=$d} }
  $ipf=99.0; if($l -gt 0){$ipf=$g/$l}; [void]$pfs.Add([double]$ipf); [void]$dds.Add($mdd); if($mdd -ge 30){$ruin++}
}
$pfSorted=$pfs|Sort-Object; $ddSorted=$dds|Sort-Object
$pf5=[math]::Round($pfSorted[[int]($iter*0.05)],3); $dd95=[math]::Round($ddSorted[[int]($iter*0.95)],2)
Write-Host ("MC (n=$iter, N=$N): PF_5th=$pf5  DD_95th=$dd95%  Ruin(DD>=30%)=$([math]::Round($ruin/$iter*100,2))%")
