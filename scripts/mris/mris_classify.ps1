# mris_classify.ps1 - MRIS regime classifier (ORDER-073 Phase-2 macro layer)
# Reads a barometer snapshot (current values, from the MT5 exporter or a web feeder)
# + barometers.json config -> emits an EXPLAINABLE regime state JSON.
# Zero LLM tokens - pure rules. State = RISK_ON / NEUTRAL / RISK_OFF / STRESS.
#
# Signal convention: each active barometer yields a signal in [-2,+2] where
#   POSITIVE = risk-ON pressure, NEGATIVE = risk-OFF pressure.
# Risk Index (RI) = weight-normalised mean of active signals. Confidence =
# fraction of active barometers whose signal sign agrees with RI ("parallel
# warning lines" - the article's whole thesis). Barometers with data_status
# not OK (PENDING/STALE/missing) are skipped and weights renormalised.
[CmdletBinding()]
param(
  [string]$Snapshot = "D:\EA_LAB\portfolio\mris\barometer_snapshot.csv",
  [string]$Config   = "D:\EA_LAB\scripts\mris\barometers.json",
  [string]$OutJson  = "D:\EA_LAB\portfolio\mris\regime_state.json",
  # an OK row whose `asof` stamp is older than this is treated as STALE and excluded
  # (defends against a snapshot that silently froze; 120h = weekend/holiday tolerant).
  [int]$MaxAgeHours = 120
)
$ErrorActionPreference = "Stop"

if (!(Test-Path $Config))   { throw "config not found: $Config" }
if (!(Test-Path $Snapshot)) { throw "snapshot not found: $Snapshot (run the MT5 exporter or seed it)" }

$cfg  = Get-Content $Config -Raw | ConvertFrom-Json
$snap = Import-Csv $Snapshot
$snapBy = @{}
foreach ($r in $snap) { $snapBy[$r.symbol] = $r }

