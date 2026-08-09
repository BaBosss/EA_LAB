# OPENING PROMPT — slice **S12**: direct Telegram Control Room + Morning Brief

> Written 2026-08-02 by lane `S-2026-08-02-SCRUT11S`, after three `/scrutinize` rounds over the
> completed S11. **This session needs no MT5 lane.** It also needs no new snapshot, no new
> projection and no new reader — S11 built all three. What it needs is a **sender**, and the
> hardest acceptance is again a *negative*: the sender must not be able to read the full snapshot,
> and it already cannot. Your job is to keep that true while giving it something to send.

---

## Where things stand

**S1–S11 are ALL CLOSED.** The chain runs: schemas → ownership (`OwnerRef`) → registries +
`ParameterBinding` resolver → preset compiler + `[CFG] effective_config_hash` → Operator/Research
surface (S7) → Thin Wrapper + the 7-point parity harness (S8) → the recoverable, idempotent
scheduler (S9) → Candidate identity + append-only attestation + magic allocator (S10) →
**the Control Center shell and the `SafeProjection` DTO in shadow mode (S11, `ORDER-1131` DONE)**.

S11 hands you four things S12 consumes directly:

| what | where | why S12 cares |
|---|---|---|
| the DTO | `_triage/factory_os/safe_projection.py` → `build(snapshot)` | this is the **only** document that may reach Telegram. Do not build a second one |
| the sender boundary | `safe_projection.read_for_sender(path, repo_root)` | already refuses every path but `build/safe_projection.json`, refuses a non-`SafeProjection` entity, checks the **shape** against `schemas.json`, then re-scans. **Call it. Do not open the file yourself** |
| the page model | `_triage/factory_os/control_center.py` → `project(read, rows, findings, source)` | the Morning Brief is a *rendering* of this, not a second computation |
| the finding lifecycle | `control_center.fold_finding` | S12's dedupe key and the "no recovery from an intermediate healthy check" rule live here already — extend it, do not restate it |

**Read the three audit rounds before building on any of it** — all six defects were one shape, and
four of them lived in code no case had ever executed:
- `c2576b97` round 1 — an account only ONE detector knew about was **invisible on both surfaces**,
  so `ALL CLEAR` could render over a blind sensor with open lots; and `OK`-with-no-document
  **invented a headline**.
- `6ff84dca` round 2 — the roll-up that refuses untested rules **could not fail**, and was hiding
  three rules no case reached.
- `c9920c18` round 3 — the shape checker **silently accepted every construct it did not
  implement**; and `control_center.main` — in `PUBLIC_API`, checked by name, called by nothing —
  held two defects.

## What S12 is (design §10 row, verbatim obligations)

**Acceptance cage:**
1. **Alerts work with OpenClaw stopped.** OpenClaw is out of the alert path entirely (design §7.3:
   hibernate/upgrade/gateway restarts make it too uncertain to carry alerts). Drive this — a test
   that never had OpenClaw running proves nothing about removing it.
2. **The dedupe key includes severity AND material revision**, not `finding_id` + `state` alone.
   Rev 1 deduped on the pair, which **swallows an escalation**: `WARN` → `REAL_MONEY` while the
   state stays `OPEN` would have been suppressed as a duplicate. `SystemFinding` in `schemas.json`
   already carries `severity` and `material_revision` as REQUIRED for exactly this reason.
3. **A per-channel delivery ledger** — `(event, channel, receipt)`. Without it, dedupe is a claim
   about *sending*, not about *arriving*, and a replay after an outage re-alerts what already
   landed.
4. **One recovery message** when genuinely healthy, and **escalation is never swallowed**.

**Prohibitions (design §10):** no token in git / logs / generated HTML / chat · OpenClaw not in the
path.

**Assigned to Codex/Sonnet in the design's own table.** Decide deliberately. The honest note from
S11, where the same line applied: the cost ladder says try the cheaper tier first *where a
verification cage exists* — on S11 the cage **was** the work, so it stayed with the seat. Here a
cage partly exists (`fold_finding` and the `SafeProjection` suite), so the calculus may differ.

## Three things to verify before you act on the design

- **`OPEN → HEALTHY_1_OF_2 → OPEN` must emit no recovery.** `control_center.fold_finding` already
  computes `recovery_emitted` and case `S05` drives it. Reuse that function; a second copy of this
  rule in the sender is how the two drift.
- **The `SafeProjection` carries `findings` with `public_id`/`severity`/`state` and nothing else.**
  There is no `material_revision` on that surface today. **The dedupe key therefore cannot be
  computed from the projection alone** — decide deliberately where it is computed (local side,
  before sending) and prove the internal ids never travel. This is a real gap, named here rather
  than discovered at the sender.
- 🔴 **`dd_pct_band` reads `UNKNOWN` for every account, and that is correct.** No detector in
  `control_room_snapshot.json` publishes a drawdown band. **S12 must not compute one from
  `equity`/`balance`** — design §7.1: "the dashboard creates no competing threshold". If the
  Morning Brief needs a DD number, the answer is a new detector, in its own order, not a
  calculation in a notifier.

## ⚠️ Owed to the owner — ask before it shapes the work

**Which channel gets what?** design §7.3 names two bots on one event system: the existing **Trade
emergency bot** (real-money / DD / critical only) and a new **`EA LAB Control Room` bot** (Morning
Brief, decisions/blockers, monitor health, Idea intake). The **routing table between severity and
channel is a policy choice the owner has not made**, and it decides what wakes them at 3am. Bring
it as a costed table, not as a question.

