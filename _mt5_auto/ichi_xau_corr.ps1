# ORDER-112E: monthly-P&L Pearson, Ichimoku-XAU vs the XAU book (PowerShell version).
$rp='D:\EA_LAB\_mt5_auto\reports'
function Get-Monthly($rep){
  $p="$rp\$rep.htm"; $m=@{}
  if(-not(Test-Path $p)){return $m}
  $raw=[IO.File]::ReadAllText($p,[Text.Encoding]::Unicode)
  foreach($tr in [regex]::Matches($raw,'<tr[^>]*>(.*?)</tr>','Singleline')){
    $cells=[regex]::Matches($tr.Groups[1].Value,'<t[dh][^>]*>(.*?)</t[dh]>','Singleline') | %{ ($_.Groups[1].Value -replace '<[^>]+>','').Trim() }
    if($cells.Count -ne 13){continue}
    if($cells[4].ToLower() -ne 'out'){continue}
    $pr=($cells[10]) -replace '[\s ,]',''; $cm=($cells[8]) -replace '[\s ,]',''; $sw=($cells[9]) -replace '[\s ,]',''
    $v=0.0; if(-not [double]::TryParse($pr,[ref]$v)){continue}
    $cmv=0.0;[void][double]::TryParse($cm,[ref]$cmv); $swv=0.0;[void][double]::TryParse($sw,[ref]$swv)
    $mt=[regex]::Match($cells[0],'(\d{4})\.(\d{2})'); if(-not $mt.Success){continue}
    $ym="$($mt.Groups[1].Value)-$($mt.Groups[2].Value)"
    if(-not $m.ContainsKey($ym)){$m[$ym]=0.0}; $m[$ym]+=$v+$cmv+$swv
  }
  return $m
}
function Pearson($xs,$ys){ $n=$xs.Count; if($n -lt 4){return [double]::NaN}
  $mx=($xs|Measure-Object -Average).Average; $my=($ys|Measure-Object -Average).Average
  $nu=0.0;$dx=0.0;$dy=0.0; for($i=0;$i-lt$n;$i++){ $a=$xs[$i]-$mx;$b=$ys[$i]-$my; $nu+=$a*$b;$dx+=$a*$a;$dy+=$b*$b }
  if($dx -eq 0 -or $dy -eq 0){return [double]::NaN}; return $nu/([math]::Sqrt($dx)*[math]::Sqrt($dy)) }
$ichi=Get-Monthly 'CORR_ICHI_XAU'
Write-Host ("Ichimoku-XAU months={0} net={1:N0}`n" -f $ichi.Count,(($ichi.Values|Measure-Object -Sum).Sum))
Write-Host ("{0,-16}{1,10}{2,11}  {3}" -f 'vs','Pearson','shared','verdict')
Write-Host ('-'*60)
foreach($pair in @(@('CORR_BRK_XAU','BRK_XAU'),@('CORR_KAU_XAU','KAUFMAN_XAU'),@('CORR_ST_XAU','SuperTrend_XAU'))){
  $o=Get-Monthly $pair[0]
  $shared=@($ichi.Keys | Where-Object { $o.ContainsKey($_) } | Sort-Object)
  if($shared.Count -lt 4){ Write-Host ("{0,-16}{1,10}{2,11}  no data" -f $pair[1],'n/a',$shared.Count); continue }
  $xs=@($shared | %{ $ichi[$_] }); $ys=@($shared | %{ $o[$_] })
  $c=Pearson $xs $ys
  $v=if($c -lt 0.6){'LOW additive (<0.6)'}elseif($c -le 0.8){'reduce-lot (0.6-0.8)'}else{'HIGH redundant (>0.8)'}
  Write-Host ("{0,-16}{1,10:N3}{2,11}  {3}" -f $pair[1],$c,$shared.Count,$v)
}
