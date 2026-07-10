<#
collect_live_deals.ps1 - pick up DealsExporter CSV snapshots (ORDER-039).

DealsExporter.mq5 (attached on the monitored terminal) writes
  <Common>\Files\EA_LAB_deals_<login>.csv  nightly.
This script copies every such file into the repo with a date stamp so
/ea-monitor can read them and git keeps the audit trail.

  powershell -File scripts\collect_live_deals.ps1
#>
[CmdletBinding()]
param(
  [string]$CommonFiles = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\Common\Files",
  [string]$DestDir = "D:\EA_LAB\portfolio\live_deals"
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $DestDir)) { New-Item -ItemType Directory -Force $DestDir | Out-Null }
$found = @()
$found += Get-ChildItem (Join-Path $CommonFiles 'EA_LAB_deals_*.csv') -ErrorAction SilentlyContinue
$found += Get-ChildItem (Join-Path $CommonFiles 'EA_LAB_mt4_orders_*.csv') -ErrorAction SilentlyContinue
if (-not $found) { Write-Host "no EA_LAB_deals_*/EA_LAB_mt4_orders_*.csv in $CommonFiles (exporter not attached yet?)"; exit 1 }
# login=0 = terminal was not authorized when the exporter fired -> empty garbage, never collect
foreach ($s in ($found | Where-Object { $_.BaseName -match '_0$' })) { Write-Host "skipped (login=0, terminal not authorized): $($s.Name)" }
$found = @($found | Where-Object { $_.BaseName -notmatch '_0$' })
if (-not $found) { Write-Host "nothing left after login=0 filter"; exit 1 }
# CODEX-AUDIT A4 (2026-07-11): never relabel a stale exporter file as today's snapshot.
# Rotation rewrites every exporter CSV nightly, so a source older than 30h means the
# rotation/exporter for that account is DEAD - copying it under today's date would hide that.
$staleH = 30
$fresh = 0
foreach ($f in $found) {
  $ageH = ((Get-Date) - $f.LastWriteTime).TotalHours
  if ($ageH -gt $staleH) {
    Write-Host ("SKIPPED-STALE: {0} last written {1:yyyy-MM-dd HH:mm} ({2:n1} h ago > {3} h) - exporter/rotation dead for this account?" -f $f.Name, $f.LastWriteTime, $ageH, $staleH) -ForegroundColor Yellow
    continue
  }
  $stamp = Get-Date -Format 'yyyyMMdd'
  $dest = Join-Path $DestDir ($f.BaseName + "_$stamp.csv")
  Copy-Item $f.FullName $dest -Force
  $fresh++
  Write-Host "collected -> $dest ($([math]::Round($f.Length/1kb,1)) KB)"
}
if ($fresh -eq 0) { Write-Host "no FRESH exporter file collected (all stale or missing)"; exit 1 }
exit 0
