#!/usr/bin/env python3
import csv, hashlib, html, json
from collections import Counter
from pathlib import Path

RUN = Path(__file__).resolve().parent
VIS = RUN / "visuals"
VIS.mkdir(exist_ok=True)
parent = json.loads((RUN / "parent_analysis.json").read_text(encoding="utf-8"))
child = json.loads((RUN / "child_analysis.json").read_text(encoding="utf-8"))
comparison = json.loads((RUN / "comparison.json").read_text(encoding="utf-8"))
mechanical = json.loads((RUN / "mechanical_acceptance.json").read_text(encoding="utf-8"))
source_recon = json.loads((RUN / "source_graph_reconciliation.json").read_text(encoding="utf-8"))

def esc(x): return html.escape(str(x))
def svg_start(w,h,title):
    return [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}">',
            '<rect width="100%" height="100%" fill="white"/>',
            f'<text x="20" y="28" font-family="sans-serif" font-size="18">{esc(title)}</text>']
def svg_end(lines,note="VISUAL_ONLY_NO_AUTHORITY"):
    lines += [f'<text x="20" y="97%" font-family="sans-serif" font-size="10">{esc(note)}</text>','</svg>']
    return "\n".join(lines)
def metric_table():
    lines=svg_start(1050,320,"B16 XAUUSD/M15 early-zone spacing — parent vs child")
    heads=["Window","Arm","Net USD","PF","Trades","EqDD%","Max depth"]
    xs=[20,130,270,390,500,620,760]
    for x,t in zip(xs,heads): lines.append(f'<text x="{x}" y="60" font-family="sans-serif" font-size="12">{t}</text>')
    y=88
    for window in ("MAIN","BWD"):
        for arm in ("parent","child"):
            r=comparison["windows"][window][arm]
            vals=[window,arm.upper(),r["net"],r["pf"],r["trades"],r["eqdd_pct"],r["max_depth"]]
            for x,v in zip(xs,vals): lines.append(f'<text x="{x}" y="{y}" font-family="sans-serif" font-size="12">{esc(v)}</text>')
            y+=30
        d=comparison["windows"][window]["delta"]
        lines.append(f'<text x="130" y="{y}" font-family="sans-serif" font-size="11">CHILD-PARENT: net {d["net"]:+.2f}, PF {d["pf"]:+.2f}, trades {d["trades"]:+d}, EqDD {d["eqdd_pp"]:+.2f}pp</text>')
        y+=42
    (VIS/"r2_parent_child_metrics.svg").write_text(svg_end(lines),encoding="utf-8")

def year_chart():
    rows=list(csv.DictReader((RUN/"year_split.csv").open(encoding="utf-8")))
    items=[(r["arm"],r["window"],int(r["year"]),float(r["net"])) for r in rows]
    maxabs=max(abs(v) for *_,v in items) or 1.0
    lines=svg_start(1100,450,"Year-by-year net — same-install parent vs child")
    base=210; x=40; bw=55; gap=22
    lines.append(f'<line x1="25" y1="{base}" x2="1070" y2="{base}" stroke="black"/>')
    for arm,window,year,val in items:
        h=abs(val)/maxabs*150; y=base-h if val>=0 else base
        lines.append(f'<rect x="{x}" y="{y:.1f}" width="{bw}" height="{h:.1f}" fill="none" stroke="black"/>')
        lines.append(f'<text x="{x+bw/2}" y="{base+22}" text-anchor="middle" font-family="sans-serif" font-size="9">{year}</text>')
        lines.append(f'<text x="{x+bw/2}" y="{base+36}" text-anchor="middle" font-family="sans-serif" font-size="8">{arm[0]}-{window[0]}</text>')
        lines.append(f'<text x="{x+bw/2}" y="{y-4 if val>=0 else y+h+12:.1f}" text-anchor="middle" font-family="sans-serif" font-size="8">{val:.0f}</text>')
        x+=bw+gap
    lines.append('<text x="25" y="390" font-family="sans-serif" font-size="10">P=parent, C=child; M=MAIN, B=BWD. BWD 2021 remains negative and worsens in the child.</text>')
    (VIS/"r2_year_net.svg").write_text(svg_end(lines),encoding="utf-8")

def series(which,window):
    node=(parent if which=="PARENT" else child)[window.lower()]
    bal=10000.0; out=[]
    for c in node["cycles"]:
        bal+=float(c["pnl"]); out.append(bal)
    return out

