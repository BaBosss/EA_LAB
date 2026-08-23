# -*- coding: utf-8 -*-
"""Deterministic one-time M4 importer from frozen M1-M4 consolidation evidence."""
from __future__ import print_function
import argparse, hashlib, io, json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(REPO_ROOT, 'factory', 'legacy_migration')


def load_jsonl(path):
    rows=[]
    with io.open(path, 'r', encoding='utf-8-sig') as fh:
        for line in fh:
            if line.strip(): rows.append(json.loads(line))
    return rows


def sha_file(path):
    h=hashlib.sha256()
    with open(path,'rb') as fh:
        for chunk in iter(lambda: fh.read(1024*1024), b''): h.update(chunk)
    return h.hexdigest()


def line_bytes(rows):
    return ''.join(json.dumps(r, ensure_ascii=False, sort_keys=True, separators=(',',':'))+'\n' for r in rows).encode('utf-8')


def write_bytes(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path,'wb') as fh: fh.write(data)


def storage_for(root_id):
    if root_id in ('EA_LAB','FOREX'): return 'TAR_SNAPSHOT'
    if root_id == 'EA_PROJECT': return 'DIRECTORY_SNAPSHOT'
    if root_id.startswith('MT4_') or root_id.startswith('MT5_'): return 'TERMINAL_CAS_ARCHIVE'
    raise ValueError('unsupported root alias %r' % root_id)


def rank_alias(a):
    root=a['root_alias']
    pri={'EA_LAB':0,'EA_PROJECT':1,'FOREX':2}.get(root,3)
    return (pri, root, a.get('relative_path') or '')


def git_head():
    p=subprocess.run(['git','-C',REPO_ROOT,'rev-parse','HEAD'],capture_output=True,text=True)
    if p.returncode: raise RuntimeError('cannot resolve repo HEAD')
    return p.stdout.strip()


def source_paths(root):
    return {
        'strategy_bridge': os.path.join(root,'M4_READONLY','STRATEGY_BRIDGE.jsonl'),
        'evidence_addressability': os.path.join(root,'M4_READONLY','EVIDENCE_ADDRESSABILITY.jsonl'),
        'canonical_evidence_manifest': os.path.join(root,'M4_READONLY','CURRENT_EVIDENCE_MANIFEST.jsonl'),
        'm3_evidence': os.path.join(root,'M3','EVIDENCE_RECORDS.jsonl'),
        'm2_claims': os.path.join(root,'M2','HISTORICAL_CLAIMS.jsonl'),
        'm1_aliases': os.path.join(root,'M1','OBJECT_ALIAS_MAP.jsonl'),
    }


