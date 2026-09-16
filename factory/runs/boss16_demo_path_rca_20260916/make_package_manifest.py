import argparse, hashlib, json
from pathlib import Path
P=Path(__file__).resolve().parent; ROOT=P.parents[2]; OUT=P/'package_manifest.json'
def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for c in iter(lambda:f.read(1024*1024),b''): h.update(c)
    return h.hexdigest()
FILES=[x for x in sorted(P.iterdir()) if x.is_file() and x.name!='package_manifest.json']
DOC=ROOT/'docs/research/BOSS16_DEMO_MODEL1_PATH_RCA_20260916.md'
FILES.append(DOC)
def build():
    rows=[]
    for p in FILES:
        rel=str(p.relative_to(ROOT)).replace('\\','/')
        rows.append({'path':rel,'bytes':p.stat().st_size,'sha256':sha(p)})
    return {'schema':'boss16_demo_path_rca_package/1','authority':'RESEARCH_DIAGNOSTIC_ONLY_ZERO_NEW_MT5',
            'direct_consumer':'Boss16 Demo-vs-Model1 divergence RCA and real-tick source qualification routing','artifacts':rows}
def check(m):
    errs=[]
    for x in m['artifacts']:
        p=ROOT/x['path']
        if not p.exists(): errs.append('missing:'+x['path']); continue
        if p.stat().st_size!=x['bytes'] or sha(p)!=x['sha256']: errs.append('mismatch:'+x['path'])
    return errs
ap=argparse.ArgumentParser(); ap.add_argument('--check',action='store_true'); a=ap.parse_args()
if a.check:
    m=json.loads(OUT.read_text(encoding='utf-8')); errs=check(m); print(json.dumps({'status':'PASS' if not errs else 'FAIL','errors':errs,'artifacts':len(m['artifacts'])},indent=2)); raise SystemExit(0 if not errs else 2)
m=build(); OUT.write_text(json.dumps(m,indent=2),encoding='utf-8'); print(json.dumps({'status':'BUILT','artifacts':len(m['artifacts'])},indent=2))
