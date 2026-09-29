from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
from datetime import datetime, timezone, timedelta

ROOT = Path(r"D:\EA_LAB_CONTROL\lnwjud-write-v1-20260928")
SNAPSHOT = ROOT / "snapshot"
REGISTRY_ROOT = Path(r"D:\EA_LAB_CONTROL\lanes\registry-v1")
JOBS_ROOT = Path(r"D:\EA_LAB_CONTROL\jobs")
EVIDENCE_ROOT = Path(r"D:\EA_LAB_CONTROL\evidence")
MONITOR_ROOT = Path(r"D:\OneDrive\Monitor")
DEFAULT_CANONICAL_ROOT = Path(r"D:\EA_LAB_CONTROL\lnwjud-write-v1-20260928\canonical")
MAX_FILE_BYTES = 1024 * 1024
EVIDENCE_HOURS = 96
MAX_JOBS = 1000
SAFE_EVIDENCE_EXTS = {
    ".json", ".jsonl", ".md", ".txt", ".log", ".csv", ".patch", ".diff",
    ".ps1", ".py", ".cjs", ".js", ".html", ".yaml", ".yml",
}
SENSITIVE_SEGMENT_RE = re.compile(
    r"(^|[-_.])(secret|credential|password|passwd|private[-_]?key|api[-_]?key|auth[-_]?token|access[-_]?token)([-_.]|$)",
    re.I,
)

