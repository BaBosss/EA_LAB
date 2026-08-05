> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **shift-change note for lane
> `S-2026-08-01-TEMPLATE`** — the factory/EA-template batch session opened from
> `_triage/PROMPT_NEXT_SESSION_TEMPLATE_FACTORY.md`. This is a note, not a queue — every open item
> below already has a home on `AGENT_TASKBOARD.md`.

# Session end — 2026-08-01, `S-2026-08-01-TEMPLATE`

The user asked to work through the five orders in
`_triage/PROMPT_NEXT_SESSION_TEMPLATE_FACTORY.md`, then hibernate the machine (going to sleep).
**Two of the five are closed. Three are not, for reasons stated below rather than left silent —
two need the user awake, and the last two are infra builds that deserve a session of their own
rather than being rushed at 23:00 with nobody available to review a mistake in shared guard
plumbing.**

## 1. `ORDER-510` — STEP 1 verified + one-command check DELIVERED, order stays `OPEN`

`_triage/ORDER510_ADOPT_ONCE_PROCEDURE.md` §11 records the verification: the procedure holds, and
re-reading it at the line found two things that would have misled an operator mid-upgrade (§11.1
the wrong journal line is named for a chart refused by trigger 1/2 — they're consumed into
`rc_state`, never "migrated" · §11.2 the DryRun rehearsal is silent on triggers 1/2 and parks the
EA in kill-pending with closes suppressed, which the "only while FLAT" rule covers by accident).

`scripts/check_persist_legacy.ps1` (§12) turns an F3 census into SAFE/NOT SAFE. Cage
`scripts/_test/run_persist_legacy_tests.ps1`, **30/30 green**, red-first measured against four
neutralised mechanisms (not asserted). Registered in `run_guard_shape_lint.py`'s `L1_NOT_PARSED`
(11→12) — the lint refused the first commit attempt and named the file itself.

**STEP 2 and STEP 3 need the terminals (F3 census on 4 unchecked accounts, 3 of them real money)
and the owner's approval per magic — cannot proceed without both awake.** Next session: run the
new checker against a real F3 export before touching anything, per account, starting with
`415573666` (the one DEMO account still unchecked).

## 2. `ORDER-432` — `DONE`, bookkeeping only; `ORDER-950` opened

**The opener prompt was stale.** It claimed findings 1, 3, 4, 5 were still open on this order. They
were not — the row's own body already recorded all six findings fixed on 2026-07-27, across two
sessions, with a pre-registered spread-drift test for finding 1 and a fired+specificity-checked
guard for finding 3. Re-read at today's SHA confirms nothing regressed. Memory
`grep-destination-before-tasking-user` applies to a session opener's own status claims, not only to
requests from the user — check the row, not the summary of the row.

The one real gap named in that row — guard G4 (`Wave5_SLValid` / `g_w5_n_sl_invalid`) fired **zero**
times across every run so far — is spun into its own order, **`ORDER-950`**, with three routes to
evidence ranked cheapest-first (read the tester's actual `SYMBOL_TRADE_STOPS_LEVEL` for XAUUSD and
compute the gap · try the BWD 2020-22 window · only as a last resort, a labelled synthetic
reachability probe that must never be reported as evidence about the deployed config). No code
changed this session for either order.

## 3. `ORDER-941` — blocked on the user, not started

Needs one read of the Inputs tab per chart, four charts (`990066`/`990067`/`990068`/`990069`),
`_06_AllowLive` and `_06_Magic` first. Cannot be done without the user at the terminal. **Ask for
one log export covering all four rather than four screenshots** (memory
`proving-a-set-was-loaded-on-a-chart`).

## 4. `ORDER-730` and `ORDER-761` — not started, and that is a judgment call worth stating

Both are genuine infra builds, not edits: `730` needs a DERIVED enumeration of every locked
constant in `ea_template/core/` on both the MQL5 and Python sides of the config fingerprint, with
the `surface_only` → `surface+constants` label change gated on it actually being true (`ORDER-710`
precedent — the label must not move before the substance does). `761` needs a `GUARDED_INPUTS`
declaration mechanism, checked (not trusted) against `run_guard_shape_lint.py`'s own read-parser,
unioned through `PART 4b`'s import-closure walk. Comparable prior work in this repo
(`run_guard_shape_lint.py` itself, the front-guard declarations) each took a full dedicated session
with red-first cages and at least one `/scrutinize` pass that found a real defect in the first
attempt.

**Why they were not attempted tonight:** both modify shared pre-commit-enforced infrastructure that
every future commit runs through. Rushing either at the tail end of a long session, with the user
about to be unreachable for hours, risks landing a half-verified change to the mechanism that gates
every other session's commits — exactly the "guard that refuses valid work gets switched off"
failure mode the Decision log already paid for once (2026-07-30). Recommendation: give each its own
session, in the order the opener specified (`730` before `761`, because `761` changes what the tier
runs and should land after other measurements in a batch are stable).

## Verification run this session

`scripts/check_state.ps1` — CLEAN. Every commit this session passed the full pre-commit hook
(`check_state`, `precommit-staged`, `order-collision`, `attested-pin`, `fast-cages`) with no
`--no-verify`. No `ea_template/core/**` edit was made, so `tpl_regression.ps1` was not required to
run this session (`check_persist_legacy.ps1` lives under `scripts/`, outside that path).

## What did NOT happen (stated, not implied)

No VPS touched. No `Boss_*.ex5` copied or rebuilt. No GlobalVariable read or written on any real
terminal. No live/demo chart attached. No `.set` changed. No EA verdict issued. No S2a bundle
member touched. `AGENTS.md`/`MASTER_BACKLOG.md`/`s2a_attestations.jsonl` untouched.

## Next session opener

Read this file, then `docs/SESSION_LEDGER.md`'s `S-2026-08-01-TEMPLATE` row for the full detail
behind each line above. Reserve a fresh block before touching anything (rule in
`docs/SESSION_LEDGER.md`). Recommended order: `ORDER-510` STEP 2/3 (needs the user + VPS) or
`ORDER-941` (needs the user) first if the user is present; `ORDER-730` if working solo.

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| `ORDER-510` STEP 2/3 (adopt-once per magic, needs terminals + owner) | ORDER-510 |
| guard G4 fire-count evidence (`Wave5_SLValid`) | ORDER-950 |
| four IchiADX legs silent/thin, needs user's Inputs-tab read | ORDER-941 |
| config-fingerprint locked-constant enumeration | ORDER-730 |
| module-declared `GUARDED_INPUTS` mechanism | ORDER-761 |
| `ORDER-510` STEP 1 (procedure verify + one-command check) | DONE |
| `ORDER-432` (all six findings, bookkeeping close) | DONE |
