import json, unittest
from unittest.mock import patch
from pathlib import Path
import test_reader
from reader import ReaderError, query_packet, make_document, load_drafts, load_verified_index
from types import SimpleNamespace
class ScrutinyRepairTests(unittest.TestCase):
 def setUp(self): self.fixture=test_reader.ReaderTests();self.fixture.setUp()
 def tearDown(self): self.fixture.tearDown()
 def test_SBR001_plain_forged_index_refused(self):
  forged=json.loads(json.dumps(self.fixture.build()));forged['authority']='FORGED';forged['documents'][0]['path']='C:/browser/profile/token.txt';forged['documents'][0]['body']='RAW_PRIVATE_COMMENT'
  with self.assertRaises(ReaderError):query_packet(forged,'EA',{})
 def test_SBR001_mutated_verified_object_refused(self):
  idx=self.fixture.build();idx['documents'][0]['body']='RAW_PRIVATE_COMMENT'
  with self.assertRaises(ReaderError):query_packet(idx,'EA',{})
 def test_SBR002_primary_source_not_filename(self):
  text='---\ncard_id: RC-X\nsource_id: SRC-JB-TV-DEMON-BEAM-V23\n---\n# Example\n[Source](SRC-JB-TV-DEMON-BEAM-V23_NOTE.md)\nRelated text SRC-OTHER\n'
  d=make_document('knowledge/02_research_cards/RC-X.md',text.encode(),{},'DRAFT_NOT_IMPORTED')
  self.assertEqual(d['source_ids'],['SRC-JB-TV-DEMON-BEAM-V23'])
 def test_SBR004_original_packet_root_checked(self):
  root,digest=self.fixture.packet();original=Path.is_symlink
  with patch.object(Path,'is_symlink',lambda p: p==root or original(p)):
   with self.assertRaisesRegex(ReaderError,'symlink|junction'):load_drafts(root,digest,{})
 def test_SBR005_empty_question_refused(self):
  for q in ['', '  ', '\n']:
   with self.assertRaises(ReaderError):query_packet(self.fixture.build(),q,{})
 def test_SBR001_rebuild_accepts_original_and_refuses_same_pin_forgery(self):
  f=self.fixture;idx=f.build();p=f.repo.parent/'index.json';p.write_text(json.dumps(idx),encoding='utf8')
  args=SimpleNamespace(index=p,repo=f.repo,ref=f.sha,expected_sha=f.sha,prepared_packet=None,prepared_manifest_sha256=None)
  good=load_verified_index(args);self.assertEqual(good['canonical']['sha'],f.sha)
  idx['documents'][0]['body']='RAW_PRIVATE_COMMENT';p.write_text(json.dumps(idx),encoding='utf8')
  with self.assertRaisesRegex(ReaderError,'provenance differs'):load_verified_index(args)
 def test_SBR004_original_packet_parent_checked(self):
  root,digest=self.fixture.packet();original=Path.is_symlink
  with patch.object(Path,'is_symlink',lambda p: p==root.parent or original(p)):
   with self.assertRaisesRegex(ReaderError,'symlink|junction'):load_drafts(root,digest,{})
if __name__=='__main__':unittest.main()
