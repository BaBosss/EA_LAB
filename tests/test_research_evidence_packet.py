import hashlib
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from tools.research_evidence_packet import packet as p

SAMPLES = {
 'B17_H0': {'closeout': ('b17.md', '# B17 summary\nHistorical MAIN: Hard Kill at 25.58% on 2023-03-10.\n')},
 'B17_B6230': {'result': ('w5.json', {'schema':'W5_B6230_TEST_RESULT_V1','cell':'MAIN_OFF','runner_exit':0,'data_unchanged':False}), 'drift':('drift.json',{'schema':'W5_B6230_DATA_SHA_POSTTEST_V2_AUDIT','drift_count':3,'checked_count':106})},
 'B16_H08': {'validation':('b16.json',{'schema':'ea-lab-b16-h08-validation-evidence/1','selected_center':{'_16_RsiPeriod':14,'_16_RsiLow':35.0},'cells':[{'window':'MAIN','pf':1.68},{'window':'BWD','pf':0.66}],'classification':'FIXED_VALIDATION_FAIL'})},
 'BOSS19_R02': {'result':('r02.json',{'schema_version':'BOSS19_P4B_UNIT_EXPORT_REPAIR02_RESULT_V1','status':'BLOCKED(MAGIC_FIELD_NOT_SOURCE_BOUND)','evidence_contract_gate':{'status':'BLOCKED','code':'MAGIC_FIELD_NOT_SOURCE_BOUND'}})},
 'BOSS19_R03': {'result':('r03.json',{'schema_version':'BOSS19_P4B_UNIT_EXPORT_REPAIR03_RESULT_V1','status':'PASS','source_magic_gate':{'status':'PASS','source_magic_provenance':'PER_DEAL_HISTORY_DEAL_MAGIC'},'independent_review':{'verdict':'PASS'}})},
}

def prepare(root, keys=None):
 cases=[]
 for kind in keys or SAMPLES:
  recs=[]
  for role,(name,value) in SAMPLES[kind].items():
   data=value.encode('utf-8') if isinstance(value,str) else (json.dumps(value,sort_keys=True)+'\n').encode('utf-8')
   (root/name).write_bytes(data)
   recs.append({'role':role,'path':name,'sha256':hashlib.sha256(data).hexdigest()})
  cases.append({'case_id':kind,'kind':kind,'records':recs})
 return {'schema':p.SCHEMA,'cases':cases}

