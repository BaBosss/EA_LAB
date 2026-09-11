# ORDER-353 VPS Evidence Operations — Lessons Learned / Runbook

Date: 2026-09-11
Canonical base at capture: `346175b42e68405aea0bc099a67009090bfedc0e`
Target: `463666728|990026` / `(TRD)_SuperTrendFlip_rev05` / `BTCUSDm,H4`
Authority: evidence/operations only. No attachment, restart, forced trade, risk/default, LIVE, or judge-clock authority.

## 1. Why this exists

This runbook captures the operator pain-points and verification sequence discovered while recovering ORDER-353 RuntimeIdentity evidence from the VPS. Its direct consumer is the future Control Tower: avoid repeating blind OAuth/RDP/transport debugging and preserve fail-closed evidence semantics.

Canonical state at capture:
- accepted attachment expectation is `epoch-2`;
- `first_trade_epoch=null`;
- `judge_date=null`;
- forward state remains `FORWARD_TEST_UNTRUSTED`;
- automated VPS transport remains `BLOCKED / UNVERIFIED`;
- global monitoring remains `DEGRADED_MONITORING`.

The manually acquired epoch-2 sidecar was content-matching but stale at canonical reconciliation. Manual acquisition does not make automated transport healthy.

## 2. Correct system model

The path is:

`VPS EA producer -> MT5 FILE_COMMON sidecar/snapshot -> transport -> BaBoss local/synced input -> DailyMonitor -> Control Room/Monitor`

BaBoss `EA_LAB_DailyMonitor` is a **consumer**, not a VPS puller. On 2026-09-11 it was observed enabled at 07:30 daily plus logon. No separate BaBoss Scheduled Task was found that pulls RuntimeIdentity directly from the VPS.
A DailyMonitor non-zero result can be an intentional fail-closed evidence result. Do not classify the Scheduled Task itself as broken merely because `Last Result = 1`; inspect the named monitor failures first.

RuntimeIdentity is currently event-driven. The strategy emits the sidecar at initialization and after the first qualifying entry; there is no accepted heartbeat that refreshes it every morning. Therefore copying an unchanged sidecar every day only reproduces stale evidence.

## 3. What was proven manually

The VPS `FILE_COMMON` sidecar was acquired read-only and copied to BaBoss:

`D:\EA_LAB_CONTROL\evidence\order353-manual-20260910\EA_LAB_identity_463666728_990026.json`

Observed file:
- size: `518` bytes;
- SHA256: `079a9300242893d35e1e7b6cd4ca3f27a645e7154a4ad378d0252c4bbe3fe6be`;
- `attach_epoch=epoch-2`;
- `attach_time_unix=1789039970`;
- `first_trade_epoch=null`;
- build/config/account/magic/symbol/timeframe matched the pinned identity.

The earlier raw candidate ticket `2227380592` predates the epoch-2 attach boundary and cannot be transferred from epoch-1. Never start the judge clock from that historical candidate.

## 4. Pain points / failure modes

### 4.1 Host/control-channel ambiguity

Desktop Commander was available for BaBoss but not for the VPS. The VPS required manual RDP. Do not infer that a connected Desktop Commander session is the VPS; always pin device ID/hostname and origin before consequential work.

The VPS was Windows Server 2012 R2. A modern Node-based Remote Desktop Commander install rejected that OS. Do **not** bypass this with `NODE_SKIP_PLATFORM_CHECK=1`; treat unsupported control-channel setup as an environment dependency instead of widening the runtime surface.
### 4.2 RDP shell/paste fragility

Long inline PowerShell commands repeatedly suffered quoting/interpolation/paste failures. Prefer:
- one short command at a time for manual RDP;
- file-backed PowerShell for multi-step logic;
- explicit `$LASTEXITCODE` checks;
- exact paths rather than shell-dependent defaults.

A parser/paste failure is a harness/operator problem, not runtime evidence. Confirm whether any mutation occurred before retrying.

### 4.3 rclone config-path ambiguity

The worker used `C:\rclone\rclone.conf`. Running `rclone config reconnect onedrive:` without `--config C:\rclone\rclone.conf` can update a different default config and create a false sense that authentication was repaired.

For all VPS diagnostics use the explicit config path:

`C:\rclone\rclone.exe ... --config C:\rclone\rclone.conf`

Never print or paste OAuth tokens into chat/logs. For headless OAuth, run the exact `rclone authorize "onedrive" ...` command on the browser-capable BaBoss machine, then paste the returned token directly into the VPS `config_token>` prompt.

