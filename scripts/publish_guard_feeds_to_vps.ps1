# Publish validated NewsGuard + MacroGate feeds to local Common\Files and VPS staging.
# Each feed is independent: a bad feed never overwrites its last-good copy and does not
# prevent the other valid feed from publishing. Any failed feed still makes the step red.
[CmdletBinding()]
param(
  [string]$NewsCsv = '',
  [string]$RegimeCsv = '',
  [string]$CommonDir = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\Common\Files',
  [string]$StagingDir = 'C:\Users\patip\OneDrive\EA_LAB_VPS_SYNC\lab-to-vps\news',
  [int]$NewsMaxAgeHours = 26,
  [int]$RegimeMaxAgeHours = 30
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\repo_paths.ps1')
$RepoRoot = Resolve-EaLabRepoRoot -AnchorPath $PSCommandPath
if (-not $NewsCsv) { $NewsCsv = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'portfolio\news_week.csv' }
if (-not $RegimeCsv) { $RegimeCsv = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'portfolio\EA_LAB_mris_regime.csv' }
$ci = [Globalization.CultureInfo]::InvariantCulture
$failures = @()

function Get-FreshSource([string]$Path, [int]$MaxAgeHours, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "$Label source not found: $Path" }
  $f = Get-Item -LiteralPath $Path
  $ageH = ((Get-Date) - $f.LastWriteTime).TotalHours
  if ($f.Length -lt 20) { throw "$Label source is only $($f.Length) bytes" }
  if ($ageH -gt $MaxAgeHours) { throw ("$Label source is {0:N1} h old (> {1} h)" -f $ageH,$MaxAgeHours) }
  return [pscustomobject]@{ File=$f; AgeHours=$ageH }
}
function Test-NewsFeed([string]$Path) {
  $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
  if ($lines.Count -lt 2) { throw 'news feed has no data rows' }
  if ($lines[0] -notmatch 'BkkTime' -or $lines[0] -notmatch 'Currency' -or $lines[0] -notmatch 'Title') {
    throw "news header mismatch: $($lines[0])"
  }
  $events = 0
  foreach ($line in $lines[1..($lines.Count-1)]) {
    if ($line -match '^"?(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2})"?,') { $events++ }
  }
  if ($events -lt 1) { throw 'news feed has zero parseable yyyy.MM.dd HH:mm events' }
  return $events
}

function Test-RegimeFeed([string]$Path) {
  $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
  if ($lines.Count -lt 2) { throw 'regime feed has no data rows' }
  if ($lines[0] -notmatch '^\s*datetime\s*,\s*state\s*,\s*ri(?:\s*,|$)') { throw "regime header mismatch: $($lines[0])" }
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
function Publish-One([string]$Label,[string]$Source,[string]$DestName,[int]$MaxAgeHours,[scriptblock]$Validator) {
  try {
    $meta = Get-FreshSource $Source $MaxAgeHours $Label
    $count = & $Validator $Source
    foreach ($dir in @($CommonDir,$StagingDir)) {
      if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
      $tmp = Join-Path $dir ($DestName + '.tmp')
      $final = Join-Path $dir $DestName
      Copy-Item -LiteralPath $Source -Destination $tmp -Force
      if ((Get-Item -LiteralPath $tmp).Length -ne $meta.File.Length) { throw "short write to $tmp" }
      & $Validator $tmp | Out-Null
      Move-Item -LiteralPath $tmp -Destination $final -Force
    }
    Write-Host ("publish-guards OK: {0} rows={1} age={2:N1}h -> Common + staging" -f $Label,$count,$meta.AgeHours)
  } catch {
    $script:failures += $Label
    Write-Host "publish-guards FAILED [$Label]: $($_.Exception.Message)"
  }
}

Publish-One 'NewsGuard' $NewsCsv 'EA_LAB_news_week.csv' $NewsMaxAgeHours ${function:Test-NewsFeed}
Publish-One 'MacroGate' $RegimeCsv 'EA_LAB_mris_regime.csv' $RegimeMaxAgeHours ${function:Test-RegimeFeed}

if ($failures.Count -gt 0) {
  Write-Host "publish-guards FAILED feed(s): $($failures -join ', ')"
  exit 1
}
Write-Host 'publish-guards COMPLETE: both feeds validated and published atomically'
exit 0