class PacketTests(unittest.TestCase):
 def setUp(self):
  self.t=tempfile.TemporaryDirectory()
  self.addCleanup(self.t.cleanup)
  self.root=Path(self.t.name)
  self.m=prepare(self.root)
 def result(self):return p.packet(self.root,self.m)
 def test_five_historical_shapes(self):
  statuses=[x['status'] for x in self.result()['cases']]
  self.assertEqual(statuses,['REJECT_HISTORICAL_NEGATIVE','REFUSE_MECHANICAL_PROVENANCE','REJECT_HISTORICAL_NEGATIVE','REFUSE_MECHANICAL_PROVENANCE','RESEARCH_REFERENCE_ONLY'])
 def test_all_denials_including_repaired_case(self):
  v=self.result()
  self.assertEqual(v['candidate_promotions'],0)
  for r in v['cases']:
   for k in p.DENIALS: self.assertIs(r[k],False)
   self.assertIs(r['native_authenticated'],False)
   self.assertIs(r['owner_authenticated'],False)
 def test_case_tamper_fails_closed(self):
  (self.root/'b16.json').write_text('{"tampered":true}')
  r=self.result()['cases'][2]
  self.assertEqual(r['status'],'UNKNOWN_INCOMPLETE')
  self.assertIn('RECEIPT_HASH_MISMATCH',r['reasons'])
 def test_missing_file_fails_closed(self):
  (self.root/'drift.json').unlink()
  r=self.result()['cases'][1]
  self.assertIn('RECEIPT_MISSING',r['reasons'])
 def test_wrong_hash_pin(self):
  self.m['cases'][4]['records'][0]['sha256']='f'*64
  self.assertIn('RECEIPT_HASH_MISMATCH',self.result()['cases'][4]['reasons'])
 def test_traversal_refused(self):
  self.m['cases'][2]['records'][0]['path']='../outside.json'
  self.assertIn('PATH_TRAVERSAL_OR_AMBIGUOUS',self.result()['cases'][2]['reasons'])
 def test_absolute_refused(self):
  self.m['cases'][2]['records'][0]['path']='/tmp/a.json'
  self.assertIn('ABSOLUTE_PATH_FORBIDDEN',self.result()['cases'][2]['reasons'])
 def test_windows_absolute_refused(self):
  self.m['cases'][2]['records'][0]['path']='C:/tmp/a.json'
  self.assertIn('ABSOLUTE_PATH_FORBIDDEN',self.result()['cases'][2]['reasons'])
 def test_backslash_refused(self):
  self.m['cases'][2]['records'][0]['path']='x\\y.json'
  self.assertIn('INVALID_RELATIVE_PATH',self.result()['cases'][2]['reasons'])
 def test_unknown_kind_fails_closed(self):
  self.m['cases'][0]['kind']='ARBITRARY'
  self.assertIn('CASE_KIND_UNSUPPORTED',self.result()['cases'][0]['reasons'])
 def test_duplicate_case_ids_refuses_entire_manifest(self):
  self.m['cases'][1]['case_id']=self.m['cases'][0]['case_id']
  with self.assertRaises(p.InputRefused):self.result()
 def test_duplicate_record_role(self):
  self.m['cases'][1]['records'][1]['role']='result'
  self.assertIn('RECORD_ROLE_INVALID_OR_DUPLICATE',self.result()['cases'][1]['reasons'])
 def test_no_native_pass_from_w5_clean_claim(self):
  (self.root/'w5.json').write_text(json.dumps({'schema':'W5_B6230_TEST_RESULT_V1','cell':'MAIN_OFF','data_unchanged':True}),encoding='utf-8')
  (self.root/'drift.json').write_text(json.dumps({'schema':'W5_B6230_DATA_SHA_POSTTEST_V2_AUDIT','drift_count':0,'checked_count':106}),encoding='utf-8')
  for i in (0,1):
   d=self.m['cases'][1]['records'][i]
   d['sha256']=hashlib.sha256((self.root/d['path']).read_bytes()).hexdigest()
  self.assertEqual(self.result()['cases'][1]['status'],'UNKNOWN_INCOMPLETE')
 def test_repair03_unreviewed_fails_closed(self):
  x=json.loads((self.root/'r03.json').read_text())
  x['independent_review']={'verdict':'NOT_DISPATCHED'}
  (self.root/'r03.json').write_text(json.dumps(x))
  self.m['cases'][4]['records'][0]['sha256']=hashlib.sha256((self.root/'r03.json').read_bytes()).hexdigest()
  self.assertEqual(self.result()['cases'][4]['status'],'UNKNOWN_INCOMPLETE')
 def test_b16_wrong_center_fails_closed(self):
  x=json.loads((self.root/'b16.json').read_text());x['selected_center']['_16_RsiLow']=30
  (self.root/'b16.json').write_text(json.dumps(x))
  self.m['cases'][2]['records'][0]['sha256']=hashlib.sha256((self.root/'b16.json').read_bytes()).hexdigest()
  self.assertIn('B16_IDENTITY_MISMATCH',self.result()['cases'][2]['reasons'])
 def test_duplicate_json_keys_refused(self):
  content=b'{"schema":"foo","schema":"bar"}'
  (self.root/'r02.json').write_bytes(content)
  self.m['cases'][3]['records'][0]['sha256']=hashlib.sha256(content).hexdigest()
  self.assertIn('DUPLICATE_JSON_KEY',self.result()['cases'][3]['reasons'])
 def test_invalid_sha_refused(self):
  self.m['cases'][0]['records'][0]['sha256']='not a hash'
  self.assertIn('PIN_SHA256_INVALID',self.result()['cases'][0]['reasons'])
 def test_nonfinite_json_refused(self):
  data=b'{"value":NaN}'
  (self.root/'r02.json').write_bytes(data)
  self.m['cases'][3]['records'][0]['sha256']=hashlib.sha256(data).hexdigest()
  self.assertIn('NONFINITE_JSON',self.result()['cases'][3]['reasons'])
 def test_invalid_manifest_refused(self):
  self.m['schema']='OTHER'
  with self.assertRaises(p.InputRefused):self.result()
 def test_markdown_does_not_accept_missing_hard_kill(self):
  data=b'B17 positive results'
  (self.root/'b17.md').write_bytes(data)
  self.m['cases'][0]['records'][0]['sha256']=hashlib.sha256(data).hexdigest()
  self.assertIn('B17_HISTORICAL_MARKERS_MISSING',self.result()['cases'][0]['reasons'])
 def test_unsupported_suffix(self):
  (self.root/'foo.exe').write_bytes((self.root/'b17.md').read_bytes())
  self.m['cases'][0]['records'][0]['path']='foo.exe'
  self.assertIn('UNSUPPORTED_RECEIPT_FORMAT',self.result()['cases'][0]['reasons'])
 def test_many_cases_refused(self):
  self.m['cases']=self.m['cases']*5
  with self.assertRaises(p.InputRefused):self.result()
 def test_symlink_refusal(self):
  if not hasattr(os,'symlink'):self.skipTest('symlink unavailable')
  (self.root/'r03.json').rename(self.root/'real.json')
  try:os.symlink('real.json',str(self.root/'r03.json'))
  except (OSError,NotImplementedError):self.skipTest('symlink permission unavailable')
  self.assertIn('SYMLINK_FORBIDDEN',self.result()['cases'][4]['reasons'])
 def test_cli_no_overwrite_and_no_input_mutation(self):
  import subprocess
  before={x.name:hashlib.sha256(x.read_bytes()).hexdigest() for x in self.root.iterdir() if x.is_file()}
  manifest=self.root/'manifest.json';manifest.write_text(json.dumps(self.m))
  out=self.root.parent/('packet_test_out_'+self.root.name)
  try:
   cli=Path(p.__file__)
   result=subprocess.run([sys.executable,str(cli),'--root',str(self.root),'--manifest',str(manifest),'--out-dir',str(out)],capture_output=True,text=True)
   self.assertEqual(result.returncode,0,result.stderr)
   self.assertTrue((out/'RESEARCH_DECISION_PACKET.json').exists())
   again=subprocess.run([sys.executable,str(cli),'--root',str(self.root),'--manifest',str(manifest),'--out-dir',str(out)],capture_output=True,text=True)
   self.assertNotEqual(again.returncode,0)
   for name,sha in before.items():self.assertEqual(hashlib.sha256((self.root/name).read_bytes()).hexdigest(),sha)
  finally:
   import shutil
   shutil.rmtree(out,ignore_errors=True)
 def test_output_inside_input_refused(self):
  import subprocess
  manifest=self.root/'manifest.json';manifest.write_text(json.dumps(self.m))
  t=subprocess.run([sys.executable,str(Path(p.__file__)),'--root',str(self.root),'--manifest',str(manifest),'--out-dir',str(self.root/'results')],capture_output=True,text=True)
  self.assertNotEqual(t.returncode,0)
  self.assertFalse((self.root/'results').exists())
if __name__=='__main__':unittest.main()
