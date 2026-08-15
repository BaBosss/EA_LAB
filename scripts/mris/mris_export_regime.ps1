# mris_export_regime.ps1 - ORDER-073 Phase-3: append today's MRIS macro state to the
# rolling regime timeline CSV that the (Boss)_MacroGate watchdog reads on the VPS.
#
# Reads  : portfolio/mris/regime_state.json  (written by mris_classify.ps1 each run)
# Appends: portfolio/EA_LAB_mris_regime.csv  (columns: datetime,state,ri,flags)
#          - one row per calendar day (UTC); a same-day re-run UPDATES that day's row
#          - rows kept strictly ascending (MacroGate fails INACTIVE on non-ascending)
#          - trimmed to the most recent $KeepRows days (default 400)
# Also copies the CSV to the local MT5 Common\Files (dev-box testing); the VPS copy is
# delivered by the same rclone path as the news CSV (see daily_monitor.ps1 / runbook).
#
# datetime is written as "yyyy.MM.dd HH:mm" in UTC. MacroGate's InpOffsetHours converts
# CSV-time -> broker-server-time; for a daily-granularity file 0 is fine (the as-of logic
# just picks the latest row <= now, and states persist for days). Set InpOffsetHours only
# if you later export intraday.
#
# ORDER-200 Phase D: -EnableCrisisFold (DEFAULT OFF) lets the advisory crisis models nudge
# the exported state. OFF = this file behaves exactly as before, byte-for-byte, so real
# accounts are untouched until the switch is deliberately flipped.
[CmdletBinding()]
param(
  [string]$StateJson = '',
  [string]$OutCsv    = '',
  [string]$CommonDir = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\Common\Files",
  [int]   $KeepRows  = 400,
  # DEFAULT OFF. When on, a crisis model at 'active' downgrades the exported state ONE notch.
  [switch]$EnableCrisisFold,
  [string]$CrisisJson = '',
  # fold policy (ladder / min_coverage / max_age_hours) lives in the crisis config so the
  # cost estimator reads the SAME numbers this exporter acts on
  [string]$FoldPolicyJson = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\repo_paths.ps1')
$RepoRoot = Resolve-EaLabRepoRoot -AnchorPath $PSCommandPath
if (-not $StateJson) { $StateJson = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'portfolio\mris\regime_state.json' }
if (-not $OutCsv) { $OutCsv = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'portfolio\EA_LAB_mris_regime.csv' }
if (-not $CrisisJson) { $CrisisJson = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'portfolio\mris\crisis_models_state.json' }
if (-not $FoldPolicyJson) { $FoldPolicyJson = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'scripts\mris\crisis_models.json' }
$ci = [System.Globalization.CultureInfo]::InvariantCulture

if (!(Test-Path $StateJson)) { Write-Host "[export-regime] state json NOT found: $StateJson"; exit 1 }

try {
  $st = Get-Content -Raw -LiteralPath $StateJson | ConvertFrom-Json
} catch {
  Write-Host "[export-regime] failed to parse $StateJson : $($_.Exception.Message)"; exit 1
}

# --- validate state against MacroGate's accepted vocabulary --------------------
$valid = @('RISK_ON','NEUTRAL','RISK_OFF','STRESS')
$state = ("" + $st.state).Trim().ToUpper()
if ($valid -notcontains $state) {
  Write-Host "[export-regime] state '$state' not in $($valid -join '/') - refusing to write (fail-safe)"; exit 1
}

# --- timestamp: parse generated_utc, fall back to now(UTC) --------------------
$dt = $null
if ($st.generated_utc) {
  try { $dt = [datetime]::Parse($st.generated_utc, $ci, [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal) } catch { $dt = $null }
}
if ($null -eq $dt) { $dt = (Get-Date).ToUniversalTime() }
$dayKey = $dt.ToString('yyyy.MM.dd', $ci)
$stamp  = $dt.ToString('yyyy.MM.dd HH:mm', $ci)

# --- ri + flags (flags flattened to a single ;-joined quoted field) ----------
$ri = 0.0
if ($null -ne $st.risk_index) { [double]::TryParse(("" + $st.risk_index), [ref]$ri) | Out-Null }
$riStr = $ri.ToString('0.###', $ci)
$flags = ""
if ($st.flags) { $flags = (($st.flags | ForEach-Object { ("" + $_) -replace '"','' -replace ',',';' }) -join ' | ') }

# --- ORDER-200 Phase D: optional crisis fold (DEFAULT OFF) --------------------
# IRON RULE: this may only ever make us MORE cautious, and only by ONE notch.
#   * downgrade ladder: RISK_ON -> NEUTRAL -> RISK_OFF. Stops there.
#   * it can NEVER manufacture STRESS. STRESS is the most drastic action MacroGate takes and
#     stays owned by the VALIDATED 8-barometer layer (VIX override / RI collapse). Nothing is
#     lost by capping: a genuinely covid-like tape already trips the core VIX stress override,
#     so the core would say STRESS on its own.
#   * it can NEVER upgrade a state. A false positive therefore costs missed profit, never
#     overexposure - the correct direction for the cheap mistake (user ratified 2026-07-25).
# Only 'active' (>=60) folds; 'forming' stays brief/alert-only, so noise cannot throttle lots.
if ($EnableCrisisFold) {
  if (!(Test-Path $CrisisJson)) {
    Write-Host "[export-regime] crisis fold ON but $CrisisJson missing - exporting core state unchanged (fail-safe)"
  } else {
    try {
      $cm = Get-Content -Raw -LiteralPath $CrisisJson -Encoding UTF8 | ConvertFrom-Json
      # policy (ladder / min_coverage / max_age_hours) is read from crisis_models.json so the
      # cost estimator cannot drift from what actually runs. Defaults keep old files working.
      $fp = $null
      try { $fp = (Get-Content -Raw -LiteralPath $FoldPolicyJson -Encoding UTF8 | ConvertFrom-Json).fold_policy } catch { $fp = $null }
      $minCov  = if ($fp -and $null -ne $fp.min_coverage)   { [double]$fp.min_coverage }   else { 0.5 }
      $maxAge  = if ($fp -and $null -ne $fp.max_age_hours)  { [double]$fp.max_age_hours }  else { 30 }
      $ladder = @{}
      if ($fp -and $fp.ladder) { foreach ($p in $fp.ladder.PSObject.Properties) { $ladder[$p.Name] = "$($p.Value)" } }
      else { $ladder = @{ 'RISK_ON' = 'NEUTRAL'; 'NEUTRAL' = 'RISK_OFF' } }

      # FRESHNESS GATE: the CSV is rewritten daily, so MacroGate's own file-age check always
      # sees a fresh file - it cannot detect that the crisis SCORES inside are days old (the
      # crisis stage is non-fatal in mris_run.ps1, so a broken feed leaves the old json in
      # place). Age-gate here, mirroring mris_classify.ps1's EffStatus discipline.
      $ageOk = $true; $ageTxt = "unknown"
      if ($cm.generated_utc) {
        $gd = [datetime]::MinValue
        if ([datetime]::TryParse("$($cm.generated_utc)", $ci, [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$gd)) {
          $ageH = ((Get-Date).ToUniversalTime() - $gd).TotalHours
          $ageTxt = ("{0:N1}h" -f $ageH)
          if ($ageH -gt $maxAge) { $ageOk = $false }
        } else { $ageOk = $false; $ageTxt = "unparseable" }
      } else { $ageOk = $false; $ageTxt = "absent" }

      $activeModels = @()
      if (-not $ageOk) {
        Write-Host "[export-regime] crisis fold SKIPPED - crisis state age $ageTxt exceeds ${maxAge}h (fail-safe: core state kept)"
      } else {
        foreach ($m in $cm.models) {
          # require a real score AND enough evidence behind it - a score computed from a
          # fraction of its components must not throttle live lots
          if ($null -ne $m.score -and "$($m.label)" -eq 'active' -and [double]$m.coverage -ge $minCov) {
            $activeModels += ("{0}={1}" -f $m.name, ([double]$m.score).ToString('0.#', $ci))
          }
        }
      }
      if ($activeModels.Count -gt 0) {
        if ($ladder.ContainsKey($state)) {
          $before = $state
          $state = $ladder[$state]
          # sanitize exactly like the core flags above (commas -> ';', quotes stripped). The
          # MQL reader IS quote-aware, but the original author stripped commas deliberately and
          # appending after that step would have quietly bypassed the guard.
          $note = ("CRISIS_FOLD: $before -> $state (" + ($activeModels -join '; ') + ")") -replace '"','' -replace ',',';'
          $flags = if ($flags) { "$flags | $note" } else { $note }
          Write-Host "[export-regime] crisis fold applied: $note"
        } else {
          Write-Host "[export-regime] crisis fold: state already $state - no downgrade available (fold never manufactures STRESS)"
        }
      } elseif ($ageOk) {
        Write-Host "[export-regime] crisis fold ON, no model active at coverage>=$minCov - core state kept"
      }
    } catch {
      Write-Host "[export-regime] crisis fold read failed - exporting core state unchanged (fail-safe): $($_.Exception.Message)"
    }
  }
}

# --- load existing rows (skip header), key by day, drop today's if re-run ------
$rows = @()   # each: [pscustomobject]@{ day=; line= }
if (Test-Path $OutCsv) {
  $existing = Get-Content -LiteralPath $OutCsv | Where-Object { $_ -and $_ -notmatch '^\s*datetime\s*,' }
  foreach ($ln in $existing) {
    $firstComma = $ln.IndexOf(',')
    if ($firstComma -lt 0) { continue }
    $dtok = $ln.Substring(0, $firstComma).Trim().Trim('"')
    $sp = $dtok.IndexOf(' ')
    $dkey = if ($sp -gt 0) { $dtok.Substring(0, $sp) } else { $dtok }
    if ($dkey -eq $dayKey) { continue }   # today re-run -> replace
    $rows += [pscustomobject]@{ day = $dkey; line = $ln }
  }
}

# --- append today, sort ascending by day, trim ------------------------------
$newLine = '{0},{1},{2},"{3}"' -f $stamp, $state, $riStr, $flags
$rows += [pscustomobject]@{ day = $dayKey; line = $newLine }
# @() wrap: Sort-Object returns a SCALAR for a single row, whose .Count is empty in PS 5.1
# (printed "wrote  row(s)" on a fresh file and would break the KeepRows compare).
$rows = @($rows | Sort-Object { [datetime]::ParseExact($_.day, 'yyyy.MM.dd', $ci) })
if ($rows.Count -gt $KeepRows) { $rows = @($rows | Select-Object -Last $KeepRows) }

# --- write atomically (header + ascending rows) ------------------------------
$outLines = @('datetime,state,ri,flags') + ($rows | ForEach-Object { $_.line })
$tmp = "$OutCsv.tmp"
Set-Content -LiteralPath $tmp -Value $outLines -Encoding UTF8
Move-Item -LiteralPath $tmp -Destination $OutCsv -Force
Write-Host "[export-regime] wrote $($rows.Count) row(s) -> $OutCsv (today: $stamp $state ri=$riStr)"

# --- mirror to local Common\Files for dev-box testing (non-fatal) ------------
if (Test-Path $CommonDir) {
  try {
    Copy-Item -LiteralPath $OutCsv -Destination (Join-Path $CommonDir 'EA_LAB_mris_regime.csv') -Force
    Write-Host "[export-regime] copied to Common\Files (dev)"
  } catch {
    Write-Host "[export-regime] Common\Files copy failed (non-fatal): $($_.Exception.Message)"
  }
}
exit 0
