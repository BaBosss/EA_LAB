"""Trusted exporter. SealedSnapshot contains bytes, never live host handles."""
from dataclasses import dataclass
import hashlib
from pathlib import Path
from types import MappingProxyType
import zlib

from preflight import canonical, identity, inventory, relative_path, require, sha256, unique


@dataclass(frozen=True)
class SealedSnapshot:
    manifest_bytes: bytes
    entries: object

    @property
    def manifest_sha256(self):
        return sha256(self.manifest_bytes)


def oid(kind, raw, object_format):
    header = kind.encode("ascii") + b" " + str(len(raw)).encode("ascii") + b"\0"
    return hashlib.new(object_format, header + raw).hexdigest()


def head(pins, repo):
    """Read only local HEAD/ref bytes; never resolve a revision via a shell."""
    git = repo / ".git"
    require(git.is_dir() and not git.is_symlink(), "EXTERNAL_GIT_DIR")
    raw = pins.read(repo, ".git/HEAD", 1024).decode("ascii").strip()
    if raw.startswith("ref: "):
        ref = raw[5:]
        relative_path(ref)
        require(ref.startswith("refs/heads/"), "HEAD_REF")
        # Packed-only refs require a fresh standalone loose-object export.
        raw = pins.read(repo, ".git/" + ref, 1024).decode("ascii").strip()
    require(len(raw) in (40, 64) and all(c in "0123456789abcdef" for c in raw), "HEAD_OID")
    return raw


def git_safety(pins, repo, object_format):
    git = repo / ".git"
    require(git.is_dir(), "EXTERNAL_GIT_DIR")
    for bad in ("commondir", "objects/info/alternates", "objects/info/http-alternates", "shallow"):
        require(not (git / bad).exists(), "GIT_EXTERNAL_OR_PARTIAL")
    for bad in ("refs/replace", "objects/pack"):
        p = git / bad
        require(not p.exists() or not any(p.iterdir()), "GIT_REPLACE_OR_PACKED")
    # Pin every Git metadata/object file; forbid hidden reparse/hardlinks even
    # outside requested objects. No program is invoked and no config is executed.
    for rel in inventory(git):
        pins.read(repo, ".git/" + rel, 16 * 1024 * 1024)
    config = pins.read(repo, ".git/config", 65536).decode("utf-8", "strict").lower()
    require(not any(token in config for token in
                    ("promisor", "partialclone", "alternates", "include", "worktree", "replace")), "GIT_CONFIG_EXTERNAL")
    require(("objectformat = sha256" in config or "objectformat=sha256" in config)
            == (object_format == "sha256"), "GIT_OBJECT_FORMAT")


def read_object(pins, repo, spec, object_format, limit):
    object_id = spec["oid"]
    require(len(object_id) == (40 if object_format == "sha1" else 64), "GIT_OID_LENGTH")
    packed = pins.read(repo, ".git/objects/" + object_id[:2] + "/" + object_id[2:], limit + 65536)
    decoder = zlib.decompressobj()
    raw = decoder.decompress(packed, limit + 128)
    require(decoder.eof and not decoder.unused_data and not decoder.unconsumed_tail, "GIT_DECOMPRESSION_BOUND")
    header, separator, data = raw.partition(b"\0")
    require(separator and header == spec["type"].encode() + b" " + str(len(data)).encode(), "GIT_OBJECT_HEADER")
    require(len(data) <= limit, "GIT_OBJECT_CAPACITY")
    require(len(data) == spec["size"] and sha256(data) == spec["sha256"], "GIT_OBJECT_BYTES")
    require(oid(spec["type"], data, object_format) == object_id, "GIT_OBJECT_IDENTITY")
    return data


def parse_tree(raw, object_format):
    width = 20 if object_format == "sha1" else 32
    result = {}
    while raw:
        header, separator, rest = raw.partition(b"\0")
        require(separator and len(rest) >= width, "GIT_TREE_ENCODING")
        mode, separator, name = header.partition(b" ")
        require(separator and mode in (b"40000", b"100644", b"100755"), "GIT_TREE_LINK_OR_MODE")
        name = name.decode("utf-8", "strict")
        require(len(relative_path(name)) == 1, "GIT_TREE_NAME")
        require(name.casefold() not in {n.casefold() for n in result}, "GIT_TREE_CASE_COLLISION")
        result[name] = ("tree" if mode == b"40000" else "blob", rest[:width].hex())
        raw = rest[width:]
    return result


