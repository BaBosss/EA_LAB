from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import Any, Iterable


SCHEMA = "ea-lab-second-brain-reader/1"
PACKET_SCHEMA = "ea-lab-knowledge-query-packet/1"
HEX40 = re.compile(r"^[0-9a-f]{40}$")
HEX64 = re.compile(r"^[0-9a-f]{64}$")
SOURCE_ID = re.compile(r"\bSRC-[A-Z0-9][A-Z0-9-]*\b")
MARKDOWN_LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
URL = re.compile(r"https?://[^\s)>\]]+", re.I)
EN_TOKEN = re.compile(r"[A-Za-z0-9]+(?:[-_][A-Za-z0-9]+)*")
CURATED_ROOTS = (
    "knowledge/00_indexes/", "knowledge/01_sources/", "knowledge/02_research_cards/",
    "knowledge/03_strategy_mechanisms/", "knowledge/04_components/", "knowledge/05_regimes/",
    "knowledge/06_validation/", "knowledge/07_risk_execution/", "knowledge/10_synthesis/",
    "knowledge/90_negative_knowledge/",
)
CURATED_FILES = {"knowledge/README.md"}
DRAFT_ROOTS = ("knowledge/01_sources/", "knowledge/02_research_cards/")
REGISTRY_PATH = "knowledge/01_sources/source_registry.jsonl"
ASSET_PATHS = ("mobile_report_hub/knowledge_reader.js", "mobile_report_hub/knowledge_reader.css")
SECRET_PATTERNS = (
    re.compile(r"(?i)\b(?:authorization\s*:\s*bearer|bearer\s+)[A-Za-z0-9._~+/=-]{12,}"),
    re.compile(r"(?i)\b(?:api[_-]?key|secret|password)\s*[:=]\s*['\"]?[A-Za-z0-9._~+/=-]{12,}"),
)


class ReaderError(RuntimeError):
    pass


def _run(repo: Path, *args: str, text: bool = False) -> bytes | str:
    proc = subprocess.run(["git", "-C", str(repo), *args], stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, text=text, check=False)
    if proc.returncode:
        message = proc.stderr.strip() if text else proc.stderr.decode("utf-8", "replace").strip()
        raise ReaderError(f"git {' '.join(args)} failed: {message}")
    return proc.stdout


def resolve_ref(repo: Path, ref: str, expected: str) -> str:
    if not HEX40.fullmatch(ref) or not HEX40.fullmatch(expected):
        raise ReaderError("--ref and --expected-sha must be lowercase 40-hex commit IDs")
    actual = str(_run(repo, "rev-parse", "--verify", f"{ref}^{{commit}}", text=True)).strip()
    if actual != expected or actual != ref:
        raise ReaderError(f"canonical pin mismatch: ref={actual}, expected={expected}")
    return actual


def git_tree(repo: Path, ref: str) -> dict[str, str]:
    raw = bytes(_run(repo, "ls-tree", "-r", "-z", ref))
    tree: dict[str, str] = {}
    for entry in raw.split(b"\0"):
        if not entry:
            continue
        meta, path_raw = entry.split(b"\t", 1)
        mode, kind, _oid = meta.decode("ascii").split()
        path = path_raw.decode("utf-8")
        if kind != "blob":
            continue
        tree[path] = mode
    return tree


def git_bytes(repo: Path, ref: str, path: str) -> bytes:
    return bytes(_run(repo, "show", f"{ref}:{path}"))


def safe_posix(path: str) -> str:
    if not isinstance(path,str) or not path or ":" in path or "\\" in path or "\x00" in path or any(x in ("", ".", "..") for x in path.split("/")):
        raise ReaderError(f"unsafe path: {path!r}")
    value = PurePosixPath(path)
    if value.is_absolute() or any(part in ("", ".", "..") for part in value.parts):
        raise ReaderError(f"unsafe path: {path!r}")
    return value.as_posix()


