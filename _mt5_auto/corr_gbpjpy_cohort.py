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

# subject = GBPJPY leg-8 candidate (d2.0/s4.0), gate for reuse across symbol of SAME EA = pairwise |corr| < 0.8
gj = extract_monthly(RDIR / "CORRGJ_GJ.htm")
cohort = {
    "USDJPY(990201)": "CORRGJ_USDJPY.htm",
    "AUDNZD(990202)": "CORRGJ_AUDNZD.htm",
    "EURJPY(990203)": "CORRGJ_EURJPY.htm",
    "AUDCAD(990204)": "CORRGJ_AUDCAD.htm",
    "CADJPY(990205)": "CORRGJ_CADJPY.htm",
    "EURUSD(990206)": "CORRGJ_EURUSD.htm",
    "XAUUSD(990207)": "CORRGJ_XAU.htm",
}
print(f"GBPJPY leg-8 (d2.0): {len(gj)} months, net {sum(gj.values()):.1f}")
print(f"{'Cohort leg':<16}{'Corr vs GBPJPY':>15}{'Shared mo':>11}{'Gate(<0.8)':>13}")
print("-" * 55)
maxc = None
for name, rep in cohort.items():
    cm = extract_monthly(RDIR / rep)
    shared = sorted(set(gj) & set(cm))
    if len(shared) < 4:
        print(f"{name:<16}{'n/a':>15}{len(shared):>11}{'no-data':>13}")
        continue
    xs = [gj[m] for m in shared]; ys = [cm[m] for m in shared]
    c = pearson(xs, ys)
    if c is None:
        print(f"{name:<16}{'flat':>15}{len(shared):>11}")
        continue
    maxc = abs(c) if maxc is None else max(maxc, abs(c))
    verdict = "PASS additive" if abs(c) < 0.8 else "REDUNDANT>=0.8"
    print(f"{name:<16}{c:>15.3f}{len(shared):>11}{verdict:>13}")
print("-" * 55)
if maxc is not None:
    print(f"max |corr| = {maxc:.3f} -> " +
          ("ALL PASS <0.8 => GBPJPY leg-8 additive, propose to user" if maxc < 0.8
           else "at least one REDUNDANT >=0.8 => user decides (do not auto-drop)"))
