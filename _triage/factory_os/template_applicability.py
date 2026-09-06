# -*- coding: utf-8 -*-
"""Offline applicability index for template sidecar evidence.

This tool compares the source_refs recorded by each Factory vNext artifact index with the
bytes at an exact Git ref. A different source commit is evidence only that the commits differ;
it is not a reason to invalidate a package whose recorded dependencies are byte-identical.

The output is deliberately non-authoritative. UNCHANGED_DEPENDENCIES means the recorded inputs
are unchanged. UNVERIFIED means a relevant input changed or disappeared. Neither state asserts
behavioral parity, qualification, deployment readiness, or strategy quality.

Usage:
  python _triage/factory_os/template_applicability.py --repo . --ref <40-hex> --output report.json
"""
from __future__ import print_function

import argparse
import csv
import hashlib
import json
import os
import posixpath
import re
import subprocess
import sys


class ApplicabilityRefusal(Exception):
    pass


class MissingDependency(Exception):
    pass


SAFE_PATH = re.compile(r'^[A-Za-z0-9_.][A-Za-z0-9_./ -]*$')
INDEX_RE = re.compile(
    r'^factory/vnext/pilots/boss(?P<boss>1[1-8])_[^/]+/artifact_index\.json$')

# Only B14 has accepted wrapper parity in the persisted readiness evidence. This records that
# source and its conservative dependency closure; it does not confer current acceptance.
ACCEPTED_WRAPPERS = {
    'B14': {
        'source_ref': '19b8b3edcf5daf6a3a10eaec9634c37db2dde140',
        'paths': (
            'ea_template/Boss_14_GridLog.mq5',
            'ea_template/core',
            'ea_template/generated/B14_H01_r1.mq5',
            'ea_template/generated/B14_H02_r1.mq5',
            'ea_template/generated/B14_H01_r1_allowlist.mqh',
            'ea_template/generated/B14_H02_r1_allowlist.mqh',
            '_triage/factory_os/gen_wrapper.py',
            '_triage/factory_os/check_wrapper_gen.py',
            '_triage/factory_os/activation.py',
            '_triage/factory_os/hypothesis_b14.py',
            '_triage/factory_os/parity.py',
            'scripts/parity_run.ps1',
        ),
    },
}


def _safe_path(path):
    if (not isinstance(path, str) or not path or '\\' in path or path.startswith('/') or
            not SAFE_PATH.fullmatch(path) or posixpath.normpath(path) != path or
            path == '..' or path.startswith('../')):
        raise ApplicabilityRefusal('unsafe dependency path %r' % path)
    return path


def _sha256(data):
    return hashlib.sha256(data).hexdigest()


def assess_package(index, source, current_ref):
    """Assess one parsed artifact index against a byte source exposing read_bytes(path)."""
    refs = index.get('source_refs')
    if not isinstance(refs, list) or not refs:
        raise ApplicabilityRefusal('artifact index has no non-empty source_refs list')
    changed = []
    missing = []
    seen = set()
    for row in refs:
        if not isinstance(row, dict):
            raise ApplicabilityRefusal('source_refs contains a non-object row')
        path = _safe_path(row.get('path'))
        if path in seen:
            raise ApplicabilityRefusal('duplicate dependency path %r' % path)
        seen.add(path)
        expected = row.get('sha256')
        if not isinstance(expected, str) or not re.fullmatch(r'[0-9a-f]{64}', expected):
            raise ApplicabilityRefusal('%s has malformed sha256 %r' % (path, expected))
        try:
            current = source.read_bytes(path)
        except MissingDependency:
            missing.append(path)
            continue
        if _sha256(current) != expected:
            changed.append(path)
    state = 'UNCHANGED_DEPENDENCIES' if not changed and not missing else 'UNVERIFIED'
    accepted_source = index.get('source_commit')
    return {
        'package_id': index.get('PackageID'),
        'authority': index.get('authority'),
        'accepted_source_ref': accepted_source,
        'current_source_ref': current_ref,
        'source_sha_differs': accepted_source != current_ref,
        'comparison': 'recorded source_refs.sha256 vs exact-ref Git blob sha256',
        'dependency_state': state,
        'changed_dependencies': sorted(changed),
        'missing_dependencies': sorted(missing),
    }


def assess_parameter_contract(schema, csv_text):
    """Compare the generated-contract source with the actual registry header/vocabulary."""
    try:
        contract = schema['x-ea-lab-meta']['contracts']['parameter_registry_columns']
        rows = contract['rows']
    except (KeyError, TypeError):
        raise ApplicabilityRefusal('schema has no parameter_registry_columns rows')
    declared = [row.get('column') for row in rows]
    header_line = next((line for line in csv_text.splitlines()
                        if line.strip() and not line.startswith('>')), None)
    if header_line is None:
        raise ApplicabilityRefusal('parameter registry has no CSV header')
    try:
        actual = next(csv.reader([header_line]))
    except (csv.Error, StopIteration) as exc:
        raise ApplicabilityRefusal('parameter registry header is malformed: %s' % exc)
    classification = next((row.get('meaning', '') for row in rows
                           if row.get('column') == 'classification'), '')
    vocabulary = sorted(set(re.findall(
        r'\b(?:ACTIVE|OVERRIDE|INACTIVE|COMPATIBILITY)\b', classification)))
    expected_vocabulary = sorted(('ACTIVE', 'OVERRIDE', 'INACTIVE', 'COMPATIBILITY'))
    problems = []
    if declared != actual:
        problems.append('declared columns do not exactly match the CSV header')
    if vocabulary != expected_vocabulary:
        problems.append('classification vocabulary is incomplete or different')
    return {
        'state': 'COHERENT' if not problems else 'CONFLICT',
        'declared_columns': declared,
        'actual_columns': actual,
        'classification_vocabulary': vocabulary,
        'problems': problems,
    }


