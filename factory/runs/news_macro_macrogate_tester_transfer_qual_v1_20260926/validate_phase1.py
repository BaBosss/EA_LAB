"""Planning/package validation only. No MQL compilation, MT5, trade or runtime qualification."""
from pathlib import Path
import argparse, copy, csv, hashlib, io, json, subprocess

def load(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def digest(data): return hashlib.sha256(data).hexdigest()
def require(ok, message):
    if not ok: raise ValueError(message)

def schema_gate(p,c):
    require(p['disposition']=='READY_FOR_PROSPECTIVE_IMPLEMENTATION','disposition')
    require(p['implementation_ready'] is True,'implementation-ready')
    for k in ('performance_execution_authorized','implementation_authorized_now'): require(p[k] is False,k)
    for k in ('performance_authorized','implementation_authorized_now'): require(c[k] is False,k)
    require(p['holdout']=='LOCKED_UNSPENT' and c['authority_ceiling']['holdout']=='LOCKED_UNSPENT','holdout')
    require(p['consumed_blocker']['bwd_attempt_denominator'] is None,'historical denominator')
    require(p['consumed_blocker']['bwd_denominator_status']=='UNAVAILABLE_NOT_CERTIFIED','historical certification')
    require(p['transfer_contract']==c['transfer'] and p['denominator_design']==c['denominator'],'mirrored design')
    t=c['transfer']; d=c['denominator']
    require('not embedded in EX5' in t['compile_semantics'],'transfer timing')
    require('CryptEncode(CRYPT_HASH_SHA256' in t['runtime_future_adapter'] and 'BEFORE strategy' in t['runtime_future_adapter'],'raw hash requirement')
    require('same immutable uchar buffer' in t['same_buffer_rule'],'same-buffer parser')
    require(d['independent_of_MG_SelfGate'] is True and '_MG_SelfGate' not in d['enable_condition'],'BASE-enabled telemetry')
    require(d['enable_condition']=='defined(LAB_MG_TESTER_EVIDENCE_QUAL) && MQL_TESTER','tester-only flag')
    require(d['historical_bwd_denominator'] is None and d['retrospective_substitution_forbidden'] is True,'no rewrite')
    require(set(('execution_entry_total','submit_total','native_request_total','accepted_request_total','rejected_request_total','unresolved_request_total','entry_fill_total')).issubset(d['units']),'distinct units')
    require(d['formula']['denominator']=='execution_entry_total in the SAME certified arm/window','ratio unit')
    require(any('scripts/tpl_regression.ps1' in x and 'CLEAN' in x for x in c['required_gates']),'TPL gate')
    require(c['probe']['production_wrapper_directive_count']==11 and c['probe']['probe_directive_count_per_variant']==1,'probe count')

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--repo',type=Path);ap.add_argument('--out',type=Path)
    args=ap.parse_args();wt=args.repo or Path(__file__).resolve().parents[3]
    run=wt/'factory/runs/news_macro_macrogate_tester_transfer_qual_v1_20260926'
    p=load(run/'PHASE1_QUALIFICATION.json');c=load(run/'PROSPECTIVE_IMPLEMENTATION_CONTRACT.json');m=load(run/'PACKAGE_MANIFEST.json');b=load(run/'SOURCE_BINDING.json')
    schema_gate(p,c);counts={'schema':1,'package_hashes':0,'source_blocker_hashes':0,'accepted_feeds':0,'official_references':0,'negative_schema_cases':0,'negative_file_cases':0}
    for f in m['files']:
        raw=(wt/f['path']).read_bytes();require(digest(raw)==f['sha256'] and len(raw)==f['bytes'],'package '+f['path']);counts['package_hashes']+=1
    for f in b['source_files']+b['blocker_files']:
        require(digest((wt/f['path']).read_bytes())==f['sha256'],'source '+f['path']);counts['source_blocker_hashes']+=1
    exp=load(run/'FEED_RUNTIME_EXPECTATIONS.json')['entries'];require(len(exp)==11,'eleven feeds')
    for f in exp:
        raw=(wt/f['source_path']).read_bytes();rows=list(csv.DictReader(io.StringIO(raw.decode('utf-8-sig'))))
        require(digest(raw)==f['sha256'] and len(raw)==f['bytes'],'feed bytes')
        require(len(rows)==f['rows'] and rows[0]['datetime']==f['first'] and rows[-1]['datetime']==f['last'],'feed metadata');counts['accepted_feeds']+=1
    refs=load(run/'MQL5_REFERENCE_BINDING.json')['references'];require(len(refs)==9,'references')
    for f in refs: require(digest(Path(f['path']).read_bytes())==f['sha256'],'official capture');counts['official_references']+=1
    raw=(wt/exp[0]['source_path']).read_bytes();lines=raw.splitlines(keepends=True);changed=list(lines);old=changed[2].split(b',')[0];changed[2]=changed[2].replace(old,old[:-5]+b'03:00',1);wrong=b''.join(changed);stale=b''.join(lines[:-1])
    fixtures={x['id']:x for x in c['probe']['fixtures']}
    require(digest(wrong)==fixtures['WRONG_SAME_METADATA']['actual_sha256'] and digest(wrong)!=digest(raw),'wrong-byte negative')
    require(len(wrong)==len(raw) and len(changed)==len(lines) and changed[1]==lines[1] and changed[-1]==lines[-1],'equal-metadata negative')
    require(digest(stale)==fixtures['STALE_TRUNCATED_COPY']['actual_sha256'] and digest(stale)!=digest(raw),'stale-copy negative')
    require(fixtures['MISSING']['actual_sha256'] is None and fixtures['POSITIVE_GOLDEN_REAL']['actual_sha256']==digest(raw),'missing/positive fixture')
    counts['negative_file_cases']=3
    mutations=[lambda x,y:x.update(performance_execution_authorized=True),lambda x,y:x.update(implementation_authorized_now=True),lambda x,y:x['consumed_blocker'].update(bwd_attempt_denominator=220),lambda x,y:y['denominator'].update(enable_condition='MQL_TESTER && _MG_SelfGate'),lambda x,y:y['transfer'].update(same_buffer_rule='reopen file'),lambda x,y:y['probe'].update(production_wrapper_directive_count=12)]
    for mutate in mutations:
        a,z=copy.deepcopy(p),copy.deepcopy(c);mutate(a,z)
        try: schema_gate(a,z)
        except ValueError: counts['negative_schema_cases']+=1
        else: raise ValueError('schema mutant was not detected')
    head=subprocess.check_output(['git','-C',str(wt),'rev-parse','HEAD'],text=True).strip()
    source_delta=subprocess.check_output(['git','-C',str(wt),'diff','--name-only',p['canonical_sha'],'--','ea_template','scripts'],text=True).strip()
    require(not source_delta,'source changed during planning')
    doc=(wt/'docs/research/NEWS_MACRO_MACROGATE_TESTER_TRANSFER_QUAL_V1_20260926.md').read_text(encoding='utf-8-sig')
    require('\x0c' not in doc and '_MG_InCommon=false' in doc and 'NOT IMPLEMENTED' in doc,'document identity')
    report={'status':'PASS','review_scope':'PLANNING_PACKAGE_AND_HOST_ONLY_NEGATIVE_CHECKS','head_at_check':head,'counts':counts,'mt5_runs':0,'runtime_byte_hash_qualification':'NOT_RUN','native_telemetry_qualification':'NOT_RUN','source_implementation':'NOT_AUTHORIZED','old_bwd_denominator':None,'holdout':'LOCKED_UNSPENT'}
    if args.out:
        require(not args.out.exists(),'preserve existing validation output');args.out.parent.mkdir(parents=True,exist_ok=True);args.out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report))

if __name__=='__main__': main()
