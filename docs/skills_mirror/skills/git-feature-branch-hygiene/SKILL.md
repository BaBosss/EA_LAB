---
name: git-feature-branch-hygiene
description: Branch hygiene guide for keeping unrelated git features separated. Use when starting a new feature, bugfix, refactor, documentation change, skill change, or follow-up that may not belong on the current branch; when deciding whether to reuse the current branch or create a new one; or when preventing mixed pull requests, unrelated commits, and accidental work on stale feature branches.
---

# Git Feature Branch Hygiene

Use this skill before starting work that may not belong on the current branch.

The goal is to keep branches reviewable: one branch should tell one coherent story. If the new work is unrelated to the branch's existing purpose, create a new branch from the right base before editing files.

## Start With Repo Truth

Inspect before deciding:

```bash
git status --short --branch --untracked-files=all
git branch --show-current
git log --oneline --decorate -5
git remote -v
```

If the working tree is dirty, decide whether those changes belong to the current branch before creating another branch. Do not silently carry unrelated uncommitted changes into a new branch.

## Branch Decision

Stay on the current branch when the new work:

- Directly completes the same feature or PR
- Fixes feedback on the same feature
- Updates tests or docs for the same change
- Depends on unmerged commits already on the current branch

Create a new branch when the new work:

- Solves a different feature, bug, or cleanup
- Would make the PR title or review scope confusing
- Touches unrelated modules or documentation
- Could be merged independently from the current branch
- Is only inspired by the current work, not required by it

When unsure, prefer a new branch unless the new work clearly belongs in the same review.

## Choose The Base

Use the default branch as the base for independent work:

```bash
git fetch origin DEFAULT_BRANCH
git switch -c codex/short-feature-name origin/DEFAULT_BRANCH
```

Use the current branch as the base only when the new work depends on current unmerged commits:

```bash
git switch -c codex/short-followup-name
```

If the repo uses `master` or another default branch, inspect remotes instead of assuming `main`.

## Naming

Use concise branch names that describe the task:

```text
codex/add-branch-hygiene-skill
codex/fix-sandbox-git-push-guidance
codex/update-readme-develop-notes
```

Avoid branch names that describe process rather than work, such as `codex/more-changes` or `codex/fixes`.

## Before Committing

Check that the branch still has one scope:

```bash
git status --short --branch
git diff --stat
git diff --name-status
```

If unrelated work slipped in, split it before committing when practical.

## Before Pushing Or Opening A PR

Verify the commit story:

```bash
git log --oneline --decorate origin/DEFAULT_BRANCH..HEAD
git diff --stat origin/DEFAULT_BRANCH...HEAD
```

If the branch includes unrelated commits from another feature, rebase or recreate the branch before pushing.

## Practical Rule

If a reviewer would ask "why is this in the same PR?", use a separate branch.

