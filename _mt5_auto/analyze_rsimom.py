import csv, collections

rows = list(csv.DictReader(open(r"D:\EA_LAB\_mt5_auto\RSIMOM_FINE_SWEEPS.csv")))
data = {}
for r in rows:
    key = r['combo']
    data.setdefault(key, {})[r['window']] = r

def pf(row):
    try:
        return float(row['PF'])
    except:
        return None

def show_grid(prefix, periods, levels, tag):
    print(f"\n=== {tag} (both-window PF: MAIN/BWD) ===")
    header = "P\L".ljust(6) + "".join(str(l).rjust(14) for l in levels)
    print(header)
    for p in periods:
        line = str(p).ljust(6)
        for l in levels:
            combo = f"{prefix}_P{p}_L{l}"
            d = data.get(combo, {})
            m = pf(d.get('MAIN', {}))
            b = pf(d.get('BWD', {}))
            ms = f"{m:.2f}" if m is not None else "NA"
            bs = f"{b:.2f}" if b is not None else "NA"
            line += f"{ms}/{bs}".rjust(14)
        print(line)

show_grid("T1A", [7,8,9,10,11], [52,54,55,56,58], "TASK1 neighborhood P9/L55 (mode B)")
show_grid("T1B", [18,20,21,23,25], [47,49,50,51,53], "TASK1 neighborhood P21/L50 (mode B)")

def show_modeA():
    print("\n=== TASK2 Mode A (RSI/SMA cross) ranked by MAIN PF ===")
    res = []
    for sma in [10,14,20,30]:
        for p in [9,14,21]:
            combo = f"T2A_SMA{sma}_P{p}"
            d = data.get(combo, {})
            m = pf(d.get('MAIN', {})); b = pf(d.get('BWD', {}))
            tm = d.get('MAIN', {}).get('Trades'); tb = d.get('BWD', {}).get('Trades')
            res.append((combo, m, b, tm, tb))
    res.sort(key=lambda x: (x[1] if x[1] is not None else -99), reverse=True)
    for c, m, b, tm, tb in res:
        print(f"{c}: MAIN={m} (t={tm})  BWD={b} (t={tb})")

def show_modeC():
    print("\n=== TASK2 Mode C (RSI breakout) ranked by MAIN PF ===")
    res = []
    for lb in [10,15,20,30]:
        for p in [9,14,21]:
            combo = f"T2C_LB{lb}_P{p}"
            d = data.get(combo, {})
            m = pf(d.get('MAIN', {})); b = pf(d.get('BWD', {}))
            tm = d.get('MAIN', {}).get('Trades'); tb = d.get('BWD', {}).get('Trades')
            res.append((combo, m, b, tm, tb))
    res.sort(key=lambda x: (x[1] if x[1] is not None else -99), reverse=True)
    for c, m, b, tm, tb in res:
        print(f"{c}: MAIN={m} (t={tm})  BWD={b} (t={tb})")

show_modeA()
show_modeC()

# plateau check function
def plateau_check(prefix, center_p, center_l, periods, levels):
    def get(p,l):
        combo = f"{prefix}_P{p}_L{l}"
        d = data.get(combo, {})
        m = pf(d.get('MAIN', {})); b = pf(d.get('BWD', {}))
        return m,b
    idx_p = periods.index(center_p); idx_l = levels.index(center_l)
    neighbors = []
    if idx_p>0: neighbors.append((periods[idx_p-1], center_l))
    if idx_p<len(periods)-1: neighbors.append((periods[idx_p+1], center_l))
    if idx_l>0: neighbors.append((center_p, levels[idx_l-1]))
    if idx_l<len(levels)-1: neighbors.append((center_p, levels[idx_l+1]))
    center = get(center_p, center_l)
    print(f"\ncenter {prefix} P{center_p}/L{center_l}: MAIN={center[0]} BWD={center[1]}")
    all_ok = center[0] is not None and center[0]>=1.0 and center[1] is not None and center[1]>=1.0
    for np_, nl_ in neighbors:
        m,b = get(np_, nl_)
        ok = m is not None and m>=1.0 and b is not None and b>=1.0
        all_ok = all_ok and ok
        print(f"  neighbor P{np_}/L{nl_}: MAIN={m} BWD={b} bothwindow_ge1={ok}")
    print(f"PLATEAU (center+4 neighbors all both-window>=1.0)? {all_ok}")

plateau_check("T1A", 9, 55, [7,8,9,10,11], [52,54,55,56,58])
plateau_check("T1B", 21, 50, [18,20,21,23,25], [47,49,50,51,53])
