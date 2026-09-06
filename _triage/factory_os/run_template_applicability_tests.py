# -*- coding: utf-8 -*-
"""Focused offline cage for dependency-based template evidence applicability."""
import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import template_applicability as app  # noqa: E402


def sha(data):
    return hashlib.sha256(data).hexdigest()


class FakeSource(object):
    def __init__(self, files):
        self.files = dict(files)

    def read_bytes(self, path):
        if path not in self.files:
            raise app.MissingDependency(path)
        return self.files[path]


def check(name, ok, detail=''):
    if not ok:
        raise AssertionError('%s: %s' % (name, detail))
    print('[OK] ' + name)


def main():
    same = b'same dependency bytes\n'
    index = {
        'PackageID': 'PKG-1',
        'authority': 'NON_AUTHORITATIVE_SIDECAR',
        'source_commit': 'a' * 40,
        'source_refs': [{'path': 'dep.txt', 'sha256': sha(same), 'bytes': len(same)}],
    }
    got = app.assess_package(index, FakeSource({'dep.txt': same}), 'b' * 40)
    check('source SHA mismatch alone preserves unchanged dependency applicability',
          got['source_sha_differs'] and got['dependency_state'] == 'UNCHANGED_DEPENDENCIES',
          json.dumps(got, sort_keys=True))

    changed = app.assess_package(index, FakeSource({'dep.txt': b'changed\n'}), 'b' * 40)
    check('changed dependency is UNVERIFIED and is named',
          changed['dependency_state'] == 'UNVERIFIED' and
          changed['changed_dependencies'] == ['dep.txt'], json.dumps(changed, sort_keys=True))

    missing = app.assess_package(index, FakeSource({}), 'b' * 40)
    check('missing dependency is UNVERIFIED and is named',
          missing['dependency_state'] == 'UNVERIFIED' and
          missing['missing_dependencies'] == ['dep.txt'], json.dumps(missing, sort_keys=True))

    try:
        app.assess_package({'source_refs': [{'path': '../outside', 'sha256': sha(same)}]},
                           FakeSource({'../outside': same}), 'b' * 40)
    except app.ApplicabilityRefusal as exc:
        check('unsafe dependency path refuses', 'unsafe dependency path' in str(exc), str(exc))
    else:
        raise AssertionError('unsafe dependency path was accepted')

    repo_root = os.environ.get(
        'EA_LAB_TEMPLATE_TEST_ROOT', os.path.dirname(os.path.dirname(HERE)))
    schema_path = os.path.join(repo_root, '_triage', 'factory_os', 'schemas.json')
    registry_path = os.environ.get(
        'EA_LAB_PARAMETER_REGISTRY_PATH',
        os.path.join(repo_root, 'docs', 'PARAM_REGISTRY.csv'))
    with open(schema_path, encoding='utf-8') as handle:
        schema = json.load(handle)
    with open(registry_path, encoding='utf-8-sig') as handle:
        parameter_csv = handle.read()
    contract = app.assess_parameter_contract(schema, parameter_csv)
    check('generated parameter contract exactly matches the operational CSV header and vocabulary',
          contract['state'] == 'COHERENT', json.dumps(contract, sort_keys=True))


    print('TEMPLATE APPLICABILITY TESTS OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