def resolve_repo_link(base: PurePosixPath, target: str) -> str:
    if not target or target.startswith(("/", "\\")) or "\\" in target or "\x00" in target:
        raise ReaderError(f"unsafe link: {target!r}")
    parts: list[str] = list(base.parts)
    for part in PurePosixPath(target).parts:
        if part in ("", "."):
            continue
        if part == "..":
            if not parts:
                raise ReaderError(f"link escapes repository: {target!r}")
            parts.pop()
        else:
            parts.append(part)
    if not parts:
        raise ReaderError(f"unsafe link: {target!r}")
    return PurePosixPath(*parts).as_posix()


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def decode_markdown(data: bytes, path: str) -> str:
    try:
        text = data.decode("utf-8-sig").replace("\r\n", "\n")
    except UnicodeDecodeError as exc:
        raise ReaderError(f"non-UTF-8 markdown: {path}") from exc
    for pattern in SECRET_PATTERNS:
        if pattern.search(text):
            raise ReaderError(f"possible credential/bearer content refused: {path}")
    return text


def frontmatter(text: str) -> dict[str, str]:
    if not text.startswith("---\n"):
        return {}
    end = text.find("\n---", 4)
    if end < 0:
        return {}
    result: dict[str, str] = {}
    for line in text[4:end].splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            result[key.strip()] = value.strip().strip("'\"")
    return result


def title_of(text: str, path: str) -> str:
    match = re.search(r"^#\s+(.+?)\s*$", text, re.M)
    return match.group(1).strip() if match else PurePosixPath(path).stem


def section_refs(text: str) -> list[dict[str, Any]]:
    lines = text.splitlines()
    headings: list[tuple[int, str]] = []
    for number, line in enumerate(lines, 1):
        match = re.match(r"^(#{1,6})\s+(.+?)\s*$", line)
        if match:
            headings.append((number, match.group(2)))
    refs = []
    for index, (start, heading) in enumerate(headings):
        end = headings[index + 1][0] - 1 if index + 1 < len(headings) else len(lines)
        refs.append({"section": heading, "start_line": start, "end_line": end})
    return refs


def doc_type(path: str, meta: dict[str, str]) -> str:
    if meta.get("card_type"):
        return meta["card_type"]
    if PurePosixPath(path).name == "README.md":
        return "FOLDER_GUIDE"
    for root, name in (("02_research_cards", "RESEARCH_CARD"), ("03_strategy_mechanisms", "MECHANISM"),
                       ("04_components", "COMPONENT"), ("05_regimes", "REGIME"),
                       ("06_validation", "VALIDATION"), ("07_risk_execution", "RISK_EXECUTION"),
                       ("10_synthesis", "SYNTHESIS"), ("90_negative_knowledge", "NEGATIVE_KNOWLEDGE"),
                       ("01_sources", "SOURCE_NOTE"), ("00_indexes", "INDEX")):
        if f"knowledge/{root}/" in path:
            return name
    return "SECOND_BRAIN_GUIDE"


def topics_for(text: str, path: str, dtype: str) -> list[str]:
    values = {dtype.replace("_", " ").title()}
    folder = PurePosixPath(path).parent.name.replace("_", " ").strip()
    if folder:
        values.add(folder.title())
    lower = text.lower()
    for label, needles in {
        "Order Flow": ("order flow", "orderflow", "volume delta"), "BWD": ("bwd", "backward"),
        "Risk": ("risk", "drawdown", "sizing", "ruin"), "Demon Beam": ("demon beam",),
        "Validation": ("walk-forward", "overfit", "validation", "holdout"),
        "Negative Memory": ("closed_negative", "do_not_reopen", "negative knowledge", "falsif"),
    }.items():
        if any(needle in lower for needle in needles):
            values.add(label)
    return sorted(values, key=lambda value: (value.casefold(), value))


