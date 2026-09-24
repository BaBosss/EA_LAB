"""Fail-closed input parsing, schema subset and pinned file identities.

Only the trusted launcher imports this module. None of these functions are tools.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import stat


class Refusal(ValueError):
    pass


def require(condition, reason):
    if not condition:
        raise Refusal(reason)


def sha256(raw):
    return hashlib.sha256(raw).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=True, allow_nan=False).encode("ascii")


def strict_json(raw, limit=1048576, depth=20):
    require(type(raw) is bytes and 0 < len(raw) <= limit, "JSON_SIZE")
    require(b"\0" not in raw, "RAW_NUL")
    try:
        text = raw.decode("utf-8", errors="strict")
        # Bound nesting before allocating a recursive JSON structure.
        level = 0
        quoted = escaped = False
        for char in text:
            if quoted:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    quoted = False
            elif char == '"':
                quoted = True
            elif char in "[{":
                level += 1
                require(level <= depth, "JSON_DEPTH")
            elif char in "]}":
                level -= 1

        def pairs(items):
            result = {}
            for key, value in items:
                require(key not in result, "DUPLICATE_KEY")
                result[key] = value
            return result

        def constant(_):
            raise Refusal("NONFINITE_NUMBER")

        value = json.loads(text, object_pairs_hook=pairs, parse_constant=constant)

        def walk(item):
            if isinstance(item, str):
                require("\0" not in item, "DECODED_NUL")
                item.encode("utf-8", "strict")
            elif isinstance(item, dict):
                for key, child in item.items():
                    walk(key)
                    walk(child)
            elif isinstance(item, list):
                for child in item:
                    walk(child)
        walk(value)
        return value
    except (UnicodeError, json.JSONDecodeError, RecursionError) as exc:
        raise Refusal("INVALID_JSON") from exc


def validate(value, schema):
    """Closed, deliberately small JSON Schema vocabulary; no remote refs/code.

    All shipped schemas use ONLY these keywords. Unknown keywords fail closed.
    This is not advertised as a general JSON Schema implementation.
    """
    supported = {"$schema", "title", "type", "properties", "required",
                 "additionalProperties", "items", "minItems", "maxItems",
                 "minimum", "maximum", "minLength", "maxLength", "pattern",
                 "enum", "const"}
    require(isinstance(schema, dict) and set(schema) <= supported, "SCHEMA_KEYWORD")
    kinds = {"object": type(value) is dict, "array": type(value) is list,
             "string": type(value) is str, "integer": type(value) is int,
             "boolean": type(value) is bool, "null": value is None}
    types = schema.get("type", list(kinds))
    if isinstance(types, str):
        types = [types]
    require(any(kinds.get(t, False) for t in types), "SCHEMA_TYPE")
    if "const" in schema:
        require(canonical(value) == canonical(schema["const"]), "SCHEMA_CONST")
    if "enum" in schema:
        require(any(type(value) is type(x) and value == x for x in schema["enum"]), "SCHEMA_ENUM")
    if type(value) is dict:
        props = schema.get("properties", {})
        require(set(schema.get("required", [])) <= set(value), "SCHEMA_REQUIRED")
        if schema.get("additionalProperties") is False:
            require(set(value) <= set(props), "SCHEMA_UNKNOWN_FIELD")
        for key, child in value.items():
            if key in props:
                validate(child, props[key])
    if type(value) is list:
        require(schema.get("minItems", 0) <= len(value) <= schema.get("maxItems", 100000), "SCHEMA_ARRAY_SIZE")
        for child in value:
            validate(child, schema.get("items", {}))
    if type(value) is str:
        require(schema.get("minLength", 0) <= len(value) <= schema.get("maxLength", 1048576), "SCHEMA_STRING_SIZE")
        if "pattern" in schema:
            require(re.fullmatch(schema["pattern"], value) is not None, "SCHEMA_PATTERN")
    if type(value) is int:
        require(schema.get("minimum", -2**63) <= value <= schema.get("maximum", 2**63-1), "SCHEMA_NUMBER")


def relative_path(value):
    require(type(value) is str and 0 < len(value) <= 240, "PATH_TYPE")
    require(not any(c in value for c in "\\:\0"), "PATH_DEVICE_ADS")
    parts = value.split("/")
    for part in parts:
        require(part not in ("", ".", "..") and not part.endswith((" ", ".")), "PATH_TRAVERSAL")
        require(not re.search(r'[<>"|?*\x00-\x1f]', part), "PATH_CHARACTER")
        require(not re.fullmatch(r"(?i)(con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\..*)?", part), "PATH_DEVICE")
    return parts


def identity(path):
    st = os.lstat(path)
    require(not stat.S_ISLNK(st.st_mode) and not getattr(st, "st_file_attributes", 0) & 0x400, "REPARSE_OR_SYMLINK")
    require(st.st_ino != 0, "IDENTITY_UNAVAILABLE")
    return {"device": st.st_dev, "inode": st.st_ino}


def local_root(path):
    p = Path(path)
    require(p.is_absolute() and not str(p).startswith(("\\\\", "//")), "ROOT_UNC_OR_RELATIVE")
    require(".." not in p.parts, "ROOT_TRAVERSAL")
    if os.name == "nt":
        require(re.fullmatch(r"[A-Za-z]:\\.*", str(p)) is not None, "ROOT_DEVICE")
        require(":" not in str(p)[2:], "ROOT_ADS")
    for parent in reversed((p, *p.parents)):
        identity(parent)
    require(p.is_dir(), "ROOT_NOT_DIRECTORY")
    require(os.path.normcase(str(p.resolve())) == os.path.normcase(str(p)), "ROOT_SUBSTITUTION")
    return p


class Pins:
    """Keep Windows directory/file handles open without FILE_SHARE_DELETE/WRITE.

    Directories disallow delete/rename, files disallow write/delete. On other OSes
    no equivalent guarantee is claimed: production preflight refuses them.
    """
    def __init__(self):
        self.handles = []

    def pin(self, path, directory=False):
        require(os.name == "nt", "WINDOWS_PINNING_REQUIRED")
        import ctypes
        from ctypes import wintypes
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                      wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
        kernel.CreateFileW.restype = wintypes.HANDLE
        handle = kernel.CreateFileW(str(path), 0x80000000, 3 if directory else 1,
                                    None, 3, 0x02200000 if directory else 0x00200000, None)
        require(handle != wintypes.HANDLE(-1).value, "PIN_OPEN_FAILED")
        self.handles.append(handle)
        # Bind the opened handle itself, not only the path queried afterwards.
        class Information(ctypes.Structure):
            _fields_ = [("attributes", wintypes.DWORD), ("created", wintypes.FILETIME),
                        ("accessed", wintypes.FILETIME), ("modified", wintypes.FILETIME),
                        ("volume", wintypes.DWORD), ("size_high", wintypes.DWORD),
                        ("size_low", wintypes.DWORD), ("links", wintypes.DWORD),
                        ("index_high", wintypes.DWORD), ("index_low", wintypes.DWORD)]
        kernel.GetFileInformationByHandle.argtypes = [wintypes.HANDLE, ctypes.POINTER(Information)]
        info = Information()
        require(kernel.GetFileInformationByHandle(handle, ctypes.byref(info)), "HANDLE_IDENTITY_UNAVAILABLE")
        require(not info.attributes & 0x400, "HANDLE_REPARSE")
        current = os.lstat(path)
        require(current.st_ino == (info.index_high << 32 | info.index_low)
                and (current.st_dev & 0xffffffff) == info.volume, "HANDLE_PATH_IDENTITY")
        require(bool(info.attributes & 0x10) == directory, "HANDLE_KIND")
        if not directory:
            require(info.links == 1, "HANDLE_HARDLINK")
        identity(path)

    def root(self, path, expected):
        p = local_root(path)
        for parent in reversed((p, *p.parents)):
            self.pin(parent, directory=True)
        require(identity(p) == expected, "ROOT_IDENTITY")
        return p

    def read(self, root, relative, maximum, expected=None):
        parts = relative_path(relative)
        p = root
        for part in parts[:-1]:
            p = p / part
            self.pin(p, directory=True)
            require(p.is_dir(), "PARENT_NOT_DIRECTORY")
        p = p / parts[-1]
        self.pin(p)
        before = os.lstat(p)
        require(stat.S_ISREG(before.st_mode) and before.st_nlink == 1, "NONREGULAR_OR_HARDLINK")
        require(before.st_size <= maximum, "FILE_SIZE")
        if expected is not None:
            require(identity(p) == expected, "FILE_IDENTITY")
        with p.open("rb") as stream:
            raw = stream.read(maximum + 1)
        after = os.lstat(p)
        stable = lambda st: (st.st_dev, st.st_ino, st.st_size, st.st_mtime_ns, st.st_nlink)
        require(len(raw) == before.st_size and stable(after) == stable(before), "FILE_CHANGED")
        return raw

    def close(self):
        if self.handles:
            import ctypes
            from ctypes import wintypes
            kernel = ctypes.WinDLL("kernel32", use_last_error=True)
            kernel.CloseHandle.argtypes = [wintypes.HANDLE]
            for handle in reversed(self.handles):
                kernel.CloseHandle(handle)
            self.handles.clear()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()


def inventory(root, excluded=(), include_directories=False):
    found = []
    folded = set()

    def enumeration_error(exc):
        raise Refusal("INVENTORY_ENUMERATION_FAILED") from exc

    for current, dirs, files in os.walk(root, followlinks=False, onerror=enumeration_error):
        require(len(folded) + len(dirs) + len(files) <= 20000, "INVENTORY_CAPACITY")
        for name in dirs + files:
            p = Path(current) / name
            rel = p.relative_to(root).as_posix()
            relative_path(rel)
            identity(p)
            require(rel.casefold() not in folded, "CASE_COLLISION")
            folded.add(rel.casefold())
        dirs[:] = [d for d in dirs if (Path(current) / d).relative_to(root).as_posix() not in excluded]
        if include_directories:
            found.extend((Path(current) / d).relative_to(root).as_posix() + "/" for d in dirs)
        for name in files:
            rel = (Path(current) / name).relative_to(root).as_posix()
            if not any(rel == x or rel.startswith(x + "/") for x in excluded):
                found.append(rel)
    return sorted(found)


def unique(items, key):
    values = [item[key].casefold() for item in items]
    require(len(values) == len(set(values)), "DUPLICATE_INVENTORY")


def load_schema(name):
    return strict_json((Path(__file__).parent / "schemas" / (name + ".schema.json")).read_bytes())
