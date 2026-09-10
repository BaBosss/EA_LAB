#!/usr/bin/env python3
import hashlib, json, xml.etree.ElementTree as ET
from pathlib import Path
RUN=Path(__file__).resolve().parent
cmp=json.loads((RUN/'comparison.json').read_text())
mech=json.loads((RUN/'mechanical_acceptance.json').read_text())
recon=json.loads((RUN/'source_graph_reconciliation.json').read_text())
assert mech['state']=='PASS'
assert cmp['mechanical_state']=='PASS'
assert cmp['classification']=='HYPOTHESIS_NOT_FALSIFIED / DUAL_WINDOW_SIGN_SURVIVES_WIDER_EARLY_ZONE'
assert cmp['pareto_nonworse'] is False
assert mech['sole_executed_input_change']=={'_16_AtrMultFirst4':[0.8,1.4]}
assert recon['files_compared']==35 and recon['changed_count']==0 and recon['missing_count']==0
for arm in ('PARENT','CHILD'):
    for win in ('MAIN','BWD'):
        d=RUN/'runtime'/arm/win
        assert (d/'report.htm').is_file() and (d/'tester.ini').is_file()
        lev=json.loads((d/'leverage_check.json').read_text(encoding='utf-8-sig'))
        trunc=json.loads((d/'truncation_check.json').read_text(encoding='utf-8-sig'))
        assert lev['status']=='MATCH' and lev['actual_leverage']==100
        assert trunc['checker_exit_code']==0
for p in (RUN/'visuals').glob('*.svg'):
    ET.parse(p)
assert len(list((RUN/'visuals').glob('*.svg')))==5
manifest=(RUN/'artifacts.sha256').read_text().splitlines()
assert len(manifest)>=25
for line in manifest:
    h,rel=line.split('  ',1); p=RUN/rel
    assert p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest()==h
report=(RUN/'R2_MECHANISM_REPORT.md').read_text(encoding='utf-8')
for token in ('MECHANISM_VALUE = WEAK','HOLDOUT UNSPENT','D:\\Meta 5c','do not retune from BWD','VISUAL_ONLY_NO_AUTHORITY'):
    assert token in report
print(f'QA_PASS manifest={len(manifest)} visuals=5 cells=4 source_graph=35/35')
