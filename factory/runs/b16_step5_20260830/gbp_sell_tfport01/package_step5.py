import gzip, hashlib, json
from pathlib import Path
ROOT=Path(r'D:\EA_LAB_CONTROL\worktrees\b16-gbp-sell-tfport01-20260830\factory\runs\b16_step5_20260830\gbp_sell_tfport01')
for p in sorted(ROOT.glob('runtime/*/*/report.htm')):
    raw=p.read_bytes(); out=p.with_suffix(p.suffix+'.gz')
    with out.open('wb') as f:
        with gzip.GzipFile(filename='',mode='wb',fileobj=f,mtime=0) as g: g.write(raw)
    p.unlink()
log=ROOT/'execution_console.log'
if log.exists():
    raw=log.read_bytes(); out=ROOT/'execution_console.log.gz'
    with out.open('wb') as f:
        with gzip.GzipFile(filename='',mode='wb',fileobj=f,mtime=0) as g: g.write(raw)
    log.unlink()
# compact visual: exact full-window net by timeframe/window
summary=json.loads((ROOT/'evidence_summary.json').read_text(encoding='utf-8'))
vals={(r['tf'],r['window']):r['net'] for r in summary['cells']}
vals.update({('H4','MAIN'):283.20,('H4','BWD'):268.97})
w,h=840,320; x0=80; base=155; scale=0.35
chunks=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}">','<text x="20" y="25" font-size="17">B16 GBPUSD SELL timeframe portability — full-window net</text>',f'<line x1="40" y1="{base}" x2="810" y2="{base}" stroke="black"/>']
i=0
for tf in ('M15','H1','H4'):
    for window in ('MAIN','BWD'):
        v=vals[(tf,window)]; x=x0+i*110; bh=abs(v)*scale; y=base-bh if v>=0 else base
        chunks += [f'<rect x="{x}" y="{y:.1f}" width="70" height="{bh:.1f}" fill="gray"/>',f'<text x="{x}" y="280" font-size="12">{tf} {window}</text>',f'<text x="{x}" y="300" font-size="12">{v:+.2f}</text>']; i+=1
chunks += ['<text x="20" y="315" font-size="10">VISUAL_ONLY_NO_AUTHORITY; H4 is accepted prior evidence, H1/M15 are Step-5 cells.</text>','</svg>']
(ROOT/'tf_portability_net.svg').write_text('\n'.join(chunks),encoding='utf-8')
# deterministic package manifest
lines=[]
for p in sorted(x for x in ROOT.rglob('*') if x.is_file() and x.name!='artifacts.sha256'):
    lines.append(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(ROOT).as_posix())
(ROOT/'artifacts.sha256').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('PACKAGED',len(lines))