import re
from pathlib import Path
from collections import defaultdict

def read_text(p):
    raw = Path(p).read_bytes()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"): return raw.decode("utf-16", errors="replace")
    return raw.decode("utf-8", errors="replace")

def num(s):
    s=str(s).strip().replace("\xa0","").replace(" ","").replace(",","")
    try: return float(s)
    except: return None

def analyze(path, label):
    text=read_text(path)
    groups=defaultdict(lambda:{"n":0,"sum":0.0,"win":0,"profits":[]})
    for r in re.findall(r"<tr[^>]*>(.*?)</tr>", text, re.S):
        cells=[re.sub("<[^>]+>","",c).strip() for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", r, re.S)]
        if len(cells)!=13: continue
        if cells[4].lower()!="out": continue
        profit=num(cells[10])
        if profit is None: continue
        comment=cells[12]
        u=comment.upper()
        if "RETEST" in u: key="RETEST(pending)"
        elif "MKT" in u or "BRKOUT" in u: key="MARKET(runner)"
        else: key="other:"+comment[:12]
        g=groups[key]; g["n"]+=1; g["sum"]+=profit; g["profits"].append(profit)
        if profit>0: g["win"]+=1
    print("\n=== %s ===" % label)
    print("%-16s%5s%10s%9s%7s%9s%9s" % ("leg","n","net$","avg$","win%","best$","worst$"))
    for k in sorted(groups):
        g=groups[k]
        avg=g["sum"]/g["n"] if g["n"] else 0
        winp=100.0*g["win"]/g["n"] if g["n"] else 0
        print("%-16s%5d%10.1f%9.2f%7.1f%9.1f%9.1f" % (k,g["n"],g["sum"],avg,winp,max(g["profits"]),min(g["profits"])))

analyze(r"_mt5_auto/reports/O108_S_H1_MAIN.htm","SPLIT MAIN 2023-2026")
analyze(r"_mt5_auto/reports/O108_S_H1_BWD.htm","SPLIT BWD 2020-2022")
