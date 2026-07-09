# monitor_rotation.ps1 (v2 â€” matches user's per-account folder layout, 2026-07-09)
# D:\Monitor\<one folder per account>, each terminal ALREADY logged in (saved credentials,
# no passwords in any file). This script launches ALL of them concurrently in /portable mode
# with a startup-ini that auto-attaches the exporter to a fresh chart, waits ~5.5 min
# (exporter fires at 0s/+2m/+4m), then kills only D:\Monitor processes.
# PREREQ per folder: Exness-branded terminal + logged in once by the user.
# MT4 note: a ThinkMarkets-copied build cannot reach Exness servers until the matching
# Exness .srv files are placed in <folder>\config\ (copy from the VPS terminal) or the
# folder is replaced with a real Exness MT4 install.
$ErrorActionPreference = 'Continue'
$dwell = 420

$plan = @(
    @{ dir = 'D:\Monitor\MT5 - 159503454';  exe = 'terminal64.exe'; expert = 'DealsExporter';     symbol = 'EURUSDc' },
    @{ dir = 'D:\Monitor\MT5 - 159475669';  exe = 'terminal64.exe'; expert = 'DealsExporter';     symbol = 'EURUSDc' },
    @{ dir = 'D:\Monitor\MT5 - 415573666';  exe = 'terminal64.exe'; expert = 'DealsExporter';     symbol = 'EURUSDm' },
    @{ dir = 'D:\Monitor\MT4 - 141049900';  exe = 'terminal.exe';   expert = 'OrdersExporterMT4'; symbol = 'EURUSDc' },
    @{ dir = 'D:\Monitor\MT4 - 69424711';   exe = 'terminal.exe';   expert = 'OrdersExporterMT4'; symbol = 'EURUSDm' }
)

$procs = @()
foreach ($p in $plan) {
    $exe = Join-Path $p.dir $p.exe
    if (-not (Test-Path $exe)) { Write-Host "[SKIP] missing: $exe"; continue }
    $ini = Join-Path $p.dir 'monitor_startup.ini'
    if ($p.exe -eq 'terminal64.exe') {
        @("[StartUp]", "Expert=$($p.expert)", "Symbol=$($p.symbol)", "Period=H1") | Set-Content $ini -Encoding ASCII
        $procs += Start-Process -FilePath $exe -ArgumentList '/portable', "/config:$ini" -PassThru
    } else {
        @("Expert=$($p.expert)", "Symbol=$($p.symbol)", "Period=H1") | Set-Content $ini -Encoding ASCII
        $procs += Start-Process -FilePath $exe -ArgumentList '/portable', "`"$ini`"" -PassThru
    }
    Write-Host "[RUN] $($p.dir)"
}
if ($procs.Count -gt 0) {
    Start-Sleep -Seconds $dwell
    foreach ($pr in $procs) { if (-not $pr.HasExited) { Stop-Process -Id $pr.Id -Force -ErrorAction SilentlyContinue } }
    Start-Sleep -Seconds 5
}
Write-Host "rotation done ($($procs.Count) terminals)"
