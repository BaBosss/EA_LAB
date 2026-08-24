"""Executable package entrypoint for the EA_LAB Harness v1 CLI."""

import pathlib
import sys


sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from harness import main  # noqa: E402


raise SystemExit(main())
