# -*- coding: utf-8 -*-
"""Fail-closed staged guard for the append-only QI-1 record store."""
import io
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import qi_1 as qi  # noqa: E402


EXPERIMENT_PATH_RE = re.compile(
    r"^factory/experiments/exp_[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/contract\.json$")
RESULT_PATH_RE = re.compile(
    r"^factory/experiments/exp_[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/results/res_[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.json$")


def _git(root, *args):
    try:
        return subprocess.check_output(["git", "-C", root] + list(args), stderr=subprocess.STDOUT)
    except (OSError, subprocess.CalledProcessError) as exc:
        output = getattr(exc, "output", b"")
        detail = output.decode("utf-8", "replace").strip()
        raise RuntimeError("git %s failed%s" % (" ".join(args), (": " + detail) if detail else ""))


def _paths(root, *args):
    raw = _git(root, *args).decode("utf-8")
    return [line for line in raw.splitlines() if line]


def _blob(root, spec):
    return _git(root, "show", spec)


def _is_qi_path(path):
    return bool(EXPERIMENT_PATH_RE.fullmatch(path) or RESULT_PATH_RE.fullmatch(path))


def _check_immutability(root, head_paths, index_paths):
    problems = []
    index_set = set(index_paths)
    for path in head_paths:
        if path not in index_set:
            problems.append("established QI-1 record was deleted: %s" % path)
            continue
        if _blob(root, "HEAD:%s" % path) != _blob(root, ":%s" % path):
            problems.append("established QI-1 record was modified: %s" % path)
    return problems


def _materialize_index(root, index_paths, destination):
    for path in index_paths:
        target = os.path.join(destination, path.replace("/", os.sep))
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with io.open(target, "wb") as handle:
            handle.write(_blob(root, ":%s" % path))


def check_staged_store(root):
    root = os.path.abspath(root)
    staged_paths = _paths(root, "diff", "--cached", "--name-only", "--", "factory/experiments")
    if not staged_paths:
        return []
    index_paths = _paths(root, "ls-files", "--cached", "--", "factory/experiments")
    head_paths = _paths(root, "ls-tree", "-r", "--name-only", "HEAD", "--", "factory/experiments")
    problems = []
    for path in index_paths:
        if not _is_qi_path(path):
            problems.append("unexpected staged QI-1 path: %s" % path)
    for path in head_paths:
        if not _is_qi_path(path):
            problems.append("unexpected established QI-1 path: %s" % path)
    problems.extend(_check_immutability(root, head_paths, index_paths))
    if problems:
        return sorted(set(problems))

    with tempfile.TemporaryDirectory(prefix="qi1-staged-") as snapshot:
        _materialize_index(root, index_paths, snapshot)
        store_problems, _contracts, _results = qi.validate_store(snapshot, root)
        return sorted(set(store_problems))


def main(argv=None):
    argv = list(argv or sys.argv[1:])
    root = os.path.abspath(argv[0]) if argv else os.getcwd()
    try:
        problems = check_staged_store(root)
    except (OSError, RuntimeError, qi.QIValidationError, ValueError) as exc:
        problems = [str(exc)]
    if problems:
        for problem in problems:
            print("[FAIL] %s" % problem)
        print("QI-1 STAGED GUARD: FAIL")
        return 1
    print("QI-1 STAGED GUARD: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
