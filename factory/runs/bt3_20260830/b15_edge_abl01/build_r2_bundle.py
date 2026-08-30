#!/usr/bin/env python3
import argparse, csv, gzip, hashlib, html, json, re
from collections import defaultdict
from datetime import datetime
from pathlib import Path


def raw_bytes(path):
    raw = Path(path).read_bytes()
    return gzip.decompress(raw) if str(path).lower().endswith('.gz') else raw


def read_text(path):
    raw = raw_bytes(path)
    if raw[:2] in (b'\xff\xfe', b'\xfe\xff'):
        return raw.decode('utf-16', errors='replace')
    return raw.decode('utf-8', errors='replace')


def sha256(path):
    return hashlib.sha256(raw_bytes(path)).hexdigest()


def metric_parts(path):
    text = re.sub(r'<[^>]+>', '|', read_text(path))
    return [html.unescape(x).strip() for x in text.split('|') if html.unescape(x).strip()]


def num(s):
    return float(s.replace(' ', '').replace(',', ''))


def report_metrics(path):
    parts = metric_parts(path)
    out = {}
    labels = {'Total Net Profit:':'net','Profit Factor:':'pf','Total Trades:':'trades',
              'Equity Drawdown Maximal:':'eqdd','History Quality:':'quality','Modelling Quality:':'quality'}
    for i, v in enumerate(parts[:-1]):
        if v in labels and labels[v] not in out:
            out[labels[v]] = parts[i+1]
    m = re.search(r'\(([-+0-9., ]+)%\)', out.get('eqdd',''))
    out['eqdd_pct'] = num(m.group(1)) if m else None
    out['pf_num'] = num(out['pf']); out['trades_num'] = int(num(out['trades']))
    out['net_num'] = num(out['net']); out['report_sha256'] = sha256(path)
    return out

def deals(path, deposit=10000.0):
    rows = re.findall(r'<tr[^>]*>(.*?)</tr>', read_text(path), re.S)
    result, equity, peak = [], deposit, deposit
    for row in rows:
        cells = [html.unescape(re.sub('<[^>]+>', '', c)).strip()
                 for c in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', row, re.S)]
        if len(cells) != 13 or cells[4].lower() != 'out':
            continue
        try:
            t = datetime.strptime(cells[0], '%Y.%m.%d %H:%M:%S')
            pnl = sum(num(cells[i] or '0') for i in (8, 9, 10))
        except ValueError:
            continue
        equity += pnl; peak = max(peak, equity)
        dd = (peak-equity)/peak*100.0 if peak else 0.0
        result.append({'time':t,'pnl':pnl,'equity':equity,'dd_pct':dd})
    return result


def stats(rows, deposit=10000.0):
    gp = sum(max(r['pnl'],0) for r in rows); gl = sum(max(-r['pnl'],0) for r in rows)
    return {'trades':len(rows),'pf':gp/gl if gl else None,
            'net':sum(r['pnl'] for r in rows),'balance_dd_pct':max([r['dd_pct'] for r in rows] or [0.0])}


def yearly(rows):
    groups = defaultdict(list)
    for r in rows: groups[r['time'].year].append(r)
    return {str(y):stats(groups[y]) for y in sorted(groups)}

def svg_series(path, title, series, value_key, ylabel):
    width, height, margin = 900, 360, 55
    panels = list(series.items()); panel_w = (width-3*margin)/max(1,len(panels))
    chunks = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">',
              f'<text x="20" y="24" font-size="17">{html.escape(title)}</text>']
    for j,(name,rows) in enumerate(panels):
        x0=margin+j*(panel_w+margin); y0=50; h=height-105
        vals=[r[value_key] for r in rows] or [0.0]; lo=min(vals); hi=max(vals)
        if hi==lo: hi=lo+1.0
        pts=[]
        for i,v in enumerate(vals):
            x=x0+(i/max(1,len(vals)-1))*panel_w; y=y0+h-(v-lo)/(hi-lo)*h; pts.append(f'{x:.1f},{y:.1f}')
        chunks += [f'<rect x="{x0:.1f}" y="{y0}" width="{panel_w:.1f}" height="{h}" fill="none" stroke="gray"/>',
                   f'<polyline points="{" ".join(pts)}" fill="none" stroke="black" stroke-width="1"/>',
                   f'<text x="{x0:.1f}" y="{height-30}" font-size="13">{html.escape(name)} n={len(rows)}</text>',
                   f'<text x="{x0:.1f}" y="{y0+14}" font-size="11">max={hi:.2f} min={lo:.2f}</text>']
    chunks += [f'<text x="20" y="{height-8}" font-size="11">{html.escape(ylabel)}; exact closed-deal sequence</text>','</svg>']
    Path(path).write_text('\n'.join(chunks), encoding='utf-8')


