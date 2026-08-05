import subprocess, os, re, csv, time, sys

SET_DIR = r"D:\EA_LAB\_mt5_auto\ab_sets\rsimom_fine"
REPORT_DIR = r"D:\EA_LAB\_mt5_auto\reports"
CSV_PATH = r"D:\EA_LAB\_mt5_auto\RSIMOM_FINE_SWEEPS.csv"
EXPERT = "RsiMomentum_Naked"
SYMBOL = "XAUUSD"
PERIOD = "H1"
PER_TEST_TIMEOUT = 100

WINDOWS = [
    ("MAIN", "2023.01.01", "2025.12.31"),
    ("BWD",  "2020.01.01", "2022.12.31"),
]

def kill_mt5():
    subprocess.run(['powershell.exe', '-Command',
                     'Stop-Process -Name terminal64 -Force -ErrorAction SilentlyContinue'],
                    capture_output=True)

def parse_report(path):
    out = {}
    try:
        result = subprocess.run(
            ['powershell.exe', '-File', r'D:\EA_LAB\scripts\parse_htm.ps1', '-Path', path],
            capture_output=True, text=True, timeout=30)
        txt = result.stdout
        for line in txt.splitlines():
            m = re.match(r'^(\w+)\s*:\s*(.*)$', line.strip())
            if m:
                out[m.group(1)] = m.group(2).strip()
    except Exception as e:
        out['error'] = str(e)
    return out

def main():
    set_files = sorted(f for f in os.listdir(SET_DIR) if f.endswith('.set'))
    rows = []
    # resume support
    done_labels = set()
    if os.path.exists(CSV_PATH):
        with open(CSV_PATH, newline='') as f:
            r = csv.DictReader(f)
            for row in r:
                done_labels.add((row['combo'], row['window']))
                rows.append(row)

    fieldnames = ['combo', 'window', 'PF', 'Trades', 'DDpct', 'RF', 'Net', 'status']
    write_header = not os.path.exists(CSV_PATH)

    with open(CSV_PATH, 'a', newline='') as fcsv:
        writer = csv.DictWriter(fcsv, fieldnames=fieldnames)
        if write_header:
            writer.writeheader()

        for sf in set_files:
            combo = sf[:-4]
            setpath = os.path.join(SET_DIR, sf)
            for wname, fdate, tdate in WINDOWS:
                if (combo, wname) in done_labels:
                    print(f"SKIP already done {combo} {wname}", flush=True)
                    continue
                label = f"RSIMOM_{combo}_{wname}"
                cmd = ['powershell.exe', '-File', r'D:\EA_LAB\scripts\mt5_run.ps1',
                       '-Expert', EXPERT, '-Symbol', SYMBOL, '-Period', PERIOD,
                       '-Model', '1', '-FromDate', fdate, '-ToDate', tdate,
                       '-SetFile', setpath, '-ReportName', label, '-Force']
                t0 = time.time()
                status = 'ok'
                try:
                    result = subprocess.run(cmd, capture_output=True, text=True, timeout=PER_TEST_TIMEOUT)
                    tail = (result.stdout + result.stderr).strip().split('\n')[-1]
                except subprocess.TimeoutExpired:
                    kill_mt5()
                    status = 'TIMEOUT'
                    tail = 'killed'
                    time.sleep(2)
                el = time.time() - t0

                htm = os.path.join(REPORT_DIR, label + ".htm")
                row = {'combo': combo, 'window': wname, 'PF': '', 'Trades': '', 'DDpct': '', 'RF': '', 'Net': '', 'status': status}
                if status == 'ok' and os.path.exists(htm):
                    p = parse_report(htm)
                    row['PF'] = p.get('PF', '')
                    row['Trades'] = p.get('Trades', '')
                    row['DDpct'] = p.get('DDpct', '')
                    row['RF'] = p.get('RF', '')
                    row['Net'] = p.get('Net', '')
                    if not row['PF']:
                        row['status'] = 'NO_PF'
                else:
                    row['status'] = 'NAME_ERROR' if status == 'ok' else status

                writer.writerow(row)
                fcsv.flush()
                print(f"RESULT {label}: PF={row['PF']} Trades={row['Trades']} DD={row['DDpct']} status={row['status']} ({el:.0f}s) | {tail}", flush=True)

    print("DONE all combos", flush=True)

if __name__ == '__main__':
    main()