class GitSource(object):
    def __init__(self, repo, ref):
        self.repo = os.path.abspath(repo)
        self.ref = ref

    def _git(self, args, binary=False):
        proc = subprocess.run(
            ['git', '--no-optional-locks', '-C', self.repo] + list(args),
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if proc.returncode:
            detail = proc.stderr.decode('utf-8', 'replace').strip()
            raise ApplicabilityRefusal('git %s failed: %s' % (' '.join(args), detail))
        return proc.stdout if binary else proc.stdout.decode('utf-8', 'strict')

    def read_bytes(self, path):
        _safe_path(path)
        proc = subprocess.run(
            ['git', '--no-optional-locks', '-C', self.repo, 'cat-file', 'blob',
             '%s:%s' % (self.ref, path)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if proc.returncode:
            raise MissingDependency(path)
        return proc.stdout

    def tree(self):
        return [p for p in self._git(['ls-tree', '-r', '--name-only', self.ref]).splitlines() if p]

    def changed_paths(self, old_ref, paths):
        text = self._git(['diff', '--name-only', old_ref, self.ref, '--'] + list(paths))
        return sorted(p for p in text.splitlines() if p)


def _b14_relevant(path):
    """Exclude entry modules that the B14 build does not select."""
    if path.startswith('ea_template/core/entries/Entry_'):
        return path.endswith('/Entry_GridLog.mqh')
    if path == 'ea_template/core/entries/Kangaroo.mqh':
        return False
    return True


def build_report(repo, ref):
    if not re.fullmatch(r'[0-9a-f]{40}', ref or ''):
        raise ApplicabilityRefusal('--ref must be an exact lowercase 40-hex commit')
    source = GitSource(repo, ref)
    resolved = source._git(['rev-parse', ref]).strip()
    if resolved != ref:
        raise ApplicabilityRefusal('exact ref %s resolved as %s' % (ref, resolved))
    tree = source.tree()
    indexes = {}
    for path in tree:
        match = INDEX_RE.match(path)
        if not match:
            continue
        boss = 'B' + match.group('boss')
        if boss in indexes:
            raise ApplicabilityRefusal('multiple artifact indexes found for %s' % boss)
        try:
            parsed = json.loads(source.read_bytes(path).decode('utf-8'))
        except (ValueError, UnicodeDecodeError) as exc:
            raise ApplicabilityRefusal('%s is not valid UTF-8 JSON: %s' % (path, exc))
        result = assess_package(parsed, source, ref)
        result['artifact_index'] = path
        indexes[boss] = result

    rows = []
    for n in range(11, 19):
        boss = 'B%d' % n
        wrappers = sorted(
            p for p in tree if re.match(r'^ea_template/generated/%s_.*\.mq5$' % boss, p))
        accepted = ACCEPTED_WRAPPERS.get(boss)
        changed = []
        if accepted:
            changed = source.changed_paths(accepted['source_ref'], accepted['paths'])
            changed = [p for p in changed if _b14_relevant(p)]
            wrapper_state = 'UNCHANGED_DEPENDENCIES' if not changed else 'UNVERIFIED'
        else:
            wrapper_state = 'CODE_WITHOUT_ACCEPTED_PARITY' if wrappers else 'NO_GENERATED_WRAPPER'
        rows.append({
            'boss': boss,
            'generated_wrappers': wrappers,
            'accepted_wrapper_source_ref': accepted['source_ref'] if accepted else None,
            'original_wrapper_evidence_accepted': bool(accepted),
            'wrapper_dependency_state': wrapper_state,
            'changed_wrapper_dependencies': changed,
            'package': indexes.get(boss),
        })
    return {
        'schema_version': 'ea-lab-template-applicability-v1',
        'source_ref': ref,
        'authority': 'NON_AUTHORITATIVE_OFFLINE_CHECK',
        'meaning': ('Dependency identity only. This report does not assert behavioral parity, '
                    'qualification, deployment readiness, or strategy quality.'),
        'bosses': rows,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', default='.')
    parser.add_argument('--ref', required=True)
    parser.add_argument('--output')
    args = parser.parse_args(argv)
    try:
        report = build_report(args.repo, args.ref)
    except ApplicabilityRefusal as exc:
        print('[REFUSED] %s' % exc, file=sys.stderr)
        return 2
    text = json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False) + '\n'
    if args.output:
        with open(args.output, 'w', encoding='utf-8', newline='\n') as handle:
            handle.write(text)
    else:
        sys.stdout.write(text)
    return 0


if __name__ == '__main__':
    sys.exit(main())
