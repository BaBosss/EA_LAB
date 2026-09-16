"""Validate the inert Arxon design library; never invoke MT5 or modify the repository."""
from __future__ import annotations
import argparse
import copy
import json
from pathlib import Path
import re
import sys

EXPECTED_FAMILIES = {f'ARX-{i:02d}' for i in range(1, 7)}
EXPECTED_COMPONENTS = {f'W{i:02d}' for i in range(1, 9)} | {f'M{i:02d}' for i in range(1, 12)} | {f'O{i:02d}' for i in range(1, 5)}
FALSE_TOP = ('execution_authority', 'ready_for_mt5', 'source_parity_proven')
NULL_TOP = ('factory_family_id', 'lab_entry_id', 'selected_parent', 'home', 'risk_defaults')

def validate_catalog(doc: dict) -> list[str]:
    e = []
    def require(ok: bool, message: str) -> None:
        if not ok: e.append(message)
    require(doc.get('schema') == 'ARXON_NON_EXECUTABLE_DESIGN_CARDS_V1', 'schema mismatch')
    require(doc.get('implementation_status') == 'NOT_IMPLEMENTED', 'implementation status')
    require(doc.get('object_type') == 'DESIGN_LIBRARY_NOT_FACTORY_STRATEGY_CATALOG', 'catalog authority')
    require(bool(re.fullmatch(r'[0-9a-f]{40}', doc.get('base_canonical_sha', ''))), 'invalid base SHA')
    for k in FALSE_TOP: require(doc.get(k) is False, f'{k} must be false')
    for k in NULL_TOP: require(k in doc and doc[k] is None, f'{k} must be null')
    fs, cs = doc.get('families', []), doc.get('components', [])
    require(len(fs) == doc.get('tool_count') == 6, 'family count')
    require(len(cs) == doc.get('module_slot_count') == 23, 'component count')
    require({x.get('id') for x in fs} == EXPECTED_FAMILIES, 'family IDs')
    require({x.get('component_id') for x in cs} == EXPECTED_COMPONENTS, 'component IDs')
    require('CLOSED_NEGATIVE' in doc.get('protected_branch',''), 'closed branch not preserved')
    sources={s['id'] for s in doc.get('sources',[])}
    require(sources == {f'S{i:02d}' for i in range(1,10)}, 'source coverage')
    for f in fs:
        fid=f.get('id')
        require(f.get('stage') == 'NON_EXECUTABLE_STRATEGY_DESIGN', f'{fid}: stage')
        for k in ('ea_implemented','compiled','backtested','exact_parity_proven'):
            require(f.get(k) is False, f'{fid}: {k}')
        for k in ('entry_rule','exit_rule','risk_config','selected_parent'):
            require(k in f and f[k] is None, f'{fid}: {k}')
        require(set(f.get('source_refs',[])) <= sources, f'{fid}: unknown source')
        actual={c.get('component_id') for c in cs if c.get('family_id')==fid}
        require(set(f.get('component_ids',[])) == actual, f'{fid}: component mapping')
    graph={}
    for c in cs:
        cid=c.get('component_id')
        require(c.get('family_id') in EXPECTED_FAMILIES, f'{cid}: family')
        require(c.get('status')=='NON_EXECUTABLE_STRATEGY_DESIGN', f'{cid}: status')
        for k in ('implemented','compiled','backtested','trading_authority'):
            require(c.get(k) is False, f'{cid}: {k}')
        for k in ('selected_role','selected_direction','entry_rule','exit_rule','risk_config','selected_parent','home'):
            require(k in c and c[k] is None, f'{cid}: {k}')
        for k in ('source_locator','source_summary','proposal_not_approved_semantics','scope_blocker'):
            require(isinstance(c.get(k),str) and bool(c[k].strip()), f'{cid}: missing {k}')
        for k in ('freeze_fields','proposed_outputs','test_cases_not_run'):
            require(isinstance(c.get(k),list) and bool(c[k]), f'{cid}: missing {k}')
        deps=c.get('dependencies',[]);graph[cid]=deps
        require(set(deps) <= EXPECTED_COMPONENTS, f'{cid}: dependency reference')
        if cid in ('W06','M10'):
            require(c.get('target_kind')=='INFRASTRUCTURE_ONLY', f'{cid}: not a standalone EA')
    def visit(n: str, trail: set[str]) -> None:
        if n in trail: e.append('dependency cycle'); return
        for d in graph.get(n,[]): visit(d,trail|{n})
    for n in graph: visit(n,set())
    return e