function AsNum($v) {
  if ($null -eq $v -or "$v".Trim() -eq "" -or "$v" -eq "NA") { return $null }
  # InvariantCulture so a th-TH / de-DE host cannot misread "17.5" as 175 (Codex QA 2026-07-17)
  $d = 0.0
  if ([double]::TryParse("$v", [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { return $d } else { return $null }
}

# Effective status of a snapshot row = its data_status, then the freshness age-gate:
# an OK row older than MaxAgeHours -> STALE_AGED; an OK row with a present-but-unparseable
# asof -> STALE_INVALID_ASOF (fail closed); blank/missing asof stays ungated (back-compat).
# Centralised so cross-row reads (e.g. gold's VIX co-move) see the SAME effective status
# the Risk Index does, not the raw data_status (Codex QA 2026-07-17).
function EffStatus($row) {
  if ($null -eq $row) { return "MISSING" }
  $s = "$($row.data_status)".ToUpper()
  if ($s -eq "OK" -and $row.asof -and "$($row.asof)".Trim() -ne "") {
    $asofDt = [datetime]::MinValue
    if ([datetime]::TryParseExact("$($row.asof)", 'yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$asofDt)) {
      if (((Get-Date) - $asofDt).TotalHours -gt $MaxAgeHours) { return "STALE_AGED" }
    } else {
      return "STALE_INVALID_ASOF"
    }
  }
  return $s
}

$results = @()
foreach ($b in $cfg.barometers) {
  $row = $snapBy[$b.symbol]
  $status = EffStatus $row
  $spot   = if ($row) { AsNum $row.spot }       else { $null }
  $sma200 = if ($row) { AsNum $row.sma200 }     else { $null }
  $atr20  = if ($row) { AsNum $row.atr20 }       else { $null }
  $chg5d  = if ($row) { AsNum $row.chg5d_pct }   else { $null }

  # skip inactive barometers (no usable data)
  if ($status -ne "OK" -or $null -eq $spot) {
    $results += [pscustomobject]@{
      symbol=$b.symbol; active=$false; status=$status; weight=$b.weight
      signal=$null; reason="inactive ($status) - excluded from Risk Index"; flags=@()
    }
    continue
  }

  $signal = 0.0
  $reasons = @()
  $flags = @()

  switch ($b.polarity) {
    "risk_on" {
      # carry / risk proxies (AUDJPY, BTC): below trend or fast drop = risk-off
      $pin = AsNum $b.user_pin
      $belowTrend = ($null -ne $sma200 -and $spot -lt $sma200)
      $fastMult = if ($b.fast_drop_atr_mult) { $b.fast_drop_atr_mult } else { $null }
      $fastDrop = $false
      if ($fastMult -and $null -ne $atr20 -and $null -ne $chg5d) {
        $dropPct = -($fastMult * $atr20 / $spot * 100.0)
        if ($chg5d -le $dropPct) { $fastDrop = $true }
      } elseif ($b.move_5d_pct -and $null -ne $chg5d) {
        if ($chg5d -le -[double]$b.move_5d_pct) { $fastDrop = $true }
      }
      # -2 = confirmed unwind. ORDER-203: this used to read "below user_pin AND below SMA200",
      # but user_pin is an ABSOLUTE 2026 price (AUDJPY 110) -- on any pre-2026 date the pin test
      # is always true, so every below-SMA200 day scored -2 instead of -1 and the weight-3
      # AUDJPY leg alone pushed RI past the RISK_OFF band. The pin is now advisory only
      # (TRIPWIRE_NEAR below); confirmation comes from two RELATIVE conditions agreeing.
      if ($belowTrend -and $fastDrop) {
        $signal = -2; $reasons += "below SMA200 AND fast drop beyond ATR band -> carry-unwind confirmed"
      } elseif ($fastDrop) {
        $signal = -1.5; $reasons += "fast drop (5d $chg5d`%) beyond ATR band -> unwind starting"
      } elseif ($belowTrend) {
        $signal = -1; $reasons += "below SMA200 -> risk-off lean"
      } elseif ($null -ne $chg5d -and $chg5d -ge 0) {
        $signal = 1; $reasons += "above SMA200, 5d $chg5d`% -> risk-on intact"
      } else {
        $signal = 0.5; $reasons += "above SMA200 but soft 5d -> mild risk-on"
      }
      # proximity flag to user pin
      if ($null -ne $pin -and $b.pin_warn_band_pct) {
        $distPct = ($spot - $pin) / $pin * 100.0
        if ($spot -ge $pin -and $distPct -le [double]$b.pin_warn_band_pct) {
          $flags += "TRIPWIRE_NEAR: $($b.symbol) $([math]::Round($spot,2)) only $([math]::Round($distPct,2))% above pin $pin"
        }
      }
    }
    "carry_fuel" {
      # Two carry_fuel shapes, distinguished by which threshold the config sets:
      #  (a) narrowing_5d_bps  -> a RATE-SPREAD proxy (US10Y_JP10Y via ^TNX). The 5d
      #      move of the spread is ~entirely the US leg (JP10Y BOJ-pinned). A spread
      #      NARROWING (US yield falling) = carry less attractive = risk-off lean.
      #  (b) extreme_weak_level + sharp_reversal_atr_mult -> a PRICE level (USDJPY):
      #      danger is a SHARP REVERSAL, plus 'loaded' when at a crowded extreme.
      $narrowBps = AsNum $b.narrowing_5d_bps
      if ($null -ne $narrowBps) {
        # 5d change of the yield in bps (spot is the yield in %, chg5d its % change)
        $bps5d = if ($null -ne $chg5d) { ($spot - ($spot / (1.0 + $chg5d / 100.0))) * 100.0 } else { $null }
        if ($null -eq $bps5d) {
          $signal = 0; $reasons += "spread proxy: no 5d data -> neutral"
        } elseif ($bps5d -le -$narrowBps) {
          $signal = -1; $reasons += "carry spread narrowed ~$([math]::Round($bps5d,1))bps/5d (US10Y proxy) -> carry fuel weakening"
          $flags += "CARRY_NARROWING: US10Y proxy $([math]::Round($bps5d,1))bps/5d"
        } elseif ($bps5d -ge $narrowBps) {
          $signal = 0.5; $reasons += "carry spread widened ~$([math]::Round($bps5d,1))bps/5d -> carry more attractive"
        } else {
          $signal = 0; $reasons += "carry spread ~flat ($([math]::Round($bps5d,1))bps/5d) -> neutral"
        }
      } else {
        $ext = AsNum $b.extreme_weak_level
        $sharpMult = if ($b.sharp_reversal_atr_mult) { $b.sharp_reversal_atr_mult } else { $null }
        $sharpRev = $false
        if ($sharpMult -and $null -ne $atr20 -and $null -ne $chg5d) {
          $revPct = -($sharpMult * $atr20 / $spot * 100.0)
          if ($chg5d -le $revPct) { $sharpRev = $true }
        }
        if ($sharpRev) {
          $signal = -2; $reasons += "sharp reversal down (5d $chg5d`%) -> JPY repatriation / carry unwind trigger"
        } elseif ($null -ne $ext -and $spot -ge $ext) {
          $signal = 0.5; $reasons += "extreme weak ($spot >= $ext) -> risk-on now BUT crowded/loaded"
          $flags += "LOADED_FUSE: $($b.symbol) $([math]::Round($spot,2)) at extreme - crowded short, snap-back risk high"
        } else {
          $signal = 0; $reasons += "no sharp reversal, not extreme -> neutral"
        }
      }
    }
    "risk_off" {
      # VIX: high = risk-off
      $calm = AsNum $b.calm_below; $elev = AsNum $b.elevated_above; $stress = AsNum $b.stress_above
      if ($null -ne $stress -and $spot -ge $stress) {
        $signal = -2; $reasons += "VIX $spot >= $stress -> STRESS"; $flags += "VIX_STRESS: $spot"
      } elseif ($null -ne $elev -and $spot -ge $elev) {
        $signal = -1; $reasons += "VIX $spot >= $elev -> elevated fear"
      } elseif ($null -ne $calm -and $spot -le $calm) {
        $signal = 1; $reasons += "VIX $spot <= $calm -> calm / risk-on"
      } else {
        $signal = 0; $reasons += "VIX $spot mid-range -> neutral"
      }
    }
    "risk_off_soft" {
      # DXY: strong rally = mild risk-off flight
      $strong = AsNum $b.strong_move_5d_pct
      if ($null -ne $strong -and $null -ne $chg5d -and $chg5d -ge $strong) {
        $signal = -1; $reasons += "DXY +$chg5d`% 5d -> USD flight, mild risk-off"
      } else {
        $signal = 0; $reasons += "DXY no strong move -> neutral"
      }
    }
    "comove_confirm" {
      # Gold: only a risk-off confirm if rising WITH a MEANINGFUL VIX rise (a tiny +ve
      # VIX % off a low base is noise); and only if the VIX row itself is fresh/OK, else
      # a stale VIX reading could not confirm anything.
      $vixRow = $snapBy["VIX"]
      $vixOk  = ((EffStatus $vixRow) -eq "OK")   # effective (age-gated) status, not raw
      $vixChg = if ($vixOk) { AsNum $vixRow.chg5d_pct } else { $null }
      $th = AsNum $b.comove_5d_pct
      $vixMin = AsNum $b.comove_vix_min_pct
      if ($null -eq $vixMin) { $vixMin = 10.0 }  # default: VIX must rise >=10% over 5d to count as fear
      if ($null -ne $th -and $null -ne $chg5d -and $chg5d -ge $th -and $null -ne $vixChg -and $vixChg -ge $vixMin) {
        $signal = -1; $reasons += "gold +$chg5d`% WITH VIX +$vixChg`% (>= $vixMin`%) -> risk-off confirmation"
      } elseif (-not $vixOk) {
        $signal = 0; $reasons += "gold move: VIX not fresh -> cannot confirm co-move -> neutral"
      } else {
        $signal = 0; $reasons += "gold move is structural/USD-driven (no meaningful VIX co-move) -> neutral"
      }
    }
    default { $signal = 0; $reasons += "unknown polarity -> neutral" }
  }

  $results += [pscustomobject]@{
    symbol=$b.symbol; active=$true; status="OK"; weight=$b.weight
    spot=$spot; sma200=$sma200; chg5d_pct=$chg5d
    signal=[math]::Round($signal,2); reason=($reasons -join "; "); flags=$flags
  }
}

# ---- aggregate ----
$active = $results | Where-Object { $_.active }
if ($active.Count -eq 0) { throw "no active barometers - cannot classify" }
$wsum = ($active | Measure-Object -Property weight -Sum).Sum
$ri = 0.0
foreach ($a in $active) { $ri += $a.signal * $a.weight }
$ri = $ri / $wsum

$t = $cfg.regime_thresholds
$allFlags = @(); foreach ($a in $active) { $allFlags += $a.flags }
# VIX STRESS override must read the ACTIVE VIX signal only - a STALE/failed VIX (e.g.
# cache frozen mid-crisis after Yahoo went down) must not pin the whole state to STRESS.
$vixActive = $active | Where-Object { $_.symbol -eq "VIX" } | Select-Object -First 1
$vixSpot = if ($vixActive) { AsNum $vixActive.spot } else { $null }

$state = ""
if (($null -ne $vixSpot -and $vixSpot -ge $t.vix_stress_override) -or $ri -lt $t.stress_below) {
  $state = "STRESS"
} elseif ($ri -ge $t.risk_on_min) {
  $state = "RISK_ON"
} elseif ($ri -ge $t.neutral_min) {
  $state = "NEUTRAL"
} else {
  $state = "RISK_OFF"
}

# confidence = agreement of active signals with RI sign
$riSign = if ($ri -ge 0) { 1 } else { -1 }
$agree = ($active | Where-Object { $_.signal -ne 0 -and ([math]::Sign($_.signal) -eq $riSign) }).Count
$nonZero = ($active | Where-Object { $_.signal -ne 0 }).Count
$confFrac = if ($nonZero -gt 0) { [double]$agree / $nonZero } else { 0.0 }
$conf = if ($confFrac -ge $cfg.confidence.high_min) { "HIGH" } elseif ($confFrac -ge $cfg.confidence.med_min) { "MED" } else { "LOW" }

$bias = if ($ri -ge $t.risk_on_min) { "risk-on / carry constructive" }
        elseif ($ri -ge $t.neutral_min) { "balanced - watch for tilt" }
        else { "defensive / reduce carry exposure" }

$pending = @($cfg.barometers | Where-Object { $_.optional } | ForEach-Object { $_.symbol })

$out = [ordered]@{
  generated_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
  state         = $state
  risk_index    = [math]::Round($ri,3)
  bias          = $bias
  confidence    = $conf
  confidence_frac = [math]::Round($confFrac,2)
  active_count  = $active.Count
  flags         = $allFlags
  data_pending  = $pending
  barometers    = $results
}
$dir = Split-Path $OutJson -Parent
if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$out | ConvertTo-Json -Depth 6 | Set-Content -Path $OutJson -Encoding UTF8

Write-Host "MRIS state = $state | RI=$([math]::Round($ri,3)) | conf=$conf ($([math]::Round($confFrac,2))) | active=$($active.Count)"
if ($allFlags.Count) { Write-Host ("flags: " + ($allFlags -join " | ")) }
Write-Host "-> $OutJson"