def svg_years(path, title, ys):
    width,height=900,330; margin=55; bars=[]
    labels=[(w,y,v['net']) for w,d in ys.items() for y,v in d.items()]
    maxabs=max([abs(v) for _,_,v in labels] or [1.0]); base=160; usable=120
    chunks=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">',
            f'<text x="20" y="24" font-size="17">{html.escape(title)}</text>',
            f'<line x1="{margin}" y1="{base}" x2="{width-margin}" y2="{base}" stroke="black"/>']
    step=(width-2*margin)/max(1,len(labels))
    for i,(window,year,val) in enumerate(labels):
        x=margin+i*step+4; bh=abs(val)/maxabs*usable; y=base-bh if val>=0 else base
        chunks.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{max(4,step-8):.1f}" height="{bh:.1f}" fill="gray"/>')
        chunks.append(f'<text x="{x:.1f}" y="{height-48}" font-size="10">{window} {year}</text>')
        chunks.append(f'<text x="{x:.1f}" y="{height-30}" font-size="10">{val:+.2f}</text>')
    chunks += ['<text x="20" y="315" font-size="11">Annual closed-deal net; no smoothing</text>','</svg>']
    Path(path).write_text('\n'.join(chunks), encoding='utf-8')


def svg_parent_child(path, title, parent, child):
    width,height=900,280
    chunks=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">',
            f'<text x="20" y="24" font-size="17">{html.escape(title)}</text>',
            '<text x="20" y="50" font-size="12">Mechanism parent vs one-change child; same install/window</text>']
    y=78
    for w in ('MAIN','BWD'):
        p=parent[w]; c=child[w]
        chunks.append(f'<text x="20" y="{y}" font-size="13">{w}</text>')
        pnet = "UNKNOWN" if p.get("net") is None else f"{p['net']:+.2f}"
        chunks.append(f'<text x="100" y="{y}" font-size="12">parent PF {p["pf"]:.2f} | net {pnet} | EqDD {p["eqdd_pct"]:.2f}% | trades {p["trades"]}</text>')
        y+=22
        chunks.append(f'<text x="100" y="{y}" font-size="12">child  PF {c["pf_num"]:.2f} | net {c["net_num"]:+.2f} | EqDD {c["eqdd_pct"]:.2f}% | trades {c["trades_num"]}</text>')
        y+=34
    chunks += ['<text x="20" y="260" font-size="11">VISUAL_ONLY_NO_AUTHORITY; exact values are in evidence_summary.json</text>','</svg>']
    Path(path).write_text('\n'.join(chunks), encoding='utf-8')

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--config', required=True); ap.add_argument('--out', required=True)
    args=ap.parse_args(); cfg=json.loads(Path(args.config).read_text(encoding='utf-8'))
    out=Path(args.out); out.mkdir(parents=True,exist_ok=True)
    child={}; sequences={}; years={}
    for window in ('MAIN','BWD'):
        rp=Path(cfg['reports'][window]); child[window]=report_metrics(rp)
        sequences[window]=deals(rp); years[window]=yearly(sequences[window])
    summary={'schema':'ea-lab-r2-evidence/1','hypothesis_id':cfg['hypothesis_id'],
             'ea':cfg['ea'],'symbol':cfg['symbol'],'timeframe':cfg['timeframe'],
             'canonical_base_sha':cfg['canonical_base_sha'],'parent':cfg['parent'],
             'child':child,'years':years,'authority':'RESEARCH_ONLY'}
    (out/'evidence_summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    with (out/'equity_curve.csv').open('w',newline='',encoding='utf-8') as f:
        w=csv.writer(f); w.writerow(['window','index','time','pnl','equity','dd_pct'])
        for window,rows in sequences.items():
            for i,r in enumerate(rows,1): w.writerow([window,i,r['time'].isoformat(' '),f'{r["pnl"]:.2f}',f'{r["equity"]:.2f}',f'{r["dd_pct"]:.6f}'])
    with (out/'year_split.csv').open('w',newline='',encoding='utf-8') as f:
        w=csv.writer(f); w.writerow(['window','year','trades','pf','net','balance_dd_pct'])
        for window,d in years.items():
            for year,v in d.items(): w.writerow([window,year,v['trades'],'' if v['pf'] is None else f'{v["pf"]:.6f}',f'{v["net"]:.2f}',f'{v["balance_dd_pct"]:.6f}'])
    svg_series(out/'r2_equity_curve.svg', f"{cfg['hypothesis_id']} child equity", sequences, 'equity', 'Balance proxy from closed deals')
    svg_series(out/'r2_underwater.svg', f"{cfg['hypothesis_id']} child underwater", sequences, 'dd_pct', 'Closed-deal balance drawdown %')
    svg_years(out/'r2_year_distribution.svg', f"{cfg['hypothesis_id']} year distribution", years)
    svg_parent_child(out/'r2_parent_child.svg', f"{cfg['hypothesis_id']} parent vs child", cfg['parent'], child)
    print(json.dumps({'status':'PASS','summary':str(out/'evidence_summary.json'),'child':child},sort_keys=True))

if __name__=='__main__': main()