def validate_files(root: Path, repo: Path | None) -> list[str]:
    errors=[]
    catalog=json.loads((root/'catalog.json').read_text(encoding='utf-8-sig'))
    errors.extend(validate_catalog(catalog))
    receipts=json.loads((root/'source_receipts.json').read_text(encoding='utf-8-sig'))
    if len(receipts)!=7 or {r.get('id') for r in receipts}!={f'S{i:02d}' for i in range(1,8)}:
        errors.append('fresh source receipt coverage')
    for r in receipts:
        if r.get('status')!='CAPTURED' or not re.fullmatch('[0-9a-f]{64}',r.get('sha256','')):
            errors.append('unqualified source capture receipt')
    for path in root.rglob('*'):
        if path.suffix.lower() in ('.mq5','.mqh','.ex5','.set'): errors.append(f'executable artifact: {path}')
    for f in catalog['families']:
        if not (root/'families'/f"{f['id']}.md").is_file(): errors.append(f"missing family card {f['id']}")
    for c in catalog['components']:
        if not (root/'components'/f"{c['component_id']}.md").is_file(): errors.append(f"missing component card {c['component_id']}")
    for md in root.rglob('*.md'):
        text=md.read_text(encoding='utf-8-sig')
        for target in re.findall(r'\]\(([^)]+)\)',text):
            target=target.split('#',1)[0]
            if not target or '://' in target:continue
            if not (md.parent/target).resolve().exists(): errors.append(f'broken link {md.name}: {target}')
    if repo:
        for a in catalog['template_anchors']:
            if not (repo/a['path']).is_file():errors.append(f"missing inspected anchor {a['path']}")
        entry=(repo/'ea_template/README.md').read_text(encoding='utf-8-sig')
        if 'strategy_cards/arxon/README.md' not in entry:errors.append('Template README has no card-library consumer')
    return errors

def self_tests(doc:dict) -> int:
    cases=[]
    def add(name, mutate):
        d=copy.deepcopy(doc);mutate(d);cases.append((name,d))
    for k in FALSE_TOP:add(k,lambda d,k=k:d.__setitem__(k,True))
    for k in NULL_TOP:add(k,lambda d,k=k:d.__setitem__(k,'fabricated'))
    add('missing family',lambda d:d['families'].pop())
    add('missing component',lambda d:d['components'].pop())
    add('duplicate ID',lambda d:d['components'][1].__setitem__('component_id','W01'))
    add('compiled family',lambda d:d['families'][0].__setitem__('compiled',True))
    add('trade direction',lambda d:d['components'][0].__setitem__('selected_direction','BUY'))
    add('no gaps',lambda d:d['components'][0].__setitem__('freeze_fields',[]))
    add('source missing',lambda d:d['sources'].pop())
    add('parent populated',lambda d:d['components'][0].__setitem__('selected_parent','unqualified'))
    add('clock made EA',lambda d:d['components'][17].__setitem__('target_kind','ENTRY'))
    add('cycle',lambda d:d['components'][0].__setitem__('dependencies',['W01']))
    add('broken family map',lambda d:d['families'][0].__setitem__('component_ids',[]))
    add('closed branch reopened',lambda d:d.__setitem__('protected_branch','READY'))
    if validate_catalog(doc):raise ValueError('positive catalog failed')
    for name,mutated in cases:
        if not validate_catalog(mutated):raise ValueError('negative fixture falsely passed: '+name)
    print(json.dumps({'suite':'adversarial_documentary_catalog','passed':len(cases)+1,'failed':0}))
    return len(cases)+1

def main() -> int:
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--repo-root',type=Path);p.add_argument('--self-test',action='store_true')
    a=p.parse_args();root=Path(__file__).resolve().parent
    try:
        errors=validate_files(root,a.repo_root.resolve() if a.repo_root else None)
        if errors:
            print(json.dumps({'result':'FAIL','errors':errors},indent=2));return 1
        if a.self_test:self_tests(json.loads((root/'catalog.json').read_text(encoding='utf-8-sig')))
        print(json.dumps({'result':'PASS','families':6,'components':23,'authority':'DOCUMENT_CHECK_ONLY','no_MT5':True}))
        return 0
    except (OSError,ValueError,TypeError,KeyError,RecursionError) as ex:
        print(json.dumps({'result':'FAIL','error':str(ex)}));return 2
if __name__=='__main__':sys.exit(main())