def line_visual(filename,title,transform,note):
    sets=[]
    for arm in ("PARENT","CHILD"):
        for window in ("MAIN","BWD"):
            vals=transform(series(arm,window)); sets.append((f"{arm} {window}",vals))
    allv=[v for _,vs in sets for v in vs]; lo=min(allv); hi=max(allv); span=max(hi-lo,1e-9)
    lines=svg_start(1100,430,title); left,top,w,h=70,55,990,300
    lines += [f'<line x1="{left}" y1="{top+h}" x2="{left+w}" y2="{top+h}" stroke="black"/>',f'<line x1="{left}" y1="{top}" x2="{left}" y2="{top+h}" stroke="black"/>']
    for idx,(name,vals) in enumerate(sets):
        pts=[]
        for i,v in enumerate(vals):
            x=left+(i/max(1,len(vals)-1))*w; y=top+h-(v-lo)/span*h; pts.append(f"{x:.1f},{y:.1f}")
        dash='' if idx<2 else ' stroke-dasharray="6,4"'
        lines.append(f'<polyline points="{" ".join(pts)}" fill="none" stroke="black" stroke-width="1.2"{dash}/>')
        lines.append(f'<text x="{left+10}" y="{top+18+idx*16}" font-family="sans-serif" font-size="10">{name}</text>')
    (VIS/filename).write_text(svg_end(lines,note),encoding="utf-8")

def drawdowns(vals):
    peak=vals[0] if vals else 10000.0; out=[]
    for v in vals:
        peak=max(peak,v); out.append((peak-v)/peak*100 if peak else 0.0)
    return out

def depth_chart():
    lines=svg_start(1000,390,"Cycle maximum depth distribution")
    x0=70; y0=310; scale=2.0
    for aidx,arm in enumerate(("PARENT","CHILD")):
        counts=Counter()
        for window in ("main","bwd"):
            for c in (parent if arm=="PARENT" else child)[window]["cycles"]: counts[int(c["max_basket_depth"])] += 1
        for d in range(1,11):
            x=x0+(d-1)*85+aidx*28; h=min(counts[d]*scale,240)
            lines.append(f'<rect x="{x}" y="{y0-h:.1f}" width="24" height="{h:.1f}" fill="none" stroke="black"/>')
            lines.append(f'<text x="{x+12}" y="{y0+18}" text-anchor="middle" font-family="sans-serif" font-size="9">{d}</text>')
        lines.append(f'<text x="{760}" y="{45+aidx*16}" font-family="sans-serif" font-size="10">{arm}: aggregated MAIN+BWD</text>')
    (VIS/"r2_depth_distribution.svg").write_text(svg_end(lines),encoding="utf-8")
metric_table(); year_chart(); depth_chart()
line_visual("r2_balance_proxy.svg","Closed-deal balance proxy",lambda x:x,"Closed-deal balance proxy; not native intratrade equity. VISUAL_ONLY_NO_AUTHORITY")
line_visual("r2_underwater_proxy.svg","Closed-deal underwater proxy",drawdowns,"Closed-deal balance drawdown proxy; native EqDD is reported separately. VISUAL_ONLY_NO_AUTHORITY")

