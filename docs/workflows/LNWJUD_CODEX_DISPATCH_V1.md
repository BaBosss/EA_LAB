# lnwjud Codex Dispatch V1

Status: **SOURCE/OFFLINE CANDIDATE — NOT RUNTIME ACTIVATED**.

This milestone adds the missing authority/policy layer in front of the existing `tools/codex_relay`. The relay remains the execution adapter and is not duplicated or broadened.

## Request boundary

A dispatch request binds request/idempotency identity, actor, exact lane, exact expected HEAD, frozen contract SHA256, server profile ID, exact prompt bytes/hash, bounded timeout and creation time. Unknown fields are refused. Clients cannot supply executable paths, commands, working directories, model names, reasoning levels, sandbox flags, provider routes or deployment/trading authority.

## Server profiles

Profiles are immutable hash-bound server data. V1 admits two policy shapes:

- `REVIEW_READ_ONLY`: existing Control Tower Relay route, `READ_ONLY`, no source mutation.
- `SOURCE_OWNER_SIDE`: future fixed Job Control Codex-source profile, `OWNER_SIDE_NO_CODEX_SANDBOX`; the client still cannot choose an executable or command. This is policy/source shape only in this milestone and does not activate a source worker.

Every profile binds an allowed lane-state set, runner kind, model route, reasoning effort, sandbox policy, maximum timeout and whether source mutation is permitted. Profile authority mismatches refuse.

## Admission

Before dispatch the policy proves exact lane/head, clean and path-verified worktree, remaining budget, profile/lane-state compatibility, contract bytes/hash and an available typed executor. Dispatch ID is deterministic from lane + idempotency key + profile. A durable PREPARED audit record is written before execution. The executor must reconcile the deterministic dispatch ID before a new launch, so lost acknowledgement cannot create a duplicate execution.

## Authority ceiling

Source/offline only. Tests use fake executors and launch zero Codex processes. No runtime publication, no generic shell/PowerShell, no arbitrary executable, no surprise provider/model choice, no Git integration/push, no MT5, no LIVE/HOLDOUT/trading/risk authority.

Runtime activation waits for predecessor Job Control and Resource/Registry operational acceptance plus this candidate's independent exact-head scrutiny.
