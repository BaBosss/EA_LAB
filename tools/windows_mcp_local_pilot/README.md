# EA_LAB Windows-MCP Local Display Pilot

Status: **SOURCE-ONLY CANDIDATE / CT REVIEW REQUIRED**.

This change does **not** install Windows-MCP, attach a Codex client, expose a listener, modify a scheduled task, run a tester, or authorize EA_LAB resource control.

## Frozen identity
- Upstream: https://github.com/CursorTouch/Windows-MCP
- Package: `windows-mcp==0.8.8`, MIT license, Python 3.14+
- Published: 2026-10-10 (PyPI).
- PyPI wheel SHA-256: `597ef720e1902ba76510a4d2b946949f8a48f281dd210c183de5ded60ea3b873`
- PyPI source SHA-256: `f7aa1a020876aa3fe6a8b8d3c316002e28f4951e1d26a42099987a9ab7ba68a7`
- Official release provenance: GitHub commit `b74c507d9e709223a0904cf08019edf55f2a75bb`.
- Tool allowlist: **DisplayInventory** only.
- Transport: **stdio**, local session only.

## Scope
Use a separate, isolated branch and worktree. **Do not** edit the dirty
`D:\EA_LAB` checkout, existing Codex configuration, lnwjud workspaces,
Monitor, Registry or MT5 artifacts.

After qualified CT admission, an isolated local client may start the selected
version as an ephemeral stdio process with the flags:

```text
uv tool run --python 3.14 --from windows-mcp==0.8.8 windows-mcp serve --transport stdio --tools DisplayInventory
```

This is **not** a command to be run automatically. The local launch can download
Python dependencies and must verify installed package/provenance before live use.
Prefer explicit environment settings `ANONYMIZED_TELEMETRY=false` and
`WINDOWS_MCP_TOOLS=DisplayInventory`.

## Required acceptance evidence
1. Verify unique actor/lease and conflict-free source path under Main CT.
2. Pin source SHA and exact dependency provenance.
3. MCP initialize must succeed over stdio.
4. `tools/list` must expose **exactly one** tool: `DisplayInventory`.
5. Attempts to call `PowerShell`, `Registry`, `Process`, `FileSystem`,
   `Click` and `Type` must return denied/unknown-tool; NEVER call before
   proving the allowlist.
6. Read display inventory once without screenshot or desktop input.
7. Record PID, creation time, executable, exact command, termination and
   absence of any external listener.
8. Preserve all test failures with immutable raw receipts.
9. One separate reviewer checks exact HEAD and negative cases. Main CT alone
   decides integration/push.

## Hard stops
- No Windows Service / Scheduled Task / Gateway / Tunnel / Firewall / ACL changes.
- No installation with `windows-mcp install`.
- No global change to `~/.codex/config.toml` or other clients.
- No autonomous shell, Registry, account changes, Git push or file mutation via MCP.
- No MT5 Tester/optimizer, HOLDOUT, Factory, Real Submit, risk changes or trading.
- No assertion that ChatGPT Plus/iPhone can access a local stdio MCP.

## Rollback
This is a candidate source-only branch. If rejected, keep the rejected commit,
negative evidence and dirty WIP intact; do not reset or scrub history.
No installed runtime is being replaced in this lane.

## Provenance
Public documentation: https://github.com/CursorTouch/Windows-MCP
Package: https://pypi.org/project/windows-mcp/0.8.8/
