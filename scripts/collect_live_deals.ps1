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
$found = Get-ChildItem (Join-Path $CommonFiles 'EA_LAB_deals_*.csv') -ErrorAction SilentlyContinue
if (-not $found) { Write-Host "no EA_LAB_deals_*.csv in $CommonFiles (exporter not attached yet?)"; exit 1 }
foreach ($f in $found) {
  $stamp = Get-Date -Format 'yyyyMMdd'
  $dest = Join-Path $DestDir ($f.BaseName + "_$stamp.csv")
  Copy-Item $f.FullName $dest -Force
  Write-Host "collected -> $dest ($([math]::Round($f.Length/1kb,1)) KB)"
}
exit 0