def load_registry(repo: Path, ref: str, tree: dict[str, str]) -> tuple[dict[str, dict[str, Any]], list[dict[str, str]]]:
    if REGISTRY_PATH not in tree or tree[REGISTRY_PATH] == "120000":
        raise ReaderError("source registry missing or symlinked")
    records: dict[str, dict[str, Any]] = {}
    problems: list[dict[str, str]] = []
    raw = git_bytes(repo, ref, REGISTRY_PATH)
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ReaderError("source registry is not UTF-8") from exc
    for number, line in enumerate(text.splitlines(), 1):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
            if not isinstance(row, dict): raise ReaderError(f"registry line {number} must be an object")
        except json.JSONDecodeError as exc:
            raise ReaderError(f"malformed registry line {number}: {exc.msg}") from exc
        source_id = row.get("source_id")
        if not isinstance(source_id, str) or not SOURCE_ID.fullmatch(source_id):
            raise ReaderError(f"invalid source_id at registry line {number}")
        if source_id in records:
            raise ReaderError(f"duplicate source_id: {source_id}")
        locator, declared = row.get("locator"), row.get("sha256")
        if not isinstance(locator, str) or not isinstance(declared, str) or not HEX64.fullmatch(declared):
            raise ReaderError(f"malformed registry binding: {source_id}")
        binding = "EXTERNAL_NOT_VERIFIED"
        if not re.match(r"^[a-z][a-z0-9+.-]*:", locator, re.I):
            try:
                locator = safe_posix(locator)
            except ReaderError:
                binding = "PATH_ESCAPE"
            else:
                if locator not in tree:
                    binding = "MISSING"
                elif tree[locator] == "120000":
                    binding = "SYMLINK_REFUSED"
                else:
                    binding = "MATCH" if sha256(git_bytes(repo, ref, locator)) == declared else "HASH_MISMATCH"
        row = dict(row)
        row["binding_state"] = binding
        row["registry_line"] = number
        records[source_id] = row
        if binding not in ("MATCH", "EXTERNAL_NOT_VERIFIED"):
            problems.append({"kind": "REGISTRY_BINDING", "source_id": source_id, "state": binding, "path": locator})
    return records, problems


def internal_link_health(path: str, text: str, tree: dict[str, str]) -> list[dict[str, str]]:
    missing = []
    base = PurePosixPath(path).parent
    for raw in MARKDOWN_LINK.findall(text):
        target = raw.strip().split("#", 1)[0].split("?", 1)[0]
        if not target or re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith(("#", "//")):
            continue
        try:
            normalized = resolve_repo_link(base, target)
        except ReaderError:
            missing.append({"kind": "UNSAFE_LINK", "path": path, "target": raw})
            continue
        if normalized not in tree and not any(item.startswith(normalized.rstrip("/") + "/") for item in tree):
            missing.append({"kind": "MISSING_LINK", "path": path, "target": raw})
    return missing


def make_document(path: str, raw: bytes, registry: dict[str, dict[str, Any]], authority: str,
                  tree: dict[str, str] | None = None) -> dict[str, Any]:
    text = decode_markdown(raw, path)
    meta = frontmatter(text)
    ids = sorted(set(SOURCE_ID.findall(text)) | ({meta["source_id"]} if meta.get("source_id") else set()))
    bindings = [registry.get(item) for item in ids]
    broken = [item for item, binding in zip(ids, bindings) if not binding or binding.get("binding_state") not in ("MATCH", "EXTERNAL_NOT_VERIFIED")]
    is_locator = any(row and row.get("locator") == path for row in registry.values())
    if authority == "DRAFT_NOT_IMPORTED":
        authority_class = authority
    elif broken:
        authority_class = "BROKEN_PROVENANCE"
    elif ids or is_locator:
        authority_class = "REGISTERED_RESEARCH"
    else:
        authority_class = "OTHER_CANONICAL_DOCUMENT"
    dtype = doc_type(path, meta)
    urls = [url.rstrip(".,;") for url in URL.findall(text)]
    safe_urls = [url for url in urls if url.lower().startswith(("https://", "http://"))]
    doc_id = meta.get("card_id") or meta.get("mechanism_id") or meta.get("source_id") or path
    return {
        "id": doc_id, "title": title_of(text, path), "document_type": dtype,
        "authority_class": authority_class, "path": path if authority != "DRAFT_NOT_IMPORTED" else None,
        "portable_id": ("draft::" if authority == "DRAFT_NOT_IMPORTED" else "git::") + doc_id, "sha256": sha256(raw), "body": text, "source_ids": ids,
        "line_refs": section_refs(text), "topics": topics_for(text, path, dtype),
        "source_url": safe_urls[0] if safe_urls else None,
        "frontmatter": {key: meta.get(key) for key in ("card_type", "card_id", "mechanism_id", "source_id", "evidence_depth", "status", "authority")},
        "provenance_problems": broken,
    }


