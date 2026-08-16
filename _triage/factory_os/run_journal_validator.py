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
import re

try:
    import evidence
except ImportError:  # direct import from a different caller remains explicit
    evidence = None

try:
    import surface_evidence
except ImportError:  # direct callers still get the schema-only journal checks
    surface_evidence = None


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
        '47e684a7af52a5c877d7cd84202e8a684d94c39485d199d041c727cfaaf963e7',
    'factory/runs/RUN-20260802-002.jsonl':
        '8edf62d132d368c66d9d1dd299d209e4a7bb1a8b1d2faea79d63d93321423c6a',
    'factory/runs/RUN-20260802-004.jsonl':
        '09307da68db0236ce0f0846f51b7680a0ab914bfe589ff53522cb86275c18210',
}

CURRENT_FINGERPRINT_RE = re.compile(r'^(?:v[0-9]+:)?[0-9a-f]{64}$')
CURRENT_KEY_FIELDS = frozenset((
    'expert', 'symbol', 'tf', 'from_date', 'to_date', 'model', 'deposit',
    'currency', 'account_unit', 'leverage', 'terminal_build', 'set_hash',
    'ex5_hash', 'effective_config_hash', 'data_fingerprint', 'lane'))


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


def _journal_semantic_problems(record, source, key_by_file):
    """Rules that the broad historical schema cannot express safely.

    The schema keeps LegacyExecutionKey readable so the historical rows can be
    audited.  It is not permission for a new journal to use that shape.  The
    same boundary is where the versioned fingerprint contract is enforced.
    """
    if not isinstance(record, dict):
        return ['RunTransition must be an object']
    problems = []
    key = record.get('execution_key')
    if record.get('transition') == 'QUEUED' and not isinstance(key, dict):
        problems.append('QUEUED must carry a current ExecutionKey')
    if isinstance(key, dict):
        if set(key) != set(CURRENT_KEY_FIELDS):
            problems.append('legacy or incomplete ExecutionKey is allowed only by the exact '
                            'three-manifest historical exception')
        if 'ini_hash' in key:
            problems.append('execution_key.ini_hash is historical and cannot enter a new journal')
        fingerprint = key.get('data_fingerprint')
        if not isinstance(fingerprint, str) or not CURRENT_FINGERPRINT_RE.match(fingerprint):
            problems.append('data_fingerprint must be a versioned or bare sha256, not a preimage')

    surface = record.get('record', {}).get('set_surface_state') \
        if isinstance(record.get('record'), dict) else None
    if surface is not None:
        if surface_evidence is None:
            problems.append('surface evidence reader is unavailable')
        else:
            run_key = key_by_file.get(record.get('_source_file'))
            if run_key is None:
                problems.append('surface evidence has no QUEUED ExecutionKey in this journal')
            else:
                try:
                    set_bytes = source.read_committed_bytes(surface['set_path'])
                    input_bytes = source.read_committed_bytes(surface['input_source_path'])
                    problems.extend(surface_evidence.validate_surface_state(
                        surface, record.get('run_id'), run_key, set_bytes, input_bytes))
                except Exception as exc:
                    problems.append('surface evidence inputs could not be read: %s' % exc)
    return problems


def _validate_run_journals(source, schema_path, legacy_ids=LEGACY_EXCEPTION_IDS):
    report = JournalValidationReport()
    try:
        paths = source.list_committed('factory/runs/*.jsonl')
    except Exception as exc:
        if evidence is not None and isinstance(exc, evidence.ToolFailure):
            raise JournalInfrastructureError('cannot enumerate factory/runs/*.jsonl: %s' % exc)
        raise

    ordinary = []
    key_by_file = {}
    surface_files = set()
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
            if isinstance(record, dict) and isinstance(record.get('execution_key'), dict):
                key_by_file.setdefault(rel, record['execution_key'])
            if isinstance(record, dict) and isinstance(record.get('record'), dict) \
                    and record['record'].get('set_surface_state') is not None:
                surface_files.add(rel)
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
        item['record']['_source_file'] = item['file']
        semantic = _journal_semantic_problems(item['record'], source, key_by_file)
        if (isinstance(item['record'], dict)
                and item['record'].get('transition') in ('COMPLETED', 'EVIDENCE_REGISTERED')
                and item['file'] not in surface_files):
            semantic.append('completed evidence has no durable set_surface_state')
        item['record'].pop('_source_file', None)
        if semantic:
            state = INVALID
            detail = '; '.join(semantic)
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
