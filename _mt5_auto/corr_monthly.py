import re
from pathlib import Path
from collections import defaultdict

def read_text(path):
    raw = Path(path).read_bytes()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16", errors="replace")
    return raw.decode("utf-8", errors="replace")

def num(s):
    s = str(s).strip().replace("\xa0","").replace(" ","").replace(",","")
    try: return float(s)
    except: return None

def extract_monthly(paths):
    monthly = defaultdict(float)
    for path in paths:
        if not Path(path).exists():
            continue
        text = read_text(path)
        rows = re.findall(r"<tr[^>]*>(.*?)</tr>", text, re.S)
        for r in rows:
            cells = [re.sub("<[^>]+>","",c).strip()
                     for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", r, re.S)]
            if len(cells) != 13: continue
            if cells[4].lower() != "out": continue
            profit = num(cells[10])
            if profit is None: continue
            commission = num(cells[8]) or 0.0
            swap = num(cells[9]) or 0.0
            t = cells[0]
            m = re.match(r"(\d{4})\.(\d{2})", t)
            if m:
                ym = f"{m.group(1)}-{m.group(2)}"
                monthly[ym] += profit + commission + swap
    return monthly

def pearson(xs, ys):
    n = len(xs)
    if n < 4: return float("nan")
    mx = sum(xs)/n; my = sum(ys)/n
    num_ = sum((x-mx)*(y-my) for x,y in zip(xs,ys))
    dx = (sum((x-mx)**2 for x in xs))**0.5
    dy = (sum((y-my)**2 for y in ys))**0.5
    if dx==0 or dy==0: return float("nan")
    return num_/(dx*dy)

rdir = r"D:\EA_LAB\_mt5_auto\reports"

# Reference: XAU Breakout (Bars8 IS+OOS)
brk_m = extract_monthly([
    f"{rdir}/BRKXAUH4_c0_IS.htm",
    f"{rdir}/BRKXAUH4_c0_OOS.htm",
])

candidates = ["XAGUSD", "US30"]

print(f"\n{'Symbol':<10} {'Corr vs BRK_XAU':>16} {'Shared months':>14} {'Verdict':>12}")
print("-" * 58)
for sym in candidates:
    st_m = extract_monthly([f"{rdir}/ST_v1_{sym}_H4_M2.htm"])
    all_m = sorted(set(st_m) | set(brk_m))
    shared = [(m, st_m[m], brk_m[m]) for m in all_m if m in st_m and m in brk_m]
    if len(shared) < 4:
        print(f"{sym:<10} {'not enough data':>16}")
        continue
    xs = [x for _,x,_ in shared]
    ys = [y for _,_,y in shared]
    corr = pearson(xs, ys)
    verdict = "LOW - additive" if corr <= 0.40 else ("WATCH" if corr <= 0.60 else "HIGH - skip")
    print(f"{sym:<10} {corr:>16.3f} {len(shared):>14} {verdict:>12}")

print()
# Also check XAU ST vs XAU BRK for reference
st_xau = extract_monthly([
    f"{rdir}/ST_v1_H4_IS_M4.htm",
    f"{rdir}/ST_v1_H4_OOS_M4.htm",
])
all_m = sorted(set(st_xau) | set(brk_m))
shared_xau = [(m, st_xau[m], brk_m[m]) for m in all_m if m in st_xau and m in brk_m]
xs = [x for _,x,_ in shared_xau]; ys = [y for _,_,y in shared_xau]
print(f"{'XAUUSD(ref)':<10} {pearson(xs,ys):>16.3f} {len(shared_xau):>14} {'HIGH - known':>12}")
