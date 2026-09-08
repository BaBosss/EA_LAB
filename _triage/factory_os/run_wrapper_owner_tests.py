# -*- coding: utf-8 -*-
"""Adversarial cage for the declarative wrapper-owner manifest.

Every negative case mutates one accepted fixture fact and drives the public ``load`` seam.  The
P4B sibling is deliberately present in every control fixture: it defines LAB_ENTRY_19 but is not
an owner, so a resolver that scans root wrappers instead of reading the manifest fails the clean
control before any attack is considered meaningful.
"""
import os
import sys


HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import capability  # noqa: E402  -- used only for the dynamic-rebinding attack
import gen_locked_constants as locked  # noqa: E402
import wrapper_owners as owners  # noqa: E402


INPUTS = (
    '#ifndef LAB_ENTRY_11\n'
    '#ifndef LAB_ENTRY_12\n'
    '#ifndef LAB_ENTRY_19\n'
    '#define LAB_ENTRY_11\n'
    '#endif\n#endif\n#endif\n')
ROWS = (
    ('LAB_ENTRY_11', 'ea_template/Boss_11_Fix.mq5'),
    ('LAB_ENTRY_12', 'ea_template/Boss_12_Fix.mq5'),
    ('LAB_ENTRY_19', 'ea_template/Probe_19_AdaptiveTrendGrid.mq5'),
)
P4B = 'ea_template/Probe_19_AdaptiveTrendGrid_P4BUnitExport.mq5'


def manifest(rows=ROWS, header=b'build_tag,wrapper_rel'):
    body = b'\n'.join(('%s,%s' % row).encode('ascii') for row in rows)
    return header + b'\n' + body + b'\n'


def fixture(rows=ROWS, manifest_bytes=None):
    files = {
        owners.MANIFEST_REL: manifest(rows) if manifest_bytes is None else manifest_bytes,
        owners.INPUTS_REL: INPUTS,
        'ea_template/Boss_11_Fix.mq5': '#define LAB_ENTRY_11\n#include "core/Fix.mqh"\n',
        'ea_template/Boss_12_Fix.mq5': '#define LAB_ENTRY_12\n#include "core/Fix.mqh"\n',
        'ea_template/Probe_19_AdaptiveTrendGrid.mq5': (
            '#define LAB_ENTRY_19 // canonical owner\n#include "core/Fix.mqh"\n'),
        P4B: '#define LAB_ENTRY_19\n// diagnostic sibling, not an owner\n',
        'ea_template/core/Fix.mqh': '#define ORDINARY 7\n',
    }
    return files


class FakeSource(object):
    mode = 'fixture'

    def __init__(self, files, listing=None):
        self.files = dict(files)
        self.listing = listing

    def read_committed_bytes(self, rel):
        if rel not in self.files:
            raise IOError('%s is absent from the fixture snapshot' % rel)
        value = self.files[rel]
        return value if isinstance(value, bytes) else value.encode('utf-8')

    def read_committed(self, rel, errors='strict'):
        raw = self.read_committed_bytes(rel)
        return raw.decode('utf-8', errors=errors).replace('\r\n', '\n')

    def list_committed(self, pattern):
        if self.listing is not None:
            return list(self.listing)
        return sorted(path for path in self.files
                      if path.startswith('ea_template/')
                      and '/' not in path[len('ea_template/'):]
                      and path.endswith('.mq5'))


def refused(files, listing=None, contains=None):
    try:
        owners.load(FakeSource(files, listing=listing))
    except Exception as exc:  # every read/parse failure is fail-closed at this seam
        return contains is None or contains.lower() in str(exc).lower()
    return False


def mutated(files, rel, old, new):
    out = dict(files)
    value = out[rel]
    changed = value.replace(old, new)
    if changed == value:
        raise AssertionError('mutation anchor did not occur for %s: %r' % (rel, old))
    out[rel] = changed
    return out


