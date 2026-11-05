#!/usr/bin/env python3
"""
W5 Build6230 Option B: Scope B Causal Trace & Dependency Verifier V3.0
Multi-Input Causal DAG & Explicit Time Decision Auditor (Q07):
- Reconstructs multi-parent dependency DAG (multiple indicators, prices, time).
- Verifies Value Preservation between READ_RETURN and VALUE_USED.
- Enforces strict separation between BAR_ASSOCIATION metadata and TIME_CONSUMPTION_DECISION.
- Detects orphan decisions, missing input edges, dangling unconsumed reads, and value divergence.
"""

import json
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Set, Tuple

from canonical_v3 import (
    EventChainValidator,
    ERR_EVENT_CHAIN_BROKEN,
    ERR_EVENT_ID_COLLISION,
    ERR_METADATA_TIME_NOT_DECISION,
    ERR_MISSING_TIME_DECISION_EDGE,
    ERR_RECYCLED_HANDLE_COLLISION,
    ERR_UNPAIRED_READ_RETURN,
    ERR_UNPRESERVED_LAST_ERROR,
    ERR_UNVERIFIED_COVERAGE_CLAIM,
    compute_digest,
)

ERR_CAUSAL_ORPHAN_DECISION = "ERR_CAUSAL_ORPHAN_DECISION"
ERR_CAUSAL_VALUE_DIVERGENCE = "ERR_CAUSAL_VALUE_DIVERGENCE"
ERR_CAUSAL_DANGLING_READ = "ERR_CAUSAL_DANGLING_READ"
ERR_CAUSAL_TIMEFRAME_MISMATCH = "ERR_CAUSAL_TIMEFRAME_MISMATCH"


@dataclass
class CausalVerificationSummary:
    total_events: int = 0
    event_counts: Dict[str, int] = field(default_factory=dict)
    causal_chains_closed: int = 0
    dangling_reads: int = 0
    decisions_verified: int = 0
    anomalies: List[str] = field(default_factory=list)
    verdict: str = "PENDING"
    final_digest: str = ""


