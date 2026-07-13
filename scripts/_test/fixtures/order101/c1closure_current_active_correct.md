# FIXTURE TASKBOARD (active, post-split) -- C1-CLOSURE (Source B): correct-sha closes exactly one kind

## ARCHIVED ORDERS INDEX (fixture, generated-extra)

This block is a fixture generated-extra: present post-split but absent from the
pre-split snapshot, mirroring the real ARCHIVED ORDERS INDEX block in
AGENT_TASKBOARD.md. It intentionally carries no ORDER- id and no status verb.

## ORDER-210 -- synthetic fixture order, C1-CLOSURE target -- `OPEN`

Also present (unreviewed) in the archive fixture -- canonical id 210 appearing in
both boards raises cross-active-and-archive there, in ADDITION to the archive
block's own terminal-no-linked-review. The C1-CLOSURE table below closes only the
terminal-no-linked-review kind; cross-active-and-archive for the same block_id must
stay unresolved.

## C1-CLOSURE -- `REVIEWED(Opus, 2026-07-13)` -- fixture: correct sha closes exactly one kind

| kind | block_id | block_sha256 | disposition | evidence |
|---|---|---|---|---|
| terminal-no-linked-review | 210\|ORDER\|current-archive#1 | 324c84af3f4ca172a2524fb77fd88fdab019a72963960b71f9e5131f216d060c | benign-test-closure | fixture: closes exactly this ONE kind; cross-active-and-archive for the same block_id must remain unresolved |
