# ORDER-098-B corr gate: MacdDiv XAU H4 vs live gold cohort (5 EAs). Reuses corr_wave5_cohort method.
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

subj = extract_monthly(RDIR / "O098B_M4_XAU_H4_MAIN.htm")
cohort = {
    "Zeus_GridLog": "CORR_ZEUS_XAU_MAIN.htm",
    "Squeeze_BRK":  "CORR_SQZ_XAU_MAIN.htm",
    "Trendline_BRK":"CORR_TL_XAU_MAIN.htm",
    "Breakout_XAU": "CORR_BRK_XAU_MAIN.htm",
    "Wave5_XAU":    "EXT_XAU_F236_M0618_MAIN.htm",
}

print(f"MacdDiv XAU H4 (subject): {len(subj)} months, net {sum(subj.values()):.1f}")
print(f"{'Cohort EA':<16}{'Corr':>10}{'SharedMo':>10}{'Gate(<0.8)':>13}")
print("-"*49)
maxc = None
for name, rep in cohort.items():
    cm = extract_monthly(RDIR / rep)
    shared = sorted(set(subj) & set(cm))
    if len(shared) < 4:
        print(f"{name:<16}{'n/a':>10}{len(shared):>10}{'no-data':>13}")
        continue
    xs = [subj[m] for m in shared]; ys = [cm[m] for m in shared]
    c = pearson(xs, ys)
    if c is None:
        print(f"{name:<16}{'flat':>10}{len(shared):>10}")
        continue
    maxc = abs(c) if maxc is None else max(maxc, abs(c))
    verdict = "PASS" if abs(c) < 0.8 else "REDUNDANT"
    print(f"{name:<16}{c:>10.3f}{len(shared):>10}{verdict:>13}")
print("-"*49)
if maxc is not None:
    tag = "ALL PASS <0.8 (MacdDiv additive to gold cohort)" if maxc < 0.8 else "at least one REDUNDANT >=0.8"
    print(f"max |corr| = {maxc:.3f} -> {tag}")
