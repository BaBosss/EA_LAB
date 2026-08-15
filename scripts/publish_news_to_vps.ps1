# publish_news_to_vps.ps1 - validate portfolio\news_week.csv, then publish it atomically to
# (1) the LOCAL MetaQuotes Common\Files  and  (2) the OneDrive lab-to-vps staging folder that
# the VPS pulls with rclone (ea_projects\(Boss)_NewsGuard\vps_rclone\pull_news.cmd).
#
# Why this exists (2026-07-28): daily_monitor.ps1 copied the CSV to the LOCAL Common\Files only.
# The OneDrive staging folder was never created and no lab-side push was ever written, so every
# NewsGuard instance on the VPS ran on a missing/stale feed and sat INACTIVE (fail-safe) - the
# guarded EAs were unprotected while the lab looked green. See AGENT_TASKBOARD ORDER-083 finding.
#
# Contract (VPS_TRANSPORT_AND_ATTACH.md "Scheduled copy: lab to VPS"): never replace the last
# good file with an empty or malformed one -> validate first, write .tmp, then rename in place.
# One writer per direction: the lab only ever writes lab-to-vps\news.
[CmdletBinding()]
param(
  [string]$SrcCsv     = '',
  [string]$CommonDir  = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\Common\Files',
  [string]$StagingDir = 'C:\Users\patip\OneDrive\EA_LAB_VPS_SYNC\lab-to-vps\news',
  [string]$DestName   = 'EA_LAB_news_week.csv',
  [int]   $MaxAgeHours = 26
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\repo_paths.ps1')
$RepoRoot = Resolve-EaLabRepoRoot -AnchorPath $PSCommandPath
if (-not $SrcCsv) { $SrcCsv = Get-EaLabPath -RepoRoot $RepoRoot -RelativePath 'portfolio\news_week.csv' }

function Fail([string]$msg) { Write-Host "publish-news FAILED: $msg"; exit 1 }

# ---- validate the source before anything is published ---------------------
if (-not (Test-Path -LiteralPath $SrcCsv)) { Fail "source not found: $SrcCsv" }
$src = Get-Item -LiteralPath $SrcCsv
$ageH = ((Get-Date) - $src.LastWriteTime).TotalHours
if ($src.Length -lt 50)    { Fail "source is $($src.Length) bytes - refusing to publish" }
if ($ageH -gt $MaxAgeHours) { Fail ("source is {0:N1} h old (> {1} h) - keeping last good copy" -f $ageH, $MaxAgeHours) }

$lines = @(Get-Content -LiteralPath $SrcCsv -Encoding UTF8)
if ($lines.Count -lt 2) { Fail 'source has no data rows' }
if ($lines[0] -notmatch 'BkkTime' -or $lines[0] -notmatch 'Currency' -or $lines[0] -notmatch 'Title') {
    Fail "header does not match the NewsGuard feed format: $($lines[0])"
}
# NewsGuard parses column 1 as 'yyyy.MM.dd HH:mm'; a file whose rows it cannot parse loads as
# ZERO events and puts the guard INACTIVE just like a missing file. Prove at least one parses.
$events = 0
foreach ($l in $lines[1..($lines.Count - 1)]) {
    if ($l -match '^"?(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2})"?,') { $events++ }
}
if ($events -lt 1) { Fail 'no row parses as a yyyy.MM.dd HH:mm event - NewsGuard would load 0 events' }

# ---- publish: .tmp in the destination folder, then rename (atomic on NTFS) --
$published = @()
foreach ($dir in @($CommonDir, $StagingDir)) {
    try {
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $tmp   = Join-Path $dir ($DestName + '.tmp')
        $final = Join-Path $dir $DestName
        Copy-Item -LiteralPath $SrcCsv -Destination $tmp -Force
        if ((Get-Item -LiteralPath $tmp).Length -ne $src.Length) { Fail "short write to $tmp" }
        Move-Item -LiteralPath $tmp -Destination $final -Force
        $published += $dir
    } catch {
        Fail "publish to '$dir': $($_.Exception.Message)"
    }
}
Write-Host ("publish-news OK: {0} event row(s), source {1:N1} h old -> {2}" -f $events, $ageH, ($published -join ' | '))
exit 0
