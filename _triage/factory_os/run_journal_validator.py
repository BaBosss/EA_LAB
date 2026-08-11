# -*- coding: utf-8 -*-
"""ORDER-1500 validation for the committed scheduler recovery journals.

`factory/runs/*.jsonl` is an append-only journal of RunTransition records, not a
registry store.  The validator therefore reads the bounded glob separately and
validates ordinary rows against the existing RunTransition contract.  Three
historical manifests are retained by an owner-approved, byte-pinned exception
until their occurrence is represented in the experiment event log.
"""
import hashlib
import io
import json
import os
import shutil
import subprocess
import tempfile

try:
    import evidence
except ImportError:  # direct import from a different caller remains explicit
    evidence = None


VALID = 'VALID'
LEGACY_EXCEPTION = 'LEGACY_EXCEPTION'
INVALID = 'INVALID'
ERROR = 'ERROR'

LEGACY_EXCEPTION_IDS = frozenset({
    'RUN-20260802-001',
    'RUN-20260802-002',
    'RUN-20260802-004',
})

LEGACY_MANIFEST_SHA256 = {
    'factory/runs/RUN-20260802-001.jsonl':
        '799db7e3fb79c446a707df774c6110f958345cbea2264597c95045d2b020e8b4',
    'factory/runs/RUN-20260802-002.jsonl':
        '93c6ced66d26c24fd9b788603fce5929ebcd82d1efc6b38f68f88a08c7eb0188',
    'factory/runs/RUN-20260802-004.jsonl':
        'e99e4d607837452fc1d26abd12119ce509f8bd3d906c5d529918d971c8c716c2',
}


class JournalInfrastructureError(Exception):
    """The journal could not be read or the schema validator could not run."""


class JournalValidationReport(object):
    def __init__(self):
        self.rows = []
        self.legacy_files = []
        self.infrastructure_errors = []

    @property
    def invalid_rows(self):
        return [r for r in self.rows if r['state'] == INVALID]

    @property
    def error_rows(self):
        return [r for r in self.rows if r['state'] == ERROR]

    @property
    def ok(self):
        return not self.invalid_rows and not self.error_rows and not self.infrastructure_errors


def _decode(raw, rel):
    if not isinstance(raw, bytes):
        raise JournalInfrastructureError('%s reader returned non-bytes data' % rel)
    try:
        return raw.decode('utf-8-sig').replace('\r\n', '\n')
    except UnicodeDecodeError as exc:
        raise JournalInfrastructureError('%s is not UTF-8: %s' % (rel, exc))


def _exception_path(run_id):
    return 'factory/runs/%s.jsonl' % run_id


def _is_exact_exception(rel, raw, legacy_ids):
    """Return true only for the closed path + ID + committed-byte triple."""
    if rel not in LEGACY_MANIFEST_SHA256:
        return False
    run_id = os.path.basename(rel)[:-len('.jsonl')]
    if run_id not in legacy_ids or rel != _exception_path(run_id):
        return False
    return hashlib.sha256(raw).hexdigest() == LEGACY_MANIFEST_SHA256[rel]


def _parse_lines(rel, raw):
    text = _decode(raw, rel)
    parsed = []
    invalid = []
    for line_no, line in enumerate(text.split('\n'), 1):
        if not line.strip():
            continue
        try:
            parsed.append((line_no, json.loads(line)))
        except ValueError as exc:
            invalid.append({
                'file': rel,
                'line': line_no,
                'run_id': None,
                'state': INVALID,
                'detail': 'invalid JSON: %s' % exc,
            })
    return parsed, invalid


