# EA_LAB Control Tower Prompt Patch — 2026-09-11

Use this as a compact carry-forward block for the ONE existing Control Tower. Git still wins over this handoff.

## ORDER-353 / VPS evidence operations

- Current canonical ORDER-353 binding: `463666728|990026` expects `epoch-2`; `first_trade_epoch=null`; `judge_date=null`; judge clock NOT STARTED; forward state remains `FORWARD_TEST_UNTRUSTED`.
- Historical ticket `2227380592` predates epoch-2 attach boundary `1789039970`; never transfer it across epochs.
- Model data path as `VPS EA -> MT5 FILE_COMMON -> transport -> BaBoss local/synced input -> DailyMonitor -> Monitor`.
- BaBoss `EA_LAB_DailyMonitor` is a consumer, not a VPS puller. Observed schedule: 07:30 daily plus logon. A non-zero task result can be intentional fail-closed monitoring; inspect named failures before declaring the task broken.
- RuntimeIdentity is event-driven at init/first qualifying entry; no accepted heartbeat refreshes it every morning. Do not request daily copies of unchanged sidecars.
- Automated VPS->BaBoss transport remains `BLOCKED / UNVERIFIED`; root cause stays `UNKNOWN` until bounded reproduction isolates it.
- Manual fallback is read-only/event-driven: request a sidecar only after a new qualifying trade or a known attach/lifecycle change with a direct evidence consumer.
- Never force a trade, restart MT5, reattach an EA, or mutate runtime just to refresh evidence.
## VPS diagnostic rules learned

- Pin host/device ID/hostname explicitly before consequential work. Do not infer the VPS from the first online Desktop Commander device.
- VPS Windows Server 2012 R2 rejected the modern Node-based RDC path; do not bypass with `NODE_SKIP_PLATFORM_CHECK=1` without a separate authorized control-channel contract.
- Prefer one short RDP command at a time. Use file-backed PowerShell for multi-step logic; parser/paste failures are harness/operator failures until mutation is proven.
- rclone diagnostics must use the worker's exact config `C:\rclone\rclone.conf`; OAuth reconnect against a default config can repair the wrong file.
- Never expose OAuth tokens or `rclone.conf` secrets in chat/logs. Headless OAuth: authorize on a browser-capable machine, paste the returned token directly into the VPS prompt.
- `rclone about` or browser OAuth success proves read/auth only, not write delivery. Transport PASS needs a real intended-destination write/readback, non-zero size, preferably hash equality, and BaBoss arrival.
- A zero-byte remote object is invalid evidence. Snapshot `nameAlreadyExists` and identity `Unauthenticated` were both observed; neither alone proves the permanent root cause.
- A direct single-file `copyto` may isolate the identity path diagnostically, but it does not replace the production worker or authorize worker-semantic changes.
- Manual replacement of `push_snap.cmd` is not end-to-end acceptance. Scheduled-task binding and repeated automatic delivery still require proof.

Canonical operator detail: `docs/workflows/ORDER353_VPS_EVIDENCE_RUNBOOK_20260911.md`.
## Report V3 Phase B transient status

- Worker handoff frozen HEAD: `c0292a26253e49982d251b0ffa90594b555da5a6`, branch `ct/report-v3-phaseb-20260911`.
- Reported gates: Phase A 28/28 focused + 48/48 reporting; Phase B 83/83 data tests; mobile 390x844, desktop 1280x900; security/cache checks and hooks PASS.
- H08 intentionally shows `GRAPH ASSET MISSING / INCOMPLETE`; canonical metrics and `DO_NOT_ADOPT_CENTER_RETAIN_PARENT_RESEARCH_REFERENCE` conclusion remain unchanged.
- No push, PROJECT_STATE change, research-verdict change, MT5/VPS/runtime change, or deployment occurred. Preservation exception: old mandatory status helper refreshed primary generated STATUS.html and its OneDrive copy; later run used the isolated helper.
- This is implementation/test PASS only. Fresh independent exact-head review is required before acceptance/integration/push.
- Evidence locator: `D:\EA_LAB_CONTROL\evidence\ct-report-v3-phaseb-20260911\RESULT.md`.

Do not let this prompt patch outrank pushed Git, exact lane state, or a later reviewed integration result.
