"""Read-only, fail-closed EA_LAB evidence triage candidate (NOT canonical)."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
import re
from pathlib import Path

SCHEMA = "EA_LAB_RESEARCH_EVIDENCE_PACKET_INPUT_V1"
RESULT_SCHEMA = "EA_LAB_RESEARCH_DECISION_PACKET_OFFLINE_CANDIDATE_V1"
DENIALS = dict(candidate_eligible=False, allow_mt5_execution=False,
               allow_factory_submit=False, allow_risk_change=False)
SHA = re.compile(r"^[a-f0-9]{64}$")
MAX_BYTES = 4 * 1024 * 1024
ROLES = {
    "B17_H0": {"closeout"},
    "B17_B6230": {"result", "drift"},
    "B16_H08": {"validation"},
    "BOSS19_R02": {"result"},
    "BOSS19_R03": {"result"},
}

class InputRefused(ValueError):
    def __init__(self, code: str):
        self.code = code
        super().__init__(code)

def read_json_unique(blob: bytes):
    def check_pairs(pairs):
        out = {}
        for k, v in pairs:
            if k in out:
                raise InputRefused("DUPLICATE_JSON_KEY")
            out[k] = v
        return out
    try:
        return json.loads(blob.decode('utf-8-sig'), object_pairs_hook=check_pairs,
                          parse_constant=lambda _: (_ for _ in ()).throw(InputRefused('NONFINITE_JSON')))
    except (UnicodeError, json.JSONDecodeError, RecursionError) as e:
        raise InputRefused("MALFORMED_OR_NONUTF8_JSON") from e

def checked_path(root: Path, rel: str):
    if not isinstance(rel, str) or not rel or '\\' in rel or '\x00' in rel:
        raise InputRefused("INVALID_RELATIVE_PATH")
    if rel.startswith('/') or re.match(r"^[A-Za-z]:", rel):
        raise InputRefused("ABSOLUTE_PATH_FORBIDDEN")
    parts = rel.split('/')
    if any(p in ('', '.', '..') for p in parts):
        raise InputRefused("PATH_TRAVERSAL_OR_AMBIGUOUS")
    path = root
    for part in parts:
        path = path / part
        if path.is_symlink():
            raise InputRefused("SYMLINK_FORBIDDEN")
    if not path.is_file():
        raise InputRefused("RECEIPT_MISSING")
    try:
        if not path.resolve().is_relative_to(root.resolve()):
            raise InputRefused("PATH_ESCAPED_ROOT")
    except OSError as e:
        raise InputRefused("PATH_UNAVAILABLE") from e
    return path

def load_record(root, record):
    if not isinstance(record, dict):
        raise InputRefused("RECORD_INVALID")
    digest = record.get('sha256')
    if not isinstance(digest, str) or not SHA.fullmatch(digest):
        raise InputRefused("PIN_SHA256_INVALID")
    path = checked_path(root, record.get('path'))
    sha = hashlib.sha256()
    chunks=[]
    size=0
    with path.open('rb') as handle:
        while True:
            block=handle.read(131072)
            if not block: break
            size+=len(block)
            if size>MAX_BYTES:
                raise InputRefused("RECEIPT_TOO_LARGE")
            sha.update(block)
            chunks.append(block)
    got=sha.hexdigest()
    if got!=digest:
        raise InputRefused("RECEIPT_HASH_MISMATCH")
    content=b''.join(chunks)
    if path.suffix.lower()=='.json':
        value=read_json_unique(content)
    elif path.suffix.lower()=='.md':
        try: value=content.decode('utf-8-sig')
        except UnicodeError as e: raise InputRefused("NONUTF8_MARKDOWN") from e
    else:
        raise InputRefused("UNSUPPORTED_RECEIPT_FORMAT")
    return {"value":value,"path":record['path'],"sha256":got,"size":size}

def obj(v): return v if isinstance(v,dict) else {}

def evaluate(kind, recs):
    # Evidence is untrusted data even if bytes match a supplied pin.
    # No case can be a Native/Model4 acceptance or Candidate.
    if kind=='B17_H0':
        txt=recs['closeout']['value']
        if not isinstance(txt,str): raise InputRefused("B17_CLOSEOUT_FORMAT")
        required=('Hard Kill','25.58%','2023-03-10','MAIN')
        if not all(x in txt for x in required):
            raise InputRefused("B17_HISTORICAL_MARKERS_MISSING")
        return ('REJECT_HISTORICAL_NEGATIVE',['HISTORICAL_HARD_KILL','SUMMARY_NOT_RAW_NATIVE'],
                'Original B17 H0 historical closeout; native agent log bytes not directly authenticated')
    if kind=='B17_B6230':
        a=obj(recs['result']['value']); b=obj(recs['drift']['value'])
        if a.get('schema')!='W5_B6230_TEST_RESULT_V1' or b.get('schema')!='W5_B6230_DATA_SHA_POSTTEST_V2_AUDIT':
            raise InputRefused("W5_SCHEMA_MISMATCH")
        dc=b.get('drift_count'); checked=b.get('checked_count')
        if not isinstance(dc,int) or isinstance(dc,bool) or not isinstance(checked,int) or isinstance(checked,bool) or dc<0 or checked<1:
            raise InputRefused("W5_DRIFT_COUNTER_INVALID")
        if a.get('cell')!='MAIN_OFF': raise InputRefused("W5_CELL_MISMATCH")
        if dc>0 or a.get('data_unchanged') is False:
            return ('REFUSE_MECHANICAL_PROVENANCE',['BROKER_DATA_POSTCONDITION_FAILED',f'DRIFT_{dc}_OF_{checked}'],
                    'Native runner report does not override post-test hash drift')
        return ('UNKNOWN_INCOMPLETE',['NO_INDEPENDENT_NATIVE_ATTESTATION'],
                'No evidence of drift in supplied summaries is not Native acceptance')
    if kind=='B16_H08':
        a=obj(recs['validation']['value']); selected=obj(a.get('selected_center'))
        if a.get('schema')!='ea-lab-b16-h08-validation-evidence/1' or selected.get('_16_RsiPeriod')!=14 or selected.get('_16_RsiLow')!=35.0:
            raise InputRefused("B16_IDENTITY_MISMATCH")
        cells=a.get('cells')
        if not isinstance(cells,list) or len(cells)!=2 or set(obj(x).get('window') for x in cells)!={'MAIN','BWD'}:
            raise InputRefused("B16_WINDOWS_INVALID")
        if a.get('classification')!='FIXED_VALIDATION_FAIL':
            return ('UNKNOWN_INCOMPLETE',['UNEXPECTED_H08_CLASS'], 'Do not infer a profitable variant')
        return ('REJECT_HISTORICAL_NEGATIVE',['BWD_NONTRANSFER','SELECTED_14_35_ONLY','PARENT_14_30_UNTOUCHED'],
                'H08 14/35 selected center fails fixed BWD; original parent is a separate lineage')
    if kind=='BOSS19_R02':
        a=obj(recs['result']['value']); g=obj(a.get('evidence_contract_gate'))
        if a.get('schema_version')!='BOSS19_P4B_UNIT_EXPORT_REPAIR02_RESULT_V1':raise InputRefused('BOSS19_R02_SCHEMA_MISMATCH')
        if g.get('code')=='MAGIC_FIELD_NOT_SOURCE_BOUND' and g.get('status')=='BLOCKED':
            return ('REFUSE_MECHANICAL_PROVENANCE',['DEAL_MAGIC_NOT_SOURCE_BOUND'],
                    'Source-configured magic does not authenticate HistoryDealGetInteger(deal, DEAL_MAGIC)')
        return ('UNKNOWN_INCOMPLETE',['REPAIR02_PROVENANCE_NOT_PROVEN'],'Do not promote counts as provenance')
    if kind=='BOSS19_R03':
        a=obj(recs['result']['value']); g=obj(a.get('source_magic_gate'))
        rev=obj(a.get('independent_review'))
        if a.get('schema_version')!='BOSS19_P4B_UNIT_EXPORT_REPAIR03_RESULT_V1':raise InputRefused('BOSS19_R03_SCHEMA_MISMATCH')
        if (a.get('status')=='PASS' and g.get('status')=='PASS' and
                g.get('source_magic_provenance')=='PER_DEAL_HISTORY_DEAL_MAGIC' and rev.get('verdict')=='PASS'):
            return ('RESEARCH_REFERENCE_ONLY',['HISTORICAL_REPAIR_REVIEW_RECORDED','NATIVE_NOT_REATTESTED'],
                    'Repair03 report records source-bound per-deal magic; broker swap economic delta disclosed')
        return ('UNKNOWN_INCOMPLETE',['REPAIR03_PROVENANCE_NOT_PROVEN'],
                'Missing repaired provenance or review prevents positive historical reference')
    raise InputRefused("UNKNOWN_CASE_KIND")

def packet(root:Path, manifest:dict):
    if not isinstance(manifest,dict) or manifest.get('schema')!=SCHEMA:
        raise InputRefused("MANIFEST_SCHEMA_INVALID")
    cases=manifest.get('cases')
    if not isinstance(cases,list) or not 1<=len(cases)<=20:
        raise InputRefused("CASE_COUNT_INVALID")
    found=set(); out=[]
    for idx,case in enumerate(cases):
        if not isinstance(case,dict):
            raise InputRefused("CASE_NOT_OBJECT")
        cid=case.get('case_id'); kind=case.get('kind')
        if not isinstance(cid,str) or not re.fullmatch('[A-Za-z0-9_-]{1,96}',cid) or cid in found:
            raise InputRefused("CASE_ID_INVALID_OR_DUPLICATE")
        found.add(cid)
        item=dict(case_id=cid, kind=kind, evidence_integrity='UNKNOWN',
                  strategy_quality='NOT_JUDGED', authority='RESEARCH_ONLY',
                  native_authenticated=False, owner_authenticated=False, **DENIALS)
        try:
            if kind not in ROLES: raise InputRefused("CASE_KIND_UNSUPPORTED")
            records=case.get('records')
            if not isinstance(records,list) or len(records)!=len(ROLES[kind]):
                raise InputRefused("RECORD_COUNT_INVALID")
            roles={}; paths=set()
            for record in records:
                if not isinstance(record,dict) or record.get('role') not in ROLES[kind] or record['role'] in roles:
                    raise InputRefused("RECORD_ROLE_INVALID_OR_DUPLICATE")
                if record.get('path') in paths:
                    raise InputRefused("DUPLICATE_INPUT_PATH")
                paths.add(record.get('path'))
                roles[record['role']]=load_record(root,record)
            if set(roles)!=ROLES[kind]: raise InputRefused('REQUIRED_ROLES_MISSING')
            status,reasons,notes=evaluate(kind,roles)
            item.update(status=status,reasons=reasons,notes=notes,
                        evidence_integrity='PINNED_BYTES_MATCH_UNVERIFIED_OWNER',
                        source_receipts=[dict(role=k,path=v['path'],sha256=v['sha256'],bytes=v['size']) for k,v in sorted(roles.items())])
        except (InputRefused,OSError,ValueError,TypeError) as exc:
            code=exc.code if isinstance(exc,InputRefused) else 'TOOL_OR_INPUT_FAILURE'
            item.update(status='UNKNOWN_INCOMPLETE',reasons=[code],
                        notes='Fail closed: this case cannot support a research or execution acceptance',source_receipts=[])
        out.append(item)
    return dict(schema=RESULT_SCHEMA,authority='OFFLINE_PROTOTYPE_NOT_CANONICAL',
                source='local files supplied in task-local root, SHA256 pins are caller claims',
                candidate_promotions=0,**DENIALS,cases=out)

def markdown(result):
    lines=['# EA_LAB Research Decision Packet (offline candidate)','',
           '**NOT source-admitted, not Native accepted, no Candidate/MT5/Factory/Risk grants.**','',
           '| Case | Classification | Evidence | Reasons |','|---|---|---|---|']
    for r in result['cases']:
        cells=[str(r[k]).replace('|','/').replace('\n',' ') for k in ('case_id','status','evidence_integrity')]
        lines.append('| '+' | '.join(cells+[', '.join(r['reasons'])])+' |')
    lines.append('\nAll outputs fail closed. A caller-supplied SHA pin does not prove native owner identity.')
    return '\n'.join(lines)+'\n'

def main(argv=None):
    ap=argparse.ArgumentParser(description='Offline, source-neutral, read-only evidence triage candidate')
    ap.add_argument('--root',type=Path,required=True,help='Isolated authorized input root')
    ap.add_argument('--manifest',type=Path,required=True,help='Case manifest, read-only')
    ap.add_argument('--out-dir',type=Path,required=True,help='Unused output dir; never overwrites files')
    ns=ap.parse_args(argv)
    if not ns.root.is_dir(): ap.error('root is not a directory')
    if not ns.manifest.is_file(): ap.error('manifest missing')
    if ns.out_dir.exists(): ap.error('output path already exists; overwrite forbidden')
    try:
        m=read_json_unique(ns.manifest.read_bytes())
        result=packet(ns.root,m)
    except (InputRefused,OSError) as e:
        ap.error('input refused: '+str(e))
    # Keep all inputs read-only and refuse the output dir overlapping the source root.
    if ns.out_dir.resolve().is_relative_to(ns.root.resolve()):
        ap.error('output directory may not be nested under the input root')
    ns.out_dir.mkdir(parents=True,exist_ok=False)
    (ns.out_dir/'RESEARCH_DECISION_PACKET.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    (ns.out_dir/'RESEARCH_DECISION_PACKET.md').write_text(markdown(result),encoding='utf-8')
    print(json.dumps({'cases':len(result['cases']),'promotions':0,'refused_or_blocked':sum(x['status'] not in ('RESEARCH_REFERENCE_ONLY',) for x in result['cases']), 'output':str(ns.out_dir)},sort_keys=True))
    return 0
if __name__=='__main__':
    raise SystemExit(main())