def load_drafts(packet: Path, manifest_expected: str, registry: dict[str, dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, str]]]:
    if not HEX64.fullmatch(manifest_expected):
        raise ReaderError("--prepared-manifest-sha256 must be lowercase 64-hex")
    packet = packet.resolve(strict=True)
    manifest_path = packet / "MANIFEST_SHA256.json"
    if manifest_path.is_symlink() or not manifest_path.is_file():
        raise ReaderError("prepared manifest missing or symlinked")
    manifest_raw = manifest_path.read_bytes()
    if sha256(manifest_raw) != manifest_expected:
        raise ReaderError("prepared manifest byte hash mismatch")
    try:
        manifest = json.loads(manifest_raw)
    except json.JSONDecodeError as exc:
        raise ReaderError(f"malformed prepared manifest: {exc.msg}") from exc
    files = manifest.get("files")
    if not isinstance(files, list):
        raise ReaderError("prepared manifest files must be an array")
    seen: set[str] = set()
    verified: dict[str, bytes] = {}
    for item in files:
        if not isinstance(item, dict) or not isinstance(item.get("path"), str) or not isinstance(item.get("sha256"), str):
            raise ReaderError("malformed prepared manifest entry")
        relative = safe_posix(item["path"])
        if relative in seen:
            raise ReaderError(f"duplicate prepared path: {relative}")
        seen.add(relative)
        target = packet.joinpath(*PurePosixPath(relative).parts)
        cursor = target
        while cursor != packet:
            if cursor.is_symlink() or (hasattr(cursor,"is_junction") and cursor.is_junction()):
                raise ReaderError(f"prepared symlink/junction refused: {relative}")
            cursor = cursor.parent
        if target.is_symlink() or not target.is_file() or packet not in target.resolve().parents:
            raise ReaderError(f"prepared path missing/symlink/escape: {relative}")
        raw = target.read_bytes()
        if not HEX64.fullmatch(item["sha256"]) or sha256(raw) != item["sha256"] or ("bytes" in item and len(raw) != item["bytes"]):
            raise ReaderError(f"prepared file hash/size mismatch: {relative}")
        verified[relative] = raw
    docs = []
    for path in sorted(verified, key=lambda value: (value.casefold(), value)):
        if path.endswith(".md") and path.startswith(DRAFT_ROOTS):
            docs.append(make_document(path, verified[path], registry, "DRAFT_NOT_IMPORTED"))
    if not docs:
        raise ReaderError("prepared packet has no allowed derived knowledge markdown")
    return docs, []


def build_index(repo: Path, ref: str, expected: str, packet: Path | None = None,
                manifest_sha: str | None = None) -> dict[str, Any]:
    canonical = resolve_ref(repo, ref, expected)
    tree = git_tree(repo, canonical)
    paths = sorted((path for path, mode in tree.items() if path.endswith(".md") and
                    (path in CURATED_FILES or path.startswith(CURATED_ROOTS))), key=lambda value: (value.casefold(), value))
    if not paths:
        raise ReaderError("no curated Second Brain markdown at canonical ref")
    symlinks = [path for path in paths if tree[path] == "120000"]
    if symlinks:
        raise ReaderError(f"curated symlink refused: {symlinks[0]}")
    registry, problems = load_registry(repo, canonical, tree)
    documents = []
    link_problems: list[dict[str, str]] = []
    for path in paths:
        raw = git_bytes(repo, canonical, path)
        document = make_document(path, raw, registry, "CANONICAL", tree)
        documents.append(document)
        link_problems.extend(internal_link_health(path, document["body"], tree))
    draft_documents: list[dict[str, Any]] = []
    if packet or manifest_sha:
        if not packet or not manifest_sha:
            raise ReaderError("prepared packet and manifest SHA must be supplied together")
        draft_documents, draft_problems = load_drafts(packet, manifest_sha, registry)
        problems.extend(draft_problems)
    all_docs = documents + draft_documents
    ids: set[str] = set()
    for document in all_docs:
        identity = f'{document["authority_class"]}:{document["id"]}'
        if identity in ids:
            raise ReaderError(f"duplicate document identity: {identity}")
        ids.add(identity)
    commit_time = str(_run(repo, "show", "-s", "--format=%cI", canonical, text=True)).strip()
    source_notes = sum(doc["document_type"] == "SOURCE_NOTE" and doc["authority_class"] != "DRAFT_NOT_IMPORTED" for doc in documents)
    cards = sum(doc["document_type"] == "RESEARCH_CARD" and doc["authority_class"] != "DRAFT_NOT_IMPORTED" for doc in documents)
    problems.extend(link_problems)
    for doc in documents:
        if doc["provenance_problems"]: problems.append({"kind":"DOCUMENT_SOURCE_BINDING", "path":doc["path"], "source_ids":doc["provenance_problems"]})
    return {
        "schema_version": SCHEMA,
        "authority": "READ_ONLY_RESEARCH_NAVIGATION_NO_RUNTIME_OR_STRATEGY_AUTHORITY",
        "canonical": {"ref": canonical, "sha": canonical, "build_timestamp": commit_time, "timestamp_basis": "GIT_COMMIT_TIME_NON_AUTHORITY", "generated_at_utc":datetime.now(timezone.utc).isoformat()},
        "health": {"status": "PROBLEMS" if problems else "OK", "canonical_documents": len(documents),
                   "source_notes": source_notes, "research_cards": cards, "draft_documents": len(draft_documents),
                   "registry_records": len(registry), "external_not_verified":sum(r["binding_state"] == "EXTERNAL_NOT_VERIFIED" for r in registry.values()), "git_hash_matches":sum(r["binding_state"] == "MATCH" for r in registry.values()), "problems": problems,
                   "missing_or_unsafe_link_count": len(link_problems),
                   "registry_binding_problem_count": sum(p["kind"] == "REGISTRY_BINDING" for p in problems)},
        "registry": [registry[key] for key in sorted(registry)],
        "documents": all_docs,
    }


