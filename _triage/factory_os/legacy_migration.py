# -*- coding: utf-8 -*-
"""Owner-approved M4 legacy migration boundary.

Legacy refs preserve historical identity/evidence without becoming Factory authority.
They are intentionally unable to create E### identities, E3 evidence, candidates,
deployments, or lifecycle verdicts.
"""
from __future__ import print_function

import hashlib
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
MIGRATION_ROOT = os.path.join(REPO_ROOT, 'factory', 'legacy_migration')
STRATEGY_FILE = os.path.join(MIGRATION_ROOT, 'strategy_bridge.jsonl')
EVIDENCE_FILE = os.path.join(MIGRATION_ROOT, 'evidence_refs.jsonl')
CLAIMS_FILE = os.path.join(MIGRATION_ROOT, 'historical_claims.jsonl')
MANIFEST_FILE = os.path.join(MIGRATION_ROOT, 'manifest.json')
CATALOG_FILE = os.path.join(REPO_ROOT, 'factory', 'strategy_catalog.json')

STRAT_RE = re.compile(r'^STRAT-LEG-[0-9a-f]{16}$')
LEG_EVD_RE = re.compile(r'^leg_evd_sha256_([0-9a-f]{64})$')
SRC_EVD_RE = re.compile(r'^EV-LEG-[0-9a-f]{16}$')
BRIDGE_STATES = frozenset(('LEGACY_ONLY','CURRENT_FACTORY_EXACT','BOSS_NUMBER_COLLISION'))
CONFIDENCE = frozenset(('CONFIRMED','LIKELY','UNKNOWN'))
LEGACY_QUALITY = frozenset(('E1_REPORT_FOUND','E2_CONFIG_BOUND','N_A_SUPPORTING_ARTIFACT'))
LINK_STATES = frozenset(('LINKED_SINGLE','AMBIGUOUS','UNRESOLVED'))
STORAGE = frozenset(('TAR_SNAPSHOT','DIRECTORY_SNAPSHOT','TERMINAL_CAS_ARCHIVE'))


class LegacyMigrationRefusal(Exception):
    pass


def _load_json(path):
    try:
        with io.open(path, 'r', encoding='utf-8-sig') as fh:
            return json.load(fh)
    except (OSError, ValueError) as exc:
        raise LegacyMigrationRefusal('cannot read %s: %s' % (path, exc))


def _load_jsonl(path):
    rows = []
    try:
        with io.open(path, 'r', encoding='utf-8-sig') as fh:
            for n, line in enumerate(fh, 1):
                if not line.strip():
                    continue
                try:
                    rows.append(json.loads(line))
                except ValueError as exc:
                    raise LegacyMigrationRefusal('%s:%d invalid JSON: %s' % (path, n, exc))
    except OSError as exc:
        raise LegacyMigrationRefusal('cannot read %s: %s' % (path, exc))
    return rows

def _sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as fh:
        while True:
            b = fh.read(1024 * 1024)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def _safe_relative(value):
    if not isinstance(value, str) or not value:
        return False
    p = value.replace('\\', '/')
    if p.startswith('/') or re.match(r'^[A-Za-z]:', p):
        return False
    return all(part not in ('', '.', '..') for part in p.split('/'))


def _expected_storage(root_id):
    if root_id in ('EA_LAB', 'FOREX'):
        return 'TAR_SNAPSHOT'
    if root_id == 'EA_PROJECT':
        return 'DIRECTORY_SNAPSHOT'
    if root_id.startswith('MT4_') or root_id.startswith('MT5_'):
        return 'TERMINAL_CAS_ARCHIVE'
    return None

