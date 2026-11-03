#!/usr/bin/env python3
"""Read-only full-preset coverage and local quoted-include input placement check.

The scan models local #ifdef/#ifndef/#else and object-like #define reachability.
SDK <...> includes are reported but NOT read; their macros/declarations, compiler
builtins and macro expansion are outside this static check. Native report-input
comparison is still required: this is not a claim of full compiler equivalence.
"""
import argparse
import json
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "_triage/factory_os"))
import preset


_DIRECTIVE = re.compile(r'^\s*#\s*([A-Za-z_]\w*)\b(.*)$')
_IDENTIFIER = re.compile(r'^[A-Za-z_]\w*$')
_COMMENTS = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|//[^\n]*|/\*[\s\S]*?(?:\*/|$)')


def _without_comments(text):
    def replace(match):
        token = match.group()
        if not token.startswith(("//", "/*")):
            return token
        if token.startswith("/*") and not token.endswith("*/"):
            raise preset.PresetRefusal("unterminated block comment")
        return re.sub(r'[^\n]', ' ', token)
    return _COMMENTS.sub(replace, text)


def local_input_surface(root, wrapper, build, canonical):
    """Expand a bounded local graph; delegate ALL input/enum parsing to preset.

    Limits bound accidental cycles/expansion: 64 nesting levels, 512 include
    visits, 200,000 visited lines and 8 MiB per file. Quoted paths must remain
    inside ea_template after resolution (including symlinks). No SDK fallback.
    """
    boundary = (root / "ea_template").resolve()
    defined, lines, origins, sdk = set(), [], [], []
    visits, visited_lines = 0, 0
    inputs_seen = False

    def location(path, number):
        return "%s:%d" % (path.relative_to(root).as_posix(), number)

    def walk(path, chain):
        nonlocal visits, visited_lines, inputs_seen
        path = path.resolve()
        if not path.is_relative_to(boundary):
            raise preset.PresetRefusal("quoted include leaves ea_template: " + str(path))
        if path in chain:
            raise preset.PresetRefusal("circular quoted include: " + str(path.relative_to(root)))
        visits += 1
        if len(chain) >= 64 or visits > 512:
            raise preset.PresetRefusal("local include graph exceeds depth/visit limit at " + str(path))
        try:
            if path.stat().st_size > 8 * 1024 * 1024:
                raise preset.PresetRefusal("local include exceeds 8 MiB: " + str(path))
            text = _without_comments(path.read_text(encoding="utf-8-sig"))
        except (OSError, UnicodeError, preset.PresetRefusal) as error:
            raise preset.PresetRefusal("cannot scan %s: %s" % (path, error)) from error
        if path == canonical:
            inputs_seen = True
        frames = []
        for number, line in enumerate(text.splitlines(), 1):
            visited_lines += 1
            if visited_lines > 200000:
                raise preset.PresetRefusal("local include graph exceeds line limit at " + location(path, number))
            here = location(path, number)
            directive = _DIRECTIVE.match(line)
            active = all(frame[0] for frame in frames)
            if directive:
                command, argument = directive.group(1), directive.group(2).strip()
                if command in ("ifdef", "ifndef"):
                    if not _IDENTIFIER.fullmatch(argument):
                        raise preset.PresetRefusal("%s: unsupported #%s operand %r" % (here, command, argument))
                    condition = argument in defined
                    frames.append([condition if command == "ifdef" else not condition, False])
                    continue
                if command == "else":
                    if argument or not frames or frames[-1][1]:
                        raise preset.PresetRefusal(here + ": unmatched/repeated #else")
                    frames[-1][0] = not frames[-1][0]
                    frames[-1][1] = True
                    continue
                if command == "endif":
                    if argument or not frames:
                        raise preset.PresetRefusal(here + ": unmatched #endif")
                    frames.pop()
                    continue
                # These cannot be ignored even in inactive text: their nesting
                # or macro semantics are outside this deliberately small model.
                if command not in ("define", "include", "property"):
                    raise preset.PresetRefusal("%s: unsupported #%s directive" % (here, command))
                if not active:
                    continue
                if line.rstrip().endswith("\\"):
                    raise preset.PresetRefusal(here + ": unsupported directive continuation")
                if command == "define":
                    name = argument.split(None, 1)[0] if argument else ""
                    if not _IDENTIFIER.fullmatch(name):
                        raise preset.PresetRefusal(here + ": unsupported function-like/malformed #define")
                    defined.add(name)
                elif command == "include":
                    quoted = re.fullmatch(r'"([^"\n]+)"', argument)
                    external = re.fullmatch(r'<([^<>\n]+)>', argument)
                    if quoted:
                        target = path.parent / quoted.group(1).replace("\\", "/")
                        try:
                            walk(target, chain + (path,))
                        except preset.PresetRefusal as error:
                            raise preset.PresetRefusal("%s: #include %s: %s" % (here, argument, error)) from error
                    elif external:
                        sdk.append({"include": argument, "at": here})
                    else:
                        raise preset.PresetRefusal(here + ": unsupported #include " + argument)
                continue
            if line.lstrip().startswith("#"):
                raise preset.PresetRefusal(here + ": malformed/unsupported preprocessor directive")
            if active:
                lines.append(line)
                origins.append(here)
        if frames:
            raise preset.PresetRefusal(str(path.relative_to(root)) + ": unclosed #ifdef/#ifndef")

    walk(wrapper, ())
    if not inputs_seen:
        raise preset.PresetRefusal("wrapper local graph never includes canonical ea_template/core/Inputs.mqh")
    # Reachability has already been evaluated. The synthetic, empty guard only
    # provides parse_surface's required build identity (validated on Inputs above).
    text = "#ifndef %s\n#endif\n%s" % (build, "\n".join(lines))
    mapped = ["<build identity>", "<build identity>"] + origins
    try:
        surface = preset.parse_surface(text, build)
    except preset.PresetRefusal as error:
        message = str(error)
        message = re.sub(r'lines (\d+) and (\d+)', lambda m: "locations %s and %s" % (mapped[int(m[1])-1], mapped[int(m[2])-1]), message)
        message = re.sub(r'line (\d+)', lambda m: mapped[int(m[1])-1], message)
        raise preset.PresetRefusal(message) from error
    # Refuse shapes the existing input parser does not recognize instead of
    # silently treating sinput/multiline/multiple declarations as absent.
    recognized = {decl.line for decl in surface.inputs}
    for number, line in enumerate(lines, 3):
        code = re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '', line)
        group = re.fullmatch(r'\s*input\s+group\s+"(?:\\.|[^"\\])*"\s*;?\s*', line)
        if re.search(r'\b(?:sinput|input)\b', code) and not group:
            if number not in recognized or code.count(";") != 1:
                raise preset.PresetRefusal(mapped[number-1] + ": unsupported input declaration: " + line.strip())
    outside = [{"key": decl.name, "at": mapped[decl.line-1]} for decl in surface.inputs
               if mapped[decl.line-1].rsplit(":", 1)[0] != canonical.relative_to(root).as_posix()]
    return surface, outside, sdk


