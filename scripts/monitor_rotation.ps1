# monitor_rotation.ps1 - rotate read-only investor logins through 2 monitor terminals,
# letting DealsExporter/OrdersExporterMT4 snapshot each account's history to Common\Files.
# Called by daily_monitor.ps1 (scheduled 07:30). Design: user keeps NOTHING running;
# each account gets ~5.5 min of terminal life (export fires at 0s/+2m/+4m via boot-ticks).
# Configs (with investor passwords, user-maintained) live OUTSIDE the repo: D:\Monitor\configs\*.ini
# Skips any config whose Password= line is still blank.
$ErrorActionPreference = 'Continue'
$mt5exe = 'D:\Monitor\MT5\terminal64.exe'
$mt4exe = 'D:\Monitor\MT4\terminal.exe'
$cfgDir = 'D:\Monitor\configs'
$dwell  = 330   # seconds per account

function Has-Password([string]$ini) {
    $line = Select-String -Path $ini -Pattern '^Password=(.+)$'
    return ($null -ne $line)
}

foreach ($cfg in (Get-ChildItem $cfgDir -Filter '*.ini' | Sort-Object Name)) {
    if (-not (Has-Password $cfg.FullName)) { Write-Host "[SKIP] no password yet: $($cfg.Name)"; continue }
    $isMT5 = $cfg.Name -like 'mt5_*'
    $exe = if ($isMT5) { $mt5exe } else { $mt4exe }
    if (-not (Test-Path $exe)) { Write-Host "[SKIP] missing terminal: $exe"; continue }
    Write-Host "[RUN] $($cfg.Name)"
    if ($isMT5) {
        $p = Start-Process -FilePath $exe -ArgumentList '/portable', "/config:$($cfg.FullName)" -PassThru
    } else {
        $p = Start-Process -FilePath $exe -ArgumentList '/portable', "`"$($cfg.FullName)`"" -PassThru
    }
    Start-Sleep -Seconds $dwell
    if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 10   # let the process release files before next launch
}
Write-Host "rotation done"
