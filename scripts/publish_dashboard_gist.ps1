# publish_dashboard_gist.ps1 - push LIVE_DASHBOARD.html to a SECRET GitHub gist for phone viewing.
# First run (BY THE USER - creates the gist, this is the explicit publish consent step):
#   powershell -File D:\EA_LAB\scripts\publish_dashboard_gist.ps1
# It saves the gist id OUTSIDE the repo (D:\Monitor\dashboard_gist_id.txt); every later run
# (incl. the daily_monitor 07:30 chain) just updates the same gist -> same phone URL forever.
# Security note: a secret gist is unlisted, not private - anyone holding the link can view.
# The dashboard contains account numbers + P&L (no credentials).
[CmdletBinding()]
param(
  [string]$Dashboard = "D:\EA_LAB\portfolio\LIVE_DASHBOARD.html",
  [string]$IdFile    = "D:\Monitor\dashboard_gist_id.txt"
)
$ErrorActionPreference = "Stop"
$tmp = Join-Path $env:TEMP "dashboard.html"
Copy-Item $Dashboard $tmp -Force

if (-not (Test-Path $IdFile)) {
  $out = gh gist create $tmp --desc "EA_LAB live portfolio dashboard (auto-updated daily 07:30)"
  if ($LASTEXITCODE -ne 0) { Write-Host "gist create FAILED (gh exit $LASTEXITCODE): $out"; exit 1 }
  $url = ($out | Select-String 'https://gist.github.com/\S+').Matches.Value
  if (-not $url) { throw "gist create failed: $out" }
  $id = ($url -split '/')[-1]
  Set-Content $IdFile $id -Encoding ASCII
  $user = (gh api user --jq .login)
  Write-Host "gist created: $url"
  Write-Host ""
  Write-Host ">>> PHONE URL (bookmark this):"
  Write-Host ">>> https://gist.githack.com/$user/$id/raw/dashboard.html"
} else {
  $id = (Get-Content $IdFile -TotalCount 1).Trim()
  gh gist edit $id $tmp -f dashboard.html
  # gh is a native exe: a 401/network failure does NOT trip $ErrorActionPreference=Stop,
  # so without this check the script prints "updated" and exits 0 on a dead publish
  # (Codex system review 2026-07-18, ORDER-128).
  if ($LASTEXITCODE -ne 0) { Write-Host "gist $id update FAILED (gh exit $LASTEXITCODE)"; exit 1 }
  Write-Host "gist $id updated $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
}
