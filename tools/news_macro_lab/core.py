"""Order-free causal data preparation using EA_LAB's existing replay selector.

This module cannot place trades, write terminal files, call providers or launch
MT5. A contact is an interval observation, not an executable guard decision.
Raw-byte integrity and a valid schema do not certify the source's historical
truth, completeness, price licence, forecast provenance or economic usefulness.
"""
from __future__ import annotations

import hashlib
import json
import math
import re
import statistics
import types
from copy import deepcopy
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]  # repository root
SELECTOR = 'tools/knowledge_validation/offline_replay_validator.py'
UTC_RE = re.compile(r'\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,6})?Z')
HEX_RE = re.compile(r'[0-9a-f]{64}')
MACRO_STATES = {'RISK_ON', 'NEUTRAL', 'RISK_OFF', 'STRESS'}


class Refused(ValueError):
    """Stable fail-visible reason code. Not a strategy failure."""


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def stable_hash(value: Any) -> str:
    return sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                            separators=(',', ':'), allow_nan=False).encode('utf-8'))


def parse_json(raw: bytes) -> Any:
    def pairs(items):
        out = {}
        for key, value in items:
            if key in out:
                raise Refused('DUPLICATE_JSON_KEY')
            out[key] = value
        return out
    def bad_constant(_):
        raise Refused('NONFINITE_JSON_NUMBER')
    try:
        return json.loads(raw.decode('utf-8-sig'), object_pairs_hook=pairs,
                          parse_constant=bad_constant)
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise Refused('INVALID_JSON') from exc


def utc(value: Any) -> datetime:
    if not isinstance(value, str) or UTC_RE.fullmatch(value) is None:
        raise Refused('EXPLICIT_UTC_CLOCK_REQUIRED')
    try:
        return datetime.fromisoformat(value[:-1] + '+00:00')
    except ValueError as exc:
        raise Refused('INVALID_UTC_TIME') from exc


def text(value: Any) -> str:
    if not isinstance(value, str) or not value.strip():
        raise Refused('EXPLICIT_IDENTITY_REQUIRED')
    return value


def checksum(value: Any) -> str:
    if not isinstance(value, str) or HEX_RE.fullmatch(value) is None:
        raise Refused('EXACT_SHA256_REQUIRED')
    return value


def finite(value: Any) -> float:
    if type(value) not in (int, float) or not math.isfinite(value):
        raise Refused('FINITE_TYPED_NUMBER_REQUIRED')
    return float(value)


def count(value: Any, *, minimum: int = 0) -> int:
    if type(value) is not int or value < minimum:
        raise Refused('EXPLICIT_NONNEGATIVE_INTEGER_REQUIRED')
    return value


def safe_read(path: Path, root: Path, maximum: int = 8_000_000) -> bytes:
    root, path = root.absolute(), path.absolute()
    if '..' in path.parts or not path.is_relative_to(root):
        raise Refused('INPUT_OUTSIDE_ROOT')
    for part in [path, *path.parents]:
        info = part.lstat()
        if part.is_symlink() or getattr(info, 'st_file_attributes', 0) & 0x400:
            raise Refused('REPARSE_INPUT_REFUSED')
        if part == root:
            break
    before = path.stat()
    if not path.is_file() or before.st_size > maximum:
        raise Refused('INPUT_SIZE_OR_TYPE')
    raw = path.read_bytes()
    after = path.stat()
    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        raise Refused('INPUT_CHANGED_DURING_READ')
    return raw


def load_selector(root: Path = ROOT):
    """Compile the verified bytes, preventing a hash-check/import reread race."""
    pins = parse_json(safe_read(root / 'tools/news_macro_lab/dependency_pins.json', root))
    expected = checksum(pins['executed_dependencies'][SELECTOR])
    raw = safe_read(root / SELECTOR, root)
    if sha256(raw) != expected:
        raise Refused('CANONICAL_SELECTOR_CHANGED_REVIEW_REQUIRED')
    module = types.ModuleType('ea_lab_pinned_offline_selector')
    module.__file__ = str(root / SELECTOR)
    exec(compile(raw, module.__file__, 'exec'), module.__dict__)
    return module.qualify_replay_package, expected


def result_base(package: dict, synthetic: bool) -> dict:
    if type(synthetic) is not bool:
        raise Refused('EXPLICIT_SYNTHETIC_FLAG_REQUIRED')
    return {
        'schema_version': 'news_macro_preparation_result/1',
        'classification': 'SYNTHETIC_MECHANICS_ONLY' if synthetic else 'UNQUALIFIED_SOURCE_PREPARATION',
        'input_sha256': stable_hash(package),
        'historical_dataset_qualified': False, 'ea_replay_qualified': False,
        'can_execute': False, 'runtime_effectiveness': 'UNKNOWN',
        'performance': 'NOT_RUN', 'ea_actions': [],
    }


