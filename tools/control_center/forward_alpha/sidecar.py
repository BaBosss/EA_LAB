"""Strict source-bound forward observations and descriptive projections."""
from __future__ import annotations

import base64
from contextlib import contextmanager
from datetime import timedelta
import json
import math
import os
from pathlib import Path
from statistics import mean

from tools.control_center.contracts.observations import (
    ProjectionError, digest, hex_value, parse_json, safe_path, safe_text, utc,
)

MODULE = Path(__file__).resolve().parent
DIMENSIONS = ("symbol", "timeframe", "strategy", "family", "variant", "regime",
              "direction", "horizon_seconds", "config_sha256")
HEADERS = {"authority": "RESEARCH_ONLY", "trading": "REAL_TRADING_OFF",
           "promotion_authority": "NO_PROMOTION_AUTHORITY"}


def canonical(value):
    """Canonical JSON bytes; whitespace/key order are not semantic changes."""
    try:
        return json.dumps(value, sort_keys=True, separators=(",", ":"),
                          ensure_ascii=True, allow_nan=False).encode("ascii")
    except (ValueError, TypeError):
        raise ProjectionError("INVALID_JSON_VALUE") from None


def shape(value, required, optional=()):
    if (not isinstance(value, dict) or not set(required) <= set(value)
            or set(value) - set(required) - set(optional)):
        raise ProjectionError("UNEXPECTED_FIELD_OR_SHAPE")


def number(value, positive=False):
    try:
        valid = type(value) in (int, float) and math.isfinite(value)
    except OverflowError:
        valid = False
    if not valid or (positive and value <= 0):
        raise ProjectionError("INVALID_NUMBER")
    return value


def median(values):
    ordered = sorted(values)
    middle = len(ordered) // 2
    return ordered[middle] if len(ordered) % 2 else mean(ordered[middle - 1:middle + 1])


def source(raw, expected):
    shape(expected, ("source_id", "ref", "sha256", "canonical_sha"))
    safe_text(expected["source_id"])
    safe_path(expected["ref"])
    hex_value(expected["sha256"], 64)
    if expected["canonical_sha"] is not None:
        hex_value(expected["canonical_sha"], 40)
    if not isinstance(raw, bytes) or digest(raw) != expected["sha256"]:
        raise ProjectionError("SOURCE_HASH_MISMATCH")
    value = parse_json(raw)
    shape(value, ("source_id", "ref", "canonical_sha", "available_at", "payload"))
    for key in ("source_id", "ref", "canonical_sha"):
        if value[key] != expected[key]:
            raise ProjectionError("SOURCE_PROVENANCE_MISMATCH")
    utc(value["available_at"])
    return value


def observation(payload, available_at):
    shape(payload, ("schema", "observation_id", "observed_at", "symbol", "timeframe",
                    "strategy", "family", "variant", "regime", "direction", "horizon",
                    "config_sha256", "authority", "snapshot_sha256", "reference_price"))
    if payload["schema"] != "forward_observation/1" or payload["authority"] != "RESEARCH_ONLY":
        raise ProjectionError("SCHEMA_OR_AUTHORITY")
    for key in ("observation_id", "symbol", "timeframe", "strategy", "family", "variant", "regime"):
        safe_text(payload[key])
        if payload[key] == "UNKNOWN":
            raise ProjectionError("REQUIRED_IDENTITY_UNKNOWN")
    observed = utc(payload["observed_at"])
    if utc(available_at) > observed:
        raise ProjectionError("LOOK_AHEAD_SOURCE")
    if payload["direction"] not in ("UP", "DOWN", "UNSIGNED"):
        raise ProjectionError("INVALID_DIRECTION")
    shape(payload["horizon"], ("kind", "seconds"))
    seconds = payload["horizon"]["seconds"]
    if (payload["horizon"]["kind"] != "ELAPSED_SECONDS" or type(seconds) is not int
            or seconds <= 0):
        raise ProjectionError("INVALID_HORIZON")
    try:
        observed + timedelta(seconds=seconds)
    except OverflowError:
        raise ProjectionError("INVALID_HORIZON") from None
    if payload["config_sha256"] != "UNKNOWN":
        hex_value(payload["config_sha256"], 64)
    hex_value(payload["snapshot_sha256"], 64)
    number(payload["reference_price"], positive=True)


