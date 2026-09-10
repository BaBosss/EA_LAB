"""Read-only owner projection. Git statements and lane observations never merge."""
from __future__ import annotations

import json
import re
from datetime import datetime, timezone

STATES = {"READY", "RUNNING", "WAITING", "REVIEW", "INTEGRATING", "BLOCKED", "PARKED", "PAUSED", "FROZEN", "DONE", "UNKNOWN", "CONFLICT"}


def freshness(stamp, now, hours=24):
    try:
        instant = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
        reference = datetime.fromisoformat(now.replace("Z", "+00:00"))
        if instant.tzinfo is None or reference.tzinfo is None:
            return "UNKNOWN"
        age = (reference - instant).total_seconds()
        return "FUTURE" if age < -300 else "STALE" if age > hours * 3600 else "CURRENT"
    except (ValueError, TypeError, AttributeError):
        return "UNKNOWN"


def public_text(text):
    """Git prose is context, never code. Suppress local paths and numeric identities."""
    text = re.sub(r"[A-Za-z]:[\\/][^\s`*]+", "[LOCAL_PATH]", text)
    text = re.sub(r"https?://\S+", "[LINK]", text)
    text = re.sub(r"\b\d{6,}\b", "[IDENTITY]", text)
    return text.replace("**", "").replace("`", "").strip()[:600]


def section(text, heading):
    match = re.search(r"^" + re.escape(heading) + r"\s*$\n(.*?)(?=^#{1,3} |\Z)", text, re.M | re.S)
    return match.group(1) if match else ""


def project_projection(text, provenance):
    text = text.replace("\r\n", "\n")
    # Only the dedicated global-state declaration owns this field.
    global_match = re.search(r"^\*\*Global state: `([A-Z_]+)`\.\*\*$", text, re.M)
    now_section = section(text, "### 5.1 NOW")
    next_items = []
    for line in now_section.splitlines():
        match = re.match(r"(\d+)\. \*\*(.+?)\*\*(.*)", line)
        if match:
            next_items.append({"id": "PLAN-" + match[1], "title": public_text(match[2]),
                               "summary": public_text(match[3]), "state": "UNKNOWN",
                               "source_kind": "GIT_CANONICAL", "provenance": provenance,
                               "priority": int(match[1]), "authority": "PLAN_CONTEXT_ONLY"})
    current = []
    for line in now_section.splitlines():
        match = re.match(r"- \*\*(.+?)\*\*(.*)", line)
        if match:
            current.append({"id": "CURRENT-" + str(len(current) + 1), "title": public_text(match[1]),
                            "summary": public_text(match[2]), "state": "UNKNOWN",
                            "source_kind": "GIT_CANONICAL", "provenance": provenance})
    return {"global_state": global_match[1] if global_match else "UNKNOWN",
            "control_tower_status": "UNKNOWN", "current": current, "next": next_items,
            "status": "AVAILABLE" if now_section else "UNAVAILABLE", "provenance": provenance}


def task_rows(text, provenance):
    """Expose declared header status only; OPEN and narrative are not executable readiness."""
    rows = []
    for number, line in enumerate(text.splitlines(), 1):
        match = re.match(r"^## (ORDER-[A-Za-z0-9_-]+)\s+[\u2014\u2013-]\s+(.+)", line)
        if not match:
            continue
        spans = re.findall(r"`([^`]+)`", match[2])
        declared = next((span for span in spans if re.match(r"^(?:READY|RUNNING|WAITING|REVIEW|INTEGRATING|BLOCKED|PARKED|PAUSED|FROZEN|DONE|OPEN)\b", span)), "")
        tokens = set(re.findall(r"\b(?:READY|RUNNING|WAITING|REVIEW|INTEGRATING|BLOCKED|PARKED|PAUSED|FROZEN|DONE)\b", declared))
        status = next(iter(tokens)) if len(tokens) == 1 else "CONFLICT" if len(tokens) > 1 else "UNKNOWN"
        rows.append({"id": match[1], "title": public_text(re.split(r" [\u2014\u2013] `", match[2])[0]),
                     "state": status, "declared_state": public_text(declared) or "UNKNOWN",
                     "summary": "Taskboard header declaration; execution readiness is not established.",
                     "source_kind": "GIT_CANONICAL", "authority": "HEADER_DECLARATION_ONLY",
                     "freshness": "PINNED_GIT_REF", "blocker_type": "UNKNOWN",
                     "attention_required": False, "owner_action": "UNKNOWN",
                     "provenance": dict(provenance, line=number)})
    return rows


