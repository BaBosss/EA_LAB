import os
from pathlib import Path
import unittest
import zlib

from preflight import Refusal, Pins, identity, relative_path
from test_gate_contract import Fixture


class SnapshotTests(unittest.TestCase):
    def test_path_escape_matrix(self):
        for path in ('../secret', '/absolute', 'a/../../secret', 'C:/private', '//server/share',
                     '\\\\?\\C:\\private', 'a.txt:stream', 'a\\..\\b', './a', 'a//b',
                     'a./b', 'a /b', 'NUL.txt', 'COM1', 'a\0b', 'a?b'):
            with self.subTest(path=path), self.assertRaises(Refusal):
                relative_path(path)

    def test_wrong_head_matrix(self):
        for value in ('0'*40, 'f'*40, '0'*64, 'HEAD', True):
            with self.subTest(value=value):
                fixture = Fixture(); client = fixture.client()
                fixture.contract['requested_head'] = value; fixture.freeze()
                receipt = fixture.launch(client)
                self.assertEqual(receipt['model_dispatch_count'], 0)
                self.assertIsNone(receipt['substantive_verdict'])

    def test_actual_head_changed(self):
        fixture = Fixture(); client = fixture.client()
        (fixture.repo / '.git/refs/heads/main').write_text('f'*40+'\n')
        self.assertEqual(fixture.launch(client)['model_dispatch_count'], 0)

    def test_source_and_evidence_corruption(self):
        for which in ('source', 'evidence'):
            with self.subTest(which=which):
                fixture = Fixture(); client = fixture.client()
                path = fixture.repo/'a.py' if which == 'source' else fixture.evidence/'result.txt'
                path.write_bytes(b'wrong bytes')
                self.assertEqual(fixture.launch(client)['model_dispatch_count'], 0)

    def test_root_substitution(self):
        fixture = Fixture(); client = fixture.client()
        fixture.contract['source_root_identity']['inode'] += 1; fixture.freeze()
        self.assertEqual(fixture.launch(client)['model_dispatch_count'], 0)

    def test_inventory_extra_missing_duplicate_case(self):
        for mode in ('extra', 'missing', 'duplicate', 'case'):
            with self.subTest(mode=mode):
                fixture = Fixture(); client = fixture.client()
                if mode == 'extra': (fixture.evidence/'extra.txt').write_bytes(b'extra')
                elif mode == 'missing': fixture.contract['evidence_entries'] = []
                else:
                    entry = dict(fixture.contract['source_entries'][0])
                    entry['id'] = 's_02'
                    if mode == 'case': entry['path'] = 'A.py'
                    fixture.contract['source_entries'].append(entry)
                fixture.freeze()
                self.assertEqual(fixture.launch(client)['model_dispatch_count'], 0)

    def test_git_object_identity_matrix(self):
        for field, value in [('oid','f'*40), ('type','tree'), ('size', 999), ('sha256','0'*64)]:
            with self.subTest(field=field):
                fixture = Fixture(); client = fixture.client()
                fixture.contract['git_objects'][0][field] = value; fixture.freeze()
                self.assertEqual(fixture.launch(client)['model_dispatch_count'], 0)

    def test_git_external_and_lazy_stores_matrix(self):
        for relative in ('objects/info/alternates', 'objects/info/http-alternates', 'commondir',
                         'shallow', 'refs/replace/abc', 'objects/pack/a.promisor', 'objects/pack/a.pack'):
            with self.subTest(relative=relative):
                fixture = Fixture(); client = fixture.client()
                path = fixture.repo / '.git' / relative
                path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(b'unapproved')
                self.assertEqual(fixture.launch(client)['model_dispatch_count'], 0)
        for line in ('[remote "origin"]\n promisor = true\n', '[include]\n path = elsewhere\n'):
            fixture = Fixture(); client = fixture.client()
            with (fixture.repo/'.git/config').open('a') as file: file.write(line)
            self.assertEqual(fixture.launch(client)['model_dispatch_count'], 0)

    def test_missing_object_no_expansion(self):
        fixture = Fixture(); client = fixture.client()
        fixture.contract['git_objects'] = fixture.contract['git_objects'][1:]; fixture.freeze()
        self.assertEqual(fixture.launch(client)['model_dispatch_count'], 0)

    def test_hardlink_escape_rejected(self):
        fixture = Fixture(); client = fixture.client()
        os.link(fixture.repo/'a.py', fixture.root/'outside-link')
        self.assertEqual(fixture.launch(client)['model_dispatch_count'], 0)

    def test_symlink_and_junction_escape_rejected(self):
        # Windows symlink privilege is not presumed. A junction is created with
        # the documented reparse FSCTL by the fixture only, not product code.
        import ctypes
        from ctypes import wintypes
        import struct
        fixture = Fixture(); client = fixture.client()
        junction = fixture.repo/'escape'; junction.mkdir()
        substitute = ('\\??\\' + str(fixture.evidence)).encode('utf-16-le')
        printable = str(fixture.evidence).encode('utf-16-le')
        names = substitute + b'\0\0' + printable + b'\0\0'
        body = struct.pack('<HHHH', 0, len(substitute), len(substitute)+2, len(printable)) + names
        payload = struct.pack('<IHH', 0xA0000003, len(body), 0) + body
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.CreateFileW.argtypes = [wintypes.LPCWSTR,wintypes.DWORD,wintypes.DWORD,wintypes.LPVOID,wintypes.DWORD,wintypes.DWORD,wintypes.HANDLE]
        kernel.CreateFileW.restype = wintypes.HANDLE
        handle = kernel.CreateFileW(str(junction), 0x40000000, 0, None, 3, 0x02200000, None)
        self.assertNotEqual(handle, wintypes.HANDLE(-1).value)
        kernel.DeviceIoControl.argtypes = [wintypes.HANDLE,wintypes.DWORD,wintypes.LPVOID,wintypes.DWORD,wintypes.LPVOID,wintypes.DWORD,ctypes.POINTER(wintypes.DWORD),wintypes.LPVOID]
        returned = wintypes.DWORD()
        buffer = ctypes.create_string_buffer(payload)
        success = kernel.DeviceIoControl(handle, 0x900A4, buffer, len(payload), None, 0, ctypes.byref(returned), None)
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]; kernel.CloseHandle(handle)
        self.assertTrue(success, ctypes.get_last_error())
        self.assertEqual(fixture.launch(client)['model_dispatch_count'], 0)

    def test_pins_prevent_file_write_and_root_rename(self):
        fixture = Fixture()
        with Pins() as pins:
            root = pins.root(str(fixture.repo), identity(fixture.repo))
            pins.read(root, 'a.py', 1000)
            with self.assertRaises(OSError): (root/'a.py').write_bytes(b'changed')
            with self.assertRaises(OSError): root.rename(fixture.root/'renamed')

    def test_sha256_git_store(self):
        fixture = Fixture('sha256')
        receipt = fixture.launch()
        self.assertEqual(receipt['disposition'], 'DETERMINISTIC_TEST_ONLY', receipt['limitations'])

    def test_memory_seal_survives_later_host_change(self):
        fixture = Fixture(); snapshot = fixture.snapshot()
        (fixture.repo/'a.py').write_bytes(b'changed after export')
        self.assertEqual(snapshot.entries['s_01'], fixture.data)
        with self.assertRaises(TypeError): snapshot.entries['s_01'] = b'evil'

    def test_git_entry_capacity(self):
        fixture = Fixture(); client = fixture.client()
        # The source and evidence fit, but the commit object does not.
        fixture.contract['bounds']['max_entry_bytes'] = 80; fixture.freeze()
        receipt = fixture.launch(client)
        self.assertEqual(receipt['model_dispatch_count'],0)
        self.assertTrue(any('GIT_OBJECT_CAPACITY' in reason or 'GIT_DECOMPRESSION_BOUND' in reason
                            for reason in receipt['limitations']),receipt['limitations'])
