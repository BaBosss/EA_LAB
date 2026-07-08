# mt4_martingale_recheck.ps1 — RECHECK (not re-test) a rejected escalation EA before
# discarding it. User point 2026-07-08: "martingale ไม่ผิดเสมอ — เช็ค SL / capped steps /
# entry-edge / ดื้อไหม ก่อนปล่อยทิ้ง". Pulls everything from an EXISTING MT4 report:
#   - base lot (mode) + max lot + ratio        (escalation depth)
#   - step law: doubles (~x2 = martingale) vs adds fixed (linear) vs geometric-mild
#   - SL present? (fraction of entries with a non-zero S/L)
#   - max concurrent open positions            (is depth actually capped?)
# => classifies STRUCTURAL-ruin vs CAPPED/SL'd (worth a real .set sweep before reject).
param([Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)][Alias('FullName')][string]$Report)
process{
  if(-not(Test-Path -LiteralPath $Report)){ Write-Output "$Report : MISSING"; return }
  $c = Get-Content -LiteralPath $Report -Raw
  $trs = [regex]::Matches($c,'<tr bgcolor[^>]*>(.*?)</tr>','Singleline')
  $sizes = New-Object System.Collections.Generic.List[double]
  $slPresent = 0; $entries = 0; $open = 0; $maxOpen = 0
  foreach($tr in $trs){
    $td = [regex]::Matches($tr.Groups[1].Value,'<td[^>]*>(.*?)</td>','Singleline')|%{$_.Groups[1].Value.Trim()}
    if($td.Count -lt 6){ continue }
    $type = $td[2]
    if($type -match '^(buy|sell)'){
      $s=0; if([double]::TryParse($td[4],[ref]$s) -and $s -gt 0){ $sizes.Add($s) }
      $entries++; if($td.Count -ge 8 -and $td[6] -ne '0.00000' -and $td[6] -ne ''){ $slPresent++ }
      $open++; if($open -gt $maxOpen){ $maxOpen=$open }
    } elseif($type -match '^close|^s/l|^t/p'){ if($open -gt 0){ $open-- } }
  }
  $name = Split-Path $Report -Leaf
  if($sizes.Count -eq 0){ Write-Output "$name : no entries"; return }
  $mode = [double](($sizes|Group-Object|Sort-Object Count -Descending)[0].Name)
  $max  = ($sizes|Measure-Object -Maximum).Maximum
  $ratio= [math]::Round($max/$mode,1)
  # step law: look at the sorted unique sizes ratio between consecutive levels
  $u = $sizes | Sort-Object -Unique
  $law = "flat"
  if($u.Count -ge 3){
    $r1 = $u[1]/$u[0]; $r2 = $u[2]/$u[1]
    if($r1 -ge 1.7){ $law = "MARTINGALE(x{0:N1})" -f $r1 }
    elseif([math]::Abs(($u[1]-$u[0])-($u[2]-$u[1])) -lt ($u[0]*0.3)){ $law = "LINEAR(+{0:N2})" -f ($u[1]-$u[0]) }
    else { $law = "mild/geo" }
  }
  $slPct = if($entries -gt 0){ [math]::Round(100.0*$slPresent/$entries,0) } else { 0 }
  $verdict = if($ratio -ge 10 -and $slPct -lt 10 -and $maxOpen -ge 8){ "STRUCTURAL-ruin (uncapped-ish + no SL)" }
             elseif($slPct -ge 50){ "HAS-SL -> recheck: capped? entry-edge? worth .set sweep" }
             elseif($maxOpen -le 5){ "CAPPED depth ($maxOpen) -> not runaway; recheck entry-edge" }
             else { "borderline -> flat-lot test before reject" }
  Write-Output ("{0} : base={1} max={2} x{3} | law={4} | SL on {5}% entries | maxOpen={6} => {7}" -f `
    $name,$mode,$max,$ratio,$law,$slPct,$maxOpen,$verdict)
}
