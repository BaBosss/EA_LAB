# NewsGuard VPS transport and attach runbook

Scope: manual deployment for ORDER-083C. This document does not authorize an
agent to log in to the VPS, attach an EA, or change a live terminal. The user
performs those actions after the compiled MT5 and MT4 builds have passed their
tests.

## Transport layout

Use one OneDrive account on the lab PC and VPS, but keep the two directions in
separate directories to prevent copy loops:

```text
EA_LAB_VPS_SYNC/
  lab-to-vps/news/       # lab is the only writer
  vps-to-lab/snapshots/  # VPS is the only writer
```

The transported files contain no broker password, investor password, API key,
terminal configuration, or OneDrive token.

| Direction | Source | OneDrive staging | Destination |
|---|---|---|---|
| lab -> VPS | `D:\EA_LAB\portfolio\news_week.csv` | `lab-to-vps\news\EA_LAB_news_week.csv` | VPS MetaQuotes `Terminal\Common\Files\EA_LAB_news_week.csv` |
| VPS -> lab | VPS MetaQuotes `Terminal\Common\Files\EA_LAB_snapshot_*.csv` | `vps-to-lab\snapshots\` | read directly by `scripts\collect_live_deals.ps1 -CommonFiles <synced snapshots path>` |

Do not sync a terminal data directory or `Common\Files` wholesale. That would
copy unrelated account data and can make partially-written files visible.

## One-time setup

1. Install/sign in to OneDrive on the VPS using the least-privileged account
   available. Restrict sharing to the owner; do not create a public or
   link-accessible share.
2. Mark both folders **Always keep on this device** on the VPS and lab PC.
3. Find the real common directory from each terminal with **File -> Open Data
   Folder**, then navigate to the shared MetaQuotes `Terminal\Common\Files`.
   Do not infer it from the terminal installation path.
4. Grant the scheduled-task user read/write access only to the two sync folders
   and `Common\Files`. Store no broker or OneDrive credentials in a `.ps1`,
   `.bat`, Task Scheduler argument, repository file, or log.
5. Record the resolved paths outside the repository's public artifacts. Account
   logins may appear in snapshot filenames; therefore the OneDrive folder must
   remain private.

## Scheduled copy: lab to VPS

The existing lab daily chain creates `portfolio\news_week.csv`. Add a lab task
after that chain (or a separate task shortly after it) which performs an atomic
publish: copy to `EA_LAB_news_week.csv.tmp`, verify the CSV is non-empty and has
at least one data event, then rename it to `EA_LAB_news_week.csv`. Never replace
the last good file with an empty or malformed download.

On the VPS, run a path-scoped PowerShell task every 5 minutes:

1. Read only `lab-to-vps\news\EA_LAB_news_week.csv`.
2. Reject it if missing, zero bytes, older than 26 hours, or its header/event
   rows do not match the NewsGuard feed format.
3. Copy to `Common\Files\EA_LAB_news_week.csv.tmp`.
4. Re-read/validate the temporary file and atomically rename it over
   `EA_LAB_news_week.csv`.
5. Exit non-zero and retain the last good destination on any failure.

Configure both tasks with `Run whether user is logged on or not`,
`Start when available`, three retries five minutes apart, and a non-zero-exit
history check. Do not use `-Force` against terminal processes and do not kill a
terminal. Logs must contain timestamps and file age, not credentials.

## Scheduled copy: VPS to lab

On the VPS, every 5 minutes enumerate only files matching
`EA_LAB_snapshot_[1-9][0-9]*.csv`. Reject login `0`, test names, `.tmp` files,
and sources older than 10 minutes. Copy each through a same-directory `.tmp`
file and rename into `vps-to-lab\snapshots` so OneDrive never sees a partial
CSV.

On the lab PC, call:

```powershell
powershell -NoProfile -File D:\EA_LAB\scripts\collect_live_deals.ps1 `
  -CommonFiles '<local OneDrive>\EA_LAB_VPS_SYNC\vps-to-lab\snapshots'
```

The collector's 30-hour guard is a final audit guard, not the operational
freshness target. A VPS exporter normally rewrites every 60 seconds; alert when
the newest snapshot is more than 10 minutes old. Keep one writer per direction.

