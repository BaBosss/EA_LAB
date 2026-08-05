import subprocess, os, re, csv, time

SET_DIR = r"D:\EA_LAB\_mt5_auto\ab_sets\rsimom_fine"
REPORT_DIR = r"D:\EA_LAB\_mt5_auto\reports"
CSV_PATH = r"D:\EA_LAB\_mt5_auto\RSIMOM_FINE_SWEEPS.csv"
EXPERT = "RsiMomentum_Naked"
SYMBOL = "XAUUSD"
PERIOD = "H1"
PER_TEST_TIMEOUT = 100

WINDOWS = {
    "MAIN": ("2023.01.01", "2025.12.31"),
    "BWD":  ("2020.01.01", "2022.12.31"),
}

def kill_mt5():
    subprocess.run(['powershell.exe', '-Command',
                     'Stop-Process -Name terminal64 -Force -ErrorAction SilentlyContinue'],
                    capture_output=True)

def parse_report(path):
    out = {}
    result = subprocess.run(
        ['powershell.exe', '-File', r'D:\EA_LAB\scripts\parse_htm.ps1', '-Path', path],
        capture_output=True, text=True, timeout=30)
    for line in result.stdout.splitlines():
        m = re.match(r'^(\w+)\s*:\s*(.*)$', line.strip())
        if m:
            out[m.group(1)] = m.group(2).strip()
    return out

rows = list(csv.DictReader(open(CSV_PATH)))
failed_idx = [i for i, r in enumerate(rows) if r['status'] != 'ok']
print(f"{len(failed_idx)} to retry")

for idx in failed_idx:
    r = rows[idx]
    combo, wname = r['combo'], r['window']
    fdate, tdate = WINDOWS[wname]
    setpath = os.path.join(SET_DIR, combo + ".set")
    label = f"RSIMOM_{combo}_{wname}"
    kill_mt5()
    time.sleep(3)
    cmd = ['powershell.exe', '-File', r'D:\EA_LAB\scripts\mt5_run.ps1',
           '-Expert', EXPERT, '-Symbol', SYMBOL, '-Period', PERIOD,
           '-Model', '1', '-FromDate', fdate, '-ToDate', tdate,
           '-SetFile', setpath, '-ReportName', label, '-Force']
    status = 'ok'
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=PER_TEST_TIMEOUT)
        tail = (result.stdout + result.stderr).strip().split('\n')[-1]
    except subprocess.TimeoutExpired:
        kill_mt5()
        status = 'TIMEOUT'
        tail = 'killed'
        time.sleep(2)

    htm = os.path.join(REPORT_DIR, label + ".htm")
    time.sleep(1)
    if status == 'ok' and os.path.exists(htm):
        p = parse_report(htm)
        r['PF'] = p.get('PF', '')
        r['Trades'] = p.get('Trades', '')
        r['DDpct'] = p.get('DDpct', '')
        r['RF'] = p.get('RF', '')
        r['Net'] = p.get('Net', '')
        r['status'] = 'ok' if r['PF'] else 'NO_PF'
    else:
        r['status'] = 'NAME_ERROR_RETRY' if status == 'ok' else status
    print(f"RETRY {label}: PF={r['PF']} Trades={r['Trades']} status={r['status']} | {tail}", flush=True)

fieldnames = ['combo', 'window', 'PF', 'Trades', 'DDpct', 'RF', 'Net', 'status']
with open(CSV_PATH, 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=fieldnames)
    w.writeheader()
    for r in rows:
        w.writerow(r)
print("RETRY DONE")
