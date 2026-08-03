# Codex blind audit brief — Factory OS slice **S12** (direct Telegram Control Room + Morning Brief)

> Written 2026-08-03 by lane `S-2026-08-03-AUDITCOV`. **You are the independent brain.**
>
> This slice's built code has **never been independently audited**. Nothing in this brief tells you
> what any previous session concluded about it, and that omission is deliberate. If you find
> yourself agreeing with a claim, say *why the evidence supports it*, not *that it is stated*.

---

## 0. Read at a PINNED commit, not at HEAD

Another lane is writing in this repository. **Read every file through:**

```bash
git show a87f7448:<path>
```

`a87f7448` is the pin. If a path does not exist at that commit, say so rather than falling back to
the working tree.

## 0b. This audit is READ-ONLY — and for this slice that is not a formality

Do not edit, stage, commit, or create any file. **Do not send anything.** `notifier.py` has a real
transport and a `send --confirm` path that talks to the Telegram Bot API; the only commands you may
run are the read-only ones in §6. Do not write to `ops/`, `factory/`, or `.git/`.

**Do not attempt to obtain, print, or reconstruct the bot token.** If you find a path that would
expose it, describe the path and the file:line — never the value.

## 0c. Vocabulary note

This is a **trading-strategy research repository**. Its suites label deliberately-corrupted fixtures
`ATTACK` — mutation-testing vocabulary meaning *"mutate the input and prove the checker refuses
it."* The adversary in every case is a future careless writer, not an attacker.

---

## 1. What you are auditing, in one sentence

The alert path that carries a trading fleet's health to a human over Telegram, split by a **hard
seam**: a local side that holds the full snapshot and computes the dedupe key, and a sender side
that holds only a `SafeProjection` and, by design, **has no path to the snapshot at all**.

**Two stakes, and they pull in opposite directions.** A leak puts account numbers or a bot token
somewhere they can never be recalled. A swallowed alert means a real-money drawdown that nobody is
told about. A design that only optimises one of those fails at the other.

## 2. Read these, in this order

| | |
|---|---|
| `_triage/EA_LAB_FACTORY_OS_DESIGN.md` | **§7.1** (operations domain, read-only) · **§7.3** (notification design — the whole section, L804–837) · **§10** the **S12** row · row **16** of the table at L1176 |
| `_triage/factory_os/CONTRACTS.md` | `AlertEvent` · `AlertDelivery` · `SafeProjection` · `SystemFinding` |
| `AGENT_TASKBOARD.md` | row **`ORDER-1180`** (L968) — the order this slice was built under |

## 3. The artifacts

| file | what it decides |
|---|---|
| `_triage/factory_os/notifier.py` | the whole path: `observe` → `plan` → `assert_sendable` → `deliver`, plus the ledger, the dedupe key, routing, rendering and the Morning Brief |
| `_triage/factory_os/safe_projection.py` | the **one** reader the sender side is allowed to use |
| `_triage/factory_os/control_center.py` | `fold_finding` — the recovery/escalation rule, which S12 **calls rather than copies** |
| `_triage/factory_os/run_s12_tests.py` | the cage (in-process, plus three subprocesses for the cross-process ledger claim) |
| `scripts/_test/run_s12_tests.ps1` | adds two claims python cannot make: **B1** the token is not in the tracked tree, **B2** `ops/` runtime state is not either |
| `ops/delivery_ledger.jsonl` · `ops/finding_journal.jsonl` | per-machine append-only state — **not committed**, so you may not be able to read them at the pin. Say so if that limits a finding |
| `scripts/config.yaml` | holds the credentials — **git-ignored**. Do not read its values |

## 4. The claims — refute these

| # | claim | where |
|---|---|---|
| C1 | **the sender cannot leak what it was never handed** — `deliver()` reaches the projection only through `safe_projection.read_for_sender()` and has no path to the full snapshot | the seam; `IMPORT_CLOSURE`, `imports_of()`, `ALLOWED_IMPORTS` |
| C2 | **no token in git / logs / generated HTML / chat** — design §10's prohibition for this slice | `scrub()`, `PLACEHOLDER_TOKEN`, `run_s12_tests.ps1` B1 |
| C3 | **dedupe includes severity AND `material_revision`**, so an escalation from `WARN` to `REAL_MONEY` at unchanged state is *not* suppressed | `dedupe_key()`, `observe()` |
| C4 | **`OPEN → HEALTHY_1_OF_2 → OPEN` emits no recovery message**, and `FLAPPING` still gets a **bounded** reminder rather than permanent silence | `SILENT_STATES`, `control_center.fold_finding` |
| C5 | **the ledger stops a second send across process boundaries**, not merely within one process | `Ledger`, the three subprocess cases |
| C6 | **alerts work with OpenClaw stopped** — `openclaw_state()` measures it, and `imports_of()` proves the path cannot reach it | `OPENCLAW_PROCESS_NAMES`, `_tasklist()` |
| C7 | **no benign default is ever returned for an unrecognised input** — an unrouted severity, an unknown reason code and an unreadable process list are each a *stated* failure | `_routed()`, `REASON_CLASS`, `assert_reason_maps_agree()` |
| C8 | **the local side runs the full secret scan with the real secret list** before anything crosses the seam, because taking the snapshot away from the sender emptied that layer on the far side | `assert_sendable()` |
| C9 | the file computes **no threshold of its own** — every `dd_pct_band` reads `UNKNOWN` because no detector publishes one, rather than deriving a number | `render_morning_brief()` |

