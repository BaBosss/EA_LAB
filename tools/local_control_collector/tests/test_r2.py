"""Regression witnesses for owner-authorized R2, preserving Repair1 failure."""
import json
import sqlite3
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from test_collector import collector, make_v3_codex_home, AS_OF, digest

class R2Tests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
    def tearDown(self):
        self.tmp.cleanup()

    def test_all_malformed_registry_is_unavailable(self):
        root = self.root / 'registry'
        root.mkdir()
        (root / 'broken.json').write_text('{bad', encoding='utf-8')
        (root / 'wrong.json').write_text('{}', encoding='utf-8')
        result = collector.collect_registry(self.root, root, False)
        self.assertEqual(result['status'], 'UNAVAILABLE')
        self.assertEqual(result['malformed_count'], 2)
        self.assertEqual(result['records'], [])
        self.assertEqual(result['total_count'], 0)
        self.assertEqual(result['selected_count'] + result['omitted_count'], 0)
    def test_titles_absent_from_route_and_full_durable_observation(self):
        home = make_v3_codex_home(self.root)
        with sqlite3.connect(home / 'state_5.sqlite') as db:
            db.execute('UPDATE threads SET title=?', ('SENTINEL_OWNER_TEXT',))
        db.close()
        before = {p.name: digest(p) for p in home.glob('*.sqlite')}
        usage = collector.collect_codex_usage([home], AS_OF, {}, None)
        self.assertEqual(usage['status'], 'AVAILABLE')
        for row in usage['threads']:
            self.assertEqual(row['label'], 'THREAD:' + row['thread_id'][:12])
        packet = collector.empty_packet(AS_OF)
        packet['codex_usage'] = usage
        out = self.root / 'durable'
        collector.write_outputs(out, self.root / 'repo', packet)
        durable = next(out.glob('observation-*.json')).read_text(encoding='utf-8')
        self.assertNotIn('SENTINEL_OWNER_TEXT', durable)
        self.assertNotIn('SENTINEL_OWNER_TEXT', json.dumps(collector.compact_usage(usage)))
        self.assertEqual(len(json.loads(durable)['codex_usage']['threads']), 2)
        self.assertEqual(before, {p.name: digest(p) for p in home.glob('*.sqlite')})

    def test_reader_never_selects_title_or_prompt_columns(self):
        home = make_v3_codex_home(self.root)
        original = collector.readonly_connection
        def protected(path):
            connection = original(path)
            connection.set_authorizer(lambda action, a, b, *_: sqlite3.SQLITE_DENY
                if action == sqlite3.SQLITE_READ and b in {'title', 'initial_prompt', 'first_user_message', 'preview'} else sqlite3.SQLITE_OK)
            return connection
        with patch.object(collector, 'readonly_connection', protected):
            self.assertEqual(collector.collect_codex_usage([home], AS_OF, {}, None)['status'], 'AVAILABLE')

    def test_snapshot_round_trip_and_two_observation_delta(self):
        out = self.root / 'ledger'
        packet = collector.empty_packet(AS_OF)
        packet['codex_usage']['threads'] = [{'thread_id': 'one', 'current_lifetime_tokens': 100}]
        collector.write_outputs(out, self.root / 'repo', packet)
        prior = collector.read_prior_snapshot(out)
        self.assertEqual(prior, {'one': 100})
        self.assertEqual(len((out / 'snapshots.jsonl').read_text().splitlines()), 1)
        home = make_v3_codex_home(self.root)
        before = {'parent-1': 80, 'child-1': 20}
        packet['observed_at'] = '2026-09-21T12:00:01Z'
        packet['codex_usage']['threads'] = [{'thread_id': k, 'current_lifetime_tokens': v} for k, v in before.items()]
        collector.write_outputs(out, self.root / 'repo', packet)
        rows = collector.collect_codex_usage([home], AS_OF, {}, collector.read_prior_snapshot(out))['threads']
        self.assertEqual({r['thread_id']:r['delta_tokens'] for r in rows}, {'parent-1':20, 'child-1':5})

    def test_legacy_pretty_snapshot_is_consumed_without_rewriting(self):
        out = self.root / 'legacy'; out.mkdir()
        item = {'schema_version':collector.SNAPSHOT_SCHEMA_VERSION, 'observed_at':AS_OF, 'counters':{'a':5}}
        path = out / 'snapshots.jsonl'; path.write_bytes(collector.canonical_bytes(item))
        original = path.read_bytes()
        self.assertEqual(collector.read_prior_snapshot(out), {'a':5})
        self.assertEqual(path.read_bytes(), original)
        path.write_bytes(original + b'{bad')
        with self.assertRaises(collector.Refusal): collector.read_prior_snapshot(out)
