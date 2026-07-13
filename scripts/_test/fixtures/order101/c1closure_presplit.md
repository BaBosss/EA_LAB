# FIXTURE TASKBOARD (pre-split state) -- C1-CLOSURE (Source B) negative tests

## ORDER-210 -- synthetic fixture order, C1-CLOSURE target -- `DONE(tester, 2026-01-01)`

Acceptance: none, this is a test fixture. No REVIEW block anywhere links this id, and
it also appears (unreviewed, OPEN) in the active board fixture, so it raises BOTH
terminal-no-linked-review AND cross-active-and-archive against the SAME block_id --
the exact "two different kinds, one block_id" shape the C1-CLOSURE (kind, block_id,
block_sha256) key must distinguish.
