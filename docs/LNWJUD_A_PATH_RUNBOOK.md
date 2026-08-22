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

A Windows Scheduled Task starts the Remote Desktop Commander remote agent automatically at user logon. The task-start path itself passed one real reboot on 2026-08-22. Zero-touch session restore remains a separate proof until one reboot occurs after the persistent session was seeded.

**Scheduled task:** `EA_LAB_RemoteDesktopCommander`
**Trigger:** at logon of the current interactive user, 30 second delay
**Principal:** current user (`patip`), logon type Interactive, run level Limited — never SYSTEM, never elevated
**Action:** `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\EA_LAB_CONTROL\remote-desktop-commander\start-remote.ps1"`
**Restart on failure:** bounded, up to 3 attempts, 1 minute apart — no infinite loop
**Pinned package:** `@wonderwhy-er/desktop-commander@0.2.47`
**Session mode:** `remote --persist-session`

**Launcher / recovery:**

- `D:\EA_LAB_CONTROL\remote-desktop-commander\start-remote.ps1` — launcher v1.1.0; pinned 0.2.47 with `remote --persist-session`
- `D:\EA_LAB_CONTROL\remote-desktop-commander\Start_EA_LAB_Remote.cmd` — manual fallback
- Desktop shortcut `EA_LAB Remote` points to that same `.cmd` fallback
- `D:\EA_LAB_CONTROL\remote-desktop-commander\logs\launcher.log` — bootstrap metadata only; never captures child-agent stdout/stderr

**CLI window:** Minimize is safe. Closing the agent console with `X` stops the agent. If that happens, double-click `EA_LAB Remote` on the Desktop to start the same pinned launcher again.

**Duplicate guard:** the launcher matches the actual `desktop-commander[\/]dist[\/]index\.js` entrypoint, not generic node/npm/powershell processes. If already running it logs `ALREADY_RUNNING` and exits 0 without creating a duplicate.

**Credential persistence boundary:** the owner explicitly authorized persistent Remote Desktop Commander authentication for zero-touch reboot recovery. Package-managed session credentials are stored only in `C:\Users\patip\.desktop-commander-device\device.json`; they are not copied into the launcher, `.cmd`, Desktop shortcut, logs, or repository. After seeding, ACLs were hardened so the credential directory/file is readable only by `BABOSS\patip`, `NT AUTHORITY\SYSTEM`, and `BUILTIN\Administrators`; inherited `BaBoss\CodexSandboxUsers` read access was removed.

**Reauthentication:** if the saved session is missing, expired, or rejected, the visible minimized agent window may request device-code verification again and the user completes it manually. The launcher does not automate browser/device-code approval.

**Task controls (PowerShell):**

```powershell
Get-ScheduledTask -TaskName EA_LAB_RemoteDesktopCommander | Format-List *
Get-ScheduledTaskInfo -TaskName EA_LAB_RemoteDesktopCommander
Disable-ScheduledTask -TaskName EA_LAB_RemoteDesktopCommander
Enable-ScheduledTask -TaskName EA_LAB_RemoteDesktopCommander
```

Disabling the task stops future logon auto-start; it does not itself terminate an agent that is already running.

**Manual fallback:** double-click `EA_LAB Remote`, run `D:\EA_LAB_CONTROL\remote-desktop-commander\Start_EA_LAB_Remote.cmd`, or run `npx --yes @wonderwhy-er/desktop-commander@0.2.47 remote --persist-session`.

**Acceptance status — 2026-08-22:**
- real reboot proved Scheduled Task startup: PASS
- pinned 0.2.47 startup after logon: PASS
- A-PATH `lnwjudctl status/workspace-info/git-status/execute check`: PASS after reboot
- persistent session seeded: PASS; session credential values were not read or displayed
- credential ACL hardening: PASS
- Desktop recovery shortcut: INSTALLED
- zero-touch reboot/session-restore proof: PENDING

**Auto-start configuration: INSTALLED / REBOOT START PASS.**
**Zero-touch session restore proof: PENDING.** Perform one owner-present reboot after the persisted session seed. After Windows login, do not click Verify and do not start the agent manually; wait at least 60 seconds and let Control Tower confirm that device `BaBoss` returns online from the saved session.

## Not covered by this runbook

- task-scoped mutation/A6
- deployment/runtime attachment
- trading or real money
- LIVE/DEMO->LIVE changes
- risk/default changes
- Secure MCP Tunnel activation as primary transport