class CausalGraphAuditor:
    """
    Reconstructs and audits multi-parent causal dependency DAGs (Q07).
    """
    def __init__(self):
        self.events_by_id: Dict[str, Dict[str, Any]] = {}
        self.read_requests: Dict[str, Dict[str, Any]] = {}
        self.read_returns: Dict[str, Dict[str, Any]] = {}
        self.read_failures: Dict[str, Dict[str, Any]] = {}
        self.paired_read_requests: Set[str] = set()
        self.value_uses: Dict[str, Dict[str, Any]] = {}
        self.decisions: Dict[str, Dict[str, Any]] = {}
        self.read_to_use_links: Dict[str, Set[str]] = {}  # read_return_id -> set of value_used_ids
        self.use_to_decision_links: Dict[str, Set[str]] = {}  # value_used_id -> set of decision_ids
        self.time_decisions: Dict[str, Dict[str, Any]] = {}

    def ingest_event(self, event: Dict[str, Any]) -> None:
        eid = event["event_id"]
        etype = event["event_type"]
        self.events_by_id[eid] = event
        # Preserve append order; later events may not retroactively authorize inputs.
        if not hasattr(self, "event_order"):
            self.event_order = {}
        self.event_order[eid] = len(self.event_order)

        if etype == "READ_REQUEST":
            self.read_requests[eid] = event
        elif etype == "READ_RETURN":
            self.read_returns[eid] = event
            parents = self._extract_parent_ids(event)
            for p in parents:
                self.paired_read_requests.add(p)
        elif etype == "READ_FAILURE":
            self.read_failures[eid] = event
            parents = self._extract_parent_ids(event)
            for p in parents:
                self.paired_read_requests.add(p)
        elif etype == "VALUE_USED":
            self.value_uses[eid] = event
            parents = self._extract_parent_ids(event)
            for p in parents:
                if p not in self.read_to_use_links:
                    self.read_to_use_links[p] = set()
                self.read_to_use_links[p].add(eid)
        elif etype == "DECISION":
            self.decisions[eid] = event
            parents = self._extract_parent_ids(event)
            for p in parents:
                if p not in self.use_to_decision_links:
                    self.use_to_decision_links[p] = set()
                self.use_to_decision_links[p].add(eid)

            # Check if this decision is explicitly a time consumption decision
            cl = event.get("causality_link", {})
            if cl.get("edge_type") == "DECISION_DEPENDENCY" and event.get("sensor_payload", {}).get("indicator_kind") == "CUSTOM":
                self.time_decisions[eid] = event

    def _extract_parent_ids(self, event: Dict[str, Any]) -> List[str]:
        parents = []
        p_single = event.get("parent_event_id")
        if p_single:
            parents.append(p_single)
        p_multi = event.get("parent_event_ids")
        if isinstance(p_multi, list):
            for p in p_multi:
                if p and p not in parents:
                    parents.append(p)
        return parents

    def audit_causality(self, allow_unconsumed_reads: bool = False) -> Tuple[bool, List[str]]:
        anomalies: List[str] = []

        # 1. Audit every DECISION: must be grounded in observed VALUE_USED inputs (Q07)
        for did, dev in self.decisions.items():
            causality = dev.get("causality_link", {})

            # Defense against metadata-time leakage (F60)
            if causality.get("edge_type") == "BAR_ASSOCIATION":
                anomalies.append(f"{ERR_METADATA_TIME_NOT_DECISION}: decision {did} claims time dependency from BAR_ASSOCIATION metadata")
                continue

            parent_ids = self._extract_parent_ids(dev)
            if not parent_ids:
                anomalies.append(f"{ERR_CAUSAL_ORPHAN_DECISION}: decision {did} has no parent inputs")
                continue

            if not causality.get("consumed_in_decision"):
                anomalies.append(f"{ERR_CAUSAL_ORPHAN_DECISION}: decision {did} claims consumed_in_decision=False but has inputs")
                continue

            # Audit all input dependencies (multi-input DAG)
            for pid in parent_ids:
                if pid not in self.value_uses:
                    anomalies.append(f"{ERR_CAUSAL_ORPHAN_DECISION}: decision {did} missing parent VALUE_USED {pid}")
                    continue

                use_ev = self.value_uses[pid]
                if self.event_order[pid] >= self.event_order[did]:
                    anomalies.append(f"{ERR_CAUSAL_ORPHAN_DECISION}: VALUE_USED is not prior to decision")
                if use_ev.get("causality_link", {}).get("edge_type") == "BAR_ASSOCIATION":
                    anomalies.append(f"{ERR_METADATA_TIME_NOT_DECISION}: metadata-only VALUE_USED {pid} cannot justify decision")
                read_parents = self._extract_parent_ids(use_ev)
                if not read_parents:
                    anomalies.append(f"{ERR_CAUSAL_ORPHAN_DECISION}: value_use {pid} missing parent READ_RETURN")
                    continue

                for rrid in read_parents:
                    if rrid not in self.read_returns:
                        anomalies.append(f"{ERR_CAUSAL_ORPHAN_DECISION}: value_use {pid} missing parent READ_RETURN {rrid}")
                        continue

                    read_ev = self.read_returns[rrid]
                    if self.event_order[rrid] >= self.event_order[pid]:
                        anomalies.append(f"{ERR_CAUSAL_ORPHAN_DECISION}: READ_RETURN must precede VALUE_USED {pid}")
                    read_val = read_ev.get("sensor_payload", {}).get("raw_value")
                    used_val = use_ev.get("sensor_payload", {}).get("raw_value")
                    if read_val != used_val:
                        anomalies.append(
                            f"{ERR_CAUSAL_VALUE_DIVERGENCE}: decision {did} used value {used_val} != read return {read_val}"
                        )

        # 2. Audit every READ_RETURN: must have valid preceding READ_REQUEST
        for rrid, rrev in self.read_returns.items():
            parent_req_ids = self._extract_parent_ids(rrev)
            if not parent_req_ids:
                anomalies.append(f"{ERR_UNPAIRED_READ_RETURN}: read_return {rrid} missing parent READ_REQUEST")
            else:
                for req_id in parent_req_ids:
                    if req_id not in self.read_requests:
                        anomalies.append(f"{ERR_UNPAIRED_READ_RETURN}: read_return {rrid} missing parent READ_REQUEST {req_id}")
                    elif self.event_order[req_id] >= self.event_order[rrid]:
                        anomalies.append(f"{ERR_UNPAIRED_READ_RETURN}: return precedes request {req_id}")

        # Open / unpaired READ_REQUEST check (H4: probe P6)
        for req_id in self.read_requests:
            if req_id not in self.paired_read_requests:
                anomalies.append(f"{ERR_UNPAIRED_READ_RETURN}: read_request {req_id} was never closed by READ_RETURN or READ_FAILURE")

        # 3. Audit unconsumed/dangling reads (if strict)
        if not allow_unconsumed_reads:
            for rrid in self.read_returns:
                if rrid not in self.read_to_use_links or len(self.read_to_use_links[rrid]) == 0:
                    anomalies.append(f"{ERR_CAUSAL_DANGLING_READ}: read_return {rrid} was never consumed by VALUE_USED")

        return (len(anomalies) == 0, anomalies)


class CausalTraceVerifier:
    """
    Combined verification engine: cryptographic event chain + causal dependency audit.
    """
    def __init__(self, trust_domain: str = "SYNTHETIC_FIXTURE_TEST_ONLY", schema_path: Optional[str] = None):
        self.chain_validator = EventChainValidator(trust_domain=trust_domain, schema_path=schema_path)
        self.graph_auditor = CausalGraphAuditor()

    def verify_stream(
        self,
        events: List[Dict[str, Any]],
        allow_unconsumed_reads: bool = False,
        external_witness_present: bool = False,
        time_filter_active: bool = False
    ) -> CausalVerificationSummary:
        summary = CausalVerificationSummary()
        summary.total_events = len(events)

        # 1. Step-by-step cryptographic and schema validation
        try:
            for ev in events:
                etype = ev.get("event_type", "UNKNOWN")
                summary.event_counts[etype] = summary.event_counts.get(etype, 0) + 1

                # Ingest into chain validator
                self.chain_validator.validate_event(
                    ev,
                    external_witness_present=external_witness_present,
                    time_filter_active=time_filter_active
                )

                # Ingest into graph auditor
                self.graph_auditor.ingest_event(ev)

            summary.final_digest = self.chain_validator.last_digest

        except ValueError as exc:
            summary.anomalies.append(str(exc))
            summary.verdict = "FAILED"
            return summary

        # 2. Causal Graph Audit (Q07)
        ok, graph_anomalies = self.graph_auditor.audit_causality(allow_unconsumed_reads=allow_unconsumed_reads)
        if not ok:
            summary.anomalies.extend(graph_anomalies)
            summary.verdict = "FAILED"
            return summary

        summary.decisions_verified = len(self.graph_auditor.decisions)
        summary.causal_chains_closed = len(self.graph_auditor.read_to_use_links)
        summary.dangling_reads = len(self.graph_auditor.read_returns) - len(self.graph_auditor.read_to_use_links)
        summary.verdict = "VERIFIED_CLEAN"
        return summary
