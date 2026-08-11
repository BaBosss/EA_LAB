<#
collect_live_deals.ps1 - pick up DealsExporter CSV snapshots (ORDER-039).

DealsExporter.mq5 (attached on the monitored terminal) writes
  <Common>\Files\EA_LAB_deals_<login>.csv  nightly.
This script copies every such file into the repo with a date stamp so
/ea-monitor can read them and git keeps the audit trail.

ORDER-092 addition: also collects EA_LAB_snapshot_<login>.csv written by
AccountSnapshotExporter (floating-risk telemetry, rewritten every 60s while
attached). Snapshot collection is ADDITIVE - it never changes the exit code,
which stays keyed to the closed-history exporters exactly as before.

  powershell -File scripts\collect_live_deals.ps1
#>
[CmdletBinding()]
param(
  [string]$CommonFiles = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\Common\Files",
  [string]$DestDir = "D:\EA_LAB\portfolio\live_deals"
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $DestDir)) { New-Item -ItemType Directory -Force $DestDir | Out-Null }

# ---------------------------------------------------------------------------
# ORDER-092: floating-risk snapshots (AccountSnapshotExporter.mq5/.mq4) FIRST,
# so they are collected even when the closed-history exporters have nothing
# (e.g. a VPS terminal running only the snapshot exporter). Same 30h stale
# guard as the deals section below (rotation-mode lower bound - do NOT weaken).
# Freshness note: unlike the nightly deals exporters, the snapshot exporter
# rewrites its file every 60s while attached, so on an always-on VPS terminal
# even a few HOURS of age already means the exporter/terminal is down. We print
# the age so the log shows it; the dashboard greys anything older than 26h.
# This section never changes the script's exit code (deals guard semantics
# below are the contract daily_monitor.ps1 depends on).
# ---------------------------------------------------------------------------
$snapStaleH = 30
$snaps = @(Get-ChildItem (Join-Path $CommonFiles 'EA_LAB_snapshot_*.csv') -ErrorAction SilentlyContinue |
           Where-Object { $_.Extension -eq '.csv' })
foreach ($s in @($snaps | Where-Object { $_.BaseName -notmatch '^EA_LAB_snapshot_[1-9]\d*$' })) {
  Write-Host "snapshot skipped (login=0/TEST/garbage name): $($s.Name)"
}
$snaps = @($snaps | Where-Object { $_.BaseName -match '^EA_LAB_snapshot_[1-9]\d*$' })
if (-not $snaps) {
  Write-Host "no EA_LAB_snapshot_*.csv in $CommonFiles (AccountSnapshotExporter not attached yet - floating risk stays blind)"
} else {
  foreach ($f in $snaps) {
    $ageH = ((Get-Date) - $f.LastWriteTime).TotalHours
    if ($ageH -gt $snapStaleH) {
      Write-Host ("SKIPPED-STALE: {0} last written {1:yyyy-MM-dd HH:mm} ({2:n1} h ago > {3} h) - snapshot exporter/terminal dead for this account?" -f $f.Name, $f.LastWriteTime, $ageH, $snapStaleH) -ForegroundColor Yellow
      continue
    }
    $stamp = Get-Date -Format 'yyyyMMdd'
    $dest = Join-Path $DestDir ($f.BaseName + "_$stamp.csv")
    Copy-Item $f.FullName $dest -Force
    Write-Host ("collected snapshot -> {0} (age {1:n1} h; exporter rewrites every 60s when attached)" -f $dest, $ageH)
  }
}

# Runtime identity sidecars (VPS DEMO / Forward-Test identity blocker). These are the
# per-chart records emitted by the EA itself. Collection is additive: a missing or malformed
# sidecar is carried as a monitoring finding later, never silently upgraded to healthy here.
$identityFiles = @(Get-ChildItem (Join-Path $CommonFiles 'EA_LAB_identity_*.json') -ErrorAction SilentlyContinue)
$identityStaleH = 30  # canonical collector freshness bar; keep aligned with runtime_identity.py
$identityFutureToleranceMinutes = 5
if (-not $identityFiles) {
  Write-Host "no EA_LAB_identity_*.json in $CommonFiles (runtime identity not attached yet)"
} else {
  foreach ($f in $identityFiles) {
    if ($f.Name -notmatch '^EA_LAB_identity_[1-9]\d*_[1-9]\d*\.json$') {
      Write-Host "identity skipped (invalid login/magic filename): $($f.Name)" -ForegroundColor Yellow
      continue
    }
    try {
      $doc = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
      if ($doc.schema -ne 'runtime_identity/1' -or -not $doc.account_login -or -not $doc.magic) {
        throw 'missing runtime identity schema/login/magic'
      }
      $producerTime = [datetime]::MinValue
      try { $producerTime = [datetime]::Parse([string]$doc.evidence_timestamp) }
      catch { throw 'invalid producer evidence_timestamp' }
      $ageH = ((Get-Date) - $producerTime).TotalHours
      if ($ageH -gt $identityStaleH) {
        Write-Host ("identity skipped (STALE producer timestamp): {0} ({1:n1} h ago > {2} h)" -f $f.Name,$ageH,$identityStaleH) -ForegroundColor Yellow
        continue
      }
      if ($ageH -lt -($identityFutureToleranceMinutes / 60.0)) {
        Write-Host ("identity skipped (FUTURE producer timestamp): {0} ({1:n1} h ahead > {2} min)" -f $f.Name,-$ageH,$identityFutureToleranceMinutes) -ForegroundColor Yellow
        continue
      }
    } catch {
      Write-Host "identity skipped (malformed/unreadable): $($f.Name) :: $($_.Exception.Message)" -ForegroundColor Red
      continue
    }
    $stamp = Get-Date -Format 'yyyyMMdd'
    $dest = Join-Path $DestDir ($f.BaseName + "_$stamp.json")
    # The date in the archive filename is collection provenance only. Copy the producer JSON
    # byte-for-byte so evidence_timestamp remains the authoritative producer time.
    Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
    Write-Host "collected runtime identity -> $dest"
  }
}

$found = @()
$found += Get-ChildItem (Join-Path $CommonFiles 'EA_LAB_deals_*.csv') -ErrorAction SilentlyContinue
$found += Get-ChildItem (Join-Path $CommonFiles 'EA_LAB_mt4_orders_*.csv') -ErrorAction SilentlyContinue
if (-not $found) { Write-Host "no EA_LAB_deals_*/EA_LAB_mt4_orders_*.csv in $CommonFiles (exporter not attached yet?)"; exit 1 }
# login=0 = terminal was not authorized when the exporter fired -> empty garbage, never collect
foreach ($s in ($found | Where-Object { $_.BaseName -match '_0$' })) { Write-Host "skipped (login=0, terminal not authorized): $($s.Name)" }
$found = @($found | Where-Object { $_.BaseName -notmatch '_0$' })
if (-not $found) { Write-Host "nothing left after login=0 filter"; exit 1 }
# 2026-07-11: header-only file = a Strategy-Tester login (e.g. 146237 = MT5 backtest terminal)
# that rotation authenticated but has ZERO trade history -> phantom account on the dashboard.
# A real live account always has >=1 deal row. Skip files whose only line is the header.
foreach ($s in ($found | Where-Object { @(Get-Content $_.FullName -TotalCount 2).Count -lt 2 })) {
  Write-Host "skipped (header-only, no deal rows - tester/empty login): $($s.Name)" -ForegroundColor DarkGray
}
$found = @($found | Where-Object { @(Get-Content $_.FullName -TotalCount 2).Count -ge 2 })
if (-not $found) { Write-Host "nothing left after header-only filter"; exit 1 }
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
