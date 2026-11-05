#!/usr/bin/env python3
"""
W5 Build6230 Option B: Engineering Observability Canonicalization & Verification Engine V3.0
RFC 8785 (JCS) Compliant Implementation:
- Preserves Unicode strings without normalization (Q01).
- Strict ECMAScript 6 / IEEE 754 number serialization (no NaN/Inf, -0 -> 0) (Q01).
- UTF-16 code unit key sorting for non-BMP surrogate ordering (Q01).
- Exhaustive Draft-07 Schema Invariant Validator (Q02).
- Persistent Replay Ledger with atomic file sync (Q04).
- Domain-separated digests and event chain integrity.
"""

import hashlib
from contextlib import contextmanager
import time
import json
import math
import os
import re
import tempfile
from typing import Any, Dict, List, Optional, Set, Tuple

# Domain prefixes
STAGE_DOMAIN = "W5_STAGE_SIGNING_DOMAIN_V3:"
ACTION_DOMAIN = "W5_ACTION_SIGNING_DOMAIN_V3:"
EVENT_DOMAIN = "W5_EVENT_SIGNING_DOMAIN_V3:"

# Error codes
ERR_INVALID_SIGNATURE = "ERR_INVALID_SIGNATURE"
ERR_REPLAY_NONCE_COLLISION = "ERR_REPLAY_NONCE_COLLISION"
ERR_REPLAY_LEDGER_CORRUPTED = "ERR_REPLAY_LEDGER_CORRUPTED"
ERR_PROCESS_IDENTITY_MISMATCH = "ERR_PROCESS_IDENTITY_MISMATCH"
ERR_STAGE_CHAIN_ORDER = "ERR_STAGE_CHAIN_ORDER"
ERR_PATH_CENSUS_MISMATCH = "ERR_PATH_CENSUS_MISMATCH"
ERR_UNVERIFIED_AUTHORITATIVE_CUSTODY_CLAIM = "ERR_UNVERIFIED_AUTHORITATIVE_CUSTODY_CLAIM"
ERR_SYMBOL_SCOPE_MISMATCH = "ERR_SYMBOL_SCOPE_MISMATCH"
ERR_COVERAGE_GAP_DETECTED = "ERR_COVERAGE_GAP_DETECTED"
ERR_UNPAIRED_READ_RETURN = "ERR_UNPAIRED_READ_RETURN"
ERR_COMMISSION_ZERO_COERCION = "ERR_COMMISSION_ZERO_COERCION"
ERR_RAW_BUNDLE_INCOMPLETE = "ERR_RAW_BUNDLE_INCOMPLETE"
ERR_LEGACY_IDENTITY_MISMATCH = "ERR_LEGACY_IDENTITY_MISMATCH"
ERR_EVENT_CHAIN_BROKEN = "ERR_EVENT_CHAIN_BROKEN"
ERR_LEGACY_WAIVER_PROHIBITED = "ERR_LEGACY_WAIVER_PROHIBITED"
ERR_EVENT_ID_COLLISION = "ERR_EVENT_ID_COLLISION"
ERR_METADATA_TIME_NOT_DECISION = "ERR_METADATA_TIME_NOT_DECISION"
ERR_MISSING_TIME_DECISION_EDGE = "ERR_MISSING_TIME_DECISION_EDGE"
ERR_RECYCLED_HANDLE_COLLISION = "ERR_RECYCLED_HANDLE_COLLISION"
ERR_STATIC_CALLSITE_OMITTED = "ERR_STATIC_CALLSITE_OMITTED"
ERR_UNVERIFIED_COVERAGE_CLAIM = "ERR_UNVERIFIED_COVERAGE_CLAIM"
ERR_JCS_INVALID_INTEGER_FLOAT = "ERR_JCS_INVALID_INTEGER_FLOAT"
ERR_JCS_KEY_SORT_ORDER = "ERR_JCS_KEY_SORT_ORDER"
ERR_UNPRESERVED_LAST_ERROR = "ERR_UNPRESERVED_LAST_ERROR"
ERR_NATIVE_IDENTITY_SPOOF = "ERR_NATIVE_IDENTITY_SPOOF"
ERR_KEY_REVOKED = "ERR_KEY_REVOKED"
ERR_UNKNOWN_ISSUER = "ERR_UNKNOWN_ISSUER"
ERR_KEY_EXPIRED = "ERR_KEY_EXPIRED"

# Schema validation error codes
ERR_SCHEMA_MISSING_REQUIRED_KEY = "ERR_SCHEMA_MISSING_REQUIRED_KEY"
ERR_SCHEMA_ADDITIONAL_PROPERTY = "ERR_SCHEMA_ADDITIONAL_PROPERTY"
ERR_SCHEMA_TYPE_MISMATCH = "ERR_SCHEMA_TYPE_MISMATCH"
ERR_SCHEMA_INVALID_PATTERN = "ERR_SCHEMA_INVALID_PATTERN"
ERR_SCHEMA_VALUE_OUT_OF_RANGE = "ERR_SCHEMA_VALUE_OUT_OF_RANGE"
ERR_SCHEMA_MISSING_NESTED_KEY = "ERR_SCHEMA_MISSING_NESTED_KEY"
ERR_INVALID_SCHEMA_VERSION = "ERR_INVALID_SCHEMA_VERSION"
ERR_INVALID_LINEAGE_ID = "ERR_INVALID_LINEAGE_ID"
ERR_INVALID_TRUST_DOMAIN = "ERR_INVALID_TRUST_DOMAIN"
ERR_INVALID_EVENT_TYPE = "ERR_INVALID_EVENT_TYPE"
ERR_INVALID_INDICATOR_KIND = "ERR_INVALID_INDICATOR_KIND"
ERR_INVALID_EDGE_TYPE = "ERR_INVALID_EDGE_TYPE"
ERR_INVALID_WITNESS_ENUM = "ERR_INVALID_WITNESS_ENUM"


