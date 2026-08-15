"""Explicit-root, immutable storage for external intelligence records."""

from __future__ import annotations

from dataclasses import is_dataclass
import json
from pathlib import Path
import re
from typing import Any

from contracts import ContractError, canonical_json


class ImmutableStoreError(RuntimeError):
    """Raised when a write-once external record already exists."""


class ExternalIntelligenceStore:
    """Store records only below a caller-selected external root; there is no default."""

    def __init__(self, root: str | Path) -> None:
        if root is None:
            raise TypeError("root is required; repository storage is never implicit")
        self.root = Path(root).expanduser().resolve()
        if (self.root / ".git").exists():
            raise ContractError("repository root cannot be used as external-intelligence storage")
        self.root.mkdir(parents=True, exist_ok=True)

    def _path(self, record_id: str) -> Path:
        if not isinstance(record_id, str) or not re.fullmatch(r"[A-Za-z0-9._-]+", record_id):
            raise ContractError("record_id must be a safe filename token")
        return self.root / f"{record_id}.json"

    def put(self, record_id: str, record: Any) -> Path:
        path = self._path(record_id)
        if hasattr(record, "to_dict"):
            payload = record.to_dict()
        elif is_dataclass(record):
            raise ContractError("dataclass record must expose to_dict")
        elif isinstance(record, dict):
            payload = record
        else:
            raise ContractError("record must be a contract or mapping")
        encoded = canonical_json(payload)
        try:
            with path.open("x", encoding="utf-8", newline="") as handle:
                handle.write(encoded)
                handle.write("\n")
        except FileExistsError as exc:
            raise ImmutableStoreError(f"record already exists: {record_id}") from exc
        return path

    def get(self, record_id: str) -> dict[str, Any]:
        with self._path(record_id).open("r", encoding="utf-8") as handle:
            value = json.load(handle)
        if not isinstance(value, dict):
            raise ContractError("stored record must be a JSON object")
        return value


__all__ = ["ExternalIntelligenceStore", "ImmutableStoreError"]
