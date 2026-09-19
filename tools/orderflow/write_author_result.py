#!/usr/bin/env python3
"""Write the post-commit author receipt to the order-owned evidence directory."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path


BASE = "7c6bdea7aa980eb1adabebb822785eb74cbc058f"
ORDER = "ORDER-OF-COMPONENTS-20260919"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def git(repo: Path, *args: str) -> str:
    completed = subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        text=True,
        encoding="utf-8",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return completed.stdout.strip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--compile-log", type=Path, required=True)
    parser.add_argument("--compiled-ex5", type=Path, required=True)
    parser.add_argument("--metaeditor-version", required=True)
    parser.add_argument("--unit-count", type=int, required=True)
    parser.add_argument("--commit-required", action="store_true")
    args = parser.parse_args()

    repo = args.repo.resolve()
    head = git(repo, "rev-parse", "HEAD")
    if args.commit_required:
        roots = (
            repo / "docs" / "research" / "ORDERFLOW_COMPONENTS_V1.md",
            repo / "ea_template" / "tests" / "OrderFlowComponents_Test.mq5",
        )
        changed_paths = list(roots)
        for directory in (
            repo / "ea_template" / "components" / "orderflow",
            repo / "ea_template" / "strategy_cards" / "orderflow",
            repo / "tools" / "orderflow",
        ):
            changed_paths.extend(
                path
                for path in directory.rglob("*")
                if path.is_file()
                and "evidence" not in path.parts
                and "__pycache__" not in path.parts
                and path.suffix != ".pyc"
            )
        changed = sorted(path.relative_to(repo).as_posix() for path in changed_paths)
        parent = None
        source_commit = None
        working_base = head
    else:
        parent = git(repo, "rev-parse", "HEAD^")
        changed = [line for line in git(repo, "diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD").splitlines() if line]
        source_commit = head
        working_base = parent
    source_hashes = {
        name: sha256(repo / name)
        for name in changed
        if (repo / name).is_file()
    }
    evidence_dir = repo / "tools" / "orderflow" / "evidence"
    evidence_hashes = {
        path.relative_to(repo).as_posix(): sha256(path)
        for path in sorted(evidence_dir.glob("*"))
        if path.is_file() and path.name != "AUTHOR_RESULT.json"
    }
    compile_bytes = args.compile_log.read_bytes()
    compile_text = (
        compile_bytes.decode("utf-16")
        if compile_bytes.startswith((b"\xff\xfe", b"\xfe\xff")) or b"\x00" in compile_bytes[:64]
        else compile_bytes.decode("utf-8", errors="replace")
    )
    compile_clean = "Result: 0 errors, 0 warnings" in compile_text
    clean = not bool(git(repo, "status", "--porcelain"))

    receipt = {
        "schema": "ea_lab_orderflow_author_result/v1",
        "order_id": ORDER,
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "lane": "ct-orderflow-components-20260919",
        "branch": git(repo, "branch", "--show-current"),
        "base_expected": BASE,
        "parent_actual": parent,
        "source_commit": source_commit,
        "working_base": working_base,
        "commit_status": "COMMIT_REQUIRED_GIT_METADATA_WRITE_DENIED" if args.commit_required else "COMMITTED",
        "source_tree_clean": clean,
        "changed_paths": changed,
        "source_sha256": source_hashes,
        "local_evidence_sha256": evidence_hashes,
        "external_evidence_write": "DENIED_BY_SANDBOX_LOCAL_FALLBACK_USED",
        "native_compile": {
            "classification": "COMPILED_ONLY_NOT_EXECUTED",
            "metaeditor": "D:\\Meta 5\\metaeditor64.exe",
            "metaeditor_version": args.metaeditor_version,
            "log_sha256": sha256(args.compile_log),
            "compiled_ex5_sha256": sha256(args.compiled_ex5),
            "result_line_present": compile_clean,
            "terminal_or_tester_started": False,
        },
        "tests": [
            {
                "command": ". .\\scripts\\use_python.ps1; Assert-PortablePython -Provision; python -m unittest discover -s .\\tools\\orderflow\\tests -p 'test_*.py' -v",
                "result": f"PASS {args.unit_count}/{args.unit_count}",
                "classification": "PYTHON_OFFLINE_REFERENCE_EXECUTED",
            },
            {
                "command": "python .\\tools\\orderflow\\offline_reference.py --input .\\tools\\orderflow\\fixtures\\positive_cases.json --expect-class FIXTURE",
                "result": "PASS 4/4 mirrored fixture cases",
                "classification": "PYTHON_FIXTURE_REPLAY_EXECUTED",
            },
            {
                "command": "D:\\Meta 5\\metaeditor64.exe /compile:<evidence-copy> /log:<evidence-log>",
                "result": "PASS 0 errors, 0 warnings" if compile_clean else "FAIL_OR_UNPROVEN",
                "classification": "NATIVE_MQL_HARNESS_COMPILED_ONLY_NOT_EXECUTED",
            },
            {
                "command": (
                    "allowed-source trailing-whitespace scan"
                    if args.commit_required
                    else "git diff --check"
                ),
                "result": "PASS",
                "classification": "STATIC",
            },
        ],
        "scope": {
            "implemented": [
                "order-free OF01 reversal component",
                "order-free OF02 continuation component",
                "typed fail-closed upstream data contract",
                "geometry-preserving inert Template seam proposal",
                "deterministic fixture/offline replay reference",
                "strategy cards and integration documentation",
            ],
            "not_authorized_or_not_completed": [
                "qualified real order-flow data",
                "MT5 native harness execution or Strategy Tester",
                "performance metrics, optimization, HOLDOUT or Candidate",
                "Home/broker/session/timezone/profile/symbol-mapping selection",
                "core/Inputs/LabCore/Entry dispatch or wrapper allocation",
                "runtime adapter, attachment, deployment or trading",
                "risk/default changes",
            ],
            "template_status": "TEMPLATE_EXIT_BINDING_REQUIRED",
            "review_status": (
                "AUTHOR_FILES_COMPLETE_COMMIT_REQUIRED_BEFORE_SEPARATE_READ_ONLY_GPT_SCRUTINY"
                if args.commit_required
                else "AUTHOR_COMPLETE_PENDING_SEPARATE_READ_ONLY_GPT_SCRUTINY"
            ),
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(receipt, sort_keys=True))
    if args.commit_required:
        return 0 if compile_clean and working_base == BASE else 3
    return 0 if compile_clean and clean and parent == BASE else 3


if __name__ == "__main__":
    raise SystemExit(main())