def export(contract, pins):
    repo = pins.root(contract["source_root"], contract["source_root_identity"])
    evidence = pins.root(contract["evidence_root"], contract["evidence_root_identity"])
    require(repo != evidence and repo not in evidence.parents and evidence not in repo.parents, "ROOT_OVERLAP")
    observed = head(pins, repo)
    require(observed == contract["requested_head"], "WRONG_HEAD")
    git_safety(pins, repo, contract["git_object_format"])
    sources, evidences, objects = (contract[k] for k in ("source_entries", "evidence_entries", "git_objects"))
    all_specs = sources + evidences + objects
    unique(all_specs, "id")
    unique(sources, "path")
    unique(evidences, "path")
    unique(objects, "oid")
    require(len(all_specs) <= contract["bounds"]["max_entries"], "ENTRY_CAPACITY")
    require(sum(e["size"] for e in all_specs) <= contract["bounds"]["max_bundle_bytes"], "BUNDLE_CAPACITY")
    require(inventory(repo, (".git",)) == sorted(e["path"] for e in sources), "SOURCE_INVENTORY")
    require(inventory(evidence) == sorted(e["path"] for e in evidences), "EVIDENCE_INVENTORY")
    entries = {}
    object_bytes = {}
    for spec in objects:
        data = read_object(pins, repo, spec, contract["git_object_format"], contract["bounds"]["max_entry_bytes"])
        object_bytes[spec["oid"]] = (spec["type"], data)
        entries[spec["id"]] = data
    require(observed in object_bytes and object_bytes[observed][0] == "commit", "HEAD_COMMIT_ABSENT")
    commit = object_bytes[observed][1]
    line = commit.split(b"\n", 1)[0]
    require(line == b"tree " + contract["git_tree_oid"].encode(), "COMMIT_TREE_IDENTITY")
    trees = {k: parse_tree(v[1], contract["git_object_format"])
             for k, v in object_bytes.items() if v[0] == "tree"}
    used = {observed, contract["git_tree_oid"]}
    require(contract["git_tree_oid"] in trees, "HEAD_TREE_ABSENT")
    tree_files = {}

    def visit(tree_id, prefix="", depth=0):
        require(depth <= 128 and tree_id in trees, "MISSING_TREE_OR_DEPTH")
        used.add(tree_id)
        for name, (kind, child) in trees[tree_id].items():
            path = prefix + name
            if kind == "tree":
                visit(child, path + "/", depth + 1)
            else:
                tree_files[path] = child
                used.add(child)
        require(len(tree_files) <= contract["bounds"]["max_entries"], "TREE_CAPACITY")

    visit(contract["git_tree_oid"])
    require(tree_files == {e["path"]: e["blob_oid"] for e in sources}, "EXACT_GIT_CHECKOUT_INVENTORY")
    for spec in sources:
        tree_id = contract["git_tree_oid"]
        parts = relative_path(spec["path"])
        for index, part in enumerate(parts):
            require(tree_id in trees and part in trees[tree_id], "SOURCE_NOT_IN_TREE")
            kind, child = trees[tree_id][part]
            used.add(child)
            if index < len(parts) - 1:
                require(kind == "tree", "SOURCE_PARENT_NOT_TREE")
                tree_id = child
            else:
                require(kind == "blob" and child == spec["blob_oid"], "SOURCE_BLOB_OID")
                require(child in object_bytes and object_bytes[child][0] == "blob", "SOURCE_BLOB_ABSENT")
        data = pins.read(repo, spec["path"], contract["bounds"]["max_entry_bytes"], spec["identity"])
        require(len(data) == spec["size"] and sha256(data) == spec["sha256"], "SOURCE_HASH")
        require(data == object_bytes[spec["blob_oid"]][1], "SOURCE_GIT_BYTES")
        entries[spec["id"]] = data
    require(used == set(object_bytes), "UNREACHABLE_GIT_INVENTORY")
    for spec in evidences:
        data = pins.read(evidence, spec["path"], contract["bounds"]["max_entry_bytes"], spec["identity"])
        require(len(data) == spec["size"] and sha256(data) == spec["sha256"], "EVIDENCE_HASH")
        entries[spec["id"]] = data
    require(head(pins, repo) == observed, "HEAD_CHANGED_DURING_EXPORT")
    manifest = {"schema_version": "2", "requested_head": observed,
                "git_tree_oid": contract["git_tree_oid"], "git_object_format": contract["git_object_format"],
                "source_entries": sources, "evidence_entries": evidences, "git_objects": objects}
    return SealedSnapshot(canonical(manifest), MappingProxyType(entries))
