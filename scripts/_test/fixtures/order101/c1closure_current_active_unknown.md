# FIXTURE TASKBOARD (active, post-split) -- C1-CLOSURE (Source B): unknown row = integrity failure

## ARCHIVED ORDERS INDEX (fixture, generated-extra)

This block is a fixture generated-extra: present post-split but absent from the
pre-split snapshot, mirroring the real ARCHIVED ORDERS INDEX block in
AGENT_TASKBOARD.md. It intentionally carries no ORDER- id and no status verb.

## ORDER-210 -- synthetic fixture order, C1-CLOSURE target -- `OPEN`

Also present (unreviewed) in the archive fixture -- canonical id 210 appearing in
both boards raises cross-active-and-archive there, in ADDITION to the archive
block's own terminal-no-linked-review.

## C1-CLOSURE -- `REVIEWED(Opus, 2026-07-13)` -- fixture: unknown row must be an integrity failure

| kind | block_id | block_sha256 | disposition | evidence |
|---|---|---|---|---|
| terminal-no-linked-review | 999\|ORDER\|current-archive#999 | 0000000000000000000000000000000000000000000000000000000000000000 | benign-test-closure | fixture: this (kind, block_id) matches no detected raw exception at all -- must be flagged as an unknown closure row (integrity failure), not silently ignored |
