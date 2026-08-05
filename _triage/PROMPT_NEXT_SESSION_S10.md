# OPENING PROMPT — slice **S10**: Candidate identity + append-only Deployment attestation + magic reservation

> Written 2026-08-02 by lane `S-2026-08-02-SCRUT9S`, after four `/scrutinize` rounds over the
> completed S9. **This session needs no MT5 lane at all** — S10 is identity, attestation and
> allocation: digests recomputed on read, an append-only event log, and an exception list a guard
> reads. Every acceptance is provable in pure python against fixtures. If you find yourself
> reaching for the tester, stop and re-read the acceptance.

---

## Where things stand

**S1–S9 are ALL CLOSED.** The chain runs: schemas → ownership (`OwnerRef`) → registries +
`ParameterBinding` resolver → preset compiler + `[CFG] effective_config_hash` → Operator/Research
surface (S7) → Thin Wrapper + the 7-point parity harness (S8) → **the recoverable, idempotent
scheduler (S9, `ORDER-1080` DONE)**.

S9 gives you three things S10 consumes directly:

| what | where | why S10 cares |
|---|---|---|
| a run's identity | `ExecutionKey` + `scheduler.execution_key_digest()` | a Candidate **pins the run it came from** (decision 42) |
| the run store | `factory/runs/<run_id>.jsonl`, append-only, folded by `scheduler.fold()` | evidence → run → module set is resolved through it |
| **a canonical serializer that already works** | `scheduler.canonical()` + the numeric normalization inside `execution_key_digest()` | **design §4.5 says `candidate_digest`'s canonical form is still owed. Do not invent a second one.** |

**Read the four audit rounds before building on any of it** — the S9 write-up as first published
described code that no longer exists:
- `4f1900b2` round 1 — a comment said "THE MARKER IS WRITTEN FIRST" above a marker written *after*
  the spawn; and a roll-up measured *reached* while printing *killed*, which hid a transition that
  had never been killed at all.
- `d63ad2cf` round 2 — the lane lease was enforced at acquisition and **decorative for the whole
  run**; `queue` validated against `None`; and `10000` vs `10000.0` gave **two digests for one
  configuration**. That last one is S10's problem too, which is why the serializer is in the table.
- `81dead9e` round 3 — the manifest recorded an evidence id hashed from a **different file** than
  the one registered.
- `9ff7138d` round 4 — two runs could be handed one report name and delete each other's evidence;
  and every number in the prose was stale, one of them wrong when written.

## What S10 is (design §10 row, verbatim obligations)

**Acceptance cage (all four):**
1. **`candidate_digest` is recomputed and compared on every read.** The payload does **not** contain
   the id (design §4.5, rev 1's mistake: `id = hash(object containing id)` has no construction, so
   the check gets disabled). Reuse `scheduler.canonical()` — and carry its numeric normalization,
   because round 2 proved by probe that the same value spelled two ways silently produces two
   digests.
2. **No non-`OBSERVED` attestation event without a human authorization ref.** Automation may append
   `OBSERVED` events only; anything that changes `candidate_id` or `status` needs `user|claude`.
3. **`check_state.ps1` stays green.**
4. **Legacy magic exceptions preserved.** The three real collisions — `990103` · `991001` (live
   REAL_CENT on two accounts) · `991002` — are `LEGACY_ACCOUNT_SCOPED`, frozen to their judge
   dates, **never renumbered as a side effect**.

**Prohibitions (design §10):** no auto-update of any deployment · no renumbering of a live magic.

## Two things the design's own §11 gets wrong about S10 — check before you act on it

- **The magic-scope decision is ALREADY RATIFIED.** §11 and §4.6 still say *"`PROJECT_STATE` §3's
  invariant must be amended by the user before S10 is built"*. `PROJECT_STATE.md` §0.5 (line 62,
  ratified 2026-08-01) is newer and says the decision is made: scope is **GLOBAL** for new
  allocations, and **`check_state.ps1` flips to the global rule only when S10 gives it an exception
  list to read** — because flipping first would redden three rows the owner has just declared
  legitimate. So S10's real obligation is *"produce the exception list, then flip the checker"*, not
  *"go ask again"*. Verify this against the file before you rely on my reading of it.