def validate_strategy_rows(rows, catalog):
    problems = []
    seen, mapped = set(), {}
    catalog_ids = {r.get('ea_id') for r in catalog if isinstance(r, dict)}
    for i, row in enumerate(rows, 1):
        sid = row.get('strategy_id')
        if row.get('entity') != 'LegacyStrategyRef' or not isinstance(sid, str) or not STRAT_RE.match(sid):
            problems.append('strategy line %d has invalid identity' % i); continue
        if sid in seen:
            problems.append('duplicate strategy_id %s' % sid)
        seen.add(sid)
        state, eid = row.get('bridge_state'), row.get('factory_ea_id')
        if state not in BRIDGE_STATES or row.get('identity_confidence') not in CONFIDENCE:
            problems.append('%s has invalid state/confidence' % sid)
        if row.get('promotion_authority') is not False:
            problems.append('%s grants promotion authority' % sid)
        if state == 'CURRENT_FACTORY_EXACT':
            if eid not in catalog_ids or eid not in {'E%03d' % n for n in range(11, 19)}:
                problems.append('%s maps outside current E011-E018 catalog' % sid)
            elif eid in mapped:
                problems.append('factory identity %s mapped twice' % eid)
            else:
                mapped[eid] = sid
        elif eid is not None:
            problems.append('%s state %s must not carry factory_ea_id' % (sid, state))
    expected = {'E%03d' % n for n in range(11, 19)}
    if set(mapped) != expected:
        problems.append('current Factory bridge must resolve E011-E018 exactly once')
    return problems, seen

def validate_evidence_rows(rows, strategy_ids):
    problems = []
    seen, source_seen = set(), set()
    for i, row in enumerate(rows, 1):
        eid, src, raw = row.get('legacy_evidence_id'), row.get('source_evidence_id'), row.get('raw_sha256')
        m = LEG_EVD_RE.match(eid or '')
        if row.get('entity') != 'LegacyEvidenceRef' or not m or m.group(1) != raw:
            problems.append('evidence line %d has invalid content identity' % i); continue
        if eid in seen or src in source_seen:
            problems.append('duplicate legacy/source evidence identity at line %d' % i)
        seen.add(eid); source_seen.add(src)
        if not SRC_EVD_RE.match(src or ''):
            problems.append('%s has invalid source_evidence_id' % eid)
        if not isinstance(row.get('byte_length'), int) or row.get('byte_length') < 0:
            problems.append('%s has invalid byte_length' % eid)
        if row.get('vault_id') != 'PREMIG_20260823' or not _safe_relative(row.get('relative_path')):
            problems.append('%s has invalid vault path' % eid)
        expected_storage = _expected_storage(row.get('root_id') or '')
        if expected_storage is None or row.get('storage_class') != expected_storage:
            problems.append('%s has invalid root/storage binding' % eid)
        if row.get('storage_class') not in STORAGE or row.get('legacy_quality') not in LEGACY_QUALITY:
            problems.append('%s has invalid storage/quality' % eid)
        if row.get('promotion_authority') is not False:
            problems.append('%s grants promotion authority' % eid)
        ids = row.get('strategy_ids')
        if not isinstance(ids, list) or len(ids) != len(set(ids)) or any(x not in strategy_ids for x in ids):
            problems.append('%s has invalid strategy links' % eid); ids = ids or []
        state = row.get('link_state')
        if state not in LINK_STATES or (state == 'LINKED_SINGLE' and len(ids) != 1) or (state == 'AMBIGUOUS' and len(ids) < 2) or (state == 'UNRESOLVED' and len(ids) != 0):
            problems.append('%s has inconsistent link_state' % eid)
    return problems, source_seen

def validate_claim_rows(rows, strategy_ids):
    problems = []
    seen = set()
    allowed_authority = {'HISTORICAL_NONAUTHORITATIVE','DIRECT_SPEC_EVIDENCE'}
    for i, row in enumerate(rows, 1):
        cid = row.get('claim_id')
        if not isinstance(cid, str) or not cid or cid in seen:
            problems.append('claim line %d has invalid/duplicate claim_id' % i); continue
        seen.add(cid)
        if row.get('authority') not in allowed_authority:
            problems.append('%s has invalid authority' % cid)
        if row.get('promotion_authority') is not False:
            problems.append('%s grants promotion authority' % cid)
        ids = row.get('matched_strategy_ids') or []
        if not isinstance(ids, list) or any(x not in strategy_ids for x in ids):
            problems.append('%s links an unknown legacy strategy' % cid)
    return problems


