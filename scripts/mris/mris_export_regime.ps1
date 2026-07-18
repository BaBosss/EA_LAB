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
[CmdletBinding()]
param(
  [string]$StateJson = "D:\EA_LAB\portfolio\mris\regime_state.json",
  [string]$OutCsv    = "D:\EA_LAB\portfolio\EA_LAB_mris_regime.csv",
  [string]$CommonDir = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\Common\Files",
  [int]   $KeepRows  = 400
)
$ErrorActionPreference = 'Stop'
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
$rows = $rows | Sort-Object { [datetime]::ParseExact($_.day, 'yyyy.MM.dd', $ci) }
if ($rows.Count -gt $KeepRows) { $rows = $rows | Select-Object -Last $KeepRows }

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