def utf16_sort_key(s: str) -> bytes:
    """
    Returns UTF-16 Big-Endian bytes for RFC 8785 code unit ordering.
    Non-BMP characters (> 0xFFFF) are ordered by their surrogate pair code units.
    """
    return s.encode("utf-16-be")


def verify_jcs_key_sort(keys: List[str]) -> None:
    """
    Verifies that a list of object keys is strictly sorted according to RFC 8785 UTF-16 code units (F66).
    Rejects improper sorting (e.g., Unicode code-point sorting where non-BMP > BMP).
    """
    sorted_keys = sorted(keys, key=utf16_sort_key)
    if keys != sorted_keys:
        raise ValueError(f"{ERR_JCS_KEY_SORT_ORDER}: Object keys not sorted by UTF-16 code units: {keys} != {sorted_keys}")


def serialize_ecmascript_number(n: Any) -> str:
    """
    Serializes numbers per RFC 8785 Section 3.2.2.3 and ECMA-262 Section 7.1.12.1:
    - NaN and +/-Infinity are forbidden.
    - -0 and -0.0 are serialized as '0'.
    - Integers are serialized without decimal point or exponent.
    - Integers outside safe IEEE-754 double precision (abs(n) > 2^53 - 1)
      are coerced to double precision per ECMAScript 6 rules.
    - Shortest round-trip IEEE 754 double-precision representation.
    """
    if isinstance(n, bool):
        raise TypeError(f"Expected number, got bool: {n}")
    if isinstance(n, int):
        if abs(n) > (2**53 - 1):
            n = float(n)
        else:
            return str(n)
    if isinstance(n, float):
        if math.isnan(n) or math.isinf(n):
            raise ValueError(f"RFC 8785 non-finite number forbidden: {n}")
        if n == 0.0:
            return "0"

        sign = "-" if math.copysign(1.0, n) < 0 else ""
        val = abs(n)

        # In Python 3.1+, repr(float) produces the shortest round-trip representation
        s = repr(val)

        # Extract digits and decimal exponent exp_n (where 10^(exp_n-1) <= val < 10^exp_n)
        if 'e' in s or 'E' in s:
            m, e = re.split(r'[eE]', s)
            exp = int(e)
            if '.' in m:
                int_p, frac_p = m.split('.')
                digits = int_p + frac_p
                exp_n = len(int_p) + exp
            else:
                digits = m
                exp_n = len(m) + exp
        else:
            if '.' in s:
                int_p, frac_p = s.split('.')
                if int_p == '0':
                    stripped_frac = frac_p.lstrip('0')
                    leading_zeros = len(frac_p) - len(stripped_frac)
                    digits = stripped_frac
                    exp_n = -leading_zeros
                else:
                    digits = int_p + frac_p
                    exp_n = len(int_p)
            else:
                digits = s
                exp_n = len(s)

        digits = digits.rstrip('0')
        k = len(digits)

        # ECMA-262 7.1.12.1 ToString rules
        if k <= exp_n <= 21:
            res = digits + ('0' * (exp_n - k))
        elif 0 < exp_n <= 21:
            res = digits[:exp_n] + '.' + digits[exp_n:]
        elif -6 < exp_n <= 0:
            res = '0.' + ('0' * (-exp_n)) + digits
        else:
            exp_sign = '+' if exp_n - 1 >= 0 else '-'
            exp_val = abs(exp_n - 1)
            if k == 1:
                res = f"{digits}e{exp_sign}{exp_val}"
            else:
                res = f"{digits[0]}.{digits[1:]}e{exp_sign}{exp_val}"

        return sign + res
    raise TypeError(f"Expected number, got {type(n)}")


def escape_json_string(s: str) -> str:
    """
    RFC 8785 Section 3.2.2.2: Strings are serialized as given WITHOUT Unicode normalization.
    Characters < 0x20 are escaped as \\u00xx; quotation mark and reverse solidus are escaped.
    """
    chars = []
    for c in s:
        code = ord(c)
        if c == '"':
            chars.append('\\"')
        elif c == '\\':
            chars.append('\\\\')
        elif c == '\b':
            chars.append('\\b')
        elif c == '\f':
            chars.append('\\f')
        elif c == '\n':
            chars.append('\\n')
        elif c == '\r':
            chars.append('\\r')
        elif c == '\t':
            chars.append('\\t')
        elif code < 0x20:
            chars.append(f"\\u{code:04x}")
        else:
            chars.append(c)
    return '"' + "".join(chars) + '"'


