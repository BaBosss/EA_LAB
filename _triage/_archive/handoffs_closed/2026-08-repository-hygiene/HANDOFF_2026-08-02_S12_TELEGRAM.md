# HANDOFF — slice **S12**: direct Telegram Control Room + Morning Brief

> Lane `S-2026-08-02-S12TG`, 2026-08-02. Order `ORDER-1180`, **DONE**. No MT5 lane used, no EA
> verdict issued, no `.set` touched. **Read `ORDER-1180` on the board first** — it holds the
> evidence; this file holds what the next lane needs to *do*.

---

## What exists now that did not this morning

`_triage/factory_os/notifier.py` — the alert path end to end, with one hard seam:

| side | has | does |
|---|---|---|
| **LOCAL** `observe()` / `plan()` | the verified snapshot, the finding journal, the internal ids | computes `material_revision` (which **cannot** come from the projection), routes by severity, and runs the **known-secret scan** — the layer only this side *can* run |
| **SENDER** `deliver()` | `AlertEvent`s and nothing else | talks to `api.telegram.org`, writes `(dedupe_key, channel, outcome, receipt)` |

Entry point a human runs: `notifier.py plan` (never sends) · `send --confirm` · `probe --id X
--channel Y --confirm`. Cage: `_triage/factory_os/run_s12_tests.py` +
`scripts/_test/run_s12_tests.ps1`, registered in the fast tier.

**Nothing schedules it.** That is the next step and it is deliberate — see *Owed*.

---

## The four things you must not undo

1. **`safe_projection.read_for_sender` is the only reader a sender gets.** `notifier.load_local` is
   the one place both documents are obtained. Do not add a second.
2. **`control_center.fold_finding` is the recovery rule.** `observe()` calls it. Case `V04` spies on
   it and fails if it stops being called — a second copy is how the two drift.
3. **The routing table is CLOSED.** A severity that is not a key REFUSES. It does not fall through
   to the quiet channel and it does not fall through to nothing.
4. **No threshold is computed in the notifier.** The Morning Brief prints the band a detector
   publishes, and when nobody publishes one it says so. Do not derive a DD percentage from
   `equity`/`balance` — that is a new detector's job, in its own order.

---

## Owed, in the order a next lane should take them

### 0. 🔴 THE FAST TIER HAS 1.3s OF HEADROOM, NOT 8s — and the S12 cage is sitting outside it

This is the first thing to read and the reason the acceptance is a partial.

| invocation | tier | measured (3 samples) |
|---|---|---|
| from a shell | 25 suites | **110.8 / 111.5 / 112.4s** |
| `-Hook` (what the pre-commit hook uses) | 25 suites | **118.6 / 118.7 / 118.7s** |
| `-Hook` **with `run_s12_tests.ps1` registered** | 26 suites | **122.0 / 121.6 / 122.1s — REFUSED, over the 120.0s budget** |

The "~8s of headroom" in every recent handoff — including S12's own opening prompt — is a
**non-hook** number. The hook is the only invocation that decides whether a commit lands
(memory `tier-number-needs-its-invocation`). And staged paths that match no guard **fall back to
running everything**: `-ExportSelection` over one `_mt5_auto/*.csv` selects all 26 suites, so
committing a backtest CSV is a full hook-mode run.

So `run_s12_tests.ps1` is **commented out of `$FAST_SUITES` together with its `$SUITE_GUARDS`
entry** — both, or `run_guard_trigger_tests` fails on the key sets disagreeing. Run it by hand:

```bash
powershell -NoProfile -File scripts/_test/run_s12_tests.ps1
```

**Re-registering is uncommenting two blocks and regenerating the pathspec**, the moment
`ORDER-1130` buys the room. `ORDER-1130` is not a nice-to-have any more: at 1.3s of headroom the
next cage anyone writes hits this same wall.

### 1. The `EA LAB Control Room` bot does not exist (owner action, 2 minutes)
Every `WARN`/`INFO` alert and the Morning Brief currently report **`UNCONFIGURED`** and the CLI
exits non-zero. That is the designed behaviour, not a bug — but it means **nothing reaches the
Control Room channel until the owner does this**:

