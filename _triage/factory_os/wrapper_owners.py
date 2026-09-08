# -*- coding: utf-8 -*-
"""The declarative, fail-closed build-tag -> canonical-wrapper contract.

``wrapper_owners.csv`` is the only hand-authored owner table.  This module holds no owner rows;
each result is rebuilt from the caller's evidence snapshot.  Acceptance checkers call ``load``
with one EvidenceSource so the manifest bytes, Inputs.mqh, mapped owners, and root mq5 listing all
come from that same source.  Builder libraries that expose only a ``read(relpath)`` seam use
``load_from_read`` and still derive identity from the manifest rather than Python module state.

CATEGORY (TIER_SNAPSHOT_DESIGN.md section 2/3.3): LIB. It opens no paths and chooses no snapshot.
"""
import csv
import io
import re
from collections import namedtuple
from types import MappingProxyType

import preset


MANIFEST_REL = '_triage/factory_os/wrapper_owners.csv'
INPUTS_REL = preset.INPUTS_REL
HEADER = ('build_tag', 'wrapper_rel')
BUILD_TAG_RE = re.compile(r'^LAB_ENTRY_[0-9]+$')
BUILD_DEFINE_RE = re.compile(
    r'^[ \t]*#[ \t]*define[ \t]+(LAB_ENTRY_[0-9]+)\b(.*)$')

Refusal = preset.PresetRefusal
_Loaded = namedtuple('WrapperOwners', 'by_tag root_mq5')


def _manifest_rows(raw):
    if not isinstance(raw, bytes):
        raise Refusal('%s must be supplied as bytes, not %s'
                      % (MANIFEST_REL, type(raw).__name__))
    try:
        text = raw.decode('utf-8')
    except UnicodeDecodeError as exc:
        raise Refusal('%s is not strict UTF-8: %s' % (MANIFEST_REL, exc))
    try:
        rows = list(csv.reader(io.StringIO(text, newline=''), strict=True))
    except csv.Error as exc:
        raise Refusal('%s is not valid CSV: %s' % (MANIFEST_REL, exc))
    if not rows or tuple(rows[0]) != HEADER:
        got = tuple(rows[0]) if rows else ()
        raise Refusal('%s header must be exactly %s; got %s'
                      % (MANIFEST_REL, ','.join(HEADER), ','.join(got)))

    by_tag = {}
    exact_paths = set()
    folded_paths = {}
    for line_no, row in enumerate(rows[1:], 2):
        if len(row) != 2:
            raise Refusal('%s:%d must contain exactly two fields; got %d'
                          % (MANIFEST_REL, line_no, len(row)))
        tag, rel = row
        if not BUILD_TAG_RE.fullmatch(tag):
            raise Refusal('%s:%d build tag %r is not canonical LAB_ENTRY_<digits>'
                          % (MANIFEST_REL, line_no, tag))
        _validate_rel(rel, line_no)
        if tag in by_tag:
            raise Refusal('%s:%d duplicate build tag %s' % (MANIFEST_REL, line_no, tag))
        if rel in exact_paths:
            raise Refusal('%s:%d duplicate owner path %s' % (MANIFEST_REL, line_no, rel))
        folded = rel.casefold()
        if folded in folded_paths:
            raise Refusal('%s:%d case-insensitive owner collision: %s and %s'
                          % (MANIFEST_REL, line_no, folded_paths[folded], rel))
        by_tag[tag] = rel
        exact_paths.add(rel)
        folded_paths[folded] = rel
    return by_tag


def _validate_rel(rel, line_no):
    parts = rel.split('/')
    bad = (not rel or '\\' in rel or rel.startswith('/') or len(parts) < 2
           or any(part in ('', '.', '..') for part in parts)
           or parts[0] != 'ea_template' or not rel.endswith('.mq5'))
    # A colon is never part of a canonical repository-relative path and would be drive syntax on
    # Windows even when hidden below an apparently acceptable first segment.
    if bad or ':' in rel:
        raise Refusal('%s:%d owner path %r is not a normalized repo-relative forward-slash '
                      'path under ea_template/ ending in .mq5'
                      % (MANIFEST_REL, line_no, rel))


def _without_comments(text):
    def keep_lines(match):
        return '\n' * match.group(0).count('\n')
    return re.sub(r'/\*.*?\*/', keep_lines, text, flags=re.S)


def _owner_token(rel, text, row_tag):
    found = []
    for line_no, raw in enumerate(_without_comments(text).splitlines(), 1):
        code = raw.split('//', 1)[0]
        match = BUILD_DEFINE_RE.match(code)
        if match:
            found.append((match.group(1), match.group(2).strip(), line_no))
    if len(found) != 1:
        raise Refusal('%s must define exactly one LAB_ENTRY_* token; found %d'
                      % (rel, len(found)))
    token, value, line_no = found[0]
    if value:
        raise Refusal('%s:%d build token %s must be valueless; got %r'
                      % (rel, line_no, token, value))
    if token != row_tag:
        raise Refusal('%s:%d defines %s but its manifest row key is %s'
                      % (rel, line_no, token, row_tag))


def _validate(raw, read, inputs_text, root_listing):
    by_tag = _manifest_rows(raw)
    try:
        input_tags = set(preset.known_build_tags(inputs_text))
    except Exception as exc:
        raise Refusal('%s build tags cannot be derived: %s' % (INPUTS_REL, exc))
    manifest_tags = set(by_tag)
    missing = sorted(input_tags - manifest_tags)
    extra = sorted(manifest_tags - input_tags)
    if missing or extra:
        raise Refusal('%s tag set does not exactly equal %s: missing=%s extra=%s'
                      % (MANIFEST_REL, INPUTS_REL,
                         ','.join(missing) or '(none)', ','.join(extra) or '(none)'))

    root_mq5 = tuple(root_listing or ())
    if root_listing is not None:
        folded = {}
        for rel in root_mq5:
            key = rel.casefold()
            if key in folded:
                raise Refusal('root mq5 listing has a case-insensitive path collision: %s and %s'
                              % (folded[key], rel))
            folded[key] = rel
        exact = set(root_mq5)
        for tag, rel in sorted(by_tag.items()):
            if rel not in exact:
                raise Refusal('%s owner %s is absent with exact spelling from the root mq5 '
                              'listing for this snapshot' % (tag, rel))

    for tag, rel in sorted(by_tag.items()):
        _owner_token(rel, read(rel), tag)
    return _Loaded(MappingProxyType(dict(by_tag)), root_mq5)


def load(source, reader=None, root_listing=True):
    """Load and fully validate owners from one EvidenceSource snapshot."""
    read = reader or source.read_committed
    raw = source.read_committed_bytes(MANIFEST_REL)
    inputs_text = read(INPUTS_REL)
    listing = source.list_committed('ea_template/*.mq5') if root_listing else None
    return _validate(raw, read, inputs_text, listing)


def load_from_read(read, root_listing=None):
    """Compatibility seam for builders whose established API supplies only a text reader."""
    manifest_text = read(MANIFEST_REL)
    if not isinstance(manifest_text, str):
        raise Refusal('%s text reader returned %s, not text'
                      % (MANIFEST_REL, type(manifest_text).__name__))
    return _validate(manifest_text.encode('utf-8'), read, read(INPUTS_REL), root_listing)


def resolve_from_read(read, build_tag):
    loaded = load_from_read(read)
    try:
        return loaded.by_tag[build_tag]
    except KeyError:
        raise Refusal('no canonical wrapper owner is declared for build %r; known: %s'
                      % (build_tag, ', '.join(sorted(loaded.by_tag))))
