from __future__ import annotations

import json
import sys
from pathlib import Path

PACKAGE_ROOT = Path(__file__).resolve().parent
if str(PACKAGE_ROOT) not in sys.path:
    sys.path.insert(0, str(PACKAGE_ROOT))

from integrity import MANIFEST_PATH, build_manifest, canonical_json_bytes


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    manifest = build_manifest(repo_root)
    path = repo_root / MANIFEST_PATH
    path.write_bytes(canonical_json_bytes(manifest))
    print(
        json.dumps(
            {
                "status": "CREATED",
                "path": MANIFEST_PATH,
                "runtime_file_count": len(manifest["runtime_files"]),
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