def settlement(payload, available_at, observations):
    shape(payload, ("schema", "observation_id", "observation_sha256", "end_at", "end_price"),
          ("high_price", "low_price"))
    if payload["schema"] != "forward_settlement/1":
        raise ProjectionError("SCHEMA_MISMATCH")
    safe_text(payload["observation_id"])
    item = observations.get(payload["observation_id"])
    if item is None:
        raise ProjectionError("UNKNOWN_OBSERVATION")
    hex_value(payload["observation_sha256"], 64)
    if payload["observation_sha256"] != item["record_sha256"]:
        raise ProjectionError("OBSERVATION_PROVENANCE_MISMATCH")
    obs = item["payload"]
    end = utc(payload["end_at"])
    if (end <= utc(obs["observed_at"]) or end != utc(obs["observed_at"]) +
            timedelta(seconds=obs["horizon"]["seconds"])):
        raise ProjectionError("HORIZON_MISMATCH")
    if utc(available_at) < end:
        raise ProjectionError("OUTCOME_NOT_YET_AVAILABLE")
    price = number(payload["end_price"], positive=True)
    start = obs["reference_price"]
    if ("high_price" in payload) != ("low_price" in payload):
        raise ProjectionError("INCOMPLETE_EXTREMA")
    if "high_price" in payload:
        high, low = number(payload["high_price"], True), number(payload["low_price"], True)
        if not low <= min(start, price) <= max(start, price) <= high:
            raise ProjectionError("INVALID_EXTREMA")
    # Overflow must refuse before evidence is accepted, even for finite prices.
    outcome(obs, payload)


def outcome(obs, settled):
    start = obs["reference_price"]
    forward = number((settled["end_price"] - start) / start)
    sign = {"UP": 1, "DOWN": -1, "UNSIGNED": None}[obs["direction"]]
    signed = number(forward * sign) if sign is not None else None
    result = {"forward_return": forward, "signed_return": signed,
              "directional_hit": signed > 0 if signed is not None else None,
              "mfe": None, "mae": None}
    if "high_price" in settled and sign is not None:
        high = number((settled["high_price"] - start) / start)
        low = number((settled["low_price"] - start) / start)
        result.update(mfe=max(sign * high, sign * low), mae=min(sign * high, sign * low))
    return result


class Ledger:
    """Single append-only event file. Exclusive lock; no automatic stale-lock removal."""

    def __init__(self, directory):
        self.directory = Path(directory).resolve()
        if not self.directory.is_relative_to(MODULE) or self.directory == MODULE:
            raise ProjectionError("LEDGER_OUTSIDE_MODULE")
        self.path = self.directory / "events.jsonl"

    @contextmanager
    def _locked(self):
        self.directory.mkdir(parents=True, exist_ok=True)
        if self.directory.resolve() != self.directory:
            raise ProjectionError("UNSAFE_LEDGER_PATH")
        lock = self.directory / "writer.lock"
        try:
            handle = lock.open("xb")
        except FileExistsError:
            raise ProjectionError("LEDGER_BUSY") from None
        try:
            with handle:
                yield
        finally:
            lock.unlink()

    def _read(self):
        observations, settlements, previous = {}, {}, "0" * 64
        if self.path.is_symlink() or self.path.resolve().parent != self.directory:
            raise ProjectionError("UNSAFE_LEDGER_PATH")
        raw = self.path.read_bytes() if self.path.exists() else b""
        if raw and not raw.endswith(b"\n"):
            raise ProjectionError("INCOMPLETE_LEDGER")
        for line in raw.splitlines():
            event = parse_json(line)
            shape(event, ("kind", "source", "raw_b64", "previous_sha256", "record_sha256"))
            recorded = event.pop("record_sha256")
            if event["previous_sha256"] != previous or digest(canonical(event)) != recorded:
                raise ProjectionError("LEDGER_HASH_MISMATCH")
            try:
                data = base64.b64decode(event["raw_b64"], validate=True)
            except (ValueError, TypeError):
                raise ProjectionError("INVALID_SOURCE_ENCODING") from None
            envelope = source(data, event["source"])
            payload = envelope["payload"]
            if event["kind"] == "observation":
                observation(payload, envelope["available_at"])
                target = observations
            elif event["kind"] == "settlement":
                settlement(payload, envelope["available_at"], observations)
                target = settlements
            else:
                raise ProjectionError("INVALID_EVENT_KIND")
            identity = payload["observation_id"]
            if identity in target:
                raise ProjectionError("DUPLICATE_LEDGER_EVENT")
            target[identity] = {"record_sha256": recorded, "payload": payload,
                                "source": event["source"], "available_at": envelope["available_at"],
                                "raw_b64": event["raw_b64"]}
            previous = recorded
        return observations, settlements, previous

    def read(self):
        with self._locked():
            return self._read()

    def _append(self, kind, raw, expected_source):
        envelope = source(raw, expected_source)
        payload = envelope["payload"]
        with self._locked():
            observations, settlements, previous = self._read()
            if kind == "observation":
                observation(payload, envelope["available_at"])
                target = observations
            else:
                settlement(payload, envelope["available_at"], observations)
                target = settlements
            encoded = base64.b64encode(raw).decode("ascii")
            existing = target.get(payload["observation_id"])
            if existing:
                if existing["raw_b64"] != encoded or existing["source"] != expected_source:
                    raise ProjectionError("DIVERGENT_DUPLICATE")
                return existing["record_sha256"]
            event = {"kind": kind, "source": expected_source, "raw_b64": encoded,
                     "previous_sha256": previous}
            record_hash = digest(canonical(event))
            event["record_sha256"] = record_hash
            with self.path.open("ab") as stream:
                stream.write(canonical(event) + b"\n")
                stream.flush()
                os.fsync(stream.fileno())
            return record_hash

    def observe(self, raw, *, expected_source):
        return self._append("observation", raw, expected_source)

    def settle(self, raw, *, expected_source):
        return self._append("settlement", raw, expected_source)


