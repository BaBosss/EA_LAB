# mris_crisis_backtest.ps1 - ORDER-200 Phase-B CONCEPT CHECK for the crisis models.
# Replays the crisis-model scoring (mris_crisis_models.ps1 logic, anchors read from the
# SAME crisis_models.json) over historical episodes to verify each model actually lights
# up in its matching regime BEFORE any score is allowed to influence the exported RI.
#
# Data: 10y daily history from the free Yahoo chart API (US10Y ^TNX, VIX ^VIX, MOVE ^MOVE,
# WTI CL=F, SP500 ^GSPC, US2Y 2YY=F) + full FRED history for HY_OAS (BAMLH0A0HYM2) via
# curl.exe (Invoke-WebRequest to fred.stlouisfed.org times out on this box - TLS proxy).
# One-off analysis tool, NOT part of the daily chain. Zero LLM tokens.
[CmdletBinding()]
param(
  [string]$Config = "D:\EA_LAB\scripts\mris\crisis_models.json",
  [string]$OutDir = "D:\EA_LAB\portfolio\mris\backtest",
  # label:start:end - episodes chosen so each model has a window it SHOULD fire in
  [string[]]$Windows = @(
    "covid_2020:2020-02-01:2020-05-15",
    "inflation_2022:2022-02-15:2022-08-15",
    "yield_spike_2023:2023-08-01:2023-11-15",
    "calm_2019:2019-05-01:2019-07-31"
  )
)
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if (!(Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

$cfg = Get-Content $Config -Raw -Encoding UTF8 | ConvertFrom-Json

function AsNum($v) {
  if ($null -eq $v -or "$v".Trim() -eq "" -or "$v" -eq "NA" -or "$v" -eq ".") { return $null }
  $d = 0.0
  if ([double]::TryParse("$v", [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { return $d } else { return $null }
}

# input symbol -> Yahoo ticker (US10Y aliased from ^TNX, the same proxy the live layer uses)
$YTICK = @{ US10Y="^TNX"; VIX="^VIX"; MOVE="^MOVE"; WTI="CL=F"; SP500="^GSPC"; US2Y="2YY=F" }

# ---- Yahoo history: sorted {Dates, Vals(close)} ----
function Fetch-Yahoo($yahoo) {
  $enc = [Uri]::EscapeDataString($yahoo)
  $url = "https://query1.finance.yahoo.com/v8/finance/chart/$enc" + "?range=10y&interval=1d"
  $j = (Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 40 -Headers @{ 'User-Agent'='Mozilla/5.0' }).Content | ConvertFrom-Json
  $res = $j.chart.result[0]; $ts = $res.timestamp; $q = $res.indicators.quote[0]
  $dates=@(); $Vals=@()
  for ($i=0; $i -lt $ts.Count; $i++) {
    $c = $q.close[$i]
    if ($null -ne $c) { $dates += [DateTimeOffset]::FromUnixTimeSeconds([long]$ts[$i]).UtcDateTime.Date; $Vals += [double]$c }
  }
  return [pscustomobject]@{ Dates=$dates; Vals=$Vals; N=$Vals.Count }
}

# ---- FRED history via curl.exe: DATE,VALUE (skip '.' gaps) ----
function Fetch-Fred($id) {
  # cosd forces full history - the bare graph CSV defaults to only the last ~2yr window,
  # which would silently blind the covid-2020 credit test (Opus-seat backtest finding).
  $url = "https://fred.stlouisfed.org/graph/fredgraph.csv?id=$id&cosd=2015-01-01"
  $raw = & curl.exe -s -m 40 $url
  if ([string]::IsNullOrWhiteSpace($raw)) { throw "empty FRED body for $id" }
  $lines = $raw -split "`r?`n" | Where-Object { $_ -and $_ -notmatch '^(observation_date|DATE)' }
  $dates=@(); $Vals=@()
  foreach ($ln in $lines) {
    $p = $ln -split ','
    if ($p.Count -lt 2) { continue }
    $v = AsNum $p[1]
    if ($null -eq $v) { continue }
    $d = [datetime]::MinValue
    if ([datetime]::TryParse($p[0], [ref]$d)) { $dates += $d.Date; $Vals += $v }
  }
  return [pscustomobject]@{ Dates=$dates; Vals=$Vals; N=$Vals.Count }
}

Write-Host "fetching history..."
$HIST = @{}
foreach ($sym in $YTICK.Keys) {
  try { $HIST[$sym] = Fetch-Yahoo $YTICK[$sym]; Write-Host ("  {0,-8} {1} bars {2}..{3}" -f $sym,$HIST[$sym].N,$HIST[$sym].Dates[0].ToString('yyyy-MM-dd'),$HIST[$sym].Dates[-1].ToString('yyyy-MM-dd')) }
  catch { Write-Host "  $sym FETCH FAIL: $($_.Exception.Message)"; $HIST[$sym]=$null }
}
try { $HIST["HY_OAS"] = Fetch-Fred "BAMLH0A0HYM2"; Write-Host ("  {0,-8} {1} bars {2}..{3}" -f "HY_OAS",$HIST["HY_OAS"].N,$HIST["HY_OAS"].Dates[0].ToString('yyyy-MM-dd'),$HIST["HY_OAS"].Dates[-1].ToString('yyyy-MM-dd')) }
catch { Write-Host "  HY_OAS FETCH FAIL: $($_.Exception.Message)"; $HIST["HY_OAS"]=$null }

# index of the bar on-or-before target date
function IdxAsOf($h, [datetime]$d) {
  if ($null -eq $h) { return -1 }
  $idx = -1
  for ($i=0; $i -lt $h.N; $i++) { if ($h.Dates[$i] -le $d) { $idx=$i } else { break } }
  return $idx
}

# as-of derived fields for one symbol at date d: spot, sma200, chg5d_pct
function AsOf($sym, [datetime]$d) {
  $h = $HIST[$sym]; $i = IdxAsOf $h $d
  if ($i -lt 6) { return $null }
  $spot = $h.Vals[$i]
  $lb = [math]::Min(200, $i+1)
  $sma = (($h.Vals[($i-$lb+1)..$i]) | Measure-Object -Average).Average
  $c5 = $h.Vals[$i-5]
  $chg5d = if ($c5 -ne 0) { (($spot/$c5)-1.0)*100.0 } else { 0 }
  return [pscustomobject]@{ spot=$spot; sma200=$sma; chg5d_pct=$chg5d }
}

# resolve a "SYMBOL.field" input at date d (faithful to mris_crisis_models.ps1 Resolve-Input)
function ResolveAt([string]$key, [datetime]$d) {
  $parts = $key -split '\.', 2; if ($parts.Count -ne 2) { return $null }
  $r = AsOf $parts[0] $d; if ($null -eq $r) { return $null }
  switch ($parts[1]) {
    "spot"      { return $r.spot }
    "chg5d_pct" { return $r.chg5d_pct }
    "bps5d"     { $prev = $r.spot/(1.0+$r.chg5d_pct/100.0); return ($r.spot-$prev)*100.0 }
    "pct_vs_sma200" { if ($r.sma200 -eq 0) { return $null }; return ($r.spot-$r.sma200)/$r.sma200*100.0 }
    default { return $null }
  }
}
function Ramp($v,$calm,$stress) {
  if ($null -eq $v) { return $null }
  if ($stress -eq $calm) { return 0.0 }
  $t = ($v-$calm)/($stress-$calm); if ($t -lt 0){$t=0}; if ($t -gt 1){$t=1}
  return [math]::Round($t*100.0,1)
}
function ScoreModelsAt([datetime]$d) {
  $res = @{}
  foreach ($m in $cfg.models) {
    $wA=0.0; $wS=0.0
    foreach ($c in $m.components) {
      $sc = Ramp (ResolveAt $c.input $d) $c.calm $c.stress
      if ($null -ne $sc) { $wA += [double]$c.weight; $wS += $sc*[double]$c.weight }
    }
    $res[$m.name] = if ($wA -gt 0) { [math]::Round($wS/$wA,1) } else { $null }
  }
  return $res
}

# ---- replay each window over SP500's calendar ----
$activeMin = [double]$cfg.labels.active_min
$summary = @()
foreach ($w in $Windows) {
  $parts = $w -split ':'; $label=$parts[0]; $start=[datetime]$parts[1]; $end=[datetime]$parts[2]
  $cal = $HIST["SP500"]
  $rows=@()
  for ($i=0; $i -lt $cal.N; $i++) {
    $d = $cal.Dates[$i]
    if ($d -lt $start -or $d -gt $end) { continue }
    $s = ScoreModelsAt $d
    $rows += [pscustomobject]@{ date=$d.ToString('yyyy-MM-dd'); YIELD_SHOCK=$s["YIELD_SHOCK"]; CREDIT_STRESS=$s["CREDIT_STRESS"]; INFLATION_OIL=$s["INFLATION_OIL"] }
  }
  $out = Join-Path $OutDir "crisis_$label.csv"
  $rows | Export-Csv $out -NoTypeInformation -Encoding UTF8
  Write-Host ""
  Write-Host "=== $label ($($parts[1])..$($parts[2])) : $($rows.Count) days -> $out ==="
  foreach ($mn in @("YIELD_SHOCK","CREDIT_STRESS","INFLATION_OIL")) {
    $vals = $rows | ForEach-Object { $_.$mn } | Where-Object { $null -ne $_ }
    if ($vals.Count -eq 0) { Write-Host ("   {0,-15} no data" -f $mn); continue }
    $peak = ($vals | Measure-Object -Maximum).Maximum
    $avg  = [math]::Round((($vals | Measure-Object -Average).Average),1)
    $daysActive = ($vals | Where-Object { $_ -ge $activeMin }).Count
    $mark = if ($peak -ge $activeMin) { "ACTIVE-fired" } else { "did-not-fire" }
    Write-Host ("   {0,-15} peak={1,5}  avg={2,5}  days>=60: {3,3}/{4}  [{5}]" -f $mn,$peak,$avg,$daysActive,$vals.Count,$mark)
    $summary += [pscustomobject]@{ window=$label; model=$mn; peak=$peak; avg=$avg; days_active=$daysActive; total=$vals.Count }
  }
}

Write-Host ""
Write-Host "=== EXPECTATION CHECK (each model should fire in its matching episode, stay calm in calm_2021) ==="
function PeakOf($win,$mod) { ($summary | Where-Object { $_.window -eq $win -and $_.model -eq $mod } | Select-Object -First 1).peak }
$checks = @(
  @{ desc="CREDIT_STRESS fires in covid_2020";      pass=((PeakOf 'covid_2020' 'CREDIT_STRESS') -ge $activeMin) },
  @{ desc="INFLATION_OIL fires in inflation_2022";   pass=((PeakOf 'inflation_2022' 'INFLATION_OIL') -ge $activeMin) },
  @{ desc="YIELD_SHOCK fires in yield_spike_2023";   pass=((PeakOf 'yield_spike_2023' 'YIELD_SHOCK') -ge $activeMin) },
  @{ desc="all models calm (<60) in calm_2021";      pass=(((PeakOf 'calm_2021' 'CREDIT_STRESS') -lt $activeMin) -and ((PeakOf 'calm_2021' 'YIELD_SHOCK') -lt $activeMin) -and ((PeakOf 'calm_2021' 'INFLATION_OIL') -lt $activeMin)) }
)
$nPass=0
foreach ($c in $checks) { $tag = if ($c.pass) { "PASS"; $nPass++ } else { "FAIL" }; Write-Host ("   [{0}] {1}" -f $tag,$c.desc) }
Write-Host ""
Write-Host ("CONCEPT CHECK: $nPass/$($checks.Count) expectations met")