def canonicalize_jcs(obj: Any) -> str:
    """
    RFC 8785 JSON Canonicalization Scheme (JCS):
    - Strings serialized unmodified without NFC/NFD coercion (Q01).
    - Keys sorted by UTF-16 code units (Q01).
    - ECMAScript number serialization (Q01).
    - No whitespace outside strings.
    """
    if isinstance(obj, str):
        return escape_json_string(obj)
    elif isinstance(obj, bool):
        return "true" if obj else "false"
    elif obj is None:
        return "null"
    elif isinstance(obj, (int, float)):
        return serialize_ecmascript_number(obj)
    elif isinstance(obj, dict):
        sorted_keys = sorted(obj.keys(), key=utf16_sort_key)
        items = [f"{escape_json_string(k)}:{canonicalize_jcs(obj[k])}" for k in sorted_keys]
        return "{" + ",".join(items) + "}"
    elif isinstance(obj, (list, tuple)):
        items = [canonicalize_jcs(x) for x in obj]
        return "[" + ",".join(items) + "]"
    else:
        raise TypeError(f"Unsupported type for JCS: {type(obj)}")


def compute_digest(obj: Any) -> str:
    """Computes SHA256 hex digest of JCS canonical bytes."""
    can_str = canonicalize_jcs(obj)
    return hashlib.sha256(can_str.encode("utf-8")).hexdigest()


def compute_domain_digest(domain_prefix: str, obj: Any) -> str:
    """Computes SHA256 hex digest with domain separation prefix."""
    can_bytes = canonicalize_jcs(obj).encode("utf-8")
    payload = domain_prefix.encode("utf-8") + can_bytes
    return hashlib.sha256(payload).hexdigest()


class ReplayLedger:
    """
    Atomic Replay Ledger with optional file persistence (Q04).
    Key: (protocol, environment, issuer_id, key_fingerprint, nonce)
    """
    def __init__(self, ledger_file: Optional[str] = None):
        self.ledger_file = ledger_file
        self._seen_nonces: Set[Tuple[str, str, str, str, str]] = set()
        self._uncommitted_nonces: Set[Tuple[str, str, str, str, str]] = set()
        if self.ledger_file and os.path.exists(self.ledger_file):
            self._load()

    def _read_disk_state(self) -> Set[Tuple[str, str, str, str, str]]:
        if not self.ledger_file or not os.path.exists(self.ledger_file):
            return set()
        try:
            with open(self.ledger_file, "r", encoding="utf-8") as f:
                data = json.load(f)
            if not isinstance(data, list):
                raise ValueError("Replay ledger must be a JSON array")
            seen = set()
            for item in data:
                if not isinstance(item, list) or len(item) != 5 or not all(isinstance(v, str) for v in item):
                    raise ValueError("Invalid replay ledger record")
                seen.add(tuple(item))
            return seen
        except Exception as e:
            raise IOError(f"{ERR_REPLAY_LEDGER_CORRUPTED}: Failed to load ledger: {e}") from e

    def _load(self) -> None:
        self._seen_nonces = self._read_disk_state()

    @contextmanager
    def _locked_file(self):
        """One durable lock-file inode per ledger; never delete the lock file."""
        if not self.ledger_file:
            yield
            return
        lock_path = self.ledger_file + ".lock"
        fd = os.open(lock_path, os.O_CREAT | os.O_RDWR, 0o600)
        acquired = False
        try:
            for _ in range(200):
                os.lseek(fd, 0, os.SEEK_SET)
                try:
                    if os.name == "nt":
                        import msvcrt
                        msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)
                    else:
                        import fcntl
                        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    acquired = True
                    break
                except (OSError, BlockingIOError):
                    time.sleep(0.025)
            if not acquired:
                raise IOError(f"{ERR_REPLAY_LEDGER_CORRUPTED}: Replay lock unavailable")
            yield
        finally:
            if acquired:
                os.lseek(fd, 0, os.SEEK_SET)
                if os.name == "nt":
                    import msvcrt
                    msvcrt.locking(fd, msvcrt.LK_UNLCK, 1)
                else:
                    import fcntl
                    fcntl.flock(fd, fcntl.LOCK_UN)
            os.close(fd)

    def check_nonce(self, protocol: str, env: str, issuer: str, key_fp: str, nonce: str) -> None:
        key = (protocol, env, issuer, key_fp, nonce)
        if key in self._seen_nonces or key in self._uncommitted_nonces:
            raise ValueError(ERR_REPLAY_NONCE_COLLISION)

    def stage_nonce(self, protocol: str, env: str, issuer: str, key_fp: str, nonce: str) -> None:
        self.check_nonce(protocol, env, issuer, key_fp, nonce)
        self._uncommitted_nonces.add((protocol, env, issuer, key_fp, nonce))

    def commit(self) -> None:
        pending = set(self._uncommitted_nonces)
        if not pending:
            return
        if not self.ledger_file:
            if pending & self._seen_nonces:
                raise ValueError(ERR_REPLAY_NONCE_COLLISION)
            self._seen_nonces.update(pending)
        else:
            with self._locked_file():
                latest = self._read_disk_state()
                if pending & latest:
                    raise ValueError(ERR_REPLAY_NONCE_COLLISION)
                previous = self._seen_nonces
                self._seen_nonces = latest | pending
                try:
                    self._persist()
                except Exception:
                    self._seen_nonces = previous
                    raise
        self._uncommitted_nonces.difference_update(pending)

    def rollback(self) -> None:
        self._uncommitted_nonces.clear()

    def record_and_verify(self, protocol: str, env: str, issuer: str, key_fp: str, nonce: str) -> None:
        key = (protocol, env, issuer, key_fp, nonce)
        if not self.ledger_file:
            self.check_nonce(protocol, env, issuer, key_fp, nonce)
            self._seen_nonces.add(key)
            return
        with self._locked_file():
            latest = self._read_disk_state()
            if key in latest or key in self._uncommitted_nonces:
                raise ValueError(ERR_REPLAY_NONCE_COLLISION)
            previous = self._seen_nonces
            self._seen_nonces = latest | {key}
            try:
                self._persist()
            except Exception:
                self._seen_nonces = previous
                raise

    def _persist(self) -> None:
        data = [list(k) for k in sorted(self._seen_nonces)]
        dir_name = os.path.dirname(self.ledger_file) or "."
        fd, tmp_path = tempfile.mkstemp(dir=dir_name, prefix="replay_", suffix=".tmp")
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp_path, self.ledger_file)


