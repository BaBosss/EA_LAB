# Control Tower Handoff — ORDER-353 VPS Evidence Lessons / Prompt Patch

Date: 2026-09-11
Base: `346175b42e68405aea0bc099a67009090bfedc0e`
Consumer: the ONE existing EA_LAB Main Control Tower / next prompt rotation.
Authority: operations/evidence only; no new runtime, risk, deployment, LIVE or judge-clock authority.

## Status to carry forward

- ORDER-353 expected attachment identity is canonical `epoch-2`.
- `first_trade_epoch=null`; `judge_date=null`; judge clock is NOT STARTED.
- Old candidate ticket `2227380592` predates epoch-2 attach boundary and is not transferable.
- Manual epoch-2 sidecar acquisition succeeded; acquired bytes matched identity pins but were stale at reconciliation.
- Automated VPS -> BaBoss transport remains `BLOCKED / UNVERIFIED`; root cause is `UNKNOWN` until bounded reproduction isolates it.
- Global monitoring remains `DEGRADED_MONITORING`.
- BaBoss `EA_LAB_DailyMonitor` is enabled at 07:30 daily plus logon and consumes local/synced evidence; it is not a VPS puller.

Canonical operator runbook:
`docs/workflows/ORDER353_VPS_EVIDENCE_RUNBOOK_20260911.md`

## Prompt-update block

Add the following compact rule block to the next Control Tower prompt/Operating Context rotation. Do not let it override Git/AGENTS/PROJECT_STATE.

### ORDER-353 / VPS EVIDENCE OPERATIONS

- Model the path as `VPS producer -> FILE_COMMON -> transport -> BaBoss input -> DailyMonitor -> Monitor`; DailyMonitor does not fetch from VPS.
- RuntimeIdentity is event-driven (init/first qualifying entry), not an accepted heartbeat. Do not ask for daily manual copies of an unchanged sidecar.
- While automated transport is unverified, manual sidecar acquisition is read-only and event-driven: request it only after a new qualifying trade or known attach-epoch/lifecycle change with a direct evidence consumer.
- Always pin the actual host/device and exact origin/master before VPS work; Desktop Commander on BaBoss is not evidence that the VPS is reachable through the same control channel.
- On the VPS use short commands; use file-backed PowerShell for multi-step logic. Treat parser/paste failures as harness failures until mutation is proven.
- rclone diagnostics must use the exact worker config path `C:\rclone\rclone.conf`. Never expose OAuth tokens. `about`/quota success is not write-path PASS; require a real non-zero write/readback with byte/hash confirmation.
- Preserve transport root-cause as `UNKNOWN` unless bounded reproduction isolates it. Do not generalize one failed upload into a permanent Windows/rclone incompatibility claim.
- Never transfer a historical trade across attach epochs and never start judge clock while `first_trade_epoch=null`.
- Manual worker replacement does not prove the Scheduled Task uses those bytes; prove producer -> worker/config -> destination -> BaBoss -> validator -> repeated schedule end to end.

## Incoming transient handoff — Report V3 Phase B

A separate worker handoff was received after this VPS runbook was drafted. Treat it as transient until independent review/integration:
- frozen HEAD `c0292a26253e49982d251b0ffa90594b555da5a6` on `ct/report-v3-phaseb-20260911`;
- implementation/test gates reported PASS: Phase A 28/28 focused + 48/48 reporting; Phase B 83/83 data tests; mobile 390x844, desktop 1280x900, security/cache checks and hooks PASS;
- H08 correctly renders `GRAPH ASSET MISSING / INCOMPLETE` while preserving canonical metrics/conclusion;
- worktree observed clean; no push; PROJECT_STATE/research/runtime unchanged;
- evidence: `D:\EA_LAB_CONTROL\evidence\ct-report-v3-phaseb-20260911\RESULT.md`;
- next action: fresh independent exact-head review. Do not call this canonical acceptance until that review passes and normal integration/push gates complete.
