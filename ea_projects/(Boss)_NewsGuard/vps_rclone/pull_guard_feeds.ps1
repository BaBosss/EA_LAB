# VPS-side pull for NewsGuard + MacroGate feeds.
# Fetches into private staging, validates each selected feed, then atomically replaces only valid files.
[CmdletBinding()]
param(
  [string]$RcloneExe = 'C:\rclone\rclone.exe',
  [string]$RcloneConfig = 'C:\rclone\rclone.conf',
  [string]$RemoteDir = 'onedrive:EA_LAB_VPS_SYNC/lab-to-vps/news',
  [string]$LocalStagingDir = 'C:\rclone\staging\lab-to-vps\news',
  [string]$CommonDir = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files',
  [string]$LogFile = 'C:\rclone\logs\pull_guard_feeds.log',
  [int]$NewsMaxAgeHours = 26,
  [int]$RegimeMaxAgeHours = 36,
  [switch]$RegimeOnly,
  [switch]$SkipFetch
)
$ErrorActionPreference = 'Stop'
$ci = [Globalization.CultureInfo]::InvariantCulture
$failures = @()

function Log([string]$Message) {
  $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
  Write-Host $line
  $dir = Split-Path -Parent $LogFile
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  Add-Content -LiteralPath $LogFile -Value $line
}
function Test-NewsFeed([string]$Path) {
  $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
  if ($lines.Count -lt 2) { throw 'news feed has no data rows' }
  if ($lines[0] -notmatch 'BkkTime' -or $lines[0] -notmatch 'Currency' -or $lines[0] -notmatch 'Title') { throw 'news header mismatch' }
  $events = 0
  foreach ($line in $lines[1..($lines.Count-1)]) {
    if ($line -match '^"?(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2})"?,') { $events++ }
  }
  if ($events -lt 1) { throw 'news feed has zero parseable events' }
  return $events
}

function Test-RegimeFeed([string]$Path) {
  $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
  if ($lines.Count -lt 2) { throw 'regime feed has no data rows' }
  if ($lines[0] -notmatch '^\s*datetime\s*,\s*state\s*,\s*ri(?:\s*,|$)') { throw 'regime header mismatch' }
  $prev = $null; $rows = 0
  foreach ($line in $lines[1..($lines.Count-1)]) {
    if ($line -notmatch '^"?(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2})"?,(RISK_ON|NEUTRAL|RISK_OFF|STRESS),') { continue }
    $dt = [datetime]::ParseExact($Matches[1], 'yyyy.MM.dd HH:mm', $ci)
    if ($null -ne $prev -and $dt -lt $prev) { throw 'regime rows are not ascending' }
    $prev = $dt; $rows++
  }
  if ($rows -lt 1) { throw 'regime feed has zero valid rows' }
  return $rows
}
function Publish-Staged([string]$Label,[string]$Name,[int]$MaxAgeHours,[scriptblock]$Validator) {
  try {
    $src = Join-Path $LocalStagingDir $Name
    if (-not (Test-Path -LiteralPath $src)) { throw "staged file missing: $src" }
    $f = Get-Item -LiteralPath $src
    $ageH = ((Get-Date) - $f.LastWriteTime).TotalHours
    if ($f.Length -lt 20) { throw "staged file only $($f.Length) bytes" }
    if ($ageH -gt $MaxAgeHours) { throw ("staged file is {0:N1} h old (> {1} h)" -f $ageH,$MaxAgeHours) }
    $count = & $Validator $src
    if (-not (Test-Path -LiteralPath $CommonDir)) { New-Item -ItemType Directory -Path $CommonDir -Force | Out-Null }
    $tmp = Join-Path $CommonDir ($Name + '.tmp')
    $final = Join-Path $CommonDir $Name
    Copy-Item -LiteralPath $src -Destination $tmp -Force
    if ((Get-Item -LiteralPath $tmp).Length -ne $f.Length) { throw "short write to $tmp" }
    & $Validator $tmp | Out-Null
    Move-Item -LiteralPath $tmp -Destination $final -Force
    Log ("OK [$Label] rows=$count age={0:N1}h -> $final" -f $ageH)
  } catch {
    $script:failures += $Label
    Log "FAILED [$Label]: $($_.Exception.Message); last-good Common file retained"
  }
}

if (-not $SkipFetch) {
  try {
    if (-not (Test-Path -LiteralPath $RcloneExe)) { throw "rclone not found: $RcloneExe" }
    if (-not (Test-Path -LiteralPath $LocalStagingDir)) { New-Item -ItemType Directory -Path $LocalStagingDir -Force | Out-Null }
    # Remove only selected staged targets before fetch so a remote-missing file cannot masquerade
    # as a fresh fetch from a previous pass. Common\Files last-good copies are never removed here.
    $selectedNames = if ($RegimeOnly) { @('EA_LAB_mris_regime.csv') } else { @('EA_LAB_news_week.csv','EA_LAB_mris_regime.csv') }
    foreach ($name in $selectedNames) {
      $oldStage = Join-Path $LocalStagingDir $name
      if (Test-Path -LiteralPath $oldStage) { Remove-Item -LiteralPath $oldStage -Force }
    }
    if ($RegimeOnly) {
      & $RcloneExe copy $RemoteDir $LocalStagingDir --config $RcloneConfig `
        --include 'EA_LAB_mris_regime.csv' --min-size 1 --log-level INFO --log-file $LogFile
    } else {
      & $RcloneExe copy $RemoteDir $LocalStagingDir --config $RcloneConfig `
        --include 'EA_LAB_news_week.csv' --include 'EA_LAB_mris_regime.csv' --min-size 1 --log-level INFO --log-file $LogFile
    }
    if ($LASTEXITCODE -ne 0) { throw "rclone copy exit $LASTEXITCODE" }
    Log 'rclone fetch OK'
  } catch {
    Log "rclone fetch FAILED: $($_.Exception.Message)"
    exit 1
  }
}

if (-not $RegimeOnly) {
  Publish-Staged 'NewsGuard' 'EA_LAB_news_week.csv' $NewsMaxAgeHours ${function:Test-NewsFeed}
}
Publish-Staged 'MacroGate' 'EA_LAB_mris_regime.csv' $RegimeMaxAgeHours ${function:Test-RegimeFeed}

if ($failures.Count -gt 0) {
  Log "guard feed pull FAILED feed(s): $($failures -join ', ')"
  exit 1
}
if ($RegimeOnly) {
  Log 'guard feed pull COMPLETE: MacroGate regime-only feed validated and published atomically'
} else {
  Log 'guard feed pull COMPLETE: both feeds validated and published atomically'
}
exit 0
