"""Bounded stable-byte access. Only fixed codes and opaque source keys escape."""
from __future__ import annotations
import csv
import hashlib
import io
import os
import re
import stat
import subprocess
from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from tools.control_center.contracts.observations import parse_json, utc, ProjectionError


class Refused(ValueError):
    """A fixed public reason code; never include input or exception text."""


def digest(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def opaque(kind: str, *values: str) -> str:
    return kind + "-" + digest((kind + "\0" + "\0".join(values)).encode())


def integer(value: str, *, positive: bool = False) -> str:
    if not isinstance(value, str) or not re.fullmatch(r"0|[1-9][0-9]{0,19}", value):
        raise Refused("INVALID_INTEGER")
    if positive and value == "0":
        raise Refused("INVALID_INTEGER")
    return value


def decimal(value: str) -> Decimal:
    if not isinstance(value, str) or not re.fullmatch(r"-?[0-9]{1,20}(?:\.[0-9]{1,10})?", value):
        raise Refused("INVALID_DECIMAL")
    return Decimal(value)


def broker_time(value: str) -> str:
    if not isinstance(value, str) or not re.fullmatch(r"[0-9]{4}\.[0-9]{2}\.[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}", value):
        raise Refused("INVALID_BROKER_TIME")
    try:
        return datetime.strptime(value, "%Y.%m.%d %H:%M:%S").isoformat()
    except ValueError:
        raise Refused("INVALID_BROKER_TIME") from None


def symbol(value: str, *, empty: bool = False) -> str:
    if value == "" and empty:
        return value
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z][A-Za-z0-9_.#-]{0,31}", value):
        raise Refused("INVALID_SYMBOL")
    return value


def currency(value: str) -> str:
    if not isinstance(value, str) or not re.fullmatch(r"[A-Z]{3}", value):
        raise Refused("INVALID_CURRENCY")
    return value


def checked_path(path: Path, root: Path, *, missing_leaf: bool = False) -> Path:
    path, root = Path(path).absolute(), Path(root).absolute()
    for candidate in (path, root):
        if str(candidate).startswith(("\\\\", "//")):
            raise Refused("NETWORK_OR_DEVICE_PATH_REFUSED")
        for part in candidate.parts:
            if part == candidate.anchor:
                continue
            if (":" in part or part.endswith((" ", ".")) or re.fullmatch(r"(?i:CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:\..*)?", part)):
                raise Refused("DEVICE_OR_ALTERNATE_STREAM_REFUSED")
    if ".." in path.parts or ".." in root.parts or not path.is_relative_to(root):
        raise Refused("PATH_OUTSIDE_ROOT")
    for part in reversed((path, *path.parents)):
        try:
            info = part.lstat()
        except FileNotFoundError:
            if missing_leaf and part == path:
                continue
            raise Refused("SOURCE_MISSING") from None
        except OSError:
            raise Refused("SOURCE_ACCESS_DENIED") from None
        if stat.S_ISLNK(info.st_mode) or getattr(info, "st_file_attributes", 0) & 0x400:
            raise Refused("LINK_OR_REPARSE_REFUSED")
        if part != path and not stat.S_ISDIR(info.st_mode):
            raise Refused("INVALID_SOURCE_PARENT")
    if not path.resolve().is_relative_to(root.resolve()):
        raise Refused("PATH_OUTSIDE_ROOT")
    return path


@dataclass(frozen=True)
class Limits:
    files: int = 800
    file_bytes: int = 8_000_000
    total_bytes: int = 128_000_000
    rows: int = 1_000_000
    directory_entries: int = 2000

    def __post_init__(self):
        for value, ceiling in zip(self.__dict__.values(), (800, 8_000_000, 128_000_000, 1_000_000, 2000)):
            if type(value) is not int or not 0 < value <= ceiling:
                raise Refused("INVALID_BUDGET")


@dataclass
class Sources:
    limits: Limits = field(default_factory=Limits)
    provenance: list[dict] = field(default_factory=list)
    errors: list[dict] = field(default_factory=list)
    files: int = 0
    bytes: int = 0
    rows: int = 0

    def error(self, owner: str, code: str, source: str | None = None):
        self.errors.append({"owner": owner, "code": code, "source_id": source,
                            "finding_id": opaque("finding", owner, code, source or "MISSING"),
                            "next_action": "INSPECT_DECLARED_SOURCE_EVIDENCE"})

    def reserve(self, size: int):
        self.files += 1
        self.bytes += size
        if self.files > self.limits.files or size > self.limits.file_bytes or self.bytes > self.limits.total_bytes:
            raise Refused("SOURCE_BUDGET_EXCEEDED")

    def record(self, key: str, raw: bytes, kind: str):
        self.provenance.append({"source_id": key, "sha256": digest(raw), "bytes": len(raw), "kind": kind})

    def read(self, root: Path, relative: str, kind: str) -> tuple[bytes, str]:
        key = opaque("source", kind, str(Path(root).absolute()), relative)
        path = checked_path(Path(root) / relative, root)
        try:
            before = path.stat()
            if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1:
                raise Refused("NON_REGULAR_OR_HARDLINK")
            self.reserve(before.st_size)
            with path.open("rb") as stream:
                opened = os.fstat(stream.fileno())
                raw = stream.read(self.limits.file_bytes + 1)
            checked_path(path, root)
            with path.open("rb") as stream:
                reopened = os.fstat(stream.fileno())
                again = stream.read(self.limits.file_bytes + 1)
            after = path.stat()
            # Python 3.12 Windows stat/fstat can expose different ctime semantics.
            # Compare ctime only between calls to the same API, keeping identity,
            # size, mtime, link count and both complete byte reads bound throughout.
            signature = lambda s: (s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns, s.st_nlink)
            if (signature(before) != signature(opened) or signature(before) != signature(after)
                    or signature(opened) != signature(reopened)
                    or before.st_ctime_ns != after.st_ctime_ns or opened.st_ctime_ns != reopened.st_ctime_ns
                    or raw != again or len(raw) != before.st_size):
                raise Refused("SOURCE_CHANGED_DURING_READ")
        except OSError:
            raise Refused("SOURCE_ACCESS_FAILED") from None
        self.record(key, raw, kind)
        return raw, key

    def discover(self, root: Path, prefix: str) -> list[str]:
        checked_path(root, root)
        names = []
        try:
            with os.scandir(root) as entries:
                for count, item in enumerate(entries, 1):
                    if count > self.limits.directory_entries:
                        raise Refused("DIRECTORY_BUDGET_EXCEEDED")
                    if item.name.startswith(prefix) and item.name.endswith(".csv"):
                        names.append(item.name)
                        if len(names) > self.limits.files:
                            raise Refused("SOURCE_BUDGET_EXCEEDED")
        except OSError:
            raise Refused("SOURCE_ACCESS_FAILED") from None
        return sorted(names)

    def csv(self, raw: bytes, fields: set[str] | None = None, optional: set[str] = frozenset()) -> list[dict[str, str]]:
        try:
            reader = csv.DictReader(io.StringIO(raw.decode("utf-8-sig")), strict=True)
            header = reader.fieldnames
            if (not header or len(header) != len(set(header)) or any(not x for x in header)
                    or (fields is not None and (not fields <= set(header) or set(header) - fields - optional))):
                raise Refused("CSV_SCHEMA_INVALID")
            result = []
            for row in reader:
                self.rows += 1
                if self.rows > self.limits.rows:
                    raise Refused("ROW_BUDGET_EXCEEDED")
                if set(row) != set(header) or any(v is None for v in row.values()):
                    raise Refused("CSV_ROW_SHAPE_INVALID")
                result.append(row)
            return result
        except (UnicodeError, csv.Error):
            raise Refused("CSV_ENCODING_OR_SYNTAX_INVALID") from None

    def git_blob(self, repo: Path, sha: str, path: str) -> tuple[bytes, str]:
        # Fixed caller-owned paths only; no shell, fetch, hooks or worktree-source reads.
        checked_path(repo, repo)
        if not re.fullmatch(r"[0-9a-f]{40}", sha) or not re.fullmatch(r"[A-Za-z0-9_(). /-]+", path) or ".." in Path(path).parts:
            raise Refused("INVALID_GIT_REQUEST")
        def git(*args):
            try:
                r = subprocess.run(["git", "--no-optional-locks", "-C", str(repo), *args], capture_output=True, timeout=15)
            except (OSError, subprocess.TimeoutExpired):
                raise Refused("GIT_READ_FAILED") from None
            if r.returncode:
                raise Refused("GIT_SOURCE_UNAVAILABLE")
            return r.stdout
        entry = git("ls-tree", sha, "--", path).decode("utf-8")
        if not re.fullmatch(r"100(?:644|755) blob [0-9a-f]{40}\t" + re.escape(path) + r"\n", entry):
            raise Refused("GIT_SOURCE_NOT_REGULAR")
        self.reserve(int(git("cat-file", "-s", sha + ":" + path)))
        raw = git("show", sha + ":" + path)
        key = opaque("source", sha, path)
        self.record(key, raw, "PINNED_GIT")
        return raw, key


def json_object(raw: bytes) -> dict:
    try:
        return parse_json(raw)
    except ProjectionError:
        raise Refused("JSON_SCHEMA_INVALID") from None


def utc_time(value: str):
    try:
        return utc(value)
    except ProjectionError:
        raise Refused("INVALID_QUALIFIED_TIMESTAMP") from None