Also: **the bot token has to come from somewhere.** It may not enter git, logs, generated HTML or
chat. Propose the mechanism (environment variable read at send time · a file outside the repo ·
the existing emergency bot's arrangement, whatever that is — **go and look**) and let the owner
pick. Do not invent a location and start using it.

## Before you start — verify, do not assume

- **Re-derive your order block from BOTH tests**: parse `## ORDER-<n>` out of all four board files
  **and** check every lane's reserved block in `docs/SESSION_LEDGER.md` — **a reserved-but-unused
  block is invisible to the number test, and this exact trap fired on 2026-08-02**: the S11 prompt
  named `1130-1139` as free and it had been taken minutes earlier, together with the order number
  for S11 itself. **Commit the reservation before using a number.** As of this writing the highest
  order in use is **1132** and the highest reserved block is **1150-1159**.
- **Check whether your order already exists.** S11's did. If a parallel lane has opened the S12
  row, execute that number rather than opening a second.
- **Baseline green first:** `run_s11_tests.py` · `run_s10_tests.py` · `run_scheduler_tests.py` ·
  `run_parity_tests.py` · `run_wrapper_gen_tests.py` · `run_guard_shape_lint.py` ·
  `run_schema_fixtures.py` · `check_param_surface.py --worktree` · `check_wrapper_gen.py
  --worktree` · `check_schema_structure.py`. The full-tier numbers are in the
  `S-2026-08-02-SCRUT11S` ledger row; if the tier is not green, someone moved the tree.
- **Delete `_triage/factory_os/__pycache__`** before the first generator run.
- `git log --oneline -15`.

## ⚠️ The tier budget, and the constraint on your cage

Full tier budget **120.0s**, and the three expensive suites (`run_contract_binding_tests` ·
`run_front_guard_evidence_tests` · `run_guard_trigger_tests`) are still ~65% of it. Speeding or
displacing them is **`ORDER-1130`**, not yours. Your suite has to fit in what is left — the
S11 suite does its whole job in **1.6s**, and the shape that bought that is:

👉 **make the cage cheaper to DRIVE, not cheaper to CARE.** Everything in fixtures, in one process;
one subprocess per claim the fixtures genuinely cannot make. For S12 those claims are: *the sender
really refuses the snapshot* and *a message really is not sent twice*.

## Build guidance these three rounds paid for

- 🔴 **The unhandled case must not render as the satisfied one.** All six S11 defects were this. For
  S12: an undeliverable message, an unreachable Telegram API, a finding whose severity is not in
  your routing table — each must be a **stated failure**, never a silent no-send. A sender that
  cannot send and reports nothing is indistinguishable from a quiet fleet.
- 🔴 **Drive the entry point a human actually runs.** Four of six defects lived in code no case
  executed, two of them in a CLI that was in `PUBLIC_API` and called by nothing. Whatever S12's
  entry point is, a case must run it end to end.
- 🔴 **A completeness roll-up must read its counter BEFORE any fixture tops it up**, and *coverage*
  and *reachability* are two roll-ups because they are two claims (memory
  `completeness-rollup-measured-after-topup`).
- 🔴 **A guard with zero fires is `UNTESTED`** (CLAUDE.md's bar table). Two `SafeProjection` scan
  rules had never fired and were caught by exactly this rule.
- 🔴 **Do not restate a number in prose. Name the module that prints it.**
- 🔴 **A prohibition can disarm the check that enforces it.** S11's sender cannot see the snapshot,
  which is correct — and that emptied the scan layer that catches raw account numbers. When you
  take an input away from one side, **ask which of that side's checks were reading it** (memory
  `prohibition-disarms-its-own-check`).
- **PowerShell traps already paid for:** `[AllowNull()][string]` **coerces `$null` to `''`** ·
  `$case` IS `$Case` · `Set-Content -Encoding UTF8` writes a BOM that `json.loads` refuses (read
  `utf-8-sig`) · `Start-Process -ArgumentList` **quotes nothing** · `[Console]::Out.WriteLine`
  bypasses **every** PowerShell stream · redirecting a native command's stderr with `2>&1` inside
  PowerShell wraps each line in an ErrorRecord and can make a verdict depend on the caller's
  `$ErrorActionPreference`.

## Do NOT do in this session

- 🚫 Put a token in git, a log, generated HTML, a handoff, or chat.
- 🚫 Put OpenClaw anywhere in the alert path.
- 🚫 Let anything but `safe_projection.read_for_sender` open a document for the sender · build a
  second projection · write a second snapshot reader.
- 🚫 Compute a drawdown band, a DD percentage or any risk threshold in the notifier.
- 🚫 Send a real message to a real chat without the owner's explicit go-ahead in this session.
- 🚫 Write anything from the UI — S11's prohibition still stands.
- 🚫 Edit any committed `factory/runs/*.jsonl` · issue a `CandidateManifest` for a real EA · append
  an attestation event to a real deployment · allocate, renumber or retire a magic.
- 🚫 Touch the S2a bundle · `MASTER_BACKLOG.md` §2 · `s2a_attestations.jsonl` · `AGENTS.md`.
- 🚫 Any EA verdict, any `.set` migration.

## Definition of done

Alerts deliver with OpenClaw stopped, **observed**, with a per-channel delivery ledger that answers
"did this arrive" · the dedupe key carries severity and material revision and an **escalation is
driven through it and survives** · exactly one recovery message on a genuine recovery and none on
an intermediate healthy check · every new cage RED-first and registered in the fast tier (measure
it **three times** — memory `phantom-regression-from-two-single-samples`) · ledger `CLOSED`,
`check_state.ps1` CLEAN, handoff in `_triage/`. **Or an honest partial with the numbers measured
and the exact next step.**

Open with: **"อ่านไฟล์นี้ แล้วเริ่ม S12 — Telegram Control Room + Morning Brief"**
