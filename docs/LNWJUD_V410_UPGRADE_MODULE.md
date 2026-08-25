# LNWJUD v4.10 Upgrade Module

## Purpose

This module stages and validates an lnwjud v4.10 candidate for EA_LAB without replacing the trusted runtime source.
It is intentionally side-by-side and does not perform cutover, merge, push, deployment, runtime attachment, or authority changes.

Current trusted source remains:

- `D:\EA_LAB_TOOLS\lnwjud-v4-src`
- pinned by `tools/lnwjud/status-contract.json`

Default candidate staging root:

- `D:\EA_LAB_CONTROL\lnwjud-upgrades\v4.10.0\source`

## Commands

Use `tools\lnwjud_upgrade\Invoke-LnwjudUpgrade.ps1` with one of:

- `Plan` -- verify current trusted-source pin and resolve the exact target tag SHA.
- `Stage` -- create or reuse an exact detached side-by-side candidate worktree.
- `Build` -- run frozen-lockfile install and upstream build; tracked source changes fail closed except two proven normalization-only generated-file cases.
- `Compat` -- verify candidate version/SHA and the internal modules/exports consumed by the EA_LAB restricted gateway.
- `Manifest` -- emit external evidence with all authority/cutover flags false.

## Safety contract

The module refuses to stage when the trusted source HEAD differs from the canonical expected SHA or has tracked changes.
The candidate must be below the configured staging root and may not equal the trusted source path.
Compatibility evidence is accepted only from an exact clean candidate HEAD.

Build normalization handling is narrow: only
`apps/desktop/build/windows-capability-bridge.sha256` and
`packages/capabilities/src/windows-capability-integrity.generated.ts`
may be restored, and only when Git's normalized worktree hash still equals the index blob. Any real content change or any other tracked change fails closed.

## v4.10.0 validation evidence - 2026-08-25

Validated exact upstream target:

- ref: `v4.10.0`
- SHA: `8c407dfe5c67ecafad39f4e52d555081fc6f0b28`
- frozen-lockfile install: PASS
- upstream build: PASS
- post-build candidate: CLEAN after the bounded normalization-only repair
- internal compatibility seams: PASS 5/5 (`ToolRegistry`, `createStdioMcpRuntime`, storage, workspace, permission profiles)
- focused module tests: PASS 20/20

The generated runtime evidence manifest is kept outside the repository under `D:\EA_LAB_CONTROL\lnwjud-upgrades\v4.10.0\upgrade-manifest.json`.
This milestone does not authorize changing `status-contract.json`, the trusted runtime source, the Secure Tunnel contract, or any deployment/runtime state.
