# -*- coding: utf-8 -*-
"""Focused negative/attack tests for the M4 legacy migration boundary."""
from __future__ import print_function
import copy, io, json, os, sys

HERE=os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0,HERE)
import legacy_migration as L

FAIL=0

def check(name, ok):
    global FAIL
    print('[%s] %s' % ('OK ' if ok else 'BAD', name))
    if not ok: FAIL += 1


def rejected(fn, needle=None):
    try:
        problems=fn()
    except Exception as exc:
        return needle is None or needle in str(exc)
    text='\n'.join(problems[0] if isinstance(problems,tuple) else problems)
    return bool(text) and (needle is None or needle in text)

strategies=L._load_jsonl(L.STRATEGY_FILE)
evidence=L._load_jsonl(L.EVIDENCE_FILE)
claims=L._load_jsonl(L.CLAIMS_FILE)
manifest=L._load_json(L.MANIFEST_FILE)
catalog=L._load_json(L.CATALOG_FILE)
base_problems, summary=L.validate_all()
check('live migration stores validate', not base_problems and summary['problems']==0)
# Strategy authority mutations.
mut=copy.deepcopy(strategies); mut[0]['promotion_authority']=True
check('legacy strategy cannot gain promotion authority', rejected(lambda:L.validate_strategy_rows(mut,catalog),'promotion authority'))
collision=next(i for i,r in enumerate(strategies) if r['bridge_state']=='BOSS_NUMBER_COLLISION')
mut=copy.deepcopy(strategies); mut[collision]['factory_ea_id']='E011'
check('Boss-number collision cannot map into E011', rejected(lambda:L.validate_strategy_rows(mut,catalog),'must not carry'))
exact=[i for i,r in enumerate(strategies) if r['bridge_state']=='CURRENT_FACTORY_EXACT']
mut=copy.deepcopy(strategies); mut[exact[1]]['factory_ea_id']=mut[exact[0]]['factory_ea_id']
check('Factory E identity cannot be mapped twice', rejected(lambda:L.validate_strategy_rows(mut,catalog),'mapped twice'))
mut=copy.deepcopy(strategies); mut[exact[0]]['bridge_state']='LEGACY_ONLY'; mut[exact[0]]['factory_ea_id']=None
check('E011-E018 exact bridge is closed', rejected(lambda:L.validate_strategy_rows(mut,catalog),'E011-E018'))

# Evidence authority/address mutations.
strategy_ids={r['strategy_id'] for r in strategies}
def ev_problem(change, needle):
    m=copy.deepcopy(evidence); change(m[0]); return rejected(lambda:L.validate_evidence_rows(m,strategy_ids),needle)
check('legacy evidence cannot gain promotion authority', ev_problem(lambda r:r.__setitem__('promotion_authority',True),'promotion authority'))
check('legacy evidence cannot become E3', ev_problem(lambda r:r.__setitem__('legacy_quality','E3_REPRODUCIBLE'),'storage/quality'))
check('absolute vault path is refused', ev_problem(lambda r:r.__setitem__('relative_path','D:/escape/report.htm'),'vault path'))
check('parent traversal is refused', ev_problem(lambda r:r.__setitem__('relative_path','a/../report.htm'),'vault path'))
check('root/storage mismatch is refused', ev_problem(lambda r:r.__setitem__('storage_class','DIRECTORY_SNAPSHOT'),'root/storage'))
check('unknown strategy link is refused', ev_problem(lambda r:r.__setitem__('strategy_ids',['STRAT-LEG-ffffffffffffffff']),'strategy links'))
check('LINKED_SINGLE cardinality is enforced', ev_problem(lambda r:(r.__setitem__('link_state','LINKED_SINGLE'),r.__setitem__('strategy_ids',[])),'link_state'))
check('content-addressed legacy evidence id is enforced', ev_problem(lambda r:r.__setitem__('legacy_evidence_id','leg_evd_sha256_'+'f'*64),'content identity'))
mut=copy.deepcopy(evidence); mut[1]['source_evidence_id']=mut[0]['source_evidence_id']
check('source evidence identity is unique', rejected(lambda:L.validate_evidence_rows(mut,strategy_ids),'duplicate'))

# Historical claims stay claims.
mut=copy.deepcopy(claims); mut[0]['promotion_authority']=True
check('historical claim cannot gain promotion authority', bool(L.validate_claim_rows(mut,strategy_ids)))

# Manifest is a policy lock, not a status table.
mut=copy.deepcopy(manifest); mut['authority']['legacy_evidence_e3_allowed']=True
check('manifest cannot authorize legacy E3', bool(L.validate_manifest(mut,strategies,evidence,claims,{r['source_evidence_id'] for r in evidence})))
mut=copy.deepcopy(manifest); mut['cutover']['legacy_sources_status']='AUTHORITATIVE'
check('legacy status sources cannot regain authority', bool(L.validate_manifest(mut,strategies,evidence,claims,{r['source_evidence_id'] for r in evidence})))
mut=copy.deepcopy(manifest); mut['counts']['source_evidence_total']-=1
check('manifest requires complete M3 evidence coverage', bool(L.validate_manifest(mut,strategies,evidence,claims,{r['source_evidence_id'] for r in evidence})))

# Candidate path must remain structurally separate from the legacy namespace.
schema=json.loads(io.open(os.path.join(HERE,'schemas.json'),encoding='utf-8').read())
defs=schema['$defs']
candidate_blob=json.dumps({'CandidatePayload':defs['CandidatePayload'],'CandidateManifest':defs['CandidateManifest']},sort_keys=True)
check('Candidate schema does not reference LegacyEvidenceRef', 'LegacyEvidenceRef' not in candidate_blob and 'leg_evd_sha256_' not in candidate_blob)
canon=defs['EvidenceRef']
check('canonical EvidenceRef identity contract is unchanged', canon['properties']['evidence_id']['pattern']=='^evd_sha256_[0-9a-f]{64}$' and 'LegacyEvidenceRef' not in json.dumps(canon))

print('M4 legacy migration focused tests: %d failure(s)' % FAIL)
sys.exit(1 if FAIL else 0)