def select_asof(package: dict, source_raw: bytes, decision: str, *,
                synthetic: bool, root: Path = ROOT) -> dict:
    """Delegate record/revision/cancellation selection; never duplicate it."""
    if not isinstance(package, dict):
        raise Refused('PACKAGE_OBJECT_REQUIRED')
    utc(decision)
    if not isinstance(source_raw, bytes) or not source_raw:
        raise Refused('RAW_SOURCE_BYTES_REQUIRED')
    if sha256(source_raw) != checksum(package.get('source_snapshot_sha256')):
        raise Refused('RAW_SOURCE_HASH_MISMATCH')
    records = package.get('records')
    if not isinstance(records, list):
        raise Refused('RECORD_LIST_REQUIRED')
    for record in records:
        if not isinstance(record, dict):
            raise Refused('RECORD_OBJECT_REQUIRED')
        utc(record.get('available_at_utc'))
    p = deepcopy(package)
    p['decision_at_utc'] = decision
    selector, selector_hash = load_selector(root)
    selected = selector(p)
    result = result_base(p, synthetic)
    result.update(selector_sha256=selector_hash, selection=selected,
                  decision_at_utc=decision, status=selected['status'])
    # Caller-provided provenance labels never upgrade the canonical selector scope.
    return result


def news_contact(package: dict, source_raw: bytes, decision: str, *,
                 currencies: list[str], importance_levels: list[str],
                 pre_minutes: int, post_minutes: int,
                 synthetic: bool, root: Path = ROOT) -> dict:
    """Observe [event-pre,event+post), using the latest KNOWN schedule version.

    This is NOT parity certification for NewsGuard_Core. There is no automatic
    USD relevance, magic inference, closing, pending cancellation or GV write.
    Relevance and intervals must be explicit inputs to a later frozen contract.
    """
    count(pre_minutes); count(post_minutes)
    if pre_minutes + post_minutes == 0:
        raise Refused('EMPTY_CONTACT_WINDOW')
    if (not isinstance(currencies, list) or not currencies or
        any(not isinstance(c, str) or re.fullmatch('[A-Z]{3}', c) is None for c in currencies) or
        len(set(currencies)) != len(currencies)):
        raise Refused('EXPLICIT_UNIQUE_CURRENCIES_REQUIRED')
    allowed_importance = {'High', 'Medium', 'Low'}
    if (not isinstance(importance_levels, list) or not importance_levels or
        any(i not in allowed_importance for i in importance_levels) or
        len(set(importance_levels)) != len(importance_levels)):
        raise Refused('EXPLICIT_UNIQUE_IMPORTANCE_LEVELS_REQUIRED')
    result = select_asof(package, source_raw, decision, synthetic=synthetic, root=root)
    result.update(contact_status='UNKNOWN', contact_event_ids=[],
                  contact_window={'pre_minutes': pre_minutes, 'post_minutes': post_minutes,
                                  'boundary': 'LEFT_CLOSED_RIGHT_OPEN'},
                  contact_filter={'currencies': list(currencies),
                                  'importance_levels': list(importance_levels)},
                  policy_parity='NOT_CERTIFIED')
    selection = result['selection']
    if selection['status'] == 'REFUSED':
        return result
    now = utc(decision)
    contacts = []
    for row in selection['selected_records']:
        if row.get('record_type') != 'CALENDAR_EVENT':
            raise Refused('NEWS_REQUIRES_SCHEDULE_ONLY_RECORDS')
        # Actual/surprise/stance belong to separately timestamped payload streams.
        fields = {'record_id', 'revision_id', 'record_type', 'state', 'available_at_utc',
                  'scheduled_at_utc', 'currency', 'importance'}
        if set(row) != fields or row['importance'] not in ('High', 'Medium', 'Low'):
            raise Refused('CALENDAR_SCHEMA_OR_PAYLOAD_LEAK')
        if not isinstance(row['currency'], str) or re.fullmatch('[A-Z]{3}', row['currency']) is None:
            raise Refused('INVALID_EVENT_CURRENCY')
        event = utc(row['scheduled_at_utc'])
        try:
            start, end = event - timedelta(minutes=pre_minutes), event + timedelta(minutes=post_minutes)
        except OverflowError as exc:
            raise Refused('WINDOW_OVERFLOW') from exc
        if (row['currency'] in currencies and row['importance'] in importance_levels
                and start <= now < end):
            contacts.append(row['record_id'])
    result['contact_event_ids'] = sorted(contacts)
    # Canonical selector omits tentative rows; aggregate tentative coverage cannot
    # be falsely translated to an all-clear for a downstream asset.
    if selection.get('tentative_record_count', 0):
        result['contact_reason'] = 'TENTATIVE_COVERAGE_REQUIRES_RESOLUTION'
    else:
        result['contact_status'] = 'CONTACT' if contacts else 'NO_CONTACT'
        result['contact_reason'] = 'KNOWN_SCHEDULE_AT_DECISION'
    return result


