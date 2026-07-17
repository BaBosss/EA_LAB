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

The lab PC keeps its normal OneDrive desktop client. The VPS is Windows Server
2012 R2, which the modern OneDrive and Google Drive desktop clients no longer
support (the installer crashes with "Setup has stopped working"). The VPS
therefore reaches the **same** OneDrive account through **rclone** — a portable,
headless `rclone.exe` that talks to OneDrive over the Microsoft Graph API with
no desktop client and no OS-level sign-in. No account change is required; only
the VPS-side sync engine differs.

1. On the VPS, place `rclone.exe` in a private tools directory (for example
   `C:\rclone\`), outside any synced or repository folder. Restrict sharing of
   the OneDrive folder to the owner; do not create a public or link-accessible
   share.
2. The VPS has no usable browser, so run the OAuth step on the lab PC (which
   has one): `rclone authorize "onedrive"`. Sign in to the **same** OneDrive
   account, approve the request, and copy the JSON token block it prints.
3. On the VPS run `rclone config`, create a new remote of type `onedrive`, and
   when it asks to auto-authenticate answer **no** ("Use auto config? n") so it
   offers the "paste token from another machine" path. Paste the token block
   from step 2. Scope the remote (or a remote path) at the dedicated
   `EA_LAB_VPS_SYNC` folder only — not the whole OneDrive drive — so the token
   grants access to nothing beyond the transport folders.
4. Store `rclone.conf` (which contains the OAuth token) on the VPS outside any
   synced or repository folder, readable only by the scheduled-task user. Treat
   the token like a password: store no broker, OneDrive, or rclone credentials
   in a `.ps1`, `.bat`, Task Scheduler argument, repository file, or log.
5. On the lab PC, mark both folders **Always keep on this device** so the
   OneDrive client retains a local copy. The VPS has no desktop client, so
   "Always keep on this device" does not apply there — rclone pulls and pushes
   on demand instead.
6. Find the real common directory from each terminal with **File -> Open Data
   Folder**, then navigate to the shared MetaQuotes `Terminal\Common\Files`.
   Do not infer it from the terminal installation path.
7. Grant the scheduled-task user read/write access only to the local rclone
   staging folders and `Common\Files`.
8. Record the resolved paths outside the repository's public artifacts. Account
   logins may appear in snapshot filenames; therefore the OneDrive folder must
   remain private.

## Scheduled copy: lab to VPS

The existing lab daily chain creates `portfolio\news_week.csv`. Add a lab task
after that chain (or a separate task shortly after it) which performs an atomic
publish: copy to `EA_LAB_news_week.csv.tmp`, verify the CSV is non-empty and has
at least one data event, then rename it to `EA_LAB_news_week.csv`. Never replace
the last good file with an empty or malformed download.

On the VPS, run a path-scoped PowerShell task every 5 minutes that first pulls
the file with rclone, then validates and publishes it exactly as before:

1. Pull the latest copy into a local staging folder with rclone (the remote is
   already scoped to `EA_LAB_VPS_SYNC`):

   ```text
   rclone copy "onedrive:lab-to-vps/news/EA_LAB_news_week.csv" ^
     "C:\rclone\staging\lab-to-vps\news" --config C:\rclone\rclone.conf
   ```

   Leave freshness/format checks to the wrapper below; do not push validation
   into rclone flags.
2. Read only the staged `EA_LAB_news_week.csv`.
3. Reject it if missing, zero bytes, older than 26 hours, or its header/event
   rows do not match the NewsGuard feed format.
4. Copy to `Common\Files\EA_LAB_news_week.csv.tmp`.
5. Re-read/validate the temporary file and atomically rename it over
   `EA_LAB_news_week.csv`.
6. Exit non-zero and retain the last good destination on any failure.

Configure both tasks with `Run whether user is logged on or not`,
`Start when available`, three retries five minutes apart, and a non-zero-exit
history check. Do not use `-Force` against terminal processes and do not kill a
terminal. Logs must contain timestamps and file age, not credentials.

## Scheduled copy: VPS to lab

On the VPS, every 5 minutes enumerate only files matching
`EA_LAB_snapshot_[1-9][0-9]*.csv`. Reject login `0`, test names, `.tmp` files,
and sources older than 10 minutes. Copy each through a same-directory `.tmp`
file and rename into a local staging folder so no partial CSV is ever
published. Then push the staged snapshots up with rclone:

```text
rclone copy "C:\rclone\staging\vps-to-lab\snapshots" ^
  "onedrive:vps-to-lab/snapshots" --config C:\rclone\rclone.conf
```

Because the atomic `.tmp`→rename completes in the staging folder before rclone
runs, OneDrive never receives a partial CSV.

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
- News CSV age on the VPS, the rclone copy result (and the lab PC's OneDrive
  sync status), parsed event count and detected UTC offset are visible in logs.
- Every expected account produces a snapshot younger than 10 minutes; every
  magic is non-zero and mapped to an owner EA.
- Push notifications arrive for a controlled init/config warning.
- Outside a news window no stale block global variable or orphaned guard state
  remains.

Keep a daily freshness check thereafter. Neither a green OneDrive icon on the
lab PC nor a zero rclone exit code on the VPS is proof of end-to-end delivery;
verify the final `Common\Files` file and the final lab CSV.

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

- On the lab PC, OneDrive authentication stays in Windows' credential store. On
  the VPS, the rclone OAuth token stays in `rclone.conf` outside any synced or
  repository folder, readable only by the scheduled-task user, and is treated
  like a password. Broker passwords, investor passwords and MQID values stay
  outside Git and OneDrive payloads.
- Do not put account screenshots, terminal configs, `.set` files containing
  secrets, or logs with credentials in the transport folders.
- Give the scheduled-task account no interactive broker-login authority.
- If OneDrive or rclone is unavailable, NewsGuard must expose a stale feed and
  follow its approved fail-safe policy. Manual copying is an emergency action
  with the same validation and audit log, not permission to disable freshness
  checks.