def registry_projection(path, now, safe_id):
    missing = {"status": "UNAVAILABLE", "freshness": "UNKNOWN", "observed_at": "UNKNOWN", "rows": [],
               "source_kind": "LANE_REGISTRY_NONCANONICAL", "reason": "NOT_PROVIDED"}
    if path is None:
        return missing
    try:
        raw = json.loads(path.read_text(encoding="utf-8-sig"))
        if not isinstance(raw, dict) or raw.get("result") != "AUDIT" or not isinstance(raw.get("records"), list):
            raise ValueError("expected canonical Audit envelope")
        stamp = raw.get("generated_at")
        envelope_freshness = freshness(stamp, now)
        rows = []
        for item in raw["records"]:
            if not isinstance(item, dict) or item.get("state") not in STATES:
                raise ValueError("invalid lane row")
            if item["state"] == "DONE":
                continue
            observed = item.get("updated_at", "UNKNOWN")
            row_freshness = freshness(observed, now)
            classification = item.get("classification")
            conflict = classification in {"ACTIVE_IDENTITY_MISMATCH", "ACTIVE_MISSING_WORKTREE"}
            eligible = envelope_freshness == row_freshness == "CURRENT" and classification in {"ACTIVE_CURRENT", "QUEUED_CURRENT"}
            blocker = item.get("blocker_class", "")
            owner = isinstance(blocker, str) and re.match(r"^E(?:$|[_ /-])", blocker) is not None
            rows.append({"id": safe_id(item.get("lane_id")), "state": "CONFLICT" if conflict else item["state"] if eligible else "UNKNOWN",
                         "declared_state": item["state"], "source_kind": "LANE_REGISTRY_NONCANONICAL",
                         "freshness": row_freshness if envelope_freshness == "CURRENT" else envelope_freshness,
                         "observed_at": observed if row_freshness != "UNKNOWN" else "UNKNOWN",
                         "blocker_type": "OWNER_EXTERNAL" if owner else "UNKNOWN",
                         "attention_required": item.get("attention_required") is True or conflict,
                         "owner_action": "UNKNOWN", "owner_required": bool(owner and eligible),
                         "summary": "Lane observation only; process health and canonical completion are not established."})
        return dict(missing, status="AVAILABLE" if envelope_freshness == "CURRENT" else "UNAVAILABLE",
                    freshness=envelope_freshness, observed_at=stamp if envelope_freshness != "UNKNOWN" else "UNKNOWN",
                    rows=rows, reason="AUDIT_OBSERVATION")
    except (OSError, ValueError, TypeError, UnicodeError):
        return dict(missing, reason="INVALID_INPUT")


def build_projection(project_text, project_source, boards, registry, now, safe_id):
    project = project_projection(project_text, project_source)
    canonical = [row for text, source in boards for row in task_rows(text, source)]
    for row in canonical:
        matches = [other for other in canonical if other["id"] == row["id"]]
        if len(matches) > 1:
            row["state"] = "CONFLICT"
    observed = registry_projection(registry, now, safe_id)
    # Equal IDs with different declarations remain two rows, both visibly conflicting.
    for row in observed["rows"]:
        matches = [item for item in canonical if item["id"] == row["id"]]
        if any(item["state"] != row["state"] for item in matches):
            row["state"] = "CONFLICT"
            row["owner_required"] = False
            for item in matches:
                item["state"] = "CONFLICT"
    attention = [dict(row, reason="Explicit Lane Registry E / OWNER_EXTERNAL blocker")
                 for row in observed["rows"] if row.get("owner_required")]
    return {"version": 3, "project": project, "work": canonical, "registry": observed,
            "need_boss": attention, "owner_derivation": "EXPLICIT_CURRENT_E_BLOCKER_ONLY",
            "runtime": [{"id": name, "state": "UNKNOWN", "source_kind": "UNAVAILABLE",
                         "observed_at": "UNKNOWN", "reason": "No qualified observation supplied"}
                        for name in ("Workers / jobs", "Long Jobs", "MT5 lanes", "VPS", "Scheduled monitoring")]}