def dimensions(obs):
    return {key: obs["horizon"]["seconds"] if key == "horizon_seconds" else obs[key]
            for key in DIMENSIONS}


def query_contract(query):
    shape(query, ("group_by", "omitted_dimensions", "start_at", "end_at", "as_of", "filters"),
          ("minimum_sample",))
    for key in ("group_by", "omitted_dimensions"):
        values = query[key]
        if (not isinstance(values, list) or any(not isinstance(v, str) for v in values)
                or len(values) != len(set(values))):
            raise ProjectionError("INVALID_GROUPING")
    grouped, omitted = set(query["group_by"]), set(query["omitted_dimensions"])
    if grouped & omitted or grouped | omitted != set(DIMENSIONS):
        raise ProjectionError("EXPLICIT_DIMENSION_OMISSION_REQUIRED")
    if not utc(query["start_at"]) < utc(query["end_at"]) <= utc(query["as_of"]):
        raise ProjectionError("INVALID_QUERY_WINDOW")
    if not isinstance(query["filters"], dict) or set(query["filters"]) - set(DIMENSIONS):
        raise ProjectionError("INVALID_FILTER")
    for key, values in query["filters"].items():
        if not isinstance(values, list) or not values:
            raise ProjectionError("INVALID_FILTER")
        for value in values:
            if key == "horizon_seconds":
                if type(value) is not int or value <= 0:
                    raise ProjectionError("INVALID_FILTER")
            elif key == "config_sha256" and value != "UNKNOWN":
                hex_value(value, 64)
            else:
                safe_text(value)
    minimum = query.get("minimum_sample")
    if minimum is not None and (type(minimum) is not int or minimum < 0):
        raise ProjectionError("INVALID_MINIMUM_SAMPLE")


def evidence_ref(item):
    return {"record_sha256": item["record_sha256"], "source": item["source"],
            "available_at": item["available_at"]}


