import subprocess, os, time

PER_TEST_TIMEOUT = 180

def kill_mt5():
    subprocess.run(['powershell.exe', '-Command',
                    'Stop-Process -Name terminal64 -Force -ErrorAction SilentlyContinue'],
                   capture_output=True)

def run(expert, symbol, period, setfile, reportname, model='2'):
    cmd = ['powershell.exe', '-NoProfile', '-File', 'scripts/mt5_run.ps1',
           '-Expert', expert, '-Symbol', symbol, '-Period', period,
           '-FromDate', '2023.01.01', '-ToDate', '2025.12.31',
           '-Model', model, '-SetFile', setfile, '-ReportName', reportname]
    t0 = time.time()
    for attempt in range(2):
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=PER_TEST_TIMEOUT)
            out = (result.stdout + result.stderr).strip()
            el = time.time() - t0
            if 'ABORT' in out and 'already running' in out and attempt == 0:
                print(f'{reportname}: ABORT already running, wait+retry', flush=True)
                time.sleep(15)
                continue
            print(f'RESULT {reportname}: ({el:.0f}s) tail: {out.strip().split(chr(10))[-1]}', flush=True)
            return
        except subprocess.TimeoutExpired:
            kill_mt5()
            print(f'TIMEOUT {reportname}: killed after {PER_TEST_TIMEOUT}s', flush=True)
            time.sleep(2)
            return

folder = r'_mt5_auto\ab_sets\order133_tapfair'
cells = {
    'XAUUSDM15': ('XAUUSD', 'M15'),
    'EURGBPH1': ('EURGBP', 'H1'),
}
sets = [
    'STMT_XAUUSDM15_K9_tap1.set','STMT_XAUUSDM15_K9_tap2.set','STMT_XAUUSDM15_K9_tap3.set',
    'STMT_XAUUSDM15_K17_tap1.set','STMT_XAUUSDM15_K17_tap2.set','STMT_XAUUSDM15_K17_tap3.set',
    'STMT_EURGBPH1_K9_tap1.set','STMT_EURGBPH1_K9_tap2.set','STMT_EURGBPH1_K9_tap3.set',
    'STMT_EURGBPH1_K17_tap1.set','STMT_EURGBPH1_K17_tap2.set','STMT_EURGBPH1_K17_tap3.set',
]

for s in sets:
    base = s[:-4]
    parts = base.split('_')
    cell = parts[1]
    symbol, period = cells[cell]
    setfile = os.path.join(folder, s)
    run('(EXP)_StoMultiTap', symbol, period, setfile, base)

# Part B
run('EmaStoRev', 'EURGBP', 'H1',
    r'_mt5_auto\ab_sets\order107_opt\top_EURGBP\EmaStoRev_top1.set',
    'EMASTOREV_EURGBP_H1_MAIN')

print('DONE ALL', flush=True)
