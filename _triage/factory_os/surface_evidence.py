# -*- coding: utf-8 -*-
"""ORDER-1290: durable evidence for the input surface handed to a run.

The runners already have one surface contract in ``setfile_surface.ps1``:
``FULL``, ``MISMATCH``, ``UNDECLARED``, ``UNREADABLE`` and ``NOSETFILE``.  This
module does not create another policy.  It reads the same generated header and
uses the existing ``preset.parse_surface`` / ``setfile.surface_problems``
policy to make the state durable and independently checkable after a run.

The record is intentionally bound to both the run and its ExecutionKey.  A
surface claim without those bindings can be true for a different run and is
not evidence for the result being reviewed.
"""
import hashlib
import os
import re

import preset
import setfile


HEADER_RE = re.compile(
    r'^;\s*build=(\S+)\s+surface=(\d+)\s+'
    r'effective_config_hash=([0-9a-f]{64})(?:\s|$)')
SHA256_RE = re.compile(r'^[0-9a-f]{64}$')
RELATIVE_PATH_RE = re.compile(r'^(?![A-Za-z]:)(?!/)(?!\\)(?:[^/\\]+/)*[^/\\]+$')
STATES = ('FULL', 'MISMATCH', 'UNDECLARED', 'UNREADABLE', 'NOSETFILE')


def _sha256(raw):
    return hashlib.sha256(raw).hexdigest()


def _text(raw, label):
    if not isinstance(raw, bytes):
        raise ValueError('%s must be raw bytes' % label)
    try:
        return raw.decode('utf-8-sig').replace('\r\n', '\n')
    except UnicodeDecodeError as exc:
        raise ValueError('%s is not UTF-8: %s' % (label, exc))


def _header(set_text):
    for line in set_text.split('\n'):
        match = HEADER_RE.match(line.strip())
        if match:
            return {
                'build_tag': match.group(1),
                'declared': int(match.group(2)),
                'effective_config_hash': match.group(3),
            }
    return None


def _assignment_count(set_text):
    lines, _comments = setfile.parse_set(set_text)
    return lines, len(lines)


def _surface_state(set_text, input_text, build_tag, declared, assignments):
    if build_tag is None:
        return 'UNDECLARED', []
    try:
        surface = preset.parse_surface(input_text, build_tag)
        lines, _ = setfile.parse_set(set_text)
        problems = setfile.surface_problems(
            [line.name for line in lines], surface,
            what='the committed run .set', require_full_surface=True)
    except (ValueError, setfile.Refusal, preset.PresetRefusal) as exc:
        return 'MISMATCH', ['surface could not be resolved: %s' % exc]
    if declared != assignments:
        problems.append('surface header declares %d assignments but the .set carries %d'
                        % (declared, assignments))
    return ('FULL' if not problems else 'MISMATCH'), problems


def make_surface_state(run_id, execution_key, set_path, set_bytes,
                       input_source_path, input_source_bytes, build_tag=None):
    """Build a durable state record from the bytes actually used by the run.

    The caller supplies committed bytes, so the writer cannot accidentally hash a
    normalised or different worktree copy.  Incomplete/undeclared input is still
    represented, but ``complete`` is false and the reader will not accept it as
    reproducible evidence.
    """
    if not isinstance(run_id, str) or not run_id:
        raise ValueError('run_id is required')
    if not isinstance(execution_key, dict):
        raise ValueError('execution_key is required')
    if not isinstance(set_path, str) or not RELATIVE_PATH_RE.match(set_path):
        raise ValueError('set_path must be a repository-relative path')
    if not isinstance(input_source_path, str) or not RELATIVE_PATH_RE.match(input_source_path):
        raise ValueError('input_source_path must be a repository-relative path')
    set_text = _text(set_bytes, 'set_bytes')
    input_text = _text(input_source_bytes, 'input_source_bytes')
    header = _header(set_text)
    if header is None:
        state = 'UNDECLARED'
        declared = None
        assignments = len(_assignment_count(set_text)[0])
        effective = None
        resolved_build = None
    else:
        resolved_build = header['build_tag']
        declared = header['declared']
        effective = header['effective_config_hash']
        _lines, assignments = _assignment_count(set_text)
        state, _problems = _surface_state(
            set_text, input_text, resolved_build, declared, assignments)
    return {
        'run_id': run_id,
        'execution_key_digest': _execution_key_digest(execution_key),
        'set_path': set_path.replace('\\', '/'),
        'set_sha256': _sha256(set_bytes),
        'input_source_path': input_source_path.replace('\\', '/'),
        'input_source_sha256': _sha256(input_source_bytes),
        'state': state,
        'build_tag': resolved_build,
        'declared': declared,
        'assignments': assignments,
        'complete': state == 'FULL',
        'effective_config_hash': effective,
    }