### 4.4 Read auth is not write-path proof

`rclone about onedrive:` can succeed while an upload path still fails. Therefore OAuth/browser success and quota listing are **not** acceptance evidence for VPS -> OneDrive writes.

A transport PASS requires a real write/readback check on the intended destination, including non-zero size (and preferably hash/byte equality). Do not accept a zero-byte remote object as evidence.

The manual session observed both `Unauthenticated` upload errors and a snapshot `nameAlreadyExists` collision. These observations do not prove one universal root cause. Canonical classification remains `UNKNOWN / transport unverified` until a bounded reproduction isolates it.
### 4.5 Bulk worker failures can mask the identity diagnostic

The canonical transport worker has separate snapshot and RuntimeIdentity passes with aggregate return status. During diagnosis, a snapshot collision can make the overall worker fail even when the identity path is the question of interest.

Use a bounded direct `copyto` of the single RuntimeIdentity file only as a diagnostic to isolate the identity write path. This does not replace the production worker and does not authorize changing worker semantics.

### 4.6 Manual worker replacement is not transport acceptance

The manual session copied the canonical `push_snap.cmd` bytes to the VPS and preserved the previous file as a backup. Treat that as an operator observation, not proof that the Scheduled Task is using those bytes or that end-to-end transport is healthy.

Acceptance requires all of:
1. producer file exists and is fresh;
2. exact worker/config path is known;
3. scheduled/manual invocation is source-bound;
4. destination object is non-zero and byte/hash consistent;
5. BaBoss sees the intended file;
6. canonical validator passes freshness/identity;
7. repeated scheduled delivery is proven independently of the manual diagnostic.

## 5. Verification order — use this sequence next time

1. Fetch/pin current `origin/master`; read `PROJECT_STATE`, task owner and Lane Registry.
2. Pin host/device explicitly. Never use first-online fallback for VPS work.
3. Read the VPS producer file first: size, mtime, JSON fields, attach epoch, first-trade epoch.
4. Compare producer identity to current canonical `RUNTIME_IDENTITY_MAP.csv` before touching transport.
5. If producer evidence is stale/event-only, decide whether a transport test has a direct consumer; do not refresh it by reattach/restart.
6. Inspect the exact transport worker/config paths and preserve existing bytes before any owner-approved mutation.
7. Verify rclone against the **same explicit config** the worker uses. `about` is only a read/auth probe; then prove the intended write path separately.
8. For a direct identity diagnostic, use one file and verify destination size/hash. Avoid broad Common\Files sync.
9. Confirm BaBoss local/synced arrival before running the canonical validator.
10. Only after canonical identity validation and a qualifying post-attach trade may first-trade/judge-clock logic advance.

## 6. Manual fallback policy while transport is unverified

Do **not** ask the owner to copy the sidecar every morning.

Manual copy is event-driven and read-only:
- after a new qualifying trade for magic `990026`, or
- after a known runtime lifecycle/attach epoch change when evidence reconciliation requires it.

Copy the current `EA_LAB_identity_463666728_990026.json` from VPS `Common\Files` to a bounded BaBoss evidence directory, then hash and validate it. A manual copy proves only the acquired bytes; it does not make transport PASS.

Do not force a trade, restart MT5, reattach the EA, or mutate strategy/runtime merely to refresh evidence.

## 7. Do-not-repeat list

- Do not confuse the 07:30 BaBoss DailyMonitor with a VPS pull task.
- Do not rerun OAuth blindly without first proving which config file is in use.
- Do not expose OAuth tokens or `rclone.conf` contents in chat/logs.
- Do not treat browser OAuth success or `rclone about` as write-path PASS.
- Do not accept a zero-byte destination object.
- Do not infer a permanent Server-2012/rclone incompatibility from one failed upload; current root cause is unresolved.
- Do not bypass unsupported Node/RDC platform checks on the VPS.
- Do not retry long pasted PowerShell after parser failure without confirming whether mutation occurred.
- Do not transfer an old trade across attach epochs.
- Do not start judge clock while `first_trade_epoch=null`.

## 8. Future automation acceptance target

The durable fix is a source-bound, unattended VPS -> BaBoss evidence transport that proves producer freshness, worker/config identity, destination byte integrity, BaBoss arrival, canonical validation, and scheduled recurrence. Until that exists, keep transport `BLOCKED / UNVERIFIED` and use the bounded event-driven manual fallback above.