class HandleLifecycleTracker:
    """
    Tracks MQL handles and generations.
    Detects use of unallocated or recycled handles.
    """
    def __init__(self):
        self._active_handles: Dict[str, int] = {}
        self._released_handles: Set[str] = set()

    def create(self, handle_id: str, generation: int) -> None:
        if handle_id in self._active_handles:
            raise ValueError(ERR_RECYCLED_HANDLE_COLLISION)
        self._active_handles[handle_id] = generation
        self._released_handles.discard(handle_id)

    def release(self, handle_id: str) -> None:
        if handle_id not in self._active_handles:
            raise ValueError(ERR_RECYCLED_HANDLE_COLLISION)
        del self._active_handles[handle_id]
        self._released_handles.add(handle_id)

    def verify_active(self, handle_id: str, expected_gen: int) -> None:
        if handle_id not in self._active_handles:
            raise ValueError(ERR_RECYCLED_HANDLE_COLLISION)
        if self._active_handles[handle_id] != expected_gen:
            raise ValueError(ERR_RECYCLED_HANDLE_COLLISION)


# Narrow, explicit Draft-07 keyword engine for the committed closed ABI.
# Fail closed if the document introduces a keyword we cannot enforce.
_DRAFT07_SUPPORTED = frozenset({
    "$schema", "title", "type", "required", "properties", "items",
    "additionalProperties", "enum", "pattern", "minLength",
    "maxLength", "minimum", "maximum"
})


def _schema_matches_type(value: Any, name: str) -> bool:
    return {
        "null": lambda: value is None,
        "string": lambda: isinstance(value, str),
        "boolean": lambda: type(value) is bool,
        "integer": lambda: type(value) is int,
        "number": lambda: type(value) in (int, float) and (
            not isinstance(value, float) or math.isfinite(value)),
        "object": lambda: isinstance(value, dict),
        "array": lambda: isinstance(value, list),
    }[name]()


def _enforce_draft07_subset(value: Any, schema: Dict[str, Any], loc: str = "$") -> None:
    if not isinstance(schema, dict):
        raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:{loc}:schema_not_object")
    extra = set(schema) - _DRAFT07_SUPPORTED
    if extra:
        raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:{loc}:unsupported_schema_keywords:{sorted(extra)}")
    types = schema.get("type")
    if types is not None:
        type_list = types if isinstance(types, list) else [types]
        supported_types = {"null", "string", "boolean", "integer", "number", "object", "array"}
        if not type_list or any(not isinstance(t, str) or t not in supported_types for t in type_list):
            raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:{loc}:unknown_schema_type")
        if not any(_schema_matches_type(value, t) for t in type_list):
            raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:{loc}")
    if "enum" in schema and value not in schema["enum"]:
        raise ValueError(f"{ERR_SCHEMA_VALUE_OUT_OF_RANGE}:{loc}:enum")
    if isinstance(value, str):
        if "minLength" in schema and len(value) < schema["minLength"]:
            raise ValueError(f"{ERR_SCHEMA_VALUE_OUT_OF_RANGE}:{loc}:minLength")
        if "maxLength" in schema and len(value) > schema["maxLength"]:
            raise ValueError(f"{ERR_SCHEMA_VALUE_OUT_OF_RANGE}:{loc}:maxLength")
        if "pattern" in schema:
            # Draft-07 pattern matches via search; existing ABI adds stricter
            # full-end regex checks in validate_draft07_invariants below.
            try:
                matched = re.search(schema["pattern"], value) is not None
            except re.error as exc:
                raise ValueError(f"{ERR_SCHEMA_INVALID_PATTERN}:{loc}:bad_schema_pattern") from exc
            if not matched:
                raise ValueError(f"{ERR_SCHEMA_INVALID_PATTERN}:{loc}")
    if type(value) in (int, float):
        if "minimum" in schema and value < schema["minimum"]:
            raise ValueError(f"{ERR_SCHEMA_VALUE_OUT_OF_RANGE}:{loc}:minimum")
        if "maximum" in schema and value > schema["maximum"]:
            raise ValueError(f"{ERR_SCHEMA_VALUE_OUT_OF_RANGE}:{loc}:maximum")
    if isinstance(value, dict):
        required = schema.get("required", [])
        props = schema.get("properties", {})
        if not isinstance(required, list) or not isinstance(props, dict):
            raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:{loc}:invalid_schema_object")
        for name in required:
            if name not in value:
                raise ValueError(f"{ERR_SCHEMA_MISSING_REQUIRED_KEY}:{loc}.{name}")
        if schema.get("additionalProperties") is False:
            for name in value:
                if name not in props:
                    raise ValueError(f"{ERR_SCHEMA_ADDITIONAL_PROPERTY}:{loc}.{name}")
        for name, child in value.items():
            if name in props:
                _enforce_draft07_subset(child, props[name], loc + "." + name)
    if isinstance(value, list) and "items" in schema:
        for idx, child in enumerate(value):
            _enforce_draft07_subset(child, schema["items"], f"{loc}[{idx}]")


