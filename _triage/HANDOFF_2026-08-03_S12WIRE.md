# HANDOFF — S12 wired into the daily chain (`ORDER-1200`)

> Lane `S-2026-08-03-S12WIRE`, 2026-08-03. No MT5 lane, no EA verdict, no `.set` touched.
> The tier work (`ORDER-1130`) and slice **S13** belong to the parallel **ACTIVE** lane
> `S-2026-08-03-TIERROOM` — this lane did not touch either.

---

## What changed

1. **`scripts/daily_monitor.ps1`** now builds the `SafeProjection` and runs
   `notifier.py send --confirm --brief` right after the `snapshot` Step.
2. **`notifier.py`** splits its exit codes so an unconfigured channel cannot turn the daily chain
   red every morning (see the table below).
3. **`_triage/FXDREEMA_XRAY.md`** — the third party's Telegram token and chat id are removed from
   `HEAD`. History deliberately not rewritten.

## The one thing standing between this and a message on your phone

**The `EA LAB Control Room` bot does not exist.** Until it does, the chain runs, logs
`6 × UNCONFIGURED`, exits `4`, and stays *healthy* — by design. Two minutes:

1. BotFather → new bot, name it `EA LAB Control Room`.
2. Send the bot one message from the account that should receive the brief.
3. Get the chat id — `powershell -File scripts\mris\mris_notify.ps1 -ShowChatIds` prints chat ids
   without the token ever reaching a URL bar.
4. Put both in `scripts/config.yaml`:
   `telegram_control_room_bot_token` · `telegram_control_room_chat_ids`.
   **That file is git-ignored and must stay that way** — PART B of the S12 cage asks git directly,
   every run.
5. Verify without waiting for tomorrow — this sends ONE real message to the new channel:

```bash
tools/python312/python.exe _triage/factory_os/notifier.py probe --id CR-FIRST --channel CONTROL_ROOM --confirm
```

   A probe reads no snapshot and no projection, so it works even when those are broken — which is
   exactly when you most want to know whether alerts can still leave the machine.

## Exit codes, and why they are what they are

| exit | meaning | daily chain |
|---|---|---|
| `0` | everything delivered | healthy |
| `1` | a **configured** channel failed to deliver | **unhealthy** |
| `3` | local inputs unreadable (instrument fault) | **unhealthy** |
| `4` | a channel has no credentials yet | logged loudly, **healthy** |

`4` is still non-zero — nothing here calls "not set up" a success. It is a *different* non-zero so
the caller can tell *"you have not configured this"* from *"it broke"*. The rule it obeys was
already in `daily_monitor.ps1`, written by `ORDER-219`: **a report that turns the chain red every
morning is a report that gets muted inside a week.**

## Three PowerShell traps this cost, all found by DRIVING the block rather than reading it

The probe extracts the notify block **verbatim from `daily_monitor.ps1`** and executes it, so what
is tested is the file's own bytes rather than a retyped copy:

1. **`powershell -Command` does not propagate a child's exit code.** The notifier returned `4`, the
   caller saw `1`. Needs `; exit $LASTEXITCODE` **inside** the command string.
2. **…and that `$LASTEXITCODE` must be backtick-escaped** (`` `$LASTEXITCODE ``), or the *outer*
   shell expands it at parse time and hands the child a number from an unrelated command.
3. **Writing the log as UTF-8 fixes nothing on its own.** PowerShell decodes a native command's
   stdout with `[Console]::OutputEncoding`, which defaults to the ANSI codepage — the Thai was
   already mangled *at capture time*. Set `[Console]::OutputEncoding` **and** write UTF-8; save and
   restore it so no other Step inherits a global this block set for itself.

Related, and pre-existing: `portfolio/daily_monitor.log` already contains UTF-16-spaced output from
other Steps (git's, among others) because `*>> $log` decodes children the same wrong way. **Not
fixed here** — it touches every Step in the file and belongs to whoever owns that chain.

## Owed

| item | destination |
|---|---|
| create the `EA LAB Control Room` bot + fill the two config keys | owner, 2 minutes |
| re-register `run_s12_tests.ps1` in the fast tier once the room exists | `ORDER-1130` / `TIERROOM` lane |
| `ops/delivery_ledger.jsonl` grows ~6 lines/day while unconfigured — rotation, never truncation | `ORDER-1180` (owed) |
| a producer for `REAL_MONEY` severity — the emergency channel's only reachable traffic is `CRITICAL` | `ORDER-1180` (owed) |
| a `dd_band` detector — every band still reads `UNKNOWN`, correctly | `ORDER-1131` (owed since S11) |
| `portfolio/daily_monitor.log` is mixed-encoding from the `*>> $log` convention | unowned |
| `SKILLS DRIFT` — an `adhd-mode` skill appeared from outside the repo mid-session | unowned |

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| notifier ต่อท้าย `snapshot` ใน `daily_monitor.ps1` วันละครั้ง (owner decision) | DONE |
| exit-code split 0/1/3/4 + เคส `C05`/`C08` ขับทั้งสองฝั่ง | DONE |
| `powershell -Command` ไม่ส่งต่อ exit code ของลูก | DONE |
| `$LASTEXITCODE` ต้อง escape ด้วย backtick ไม่งั้น shell นอกขยายก่อน | DONE |
| `[Console]::OutputEncoding` ต้องตั้งด้วย ไม่ใช่แค่ `-Encoding utf8` | DONE |
| `NOT CONFIGURED` ย้ายจาก stderr → stdout (กัน `NativeCommandError` กลืน) | DONE |
| ลบ token + chat id ของบุคคลอื่นออกจาก `FXDREEMA_XRAY.md` ที่ HEAD | DONE |
| quarantine entry คงไว้ที่ `0` เพื่อให้ไฟล์ยังถูกเฝ้า | DONE |
| owner สร้างบอท `EA LAB Control Room` + ใส่ 2 คีย์ | owner |
| ORDER-1130 (tier) + re-register กรง S12 + slice S13 | `S-2026-08-03-TIERROOM` |
| `daily_monitor.log` encoding ปนกันจาก `*>> $log` ของ Step อื่น | ไม่มีเจ้าของ |
| `SKILLS DRIFT` (`adhd-mode` โผล่จากนอก repo) | ไม่มีเจ้าของ |
