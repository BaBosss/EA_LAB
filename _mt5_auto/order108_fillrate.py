import re
from pathlib import Path
from collections import defaultdict

def read_text(p):
    raw = Path(p).read_bytes()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"): return raw.decode("utf-16", errors="replace")
    return raw.decode("utf-8", errors="replace")

def fillrate(path, label):
    text=read_text(path)
    legs=defaultdict(int)
    for r in re.findall(r"<tr[^>]*>(.*?)</tr>", text, re.S):
        cells=[re.sub("<[^>]+>","",c).strip() for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", r, re.S)]
        if len(cells)!=13: continue
        if cells[4].lower()!="in": continue        # opening deals carry the EA entry comment
        comment=cells[12].upper()
        if "RETEST" in comment: legs["RETEST(pending)"]+=1
        elif "MKT" in comment or "BRKOUT" in comment: legs["MARKET(runner)"]+=1
        else: legs["other:"+cells[12][:14]]+=1
    print("\n=== %s ===" % label)
    for k in sorted(legs): print("  %-18s %d entries" % (k, legs[k]))
    mkt=legs.get("MARKET(runner)",0); ret=legs.get("RETEST(pending)",0)
    if mkt: print("  fill-rate (retest fills / market signals) = %d/%d = %.0f%%" % (ret,mkt,100.0*ret/mkt))

fillrate(r"_mt5_auto/reports/O108_S_H1_MAIN.htm","SPLIT MAIN 2023-2026")
fillrate(r"_mt5_auto/reports/O108_S_H1_BWD.htm","SPLIT BWD 2020-2022")
