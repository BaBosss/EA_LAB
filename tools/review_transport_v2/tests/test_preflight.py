from dataclasses import replace
import unittest

from preflight import Refusal, canonical, strict_json, validate, load_schema, sha256
from test_gate_contract import Fixture


class PreflightTests(unittest.TestCase):
    def test_rtv2_004_unreadable_nested_inventory_refuses(self):
        from unittest import mock
        import os
        from preflight import inventory
        fixture = Fixture()
        nested = fixture.evidence/'nested'
        nested.mkdir()
        (nested/'unapproved.txt').write_bytes(b'hidden')
        original = os.scandir

        def inaccessible(path):
            if os.fspath(path) == str(nested):
                raise PermissionError('deterministic nested enumeration denial')
            return original(path)

        with mock.patch('os.scandir', side_effect=inaccessible):
            with self.assertRaises((Refusal, OSError)):
                inventory(fixture.evidence)

    def test_corruption_matrix(self):
        values = [b'', b'\xff', b'\xef\xbb\xbf{}', b'{}{}', b'{"a":1,"a":2}', b'{"a":"\\u0000"}',
                  b'{"\\u0000":1}', b'{}\0', b'{"a":"\\ud800"}', b'{"a":NaN}', b'{"a":Infinity}',
                  b'[' * 21 + b'0' + b']' * 21, b'"unfinished', b'{"a":true,}', b'null']
        for raw in values:
            with self.subTest(raw=raw):
                fixture = Fixture()
                client = fixture.client()
                fixture.freeze(raw)
                receipt = fixture.launch(client)
                self.assertEqual(receipt["model_dispatch_count"], 0)
                self.assertEqual(receipt["disposition"], "ENVIRONMENT")
                self.assertIsNone(receipt["substantive_verdict"])
                self.assertEqual(client.requests, [])

    def test_state_semantics_matrix(self):
        changes = {"schema_version": 2, "transport_version": "1", "transport_id": "wrong", "contract_id": "wrong",
                   "contract_sha256": "0"*64, "implementation_manifest_sha256": "0"*64,
                   "endpoint_identity": "https://unapproved.invalid", "status": "RESET", "unknown": True}
        for key, value in changes.items():
            with self.subTest(key=key):
                fixture = Fixture()
                client = fixture.client()
                state = dict(fixture.state, **{key: value})
                fixture.freeze(canonical(state))
                receipt = fixture.launch(client)
                self.assertEqual(receipt["model_dispatch_count"], 0)
                self.assertIsNone(receipt["substantive_verdict"])

    def test_separately_frozen_hash(self):
        fixture = Fixture()
        client = fixture.client()
        fixture.state_path.write_bytes(fixture.state_path.read_bytes() + b' ')
        receipt = fixture.launch(client)
        self.assertIn('Refusal: STATE_RAW_SHA256', receipt['limitations'])
        self.assertEqual(receipt['model_dispatch_count'], 0)

    def test_capacity_and_path_matrix(self):
        for key, value in [('max_state_bytes', 8), ('max_bundle_bytes', 1), ('max_entries', 1), ('max_entry_bytes', 1)]:
            with self.subTest(key=key):
                fixture = Fixture(); client = fixture.client()
                fixture.contract['bounds'][key] = value; fixture.freeze()
                self.assertEqual(fixture.launch(client)['model_dispatch_count'], 0)
        fixture = Fixture(); client = fixture.client()
        fixture.contract['state_path'] = 'elsewhere/state.json'; fixture.freeze()
        self.assertEqual(fixture.launch(client)['model_dispatch_count'], 0)

    def test_implementation_manifest_hash_mismatch(self):
        fixture = Fixture(); client = fixture.client()
        fixture.approval = replace(fixture.approval, implementation_manifest_sha256='0'*64)
        self.assertEqual(fixture.launch(client)['model_dispatch_count'], 0)

    def test_schema_unknown_fields_and_types(self):
        fixture = Fixture()
        for mutation in [dict(fixture.contract, extra=True), dict(fixture.contract, run_id=1)]:
            with self.assertRaises(Refusal):
                validate(mutation, load_schema('contract'))
        with self.assertRaises(Refusal):
            validate({}, {'$ref':'https://untrusted.invalid/schema'})
        self.assertEqual(strict_json(b'{"x":"[not nesting]"}', depth=1), {'x':'[not nesting]'})

    def test_pinned_launcher_schema_dependency_and_dispatcher_hashes(self):
        for category, path in [('implementation','launch.py'),('implementation','broker.py'),
                               ('implementation','schemas/transport_state.schema.json'),
                               ('dependencies','python312.zip')]:
            with self.subTest(path=path):
                fixture = Fixture(); client = fixture.client()
                manifest = strict_json(fixture.impl_manifest)
                spec = next(e for e in manifest[category]['files'] if e['path'] == path)
                spec['sha256'] = '0'*64
                fixture.impl_manifest = canonical(manifest)
                fixture.contract['implementation_manifest_sha256'] = sha256(fixture.impl_manifest)
                fixture.freeze()
                receipt = fixture.launch(client)
                self.assertEqual(receipt['model_dispatch_count'], 0)
                self.assertIn('Refusal: IMPLEMENTATION_BYTES',receipt['limitations'])
