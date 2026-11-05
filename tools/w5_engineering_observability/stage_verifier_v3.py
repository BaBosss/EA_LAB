#!/usr/bin/env python3
"""
W5 Build6230 Option B: Scope C Synthetic 106-Stage Bundle & Custody Verifier V3.0
Implements:
1. Cryptographic Trust Anchor & Signature Verification (Q03)
2. Atomic Stage State Commit & Replay Protection (Q04)
3. Authoritative 106-Path Allowlist & Historical Drift Preservation (Q05)
4. Process Identity Authentication & Broker Scope Checks
"""

import hashlib
import math
import hmac
import json
import re
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Set, Tuple

from canonical_v3 import (
    ReplayLedger,
    canonicalize_jcs,
    compute_domain_digest,
    STAGE_DOMAIN,
    ACTION_DOMAIN,
    ERR_STAGE_CHAIN_ORDER,
    ERR_PROCESS_IDENTITY_MISMATCH,
    ERR_PATH_CENSUS_MISMATCH,
    ERR_UNVERIFIED_AUTHORITATIVE_CUSTODY_CLAIM,
    ERR_COVERAGE_GAP_DETECTED,
    ERR_LEGACY_IDENTITY_MISMATCH,
    ERR_STATIC_CALLSITE_OMITTED,
    ERR_SYMBOL_SCOPE_MISMATCH,
    ERR_COMMISSION_ZERO_COERCION,
    ERR_RAW_BUNDLE_INCOMPLETE,
    ERR_LEGACY_WAIVER_PROHIBITED,
    ERR_NATIVE_IDENTITY_SPOOF,
    ERR_REPLAY_NONCE_COLLISION,
    ERR_INVALID_SIGNATURE,
    ERR_KEY_REVOKED,
    ERR_UNKNOWN_ISSUER,
    ERR_KEY_EXPIRED,
)

STAGE_SEQUENCE = ["S0", "PREPROBE", "S1", "EXECUTION", "S2", "POSTPROBE", "S3"]

# Census Assurance Level (RQA-02)
# Authoritative original custody manifest is unadmitted. Offline census is synthetic-only.
CENSUS_ASSURANCE_LEVEL = "SYNTHETIC_106_CENSUS_ONLY"

# The 3 canonical historical failure paths in Track L Build6230
HISTORICAL_3_DRIFT_PATHS = {
    "history/XAUUSD/2026.hcc",
    "history/XAUUSD/cache/Daily.hc",
    "symbols/selected-146237.dat",
}

# Synthetic Pinned 106 Census Relative Paths (Q05, RQA-02)
SYNTHETIC_106_PATHS = set(HISTORICAL_3_DRIFT_PATHS)
# Populate the remaining 103 synthetic paths deterministically
for _cat in ("bases", "ticks", "config", "experts", "logs", "terminal", "reports"):
    for _i in range(1, 16):
        if len(SYNTHETIC_106_PATHS) < 106:
            SYNTHETIC_106_PATHS.add(f"{_cat}/path_component_{_i:03d}.dat")

# Deprecation alias for backward compatibility
CANONICAL_106_PATHS = SYNTHETIC_106_PATHS


@dataclass
class TrustAnchorKey:
    issuer_id: str
    key_fingerprint: str
    key_bytes: bytes
    valid_from: str
    valid_to: str
    revoked: bool = False


def _assert_key_valid_at_verifier_utc(
    key: TrustAnchorKey, current_time_iso: Optional[str] = None
) -> None:
    """Fail closed: payload timestamps and caller overrides cannot renew keys.

    This offline verifier trusts only its runtime UTC clock, not a stage/action
    recorded time. Trusted archival time requires separately admitted custody.
    """
    if current_time_iso is not None:
        raise ValueError(f"{ERR_KEY_EXPIRED}: untrusted time override not admitted")
    now = datetime.now(timezone.utc)
    try:
        def parse_bound(value: str) -> datetime:
            if not isinstance(value, str) or not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z", value):
                raise ValueError("invalid UTC time format")
            return datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
        start = parse_bound(key.valid_from)
        end = parse_bound(key.valid_to)
        if start > end or not (start <= now <= end):
            raise ValueError("outside trust anchor validity window")
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{ERR_KEY_EXPIRED}: {exc}") from exc


