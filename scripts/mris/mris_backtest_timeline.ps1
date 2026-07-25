# mris_backtest_timeline.ps1 - ORDER-073 Phase-3 CONCEPT CHECK + backtest-CSV generator.
# Replays the MRIS regime classifier over history so we can (a) verify MRIS actually
# flags the real carry-unwind / crash windows before we build a watchdog that gates on
# it, and (b) emit a dated regime timeline CSV the MacroGate EA reads in the strategy
# tester (yyyy.MM.dd HH:mm,STATE,RI). Multi-year daily OHLC from the free Yahoo chart API.
#
# The classification logic here is PORTED from mris_classify.ps1 and kept faithful to it
# (cross-checked against the live classifier on today's date). It is a one-off analysis
# tool, not part of the daily chain.
[CmdletBinding()]
param(
  [string]$Config  = "D:\EA_LAB\scripts\mris\barometers.json",
  [string]$OutDir  = "D:\EA_LAB\portfolio\mris\backtest",
  # windows to replay (label -> start,end). Defaults = the two mandated A/B windows.
  [string[]]$Windows = @("carry_unwind_2024:2024-06-01:2024-09-20", "covid_crash_2020:2020-02-01:2020-04-30"),
  # -Detailed also emits per-barometer signal columns + a mean-signal attribution table, so a
  # state can be traced to the gauge that caused it (ORDER-203 core-sensitivity investigation).
  [switch]$Detailed
)
$SIGCOLS = @('AUDJPY','USDJPY','VIX','DXY','XAUUSD','BTCUSD','US10Y_JP10Y','COPPER')
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if (!(Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

$cfg = Get-Content $Config -Raw | ConvertFrom-Json

# snapshot symbol -> Yahoo ticker (same mapping as the live feeder)
$TICKERS = @{
  AUDJPY="AUDJPY=X"; USDJPY="JPY=X"; XAUUSD="GC=F"; BTCUSD="BTC-USD"
  VIX="^VIX"; DXY="DX-Y.NYB"; COPPER="HG=F"; US10Y_JP10Y="^TNX"
}

function AsNum($v) {
  if ($null -eq $v -or "$v".Trim() -eq "" -or "$v" -eq "NA") { return $null }
  $d = 0.0
  if ([double]::TryParse("$v", [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { return $d } else { return $null }
}

# ---- fetch multi-year daily history per ticker -> sorted arrays of {date,c,h,l} ----
function Fetch-History($yahoo) {
  $enc = [Uri]::EscapeDataString($yahoo)
  $url = "https://query1.finance.yahoo.com/v8/finance/chart/$enc" + "?range=10y&interval=1d"
  $j = (Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 40 -Headers @{ 'User-Agent'='Mozilla/5.0' }).Content | ConvertFrom-Json
  $res = $j.chart.result[0]
  $ts = $res.timestamp
  $q  = $res.indicators.quote[0]
  # NOTE: accumulators are $Cl/$Hi/$Lo, distinct from the scalar temps $c/$h/$l -
  # PowerShell variables are CASE-INSENSITIVE, so $C/$c would be the SAME variable.
  $dates=@(); $Cl=@(); $Hi=@(); $Lo=@()
  for ($i=0; $i -lt $ts.Count; $i++) {
    $c=$q.close[$i]; $h=$q.high[$i]; $l=$q.low[$i]
    if ($null -ne $c -and $null -ne $h -and $null -ne $l) {
      $dates += [DateTimeOffset]::FromUnixTimeSeconds([long]$ts[$i]).UtcDateTime.Date
      $Cl += [double]$c; $Hi += [double]$h; $Lo += [double]$l
    }
  }
  return [pscustomobject]@{ Dates=$dates; C=$Cl; H=$Hi; L=$Lo; N=$Cl.Count }
}

Write-Host "fetching 10y history for 8 barometers..."
$HIST = @{}
foreach ($sym in $TICKERS.Keys) {
  try { $HIST[$sym] = Fetch-History $TICKERS[$sym]; Write-Host ("  {0,-12} {1} bars {2}..{3}" -f $sym,$HIST[$sym].N,$HIST[$sym].Dates[0].ToString('yyyy-MM-dd'),$HIST[$sym].Dates[-1].ToString('yyyy-MM-dd')) }
  catch { Write-Host "  $sym FETCH FAIL: $($_.Exception.Message)"; $HIST[$sym]=$null }
}

# index of the bar on-or-before target date for a history series (binary-ish linear scan)
function IdxAsOf($h, [datetime]$d) {
  if ($null -eq $h) { return -1 }
  $idx = -1
  for ($i=0; $i -lt $h.N; $i++) { if ($h.Dates[$i] -le $d) { $idx=$i } else { break } }
  return $idx
}

# build an as-of snapshot row for one symbol at date d
function AsOfRow($sym, [datetime]$d) {
  $h = $HIST[$sym]; $i = IdxAsOf $h $d
  if ($i -lt 5) { return $null }
  $spot = $h.C[$i]
  $lb = [math]::Min(200, $i+1)
  $sma = (($h.C[($i-$lb+1)..$i]) | Measure-Object -Average).Average
  $atrN = [math]::Min(20, $i)
  $trs=@(); for ($k=$i-$atrN+1; $k -le $i; $k++) { $tr1=$h.H[$k]-$h.L[$k]; $tr2=[math]::Abs($h.H[$k]-$h.C[$k-1]); $tr3=[math]::Abs($h.L[$k]-$h.C[$k-1]); $trs+=[math]::Max($tr1,[math]::Max($tr2,$tr3)) }
  $atr = (($trs) | Measure-Object -Average).Average
  $c5 = $h.C[$i-5]
  $chg5d = if ($c5 -ne 0) { (($spot/$c5)-1.0)*100.0 } else { 0 }
  return [pscustomobject]@{ spot=$spot; sma200=$sma; atr20=$atr; chg5d_pct=$chg5d }
}

# ---- faithful port of mris_classify.ps1 signal logic ----
function Classify([hashtable]$snap) {
  $results=@()
  foreach ($b in $cfg.barometers) {
    $row=$snap[$b.symbol]
    if ($null -eq $row) { $results += [pscustomobject]@{ symbol=$b.symbol; active=$false; weight=$b.weight; signal=$null; flags=@() }; continue }
    $spot=$row.spot; $sma200=$row.sma200; $atr20=$row.atr20; $chg5d=$row.chg5d_pct
    $signal=0.0; $flags=@()
    switch ($b.polarity) {
      "risk_on" {
        $pin=AsNum $b.user_pin; $belowTrend=($null -ne $sma200 -and $spot -lt $sma200)
        $fastMult=if ($b.fast_drop_atr_mult){$b.fast_drop_atr_mult}else{$null}; $fastDrop=$false
        if ($fastMult -and $null -ne $atr20 -and $null -ne $chg5d) { $dp=-($fastMult*$atr20/$spot*100.0); if ($chg5d -le $dp){$fastDrop=$true} }
        elseif ($b.move_5d_pct -and $null -ne $chg5d) { if ($chg5d -le -[double]$b.move_5d_pct){$fastDrop=$true} }
        if ($null -ne $pin -and $spot -lt $pin -and $belowTrend) { $signal=-2 }
        elseif ($fastDrop) { $signal=-1.5 }
        elseif ($belowTrend) { $signal=-1 }
        elseif ($null -ne $chg5d -and $chg5d -ge 0) { $signal=1 }
        else { $signal=0.5 }
        if ($null -ne $pin -and $b.pin_warn_band_pct) { $dpc=($spot-$pin)/$pin*100.0; if ($spot -ge $pin -and $dpc -le [double]$b.pin_warn_band_pct){$flags+="PIN_NEAR"} }
      }
      "carry_fuel" {
        $narrowBps=AsNum $b.narrowing_5d_bps
        if ($null -ne $narrowBps) {
          $bps5d=if ($null -ne $chg5d){ ($spot-($spot/(1.0+$chg5d/100.0)))*100.0 } else {$null}
          if ($null -eq $bps5d){$signal=0} elseif ($bps5d -le -$narrowBps){$signal=-1} elseif ($bps5d -ge $narrowBps){$signal=0.5} else {$signal=0}
        } else {
          $ext=AsNum $b.extreme_weak_level; $sm=if ($b.sharp_reversal_atr_mult){$b.sharp_reversal_atr_mult}else{$null}; $sharp=$false
          if ($sm -and $null -ne $atr20 -and $null -ne $chg5d){ $rp=-($sm*$atr20/$spot*100.0); if ($chg5d -le $rp){$sharp=$true} }
          if ($sharp){$signal=-2} elseif ($null -ne $ext -and $spot -ge $ext){$signal=0.5; $flags+="LOADED_FUSE"} else {$signal=0}
        }
      }
      "risk_off" {
        $calm=AsNum $b.calm_below; $elev=AsNum $b.elevated_above; $str=AsNum $b.stress_above
        if ($null -ne $str -and $spot -ge $str){$signal=-2; $flags+="VIX_STRESS"} elseif ($null -ne $elev -and $spot -ge $elev){$signal=-1} elseif ($null -ne $calm -and $spot -le $calm){$signal=1} else {$signal=0}
      }
      "risk_off_soft" { $s=AsNum $b.strong_move_5d_pct; if ($null -ne $s -and $null -ne $chg5d -and $chg5d -ge $s){$signal=-1} else {$signal=0} }
      "comove_confirm" {
        $vr=$snap["VIX"]; $vc=if ($vr){$vr.chg5d_pct}else{$null}; $th=AsNum $b.comove_5d_pct; $vm=AsNum $b.comove_vix_min_pct; if ($null -eq $vm){$vm=10.0}
        if ($null -ne $th -and $null -ne $chg5d -and $chg5d -ge $th -and $null -ne $vc -and $vc -ge $vm){$signal=-1} else {$signal=0}
      }
      default { $signal=0 }
    }
    $results += [pscustomobject]@{ symbol=$b.symbol; active=$true; weight=$b.weight; signal=$signal; flags=$flags }
  }
  $active=$results | Where-Object {$_.active}
  if ($active.Count -eq 0){ return $null }
  $wsum=($active|Measure-Object -Property weight -Sum).Sum
  $ri=0.0; foreach($a in $active){$ri+=$a.signal*$a.weight}; $ri=$ri/$wsum
  $t=$cfg.regime_thresholds
  $vixRow=$active|Where-Object {$_.symbol -eq "VIX"}|Select-Object -First 1
  $vixSpot=if ($vixRow){$snap["VIX"].spot}else{$null}
  $state=""
  if (($null -ne $vixSpot -and $vixSpot -ge $t.vix_stress_override) -or $ri -lt $t.stress_below){$state="STRESS"}
  elseif ($ri -ge $t.risk_on_min){$state="RISK_ON"} elseif ($ri -ge $t.neutral_min){$state="NEUTRAL"} else {$state="RISK_OFF"}
  $allFlags=@(); foreach($a in $active){$allFlags+=$a.flags}
  # per-barometer signals returned too, so -Detailed can attribute a state to its drivers
  # without a second (divergence-prone) copy of this logic living somewhere else.
  $sig=@{}; foreach($a in $active){ $sig[$a.symbol]=$a.signal }
  return [pscustomobject]@{ state=$state; ri=[math]::Round($ri,3); flags=($allFlags -join ','); sig=$sig }
}

# ---- replay each window over AUDJPY's trading calendar ----
foreach ($w in $Windows) {
  $parts = $w -split ':'
  $label=$parts[0]; $start=[datetime]$parts[1]; $end=[datetime]$parts[2]
  $aud=$HIST["AUDJPY"]
  $rows=@()
  for ($i=0; $i -lt $aud.N; $i++) {
    $d=$aud.Dates[$i]
    if ($d -lt $start -or $d -gt $end) { continue }
    $snap=@{}
    foreach ($sym in $TICKERS.Keys) { $r=AsOfRow $sym $d; if ($r){$snap[$sym]=$r} }
    $c=Classify $snap
    if ($c){
      $row = [pscustomobject]@{ date=$d.ToString('yyyy.MM.dd'); state=$c.state; ri=$c.ri; flags=$c.flags }
      if ($Detailed) { foreach ($sym in $SIGCOLS) { Add-Member -InputObject $row -NotePropertyName "sig_$sym" -NotePropertyValue $(if ($c.sig.ContainsKey($sym)) { $c.sig[$sym] } else { $null }) } }
      $rows += $row
    }
  }
  $out=Join-Path $OutDir "regime_$label.csv"
  $cols = @(@{n='datetime';e={ $_.date + ' 00:00' }}, 'state', 'ri', 'flags')
  if ($Detailed) { $cols += ($SIGCOLS | ForEach-Object { "sig_$_" }) }
  $rows | Select-Object $cols | Export-Csv $out -NoTypeInformation -Encoding UTF8
  # header FIRST so the attribution table below is unambiguously attributable to THIS window
  # (printing it before the header made a reader assign each table to the wrong year).
  Write-Host ""
  Write-Host "=== $label ($($parts[1])..$($parts[2])) : $($rows.Count) days -> $out ==="
  if ($Detailed) {
    # mean signal per barometer = which gauge is systematically pushing the Risk Index around
    Write-Host "   mean signal per barometer over this window (negative = pushing RISK_OFF):"
    foreach ($sym in $SIGCOLS) {
      $vals = @($rows | ForEach-Object { $_."sig_$sym" } | Where-Object { $null -ne $_ })
      if ($vals.Count -eq 0) { continue }
      $w = ($cfg.barometers | Where-Object { $_.symbol -eq $sym } | Select-Object -First 1).weight
      $mean = ($vals | Measure-Object -Average).Average
      $pctNeg = 100.0 * (@($vals | Where-Object { $_ -lt 0 }).Count) / $vals.Count
      Write-Host ("      {0,-13} w={1}  mean={2,6:N2}  weighted={3,6:N3}  days-negative={4,5:N1}%" -f $sym,$w,$mean,($mean*$w/13.0),$pctNeg)
    }
  }
  $dist = $rows | Group-Object state | Sort-Object Count -Descending | ForEach-Object { "$($_.Name)=$($_.Count)" }
  $stress = $rows | Where-Object { $_.state -eq 'STRESS' -or $_.state -eq 'RISK_OFF' } | Sort-Object date
  Write-Host ("   state dist: " + ($dist -join '  '))
  if ($stress) {
    Write-Host ("   RISK_OFF/STRESS days: " + $stress.Count + " (first " + $stress[0].date + " .. last " + $stress[-1].date + ")")
    $stress | Select-Object -First 12 | ForEach-Object { Write-Host ("      {0}  {1,-9} RI={2}  {3}" -f $_.date,$_.state,$_.ri,$_.flags) }
  } else {
    Write-Host "   !! NO RISK_OFF/STRESS days flagged in this window - gate would NOT fire here"
  }
}