1. Create a bot with BotFather, name it `EA LAB Control Room`.
2. Send it one message from the account that should receive briefs.
3. Get the chat id: `powershell -File scripts\mris\mris_notify.ps1 -ShowChatIds` prints chat ids
   without the token ever reaching a URL bar. *(That helper reads `telegram_bot_token` — the
   emergency bot — so for the new bot either paste the new token there temporarily or read the id
   from the same chat.)*
4. Fill `telegram_control_room_bot_token` and `telegram_control_room_chat_ids` in
   `scripts/config.yaml`. **That file is git-ignored and must stay that way** — PART B of the cage
   asks git directly, every run.
5. Verify: `notifier.py probe --id CR-FIRST --channel CONTROL_ROOM --confirm`.

### 2. Schedule it — and read this before you do
The moment anything runs `notifier.py send` on a timer, three things become real that are only
theoretical today:
- **`ops/delivery_ledger.jsonl` grows without bound** (one line per event per run). The retention
  answer recorded in D1 is **rotation with the rotated files kept, never truncation** — a truncated
  ledger silently re-enables a duplicate send.
- **`ops/finding_journal.jsonl` is what makes recovery possible at all.** Delete it and every open
  finding re-alerts as new, and no recovery can ever fire. It is git-ignored; it is not disposable.
- **The FLAPPING reminder is per calendar day.** That cadence is a notification choice this module
  made and states; if the owner wants a different one it is one constant in `dedupe_key`.

### 3. A third party's Telegram token is committed in `_triage/FXDREEMA_XRAY.md` (owner decision)
Found by the cage's tracked-tree sweep. It is inside the x-ray of a downloaded fxDreema EA — not
this project's credential, and nothing here uses it. It is **quarantined at exactly 1 hit** in a
closed declaration in `run_s12_tests.ps1`, so a second one anywhere still fails the tier. The
decision is scrub-the-line or accept-it; history rewriting was not something to do as a side effect
of this slice.

