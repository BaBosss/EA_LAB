import re
from pathlib import Path
from collections import defaultdict

RDIR = Path(r"D:\EA_LAB\_mt5_auto\reports")

def read_text(path):
    raw = Path(path).read_bytes()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16", errors="replace")
    return raw.decode("utf-8", errors="replace")

def num(s):
    s = str(s).strip().replace("\xa0", "").replace(" ", "").replace(",", "")
    try: return float(s)
    except: return None

def extract_monthly(path):
    monthly = defaultdict(float)
    if not Path(path).exists():
        return monthly
    text = read_text(path)
    for r in re.findall(r"<tr[^>]*>(.*?)</tr>", text, re.S):
        cells = [re.sub("<[^>]+>", "", c).strip()
                 for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", r, re.S)]
        if len(cells) != 13: continue
        if cells[4].lower() != "out": continue
        profit = num(cells[10])
        if profit is None: continue
        commission = num(cells[8]) or 0.0
        swap = num(cells[9]) or 0.0
        m = re.match(r"(\d{4})\.(\d{2})", cells[0])
        if m:
            monthly[f"{m.group(1)}-{m.group(2)}"] += profit + commission + swap
    return monthly

def pearson(xs, ys):
    n = len(xs)
    if n < 2: return None
    mx = sum(xs)/n; my = sum(ys)/n
    cov = sum((x-mx)*(y-my) for x, y in zip(xs, ys))
    vx = sum((x-mx)**2 for x in xs); vy = sum((y-my)**2 for y in ys)
    if vx == 0 or vy == 0: return None
    return cov/(vx**0.5 * vy**0.5)

home = extract_monthly(RDIR / "CORR_BRK_XAU_MAIN.htm")
candidates = {
    "USDJPY_H4": "O095_BRK_USDJPY_H4_MAIN.htm",
    "US30_H4":   "O095_BRK_US30_H4_MAIN.htm",
}

print(f"EA_BREAKOUT_XAU home (XAUUSD H4 MAIN): {len(home)} months, net {sum(home.values()):.1f}")
print(f"{'Candidate':<14}{'Corr vs XAU leg':>16}{'Shared mo':>11}{'Gate(<0.8)':>12}")
print("-"*53)
for name, rep in candidates.items():
    cm = extract_monthly(RDIR / rep)
    shared = sorted(set(home) & set(cm))
    if len(shared) < 4:
        print(f"{name:<14}{'n/a':>16}{len(shared):>11}{'no-data':>12}")
        continue
    xs = [home[m] for m in shared]; ys = [cm[m] for m in shared]
    c = pearson(xs, ys)
    verdict = "PASS additive" if (c is not None and abs(c) < 0.8) else "REDUNDANT/flat"
    print(f"{name:<14}{c if c is not None else float('nan'):>16.3f}{len(shared):>11}{verdict:>12}")
