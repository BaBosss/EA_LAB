# monitor_rotation.ps1 (v2 â€” matches user's per-account folder layout, 2026-07-09)
# D:\Monitor\<one folder per account>, each terminal ALREADY logged in (saved credentials,
# no passwords in any file). This script launches ALL of them concurrently in /portable mode
# with a startup-ini that auto-attaches the exporter to a fresh chart, waits ~5.5 min
# (exporter fires at 0s/+2m/+4m), then kills only D:\Monitor processes.
# CR-P0 (2026-07-26): DealsExporter/OrdersExporterMT4 now ALSO emit the floating-risk
# snapshot (EA_LAB_snapshot_<login>.csv) in the same EA - so attaching this one expert
# covers both the closed-deal history AND open-position risk. No second EA needed; the
# standalone AccountSnapshotExporter is redundant on monitor terminals.
# PREREQ per folder: Exness-branded terminal + logged in once by the user.
# MT4 note: a ThinkMarkets-copied build cannot reach Exness servers until the matching
# Exness .srv files are placed in <folder>\config\ (copy from the VPS terminal) or the
# folder is replaced with a real Exness MT4 install.
# 2026-07-27 (ORDER-400): the startup .ini must live in a SPACE-FREE path. When a terminal
# self-updates (LiveUpdate) it relaunches itself and re-emits its own command line, but it does
# NOT re-quote /config - so "D:\Monitor\MT5 - 415573666\monitor_startup.ini" got truncated at the
# first space to "D:\Monitor\MT5" (a real folder, so MT5 reported "successfully initialized" and
# silently attached NO expert). That is why 415573666 produced no snapshot on 2026-07-27: it was
# update day, not a broken EA. Keeping the .ini under D:\Monitor\startup_ini\ removes the space.
$ErrorActionPreference = 'Continue'
$dwell = 420
$iniDir = 'D:\Monitor\startup_ini'
if (-not (Test-Path $iniDir)) { New-Item -ItemType Directory -Path $iniDir | Out-Null }

$plan = @(
    @{ dir = 'D:\Monitor\MT5 - 159503454';  exe = 'terminal64.exe'; expert = 'DealsExporter';     symbol = 'EURUSDc' },
    @{ dir = 'D:\Monitor\MT5 - 159475669';  exe = 'terminal64.exe'; expert = 'DealsExporter';     symbol = 'EURUSDc' },
    @{ dir = 'D:\Monitor\MT5 - 415573666';  exe = 'terminal64.exe'; expert = 'DealsExporter';     symbol = 'EURUSDm' },
    @{ dir = 'D:\Monitor\MT4 - 141049900';  exe = 'terminal.exe';   expert = 'OrdersExporterMT4'; symbol = 'EURUSDc' },
    @{ dir = 'D:\Monitor\MT4 - 69424711';   exe = 'terminal.exe';   expert = 'OrdersExporterMT4'; symbol = 'EURUSDm' },
    # CR-002 sensor gap (2026-07-19): pre-registered entries. They [SKIP] gracefully until the
    # user creates the folder (copy an Exness terminal of the right platform + log in ONCE with
    # saved credentials). 463666728 = Demo bundle 10 on VPS - 14+ ACTIVE candidates currently
    # BLIND for judge evidence (judge 2026-10). 146237 = Exness user-pool demo, stale since 07-06.
    @{ dir = 'D:\Monitor\MT5 - 463666728';  exe = 'terminal64.exe'; expert = 'DealsExporter';     symbol = 'EURUSDm' },
    @{ dir = 'D:\Monitor\MT5 - 146237';     exe = 'terminal64.exe'; expert = 'DealsExporter';     symbol = 'EURUSDm' }
)

# 2026-07-27 (ORDER-400): kill by EXECUTABLE PATH, not by the pid we launched. When a terminal
# self-updates it exits and relaunches itself as a NEW pid; the pid in $procs is then already gone
# and Stop-Process kills nothing, so the update-relaunched terminal leaks. One such orphan
# (415573666, pid 20716) had been running 3h20m when this was found - and a live instance makes
# every later launch of that same folder exit immediately, so the account stays blind until reboot.
# Path-scoped so only D:\Monitor terminals are touched; the user's own trading terminals are safe.
function Stop-MonitorTerminals {
    $killed = 0
    foreach ($mp in @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe' OR Name='terminal.exe'" -ErrorAction SilentlyContinue)) {
        if ($mp.ExecutablePath -and $mp.ExecutablePath.StartsWith('D:\Monitor\', [StringComparison]::OrdinalIgnoreCase)) {
            Stop-Process -Id $mp.ProcessId -Force -ErrorAction SilentlyContinue
            $killed++
        }
    }
    return $killed
}

# Sweep leftovers BEFORE launching: an orphan from a previous rotation would otherwise silently
# swallow this run's launch (MT5 hands off to the existing instance and exits 0).
$pre = Stop-MonitorTerminals
if ($pre -gt 0) { Write-Host "[SWEEP] stopped $pre leftover monitor terminal(s) before launch"; Start-Sleep -Seconds 5 }

$procs = @()
foreach ($p in $plan) {
    $exe = Join-Path $p.dir $p.exe
    if (-not (Test-Path $exe)) { Write-Host "[SKIP] missing: $exe"; continue }
    $ini = Join-Path $iniDir ("{0}.ini" -f (Split-Path $p.dir -Leaf).Replace(' ', '_'))
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
    $n = Stop-MonitorTerminals
    Write-Host "[STOP] stopped $n monitor terminal(s)"
    Start-Sleep -Seconds 5
}
Write-Host "rotation done ($($procs.Count) terminals)"