def summarize(ledger, query):
    query_contract(query)
    observations, settlements, head = ledger.read()
    groups = {}
    for identity, item in observations.items():
        obs = item["payload"]
        if not query["start_at"] <= obs["observed_at"] < query["end_at"]:
            continue
        dims = dimensions(obs)
        if any(dims[k] not in values for k, values in query["filters"].items()):
            continue
        key = canonical({k: dims[k] for k in query["group_by"]})
        group = groups.setdefault(key, {"identity": json.loads(key), "evidence": []})
        settled = settlements.get(identity)
        if settled and settled["available_at"] > query["as_of"]:
            settled = None
        group["evidence"].append({"observation_id": identity, "observed_at": obs["observed_at"],
                                  "observation": evidence_ref(item),
                                  "settlement": evidence_ref(settled) if settled else None,
                                  "outcome": outcome(obs, settled["payload"]) if settled else None})
    result = []
    for key, group in sorted(groups.items()):
        evidence = sorted(group["evidence"], key=lambda e: (e["observed_at"], e["observation_id"]))
        outcomes = [e["outcome"] for e in evidence if e["outcome"] is not None]
        signed = [v["signed_return"] for v in outcomes if v["signed_return"] is not None]
        group.update(group_id=digest(key), evidence=evidence, sample_count=len(outcomes),
                     signed_sample_count=len(signed), open_count=len(evidence) - len(outcomes),
                     positive_count=sum(v > 0 for v in signed), negative_count=sum(v < 0 for v in signed),
                     zero_count=sum(v == 0 for v in signed),
                     hit_rate=mean(v > 0 for v in signed) if signed else None,
                     mean_signed_outcome=mean(signed) if signed else None,
                     median_signed_outcome=median(signed) if signed else None,
                     first_observed_at=evidence[0]["observed_at"], last_observed_at=evidence[-1]["observed_at"],
                     source_coverage={"observation_sources": sorted({e["observation"]["source"]["source_id"] for e in evidence}),
                                      "outcome_sources": sorted({e["settlement"]["source"]["source_id"] for e in evidence if e["settlement"]})})
        for metric in ("mfe", "mae"):
            values = [v[metric] for v in outcomes if v[metric] is not None]
            group[metric] = {"sample_count": len(values), "mean": mean(values) if values else None,
                             "median": median(values) if values else None}
        minimum = query.get("minimum_sample")
        group["caller_minimum_sample_met"] = len(outcomes) >= minimum if minimum is not None else None
        result.append(group)
    return {**HEADERS, "schema": "forward_alpha_summary/1", "interpretation": "DESCRIPTIVE_ONLY",
            "ledger_sha256": head, "query": json.loads(canonical(query)),
            "minimum_sample_origin": "CALLER_SUPPLIED" if query.get("minimum_sample") is not None else None,
            "groups": result}


def decay(ledger, *, prior, recent):
    query_contract(prior)
    query_contract(recent)
    if (prior["end_at"] > recent["start_at"] or
            {k: v for k, v in prior.items() if k not in ("start_at", "end_at")} !=
            {k: v for k, v in recent.items() if k not in ("start_at", "end_at")}):
        raise ProjectionError("INCOMPARABLE_SLICES")
    before, after = summarize(ledger, prior), summarize(ledger, recent)
    if before["ledger_sha256"] != after["ledger_sha256"]:
        raise ProjectionError("LEDGER_CHANGED_DURING_QUERY")
    left = {g["group_id"]: g for g in before["groups"]}
    right = {g["group_id"]: g for g in after["groups"]}
    deltas = []
    for key in sorted(left.keys() | right.keys()):
        row = {"group_id": key}
        for metric in ("sample_count", "hit_rate", "mean_signed_outcome"):
            a, b = left.get(key, {}).get(metric), right.get(key, {}).get(metric)
            row[metric + "_delta"] = number(b - a) if a is not None and b is not None else None
        deltas.append(row)
    return {**HEADERS, "schema": "forward_alpha_decay/1", "interpretation": "DESCRIPTIVE_ONLY",
            "prior": before, "recent": after, "deltas": deltas}


def hypotheses(ledger, *, query, selected_group_ids):
    summary = summarize(ledger, query)
    if (not isinstance(selected_group_ids, list) or not selected_group_ids
            or any(not isinstance(value, str) for value in selected_group_ids)
            or len(selected_group_ids) != len(set(selected_group_ids))):
        raise ProjectionError("INVALID_GROUP_SELECTION")
    for identity in selected_group_ids:
        hex_value(identity, 64)
    known = {g["group_id"]: g for g in summary["groups"]}
    if set(selected_group_ids) - known.keys():
        raise ProjectionError("UNKNOWN_GROUP_SELECTION")
    proposals = []
    for key in sorted(selected_group_ids):
        group = known[key]
        proposals.append({"proposal_id": digest(canonical({"summary": summary, "group_id": key})),
                          "kind": "RESEARCH_HYPOTHESIS_PROPOSAL", "group": group,
                          "question": "Does this source-bound directional association persist in new observations?",
                          "counter_evidence_ids": [e["observation_id"] for e in group["evidence"]
                                                   if e["outcome"] is not None and
                                                   e["outcome"]["signed_return"] is not None and
                                                   e["outcome"]["signed_return"] <= 0]})
    return {**HEADERS, "schema": "forward_alpha_hypotheses/1", "intake": "CONTROL_TOWER_PROPOSAL_ONLY",
            "selection_origin": "CALLER_SUPPLIED", "summary": summary, "proposals": proposals}


def snapshot(ledger, query):
    return {**HEADERS, "schema": "forward_alpha_snapshot/1", "summary": summarize(ledger, query)}