m=comparison["windows"]; cls=comparison["classification"]
report=f'''# B16 XAUUSD/M15 Early-Zone Spacing 01 — R2 Mechanism Report

Status: `MECHANICALLY_ACCEPTED / RESEARCH_ONLY / {cls}`
Prereg commit: `9b26192acb54c61c98e055272e0f7b2945b93c4b`
Installation lineage: `D:\\Meta 5c` only; Model 1 / 1 Minute OHLC; Optimization 0; HOLDOUT UNSPENT.
Parent set SHA256: `7a8e8c78bfbcd245e039a629cceb8914a91531b86db23a2b5bf7c45f5778a782`.
Child set SHA256: `551385b8a1b16141f3924315988bdf101d12a6aee2246ac1eb59ff1ba16ad88f`.
Sole executed input change: `_16_AtrMultFirst4: 0.8 -> 1.4`; `_16_AtrMultAfter=1.4` remains frozen.
EX5 SHA256: `212de9f292f2b90c24a71875352d81f39878148c57563b7d23b7a76216eb37db`.

## Evidence
| Window | Parent net / PF / trades / EqDD | Child net / PF / trades / EqDD | Child-parent |
|---|---|---|---|
| MAIN | {m['MAIN']['parent']['net']:.2f} / {m['MAIN']['parent']['pf']:.2f} / {m['MAIN']['parent']['trades']} / {m['MAIN']['parent']['eqdd_pct']:.2f}% | {m['MAIN']['child']['net']:.2f} / {m['MAIN']['child']['pf']:.2f} / {m['MAIN']['child']['trades']} / {m['MAIN']['child']['eqdd_pct']:.2f}% | net {m['MAIN']['delta']['net']:+.2f}; trades {m['MAIN']['delta']['trades']:+d}; EqDD {m['MAIN']['delta']['eqdd_pp']:+.2f}pp |
| BWD | {m['BWD']['parent']['net']:.2f} / {m['BWD']['parent']['pf']:.2f} / {m['BWD']['parent']['trades']} / {m['BWD']['parent']['eqdd_pct']:.2f}% | {m['BWD']['child']['net']:.2f} / {m['BWD']['child']['pf']:.2f} / {m['BWD']['child']['trades']} / {m['BWD']['child']['eqdd_pct']:.2f}% | net {m['BWD']['delta']['net']:+.2f}; trades {m['BWD']['delta']['trades']:+d}; EqDD {m['BWD']['delta']['eqdd_pp']:+.2f}pp |
'''
report += f'''\nMechanical acceptance: `{mechanical['state']}`; all 4 cells exact XAUUSD/M15, leverage 1:100, full-window eligible, and parser reconciliation PASS. Source-graph check compared {source_recon['files_compared']} files: changed={source_recon['changed_count']}, missing={source_recon['missing_count']}; stale launch banner is mtime-only.

The same-install Meta5c parent rerun is the acceptance-critical comparator. Historical Meta5b parent metrics are lineage context only and are not numerically compared across installations.

Year evidence: child MAIN remains positive in 2023/2024/2025; BWD 2021 is negative for both arms and worsens from -573.56 parent to -897.81 child. Both arms still reach realized depth 10, so the result is not explained by the grid becoming inactive.

## Interpretation
The preregistered sign hypothesis is **not falsified**: widening the early zone from 0.8 ATR to 1.4 ATR still leaves aggregate MAIN and BWD net positive. Therefore 0.8 ATR is not proven necessary merely to preserve dual-window positive sign on XAUUSD/M15.

The child is not an improvement direction. Net and participation fall materially in both windows while native EqDD improves only slightly. This supports retaining the narrower early-zone spacing as the stronger research reference for this context, without turning 0.8 into a production/default claim.

`MECHANISM_VALUE = WEAK` for the **wider-early-zone intervention**. This is not a grade of the B16 family.

## Decision
`{comparison['decision']}`. Close this one-change spacing question. Do not open a wider-spacing optimizer, do not retune from BWD, and do not spend HOLDOUT from this result.

## Known unknowns / authority ceiling
No claim is made for other symbols/timeframes, Model4 fidelity of this child, intratrade equity path, Candidate/Grade/KINT, DEMO/LIVE, deployment, trading, or risk/default changes. BWD remains evidence only, never a search surface.

## Lesson / next consumer
Early-zone compression contributes useful participation/net in this XAUUSD/M15 lineage, but it is not required for aggregate dual-window sign. The next B16 research question must be a different unresolved causal question; this spacing direction is closed unless genuinely new evidence creates a distinct consumer.

Visuals: `visuals/r2_parent_child_metrics.svg`, `r2_year_net.svg`, `r2_balance_proxy.svg`, `r2_underwater_proxy.svg`, `r2_depth_distribution.svg`. All are `VISUAL_ONLY_NO_AUTHORITY`.
'''
(RUN/"R2_MECHANISM_REPORT.md").write_text(report,encoding="utf-8")
tracked=[]
for p in sorted(RUN.rglob('*')):
    if not p.is_file() or p.name == 'artifacts.sha256':
        continue
    rel=p.relative_to(RUN).as_posix()
    if rel.startswith('runtime/') or rel in {'R2_MECHANISM_REPORT.md','comparison.json','mechanical_acceptance.json','cell_summary.csv','year_split.csv','source_graph_reconciliation.json','prereg_identity.json','run_receipts.jsonl'} or rel.startswith('visuals/'):
        tracked.append((hashlib.sha256(p.read_bytes()).hexdigest(),rel))
(RUN/'artifacts.sha256').write_text('\n'.join(f'{h}  {rel}' for h,rel in tracked)+'\n',encoding='utf-8')
print(json.dumps({'report':'R2_MECHANISM_REPORT.md','visuals':5,'manifest_entries':len(tracked),'classification':cls,'mechanical':mechanical['state']}))