def validate_manifest(manifest, strategies, evidence, claims, source_seen):
    problems = []
    if manifest.get('schema_version') != 1 or manifest.get('migration_id') != 'M4-20260823':
        problems.append('manifest identity/version is invalid')
    authority = manifest.get('authority') or {}
    expected_authority = {'legacy_strategy_promotion': False, 'legacy_evidence_candidate_eligible': False,
                          'legacy_evidence_e3_allowed': False, 'physical_cleanup_authorized': False}
    if authority != expected_authority:
        problems.append('manifest authority boundary changed')
    expected_cutover = {
        'legacy_sources_status': 'HISTORICAL_GENERATED_ONLY',
        'retired_authorities': ['RUN_LOG.csv','EA_MASTER_INDEX.csv','EA_STRATEGY_GUIDE.md:status_sections',
                                'EA_SCORECARD_AND_REGISTRY.md:registry_status_sections'],
        'strategy_authority': 'factory/strategy_catalog.json',
        'run_authority': 'factory/runs/*.jsonl',
        'evidence_authority': 'docs/memory_control/experiment_events/evidence-manifest.jsonl',
        'legacy_migration_authority': 'factory/legacy_migration/',
        'deployment_authority': 'portfolio/DEPLOYMENTS.csv'}
    if manifest.get('cutover') != expected_cutover:
        problems.append('legacy authority cutover policy changed')
    counts = manifest.get('counts') or {}
    if counts.get('strategy_refs') != len(strategies) or counts.get('legacy_evidence_refs') != len(evidence) or counts.get('historical_claims') != len(claims):
        problems.append('manifest counts do not match stores')
    reuse = manifest.get('canonical_evidence_reuse') or []
    for r in reuse:
        raw = r.get('raw_sha256')
        if r.get('canonical_evidence_id') != 'evd_sha256_' + str(raw):
            problems.append('canonical evidence reuse identity does not match raw sha256')
        if r.get('source_evidence_id') in source_seen:
            problems.append('source evidence appears in both canonical reuse and legacy store')
    if counts.get('source_evidence_total') != len(evidence) + len(reuse):
        problems.append('source evidence coverage count is incomplete')
    return problems

def validate_artifact_hashes(manifest):
    problems = []
    files = manifest.get('artifact_sha256') or {}
    expected = {
        'strategy_bridge.jsonl': STRATEGY_FILE,
        'evidence_refs.jsonl': EVIDENCE_FILE,
        'historical_claims.jsonl': CLAIMS_FILE,
    }
    if set(files) != set(expected):
        return ['manifest artifact_sha256 keys are incomplete or unexpected']
    for name, path in expected.items():
        try:
            got = _sha256_file(path)
        except OSError as exc:
            problems.append('cannot hash %s: %s' % (name, exc)); continue
        if files.get(name) != got:
            problems.append('%s sha256 does not match manifest' % name)
    return problems


def validate_all():
    strategies = _load_jsonl(STRATEGY_FILE)
    evidence = _load_jsonl(EVIDENCE_FILE)
    claims = _load_jsonl(CLAIMS_FILE)
    manifest = _load_json(MANIFEST_FILE)
    catalog = _load_json(CATALOG_FILE)
    problems, strategy_ids = validate_strategy_rows(strategies, catalog)
    p2, source_seen = validate_evidence_rows(evidence, strategy_ids)
    problems.extend(p2)
    problems.extend(validate_claim_rows(claims, strategy_ids))
    problems.extend(validate_manifest(manifest, strategies, evidence, claims, source_seen))
    problems.extend(validate_artifact_hashes(manifest))
    summary = {'strategy_refs': len(strategies), 'legacy_evidence_refs': len(evidence),
               'historical_claims': len(claims),
               'canonical_evidence_reuse': len(manifest.get('canonical_evidence_reuse') or []),
               'problems': len(problems)}
    return problems, summary


def main():
    try:
        problems, summary = validate_all()
    except LegacyMigrationRefusal as exc:
        print('M4 LEGACY MIGRATION TOOL FAILURE: %s' % exc)
        return 2
    print(json.dumps(summary, sort_keys=True))
    if problems:
        for p in problems[:50]:
            print('FAIL: %s' % p)
        if len(problems) > 50:
            print('... %d more problem(s)' % (len(problems) - 50))
        return 1
    print('M4 LEGACY MIGRATION: PASS / NON-PROMOTABLE')
    return 0


if __name__ == '__main__':
    sys.exit(main())