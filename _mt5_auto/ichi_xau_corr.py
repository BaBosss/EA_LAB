# ORDER-112E: monthly-P&L Pearson of Ichimoku-XAU (slowH1) vs the XAU book.
import re
from pathlib import Path
from collections import defaultdict

rdir = Path(r"D:\EA_LAB\_mt5_auto\reports")

def read_text(p):
    raw = Path(p).read_bytes()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"): return raw.decode("utf-16", errors="replace")
    return raw.decode("utf-8", errors="replace")

def num(s):
    s = str(s).strip().replace("\xa0","").replace(" ","").replace(",","")
    try: return float(s)
    except: return None

def monthly(rep):
    p = rdir / f"{rep}.htm"
    m = defaultdict(float)
    if not p.exists(): return m
    text = read_text(p)
    for r in re.findall(r"<tr[^>]*>(.*?)</tr>", text, re.S):
        cells = [re.sub("<[^>]+>","",c).strip() for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", r, re.S)]
        if len(cells) != 13: continue
        if cells[4].lower() != "out": continue
        pr = num(cells[10]);
        if pr is None: continue
        comm = num(cells[8]) or 0.0; sw = num(cells[9]) or 0.0
        mt = re.match(r"(\d{4})\.(\d{2})", cells[0])
        if mt: m[f"{mt.group(1)}-{mt.group(2)}"] += pr + comm + sw
    return m

def pearson(xs, ys):
    n=len(xs)
    if n<4: return float("nan")
    mx=sum(xs)/n; my=sum(ys)/n
    nu=sum((x-mx)*(y-my) for x,y in zip(xs,ys))
    dx=(sum((x-mx)**2 for x in xs))**0.5; dy=(sum((y-my)**2 for y in ys))**0.5
    if dx==0 or dy==0: return float("nan")
    return nu/(dx*dy)

ichi = monthly("CORR_ICHI_XAU")
print(f"Ichimoku-XAU months={len(ichi)} net={sum(ichi.values()):.0f}\n")
print(f"{'vs':<14}{'Pearson':>10}{'shared_mo':>11}{'verdict':>22}")
print("-"*57)
for rep,label in [("CORR_BRK_XAU","BRK_XAU"),("CORR_KAU_XAU","KAUFMAN_XAU"),("CORR_ST_XAU","SuperTrend_XAU")]:
    o = monthly(rep)
    shared = sorted(set(ichi) & set(o))
    if len(shared) < 4:
        print(f"{label:<14}{'n/a':>10}{len(shared):>11}   (no data / <4 months)"); continue
    c = pearson([ichi[m] for m in shared],[o[m] for m in shared])
    v = "LOW additive(<0.6)" if c<0.6 else ("reduce-lot(0.6-0.8)" if c<=0.8 else "HIGH redundant(>0.8)")
    print(f"{label:<14}{c:>10.3f}{len(shared):>11}{v:>22}")
