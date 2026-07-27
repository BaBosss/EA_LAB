---
name: codex-sandbox-git
description: Git operating guide for Codex workspace sandboxes. Use when Codex needs to read, stage, commit, move tracked files, configure local git settings, push, pull, fetch, clone, inspect remotes, or recover from sandbox-related git failures such as index.lock permission errors, .git/config lock failures, network DNS failures, credential helper prompts, and repeated approval/escalation friction.
---

# Codex Sandbox Git

Use this skill when doing git work from inside a Codex workspace sandbox.

The goal is to avoid wasting turns on predictable sandbox failures. Inspect first, use repo-local changes, escalate only when the operation needs it, and do not retry the same blocked command without changing the execution mode.

## Warning

Be careful with this skill. Escalation can run a command outside the sandbox boundaries that the user or environment intentionally set.

Do not treat escalation as the default way to use git. Use it only when the exact git operation is required, the sandbox failure is understood, and the user-facing approval request clearly names what boundary is being crossed.

Prefer the least powerful path that completes the task:

- Use read-only sandbox commands for inspection.
- Use normal workspace edits for file changes.
- Escalate only the specific `.git`, credential-helper, cache, or network command that cannot work inside the sandbox.
- Do not bundle unrelated work into an escalated command.

## Core Model

Separate git work into three classes:

1. Read-only git inspection
2. Working-tree file edits
3. Git metadata, network, or credential operations

Read-only inspection usually works in the sandbox. Working-tree edits should use normal file tools. Git metadata and network operations may need escalation because they write inside `.git`, use credential helpers, or access the network.

## Start Every Git Task With Inspection

Run these before editing, committing, pushing, or diagnosing:

```bash
git status --short --branch --untracked-files=all
git remote -v
git branch --show-current
```

Use targeted inspection as needed:

```bash
git log --oneline --decorate -5
git diff --stat
git diff --cached --stat
git config --local --list
```

Do not assume the branch, remote, identity, or dirty state from previous turns.

## Sandbox Failure Signals

Treat these as environment or permission signals, not normal git logic bugs:

- `Unable to create .git/index.lock: Operation not permitted`
- `could not lock config file .git/config: Operation not permitted`
- `Could not resolve host: github.com`
- `failed to open file ... Operation not permitted` under a tool cache outside the workspace

When one of these appears and the git operation is still required, rerun the same operation with escalation and a narrow justification. Do not loop through variants of the same sandbox-blocked command.

## Read-Only Commands

Prefer normal sandbox execution for inspection:

```bash
git status --short --branch
git diff --stat
git diff --name-status
git log --oneline --decorate -5
git show --stat
git config --local --list
```

If a read-only command touches network, such as `git ls-remote`, `git fetch --dry-run`, or remote probing, expect sandbox DNS/network failure and escalate if the result matters.

## File Edits And Moves

Use normal workspace edit tools for source files and docs.

Use `git mv` for tracked-file moves when preserving rename intent matters. If it fails with `.git/index.lock` or another `.git` permission error, rerun `git mv` with escalation instead of falling back to untracked manual moves.

Do not remove unrelated files. If a placeholder such as `.gitkeep` becomes unnecessary because a directory now contains real files, remove only that placeholder as part of the same scoped change.

## Staging And Commit

Before staging:

```bash
git status --short --branch --untracked-files=all
git diff --stat
```

Stage only the intended files unless the user explicitly asked for all changes:

```bash
git add PATHS
```

Before committing:

```bash
git status --short --branch
git diff --cached --stat
git diff --cached --name-status
```

Commit only after verifying the staged set matches the task:

```bash
git commit -m "Concise commit message"
```

If `git add` or `git commit` fails because the sandbox cannot create `.git/index.lock`, rerun with escalation. Do not edit files again to solve an index lock permission problem.

## Local Git Config

Use repo-local config for repo-specific identity, credential, or helper behavior:

```bash
git config --local user.name NAME
git config --local user.email EMAIL
git config --local credential.useHttpPath true
```

If `git config --local` fails with `.git/config` lock permission errors, rerun it with escalation. Do not switch to global config to bypass a local config lock.

## Push, Pull, Fetch, And Remote Network

Network git commands often fail in the sandbox with DNS or host resolution errors.

Before pushing, inspect branch divergence:

```bash
git status --short --branch
git rev-list --left-right --count @{u}...HEAD
```

If `@{u}` fails because the branch has no upstream, use the explicit remote branch after confirming the names:

```bash
git branch --show-current
git rev-list --left-right --count origin/BRANCH...HEAD
```

Interpret the counts as `remote_only local_only`:

- `0 N`: local branch is ahead only; normal push should work.
- `N 0`: local branch is behind only; fetch/rebase or pull before pushing.
- `N M`: histories diverged; do not push until you understand why.

If a required network command fails with `Could not resolve host`, rerun the same command with escalation:

```bash
git push origin BRANCH
git fetch origin
git ls-remote --heads origin
```

If the branch was rebased after it had already been pushed, a normal push may be rejected. `--force-with-lease` can rewrite remote branch history, so use it only after verifying the remote branch is the one you intend to rewrite and the user understands that effect:

```bash
git fetch origin BRANCH
git rev-list --left-right --count origin/BRANCH...HEAD
git push --force-with-lease origin BRANCH
```

Do not use plain `--force`.

After pushing, verify:

```bash
git status --short --branch
git log --oneline --decorate -3
```

If push reaches GitHub but fails with authentication or authorization errors, diagnose credentials separately. Do not keep retrying push unchanged.

## Credential Errors Are Different From Sandbox Errors

Interpret common push failures carefully:

- `Could not resolve host`: network/sandbox problem; retry with escalation.
- `could not read Password ... Device not configured`: missing usable HTTPS credential.
- `403`: credential was accepted but lacks permission for that repo or action.
- `Repository not found`: wrong URL, missing repo, or authenticated user lacks access.

Do not treat all push failures as the same problem.

## Escalation Hygiene

Escalate only the command that needs it.

Good escalation targets:

- `git mv ...`
- `git config --local ...`
- `git push origin BRANCH`
- `git push --force-with-lease origin BRANCH`
- `git ls-remote --heads origin`
- validators that need tool caches outside the workspace

Use a narrow `prefix_rule` when requesting approval. Avoid broad rules for arbitrary interpreters or destructive commands.

Before escalating a command, name what it can affect:

- `.git` metadata writes can change branch, index, config, or commit state.
- Network git commands can transmit refs, commits, branch names, and account identity to the remote.
- Credential helper commands can read or write authentication material.
- Tool-cache commands can write outside the workspace.

Never escalate destructive commands such as `rm`, `git reset --hard`, `git checkout -- PATH`, or plain `git push --force` unless the user explicitly requested that exact destructive action and the risk is clear. Prefer `--force-with-lease` over `--force` for rewritten git history.

## Practical Loop

Use this loop for most git tasks:

1. Inspect branch, status, and remote.
2. Make the smallest file changes.
3. Validate the changed artifact.
4. Stage the exact intended files.
5. Check the staged diff.
6. Commit if requested or clearly part of the task.
7. Push if requested.
8. Verify final status and report exact commit or push result.

If a command fails, classify the error before trying another command. Change execution mode when the failure is sandbox-related.