- **The `check_precommit_staged` duplicate-magic rule is inert** (`PROJECT_STATE.md` line 132): its
  regex is `'^d+$'` — a lost backslash — so **0 of 64 real rows ever matched**. A second guard over
  the live-money inventory has been dead since `baa1b6f5`. If S10 touches magic uniqueness, that
  guard is in scope and its blast radius was measured at 0 duplicates.

## ✅ ADDENDUM 2026-08-02 — both owner items below are now DECIDED. Read this before the section.

<sub>Added by lane `S-2026-08-02-RATIFY9` after `S10CAND` had already reserved. Full text and the
reasoning: `_triage/USER_DECISIONS_PENDING.md` items **6** and **7**.</sub>

**Item 1 → `ExecutionKey.ini_hash` MOVES to `RunAttempt`.** `ExecutionKey` becomes **14 fields**;
`RunAttempt` gains `ini_sha256`, written after the ini exists. Identity stays computable before the
run; forensics keeps the real bytes. The literal reading was not merely awkward — the ini contains
`Report=$ReportName`, which differs every run, so a real ini hash would give two runs of an
identical configuration two different digests and **criterion 3 could never fire**. Same shape
`schemas.json` already fixed by moving `pid` off the lease. **Measured: no candidate digest changes**
— `CandidatePayload.evidence` is `MetricRef`, which carries `run_id`/`lane`/`data_fingerprint` and
never the ExecutionKey.

> **This is S10's to execute, as step 0, under its own block** — `S10CAND` already declares
> `scheduler.py`, `schemas.json` and `CONTRACTS.md`, and had committed no code when this was
> decided, so it lands before anything is built on the old shape. Touches: `EXECUTION_KEY_FIELDS`
> in `scheduler.py` · the two `$defs` in `schemas.json` · regenerate `CONTRACTS.md` ·
> `run_scheduler_tests.py`'s `BASE_KEY` and its 15-field attack (it becomes a 14-field attack, and
> the "missing a field" case must still refuse). Re-run `run_scheduler_tests.py` — the
> `execution_key_digest` shape check is what will tell you the tuple and the schema agree.

**Item 2 → decision 18 reads as TWO CATEGORIES.** The mapping now in
`RETRYABLE_FOR_NEW_RUN` is **ratified as-is**: tester = `TESTER_ERROR` · execution =
`TERMINAL_ERROR`/`TIMEOUT`/`KILLED`/`LEASE_LOST` · neither = `CONFIG_REJECTED` (stays blocked).
**No code change** — only the hedge in the comment ("this is an INTERPRETATION ... the owner can
overrule") becomes a ratification, citing decision 7.

<sub>⚠️ While editing that comment block, note it currently carries a **stale sentence** from the
S9 build: the "TWO GATES, NOT ONE" paragraph still reads *"That is `RETRYABLE_FOR_NEW_RUN`, and it
is exactly the decision's two classes"*, which the tuple below it has contradicted since the wiring
proof widened it to five. A comment asserting the opposite of its own code is the exact defect
`/scrutinize` round 1 found in `scheduler_run.ps1`; fix it in the same commit.</sub>

---

## ⚠️ Owed to the owner — ask these BEFORE building, both block or shape S10 <sub>(SUPERSEDED — see the addendum above; kept because it is the reasoning the decisions answer)</sub>

1. **`ExecutionKey.ini_hash` is not knowable when the key is needed.** The ini is written *by the
   runner*, but the key is what gates whether the run may happen at all — the same shape
   `schemas.json` already fixed one level up when it removed `pid` from the lease. For S9's proof
   runs it was seeded from a canonical rendering of the same fields. **A Candidate pins the run it
   came from, so S10 inherits whatever this becomes.** Either an ExecutionKey *builder* renders the
   ini itself (moving that responsibility out of `mt5_run.ps1`), or the field is redefined.
2. **The decision-18 category mapping is an interpretation of a user-owned decision.** Decision 18
   permits a re-run *"except after an execution or tester error"*. Read as the literal pair
   (`TESTER_ERROR`, `TERMINAL_ERROR`), a machine crash made a configuration **permanently
   unrunnable** — in the slice whose whole purpose is recovery. It now reads as the two categories:
   tester = `TESTER_ERROR` · execution = `TERMINAL_ERROR`/`TIMEOUT`/`KILLED`/`LEASE_LOST` · neither
   = `CONFIG_REJECTED`. Overruling it changes one table (`RETRYABLE_FOR_NEW_RUN`).

## Before you start — verify, do not assume

- **Re-derive your order block from BOTH tests**: parse `## ORDER-<n>` out of all four board files
  (highest in use = **1080**) **and** check every ACTIVE lane's reserved block in
  `docs/SESSION_LEDGER.md` — a reserved-but-unused block is invisible to the number test. As of
  this writing the next free block is **1100-1109** (`1090-1099` = `SCRUT9S`). **Commit the
  reservation before using a number.**
- **Baseline green first:** `run_scheduler_tests.py` · `check_param_surface.py --worktree` ·
  `check_wrapper_gen.py --worktree` · `run_parity_tests.py` · `run_wrapper_gen_tests.py` ·
  `run_guard_shape_lint.py` — all CLEAN at `9ff7138d`; if any is not, someone moved the tree.
- **Delete `_triage/factory_os/__pycache__`** before the first generator run (the S7/S8 `.pyc`
  lesson: stale bytecode once baked a decision nobody made into the canonical store).
- `git log --oneline -15`.

## Build guidance these four rounds paid for — the S9 lessons that generalise

- 🔴 **A cage over a pure module proves the pure module and nothing else.** All nine `/scrutinize`
  findings lived where the 400-cell matrix structurally cannot reach: the PowerShell observation
  layer, the cage's own arithmetic, and the prose. For every acceptance, ask *which half of the
  system does my cage actually drive* — and put a cheap mechanical check (a grep, an ordering
  assertion) on the half it does not.
- 🔴 **A claim and its measurement must be the same sentence.** The roll-up recorded points
  *reached* and printed points *killed*. Correcting the measurement immediately proved one of nine
  transitions had never been killed. When you write "every X was verified", the line above it must
  be the loop that verified every X.
- 🔴 **Do not restate a number in prose.** Board row, ledger row and handoff all carried "256
  resumes" within an hour of it being wrong — and 256 was the wrong quantity anyway (cells, not
  kills). Name the module that prints the number. This is `ORDER-1021`'s "38 inputs" lesson, which
  recurred *inside the session that cited it*.