## Attach checklist (repeat for every live/demo terminal)

1. Confirm the account login, platform, host and deployed EA/magic list against
   the current deployment inventory. Stop if the terminal/account does not
   match the inventory.
2. Copy the tested NewsGuard binary to that platform's Experts folder and
   refresh Navigator. Do not compile or edit source on the VPS.
3. Open one dedicated chart per protected magic and attach one NewsGuard
   instance. **Magic `0` is forbidden.** Each magic must be a non-zero integer
   and must exactly match the owner EA. Never use one instance as an
   account-wide wildcard.
4. Select the already-approved policy for that magic; do not change the policy
   semantics during attachment. **Production MT5 default is
   `AutoDetectServerOffset=true`**: the guard re-checks on each feed reload and
   follows broker DST changes. Use `false` only as an explicit manual override
   after comparing Market Watch/server time with Bangkok time. MT4 has no
   reliable live trade-server clock API, so its input remains the manual
   override and the quote-derived comparison is advisory. Inspect the init and
   reload logs for the effective offset on every terminal.
5. Confirm terminal notifications are configured, then require one successful
   test notification. A local `Alert` alone is not remote monitoring.
6. Confirm `EA_LAB_news_week.csv` exists in `Common\Files`, is younger than 26
   hours, parses to at least one event, and the Experts log reports NewsGuard
   armed. Missing/stale/empty feed must be visible as fail-safe, not green.
7. Confirm `NEWSGUARD_BLOCK_<magic>` does not remain set outside a news window.
   Restart the terminal once outside a window and verify reconciliation clears
   a stale block while the owner EA is still prevented from opening inside a
   controlled test window.
8. Confirm the NewsGuard chart and AccountSnapshotExporter chart are saved in
   the startup profile so a VPS reboot reloads them. The snapshot exporter may
   be attached with terminal AutoTrading disabled because it is read-only.
9. Verify the outbound snapshot reaches the lab within 10 minutes and the
   dashboard maps every non-zero magic. An unmapped magic is a deployment
   error, not an informational row.

Do attachment/close tests on demo first. Do not manufacture a high-impact live
window or place a real order merely to test the guard.

## Verification after deployment

For the first 24 hours, check at least twice:

- Task Scheduler last result is `0` for successful copies and becomes non-zero
  when a test source is intentionally withheld.
- News CSV age on the VPS, OneDrive sync status, parsed event count and detected
  UTC offset are visible in logs.
- Every expected account produces a snapshot younger than 10 minutes; every
  magic is non-zero and mapped to an owner EA.
- Push notifications arrive for a controlled init/config warning.
- Outside a news window no stale block global variable or orphaned guard state
  remains.

Keep a daily freshness check thereafter. OneDrive's green icon is not proof of
end-to-end delivery; verify the final `Common\Files` file and the final lab CSV.

## Rollback

1. Disable the two scheduled copy tasks; do not delete their history yet.
2. Remove NewsGuard from its dedicated charts (or load the pre-deployment
   profile). Do not remove the owner trading EAs as part of this rollback.
3. Outside a news window, remove only global variables named
   `NEWSGUARD_BLOCK_<magic>` for the exact rolled-back magics. Never delete all
   terminal global variables.
4. Move, rather than destroy, the last transported CSVs into a timestamped
   private quarantine directory for diagnosis.
5. Confirm owner EAs, terminal AutoTrading state, open/pending orders and
   AccountSnapshotExporter remain in their pre-change state.
6. Record terminal/account, magic, time, reason and observed logs for Claude to
   review. Re-attachment requires a corrected build and the full checklist.

## Secrets and recovery boundaries

- OneDrive authentication stays in Windows' credential store. Broker passwords,
  investor passwords and MQID values stay outside Git and OneDrive payloads.
- Do not put account screenshots, terminal configs, `.set` files containing
  secrets, or logs with credentials in the transport folders.
- Give the scheduled-task account no interactive broker-login authority.
- If OneDrive is unavailable, NewsGuard must expose a stale feed and follow its
  approved fail-safe policy. Manual copying is an emergency action with the
  same validation and audit log, not permission to disable freshness checks.
