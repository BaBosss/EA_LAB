# OPENING PROMPT — after **S12**: the tier is the blocker, then slice S13

> Written 2026-08-02 by lane `S-2026-08-02-S12TG`, after building S12 and running three
> `/scrutinize` rounds over it. **Read the two boxes below before you plan anything.** The first
> one will change what you decide to do; the second is the only reason S12 is a partial.

---

## 🔴 BOX 1 — THE NUMBER EVERY RECENT HANDOFF HAS BEEN QUOTING IS WRONG

Every prompt in this chain, including S12's own, has said the fast tier has **~8s of headroom**.
It does not. That figure is measured **from a shell**. The pre-commit hook launches the tier with
`-Hook`, and that is the only invocation that decides whether a commit lands:

| invocation | suites | measured, 3 samples |
|---|---|---|
| from a shell | 25 | **110.8 / 111.5 / 112.4s** |
| **`-Hook`** | 25 | **118.6 / 118.7 / 118.7s of 120.0s → 1.3s headroom** |

And it is worse than a thin margin, because **staged paths that match no guard run EVERYTHING**
(`Select-Suites` fails open, deliberately). `-ExportSelection` over a single `_mt5_auto/*.csv`
selects **all 26 suites**. Committing a backtest CSV is a full hook-mode run.

**Consequence: no new cage fits.** S12's is 2.9s; registered, the hook tier measured
**122.0 / 121.6 / 122.1s** and refused the commit. So `ORDER-1130` is not a nice-to-have — it is
the thing standing between this project and its next cage, and it should be the first order you
take unless the owner redirects you.

Do not re-derive this from a shell run and conclude it is fine. Memory: `tier-number-needs-its-invocation`.

## 🔴 BOX 2 — S12 IS DONE WITH ONE STATED PARTIAL

`ORDER-1180` is `DONE`. The sender, the per-channel delivery ledger, the dedupe key carrying
severity **and** `material_revision`, the one-recovery rule and the FLAPPING bounded reminder are
built and driven, and **one real Telegram message was delivered with the gateway observed down**
(`message_id=9`, `openclaw=NOT_RUNNING` recorded on the ledger line beside the receipt), with its
replay suppressed at zero HTTP calls. Suite: **65 scenarios, 0 failed, both roll-ups.**

**The partial: `scripts/_test/run_s12_tests.ps1` is NOT registered in the fast tier** — Box 1 is why.
It is commented out of `$FAST_SUITES` **together with its `$SUITE_GUARDS` entry** (both, or
`run_guard_trigger_tests` fails on the key sets disagreeing, which is that guard working).
Re-registering is uncommenting two blocks and running `scripts/gen_fast_tier_pathspec.ps1`.
Meanwhile: `powershell -NoProfile -File scripts\_test\run_s12_tests.ps1`.

---

## Owner actions waiting (neither needs an engineer)

1. **Create the `EA LAB Control Room` bot.** Until it exists, every `WARN`/`INFO` alert and the
   Morning Brief report `UNCONFIGURED` and the CLI exits non-zero — which is the designed
   behaviour, not a bug, but it means nothing reaches that channel. BotFather → send it one
   message → put the token and chat id in `telegram_control_room_bot_token` /
   `telegram_control_room_chat_ids` in `scripts/config.yaml` (git-ignored, and a cage check asks
   git that every run). Verify with
   `notifier.py probe --id CR-FIRST --channel CONTROL_ROOM --confirm`.
2. **A third party's Telegram bot token is committed in `_triage/FXDREEMA_XRAY.md`**, inside the
   x-ray of a downloaded fxDreema EA. Not this project's credential, nothing here uses it, and it
   is quarantined at exactly 1 hit in a closed declaration so a second one anywhere still fails.
   Scrub the line or accept it — an owner call, because history rewriting is not a side effect.

## Before you start — verify, do not assume

- **Re-derive your order block from BOTH tests**: parse `## ORDER-<n>` out of all four board files
  **and** check every reserved block in `docs/SESSION_LEDGER.md`. A reserved-but-unused block is
  invisible to the number test, and that trap has fired twice in three days. As of this writing the
  highest order in use is **1180** and the highest reserved block is **1180-1189**, so **1190-1199**
  is the next one — **but check, and commit the reservation before using a number.**
- **Baseline green first**, and note the shape: `run_s12_tests.ps1` is **not** in the tier, so run it
  separately. `run_fast_cages.ps1` · `run_s2a_gate.py` · `run_schema_fixtures.py` ·
  `check_schema_structure.py` · `gen_design_contracts.py --check`.
- **Delete `_triage/factory_os/__pycache__`** before the first generator run.
- `git log --oneline -15`.

