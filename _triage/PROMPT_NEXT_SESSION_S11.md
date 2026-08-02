# OPENING PROMPT — slice **S11**: Control Center shell + TODAY/WORK/LIVE/SYSTEM in **shadow mode**

> Written 2026-08-02 by lane `S-2026-08-02-SCRUT10S`, after four `/scrutinize` rounds over the
> completed S10. **This session needs no MT5 lane either** — S11 is a read-only projection and a
> shell. Its hardest acceptance is a *negative*: the Telegram sender must not be able to read the
> full snapshot. If you find yourself reaching for the tester, stop and re-read the acceptance.

---

## Where things stand

**S1–S10 are ALL CLOSED.** The chain runs: schemas → ownership (`OwnerRef`) → registries +
`ParameterBinding` resolver → preset compiler + `[CFG] effective_config_hash` → Operator/Research
surface (S7) → Thin Wrapper + the 7-point parity harness (S8) → the recoverable, idempotent
scheduler (S9) → **Candidate identity, the append-only attestation log and the magic allocator
(S10, `ORDER-1100` DONE)**.

S10 gives you four things S11 consumes directly:

| what | where | why S11 cares |
|---|---|---|
| candidate identity | `candidate.py` — digest recomputed **on every read**, one reader, and it raises | CANDIDATE BENCH renders immutable candidates; it must not invent a second reader |
| the attestation history | `attestation.py` + `factory/attestations.jsonl` | DEPLOYMENTS renders attestation state; the UI **may not write** one (design §10: no dispatch, claim or closure from the UI) |
| the magic allocations | `factory/magic_allocations.jsonl` | ADMIN / UNIVERSE / PROFILE renders them |
| a masked-projection precedent | `SafeProjection` in `CONTRACTS.md` — `***123`, DD as a **band**, `FP-` public ids | S11's `SafeProjection` acceptance is exactly this contract, made real |

**Read the four audit rounds before building on any of it** — three of the six defects were the
same shape, and two of those were in code written to close that shape:
- `1dea1201` round 1 — **criterion 3 had failed OPEN on the real store.** `find_cached` answered an
  unreadable stored key with `continue`, under a comment arguing it was *"safe in the blocking
  direction"* — backwards for a gate whose job is to block.
- `7f6e695e` round 2 — the **first** candidate assignment needed no authorization while *moving*
  one did; and a `FROZEN` event did nothing at all.
- `1f245d2b` round 3 — `C9`'s `if f in key` turned "I cannot check this pin" into "checked, fine".
- `cb711d09` round 4 — `gen_magic_allocations.py` was a declared trigger nothing ran, and the
  number it prints was restated in four documents instead.

## What S11 is (design §10 row, verbatim obligations)

**Acceptance cage (both):**
1. **All 30 handoff acceptance scenarios** (design §7.1's `TODAY` ordering and the §12 handoff
   list). The order **is** the product — ① snapshot health ② `ควรเริ่มตอนนี้` ③ `ต้องการคุณ`
   ④ `ติดขัด` ⑤ `รอ Review` ⑥ `พร้อมทำ` ⑦ `กำลังรอ` ⑧ `เพิ่งเสร็จ` — and every row must render
   **why it is where it is**.
2. **`SafeProjection` DTO**: a **recursive** forbidden-key scan plus **synthetic secret/account
   fixtures**. Not a top-level key check — the point is that a nested object cannot smuggle an
   account number out.

**Prohibitions (design §10):** no dispatch, claim or closure from the UI · Telegram must not be
able to read the full snapshot.

**Assigned to Codex/Sonnet in the design's own table** — this is the first slice where that is
true. Decide deliberately whether to delegate; the cost ladder says try the cheaper tier first
where a verification cage exists, and here one does (the 30 scenarios are mechanical).

## Two things to verify before you act on the design

- **`ControlRoomSnapshotV5` and `snapshot_validator.py` already exist** and are labelled `BUILT`
  (not `WIRED`) in `schemas.json`. S11 is a *shell over* that, not a new snapshot. Check what
  `scripts/control_room_snapshot.ps1` already produces before designing a second producer.
- **The `SafeProjection` acceptance is a NEGATIVE**, and a negative needs a fixture that would
  fail. A scan that finds nothing on a clean snapshot proves nothing — build the synthetic
  secret/account fixtures FIRST and watch the scan catch them, or the check is `UNTESTED` by the
  bar table's own rule.

## ⚠️ Owed to the owner — ask before it shapes the work

**What should a `FROZEN` attestation event forbid?** Today: nothing, deliberately. Round 2 found
that `fold` computed a `frozen` flag nothing read, so a `CANDIDATE_REASSIGNED` straight after a
`FROZEN` was allowed. The flag was **removed rather than enforced**, because the obvious rule —
refuse every later candidate change — has no way back out (there is no unfreeze event type), and
inventing one is policy. Three options, costed, in
`_triage/HANDOFF_2026-08-02_SCRUT10S.md` §"One question". **S11's DEPLOYMENTS page renders
attestation state, so it inherits whatever this becomes.**

## Before you start — verify, do not assume

