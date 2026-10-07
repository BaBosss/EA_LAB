"""Offline typed inventory and synthetic selection; no feed or policy operations."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sys
from dataclasses import asdict, dataclass
from datetime import date, datetime
from pathlib import Path
from typing import Any, Literal

ROOT = Path(__file__).resolve().parents[2]
# The accepted embeddable interpreter omits CWD from its module search path.
# Bind this standalone entry point to its own repository, without changing PATH.
sys.path.insert(0, str(ROOT))
from tools.knowledge_validation.offline_replay_validator import (
    parse_utc, qualify_replay_package, stable_hash,
)
from tools.P4BMarketDataExporter.normalize_ohlc import server_to_utc

SCHEMA = 'ea_lab_news_macro_context_request/1'
SYMBOL_METADATA = {
    'USD': {'kind': 'CURRENCY', 'base': 'USD', 'quote': None, 'countries': ['US'], 'support': 'TYPED_INVENTORY'},
    'JPY': {'kind': 'CURRENCY', 'base': 'JPY', 'quote': None, 'countries': ['JP'], 'support': 'TYPED_INVENTORY'},
    'USDJPY': {'kind': 'FX_PAIR', 'base': 'USD', 'quote': 'JPY', 'countries': ['US', 'JP'], 'support': 'TYPED_INVENTORY'},
    'XAUUSD': {'kind': 'METAL_QUOTED_IN_CURRENCY', 'base': 'XAU', 'quote': 'USD', 'countries': [], 'support': 'NOTSUPPORTED'},
    'BTCUSD': {'kind': 'CRYPTO_QUOTED_IN_CURRENCY', 'base': 'BTC', 'quote': 'USD', 'countries': [], 'support': 'NOTSUPPORTED'},
    'EURGBP': {'kind': 'FX_PAIR', 'base': 'EUR', 'quote': 'GBP', 'countries': [], 'support': 'NOTSUPPORTED'},
}
AXES = ('employment', 'inflation', 'policy_rate', 'yield_10y')
LABELS = ('RISK_ON', 'NEUTRAL', 'RISK_OFF', 'STRESS')
ENVELOPE_FIELDS = {'schema_version', 'fixture_only', 'symbol', 'package', 'freshness', 'source_mode', 'broker_binding'}
FORBIDDEN = {'trade_action', 'policy_action', 'close_positions', 'block_new', 'lot_size',
             'trade_signal', 'buy', 'sell', 'policy_choice', 'aggregate_country_score', 'factor_weights'}
PINS = {
    'tools/knowledge_validation/offline_replay_validator.py': 'f0c502b437b77c381e76f8c0c0c6e933b488234250b7482b6b3db60badce62bb',
    'portfolio/HISTORICAL_MACRO_REPLAY_PAYEMS_V1_20260907.json': '84dff5e92025c5ffb491c7d7507e96b60bfe3ce6db820b25e0519a20c06ca455',
    'docs/research/HISTORICAL_MACRO_REPLAY_SOURCE_CONTRACT_20260907.md': '21fc68f03954eb11cd2d6b92e040f70e8671f5a700a15c12f86cdfe237922850',
    'docs/research/HISTORICAL_BROKER_CLOCK_CONTRACT_20260907.md': 'ce472070a96b970ea280aa672988bc8c05207b9ded9234c86b08e49703737a37',
    'tools/P4BMarketDataExporter/normalize_ohlc.py': 'cad32322e70fed379dc1ee8e19755d8256b29828fd4ccc3ea022fde19b1a34dd',
    'tools/news_macro_lab/core.py': '9f6a361a9945bd3f82bec9c1937236c8e4c707477a2c55e8313795f3d678b18c',
    'scripts/mris/README.md': '3290973419b7037e0f369e38a8ea7422b084ca923212b7a1612c5cc1ebac0f34',
}


def proof_text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip()) and value.strip().upper() not in {'UNKNOWN', 'MISSING', 'UNQUALIFIED'}


@dataclass
class FactorContext:
    country: Literal['US', 'JP']
    currency: Literal['USD', 'JPY']
    factor_id: str
    identity: dict[str, Any]
    state: Literal['UNKNOWN', 'FIXTURE_SELECTED'] = 'UNKNOWN'
    value: float | int | None = None
    unit: str | None = None
    source: dict[str, Any] | None = None
    source_qualification: str = 'UNQUALIFIED'
    revision: dict[str, str] | None = None
    observed_period: dict[str, str] | None = None
    release_clock: dict[str, str] | None = None
    available_at_utc: str | None = None
    fetched_at_utc: str | None = None
    freshness_basis: str = 'UNKNOWN'
    freshness_state: str = 'UNKNOWN'
    coverage: dict[str, Any] | None = None
    reason_codes: list[str] | None = None
    missing_inputs: list[str] | None = None


def forbidden_fields(value: Any) -> set[str]:
    found: set[str] = set()
    if isinstance(value, dict):
        found.update(str(k) for k in value if str(k).lower() in FORBIDDEN)
        for child in value.values():
            found.update(forbidden_fields(child))
    elif isinstance(value, list):
        for child in value:
            found.update(forbidden_fields(child))
    return found


def symbol_metadata(symbol: Any) -> dict[str, Any]:
    # Exact table lookup only: no slicing, suffix stripping or geographic inference.
    if isinstance(symbol, str) and symbol in SYMBOL_METADATA:
        return json.loads(json.dumps(SYMBOL_METADATA[symbol]))
    return {'kind': 'UNKNOWN', 'base': None, 'quote': None, 'countries': [], 'support': 'NOTSUPPORTED'}


def broker_clock(binding: Any, decision: Any) -> dict[str, Any]:
    result = {'state': 'UNKNOWN', 'normalized_utc': None, 'reason': 'MISSING_BROKER_LINEAGE',
              'accepted_server_interval': ['2019-03-01', '2025-12-31']}
    if binding is None:
        return result
    if not isinstance(binding, dict) or set(binding) != {'server_lineage', 'server_time', 'mapping_version'}:
        result['reason'] = 'INVALID_BROKER_BINDING'
        return result
    if (binding['server_lineage'] != 'ThinkMarkets-Live' or
            binding['mapping_version'] != 'THINKMARKETS_LIVE_US_DST_QUARANTINE_V1'):
        result['reason'] = 'UNQUALIFIED_BROKER_LINEAGE'
        return result
    try:
        server = datetime.strptime(binding['server_time'], '%Y.%m.%d %H:%M:%S')
        if not date(2019, 3, 1) <= server.date() <= date(2025, 12, 31):
            result['reason'] = 'OUTSIDE_ACCEPTED_SERVER_INTERVAL'
            return result
        normalized = server_to_utc(binding['server_time'])
        if normalized != parse_utc(decision):
            result['reason'] = 'BROKER_DECISION_MISMATCH'
            return result
    except (ValueError, TypeError) as exc:
        result['reason'] = 'UNKNOWN_DST_TRANSITION' if str(exc) == 'AMBIGUOUS_DST_TRANSITION' else 'INVALID_BROKER_TIME'
        return result
    result.update(state='REFERENCE_MAPPING_ONLY', normalized_utc=normalized.strftime('%Y-%m-%dT%H:%M:%SZ'),
                  reason='ACCEPTED_LINEAGE_DATE_MAPPING_NO_EA_REPLAY')
    return result


def _record_errors(row: Any, package: dict, digest: str) -> list[str]:
    if not isinstance(row, dict):
        return ['INVALID_FACTOR_RECORD']
    if (row.get('country'), row.get('currency'), row.get('factor_id')) != ('US', 'USD', 'employment'):
        return ['INPUT_FOR_UNQUALIFIED_SLOT']
    errors = []
    if not isinstance(row.get('state'), str):
        errors.append('INVALID_RECORD_STATE_TYPE')
    source = row.get('source')
    if not isinstance(source, dict) or any(not proof_text(source.get(k))
                                           for k in ('source_id', 'series_id', 'raw_sha256')):
        errors.append('MISSING_SOURCE_IDENTITY')
    elif source.get('qualification') != 'SYNTHETIC/FIXTURE_ONLY' or source['raw_sha256'] != digest:
        errors.append('SOURCE_PROVENANCE_MISMATCH')
    if any(not proof_text(row.get(k))
           for k in ('source_revision_id', 'vintage_id')):
        errors.append('MISSING_VINTAGE_REVISION_PROOF')
    period = row.get('observed_period')
    try:
        if not isinstance(period, dict) or set(period) != {'start', 'end'}:
            raise ValueError('period')
        if date.fromisoformat(period['start']) > date.fromisoformat(period['end']):
            raise ValueError('period order')
    except (TypeError, ValueError):
        errors.append('MISSING_OBSERVED_PERIOD')
    clock = row.get('release_clock')
    try:
        if not isinstance(clock, dict) or any(not proof_text(clock.get(k))
                                              for k in ('released_at_utc', 'source_timezone', 'mapping_version', 'evidence_id')):
            raise ValueError('clock proof')
        mapping = package.get('clock_mapping')
        if not isinstance(mapping, dict) or clock['mapping_version'] != mapping.get('version') or clock['source_timezone'] != mapping.get('source_timezone'):
            raise ValueError('clock lineage')
        if parse_utc(clock['released_at_utc']) > parse_utc(row.get('available_at_utc')):
            raise ValueError('availability before release')
    except (TypeError, ValueError):
        errors.append('MISSING_OR_INVALID_RELEASE_CLOCK_PROOF')
    # Fetch time is an independent receipt axis. It never determines visibility.
    fetched = row.get('fetched_at_utc')
    if fetched is not None:
        try:
            parse_utc(fetched)
        except (ValueError, TypeError):
            errors.append('INVALID_FETCH_TIME')
    value = row.get('value')
    if isinstance(value, bool) or not isinstance(value, (int, float)) or (isinstance(value, float) and not math.isfinite(value)):
        errors.append('MISSING_OR_INVALID_FACTOR_VALUE')
    if not isinstance(row.get('unit'), str) or not row['unit'].strip():
        errors.append('MISSING_FACTOR_UNIT')
    if row.get('record_type') != 'MACRO_OBSERVATION':
        errors.append('UNSUPPORTED_FACTOR_RECORD_TYPE')
    return errors


def build_context(request: Any, raw_source: bytes | None, *, root: Path = ROOT) -> dict[str, Any]:
    """Retain UNKNOWN inventory; use the canonical selector only for frozen fixtures."""
    slots = []
    for country, currency in (('US', 'USD'), ('JP', 'JPY')):
        for axis in AXES:
            prior = country == 'US' and axis == 'employment'
            slots.append(FactorContext(country, currency, axis,
                {'factor_id': axis, 'source_series_locator': 'PAYEMS' if prior else None,
                 'prior_selector_receipt': 'portfolio/HISTORICAL_MACRO_REPLAY_PAYEMS_V1_20260907.json' if prior else None},
                coverage={'state': 'UNKNOWN'},
                reason_codes=['NO_QUALIFIED_SOURCE_PACKAGE' if country == 'US' else 'JAPAN_SOURCE_PACKAGE_UNQUALIFIED'],
                missing_inputs=['qualified_source_package', 'revision_lineage', 'release_clock', 'availability', 'coverage', 'freshness']))
    result = {
        'schema_version': 'ea_lab_news_macro_context/1', 'context_status': 'PARTIAL',
        'classification': 'SOURCE/OFFLINE_TYPED_INVENTORY', 'evidence_label': 'SYNTHETIC/FIXTURE_ONLY',
        'capabilities': 'PARTIAL', 'historical_dataset_qualified': False, 'ea_replay_qualified': False,
        'populated_country_intelligence_qualified': False, 'automatic_policy_output': None,
        'global_mris_reference': {'owner': 'portfolio/mris/regime_state.json', 'labels': list(LABELS),
                                  'state_computed': False, 'country_aggregation': False},
        'proxy_references': [{'identity': 'US10Y_JP10Y', 'observed_leg': 'US', 'source_symbol': '^TNX',
                              'qualified_japan_series': False, 'country_factor_input': False,
                              'reason': 'EXISTING_US_LEG_CARRY_PROXY_REFERENCE_ONLY'}],
        'symbol_metadata': symbol_metadata(request.get('symbol') if isinstance(request, dict) else None),
        'selection': {'status': 'REFUSED', 'reason_codes': [], 'selected_records': []},
        'broker_clock': {'state': 'UNKNOWN', 'reason': 'NOT_EVALUATED'}, 'reason_codes': [],
    }
    errors = []
    try:
        # Inputs are JSON data, and returned evidence must not alias caller mutations.
        request = json.loads(json.dumps(request, allow_nan=False))
    except (TypeError, ValueError):
        errors.append('INVALID_JSON_DATA')
    if not isinstance(request, dict) or request.get('schema_version') != SCHEMA:
        errors.append('INVALID_REQUEST_SCHEMA')
    else:
        if set(request) != ENVELOPE_FIELDS:
            errors.append('INVALID_REQUEST_FIELDS')
        if request.get('fixture_only') is not True:
            errors.append('REAL_SOURCE_SELECTION_NOT_AUTHORIZED')
        if forbidden_fields(request):
            errors.append('FORBIDDEN_POLICY_OR_AGGREGATION_FIELD')
        for name, expected in PINS.items():
            try:
                if hashlib.sha256((root / name).read_bytes()).hexdigest() != expected:
                    errors.append('SOURCE_PIN_MISMATCH:' + name)
            except OSError:
                errors.append('SOURCE_PIN_MISSING:' + name)
    package = request.get('package') if isinstance(request, dict) else None
    if not isinstance(package, dict):
        errors.append('MISSING_SOURCE_PACKAGE')
    if not errors:
        result['broker_clock'] = broker_clock(request['broker_binding'], package.get('decision_at_utc'))
        if request.get('source_mode') != 'VINTAGE_WITH_RELEASE_CLOCK':
            errors.append('CURRENT_ONLY_NOT_REPLAYABLE')
        if raw_source is None or not isinstance(raw_source, bytes):
            errors.append('MISSING_RAW_SOURCE')
        else:
            digest = hashlib.sha256(raw_source).hexdigest()
            if package.get('source_snapshot_sha256') != digest:
                errors.append('SOURCE_HASH_MISMATCH')

            coverage = package.get('coverage')
            if isinstance(coverage, dict) and not isinstance(coverage.get('state'), str):
                errors.append('INVALID_COVERAGE_STATE_TYPE')

            records = package.get('records')
            if isinstance(records, list):
                for row in records:
                    errors.extend(_record_errors(row, package, digest))
    if errors:
        result['reason_codes'] = sorted(set(errors))
        result['selection']['reason_codes'] = result['reason_codes']
    else:
        # Preserve canonical cancellation, duplicate, coverage and revision semantics.
        selection = qualify_replay_package(package)
        result['selection'] = selection
        result['reason_codes'] = list(selection['reason_codes'])
        us = slots[0]
        us.coverage = package.get('coverage')
        if selection['status'].startswith('QUALIFIED'):
            freshness = request.get('freshness')
            if (not isinstance(freshness, dict) or set(freshness) != {'basis', 'max_age_seconds'} or
                    freshness.get('basis') != 'available_at_utc' or
                    type(freshness.get('max_age_seconds')) is not int or freshness['max_age_seconds'] <= 0):
                us.reason_codes = ['UNKNOWN_FRESHNESS']
                us.missing_inputs = ['explicit_freshness_basis_and_max_age_seconds']
            elif len(selection['selected_records']) != 1:
                us.reason_codes = ['NO_VISIBLE_FACTOR' if not selection['selected_records'] else 'MULTIPLE_OBSERVED_PERIODS_REQUIRE_SEPARATE_CONTRACT']
                us.missing_inputs = ['one_visible_observed_period']
            else:
                row = selection['selected_records'][0]
                us.source = row['source']; us.source_qualification = 'SYNTHETIC/FIXTURE_ONLY'
                us.identity = dict(us.identity, record_id=row['record_id'])
                us.revision = {k: row[k] for k in ('revision_id', 'source_revision_id', 'vintage_id')}
                us.observed_period = row['observed_period']; us.release_clock = row['release_clock']
                us.available_at_utc = row['available_at_utc']; us.fetched_at_utc = row.get('fetched_at_utc')
                us.freshness_basis = freshness['basis']
                age = (parse_utc(package['decision_at_utc']) - parse_utc(row['available_at_utc'])).total_seconds()
                if age > freshness['max_age_seconds']:
                    us.freshness_state = 'STALE'; us.reason_codes = ['STALE_FACTOR_WITHHELD']; us.missing_inputs = []
                elif selection.get('tentative_record_count', 0):
                    us.reason_codes = ['TENTATIVE_COVERAGE_REQUIRES_RESOLUTION']; us.missing_inputs = ['resolved_tentative_coverage']
                else:
                    us.state = 'FIXTURE_SELECTED'; us.value = row['value']; us.unit = row['unit']
                    us.freshness_state = 'FRESH_FIXTURE_ONLY'; us.reason_codes = ['SYNTHETIC_VISIBLE_REVISION_ONLY']; us.missing_inputs = []
        else:
            us.reason_codes = list(selection['reason_codes'])
        if result['symbol_metadata']['support'] == 'NOTSUPPORTED':
            us.state = 'UNKNOWN'; us.value = None; us.unit = None
            us.reason_codes = ['NOTSUPPORTED_SYMBOL']; us.missing_inputs = ['separately_frozen_symbol_extension']
    if errors:
        slots[0].reason_codes = result['reason_codes']
    result['factors'] = [asdict(slot) for slot in slots]
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', required=True, type=Path)
    parser.add_argument('--raw-source', required=True, type=Path)
    args = parser.parse_args()
    try:
        request = json.loads(args.input.read_text(encoding='utf-8'), parse_constant=lambda x: (_ for _ in ()).throw(ValueError(x)))
        result = build_context(request, args.raw_source.read_bytes())
    except (OSError, ValueError) as exc:
        print(json.dumps({'context_status': 'REFUSED', 'reason': 'INVALID_OFFLINE_INPUT', 'detail': str(exc)}))
        return 2
    print(json.dumps(result, sort_keys=True, indent=2, allow_nan=False))
    if any(e in result['reason_codes'] for e in ('INVALID_COVERAGE_STATE_TYPE', 'INVALID_RECORD_STATE_TYPE')):
        return 2
    return 0 if any(slot['state'] == 'FIXTURE_SELECTED' for slot in result['factors']) else 1


if __name__ == '__main__':
    raise SystemExit(main())