- 🔴 **Reproduce before fixing.** Every round-2 finding was probed and printed first
  (`WAIT` with a five-hours-dead lease; two `QUEUED` lines and two exit-0s; two digests for one
  deposit). A fix without a reproduction is a guess with a commit message.
- **A guard with zero fires is UNTESTED** (CLAUDE.md's bar table). Round 3's byte-identity refusal
  was driven until it actually fired, with its control — and the first attempt to fire it was
  intercepted by an upstream branch, which *was* the next finding.
- **PowerShell traps already paid for** (do not pay twice): `$case` IS `$Case` · `Set-Content
  -Encoding UTF8` writes a BOM that `json.loads` refuses (read `utf-8-sig`) · MT5 logs are UTF-16LE
  · `Start-Process -ArgumentList` **quotes nothing** · `[Console]::Out.WriteLine` bypasses **every**
  PowerShell stream, so even `2>&1 6>&1` misses it — capture it as a child process.

## Do NOT do in this session

- 🚫 Invent a second canonical serializer. `scheduler.canonical()` exists and its numeric
  normalization was earned by a probe.
- 🚫 Renumber any live magic · auto-update any deployment · flip `check_state.ps1` to the global
  rule **before** the exception list exists.
- 🚫 Touch the S2a bundle · `MASTER_BACKLOG.md` §2 · `s2a_attestations.jsonl` · `AGENTS.md`.
- 🚫 Any EA verdict, any `.set` migration, any second Boss conversion.
- 🚫 Start S11 (Control Center shell).

## Definition of done

`CandidateManifest` written and read with the digest **recomputed and compared on read** · the
attestation event log append-only with the non-`OBSERVED` authorization rule **observed refusing** ·
the magic allocator with the three legacy exceptions preserved and `check_state.ps1` flipped to the
global rule **only after** it has an exception list to read · every new cage RED-first and
registered in the fast tier (measure it **three times** first — memory
`phantom-regression-from-two-single-samples`) · ledger `CLOSED`, `check_state.ps1` CLEAN, handoff in
`_triage/`. **Or an honest partial with the numbers measured and the exact next step.**

Open with: **"อ่านไฟล์นี้ แล้วเริ่ม S10 — Candidate identity + attestation + magic reservation"**