## Two traps this lane paid for, in the exact place you will hit them

**Adding an entity to `schemas.json` moves the S2a bundle, and that costs the owner a signature.**
`check_s2a_migration.py` C1 demands an ownership row for **every** schema entity, so a new entity
drags `s2a_migration.jsonl`, the coverage reconciliation, `S2A_OWNERSHIP_MIGRATION.md` and often
`check_s2a_migration.py` itself — all bundle members — and the owner's standing attestation stops
describing what is on disk, turning the whole repo's tier red. Budget for it. The sequence:

```bash
tools/python312/python.exe _triage/factory_os/gen_s2a_migration.py
tools/python312/python.exe _triage/factory_os/gen_s2a_migration_doc.py
tools/python312/python.exe _triage/factory_os/check_s2a_attestation.py --template
```

Regenerate **D1 and D2 first, then take the template, then append** — taking the digest and *then*
regenerating D2 produces a line that is stale the moment you write it, because D2 is itself a bundle
member. And **`Set-Content -Encoding utf8` writes a BOM** the attestation log's own reader refuses.
Both cost a red run here.

**Thai output kills a suite inside the hook and hides why.** python takes its stdout encoding from
the console codepage; a child of the pre-commit hook gets an ANSI-codepage pipe, so the first Thai
character raises `UnicodeEncodeError`, the traceback lands on stderr, and the wrapper's `2>&1` under
`$ErrorActionPreference='Stop'` turns that into a terminating error — the tier prints
`exit -1  SUITE THREW` with the cause swallowed. It took down **S11's suite as well**, latently, for
as long as that suite has existed. Reproduce with `chcp 1252`. Every python-invoking wrapper needs
`$env:PYTHONIOENCODING = 'utf-8'`; check the ones written before today.

Related, same file: `:!path` is a **fatal** pathspec error when the path starts with `_` (git reads
it as pathspec magic), and a fatal `git grep` produces zero output — which reads as CLEAN. A control
that tests the *regex* is not a control that tests the *invocation*; write both.

## Build guidance these three rounds paid for

- 🔴 **Meeting the acceptance's letter is not meeting it.** Round 1: design §7.3 forbids a *recovery*
  message on an intermediate healthy check. The code withheld the recovery **label** and sent an
  alert saying `HEALTHY_1_OF_2` instead — the same spam under a different word — and the case
  asserted `['ALERT','ALERT','ALERT']`, i.e. **the implementation written down as the requirement**.
  When you write an assertion, ask what it would look like if the code were wrong.
- 🔴 **Count what LEAVES, not what is planned.** The case that would have caught round 1 alone drives
  `observe → plan → deliver` with a real ledger and counts messages sent.
- 🔴 **A suite green on its first run has proved nothing yet.** S12's was written after the module, so
  **14 mutants** were planted one at a time instead. Thirteen died; the survivor was real — a
  `FAILED` delivery suppressed forever, because the retry had only been proven against an in-memory
  set and never against the FILE the next scheduled run reads.
- 🔴 **A declaration nothing reads is decoration.** Round 3: `PUBLIC_API` was declared and consumed by
  no check (memory `declared-as-trigger-but-never-read`).
- 🔴 **A guard that reports CLEAN because its instrument died is the worst outcome available.** It
  happened twice today: a fatal `git grep` returning nothing, and a `-1 SUITE THREW` with no reason.

## Do NOT do in this session

- 🚫 Put a token in git, a log, generated HTML, a handoff, or chat.
- 🚫 Register a new fast-tier suite without measuring the tier **with `-Hook`** first.
- 🚫 Raise `$FullTierBudgetSeconds` — `run_guard_trigger_tests` asserts it is *the measured 120.0s*,
  which makes it a ratified number. Buy the room (`ORDER-1130`), do not move the line.
- 🚫 Send a real message to a real chat without the owner's explicit go-ahead in this session.
- 🚫 Let anything but `safe_projection.read_for_sender` open a document for the sender · build a
  second projection · write a second snapshot reader · copy `control_center.fold_finding`.
- 🚫 Compute a drawdown band, a DD percentage or any risk threshold in the notifier.
- 🚫 Edit any committed `factory/runs/*.jsonl` · issue a `CandidateManifest` for a real EA · append
  an attestation event to a real deployment · allocate, renumber or retire a magic.
- 🚫 Touch `MASTER_BACKLOG.md` §2 · `AGENTS.md` · any EA verdict · any `.set` migration.

Open with: **"อ่านไฟล์นี้ แล้วเริ่ม — ปิด ORDER-1130 (tier headroom) ก่อน แล้วค่อยลง S13"**
