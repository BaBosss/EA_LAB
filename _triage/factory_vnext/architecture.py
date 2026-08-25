# -*- coding: utf-8 -*-
"""Schema-ready Master Mold / Family / Variant identities for Factory vNext."""
from __future__ import annotations

import re
from typing import Any, Dict, Iterable, Mapping, Optional, Sequence

from .contracts import canonical_json, stable_id


class ArchitectureError(ValueError):
    pass


COMPONENT_ROLES = (
    "ENTRY", "REVERSAL", "RECOVERY", "HEDGE", "EXIT", "FILTER", "OTHER",
)
_ID_RE = re.compile(r"^[A-Z][A-Z0-9._-]{1,63}$")


def _text(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ArchitectureError("%s is required" % name)
    return value.strip()


def _machine_id(value: Any, name: str) -> str:
    text = _text(value, name).upper()
    if not _ID_RE.match(text):
        raise ArchitectureError("%s is not a valid machine id" % name)
    return text

def _ids(values: Iterable[str], name: str) -> list[str]:
    result = sorted({_machine_id(value, name) for value in values})
    if not result:
        raise ArchitectureError("%s must not be empty" % name)
    return result


def make_master_mold(mold_id: str, version: str, capabilities: Iterable[str]) -> Dict[str, Any]:
    record = {
        "schema_version": "factory-vnext-master-mold-v1",
        "MasterMoldID": _machine_id(mold_id, "MasterMoldID"),
        "MasterMoldVersion": _text(version, "MasterMoldVersion"),
        "Capabilities": _ids(capabilities, "CapabilityID"),
        "authority": "NON_AUTHORITATIVE_SIDECAR",
    }
    record["MasterMoldSnapshotID"] = stable_id("MOLD", record)
    return record


def make_strategy_family(
    master: Mapping[str, Any], family_id: str, name: str,
    capabilities: Iterable[str], display_id: Optional[str] = None,
) -> Dict[str, Any]:
    selected = _ids(capabilities, "CapabilityID")
    available = set(master.get("Capabilities") or [])
    outside = [item for item in selected if item not in available]
    if outside:
        raise ArchitectureError("family capability outside Master Mold: %s" % ",".join(outside))
    return {
        "schema_version": "factory-vnext-family-v1",
        "FamilyID": _machine_id(family_id, "FamilyID"),
        "FamilyName": _text(name, "FamilyName"),
        "DisplayID": display_id,
        "MasterMoldID": _machine_id(master.get("MasterMoldID"), "MasterMoldID"),
        "MasterMoldVersion": _text(master.get("MasterMoldVersion"), "MasterMoldVersion"),
        "Capabilities": selected,
        "authority": "NON_AUTHORITATIVE_SIDECAR",
    }

def make_position_group(group_id: str, intent: str, parent_group_id: Optional[str] = None) -> Dict[str, Any]:
    return {
        "PositionGroupID": _machine_id(group_id, "PositionGroupID"),
        "Intent": _text(intent, "Intent"),
        "ParentPositionGroupID": (
            _machine_id(parent_group_id, "ParentPositionGroupID") if parent_group_id else None
        ),
    }


def make_component(
    component_id: str, role: str, position_group_id: str, *,
    capabilities: Iterable[str], parent_position_group_id: Optional[str] = None,
    recovery_scope_position_group_id: Optional[str] = None, enabled: bool = True,
) -> Dict[str, Any]:
    component_role = _text(role, "ComponentRole").upper()
    if component_role not in COMPONENT_ROLES:
        raise ArchitectureError("unsupported ComponentRole %r" % component_role)
    return {
        "ComponentID": _machine_id(component_id, "ComponentID"),
        "ComponentRole": component_role,
        "PositionGroupID": _machine_id(position_group_id, "PositionGroupID"),
        "ParentPositionGroupID": (
            _machine_id(parent_position_group_id, "ParentPositionGroupID")
            if parent_position_group_id else None
        ),
        "RecoveryScopePositionGroupID": (
            _machine_id(recovery_scope_position_group_id, "RecoveryScopePositionGroupID")
            if recovery_scope_position_group_id else None
        ),
        "Capabilities": _ids(capabilities, "CapabilityID"),
        "Enabled": bool(enabled),
    }


def _unique_records(records: Sequence[Mapping[str, Any]], key: str) -> list[Dict[str, Any]]:
    normalized = [dict(record) for record in records]
    values = [record.get(key) for record in normalized]
    if len(values) != len(set(values)):
        raise ArchitectureError("duplicate %s" % key)
    return sorted(normalized, key=lambda record: str(record.get(key)))

def _validate_group_links(groups: Sequence[Mapping[str, Any]]) -> set[str]:
    group_ids = {str(group.get("PositionGroupID")) for group in groups}
    for group in groups:
        gid = _machine_id(group.get("PositionGroupID"), "PositionGroupID")
        parent = group.get("ParentPositionGroupID")
        if parent:
            parent_id = _machine_id(parent, "ParentPositionGroupID")
            if parent_id not in group_ids:
                raise ArchitectureError("PositionGroup parent does not exist: %s" % parent_id)
            if parent_id == gid:
                raise ArchitectureError("PositionGroup cannot parent itself: %s" % gid)
    return group_ids


def _validate_component_links(
    components: Sequence[Mapping[str, Any]], group_ids: set[str], family_caps: set[str],
) -> None:
    for component in components:
        cid = _machine_id(component.get("ComponentID"), "ComponentID")
        role = _text(component.get("ComponentRole"), "ComponentRole").upper()
        if role not in COMPONENT_ROLES:
            raise ArchitectureError("unsupported ComponentRole %r" % role)
        group_id = _machine_id(component.get("PositionGroupID"), "PositionGroupID")
        if group_id not in group_ids:
            raise ArchitectureError("component %s references unknown PositionGroup %s" % (cid, group_id))
        parent = component.get("ParentPositionGroupID")
        if parent and _machine_id(parent, "ParentPositionGroupID") not in group_ids:
            raise ArchitectureError("component %s parent PositionGroup does not exist" % cid)
        if role == "HEDGE" and not parent:
            raise ArchitectureError("hedge component %s requires ParentPositionGroupID" % cid)
        if role == "HEDGE" and _machine_id(parent, "ParentPositionGroupID") == group_id:
            raise ArchitectureError("hedge component %s parent must differ from its PositionGroup" % cid)
        recovery_scope = component.get("RecoveryScopePositionGroupID")
        if role == "RECOVERY":
            if not recovery_scope:
                raise ArchitectureError("recovery component %s requires RecoveryScopePositionGroupID" % cid)
            scope_id = _machine_id(recovery_scope, "RecoveryScopePositionGroupID")
            if scope_id != group_id:
                raise ArchitectureError("recovery component %s must be group-local" % cid)
        elif recovery_scope:
            scope_id = _machine_id(recovery_scope, "RecoveryScopePositionGroupID")
            if scope_id != group_id:
                raise ArchitectureError("component %s has cross-group recovery scope" % cid)
        component_caps = {_machine_id(x, "CapabilityID") for x in component.get("Capabilities") or []}
        outside = sorted(component_caps - family_caps)
        if outside:
            raise ArchitectureError("component %s capability outside Family: %s" % (cid, ",".join(outside)))


def make_strategy_variant(
    family: Mapping[str, Any], variant_id: str, strategy_version: str,
    position_groups: Sequence[Mapping[str, Any]], components: Sequence[Mapping[str, Any]],
    display_id: Optional[str] = None,
) -> Dict[str, Any]:
    groups = _unique_records(position_groups, "PositionGroupID")
    comps = _unique_records(components, "ComponentID")
    group_ids = _validate_group_links(groups)
    family_caps = {_machine_id(x, "CapabilityID") for x in family.get("Capabilities") or []}
    if not family_caps:
        raise ArchitectureError("Family has no capabilities")
    _validate_component_links(comps, group_ids, family_caps)
    record = {
        "schema_version": "factory-vnext-variant-v1",
        "FamilyID": _machine_id(family.get("FamilyID"), "FamilyID"),
        "VariantID": _machine_id(variant_id, "VariantID"),
        "StrategyVersion": _text(strategy_version, "StrategyVersion"),
        "DisplayID": display_id,
        "PositionGroups": groups,
        "Components": comps,
        "authority": "NON_AUTHORITATIVE_SIDECAR",
    }
    snapshot = {key: record[key] for key in (
        "FamilyID", "VariantID", "StrategyVersion", "PositionGroups", "Components",
    )}
    record["VariantSnapshotID"] = stable_id("VAR", snapshot, hex_chars=24)
    return record


def variant_context(master: Mapping[str, Any], family: Mapping[str, Any], variant: Mapping[str, Any]) -> Dict[str, Any]:
    return {
        "MasterMoldID": _machine_id(master.get("MasterMoldID"), "MasterMoldID"),
        "MasterMoldVersion": _text(master.get("MasterMoldVersion"), "MasterMoldVersion"),
        "FamilyID": _machine_id(family.get("FamilyID"), "FamilyID"),
        "VariantID": _machine_id(variant.get("VariantID"), "VariantID"),
        "VariantSnapshotID": _text(variant.get("VariantSnapshotID"), "VariantSnapshotID"),
    }
