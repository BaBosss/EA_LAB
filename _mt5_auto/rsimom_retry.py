import csv

rows = list(csv.DictReader(open(r"D:\EA_LAB\_mt5_auto\RSIMOM_FINE_SWEEPS.csv")))
failed = [(r['combo'], r['window']) for r in rows if r['status'] not in ('ok',)]
print(len(failed))
for c,w in failed:
    print(c,w)