def _load_v3_schema(path: Optional[str] = None) -> Dict[str, Any]:
    full_path = path if path is not None else os.path.join(os.path.dirname(__file__), "schema_v3.json")
    try:
        with open(full_path, "r", encoding="utf-8") as handle:
            schema = json.load(handle)
        if schema.get("$schema") != "http://json-schema.org/draft-07/schema#":
            raise ValueError("unexpected schema dialect")
        if schema.get("type") != "object" or schema.get("additionalProperties") is not False:
            raise ValueError("schema root must be closed object")
        return schema
    except (OSError, ValueError, TypeError, AttributeError) as exc:
        raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:schema_v3_unavailable_or_invalid:{exc}") from exc


def validate_draft07_invariants(event: Dict[str, Any], schema_path: Optional[str] = None) -> None:
    """
    Exhaustive Draft-07 schema validator for schema_v3.json (Q02):
    Validates required keys, additionalProperties=false, types, enums, regexes, and bounds.
    """
    # 1. Top-level required keys
    REQUIRED_ROOT = [
        "schema_version", "lineage_id", "trust_domain", "event_id", "run_id",
        "stream_id", "emitter_generation", "event_type", "local_counter",
        "recorded_utc", "strategy_bar_time", "call_site", "sensor_payload",
        "causality_link", "assurance_class", "prev_event_digest"
    ]
    for k in REQUIRED_ROOT:
        if k not in event:
            raise ValueError(f"{ERR_SCHEMA_MISSING_REQUIRED_KEY}:{k}")

    # Top-level additionalProperties: false
    ALLOWED_ROOT = set(REQUIRED_ROOT + ["parent_event_id", "parent_event_ids"])
    for k in event:
        if k not in ALLOWED_ROOT:
            raise ValueError(f"{ERR_SCHEMA_ADDITIONAL_PROPERTY}:{k}")

    # 2. Top-level enums and strings
    if event["schema_version"] != "W5_ENG_OBS_V3_0":
        raise ValueError(ERR_INVALID_SCHEMA_VERSION)
    if event["lineage_id"] != "ENGINEERING_ONLY_TRACK_E":
        raise ValueError(ERR_INVALID_LINEAGE_ID)
    if event["trust_domain"] not in ("SYNTHETIC_FIXTURE_TEST_ONLY", "NATIVE_AUTHENTIC_PROD_ONLY"):
        raise ValueError(ERR_INVALID_TRUST_DOMAIN)

    # Patterns
    if not isinstance(event["event_id"], str) or not re.match(r"^[A-Za-z0-9_-]{1,32}:[A-Za-z0-9_-]{1,16}:[0-9]+:[A-Z_]{3,16}:[0-9]+\Z", event["event_id"]):
        raise ValueError(f"{ERR_SCHEMA_INVALID_PATTERN}:event_id")
    if not isinstance(event["run_id"], str) or not re.match(r"^[A-Za-z0-9_-]{1,32}\Z", event["run_id"]):
        raise ValueError(f"{ERR_SCHEMA_INVALID_PATTERN}:run_id")
    if not isinstance(event["stream_id"], str) or not re.match(r"^[A-Za-z0-9_-]{1,16}\Z", event["stream_id"]):
        raise ValueError(f"{ERR_SCHEMA_INVALID_PATTERN}:stream_id")

    # Parent event id(s)
    pid = event.get("parent_event_id")
    if pid is not None and not isinstance(pid, str):
        raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:parent_event_id")

    pids = event.get("parent_event_ids")
    if "parent_event_ids" in event:
        if not isinstance(pids, list):
            raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:parent_event_ids")
        for item in pids:
            if not isinstance(item, str) or not re.match(r"^[A-Za-z0-9_-]{1,32}:[A-Za-z0-9_-]{1,16}:[0-9]+:[A-Z_]{3,16}:[0-9]+\Z", item):
                raise ValueError(f"{ERR_SCHEMA_INVALID_PATTERN}:parent_event_ids")

    # Integers and bounds
    if not isinstance(event["emitter_generation"], int) or isinstance(event["emitter_generation"], bool):
        raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:emitter_generation")
    if event["emitter_generation"] < 0:
        raise ValueError(f"{ERR_SCHEMA_VALUE_OUT_OF_RANGE}:emitter_generation")

    if not isinstance(event["local_counter"], int) or isinstance(event["local_counter"], bool):
        raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:local_counter")
    if event["local_counter"] < 0:
        raise ValueError(f"{ERR_SCHEMA_VALUE_OUT_OF_RANGE}:local_counter")

    # Event types
    ALLOWED_EVENTS = {
        "HANDLE_CREATE", "HANDLE_RELEASE", "SOURCE_HISTORY_DECLARED",
        "READ_REQUEST", "READ_RETURN", "READ_FAILURE", "VALUE_USED",
        "DECISION", "GAP_DETECTED", "RUN_CLOSE"
    }
    if event["event_type"] not in ALLOWED_EVENTS:
        raise ValueError(f"{ERR_INVALID_EVENT_TYPE}:{event['event_type']}")

    # Timestamps (ISO 8601 UTC regex)
    ISO_REGEX = r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.[0-9]+)?Z\Z"
    if not isinstance(event["recorded_utc"], str) or not re.match(ISO_REGEX, event["recorded_utc"]):
        raise ValueError(f"{ERR_SCHEMA_INVALID_PATTERN}:recorded_utc")

    sbt = event["strategy_bar_time"]
    if sbt is not None:
        if not isinstance(sbt, str) or not re.match(ISO_REGEX, sbt):
            raise ValueError(f"{ERR_SCHEMA_INVALID_PATTERN}:strategy_bar_time")

    # prev_event_digest (64 lowercase hex)
    if not isinstance(event["prev_event_digest"], str) or not re.match(r"^[0-9a-f]{64}\Z", event["prev_event_digest"]):
        raise ValueError(f"{ERR_SCHEMA_INVALID_PATTERN}:prev_event_digest")

    # 3. Call site validation
    cs = event["call_site"]
    if not isinstance(cs, dict):
        raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:call_site")
    for req in ("file", "function", "line"):
        if req not in cs:
            raise ValueError(f"{ERR_SCHEMA_MISSING_NESTED_KEY}:call_site.{req}")
    for k in cs:
        if k not in ("file", "function", "line"):
            raise ValueError(f"{ERR_SCHEMA_ADDITIONAL_PROPERTY}:call_site.{k}")
    if not isinstance(cs["file"], str) or not cs["file"]:
        raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:call_site.file")
    if not isinstance(cs["function"], str) or not cs["function"]:
        raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:call_site.function")
    if not isinstance(cs["line"], int) or isinstance(cs["line"], bool) or cs["line"] < 1:
        raise ValueError(f"{ERR_SCHEMA_VALUE_OUT_OF_RANGE}:call_site.line")

    # 4. Sensor payload validation
    sp = event["sensor_payload"]
    if not isinstance(sp, dict):
        raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:sensor_payload")
    REQ_SP = [
        "symbol", "timeframe", "indicator_kind", "period", "handle_id",
        "handle_generation", "buffer_id", "start_pos", "requested_count",
        "returned_count", "raw_value", "error_code"
    ]
    for req in REQ_SP:
        if req not in sp:
            raise ValueError(f"{ERR_SCHEMA_MISSING_NESTED_KEY}:sensor_payload.{req}")
    for k in sp:
        if k not in REQ_SP:
            raise ValueError(f"{ERR_SCHEMA_ADDITIONAL_PROPERTY}:sensor_payload.{k}")

    if not isinstance(sp["symbol"], str) or not sp["symbol"]:
        raise ValueError(f"{ERR_SCHEMA_VALUE_OUT_OF_RANGE}:sensor_payload.symbol")
    if not isinstance(sp["timeframe"], int) or isinstance(sp["timeframe"], bool) or sp["timeframe"] < 0:
        raise ValueError(f"{ERR_SCHEMA_VALUE_OUT_OF_RANGE}:sensor_payload.timeframe")
    if sp["indicator_kind"] not in ("ATR", "SMA", "EMA", "PRICE", "CUSTOM"):
        raise ValueError(f"{ERR_INVALID_INDICATOR_KIND}:{sp['indicator_kind']}")
    if not isinstance(sp["period"], int) or isinstance(sp["period"], bool) or sp["period"] < 1:
        raise ValueError(f"{ERR_SCHEMA_VALUE_OUT_OF_RANGE}:sensor_payload.period")
    if not isinstance(sp["handle_id"], str) or not sp["handle_id"]:
        raise ValueError(f"{ERR_SCHEMA_VALUE_OUT_OF_RANGE}:sensor_payload.handle_id")
    if not isinstance(sp["handle_generation"], int) or isinstance(sp["handle_generation"], bool) or sp["handle_generation"] < 0:
        raise ValueError(f"{ERR_SCHEMA_VALUE_OUT_OF_RANGE}:sensor_payload.handle_generation")
    if not isinstance(sp["buffer_id"], int) or isinstance(sp["buffer_id"], bool) or sp["buffer_id"] < 0:
        raise ValueError(f"{ERR_SCHEMA_VALUE_OUT_OF_RANGE}:sensor_payload.buffer_id")
    if not isinstance(sp["start_pos"], int) or isinstance(sp["start_pos"], bool) or sp["start_pos"] < 0:
        raise ValueError(f"{ERR_SCHEMA_VALUE_OUT_OF_RANGE}:sensor_payload.start_pos")
    if not isinstance(sp["requested_count"], int) or isinstance(sp["requested_count"], bool) or sp["requested_count"] < 1:
        raise ValueError(f"{ERR_SCHEMA_VALUE_OUT_OF_RANGE}:sensor_payload.requested_count")
    if sp["returned_count"] is not None:
        if not isinstance(sp["returned_count"], int) or isinstance(sp["returned_count"], bool) or sp["returned_count"] < 0:
            raise ValueError(f"{ERR_SCHEMA_VALUE_OUT_OF_RANGE}:sensor_payload.returned_count")
    if not isinstance(sp["error_code"], int) or isinstance(sp["error_code"], bool) or sp["error_code"] < 0:
        raise ValueError(f"{ERR_SCHEMA_VALUE_OUT_OF_RANGE}:sensor_payload.error_code")
    raw = sp["raw_value"]
    if raw is not None and (
        isinstance(raw, bool) or not isinstance(raw, (str, int, float)) or
        (isinstance(raw, float) and not math.isfinite(raw))
    ):
        raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:sensor_payload.raw_value")

    # 5. Causality link validation
    cl = event["causality_link"]
    if not isinstance(cl, dict):
        raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:causality_link")
    for req in ("consumed_in_decision", "decision_id", "edge_type"):
        if req not in cl:
            raise ValueError(f"{ERR_SCHEMA_MISSING_NESTED_KEY}:causality_link.{req}")
    for k in cl:
        if k not in ("consumed_in_decision", "decision_id", "edge_type"):
            raise ValueError(f"{ERR_SCHEMA_ADDITIONAL_PROPERTY}:causality_link.{k}")
    if not isinstance(cl["consumed_in_decision"], bool):
        raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:causality_link.consumed_in_decision")
    if cl["decision_id"] is not None and not isinstance(cl["decision_id"], str):
        raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:causality_link.decision_id")
    if cl["edge_type"] not in ("BAR_ASSOCIATION", "DECISION_DEPENDENCY", "OBSERVATION_ONLY", "NONE", "TIME_CONSUMPTION_DECISION"):
        raise ValueError(f"{ERR_INVALID_EDGE_TYPE}:{cl['edge_type']}")

    # 6. Assurance class validation
    ac = event["assurance_class"]
    if not isinstance(ac, dict):
        raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:assurance_class")
    for req in ("trace_internal_closed", "static_scope_instrumented", "actual_api_calls_witnessed"):
        if req not in ac:
            raise ValueError(f"{ERR_SCHEMA_MISSING_NESTED_KEY}:assurance_class.{req}")
    for k in ac:
        if k not in ("trace_internal_closed", "static_scope_instrumented", "actual_api_calls_witnessed"):
            raise ValueError(f"{ERR_SCHEMA_ADDITIONAL_PROPERTY}:assurance_class.{k}")
    if not isinstance(ac["trace_internal_closed"], bool):
        raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:assurance_class.trace_internal_closed")
    if not isinstance(ac["static_scope_instrumented"], bool):
        raise ValueError(f"{ERR_SCHEMA_TYPE_MISMATCH}:assurance_class.static_scope_instrumented")
    if ac["actual_api_calls_witnessed"] not in ("CONFIRMED_EXTERNAL_WITNESS", "UNKNOWN", "NOT_WITNESSED"):
        raise ValueError(f"{ERR_INVALID_WITNESS_ENUM}:{ac['actual_api_calls_witnessed']}")

    # The machine-readable schema is an actually enforced contract, not
    # merely documentation. The manual ABI checks above retain exact v3
    # error codes, then the file enforces all declarative Draft-07 keywords.
    _enforce_draft07_subset(event, _load_v3_schema(schema_path))