def run_git(repo: Path, *args: str) -> str:
    cp = subprocess.run(
        ["git", "-C", str(repo), *args],
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if cp.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed rc={cp.returncode}: {cp.stderr.strip()}")
    return cp.stdout.strip()

def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        while True:
            chunk = fh.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

def write_json(path: Path, obj) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(obj, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    path.write_text(text, encoding="utf-8", newline="\n")

def normalize_rel(raw: str) -> str:
    p = raw.replace("\\", "/")
    while p.startswith("./"):
        p = p[2:]
    pp = PurePosixPath(p)
    if not p or pp.is_absolute() or any(part in ("", ".", "..") for part in pp.parts):
        raise ValueError(f"unsafe relative path: {raw!r}")
    return "/".join(pp.parts)

def forbidden_repo_path(rel: str) -> bool:
    lower = rel.lower()
    parts = [p for p in lower.split("/") if p]
    base = parts[-1] if parts else ""
    if base.startswith(".env"):
        return True
    if any(p in {".git", ".ssh", "credentials", "secrets"} for p in parts):
        return True
    if lower == "portfolio/accounts.csv":
        return True
    if lower == "portfolio/live_deals" or lower.startswith("portfolio/live_deals/"):
        return True
    return False

def forbidden_evidence_path(rel: str) -> bool:
    parts = [p for p in rel.replace("\\", "/").split("/") if p]
    if any(p.lower() in {".git", ".ssh", "credentials", "secrets"} for p in parts):
        return True
    return any(SENSITIVE_SEGMENT_RE.search(p) for p in parts)

def is_text_file(path: Path, size: int) -> bool:
    if size > MAX_FILE_BYTES:
        return False
    try:
        with path.open("rb") as fh:
            sample = fh.read(min(size, 8192))
    except OSError:
        return False
    return b"\x00" not in sample

def collect_canonical(root: Path, previous: dict | None = None) -> dict:
    head = run_git(root, "rev-parse", "HEAD")
    local_origin = run_git(root, "rev-parse", "origin/master")
    remote_line = run_git(root, "ls-remote", "origin", "refs/heads/master")
    remote = remote_line.split()[0] if remote_line else ""
    if not (head == local_origin == remote):
        raise RuntimeError(
            f"canonical binding mismatch head={head} origin/master={local_origin} ls-remote={remote}"
        )
    if isinstance(previous, dict) and previous.get("head") == head:
        tracked_dirty = run_git(root, "status", "--porcelain=v1", "--untracked-files=no")
        if not tracked_dirty and previous.get("root") == str(root.resolve()) and isinstance(previous.get("entries"), list):
            reused = dict(previous)
            reused["origin_master"] = local_origin
            reused["ls_remote"] = remote
            reused["manifest_reused"] = True
            return reused
    tracked = run_git(root, "ls-tree", "-r", "--name-only", "-z", head).split("\x00")
    entries = []
    denied = 0
    binary_or_large = 0
    for raw in tracked:
        if not raw:
            continue
        rel = normalize_rel(raw)
        if forbidden_repo_path(rel):
            denied += 1
            continue
        fp = root / Path(*rel.split("/"))
        try:
            st = fp.stat()
        except OSError:
            continue
        if not fp.is_file() or not is_text_file(fp, st.st_size):
            binary_or_large += 1
            continue
        entries.append({
            "path": rel,
            "path_key": rel.lower(),
            "bytes": st.st_size,
            "sha256": sha256_file(fp),
        })
    entries.sort(key=lambda x: x["path_key"])
    return {
        "root": str(root.resolve()),
        "head": head,
        "origin_master": local_origin,
        "ls_remote": remote,
        "entries": entries,
        "file_count": len(entries),
        "forbidden_count": denied,
        "binary_or_large_count": binary_or_large,
    }

def sanitize_lane(obj: dict) -> dict:
    keys = (
        "lane_id", "owner_chat", "worker", "objective", "state", "base_sha", "head_sha",
        "worktree", "branch", "runtime_lane", "writer", "dependencies", "reviewer",
        "reviewed_head", "direct_consumer", "blocker_class", "updated_at", "superseded_by",
    )
    return {k: obj.get(k) for k in keys if k in obj}

def collect_lanes() -> list[dict]:
    lanes = []
    for fp in sorted(REGISTRY_ROOT.glob("*.json")):
        try:
            obj = json.loads(fp.read_text(encoding="utf-8-sig"))
            if isinstance(obj, dict) and obj.get("lane_id"):
                lanes.append(sanitize_lane(obj))
        except Exception:
            continue
    lanes.sort(key=lambda x: (str(x.get("updated_at") or ""), str(x.get("lane_id") or "")), reverse=True)
    return lanes

def read_json_if(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except Exception:
        return None

def collect_jobs() -> list[dict]:
    rows = []
    if not JOBS_ROOT.exists():
        return rows
    for d in JOBS_ROOT.iterdir():
        if not d.is_dir():
            continue
        job = read_json_if(d / "job.json")
        state = read_json_if(d / "state.json")
        result = read_json_if(d / "result.json")
        if not isinstance(job, dict) and not isinstance(state, dict) and not isinstance(result, dict):
            continue
        job = job if isinstance(job, dict) else {}
        state = state if isinstance(state, dict) else {}
        result = result if isinstance(result, dict) else {}
        jid = str(job.get("job_id") or state.get("job_id") or result.get("job_id") or d.name)
        row = {
            "job_id": jid,
            "stage": job.get("stage"),
            "base_sha": job.get("base_sha"),
            "worktree": job.get("worktree"),
            "created_utc": job.get("created_utc"),
            "state": state.get("state") or result.get("state"),
            "started_utc": state.get("started_utc"),
            "ended_utc": state.get("ended_utc") or result.get("ended_utc"),
            "exit_code": result.get("exit_code") if "exit_code" in result else state.get("exit_code"),
            "postcondition_exit_code": result.get("postcondition_exit_code") if "postcondition_exit_code" in result else state.get("postcondition_exit_code"),
            "reason": result.get("reason") or state.get("reason"),
        }
        rows.append(row)
    rows.sort(key=lambda x: (str(x.get("created_utc") or ""), x["job_id"]), reverse=True)
    return rows[:MAX_JOBS]

def collect_evidence(now: datetime, previous: list[dict] | None = None) -> list[dict]:
    cutoff = now - timedelta(hours=EVIDENCE_HOURS)
    rows = []
    prev_map = {}
    if isinstance(previous, list):
        prev_map = {
            str(x.get("path_key")): x for x in previous
            if isinstance(x, dict) and x.get("path_key") and x.get("sha256")
        }
    if not EVIDENCE_ROOT.exists():
        return rows
    for fp in EVIDENCE_ROOT.rglob("*"):
        if not fp.is_file():
            continue
        try:
            rel = normalize_rel(fp.relative_to(EVIDENCE_ROOT).as_posix())
            st = fp.stat()
        except (OSError, ValueError):
            continue
        if forbidden_evidence_path(rel):
            continue
        if fp.suffix.lower() not in SAFE_EVIDENCE_EXTS:
            continue
        if st.st_size > MAX_FILE_BYTES:
            continue
        mtime = datetime.fromtimestamp(st.st_mtime, timezone.utc)
        if mtime < cutoff:
            continue
        mtime_iso = mtime.isoformat()
        key = rel.lower()
        prev = prev_map.get(key)
        if (
            isinstance(prev, dict)
            and prev.get("bytes") == st.st_size
            and prev.get("mtime_utc") == mtime_iso
        ):
            rows.append(dict(prev))
            continue
        if not is_text_file(fp, st.st_size):
            continue
        rows.append({
            "path": rel,
            "path_key": key,
            "bytes": st.st_size,
            "sha256": sha256_file(fp),
            "mtime_utc": mtime_iso,
        })
    rows.sort(key=lambda x: (x["mtime_utc"], x["path_key"]), reverse=True)
    return rows

def collect_monitor() -> dict:
    out = {
        "root": str(MONITOR_ROOT),
        "delivery_receipt": None,
        "inventory_summary": None,
    }
    receipt = MONITOR_ROOT / "MONITOR_APP_RECEIPT.json"
    inv = MONITOR_ROOT / "inventory" / "inventory_summary.json"
    if receipt.exists():
        out["delivery_receipt"] = read_json_if(receipt)
    if inv.exists():
        out["inventory_summary"] = read_json_if(inv)
    return out

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--canonical-root", default=str(DEFAULT_CANONICAL_ROOT))
    ns = ap.parse_args()
    canonical_root = Path(ns.canonical_root)
    now = datetime.now(timezone.utc)

    previous_canonical = read_json_if(SNAPSHOT / "canonical_manifest.json")
    previous_evidence = read_json_if(SNAPSHOT / "evidence_manifest.json")
    canonical = collect_canonical(canonical_root, previous_canonical if isinstance(previous_canonical, dict) else None)
    lanes = collect_lanes()
    jobs = collect_jobs()
    evidence = collect_evidence(now, previous_evidence if isinstance(previous_evidence, list) else None)
    monitor = collect_monitor()

    SNAPSHOT.mkdir(parents=True, exist_ok=True)
    canonical_path = SNAPSHOT / "canonical_manifest.json"
    lanes_path = SNAPSHOT / "lanes.json"
    jobs_path = SNAPSHOT / "jobs.json"
    evidence_path = SNAPSHOT / "evidence_manifest.json"
    monitor_path = SNAPSHOT / "monitor.json"

    write_json(canonical_path, canonical)
    write_json(lanes_path, lanes)
    write_json(jobs_path, jobs)
    write_json(evidence_path, evidence)
    write_json(monitor_path, monitor)

    component_hashes = {
        "canonical_manifest.json": sha256_file(canonical_path),
        "lanes.json": sha256_file(lanes_path),
        "jobs.json": sha256_file(jobs_path),
        "evidence_manifest.json": sha256_file(evidence_path),
        "monitor.json": sha256_file(monitor_path),
    }
    snapshot_material = json.dumps(
        {
            "canonical_head": canonical["head"],
            "captured_at_utc": now.isoformat(),
            "component_hashes": component_hashes,
        },
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    snapshot_id = sha256_bytes(snapshot_material)[:32]
    seal = {
        "schema_version": 1,
        "snapshot_id": snapshot_id,
        "captured_at_utc": now.isoformat(),
        "canonical_head": canonical["head"],
        "origin_master_at_capture": canonical["origin_master"],
        "ls_remote_at_capture": canonical["ls_remote"],
        "canonical_root": canonical["root"],
        "registry_root": str(REGISTRY_ROOT),
        "jobs_root": str(JOBS_ROOT),
        "evidence_root": str(EVIDENCE_ROOT),
        "monitor_root": str(MONITOR_ROOT),
        "component_hashes": component_hashes,
        "counts": {
            "canonical_files": canonical["file_count"],
            "lanes": len(lanes),
            "jobs": len(jobs),
            "evidence_files": len(evidence),
        },
        "authority": "READ_ONLY_CURRENT_SNAPSHOT_V2",
        "limitations": [
            "Point-in-time snapshot; currentness is bounded to captured_at_utc and exact canonical binding at capture.",
            "No write/process/shell/git-mutation/Registry-transition/MT5/trading authority.",
            f"Evidence index includes bounded text files modified in the last {EVIDENCE_HOURS} hours only.",
            f"Job index includes at most {MAX_JOBS} most recent durable jobs.",
        ],
    }
    seal_path = SNAPSHOT / "snapshot_seal.json"
    write_json(seal_path, seal)

    print(json.dumps({
        "result": "PASS",
        "snapshot_id": snapshot_id,
        "captured_at_utc": seal["captured_at_utc"],
        "canonical_head": canonical["head"],
        "counts": seal["counts"],
        "seal_path": str(seal_path),
        "seal_sha256": sha256_file(seal_path),
    }, indent=2))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