class TrustAnchorRegistry:
    """
    Cryptographic Trust Anchor Registry for authenticating stage signatures (Q03).
    """
    def __init__(self):
        self._keys: Dict[str, TrustAnchorKey] = {}

    def register_key(
        self,
        issuer_id: str,
        key_fingerprint: str,
        key_bytes: bytes,
        valid_from: str = "2026-01-01T00:00:00Z",
        valid_to: str = "2027-01-01T00:00:00Z",
        revoked: bool = False
    ) -> None:
        self._keys[key_fingerprint] = TrustAnchorKey(
            issuer_id=issuer_id,
            key_fingerprint=key_fingerprint,
            key_bytes=key_bytes,
            valid_from=valid_from,
            valid_to=valid_to,
            revoked=revoked
        )

    def revoke_key(self, key_fingerprint: str) -> None:
        if key_fingerprint in self._keys:
            self._keys[key_fingerprint].revoked = True

    def is_registered(self, key_fingerprint: str) -> bool:
        return key_fingerprint in self._keys

    def sign_stage(self, key_fingerprint: str, stage_data: Dict[str, Any]) -> str:
        if key_fingerprint not in self._keys:
            raise ValueError(ERR_UNKNOWN_ISSUER)
        k = self._keys[key_fingerprint]
        if k.revoked:
            raise ValueError(ERR_KEY_REVOKED)
        _assert_key_valid_at_verifier_utc(k)
        can_bytes = canonicalize_jcs(stage_data).encode("utf-8")
        payload = STAGE_DOMAIN.encode("utf-8") + can_bytes
        return hmac.new(k.key_bytes, payload, hashlib.sha256).hexdigest()

    def sign_action(self, key_fingerprint: str, action_data: Dict[str, Any]) -> str:
        """Sign a synthetic offline action in a domain distinct from stage."""
        if key_fingerprint not in self._keys:
            raise ValueError(ERR_UNKNOWN_ISSUER)
        k = self._keys[key_fingerprint]
        if (action_data.get("issuer_id") != k.issuer_id or
                action_data.get("key_fingerprint") != key_fingerprint):
            raise ValueError(ERR_UNKNOWN_ISSUER)
        if k.revoked:
            raise ValueError(ERR_KEY_REVOKED)
        _assert_key_valid_at_verifier_utc(k)
        payload = ACTION_DOMAIN.encode("utf-8") + canonicalize_jcs(action_data).encode("utf-8")
        return hmac.new(k.key_bytes, payload, hashlib.sha256).hexdigest()

    def verify_action_signature(
        self, key_fingerprint: str, action_data: Dict[str, Any],
        signature_hex: str, current_time_iso: Optional[str] = None
    ) -> None:
        """Strict synthetic action verification; never a broker or OS witness."""
        if key_fingerprint not in self._keys:
            raise ValueError(ERR_UNKNOWN_ISSUER)
        k = self._keys[key_fingerprint]
        if (action_data.get("issuer_id") != k.issuer_id or
                action_data.get("key_fingerprint") != key_fingerprint):
            raise ValueError(ERR_UNKNOWN_ISSUER)
        if k.revoked:
            raise ValueError(ERR_KEY_REVOKED)
        # recorded_utc in action_data is signer-controlled, not a trusted clock.
        _assert_key_valid_at_verifier_utc(k, current_time_iso)
        payload = ACTION_DOMAIN.encode("utf-8") + canonicalize_jcs(action_data).encode("utf-8")
        expected = hmac.new(k.key_bytes, payload, hashlib.sha256).hexdigest()
        if not isinstance(signature_hex, str) or not hmac.compare_digest(expected, signature_hex):
            raise ValueError(ERR_INVALID_SIGNATURE)

    def verify_stage_signature(
        self,
        key_fingerprint: str,
        stage_data: Dict[str, Any],
        signature_hex: str,
        current_time_iso: Optional[str] = None
    ) -> None:
        if key_fingerprint not in self._keys:
            raise ValueError(ERR_UNKNOWN_ISSUER)
        k = self._keys[key_fingerprint]
        if stage_data.get("issuer_id") != k.issuer_id or stage_data.get("key_fingerprint") != key_fingerprint:
            raise ValueError(f"{ERR_UNKNOWN_ISSUER}: Stage issuer/key identity not registered to signer")
        if k.revoked:
            raise ValueError(ERR_KEY_REVOKED)

        # Stage recorded_utc/strategy_bar_time are untrusted claims; neither
        # can override the verifier's UTC clock or resurrect an expired key.
        _assert_key_valid_at_verifier_utc(k, current_time_iso)

        can_bytes = canonicalize_jcs(stage_data).encode("utf-8")
        payload = STAGE_DOMAIN.encode("utf-8") + can_bytes
        expected_sig = hmac.new(k.key_bytes, payload, hashlib.sha256).hexdigest()

        if not hmac.compare_digest(expected_sig, signature_hex):
            raise ValueError(ERR_INVALID_SIGNATURE)


