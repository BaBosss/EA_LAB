import sys, csv
from datetime import datetime

files = sys.argv[1:]
rows = []
for f in files:
    with open(f, newline='') as fh:
        r = csv.DictReader(fh)
        for row in r:
            rows.append((datetime.strptime(row['time'], '%Y.%m.%d %H:%M:%S'), float(row['profit'])))
rows.sort(key=lambda x: x[0])

deposit = 10000.0
bal = deposit
peak = deposit
max_dd_pct = 0.0
gross_win = 0.0
gross_loss = 0.0
wins = 0
for t, p in rows:
    bal += p
    if bal > peak:
        peak = bal
    dd = (peak - bal) / peak * 100 if peak > 0 else 0
    if dd > max_dd_pct:
        max_dd_pct = dd
    if p > 0:
        gross_win += p
        wins += 1
    else:
        gross_loss += -p

net = bal - deposit
pf = gross_win / gross_loss if gross_loss > 0 else float('inf')
rf = net / (max_dd_pct/100*deposit) if max_dd_pct > 0 else float('inf')
print(f"trades={len(rows)}  net={net:.2f}  PF={pf:.3f}  maxDD%={max_dd_pct:.3f}  RF(approx)={rf:.3f}  wins={wins} ({100*wins/len(rows):.0f}%)")
print(f"first={rows[0][0]}  last={rows[-1][0]}")
