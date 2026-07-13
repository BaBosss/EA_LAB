# FIXTURE TASKBOARD (active, post-split) -- C1-CLOSURE (Source B): stale sha stays unresolved

## ARCHIVED ORDERS INDEX (fixture, generated-extra)

This block is a fixture generated-extra: present post-split but absent from the
pre-split snapshot, mirroring the real ARCHIVED ORDERS INDEX block in
AGENT_TASKBOARD.md. It intentionally carries no ORDER- id and no status verb.

## ORDER-210 -- synthetic fixture order, C1-CLOSURE target -- `OPEN`

Also present (unreviewed) in the archive fixture -- canonical id 210 appearing in
both boards raises cross-active-and-archive there, in ADDITION to the archive
block's own terminal-no-linked-review.

## C1-CLOSURE -- `REVIEWED(Opus, 2026-07-13)` -- fixture: stale sha must NOT be honored

| kind | block_id | block_sha256 | disposition | evidence |
|---|---|---|---|---|
| terminal-no-linked-review | 210\|ORDER\|current-archive#1 | deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef | benign-test-closure | fixture: this sha256 is WRONG (the block was "edited" since this closure row was written) -- must be reported as STALE and the exception must stay unresolved, not silently closed |
