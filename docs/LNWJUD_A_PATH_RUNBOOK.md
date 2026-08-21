# LNWJUD A-PATH RUNBOOK

> Canonical entry = `PROJECT_STATE.md` · this file owns: A-PATH operator/recovery procedure only.

## Purpose

Primary transport for routine EA_LAB control:

`ChatGPT Plus -> Remote Desktop Commander -> lnwjudctl -> restricted ea-lab-gateway -> exact clean authorized worktree`

This path does not require ChatGPT Business, OpenAI Secure MCP Tunnel, or Codex for deterministic read/check work.

## Normal prerequisite

The Remote Desktop Commander agent must be running on the Windows PC and the device `BaBoss` must be online.

Start it in a normal PowerShell window:

```powershell
npx @wonderwhy-er/desktop-commander@latest remote
```

Keep that terminal/process running while remote control is needed. Authentication may be requested after reboot or session expiry; complete the browser/device-code flow if prompted.

## Recovery after reboot / `No devices available`

Symptom from ChatGPT/Control Tower:

`No devices available`

First determine transport state. If `BaBoss` is registered but `offline`, do not debug LNWJUD, Git, Tunnel, API keys, or Codex.

On the PC:

1. Open PowerShell.
2. Run `npx @wonderwhy-er/desktop-commander@latest remote`.
3. If a device-code/browser authentication prompt appears, complete it.
4. Wait for `Device marked as online`, `Presence tracked`, and `Device ready`.
5. Leave the agent process running.
6. Re-run the Control Tower device ping, then the A-PATH proof.

A Windows reboot can stop this agent even though the persisted device ID and auth registration still exist. Pairing Codex/ChatGPT Remote is a separate connection layer and does not start the Remote Desktop Commander agent.

## A-PATH proof command surface

Use `lnwjudctl` from an exact clean canonical worktree. Required read/observe proof:

- `status`
- `workspace-info`
- `git-status`
- `read PROJECT_STATE.md`
- `execute check`

Expected properties:

- exact canonical HEAD
- clean worktree
- role `EA-OBSERVE`
- no unrestricted shell exposed through `lnwjudctl`
- no raw MCP passthrough
- no write/apply-patch authority
- named non-mutating execution profiles only

## Accepted proof — 2026-08-21

After restarting the Remote Desktop Commander agent, device `BaBoss` returned online and responded to ping.

The Control Tower then executed the A-PATH remotely and observed:

- canonical HEAD `531df46c8241914f3bcf72c76ae60d3334d7660b`
- `lnwjudctl status` PASS
- `workspace-info` PASS on `D:\EA_LAB_worktrees\lnwjud-a-integrate-20260821`
- `git-status` clean
- `read PROJECT_STATE.md` PASS
- `execute check` PASS, exit code 0

This is the accepted end-to-end ChatGPT/remote-control proof for the observe-only A-PATH. Codex, Claude, and Qwen were not dispatched for the proof.

## Not covered by this runbook

- task-scoped mutation/A6
- deployment/runtime attachment
- trading or real money
- LIVE/DEMO->LIVE changes
- risk/default changes
- Secure MCP Tunnel activation as primary transport
