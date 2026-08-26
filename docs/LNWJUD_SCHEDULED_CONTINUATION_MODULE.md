# LNWJUD Scheduled Continuation Module

Status: repository module only; no runtime activation.

## Purpose

This module prepares a deterministic, durable ChatGPT Scheduled Task handoff for an already-approved EA_LAB task contract.
It is designed for long-running work where a later ChatGPT iteration should inspect durable state and continue only when safe.

It does not extend a tool session or treat scheduler timing as evidence that a process is alive.
Each scheduled iteration is a fresh control iteration bound to durable repository/job/lane evidence.

## Existing capabilities reused

The module does not rebuild the existing LNWJUD M3 Secure Tunnel implementation.
M3 already owns outbound stdio tunnel preparation, pinned tunnel-client identity, sealed preflight, and byte-checked launch.
Canonical policy keeps M3 runtime owner-gated and currently STOPPED / NOT PRIMARY TRANSPORT.

The module also reuses the Long Job Runner conceptually as the durable process-state owner when a `job_id` exists.
It does not modify or replace `scripts/long_jobs/**`.
## Files

- `tools/lnwjud/scheduled-continuation.cjs` validates a continuation spec plus an existing deterministic delegation package and emits one immutable handoff artifact.
- `tools/lnwjud/test-scheduled-continuation.cjs` covers deterministic output and refusal cases.

## Safety contract

Every artifact is `NO_NEW_AUTHORITY`.
The task prompt always requires durable state inspection before work and refuses duplicate execution while the recorded job/writer lane is still running.
It adds hard stops for runtime cutover, deployment, trading, LIVE, risk changes, and history rewrite while preserving stricter stops inherited from the task package.

A continuation may re-anchor after `origin/master` moves, but only in an isolated clean worktree and only within the already-approved task contract.
The module never starts, restarts, attaches, or cuts over the M3 Secure Tunnel.
It never creates a ChatGPT Scheduled Task by itself; the generated `prompt` is the payload supplied to the ChatGPT scheduler when that product capability is available to the account/workspace.

## CLI

```text
node tools/lnwjud/scheduled-continuation.cjs <spec.json> <delegation-package.json> <out.json>
```

The output path must not already exist; creation is fail-closed (`wx`).
