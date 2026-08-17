"""Standalone CLI entry point for the Control Tower Relay bridge.

Repo convention: the bundled ``tools/python312`` embeddable interpreter does
not add a script's own directory, or ``PYTHONPATH``, to ``sys.path`` (its
``python312._pth`` takes exclusive control). Every runnable entry point in
this repo bootstraps ``sys.path`` itself before importing its package -- see
``_triage/factory_os/*.py`` for the same pattern. This file is that
bootstrap for the relay bridge; ``bridge.py`` itself stays a normal package
module with ordinary relative imports.
"""

import os
import sys

_TOOLS_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _TOOLS_DIR not in sys.path:
    sys.path.insert(0, _TOOLS_DIR)

from codex_relay.bridge import _main  # noqa: E402  (import after sys.path bootstrap)

if __name__ == "__main__":
    raise SystemExit(_main(sys.argv[1:]))
