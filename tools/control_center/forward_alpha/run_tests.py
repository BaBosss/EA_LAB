"""Stable offline suite/compile runner, including optional impacted owner tests."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))


if __name__ == "__main__":
    paths = sorted(Path(__file__).parent.glob("*.py"))
    for path in paths:
        compile(path.read_bytes(), str(path), "exec")
    print(f"Compiled {len(paths)} Python files", flush=True)
    names = ["tools.control_center.forward_alpha.test_sidecar"]
    if "--impacted" in sys.argv:
        names = ["tools.control_center.fixtures.test_contracts",
                 "tools.control_center.research_catalog.test_catalog"]
    suite = unittest.defaultTestLoader.loadTestsFromNames(names)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    sys.exit(0 if result.wasSuccessful() and result.testsRun else 1)
