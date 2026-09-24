"""One-shot reader CLI. Sanitized stdout or one exclusively created derived JSON."""
from __future__ import annotations
import argparse
import json
import os
import sys
from pathlib import Path
from .builder import BuildRequest, build_observations
from .safe import Refused, checked_path


class SafeParser(argparse.ArgumentParser):
    def error(self, message):
        raise Refused("CLI_ARGUMENT_INVALID")


def main(argv=None) -> int:
    try:
        parser = SafeParser(description=__doc__)
        for arg in ("repo", "ref", "ledgers", "snapshots", "runtime"):
            parser.add_argument("--" + arg, required=True)
        parser.add_argument("--as-of")
        parser.add_argument("--output")
        args = parser.parse_args(argv)
        request = BuildRequest(Path(args.repo), args.ref, Path(args.ledgers), Path(args.snapshots), Path(args.runtime), args.as_of)
        output = None
        if args.output:
            root = Path(args.repo).absolute() / "build" / "ea_observation_adapters_v1" / "continuation-20260924"
            output = checked_path(Path(args.output), root, missing_leaf=True)
            if output.suffix != ".json" or output.exists():
                raise Refused("OUTPUT_MUST_BE_NEW_DERIVED_JSON")
        result = build_observations(request).to_dict()
        payload = json.dumps(result, ensure_ascii=True, allow_nan=False, sort_keys=True, indent=2) + "\n"
        if output is None:
            print(payload, end="")
        else:
            checked_path(output, root, missing_leaf=True)
            flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
            with os.fdopen(os.open(output, flags, 0o600), "w", encoding="utf-8", newline="\n") as stream:
                stream.write(payload)
            print(json.dumps({"disposition": "OBSERVATIONS_WRITTEN", "errors": len(result["errors"]), "real_data_qualified": False}))
        return 0
    except Refused as exc:
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        return 2
    except (OSError, ValueError, TypeError, KeyError, OverflowError, RecursionError):
        print('{"error":"SOURCE_OR_OUTPUT_INVALID"}', file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