def _tokens(query: str) -> tuple[list[str], list[str]]:
    english = [token.casefold() for token in EN_TOKEN.findall(query)]
    thai = re.findall(r"[\u0E00-\u0E7F]+", query)
    return english, thai


def matches(document: dict[str, Any], query: str, topics: Iterable[str] = (), scope: str = "ALL") -> bool:
    if scope == "CANONICAL" and document["authority_class"] == "DRAFT_NOT_IMPORTED":
        return False
    if scope == "DRAFT" and document["authority_class"] != "DRAFT_NOT_IMPORTED":
        return False
    wanted_topics = {item.casefold() for item in topics}
    if wanted_topics and not wanted_topics.intersection(item.casefold() for item in document.get("topics", [])):
        return False
    if not query.strip():
        return True
    haystack = "\n".join([document.get("title", ""), document.get("body", ""), " ".join(document.get("topics", [])), " ".join(document.get("source_ids", []))])
    hay_english = {token.casefold() for token in EN_TOKEN.findall(haystack)}
    english, thai = _tokens(query)
    return all(token in hay_english for token in english) and all(token in haystack for token in thai)


def excerpt(document: dict[str, Any], query: str, limit: int = 420) -> str:
    body = re.sub(r"\s+", " ", document.get("body", "")).strip()
    terms = _tokens(query)[0] + _tokens(query)[1]
    folded = body.casefold()
    positions = [folded.find(term.casefold()) for term in terms if folded.find(term.casefold()) >= 0]
    start = max(0, (min(positions) if positions else 0) - 100)
    value = body[start:start + limit]
    return ("…" if start else "") + value + ("…" if start + limit < len(body) else "")


def query_packet(index: dict[str, Any], question: str, intake: dict[str, Any]) -> dict[str, Any]:
    results = [doc for doc in index["documents"] if matches(doc, question)]
    results.sort(key=lambda doc: (doc["authority_class"] == "DRAFT_NOT_IMPORTED", doc["title"].casefold(), doc["id"]))
    negative = [doc for doc in index["documents"] if doc["document_type"] == "NEGATIVE_KNOWLEDGE" and matches(doc, question)]
    unresolved = ["Keyword NO_MATCH is not proof that no prior experiment exists. Read current PROJECT_STATE and exact family/experiment owners before any action.","Snapshot documents may contain historical plans superseded by newer canonical subject owners."]
    if not results:
        unresolved.append("NO_MATCH: no title/body/topic/source match at the pinned export")
    if any(doc["authority_class"] == "BROKEN_PROVENANCE" for doc in results):
        unresolved.append("BROKEN_PROVENANCE present in matched material")
    unresolved.extend(f"Library health: {problem['kind']}" for problem in index["health"]["problems"][:10])
    fields = ("ea", "variant", "build", "config", "symbol", "timeframe", "window", "data_source")
    normalized_intake = {field: intake.get(field) if intake.get(field) not in ("", None) else None for field in fields}
    return {
        "schema_version": PACKET_SCHEMA, "authority": index["authority"], "question": question,
        "canonical": index["canonical"], "problem_intake": normalized_intake,
        "matches": [{"id": doc["id"], "title": doc["title"], "authority_class": doc["authority_class"],
                     "path": doc["path"], "sha256": doc["sha256"], "source_ids": doc["source_ids"],
                     "excerpt": excerpt(doc, question), "line_refs":doc.get("line_refs",[])} for doc in results],
        "negative_memory": ({"status": "MATCH", "sources": [{"id": doc["id"], "sha256": doc["sha256"], "path": doc["path"], "excerpt": excerpt(doc, question)} for doc in negative]}
                            if negative else {"status": "NO_MATCH", "sources": []}),
        "unresolved_evidence_caveats": unresolved,
        "draft_separation": {"draft_matches": sum(doc["authority_class"] == "DRAFT_NOT_IMPORTED" for doc in results),
                             "notice": "DRAFT_NOT_IMPORTED is not canonical, accepted, or strategy authority."},
        "scope_notice": "READ_ONLY_REQUESTED_KNOWLEDGE_NO_AUTOMATIC_EA_ACTION",
        "automatic_actions": [], "test_verdict": None, "confidence_grade": None, "performance_grade": None,
    }


