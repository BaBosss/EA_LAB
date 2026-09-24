"""Importable observation builder. Every read is explicit and every result is sanitized."""
from __future__ import annotations
import re
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Literal
from .safe import Limits, Sources, Refused, utc_time, digest
from .readers import Metadata, read_ledgers, read_snapshots
from .coverage import read_control, deployment_coverage, guard_observations, access_provenance

PARSER_CONTRACTS = {
    "tools/DealsExporter/DealsExporter.mq5": "ccfed20042561f72c87e6b1a43c3ddca21aece18cd9d7dc22699c0cd5d992306",
    "tools/AccountSnapshot/AccountSnapshot_Core.mqh": "0152171de43a71773c9dfa98e3cc3426f53030c39a1822237fabf1e215ed3a8b",
    "tools/AccountSnapshot/AccountSnapshotExporter.mq4": "6b1ed64e7e727c326be6fb3957d7e94af1020210f3394641ce30dc4abce4529e",
    "_triage/factory_os/runtime_identity.py": "aa88dad3fc2b52ff072bc123794ede7f0ed19da2208af8eef55a818b58627756",
    "tools/control_center/contracts/observations.py": "3406a38db909a3034354f901a5781fa8f4363b7447b9ab04d46bb7edb2dc6f94",
}
METADATA_FIELDS = {
    "ACCOUNTS": set("account account_name platform environment governance_scope expected_sensor monitor_sla_minutes base_equity currency start_date alert_policy notes".split()),
    "DEPLOYMENTS": set("account account_name type platform host ea_name magic symbol status kill_rule judge_date start_date notes".split()),
    "RUNTIME_IDENTITY_MAP": set("account magic ea_logical_identity build_receipt config_fingerprint config_fingerprint_version symbol timeframe attach_epoch source_sha256 artifact_sha256".split()),
}


@dataclass(frozen=True)
class BuildRequest:
    repo: Path
    ref: str
    ledgers: Path
    snapshots: Path
    runtime: Path
    as_of: str | None = None
    limits: Limits = field(default_factory=Limits)


@dataclass(frozen=True)
class Section:
    implementation: str
    availability: Literal["REAL_DATA_QUALIFIED", "PARTIAL", "UNAVAILABLE"]
    reasons: list[str]
    data: dict
    provenance: list[dict]
    errors: list[dict]


@dataclass(frozen=True)
class Observations:
    schema_version: str
    canonical_ref: str
    read_at_utc: str
    authority: str
    integration: dict
    sections: dict[str, Section]
    provenance: list[dict]
    errors: list[dict]
    budget_usage: dict

    def to_dict(self) -> dict:
        return asdict(self)


def build_observations(request: BuildRequest) -> Observations:
    if not isinstance(request.ref, str) or not re.fullmatch("[0-9a-f]{40}", request.ref):
        raise Refused("EXPLICIT_COMMIT_REQUIRED")
    as_of = request.as_of or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    utc_time(as_of)
    sources = Sources(request.limits)
    for path, expected_hash in PARSER_CONTRACTS.items():
        raw, _ = sources.git_blob(request.repo, request.ref, path)
        if digest(raw) != expected_hash:
            raise Refused("PARSER_CONTRACT_SOURCE_CHANGED")
    owners, refs = [], []
    for name, fields in METADATA_FIELDS.items():
        raw, ref = sources.git_blob(request.repo, request.ref, "portfolio/" + name + ".csv")
        rows = sources.csv(raw, fields)
        owners.append(rows)
        refs.append(ref)
    meta = Metadata(*owners, refs)
    sections = {}

    def section(name, function, reasons, implemented="IMPLEMENTED_READER"):
        start, err_start = len(sources.provenance), len(sources.errors)
        try:
            data = function()
            availability = "PARTIAL"
        except Refused as exc:
            sources.error(name, str(exc))
            data, availability = {}, "UNAVAILABLE"
        sections[name] = Section(implemented, availability, reasons, data,
                                 sources.provenance[start:], sources.errors[err_start:])
        return data

    sections["work"] = Section("EXISTING_COLLECTOR_MONITOR_OWNER", "UNAVAILABLE",
                                ["EXCLUDED_FROM_THIS_PACKAGE"], {}, [], [])
    section("accounts", lambda: read_snapshots(sources, request.snapshots, meta),
            ["BROKER_SERVER_NOT_EXPORTED", "BROKER_TIME_UNQUALIFIED", "NO_INTERPOLATION"])
    section("ledger", lambda: read_ledgers(sources, request.ledgers, meta),
            ["FEE_CYCLE_IDS_NOT_EXPORTED", "BROKER_TIME_UNQUALIFIED", "DECLARATIVE_ATTRIBUTION_ONLY"])
    try:
        control = read_control(sources, request.runtime, request.ref, as_of)
    except Refused as exc:
        sources.error("deployments", str(exc))
        control = None
    coverage = section("deployments", lambda: deployment_coverage(meta, control, as_of),
                       ["DESCRIPTIVE_ONLY", "NO_RUNTIME_OR_FORWARD_TEST_QUALIFICATION"])
    section("guards", lambda: guard_observations(sources, request.runtime, request.repo, request.ref, as_of, coverage),
            ["NO_QUALIFIED_EFFECTIVE_EVENT_SOURCE", "EXISTING_IDENTITY_AUTHORITY_UNCHANGED"])
    sections["access_provenance"] = Section("IMPLEMENTED_PROVENANCE_ONLY", "UNAVAILABLE",
                                           ["NO_ACCESS_QUALIFICATION_EVIDENCE"], access_provenance(), [], [])
    def referenced(value):
        if isinstance(value, dict):
            return set().union(*(referenced(v) for v in value.values())) if value else set()
        if isinstance(value, list):
            return set().union(*(referenced(v) for v in value)) if value else set()
        return {value} if isinstance(value, str) and value.startswith("source-") else set()
    for name, item in list(sections.items()):
        refs_used = referenced(item.data) | {p["source_id"] for p in item.provenance}
        sections[name] = Section(item.implementation, item.availability, item.reasons, item.data,
                                 [p for p in sources.provenance if p["source_id"] in refs_used],
                                 [e for e in sources.errors if e["owner"] == name])
    return Observations("ea_observation_adapters/1", request.ref, as_of, "READ_ONLY_SOURCE_OBSERVATIONS",
        {"consumer": "tools.mobile_report_hub.owner_webapp.model.Model.snapshot",
         "ui_wired": False, "activated": False, "real_data_qualified": False},
        sections, sources.provenance, sources.errors,
        {"files": sources.files, "bytes": sources.bytes, "rows": sources.rows})