class EventChainValidator:
    """
    Validates a sequential chain of Track E engineering observability events.
    """
    def __init__(self, trust_domain: str = "SYNTHETIC_FIXTURE_TEST_ONLY", schema_path: Optional[str] = None):
        self.trust_domain = trust_domain
        self.seen_event_ids: Set[str] = set()
        self.last_digest = "0" * 64
        self.stream_counters: Dict[str, int] = {}
        self.open_requests: Dict[str, Dict[str, Any]] = {}
        self.handle_tracker = HandleLifecycleTracker()
        self.replay_ledger = ReplayLedger()
        self.revoked_keys: Set[str] = set()
        self.schema_path = schema_path

    def revoke_key(self, key_fp: str) -> None:
        self.revoked_keys.add(key_fp)

    def validate_event(
        self,
        event: Dict[str, Any],
        external_witness_present: bool = False,
        time_filter_active: bool = False
    ) -> str:
        # File-backed Draft-07 schema + ABI-specific strict error codes.
        validate_draft07_invariants(event, self.schema_path)

        # Trust domain spoofing check (F68)
        if event["trust_domain"] == "NATIVE_AUTHENTIC_PROD_ONLY" and self.trust_domain == "SYNTHETIC_FIXTURE_TEST_ONLY":
            raise ValueError(ERR_NATIVE_IDENTITY_SPOOF)

        # Event ID syntax & uniqueness (F58)
        eid = event["event_id"]
        m = re.match(r"^([A-Za-z0-9_-]+):([A-Za-z0-9_-]+):([0-9]+):([A-Z_]+):([0-9]+)\Z", eid)
        if not m:
            raise ValueError(ERR_EVENT_ID_COLLISION)
        if eid in self.seen_event_ids:
            raise ValueError(ERR_EVENT_ID_COLLISION)

        run_id, stream_id, gen_str, kind, count_str = m.groups()
        emitter_gen = int(gen_str)
        counter = int(count_str)
        kind_map = {
            "HANDLE_CREATE": "HND_CREATE", "HANDLE_RELEASE": "HND_RELEASE",
            "READ_REQUEST": "READ_REQ", "READ_RETURN": "READ_RET",
            "READ_FAILURE": "READ_FAIL", "VALUE_USED": "VAL_USED",
            "DECISION": "DECISION", "GAP_DETECTED": "GAP_DET",
            "SOURCE_HISTORY_DECLARED": "SRC_HISTORY", "RUN_CLOSE": "RUN_CLOSE",
        }
        if (
            run_id != event["run_id"] or stream_id != event["stream_id"] or
            emitter_gen != event["emitter_generation"] or
            counter != event["local_counter"] or
            kind != kind_map[event["event_type"]]
        ):
            raise ValueError(f"{ERR_EVENT_ID_COLLISION}: event_id contradicts event envelope")

        # Monotonic counter per stream (F13)
        stream_key = f"{run_id}:{stream_id}:{emitter_gen}"
        expected_counter = self.stream_counters.get(stream_key, 1)
        if counter != expected_counter:
            raise ValueError(ERR_EVENT_CHAIN_BROKEN)

        # Digest chain validation (F13)
        if event["prev_event_digest"] != self.last_digest:
            raise ValueError(ERR_EVENT_CHAIN_BROKEN)

        # Coverage claim check (F64)
        assurance = event["assurance_class"]
        if assurance["actual_api_calls_witnessed"] == "CONFIRMED_EXTERNAL_WITNESS" and not external_witness_present:
            raise ValueError(ERR_UNVERIFIED_COVERAGE_CLAIM)

        # Handle lifecycle check (F62)
        ev_type = event["event_type"]
        sensor = event["sensor_payload"]
        hid = sensor["handle_id"]
        hgen = sensor["handle_generation"]

        if ev_type == "HANDLE_CREATE":
            if hid in self.handle_tracker._active_handles:
                raise ValueError(ERR_RECYCLED_HANDLE_COLLISION)
        elif ev_type == "HANDLE_RELEASE":
            if hid not in self.handle_tracker._active_handles:
                raise ValueError(ERR_RECYCLED_HANDLE_COLLISION)
        elif ev_type in ("READ_REQUEST", "READ_RETURN", "READ_FAILURE"):
            self.handle_tracker.verify_active(hid, hgen)

        # Read Request/Return/Failure pairing (F09, F67)
        if ev_type in ("READ_RETURN", "READ_FAILURE"):
            parent = event.get("parent_event_id")
            if not parent or parent not in self.open_requests:
                raise ValueError(ERR_UNPAIRED_READ_RETURN)
            requested = self.open_requests[parent]["sensor_payload"]
            identity_fields = (
                "symbol", "timeframe", "indicator_kind", "period", "handle_id",
                "handle_generation", "buffer_id", "start_pos", "requested_count",
            )
            if any(sensor[k] != requested[k] for k in identity_fields):
                raise ValueError(f"{ERR_UNPAIRED_READ_RETURN}: CopyBuffer context differs from request")
            ret_count = sensor.get("returned_count")
            err_code = sensor.get("error_code")
            if ret_count is not None and ret_count > requested["requested_count"]:
                raise ValueError(f"{ERR_UNPAIRED_READ_RETURN}: returned_count exceeds request")
            if ev_type == "READ_FAILURE" and (ret_count not in (None, 0) or err_code == 0):
                raise ValueError(ERR_UNPRESERVED_LAST_ERROR)
            if ev_type == "READ_RETURN" and (ret_count is None or ret_count <= 0) and err_code == 0:
                raise ValueError(ERR_UNPRESERVED_LAST_ERROR)

        # Time decision check (F60, F61)
        causality = event["causality_link"]
        if ev_type in ("VALUE_USED", "DECISION"):
            if causality.get("consumed_in_decision") and causality.get("edge_type") == "BAR_ASSOCIATION":
                raise ValueError(ERR_METADATA_TIME_NOT_DECISION)
            if ev_type == "DECISION" and time_filter_active and causality.get("edge_type") != "TIME_CONSUMPTION_DECISION":
                raise ValueError(ERR_MISSING_TIME_DECISION_EDGE)

        # Compute next digest
        next_digest = compute_digest(event)

        # --- ALL CHECKS PASSED: COMMIT ATOMIC STATE TRANSITIONS ---
        self.seen_event_ids.add(eid)
        self.stream_counters[stream_key] = expected_counter + 1

        if ev_type == "HANDLE_CREATE":
            self.handle_tracker.create(hid, hgen)
        elif ev_type == "HANDLE_RELEASE":
            self.handle_tracker.release(hid)

        if ev_type == "READ_REQUEST":
            self.open_requests[eid] = event
        elif ev_type in ("READ_RETURN", "READ_FAILURE"):
            parent = event.get("parent_event_id")
            if parent in self.open_requests:
                del self.open_requests[parent]

        self.last_digest = next_digest
        return self.last_digest
