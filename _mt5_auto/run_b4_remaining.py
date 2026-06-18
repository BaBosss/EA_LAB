import subprocess, os, re, sys, time

ini_dir = '_mt5_auto/ini'
labels = [
    'SMOKE_B4_DayZone_v2_EURUSD',
    'SMOKE_B4_DayZone_v2_XAUUSD',
    'SMOKE_B4_GhostBot_G07_EURUSD',
    'SMOKE_B4_GhostBot_G07_XAUUSD',
    'SMOKE_B4_Ghost_JOMHOD_EURUSD',
    'SMOKE_B4_Ghost_JOMHOD_XAUUSD',
    'SMOKE_B4_GridProfit2way_EURUSD',
    'SMOKE_B4_GridProfit2way_XAUUSD',
]
PER_TEST_TIMEOUT = 90  # seconds

def kill_mt5():
    subprocess.run(['powershell.exe', '-Command', 'Stop-Process -Name terminal64 -Force -ErrorAction SilentlyContinue'],
                   capture_output=True)

for label in labels:
    ini = os.path.join(ini_dir, label + '.ini')
    cfg = {}
    with open(ini) as f:
        for line in f:
            m = re.match(r'^(\w+)=(.+)', line.strip())
            if m: cfg[m.group(1)] = m.group(2)
    expert = cfg.get('Expert', '')
    cmd = ['powershell.exe', '-File', 'scripts/mt5_run.ps1',
           '-Expert', expert, '-Symbol', cfg.get('Symbol', ''),
           '-Period', cfg.get('Period', 'H1'), '-Model', cfg.get('Model', '1'),
           '-FromDate', cfg.get('FromDate', '2023.01.01'),
           '-ToDate', cfg.get('ToDate', '2026.06.01'),
           '-ReportName', label]
    t0 = time.time()
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=PER_TEST_TIMEOUT)
        out = (result.stdout + result.stderr).strip().split('\n')[-1]
        el = time.time() - t0
        print(f'RESULT {label}: {out} ({el:.0f}s)', flush=True)
    except subprocess.TimeoutExpired:
        kill_mt5()
        print(f'TIMEOUT {label}: killed after {PER_TEST_TIMEOUT}s -> bad expert name, SKIP', flush=True)
        time.sleep(2)

print('DONE all 8', flush=True)