def macro_context(package: dict, source_raw: bytes, decision: str, *,
                  series_id: str, classifier_sha256: str,
                  max_source_age_seconds: int, synthetic: bool, root: Path = ROOT) -> dict:
    """Read an immutable as-of regime. No classifier, new threshold or policy."""
    text(series_id); checksum(classifier_sha256); count(max_source_age_seconds, minimum=1)
    result = select_asof(package, source_raw, decision, synthetic=synthetic, root=root)
    result.update(macro_state='UNKNOWN', context_reason='NO_VISIBLE_REGIME')
    if result['selection']['status'] == 'REFUSED':
        return result
    now, eligible = utc(decision), []
    for row in result['selection']['selected_records']:
        if row.get('record_type') != 'REGIME_OBSERVATION' or row.get('series_id') != series_id:
            continue
        if row.get('classifier_sha256') != classifier_sha256:
            raise Refused('CLASSIFIER_LINEAGE_MISMATCH')
        if row.get('regime_state') not in MACRO_STATES:
            raise Refused('UNKNOWN_REGIME_VOCABULARY')
        effective, observed, expires, available = map(utc, [row.get('effective_at_utc'),
            row.get('source_observed_at_utc'), row.get('valid_until_utc'), row['available_at_utc']])
        if observed > available or effective >= expires or observed > effective:
            raise Refused('REGIME_CLOCK_ORDER_INVALID')
        if effective <= now:
            eligible.append((effective, available, row, observed, expires))
    if not eligible:
        return result
    eligible.sort(key=lambda x: (x[0], x[1]))
    key = eligible[-1][:2]
    if sum(x[:2] == key for x in eligible) != 1:
        raise Refused('AMBIGUOUS_REGIME_AT_DECISION')
    effective, available, row, observed, expires = eligible[-1]
    if now >= expires or (now - observed).total_seconds() > max_source_age_seconds:
        result['context_reason'] = 'STALE_REGIME_WITHHELD'
        return result
    if result['selection'].get('tentative_record_count', 0):
        result['context_reason'] = 'TENTATIVE_COVERAGE_REQUIRES_RESOLUTION'
        return result
    result.update(macro_state=row['regime_state'], context_reason='VISIBLE_INPUT_REGIME_ONLY',
                  record_id=row['record_id'], classifier_sha256=classifier_sha256,
                  probability=None, probability_basis='NOT_A_CALIBRATED_PROBABILITY')
    return result


def price_features(package: dict, source_raw: bytes, decision: str, *, instrument: str,
                   currency: str, price_basis: str, closes: int,
                   max_source_age_seconds: int, synthetic: bool, root: Path = ROOT) -> dict:
    """Descriptive closed-price features; no universal ADX/ATR/regime floor."""
    text(instrument); text(currency); text(price_basis); count(closes, minimum=2)
    count(max_source_age_seconds, minimum=1)
    result = select_asof(package, source_raw, decision, synthetic=synthetic, root=root)
    result.update(feature_state='UNKNOWN', features=None, regime='UNKNOWN')
    if result['selection']['status'] == 'REFUSED':
        return result
    now, points = utc(decision), {}
    for row in result['selection']['selected_records']:
        if row.get('record_type') != 'DAILY_CLOSE' or row.get('instrument') != instrument:
            continue
        if row.get('currency') != currency or row.get('price_basis') != price_basis:
            raise Refused('PRICE_CURRENCY_OR_BASIS_MISMATCH')
        closed, available = utc(row.get('effective_at_utc')), utc(row['available_at_utc'])
        if available < closed:
            raise Refused('CLOSE_AVAILABLE_BEFORE_CLOSE')
        if closed > now:
            continue
        value = finite(row.get('value'))
        if value <= 0:
            raise Refused('NONPOSITIVE_PRICE_NOT_SUPPORTED')
        if closed in points:
            raise Refused('DUPLICATE_CLOSE_IDENTITY')
        points[closed] = value
    ordered = sorted(points.items())
    if len(ordered) < closes:
        result['feature_reason'] = 'INSUFFICIENT_VISIBLE_CLOSES'
        return result
    if (now - ordered[-1][0]).total_seconds() > max_source_age_seconds:
        result['feature_reason'] = 'STALE_CLOSES'
        return result
    window = ordered[-closes:]
    prices = [x[1] for x in window]
    returns = [math.log(b) - math.log(a) for a, b in zip(prices, prices[1:])]
    mean = statistics.mean(prices)
    try:
        finite(prices[-1] / mean - 1)
        finite(prices[-1] / prices[0] - 1)
    except (OverflowError, ZeroDivisionError, Refused) as exc:
        raise Refused('DERIVED_FEATURE_NOT_FINITE') from exc
    result.update(feature_state='DESCRIPTIVE_ONLY', instrument=instrument, currency=currency,
                  price_basis=price_basis, feature_reason='CAUSAL_VISIBLE_CLOSES',
                  features={'close_count': closes, 'price_vs_mean': prices[-1] / mean - 1,
                            'window_return': prices[-1] / prices[0] - 1,
                            'log_return_sample_std': statistics.stdev(returns) if len(returns) > 1 else None,
                            'first_close_utc': window[0][0].isoformat(),
                            'last_close_utc': window[-1][0].isoformat(),
                            'annualization': 'NONE', 'regime_thresholds': 'NOT_DEFINED'})
    return result