def read_set(path):
    raw = Path(path).read_bytes()
    text = raw.decode("utf-16") if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else raw.decode("utf-8-sig")
    values, errors = {}, []
    for number, line in enumerate(text.splitlines(), 1):
        line = line.strip()
        if not line or line.startswith((";", "#")):
            continue
        if "=" not in line:
            errors.append("line %d has no assignment" % number)
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        # MT5 optimization suffix: only the first item is the effective value.
        value = value.split("||", 1)[0].strip()
        if key in values:
            errors.append("duplicate key: " + key)
        values[key] = value
    return values, errors


def audit(root, overrides=None, only=None):
    root = Path(root).resolve()
    overrides = overrides or {}
    source = (root / "ea_template/core/Inputs.mqh").read_text(encoding="utf-8-sig")
    results = []
    if only:
        # --only audits exactly the named builds (the launcher checks the one it optimizes), resolved
        # as ea_template/<name>.mq5 so non-Boss template wrappers (Probe_*) are covered too; a name
        # with no wrapper file is refused, never silently dropped.
        wrappers = []
        for name in sorted(only):
            candidate = root / "ea_template" / (name + ".mq5")
            if re.fullmatch(r"[A-Za-z0-9_.-]+", name) and candidate.is_file():
                wrappers.append(candidate)
            else:
                results.append({"expert": name, "errors": ["--only names no ea_template wrapper"], "ok": False})
    else:
        wrappers = sorted((root / "ea_template").glob("Boss_*.mq5"))
    names = {wrapper.stem for wrapper in wrappers}
    for unknown in sorted(set(overrides) - names):
        results.append({"expert": unknown, "errors": ["preset override has no discovered Boss wrapper"], "ok": False})
    if not wrappers and not results:
        results.append({"expert": "<discovery>", "errors": ["no Boss wrappers found"], "ok": False})
    for wrapper in wrappers:
        row = {"expert": wrapper.stem, "errors": [], "missing": [], "extra": [], "invalid": []}
        path = Path(overrides.get(wrapper.stem, root / ("ea_template/sets/regression/" + wrapper.stem + "_defaults.set")))
        row["preset"] = str(path)
        try:
            tags = re.findall(r"^\s*#define\s+(LAB_ENTRY_\d+)\b", wrapper.read_text(encoding="utf-8-sig"), re.M)
            if len(tags) != 1:
                raise ValueError("wrapper must declare exactly one LAB_ENTRY tag")
            try:
                surface = preset.parse_surface(source, tags[0])
            except preset.PresetRefusal as error:
                raise preset.PresetRefusal(preset.INPUTS_REL + ": " + str(error)) from error
            row["build"] = tags[0]
            row["expected_count"] = len(surface.inputs)
            # Keep the ordinary full-preset validation even when graph scanning
            # fails: the placement guard must never weaken missing/extra/value checks.
            values, set_errors = read_set(path)
            row["errors"].extend(set_errors)
            row["held_count"] = len(values)
            row["missing"] = sorted(set(surface.by_name) - set(values))
            row["extra"] = sorted(set(values) - set(surface.by_name))
            for key in sorted(set(values) & set(surface.by_name)):
                try:
                    preset.render_value(surface.by_name[key], values[key], surface.enums)
                except (preset.PresetRefusal, ValueError, TypeError, OverflowError) as error:
                    row["invalid"].append({"key": key, "error": str(error)})
            actual, outside, sdk = local_input_surface(root, wrapper, tags[0], (root / preset.INPUTS_REL).resolve())
            row["local_graph_input_count"] = len(actual.inputs)
            row["outside_inputs"] = outside
            row["unscanned_sdk_includes"] = sdk
            row["scan_scope"] = "local quoted includes only; SDK/external macros and declarations unscanned; not compiler equivalence"
            for declaration in outside:
                row["errors"].append("active input %s at %s is outside canonical %s" % (declaration["key"], declaration["at"], preset.INPUTS_REL))
            if set(actual.by_name) - {decl["key"] for decl in outside} != set(surface.by_name):
                row["errors"].append("local graph and canonical input surfaces disagree")
        except (OSError, UnicodeError, ValueError, preset.PresetRefusal) as error:
            row["errors"].append(str(error))
        row["ok"] = not any(row[key] for key in ("errors", "missing", "extra", "invalid"))
        results.append(row)
    return results


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--preset", action="append", default=[], metavar="EXPERT=PATH", help="effective caller-selected preset; unspecified builds use their defaults.set")
    parser.add_argument("--only", action="append", default=[], metavar="EXPERT", help="audit only these builds (default: every Boss wrapper)")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    overrides = {}
    for spec in args.preset:
        name, separator, path = spec.partition("=")
        if not separator or not name or not path or name in overrides:
            parser.error("each --preset must be a unique EXPERT=PATH")
        overrides[name] = path
    try:
        results = audit(args.root, overrides, set(args.only))
    except (OSError, UnicodeError) as error:
        results = [{"expert": "<source>", "errors": [str(error)], "ok": False}]
    if args.json:
        print(json.dumps(results, indent=2))
    else:
        print("Static scope: local quoted includes only; SDK/external macros and declarations unscanned; not compiler equivalence.")
        for row in results:
            print("[%s] %s preset coverage: missing=%d extra=%d invalid=%d errors=%d" % ("OK" if row["ok"] else "FAIL", row["expert"], len(row.get("missing", [])), len(row.get("extra", [])), len(row.get("invalid", [])), len(row["errors"])))
            for key in ("missing", "extra", "invalid", "errors"):
                if row.get(key):
                    print("  %s: %s" % (key, row[key]))
            if row.get("unscanned_sdk_includes"):
                print("  unscanned_sdk_includes: %s" % row["unscanned_sdk_includes"])
    return 0 if results and all(row["ok"] for row in results) else 1


if __name__ == "__main__":
    sys.exit(main())