def build(source_root):
    src=source_paths(source_root)
    bridge=load_jsonl(src['strategy_bridge'])
    strategies=[]
    for r in sorted(bridge,key=lambda x:x['strategy_id']):
        strategies.append({
            'entity':'LegacyStrategyRef','strategy_id':r['strategy_id'],
            'canonical_name_candidate':r['canonical_name_candidate'],
            'bridge_state':r['bridge_state'],'factory_ea_id':r.get('factory_ea_id'),
            'identity_confidence':r['identity_confidence'],'promotion_authority':False})
    addr={r['evidence_id']:r for r in load_jsonl(src['evidence_addressability'])}
    canon_rows=load_jsonl(src['canonical_evidence_manifest'])
    canon_by_sha={r['raw_sha256']:r['evidence_id'] for r in canon_rows}
    m3=load_jsonl(src['m3_evidence'])
    needed={a['object_id'] for r in m3 for a in r.get('aliases',[])}
    alias_by_id={}
    with io.open(src['m1_aliases'],'r',encoding='utf-8-sig') as fh:
        for line in fh:
            if not line.strip(): continue
            r=json.loads(line)
            if r.get('object_id') in needed: alias_by_id[r['object_id']]=r
    legacy, reuse = [], []
    for r in sorted(m3,key=lambda x:x['evidence_id']):
        a=addr[r['evidence_id']]
        raw=a['raw_sha256']
        if a.get('already_registered'):
            cid=canon_by_sha.get(raw)
            if cid != 'evd_sha256_'+raw:
                raise ValueError('registered evidence missing canonical identity: %s' % r['evidence_id'])
            reuse.append({'source_evidence_id':r['evidence_id'],'canonical_evidence_id':cid,'raw_sha256':raw})
            continue
        candidates=[alias_by_id[x['object_id']] for x in r.get('aliases',[]) if x.get('object_id') in alias_by_id]
        if not candidates:
            raise ValueError('no M1 alias for %s' % r['evidence_id'])
        loc=sorted(candidates,key=rank_alias)[0]
        ids=sorted({x['strategy_id'] for x in r.get('strategy_links',[])})
        q=r['quality_level']
        if q == 'E3_REPRODUCIBLE':
            raise ValueError('E3 cannot enter LegacyEvidenceRef: %s' % r['evidence_id'])
        legacy.append({
            'entity':'LegacyEvidenceRef','legacy_evidence_id':'leg_evd_sha256_'+raw,
            'source_evidence_id':r['evidence_id'],'raw_sha256':raw,'byte_length':r['size_bytes'],
            'vault_id':'PREMIG_20260823','root_id':loc['root_alias'],
            'relative_path':loc['relative_path'].replace('\\','/'),'storage_class':storage_for(loc['root_alias']),
            'evidence_role':r['evidence_role'],'legacy_quality':q,'link_state':r['link_state'],
            'strategy_ids':ids,'promotion_authority':False})
    claims=[]
    for r in sorted(load_jsonl(src['m2_claims']),key=lambda x:x['claim_id']):
        x=dict(r)
        x['matched_strategy_ids']=sorted(set(x.get('matched_strategy_ids') or []))
        x['promotion_authority']=False
        claims.append(x)
    data={
        'strategy_bridge.jsonl':line_bytes(strategies),
        'evidence_refs.jsonl':line_bytes(legacy),
        'historical_claims.jsonl':line_bytes(claims),
    }
    source_hashes={k:{'sha256':sha_file(v),'byte_length':os.path.getsize(v)} for k,v in sorted(src.items())}
    artifact_hashes={k:hashlib.sha256(v).hexdigest() for k,v in data.items()}
    manifest={
        'schema_version':1,'migration_id':'M4-20260823','implementation_base':git_head(),
        'source_artifacts':source_hashes,
        'counts':{'strategy_refs':len(strategies),'legacy_evidence_refs':len(legacy),
                  'historical_claims':len(claims),'canonical_evidence_reuse':len(reuse),
                  'source_evidence_total':len(m3)},
        'authority':{'legacy_strategy_promotion':False,'legacy_evidence_candidate_eligible':False,
                     'legacy_evidence_e3_allowed':False,'physical_cleanup_authorized':False},
        'cutover':{
            'legacy_sources_status':'HISTORICAL_GENERATED_ONLY',
            'retired_authorities':['RUN_LOG.csv','EA_MASTER_INDEX.csv','EA_STRATEGY_GUIDE.md:status_sections',
                                   'EA_SCORECARD_AND_REGISTRY.md:registry_status_sections'],
            'strategy_authority':'factory/strategy_catalog.json',
            'run_authority':'factory/runs/*.jsonl',
            'evidence_authority':'docs/memory_control/experiment_events/evidence-manifest.jsonl',
            'legacy_migration_authority':'factory/legacy_migration/',
            'deployment_authority':'portfolio/DEPLOYMENTS.csv'},
        'canonical_evidence_reuse':sorted(reuse,key=lambda x:x['source_evidence_id']),
        'artifact_sha256':artifact_hashes,
    }
    data['manifest.json']=(json.dumps(manifest,ensure_ascii=False,sort_keys=True,indent=2)+'\n').encode('utf-8')
    return data, manifest


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--source-root',required=True)
    ap.add_argument('--check',action='store_true')
    args=ap.parse_args()
    data, manifest=build(os.path.abspath(args.source_root))
    bad=[]
    for name, blob in data.items():
        path=os.path.join(OUT,name)
        if args.check:
            try:
                with open(path,'rb') as fh: current=fh.read()
            except OSError:
                current=None
            if current != blob: bad.append(name)
        else:
            write_bytes(path,blob)
    print(json.dumps(manifest['counts'],sort_keys=True))
    if args.check:
        if bad:
            print('M4 IMPORT DRIFT: '+', '.join(bad)); return 1
        print('M4 IMPORT CHECK: CLEAN'); return 0
    print('M4 IMPORT WRITTEN: '+OUT); return 0


if __name__ == '__main__':
    sys.exit(main())