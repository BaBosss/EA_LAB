from dataclasses import replace
from pathlib import Path
import unittest
from unittest import mock

import receipt as receipt_module
from model_client import FakeModelClient
from preflight import Refusal

from launch import run
from preflight import canonical, identity, load_schema, sha256, strict_json, validate
from test_gate_contract import Fixture


class ReceiptTests(unittest.TestCase):
    def test_rtv2_001_created_artifact_replacement_refuses_completion(self):
        for target in ('manifest.json', 's_01.bin', 'read_log.json',
                       'model_output_0000.bin', 'validated_result.json'):
            with self.subTest(target=target):
                fixture = Fixture()
                original = receipt_module.write_once
                attacked = []

                def replace_created(path, raw):
                    created = original(path, raw)
                    if path.name == target:
                        # Same bytes, different file: hash-only checking is insufficient.
                        path.rename(fixture.root / (path.name + '.displaced'))
                        path.write_bytes(raw)
                        attacked.append(path)
                    return created

                with mock.patch('receipt.write_once', side_effect=replace_created), \
                     mock.patch('launch.write_once', side_effect=replace_created, create=True):
                    with self.assertRaises((Refusal, OSError)):
                        fixture.launch()
                self.assertTrue(attacked)
                self.assertFalse((fixture.control/'evidence/review-transport-v2-r1/receipt.json').exists())

    def test_rtv2_001_persisted_byte_corruption_refuses_completion(self):
        fixture = Fixture()
        original = receipt_module.write_once

        def corrupt_created(path, raw):
            created = original(path, raw)
            if path.name == 'read_log.json':
                path.write_bytes(b'[]')
            return created

        with mock.patch('receipt.write_once', side_effect=corrupt_created):
            with self.assertRaises((Refusal, OSError)):
                fixture.launch()
        self.assertFalse((fixture.control/'evidence/review-transport-v2-r1/receipt.json').exists())

    def test_rtv2_001_extra_inventory_refuses_completion(self):
        for where in ('bundle', 'run'):
            for kind in ('file', 'directory'):
                with self.subTest(where=where, kind=kind):
                    fixture = Fixture()
                    original = receipt_module.write_once

                    def add_extra(path, raw):
                        created = original(path, raw)
                        target = 'manifest.json' if where == 'bundle' else 'validated_result.json'
                        if path.name == target:
                            extra = path.parent/'unexpected'
                            extra.mkdir() if kind == 'directory' else extra.write_bytes(b'extra')
                        return created

                    with mock.patch('receipt.write_once', side_effect=add_extra), \
                         mock.patch('launch.write_once', side_effect=add_extra, create=True):
                        with self.assertRaises((Refusal, OSError)):
                            fixture.launch()
                    self.assertFalse((fixture.control/'evidence/review-transport-v2-r1/receipt.json').exists())

    def test_rtv2_002_invalid_utf8_has_distinct_binary_binding(self):
        receipts = []
        for raw in (b'\xff', b'\xfe'):
            fixture = Fixture()
            receipt = fixture.launch(FakeModelClient([raw]))
            self.assertIsNone(receipt['substantive_verdict'])
            receipts.append(receipt)
        self.assertNotEqual(receipts[0]['raw_model_output_sha256'],
                            receipts[1]['raw_model_output_sha256'])

    def test_rtv2_002_every_binary_has_ordered_size_and_hash(self):
        fixture = Fixture(); client = fixture.client()
        receipt = fixture.launch(client)
        expected = [{'path': 'model_output_%04d.bin' % i, 'size': len(raw),
                     'sha256': sha256(raw)} for i, raw in enumerate(client.responses)]
        self.assertEqual(receipt.get('raw_model_outputs'), expected)
        root = fixture.control/'evidence/review-transport-v2-r1'
        for entry in expected:
            raw = (root/entry['path']).read_bytes()
            self.assertEqual((len(raw), sha256(raw)), (entry['size'], entry['sha256']))
        self.assertEqual(strict_json((root/'raw_model_outputs.json').read_bytes()), expected)

    def test_rtv2_001_files_remain_locked_during_completion(self):
        from concurrent.futures import ThreadPoolExecutor
        fixture = Fixture()
        original = receipt_module.write_once
        blocked = []

        def attack(path, operation):
            try:
                if operation == 'write': path.write_bytes(b'corrupt')
                else: path.rename(fixture.root / (path.name + '.stolen'))
            except OSError:
                return True
            return False

        def during_completion(path, raw):
            if path.name == 'receipt.json':
                bundle_root = fixture.control/'review_transport_v2/bundles'
                targets = list(next(bundle_root.iterdir()).iterdir()) + list(path.parent.iterdir())
                with ThreadPoolExecutor(max_workers=1) as worker:
                    for target in targets:
                        for operation in ('write', 'rename'):
                            blocked.append(worker.submit(attack, target, operation).result())
            return original(path, raw)

        with mock.patch('receipt.write_once', side_effect=during_completion):
            receipt = fixture.launch()
        self.assertEqual(receipt['disposition'], 'DETERMINISTIC_TEST_ONLY', receipt['limitations'])
        self.assertEqual(len(blocked), 22)  # Six bundle files plus five run artifacts.
        self.assertTrue(all(blocked))

    def test_rtv2_001_late_bundle_inventory_change_refuses_completion(self):
        fixture = Fixture()
        original = receipt_module.write_once

        def late_extra(path, raw):
            created = original(path, raw)
            if path.name == 'validated_result.json':
                root = fixture.control/'review_transport_v2/bundles'
                (next(root.iterdir())/'late-extra').write_bytes(b'extra')
            return created

        with mock.patch('receipt.write_once', side_effect=late_extra):
            with self.assertRaisesRegex(Refusal, 'ARTIFACT_INVENTORY'):
                fixture.launch()
        self.assertFalse((fixture.control/'evidence/review-transport-v2-r1/receipt.json').exists())

    def test_persisted_artifact_hashes(self):
        fixture=Fixture(); receipt=fixture.launch()
        self.assertEqual(receipt['disposition'],'DETERMINISTIC_TEST_ONLY',receipt['limitations'])
        root=fixture.control/'evidence/review-transport-v2-r1'
        self.assertEqual(strict_json((root/'receipt.json').read_bytes()),receipt)
        for key,name in [('read_log_sha256','read_log.json'),('raw_model_output_sha256','raw_model_outputs.json'),
                         ('validated_result_sha256','validated_result.json')]:
            self.assertEqual(receipt[key],sha256((root/name).read_bytes()))
        self.assertEqual(receipt['provider_request_ids'],['fake-1','fake-2'])
        self.assertTrue(all(g['status']=='NOT_QUALIFIED' for g in receipt['gate_results']))

    def test_create_once_no_overwrite(self):
        fixture=Fixture(); fixture.launch()
        path=fixture.control/'evidence/review-transport-v2-r1/receipt.json'
        before=path.read_bytes(); client=fixture.client()
        with self.assertRaises(FileExistsError): fixture.launch(client)
        self.assertEqual(path.read_bytes(),before)
        self.assertEqual(client.requests,[])

    def test_deterministic_repeatability(self):
        fixture=Fixture(); first=fixture.launch()
        control=fixture.root/'repeat-control'
        for rel in ('review_transport_v2/contracts/c1','review_transport_v2/state/t1','review_transport_v2/bundles','evidence'):
            (control/rel).mkdir(parents=True,exist_ok=True)
        for rel in ('review_transport_v2/contracts/c1/contract.json','review_transport_v2/state/t1/state.json'):
            (control/rel).write_bytes((fixture.control/rel).read_bytes())
        approval=replace(fixture.approval,control_root=str(control),control_identity=identity(control))
        second=run(approval,fixture.client())
        self.assertEqual(canonical(first),canonical(second))
        self.assertEqual(first['disposition'],'DETERMINISTIC_TEST_ONLY',first['limitations'])

    def test_all_schemas_and_roundtrips(self):
        fixture=Fixture()
        for name, value in [('contract',fixture.contract),('transport_state',fixture.state),
                            ('bundle',strict_json(fixture.snapshot().manifest_bytes)),
                            ('review_result',fixture.result()),('receipt',fixture.launch())]:
            with self.subTest(schema=name):
                schema=load_schema(name)
                self.assertEqual(schema['$schema'],'https://json-schema.org/draft/2020-12/schema')
                validate(value,schema)
                self.assertEqual(strict_json(canonical(value)),value)