- **Re-derive your order block from BOTH tests**: parse `## ORDER-<n>` out of all four board files
  (highest in use = **1100**) **and** check every ACTIVE lane's reserved block in
  `docs/SESSION_LEDGER.md` — a reserved-but-unused block is invisible to the number test. As of
  this writing the next free block is **1130-1139** (`1120-1129` = `SCRUT10S`). **Commit the
  reservation before using a number.**
- **Baseline green first:** `run_scheduler_tests.py` · `run_s10_tests.py` · `run_parity_tests.py` ·
  `run_wrapper_gen_tests.py` · `run_guard_shape_lint.py` · `run_schema_fixtures.py` ·
  `check_param_surface.py --worktree` · `check_wrapper_gen.py --worktree` ·
  `check_schema_structure.py` — all CLEAN at `cb711d09`; full tier 24 suites, 0 failed, **106.9s of
  the 120.0s budget**. If any is not, someone moved the tree.
- **Delete `_triage/factory_os/__pycache__`** before the first generator run (the S7/S8 `.pyc`
  lesson: stale bytecode once baked a decision nobody made into the canonical store).
- `git log --oneline -15`.

## ⚠️ The tier has ~13s of headroom, and that is the constraint on your cage

`ORDER-1100` raised the budgets **deliberately, with the measurement**: per-path 65.0 → **90.0**,
full tier 90.0 → **120.0**. It made the bound true, not the tier fast. **Three suites are 65% of
the full run** (`run_contract_binding_tests` · `run_front_guard_evidence_tests` ·
`run_guard_trigger_tests`) and speeding or displacing them is still owed.

**The S10 lesson that generalises, and you will need it:** the first S10 cage spawned a whole guard
per driven case — 13.1s, against 0.3s of headroom. The fix was **not** to drop cases: the rule moved
into a callable (`scripts/lib/magic_guard.ps1`) so the cage drives it **in process**, with exactly
**one** end-to-end run kept for the claim the in-process cases cannot make (that the guard actually
calls it and routes the answer somewhere that can turn red). Cost fell to 3.9s **and the trimming
found a defect**, because the cheap missing-input case finally became affordable to keep.
👉 **When your cage is too slow, make it cheaper to DRIVE, not cheaper to CARE.**

## Build guidance these four rounds paid for

- 🔴 **An unreadable input must REFUSE, never skip.** Three of six findings were this, and two were
  in code written to close it. For S11: a snapshot the shell cannot parse must render `UNKNOWN` and
  say so — it must never render as `ALL CLEAR`, which is design §7.1's very first row.
- 🔴 **A comment that argues a skip is safe deserves more suspicion than one that says nothing.**
- 🔴 **A migration is a closed declaration, not a rule.** `LEGACY_DROPPED_KEY_FIELDS = ('ini_hash',)`
  is safe because it is a tuple tied to a recorded decision; "drop what you do not recognise" would
  let every future drift launder itself.
- 🔴 **Do not restate a number in prose. Name the module that prints it.** This recurred for the
  third recorded time, inside the session that wrote the rule into its own handoff.
- 🔴 **A declared trigger with no reader is a cage that fires with no question to ask.** If S11
  declares an input in `$SUITE_GUARDS`, something in the suite must actually consume it.
- **A guard with zero fires is UNTESTED** (CLAUDE.md's bar table) — drive it until it fires, with
  its control beside it.
- **PowerShell traps already paid for** (do not pay twice): `[AllowNull()][string]` **coerces
  `$null` to `''`**, so a "cannot read this" branch becomes dead code · `$case` IS `$Case` ·
  `Set-Content -Encoding UTF8` writes a BOM that `json.loads` refuses (read `utf-8-sig`) · MT5 logs
  are UTF-16LE · `Start-Process -ArgumentList` **quotes nothing** · `[Console]::Out.WriteLine`
  bypasses **every** PowerShell stream.

## Do NOT do in this session

- 🚫 Write anything from the UI — no dispatch, no claim, no closure. S11 is **shadow mode**.
- 🚫 Let the Telegram path read the full snapshot. That is S12's surface and S11's prohibition.
- 🚫 Invent a second snapshot producer, a second canonical serializer, or a second reader for
  `CandidateManifest`.
- 🚫 Edit any committed `factory/runs/*.jsonl` · issue a `CandidateManifest` for a real EA · append
  an attestation event to a real deployment · allocate, renumber or retire a magic.
- 🚫 Touch the S2a bundle · `MASTER_BACKLOG.md` §2 · `s2a_attestations.jsonl` · `AGENTS.md`.
- 🚫 Any EA verdict, any `.set` migration, any second Boss conversion.
- 🚫 Start S12 (Telegram + Morning Brief).

## Definition of done

The Control Center shell renders `TODAY`/`WORK`/`LIVE`/`SYSTEM` in shadow mode with **all 30
handoff acceptance scenarios driven** · the `SafeProjection` DTO with a **recursive** forbidden-key
scan **observed catching** synthetic secret and account fixtures · every new cage RED-first and
registered in the fast tier (measure it **three times** first — memory
`phantom-regression-from-two-single-samples`) · ledger `CLOSED`, `check_state.ps1` CLEAN, handoff in
`_triage/`. **Or an honest partial with the numbers measured and the exact next step.**

Open with: **"อ่านไฟล์นี้ แล้วเริ่ม S11 — Control Center shell + SafeProjection ใน shadow mode"**