def main():
    checks = []

    clean_files = fixture()
    loaded = owners.load(FakeSource(clean_files))
    checks.append(('clean control resolves exactly the manifest rows',
                   loaded.by_tag == dict(ROWS)))
    checks.append(('P4B diagnostic sibling coexists without becoming LAB_ENTRY_19 owner',
                   loaded.by_tag['LAB_ENTRY_19'] != P4B and P4B in loaded.root_mq5))

    attacks = []
    attacks.append(('missing row', fixture(ROWS[:-1]), None, 'missing'))
    attacks.append(('extra row', fixture(ROWS + (('LAB_ENTRY_13', 'ea_template/Boss_13_Fix.mq5'),)),
                    None, 'extra'))
    attacks[-1][1]['ea_template/Boss_13_Fix.mq5'] = '#define LAB_ENTRY_13\n'
    attacks.append(('duplicate build tag',
                    fixture(ROWS + (('LAB_ENTRY_11', 'ea_template/Boss_11_Other.mq5'),)),
                    None, 'duplicate build tag'))
    attacks[-1][1]['ea_template/Boss_11_Other.mq5'] = '#define LAB_ENTRY_11\n'
    attacks.append(('duplicate owner path',
                    fixture((ROWS[0], ('LAB_ENTRY_12', ROWS[0][1]), ROWS[2])),
                    None, 'duplicate owner'))
    attacks.append(('case-only owner collision', fixture((
        ROWS[0], ('LAB_ENTRY_12', 'ea_template/boss_11_fix.mq5'), ROWS[2])),
        None, 'case-insensitive'))

    collision_files = fixture()
    collision_files['ea_template/boss_11_fix.mq5'] = '#define LAB_ENTRY_11\n'
    attacks.append(('case-only committed path collision', collision_files, None, 'listing'))

    for bad_path in (
            r'ea_template\\Boss_11_Fix.mq5', '/ea_template/Boss_11_Fix.mq5',
            'ea_template/./Boss_11_Fix.mq5', 'ea_template/x/../Boss_11_Fix.mq5',
            'other/Boss_11_Fix.mq5', 'ea_template/Boss_11_Fix.MQ5'):
        attacks.append(('noncanonical owner path %r' % bad_path,
                        fixture(((ROWS[0][0], bad_path), ROWS[1], ROWS[2])),
                        None, 'path'))

    attacks.append(('missing owner', fixture(((ROWS[0][0], 'ea_template/Missing.mq5'),
                                               ROWS[1], ROWS[2])), None, 'exact spelling'))
    attacks.append(('owner token mismatch', mutated(clean_files, ROWS[0][1],
                                                     'LAB_ENTRY_11', 'LAB_ENTRY_12'),
                    None, 'row key'))
    attacks.append(('multiple owner tokens', mutated(clean_files, ROWS[0][1],
                                                      '#define LAB_ENTRY_11',
                                                      '#define LAB_ENTRY_11\n#define LAB_ENTRY_12'),
                    None, 'exactly one'))
    attacks.append(('valued build token', mutated(clean_files, ROWS[0][1],
                                                   '#define LAB_ENTRY_11',
                                                   '#define LAB_ENTRY_11 1'),
                    None, 'valueless'))
    attacks.append(('malformed header', fixture(manifest_bytes=manifest(header=b'tag,path')),
                    None, 'header'))
    attacks.append(('three-field row', fixture(manifest_bytes=(
        b'build_tag,wrapper_rel\nLAB_ENTRY_11,ea_template/Boss_11_Fix.mq5,extra\n')),
                    None, 'two fields'))
    attacks.append(('noncanonical build tag', fixture((('lab_entry_11', ROWS[0][1]),
                                                        ROWS[1], ROWS[2])),
                    None, 'canonical'))
    attacks.append(('undecodable manifest bytes', fixture(manifest_bytes=b'build_tag,wrapper_rel\n\xff'),
                    None, 'utf-8'))
    missing_manifest = fixture()
    del missing_manifest[owners.MANIFEST_REL]
    attacks.append(('unreadable manifest', missing_manifest, None, 'absent'))

    for label, files, listing, message in attacks:
        checks.append((label + ' mutation is detected', refused(files, listing, message)))

    # The prior rejected design let process state choose the owner.  Recreate that bypass after
    # import: the authoritative resolver and generated bytes must remain fixed by CSV bytes.
    checks.append(('capability has no hand-maintained WRAPPER_FILE owner table',
                   not hasattr(capability, 'WRAPPER_FILE')))
    capability.WRAPPER_FILE = {'LAB_ENTRY_11': 'ea_template/Evil.mq5'}
    rebound = owners.load(FakeSource(clean_files))
    before = locked.emit(FakeSource(clean_files).read_committed, INPUTS, loaded.by_tag)
    after = locked.emit(FakeSource(clean_files).read_committed, INPUTS, rebound.by_tag)
    checks.append(('dynamic capability.WRAPPER_FILE rebinding cannot change owner resolution',
                   rebound.by_tag == dict(ROWS) and before == after))

    bad = 0
    for label, ok in checks:
        print('[%s] %s' % ('PASS' if ok else 'FAIL', label))
        bad += 0 if ok else 1
    print('%s %d/%d; %d adversarial mutations driven'
          % ('PASS' if not bad else 'FAIL', len(checks) - bad, len(checks), len(attacks)))
    return 1 if bad else 0


if __name__ == '__main__':
    raise SystemExit(main())