### 4. Smaller, and each already measured
- **`REAL_MONEY` is unreachable.** No code path produces that severity, so the emergency channel's
  only reachable traffic today is `CRITICAL` (2 reason codes, both "a mandatory source is
  missing/unreadable"). Until a detector emits `REAL_MONEY`, the highest-stakes routing rule is
  live but untravelled.
- **`dd_band` still has no producer** (owed from S11). Every band reads `UNKNOWN`, correctly.
- **`WINDOWS_ABSOLUTE_PATH` matches the `s:/` in `https://`**, so any URL inside a failure detail is
  redacted and the operator loses the HTTP status. Fail-closed, measured by case `L09`. Widening a
  rule shared with the projection's leak scan needs its own order.
- **`AlertEvent`/`AlertDelivery` are `BUILT`, not `WIRED`** — correct today, and they flip the day
  something in production sends.

---

## Two traps this lane paid for, in the exact place the next lane will hit them

**Adding an entity to `schemas.json` moves the S2a bundle.** `check_s2a_migration.py` C1 demands an
ownership row for *every* schema entity, so a new entity drags `s2a_migration.jsonl`, the coverage
reconciliation, `S2A_OWNERSHIP_MIGRATION.md` and often `check_s2a_migration.py` itself — and every
one of those is a bundle member, so the owner's standing attestation stops being valid and the fast
tier goes red **for the whole repo**. Budget for it; it is not optional and it needs the owner.
The sequence that works:

```bash
tools/python312/python.exe _triage/factory_os/gen_s2a_migration.py
tools/python312/python.exe _triage/factory_os/gen_s2a_migration_doc.py
tools/python312/python.exe _triage/factory_os/check_s2a_attestation.py --template
```

Regenerate **D1 and D2 first, then take the template, then append.** Taking the digest and *then*
regenerating D2 produces a line that is stale the moment you write it — D2 is itself a bundle
member. That cost one red run here. And **`Set-Content -Encoding utf8` writes a BOM** which the
attestation log's own reader refuses with `Unexpected UTF-8 BOM`; write it with python, or
`Add-Content` to a file that already has no BOM.

**`2>$null` on a native command inside PowerShell 5.1** wraps each stderr line in an ErrorRecord,
which under `$ErrorActionPreference = 'Stop'` **throws** — so a check dies on exactly the condition
it exists to report. `run_s12_tests.ps1` PART B has none, on purpose. Related, same file: `:!path`
is a *fatal* pathspec error when the path starts with `_` (git reads it as pathspec magic), and a
fatal `git grep` produces zero output — which read as CLEAN until a control was added that drives
the same invocation against a string known to be present. **A control that tests the regex is not a
control that tests the invocation.**

---

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| `notifier.py` — local/sender seam, routing, dedupe key with severity + material_revision | DONE |
| per-channel delivery ledger `(dedupe_key, channel, outcome, receipt)`, replay-safe | DONE |
| one recovery message, none on an intermediate healthy check, escalation not swallowed | DONE |
| FLAPPING bounded reminder (design §7.3 + §11 row 16) | DONE |
| `occurrences_24h` counted observations rather than recurrences | DONE |
| the ledger wrote unscrubbed provider errors, and a Telegram send URL carries the token | DONE |
| real delivery observed with OpenClaw stopped (`message_id=9`), replay suppressed | DONE |
| `AlertEvent` / `AlertDelivery` in `schemas.json` + CONTRACTS.md + ajv fixtures | DONE |
| S2a ownership rows for both entities, owner-ratified, one attestation line appended | DONE |
| three `/scrutinize` rounds: HEALTHY_1_OF_2 spam · the hook-mode tier budget · a dead `PUBLIC_API` | DONE |
| 🔴 `run_s12_tests.ps1` is NOT registered in the fast tier — 1.3s of hook-mode headroom, suite is 2.9s | ORDER-1130 |
| the "~8s headroom" figure quoted across recent handoffs is a NON-HOOK number and should stop being repeated | ORDER-1130 |
| owner creates the `EA LAB Control Room` bot + fills the two config keys | ORDER-1180 (owed) |
| schedule `notifier.py send`, and the ledger rotation that becomes real when it is scheduled | ORDER-1180 (owed) |
| third-party Telegram token committed in `_triage/FXDREEMA_XRAY.md` — scrub or accept | ORDER-1180 (owed) |
| `WINDOWS_ABSOLUTE_PATH` matches the `s:/` in `https://`, so a URL in a failure detail is redacted | ORDER-1180 (owed) |
| no producer emits `REAL_MONEY`, so the emergency channel's only reachable traffic is `CRITICAL` | ORDER-1180 (owed) |
| a `dd_band` producer — every band still reads `UNKNOWN` | ORDER-1131 (owed since S11) |
| `AlertEvent` / `AlertDelivery` → `WIRED` once something in production sends | ORDER-1180 (owed) |
| fast tier at ~111.5s of 120.0s — headroom is the constraint, not this suite | ORDER-1130 |

## How to convince yourself this works, from cold

```bash
tools/python312/python.exe _triage/factory_os/run_s12_tests.py
```
Expect `0 failed, 0 roll-up problem(s)` and a printed coverage table naming which case first
produced each behaviour. Then the thing that actually matters:

```bash
powershell -NoProfile -File scripts/_test/run_s12_tests.ps1
```
PART B asks **git** whether the token prohibitions hold — a claim no python assertion can make.

The suite was green on its **first** run, which is the weakest kind of evidence, so it was checked
by planting **14 mutants** one at a time and requiring each to be caught. Thirteen died at once;
one survived and was a real defect (a `FAILED` delivery suppressed forever at the file level).
The sweep scripts are in this session's scratchpad and are cheap to rewrite — if you change
`deliver()`, `dedupe_key()` or `observe()`, plant a mutant before you believe the green.
