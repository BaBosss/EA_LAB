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

## Remote Desktop Commander auto-start

A Windows Scheduled Task starts the Remote Desktop Commander remote agent automatically at user logon, so the manual `npx ... remote` recovery step above is no longer required after a normal reboot.

**Scheduled task:** `EA_LAB_RemoteDesktopCommander`
**Trigger:** at logon of the current interactive user, 30 second delay
**Principal:** current user (`patip`), logon type Interactive, run level Limited — never SYSTEM, never elevated
**Action:** `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\EA_LAB_CONTROL\remote-desktop-commander\start-remote.ps1"`
**Restart on failure:** bounded, up to 3 attempts, 1 minute apart — no infinite loop
**Pinned package:** `@wonderwhy-er/desktop-commander@0.2.47` — the launcher deliberately does not use `@latest`, so an automatic reboot-time start can never silently change the remote-control software version. Bumping the pinned version is a separate explicit maintenance action.

**Launcher files** (machine-local, not in this repo, no secrets):

- `D:\EA_LAB_CONTROL\remote-desktop-commander\start-remote.ps1` — the launcher
- `D:\EA_LAB_CONTROL\remote-desktop-commander\Start_EA_LAB_Remote.cmd` — manual double-click fallback, runs the same launcher
- `D:\EA_LAB_CONTROL\remote-desktop-commander\logs\launcher.log` — bootstrap metadata only (timestamps, START_REQUESTED / ALREADY_RUNNING / PROCESS_STARTED / PROCESS_EXITED / exit codes). The launcher never captures or redirects the agent's own stdout/stderr, since that stream can contain device authorization codes.

**Duplicate guard:** the launcher detects the real running agent by matching `node.exe` command lines against `desktop-commander[\/]dist[\/]index\.js` — the actual package entrypoint — not by generic `node.exe`/`npx.exe`/`powershell.exe` presence. If a match is found it logs `ALREADY_RUNNING` and exits 0 without starting a second agent.

**Reauthentication:** the launcher starts the pinned agent in a visible (minimized, not hidden) console window under the current user's own session. If the persisted device session is not accepted, the user sees the device-code/browser prompt in that window and completes it manually, exactly as in the manual recovery flow above. The launcher does not automate or store any authentication step.

**No secrets stored:** the launcher script, the `.cmd` fallback, and the log file contain no API keys, tokens, device-code cache, or credentials of any kind.

**Inspect the task:**

```powershell
Get-ScheduledTask -TaskName EA_LAB_RemoteDesktopCommander | Format-List *
Get-ScheduledTaskInfo -TaskName EA_LAB_RemoteDesktopCommander
```

**Disable the task** (stops auto-start without deleting it):

```powershell
Disable-ScheduledTask -TaskName EA_LAB_RemoteDesktopCommander
```

**Re-enable the task:**

```powershell
Enable-ScheduledTask -TaskName EA_LAB_RemoteDesktopCommander
```

**Manual fallback** if auto-start does not fire or fails: run `D:\EA_LAB_CONTROL\remote-desktop-commander\Start_EA_LAB_Remote.cmd`, or fall back to the original manual recovery command earlier in this runbook (`npx @wonderwhy-er/desktop-commander@latest remote`).

**Acceptance status — 2026-08-21:** the task was created and independently inspected (task definition, trigger, principal, and settings all confirmed read-only against the contract above). The launcher was run manually twice while the real agent (PIDs `16088`/`18808`) was already live — both via direct script invocation and via `Start-ScheduledTask` — and both times logged `ALREADY_RUNNING` with `LastTaskResult 0`, created no duplicate process, and left the live agent's PIDs and Control Tower connection undisturbed.

**Auto-start configuration: INSTALLED / VERIFIED NON-DISRUPTIVELY.**
**Real reboot proof: PENDING.** This has not yet been proven across an actual Windows reboot — only that the task exists correctly and the launcher is idempotent while the agent is already running. The next step is one real reboot performed while the owner is present: log into Windows, wait for the 30 second trigger delay, and confirm from Control Tower that device `BaBoss` returns online automatically with no manual PowerShell step.

## Not covered by this runbook

- task-scoped mutation/A6
- deployment/runtime attachment
- trading or real money
- LIVE/DEMO->LIVE changes
- risk/default changes
- Secure MCP Tunnel activation as primary transport