class StageBundleVerifier:
    """
    Audits multi-stage custody bundles, cryptographic signatures, and 106-path manifests.
    """
    def __init__(
        self,
        trust_domain: str = "SYNTHETIC_FIXTURE_TEST_ONLY",
        expected_symbol: str = "XAUUSD",
        replay_ledger_file: Optional[str] = None,
        require_signatures: Optional[bool] = None
    ):
        self.trust_domain = trust_domain
        self.expected_symbol = expected_symbol
        self.replay_ledger = ReplayLedger(replay_ledger_file)
        self.trust_registry = TrustAnchorRegistry()
        if require_signatures is None:
            self.require_signatures = (trust_domain != "SYNTHETIC_FIXTURE_TEST_ONLY")
        else:
            self.require_signatures = require_signatures
        self.current_stage_idx = -1
        self.last_stage_digest = "0" * 64
        self.known_pids: Dict[int, str] = {}  # pid -> birth_timestamp

    def register_trusted_key(
        self,
        issuer_id: str,
        key_fp: str,
        secret: bytes,
        valid_from: str = "2026-01-01T00:00:00Z",
        valid_to: str = "2027-01-01T00:00:00Z",
        revoked: bool = False
    ) -> None:
        self.trust_registry.register_key(issuer_id, key_fp, secret, valid_from, valid_to, revoked)

    def verify_stage_envelope(self, stage_envelope: Dict[str, Any]) -> str:
        """
        Atomic stage verification (Q04):
        Verifies sequence, signature (Q03), replay nonce, process identity, and digest chain
        BEFORE mutating state or committing nonce.
        """
        stage_data = stage_envelope.get("stage_data", stage_envelope)
        signature = stage_envelope.get("signature_hex")

        stage_name = stage_data.get("stage_name")
        if stage_name not in STAGE_SEQUENCE:
            raise ValueError(f"{ERR_STAGE_CHAIN_ORDER}: Unknown stage {stage_name}")

        idx = STAGE_SEQUENCE.index(stage_name)
        if idx != self.current_stage_idx + 1:
            raise ValueError(f"{ERR_STAGE_CHAIN_ORDER}: Out of sequence transition {stage_name}")

        # Check nonce in replay ledger (read-only preflight check)
        nonce = stage_data.get("nonce")
        if not nonce or not isinstance(nonce, str) or not nonce.strip():
            raise ValueError(f"{ERR_REPLAY_NONCE_COLLISION}: Missing or empty stage nonce")

        issuer = stage_data.get("issuer_id")
        key_fp = stage_data.get("key_fingerprint")

        if self.require_signatures:
            if not issuer or not isinstance(issuer, str) or not issuer.strip():
                raise ValueError(f"{ERR_UNKNOWN_ISSUER}: Missing issuer_id in signed stage")
            if not key_fp or not isinstance(key_fp, str) or not key_fp.strip():
                raise ValueError(f"{ERR_UNKNOWN_ISSUER}: Missing key_fingerprint in signed stage")
        else:
            if self.trust_domain != "SYNTHETIC_FIXTURE_TEST_ONLY":
                raise ValueError(f"{ERR_INVALID_SIGNATURE}: Unsigned stage forbidden under non-synthetic trust domain: {self.trust_domain}")
            issuer = issuer or "ISSUER_DEV"
            key_fp = key_fp or "KEY_DEV"

        self.replay_ledger.check_nonce("V3_0", self.trust_domain, issuer, key_fp, nonce)

        # Process identity check (PID + birth timestamp) (F04)
        proc = stage_data.get("process_identity")
        pid = None
        birth = None
        if proc and isinstance(proc, dict):
            pid = proc.get("pid")
            birth = proc.get("birth_timestamp")
            if pid is not None:
                if not birth or not isinstance(birth, str) or not birth.strip():
                    raise ValueError(f"{ERR_PROCESS_IDENTITY_MISMATCH}: PID {pid} missing valid birth_timestamp")
                if pid in self.known_pids and self.known_pids[pid] != birth:
                    raise ValueError(f"{ERR_PROCESS_IDENTITY_MISMATCH}: PID {pid} reused with different birth timestamp")

        # Cryptographic signature verification (Q03, RQA-03)
        if self.require_signatures:
            if not signature or not isinstance(signature, str) or not signature.strip():
                raise ValueError(f"{ERR_INVALID_SIGNATURE}: Missing or empty signature in signed-stage mode")
            if not key_fp or not self.trust_registry.is_registered(key_fp):
                raise ValueError(f"{ERR_UNKNOWN_ISSUER}: Unknown or unregistered issuer key_fingerprint: {key_fp}")
            self.trust_registry.verify_stage_signature(key_fp, stage_data, signature)
        elif signature:
            if not key_fp or not self.trust_registry.is_registered(key_fp):
                raise ValueError(f"{ERR_UNKNOWN_ISSUER}: Unknown or unregistered issuer key_fingerprint: {key_fp}")
            self.trust_registry.verify_stage_signature(key_fp, stage_data, signature)

        # Digest chaining check
        prev_digest = stage_data.get("prev_stage_digest")
        if prev_digest != self.last_stage_digest:
            raise ValueError(f"{ERR_STAGE_CHAIN_ORDER}: Stage digest chain broken at {stage_name}")

        # Persist the nonce BEFORE advancing in-memory verifier state. The ledger
        # refreshes disk and commits under a cross-process lock; failed persistence
        # must leave the stage index, digest and PID identity unchanged.
        next_digest = compute_domain_digest(STAGE_DOMAIN, stage_data)
        self.replay_ledger.record_and_verify("V3_0", self.trust_domain, issuer, key_fp, nonce)
        self.current_stage_idx = idx
        if pid is not None:
            self.known_pids[pid] = birth
        self.last_stage_digest = next_digest
        return next_digest

    def verify_106_path_census(
        self,
        manifest_paths: Dict[str, str],
        claim_clean_all: bool = False,
        claim_authoritative: bool = False
    ) -> Tuple[bool, List[str]]:
        """
        Enforces 106-path structural census and historical drift preservation (Q05, RQA-02).
        Assurance level: SYNTHETIC_106_CENSUS_ONLY.
        Any claim of authoritative original custody without an owner/authorized manifest is rejected.
        """
        anomalies: List[str] = []

        # Claiming authoritative original custody on synthetic paths is strictly forbidden (RQA-02)
        if claim_authoritative:
            anomalies.append(
                f"{ERR_UNVERIFIED_AUTHORITATIVE_CUSTODY_CLAIM}: "
                f"Authoritative original custody manifest is unadmitted. "
                f"Assurance level is limited to {CENSUS_ASSURANCE_LEVEL}."
            )

        # 1. Total count check
        if len(manifest_paths) != 106:
            anomalies.append(f"{ERR_PATH_CENSUS_MISMATCH}: Path count {len(manifest_paths)} != 106")

        # 2. Exact membership check against synthetic 106 paths
        manifest_set = set(manifest_paths.keys())
        missing_paths = SYNTHETIC_106_PATHS - manifest_set
        excess_paths = manifest_set - SYNTHETIC_106_PATHS

        if missing_paths:
            anomalies.append(f"{ERR_PATH_CENSUS_MISMATCH}: Missing synthetic paths: {sorted(list(missing_paths))[:3]}")
        if excess_paths:
            anomalies.append(f"{ERR_PATH_CENSUS_MISMATCH}: Unauthorized excess paths: {sorted(list(excess_paths))[:3]}")

        # 3. Path hash values validation (M2: reject placeholder zero-hashes and unauthorized drift markers)
        if len(manifest_paths) > 1 and len(set(manifest_paths.values())) == 1 and list(manifest_paths.values())[0] == "0" * 64:
            anomalies.append(f"{ERR_PATH_CENSUS_MISMATCH}: Manifest contains identical zero-hash placeholders")

        for p, h in manifest_paths.items():
            if h == "DRIFTED" and p not in HISTORICAL_3_DRIFT_PATHS:
                anomalies.append(f"{ERR_PATH_CENSUS_MISMATCH}: Unauthorized drift marker on non-drift path: {p}")
            elif h == "DRIFTED" and claim_clean_all:
                anomalies.append(f"{ERR_LEGACY_WAIVER_PROHIBITED}: Drift marker present on {p} cannot be claimed clean")

        # 4. Historical drift preservation check (F14)
        for drift_path in HISTORICAL_3_DRIFT_PATHS:
            if drift_path not in manifest_paths:
                anomalies.append(f"{ERR_PATH_CENSUS_MISMATCH}: Missing historical tracked path {drift_path}")

        # If claim says all 106 paths clean without failure, reject as prohibited waiver (F14)
        if claim_clean_all:
            anomalies.append(f"{ERR_LEGACY_WAIVER_PROHIBITED}: Historical 3/106 failure cannot be waived clean")

        return (len(anomalies) == 0, anomalies)

    def verify_temporal_coverage(
        self,
        start_year: int,
        end_year: int,
        warmup_complete: bool = True
    ) -> None:
        """
        Verifies temporal coverage requirements (F08).
        Requires 2022 M1 warmup and continuous yearly coverage.
        """
        if not warmup_complete:
            raise ValueError(f"{ERR_COVERAGE_GAP_DETECTED}: Missing 2022 M1 warmup data")
        if start_year > 2022:
            raise ValueError(f"{ERR_COVERAGE_GAP_DETECTED}: Warmup period starting after 2022: {start_year}")
        if end_year < 2026:
            raise ValueError(f"{ERR_COVERAGE_GAP_DETECTED}: Incomplete evaluation period: ends {end_year} < 2026")

    def verify_legacy_ex5_identity(
        self,
        claimed_sha256: str,
        expected_sha256: str = "aa06cf4969139f13eee4c0c1c57cdc3d9f16d36b2de0e992d7f03d93b26c45ac"
    ) -> None:
        """
        Verifies EX5 binary SHA matches original legacy identity (F12).
        Any modification to binary claiming original legacy identity is rejected.
        Empty file SHA-256 is explicitly rejected.
        """
        EMPTY_FILE_SHA256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        if claimed_sha256 == EMPTY_FILE_SHA256:
            raise ValueError(
                f"{ERR_LEGACY_IDENTITY_MISMATCH}: Empty file hash rejected as original legacy EX5 identity"
            )
        if claimed_sha256 != expected_sha256:
            raise ValueError(
                f"{ERR_LEGACY_IDENTITY_MISMATCH}: Altered EX5 binary SHA "
                f"({claimed_sha256[:16]}... != {expected_sha256[:16]}...) claiming original legacy identity"
            )

    def verify_callsite_static_coverage(
        self,
        declared_callsites: List[str],
        telemetry_callsites: List[str]
    ) -> None:
        """
        Verifies all statically declared call-sites in AST are present in telemetry (F63).
        """
        missing = set(declared_callsites) - set(telemetry_callsites)
        if missing:
            raise ValueError(f"{ERR_STATIC_CALLSITE_OMITTED}: Omitted static call-sites: {sorted(list(missing))}")

    def verify_broker_economics(self, deal_record: Dict[str, Any]) -> None:
        symbol = deal_record.get("symbol")
        if symbol != self.expected_symbol:
            raise ValueError(f"{ERR_SYMBOL_SCOPE_MISMATCH}: Symbol {symbol} != expected {self.expected_symbol}")

        # Economic honesty (F10, H2)
        has_s2_auth = deal_record.get("s2_broker_authenticated", False)
        if type(has_s2_auth) is not bool:
            raise ValueError(f"{ERR_COMMISSION_ZERO_COERCION}: S2 authentication flag must be boolean")
        # A boolean flag in synthetic data is NOT an independently authenticated
        # broker witness. This verifies only the shape/claims of offline fixtures.
        for field in ("commission", "swap"):
            if field not in deal_record:
                raise ValueError(f"{ERR_COMMISSION_ZERO_COERCION}: {field} is UNKNOWN, no broker S2 evidence")
            value = deal_record[field]
            if isinstance(value, bool) or not isinstance(value, (float, int)) or not math.isfinite(value):
                raise ValueError(f"{ERR_COMMISSION_ZERO_COERCION}: {field} must be a finite numeric value")
            if value == 0 and not has_s2_auth:
                raise ValueError(f"{ERR_COMMISSION_ZERO_COERCION}: unauthenticated zero {field} not permitted")

    def verify_bundle_completeness(self, bundle: Dict[str, Any]) -> None:
        # F11 check
        for req_asset in ("deal_journal", "report_html", "hard_kill_record"):
            if not bundle.get(req_asset):
                raise ValueError(f"{ERR_RAW_BUNDLE_INCOMPLETE}: Missing required bundle asset {req_asset}")