def _ajv_validate(schema_path, rows):
    """Validate ordinary rows against only the RunTransition definition."""
    if not rows:
        return {}
    try:
        with io.open(schema_path, encoding='utf-8') as fh:
            schema_doc = json.load(fh)
    except (IOError, ValueError) as exc:
        raise JournalInfrastructureError('cannot read schema %s: %s' % (schema_path, exc))

    tmpdir = tempfile.mkdtemp(prefix='order1500_journal_')
    try:
        wrapper_path = os.path.join(tmpdir, 'run_transition_schema.json')
        wrapper = {
            '$schema': schema_doc.get('$schema', 'https://json-schema.org/draft/2020-12/schema'),
            '$defs': schema_doc.get('$defs'),
            '$ref': '#/$defs/RunTransition',
        }
        with io.open(wrapper_path, 'w', encoding='utf-8') as fh:
            json.dump(wrapper, fh)

        names = {}
        cmd = ['ajv', 'validate', '-s', wrapper_path, '--spec=draft2020', '--strict=false',
               '--errors=line']
        for index, row in enumerate(rows):
            name = 'row_%04d.json' % index
            path = os.path.join(tmpdir, name)
            with io.open(path, 'w', encoding='utf-8') as fh:
                json.dump(row['record'], fh)
            names[name] = row
            cmd += ['-d', path]
        try:
            proc = subprocess.run(cmd, capture_output=True, text=True, shell=True)
        except OSError as exc:
            raise JournalInfrastructureError('cannot execute ajv: %s' % exc)
        output = ((proc.stdout or '') + '\n' + (proc.stderr or '')).strip()
        results = {}
        lines = output.splitlines()
        for line_index, line in enumerate(lines):
            stripped = line.strip()
            for name, row in names.items():
                if name not in stripped:
                    continue
                if stripped.endswith(' valid'):
                    results[id(row)] = (VALID, stripped)
                elif stripped.endswith(' invalid'):
                    detail = lines[line_index + 1].strip() if line_index + 1 < len(lines) else stripped
                    results[id(row)] = (INVALID, detail)
                break
        if proc.returncode not in (0, 1) or len(results) != len(rows):
            raise JournalInfrastructureError(
                'ajv did not produce one verdict per row (exit %s): %s'
                % (proc.returncode, output[:500]))
        return results
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def _validate_run_journals(source, schema_path, legacy_ids=LEGACY_EXCEPTION_IDS):
    report = JournalValidationReport()
    try:
        paths = source.list_committed('factory/runs/*.jsonl')
    except Exception as exc:
        if evidence is not None and isinstance(exc, evidence.ToolFailure):
            raise JournalInfrastructureError('cannot enumerate factory/runs/*.jsonl: %s' % exc)
        raise

    ordinary = []
    for rel in sorted(paths):
        try:
            raw = source.read_committed_bytes(rel)
        except Exception as exc:
            if evidence is not None and isinstance(exc, evidence.ToolFailure):
                raise JournalInfrastructureError('cannot read %s: %s' % (rel, exc))
            raise
        parsed, parse_invalid = _parse_lines(rel, raw)
        report.rows.extend(parse_invalid)
        if _is_exact_exception(rel, raw, legacy_ids):
            expected_id = os.path.basename(rel)[:-len('.jsonl')]
            if parse_invalid or any((not isinstance(record, dict)
                                     or record.get('run_id') != expected_id
                                     or record.get('entity') != 'RunTransition')
                                    for _line, record in parsed):
                # A byte-pinned file cannot reach this branch in normal operation; retain the
                # explicit guard so an altered policy cannot turn a malformed file into a pass.
                for line_no, record in parsed:
                    report.rows.append({
                        'file': rel,
                        'line': line_no,
                        'run_id': record.get('run_id') if isinstance(record, dict) else None,
                        'state': INVALID,
                        'detail': 'historical exception content does not match its literal manifest',
                    })
                continue
            report.legacy_files.append(rel)
            for line_no, record in parsed:
                report.rows.append({
                    'file': rel,
                    'line': line_no,
                    'run_id': expected_id,
                    'state': LEGACY_EXCEPTION,
                    'detail': 'accepted by exact byte-pinned historical exception',
                })
            continue
        for line_no, record in parsed:
            ordinary.append({
                'file': rel,
                'line': line_no,
                'run_id': record.get('run_id') if isinstance(record, dict) else None,
                'record': record,
            })

    try:
        ajv_results = _ajv_validate(schema_path, ordinary)
    except JournalInfrastructureError:
        raise
    for item in ordinary:
        state, detail = ajv_results[id(item)]
        report.rows.append({
            'file': item['file'],
            'line': item['line'],
            'run_id': item['run_id'],
            'state': state,
            'detail': detail,
        })
    return report


def validate_run_journals(source, schema_path):
    """Production entry point: only the closed policy can be used."""
    return _validate_run_journals(source, schema_path, LEGACY_EXCEPTION_IDS)