def offline_html(index: dict[str, Any], js: str, css: str) -> str:
    payload = json.dumps(index, ensure_ascii=False, separators=(",", ":")).replace("<", "\\u003c").replace("\u2028", "\\u2028").replace("\u2029", "\\u2029")
    return """<!doctype html><html lang=\"th\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><meta name=\"referrer\" content=\"no-referrer\"><title>EA_LAB Second Brain — Frozen Reader</title><style>""" + css + """</style></head><body><main id=\"knowledge-reader\"></main><script type=\"application/json\" id=\"knowledge-data\">""" + payload + """</script><script>""" + js + """\nwindow.EALabKnowledgeReader.mount(document.querySelector('#knowledge-reader'),{data:JSON.parse(document.querySelector('#knowledge-data').textContent),offline:true});</script></body></html>"""


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description="Exact-Git read-only Second Brain export/query")
    sub = root.add_subparsers(dest="command", required=True)
    build = sub.add_parser("build")
    build.add_argument("--repo", required=True, type=Path); build.add_argument("--ref", required=True)
    build.add_argument("--expected-sha", required=True); build.add_argument("--output", required=True, type=Path)
    build.add_argument("--prepared-packet", type=Path); build.add_argument("--prepared-manifest-sha256")
    export = sub.add_parser("export")
    export.add_argument("--repo", required=True, type=Path); export.add_argument("--ref", required=True)
    export.add_argument("--expected-sha", required=True); export.add_argument("--index", required=True, type=Path)
    export.add_argument("--output", required=True, type=Path)
    query = sub.add_parser("query")
    query.add_argument("--index", required=True, type=Path); query.add_argument("--question", required=True)
    query.add_argument("--output", required=True, type=Path)
    for field in ("ea", "variant", "build", "config", "symbol", "timeframe", "window", "data-source"):
        query.add_argument(f"--{field}")
    return root


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        if args.command == "build":
            result = build_index(args.repo.resolve(), args.ref, args.expected_sha, args.prepared_packet, args.prepared_manifest_sha256)
            write_json(args.output, result)
        elif args.command == "export":
            canonical = resolve_ref(args.repo.resolve(), args.ref, args.expected_sha)
            index = json.loads(args.index.read_text(encoding="utf-8"))
            if index.get("canonical", {}).get("sha") != canonical:
                raise ReaderError("index pin does not match export pin")
            tree = git_tree(args.repo.resolve(), canonical)
            assets = []
            for path in ASSET_PATHS:
                if path not in tree or tree[path] == "120000":
                    raise ReaderError(f"reader asset missing or symlinked: {path}")
                assets.append(git_bytes(args.repo.resolve(), canonical, path).decode("utf-8"))
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(offline_html(index, assets[0], assets[1]), encoding="utf-8")
        else:
            index = json.loads(args.index.read_text(encoding="utf-8"))
            if index.get("schema_version") != SCHEMA:
                raise ReaderError("unsupported or malformed index")
            intake = vars(args).copy(); intake["data_source"] = intake.pop("data_source", None)
            write_json(args.output, query_packet(index, args.question, intake))
    except (ReaderError, OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    print(json.dumps({"status": "OK", "command": args.command, "output": str(args.output)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
