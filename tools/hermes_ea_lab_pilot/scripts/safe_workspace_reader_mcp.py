"""Hermes EA_LAB read-only MCP server rooted to one SafeWorkspace.

This server intentionally exposes no mutation or process-execution tools.
Every path is repository-relative, canonicalized, and required to remain
inside the exact workspace root supplied by the harness.
"""
from __future__ import annotations

import fnmatch
import hashlib
import sys
from pathlib import Path

from mcp.server.mcpserver.server import MCPServer
from mcp.types import ToolAnnotations

MAX_TEXT_BYTES = 2 * 1024 * 1024
MAX_READ_LINES = 500
MAX_SEARCH_RESULTS = 300
MAX_LIST_RESULTS = 1000

READ_ONLY = ToolAnnotations(
    read_only_hint=True,
    destructive_hint=False,
    idempotent_hint=True,
    open_world_hint=False,
)


def _workspace_root(value: str | Path) -> Path:
    root = Path(value).resolve(strict=True)
    if not root.is_dir():
        raise ValueError("SafeWorkspace root must be a directory")
    return root


def _resolve_inside(root: Path, relative_path: str, *, require_file: bool | None = None) -> Path:
    raw = Path(relative_path)
    if raw.is_absolute():
        raise ValueError("absolute paths are denied; use a SafeWorkspace-relative path")
    candidate = (root / raw).resolve(strict=True)
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise ValueError("path escapes SafeWorkspace") from exc
    if require_file is True and not candidate.is_file():
        raise ValueError("path is not a file")
    if require_file is False and not candidate.is_dir():
        raise ValueError("path is not a directory")
    return candidate


def _read_text_file(path: Path) -> str:
    size = path.stat().st_size
    if size > MAX_TEXT_BYTES:
        raise ValueError(f"file exceeds read limit ({MAX_TEXT_BYTES} bytes)")
    if path.is_symlink():
        # Resolution already proved the target remains inside the workspace.
        path = path.resolve(strict=True)
    data = path.read_bytes()
    if b"\x00" in data[:8192]:
        raise ValueError("binary file refused")
    return data.decode("utf-8", errors="replace")


def read_text_impl(root: Path, path: str, start_line: int = 1, max_lines: int = 200) -> str:
    if start_line < 1:
        raise ValueError("start_line must be >= 1")
    if max_lines < 1 or max_lines > MAX_READ_LINES:
        raise ValueError(f"max_lines must be 1..{MAX_READ_LINES}")
    target = _resolve_inside(root, path, require_file=True)
    lines = _read_text_file(target).splitlines()
    selected = lines[start_line - 1 : start_line - 1 + max_lines]
    return "\n".join(f"{start_line + i}: {line}" for i, line in enumerate(selected))


def list_files_impl(root: Path, path: str = ".", glob: str = "*", recursive: bool = True, max_results: int = 200) -> str:
    if max_results < 1 or max_results > MAX_LIST_RESULTS:
        raise ValueError(f"max_results must be 1..{MAX_LIST_RESULTS}")
    base = _resolve_inside(root, path, require_file=False)
    iterator = base.rglob("*") if recursive else base.iterdir()
    rows: list[str] = []
    for item in sorted(iterator, key=lambda p: p.as_posix().lower()):
        if len(rows) >= max_results:
            break
        if not item.is_file():
            continue
        try:
            resolved = item.resolve(strict=True)
            resolved.relative_to(root)
        except (OSError, ValueError):
            continue
        rel = resolved.relative_to(root).as_posix()
        if rel == ".git" or rel.startswith(".git/"):
            continue
        if fnmatch.fnmatch(rel, glob) or fnmatch.fnmatch(resolved.name, glob):
            rows.append(rel)
    return "\n".join(rows)


def search_text_impl(
    root: Path,
    query: str,
    path: str = ".",
    glob: str = "*",
    case_sensitive: bool = False,
    max_results: int = 100,
) -> str:
    if not query:
        raise ValueError("query must be non-empty")
    if max_results < 1 or max_results > MAX_SEARCH_RESULTS:
        raise ValueError(f"max_results must be 1..{MAX_SEARCH_RESULTS}")
    base = _resolve_inside(root, path)
    needle = query if case_sensitive else query.casefold()
    rows: list[str] = []
    items = [base] if base.is_file() else sorted(base.rglob("*"), key=lambda p: p.as_posix().lower())
    for item in items:
        if len(rows) >= max_results:
            break
        if not item.is_file():
            continue
        try:
            resolved = item.resolve(strict=True)
            resolved.relative_to(root)
        except (OSError, ValueError):
            continue
        rel = resolved.relative_to(root).as_posix()
        if rel == ".git" or rel.startswith(".git/"):
            continue
        if not (fnmatch.fnmatch(rel, glob) or fnmatch.fnmatch(resolved.name, glob)):
            continue
        try:
            text = _read_text_file(resolved)
        except (OSError, ValueError):
            continue
        for line_no, line in enumerate(text.splitlines(), start=1):
            haystack = line if case_sensitive else line.casefold()
            if needle in haystack:
                rows.append(f"{rel}:{line_no}: {line}")
                if len(rows) >= max_results:
                    break
    return "\n".join(rows)


def sha256_file_impl(root: Path, path: str) -> str:
    target = _resolve_inside(root, path, require_file=True)
    if target.stat().st_size > MAX_TEXT_BYTES * 64:
        raise ValueError("file exceeds hash limit")
    digest = hashlib.sha256()
    with target.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def create_server(workspace: str | Path) -> MCPServer:
    root = _workspace_root(workspace)
    server = MCPServer(
        name="ea-lab-safe-reader",
        description="Read-only, SafeWorkspace-rooted local repository inspection for EA_LAB Hermes observe tasks.",
    )

    @server.tool(annotations=READ_ONLY)
    def read_text(path: str, start_line: int = 1, max_lines: int = 200) -> str:
        """Read bounded text lines from a SafeWorkspace-relative file."""
        return read_text_impl(root, path, start_line, max_lines)

    @server.tool(annotations=READ_ONLY)
    def search_text(
        query: str,
        path: str = ".",
        glob: str = "*",
        case_sensitive: bool = False,
        max_results: int = 100,
    ) -> str:
        """Literal-search one SafeWorkspace-relative file or files under a relative directory."""
        return search_text_impl(root, query, path, glob, case_sensitive, max_results)

    @server.tool(annotations=READ_ONLY)
    def list_files(path: str = ".", glob: str = "*", recursive: bool = True, max_results: int = 200) -> str:
        """List bounded files under a SafeWorkspace-relative directory."""
        return list_files_impl(root, path, glob, recursive, max_results)

    @server.tool(annotations=READ_ONLY)
    def sha256_file(path: str) -> str:
        """Return SHA-256 for one SafeWorkspace-relative file."""
        return sha256_file_impl(root, path)

    return server


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: safe_workspace_reader_mcp.py <SafeWorkspace>", file=sys.stderr)
        return 2
    create_server(argv[1]).run("stdio")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