## 5. Where to aim

1. **The error paths, not the happy path.** C2 is easy to satisfy when everything works. Trace the
   token through: an exception traceback, a `subprocess` argv, an HTTP failure body, a retry log, a
   `repr()` of `Credentials`, a `--verbose` dump, the ledger, and anything written to `ops/`. Does
   `scrub()` sit on **every** one of those, or only on the ones someone thought of?
2. **`safe_detail()` and `scrub()` as the whole leak defence.** What input defeats them? Consider a
   token split across a formatted string, URL-encoding, a partial token, a chat id (design §7.3
   says a chat id **is a delivery credential** and must never appear in `AlertDelivery`).
3. **`imports_of()` proves a *static* property.** Does it? It parses source. What reaches OpenClaw
   or the snapshot at runtime without appearing as an import — `subprocess`, an env var, a relative
   path read, `importlib`, a module already in `sys.modules`?
4. **Suppression is the dangerous direction.** Enumerate every route by which a real alert ends as
   `SUPPRESSED_DUPLICATE`, `UNCONFIGURED`, or simply never planned. C3 protects one escalation
   shape; are there others — severity *down* then up, a `material_revision` that does not change
   when the material does, a `finding_id` that changes when the finding did not (which floods),
   clock skew, a day boundary, `RECURRENCE_WINDOW_HOURS`?
5. **`_recurrences()` and `parse_at()`.** Time handling is where quiet suppression lives. What
   happens with a missing timestamp, a non-monotonic one, a timezone, or a journal replayed after
   an outage — the exact case C5's ledger exists for?
6. **C5's cross-process claim.** Three subprocesses prove *a* case. Is the ledger write atomic
   under a concurrent second writer, a crash between send and receipt, or a partially-written last
   line? An append-only ledger that can record a send that did not happen fails **closed** (silence);
   one that can miss a send that did happen fails **open** (spam). Which way does this one fail?
7. **`fold_finding` is CALLED not copied — verify that is still true**, and that the caller cannot
   pass arguments that make the shared rule behave differently here than in the dashboard.
8. **C9's `UNKNOWN`.** A field that is always `UNKNOWN` is indistinguishable from a field nothing
   populates. Is there a path that makes it something else, and would anyone notice if the detector
   that should publish it silently stopped?
9. **The two suites' division of labour.** `run_s12_tests.ps1` says a python suite "cannot assert
   what git TRACKS". Agree — but does B1's grep actually match the token *shape* that would be
   emitted, and does B2's check fire on a real violation or only on a synthetic one? A prohibition
   nobody can check is a sentence; so is a check that cannot fail.
10. **The one real send.** The order says the live leg was driven **once, by hand**, with a receipt
    in `ops/delivery_ledger.jsonl` — a file that is not committed. What in the repository lets a
    reader verify that claim, and if nothing does, say so.

## 6. How to reproduce — the read-only commands only

```bash
tools/python312/python.exe _triage/factory_os/run_s12_tests.py
```
```bash
tools/python312/python.exe _triage/factory_os/run_s12_tests.py --list
```
```bash
powershell -NoProfile -File scripts/_test/run_s12_tests.ps1
```

🚫 **Never run** `notifier.py send --confirm` or `notifier.py probe ... --confirm`. Both transmit.
`notifier.py plan` is read-only and safe.

⚠️ Two suites unrelated to S12 (`run_s2a_gate` F2, `check_coverage_transfer` A8) are **known red at
this pin** for a reason already recorded elsewhere. If you see them fail, that is not your finding.

## 7. What a finding must contain

`file:line` · the **input or state** that exposes it · the consequence stated as either *what
escapes* or *what alert never arrives* · and, where you can, a **command that reproduces it**. A
finding you cannot reproduce is a hypothesis — label it and file it anyway.

Rank by severity, and keep **"this leaks"** separate from **"this goes quiet"** — they are different
failures with different owners.

## 8. No lane is needed

Source plus python cages. No MT5 terminal, no backtest, and **no message sent**.