def _execution_key_digest(execution_key):
    """Use the scheduler's canonical identity digest without duplicating its field order."""
    import scheduler
    return scheduler.execution_key_digest(execution_key)


def validate_surface_state(record, run_id, execution_key, set_bytes, input_source_bytes):
    """Return named problems; an empty list means reproducible, complete evidence."""
    problems = []
    if not isinstance(record, dict):
        return ['set_surface_state must be an object']
    required = {
        'run_id', 'execution_key_digest', 'set_path', 'set_sha256',
        'input_source_path', 'input_source_sha256', 'state', 'build_tag',
        'declared', 'assignments', 'complete', 'effective_config_hash',
    }
    extra = sorted(set(record) - required)
    missing = sorted(required - set(record))
    if missing:
        problems.append('set_surface_state missing %s' % ', '.join(missing))
    if extra:
        problems.append('set_surface_state has unknown fields %s' % ', '.join(extra))
    if problems:
        return problems

    if record['run_id'] != run_id:
        problems.append('surface run_id %r does not match journal run_id %r'
                        % (record['run_id'], run_id))
    if not isinstance(record['set_path'], str) or not RELATIVE_PATH_RE.match(record['set_path']):
        problems.append('surface set_path must be repository-relative')
    if not isinstance(record['input_source_path'], str) \
            or not RELATIVE_PATH_RE.match(record['input_source_path']):
        problems.append('surface input_source_path must be repository-relative')
    for field in ('set_sha256', 'input_source_sha256', 'effective_config_hash'):
        if record[field] is not None and (not isinstance(record[field], str)
                                          or not SHA256_RE.match(record[field])):
            problems.append('surface %s is not a sha256' % field)
    if record['state'] not in STATES:
        problems.append('surface state %r is not one of %s' % (record['state'], STATES))
    if not isinstance(record['complete'], bool):
        problems.append('surface complete must be boolean')
    if not isinstance(record['assignments'], int) or isinstance(record['assignments'], bool):
        problems.append('surface assignments must be an integer')
    if record['declared'] is not None and \
            (not isinstance(record['declared'], int) or isinstance(record['declared'], bool)):
        problems.append('surface declared must be an integer or null')
    if problems:
        return problems

    if record['set_sha256'] != _sha256(set_bytes):
        problems.append('surface set_sha256 does not match the committed .set bytes')
    if record['input_source_sha256'] != _sha256(input_source_bytes):
        problems.append('surface input_source_sha256 does not match Inputs.mqh bytes')
    try:
        expected_digest = _execution_key_digest(execution_key)
    except (AttributeError, TypeError, ValueError) as exc:
        problems.append('execution key cannot be digested: %s' % exc)
    else:
        if record['execution_key_digest'] != expected_digest:
            problems.append('surface execution_key_digest does not match this run identity')
        if execution_key.get('set_hash') != record['set_sha256']:
            problems.append('surface set hash does not match ExecutionKey.set_hash')
        if execution_key.get('effective_config_hash') != record['effective_config_hash']:
            problems.append('surface effective config hash does not match ExecutionKey')

    set_text = _text(set_bytes, 'set_bytes')
    input_text = _text(input_source_bytes, 'input_source_bytes')
    header = _header(set_text)
    if header is None:
        actual_state = 'UNDECLARED'
        actual_build = None
        actual_declared = None
        actual_effective = None
        try:
            _lines, actual_assignments = _assignment_count(set_text)
        except (ValueError, setfile.Refusal) as exc:
            problems.append('set file cannot be parsed: %s' % exc)
            actual_assignments = None
    else:
        actual_build = header['build_tag']
        actual_declared = header['declared']
        actual_effective = header['effective_config_hash']
        try:
            _lines, actual_assignments = _assignment_count(set_text)
            actual_state, state_problems = _surface_state(
                set_text, input_text, actual_build, actual_declared, actual_assignments)
            problems.extend(state_problems)
        except (ValueError, setfile.Refusal) as exc:
            actual_state = 'MISMATCH'
            actual_assignments = None
            problems.append('set file cannot be parsed: %s' % exc)

    checks = (
        ('build_tag', actual_build),
        ('declared', actual_declared),
        ('assignments', actual_assignments),
        ('effective_config_hash', actual_effective),
        ('state', actual_state),
    )
    for field, actual in checks:
        if record[field] != actual:
            problems.append('surface %s=%r does not match committed input (%r)'
                            % (field, record[field], actual))
    if record['complete'] != (actual_state == 'FULL'):
        problems.append('surface complete flag contradicts the committed surface state')
    if actual_state != 'FULL':
        problems.append('surface is not complete: %s' % actual_state)
    return problems
