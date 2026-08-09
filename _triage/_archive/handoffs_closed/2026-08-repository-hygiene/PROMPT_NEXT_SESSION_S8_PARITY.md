# OPENING PROMPT — finish S8: the `Inputs.mqh` token rollout, then the 7-point parity harness

> Written 2026-08-02 by lane `S-2026-08-02-SCRUT78B`, after three `/scrutinize` rounds over the
> S7/S8 work. **This session needs the MT5 tester.** If you cannot hold an MT5 lane for a few
> hours, do not open this one — step 2 is the whole point and it does not exist without runs.

---

## Where things stand

**S7 is CLOSED.** All three acceptance criteria are met and measured: `param_registry_check` CLEAN
(it now runs the design §5.4 state table too) · **zero `UNKNOWN` on Boss_14's Operator surface** ·
an old `.set` **fails loudly**, 42 real fires on 50 template files.

**S8's generator is built, caged and compiling.** Two of its three acceptance criteria are checks
that can fail (`W1` byte-identical, `W2` zero logic); both wrappers compile **0 errors / 0
warnings** on lane 1. **The third — the 7-point parity contract — does not exist yet, and no file
implies that it does.**

| | |
|---|---|
| `B14-H01-r1` | 116 rows · **18 OPERATOR** · 13 RESEARCH · 85 HIDDEN · 31 visible |
| `B14-H02-r1` | 116 rows · **21 OPERATOR** · 13 RESEARCH · 82 HIDDEN · 34 visible |

## Read first, in this order

1. `PROJECT_STATE.md` §0.5 anti-drift · §3 decision log (**the two rows dated 2026-08-01 bind this
   session**: per-Boss token rollout, and fail-loud `.set`)
2. `_triage/HANDOFF_2026-08-02_FACTORY78B.md` — what landed and what it cost
3. `_triage/EA_LAB_FACTORY_OS_DESIGN.md` **§5.3** (allowlist) and **§5.5** (the parity contract) ·
   `_triage/factory_os/CONTRACTS.md` → `META_parity_cases` (the case list is **generated**, so the
   count IS the list)
4. `AGENT_TASKBOARD.md` row **`ORDER-1021`** — it carries the remaining work in order
5. `docs/SESSION_LEDGER.md` — reserve a lane and **commit that row first**

## Before you start — verify, do not assume

- **Re-derive your order block** by parsing `## ORDER-<n>` out of **all four** board files. The
  ledger's summary line is not evidence. 🔴 **And check the ACTIVE lanes' reserved blocks, not just
  the highest number in use** — a block reserved but not yet used is invisible to the
  number-based derivation, and that produced **two collisions on 2026-08-02 alone**.
- **Hold ONE MT5 lane and declare it.** `ORDER-371`: numbers do not transfer across installs.
  `tpl_regression` and parity must share the pin.
- **Delete `_triage/factory_os/__pycache__` before your first generator run.** Round 3 lost an hour
  to a stale `.pyc` that baked a decision nobody made into the canonical store. `P5` now detects
  it, but starting clean costs nothing.
- Run `tools/python312/python.exe _triage/factory_os/check_param_surface.py --worktree` and
  `check_wrapper_gen.py --worktree` **before touching anything**, so you know the baseline is green.

---

## STEP 1 — `Inputs.mqh` capability-token rollout, **Boss_14 only**

**This must land before parity, and the reason is not sequencing taste:** until it does, a
generated wrapper defines the tokens and `Inputs.mqh` ignores them, so it compiles to a binary
**identical** to the hand-written `Boss_14_GridLog`. Doing the rollout and the parity harness in one
step gives a parity failure **two candidate causes and no way to tell them apart**.

**What it is.** Each input in `ea_template/core/Inputs.mqh` is declared inside its capability token,
so an input outside the wrapper's set becomes a `const` at its canonical default. The token→input
map already exists and is caged: `activation.TABLE['LAB_ENTRY_14']` — **78 of 116 are unreachable
under `B14-H01`**, and those are exactly the ones that become `const`.

**Binding constraints:**
- 🔴 MQL5 has **no `#if EXPR==n` and no `#elif`** (`Inputs.mqh:11` says so, and the file already
  nests eight `#ifndef LAB_ENTRY_nn` guards to emulate a default). **Token `#ifdef` only.**
- 🔴 **PER-BOSS, Boss_14 first** (owner-ratified 2026-08-01). **Two conventions coexisting is
  EXPECTED, not drift** — a guard that reports "partially rolled out" as a failure makes rollback
  the cheapest fix, which is the opposite of the decision. A build counts as converted only when
  `tpl_regression` is CLEAN **on the lane that compiled it**.
- 🔴 A capability **selector** may not live inside the capability it selects. `LotProg` decides
  whether `LAB_CAP_LOTPROG` is on; owned by that token, turning the capability off would `const`
  away the input that decides it. `activation.py` already models this — selectors are
  `LAB_CAP_CORE`.
- ⚠️ **Adding a valued `#define` to any core header changes `LockedConstants_gen.mqh`** and
  therefore every build's `effective_config_hash`. The allowlist emits **token** defines (no value),
  which `gen_locked_constants` correctly ignores — keep it that way.

**Owed after every `ea_template/**` edit:** `scripts/tpl_regression.ps1` **CLEAN 8/8** on the pinned
lane, binaries asserted fresh first · compile **0 errors / 0 warnings on 9 targets**.

**Acceptance for step 1:** Boss_14's Inputs page shows **31** inputs (18 OPERATOR + 13 RESEARCH),
`tpl_regression` CLEAN 8/8, and the seven other Boss builds are **byte-for-byte unaffected** in
behaviour. Prove the last one — it is the whole risk of touching a shared header.

## STEP 2 — the 7-point parity harness

**A Thin Wrapper is valid iff**, on one lane / one data fingerprint / one window / one model, the
wrapper and the **parent Boss configured with the wrapper's effective config** agree on all seven:

1. **init result** — both attach, or both refuse **for the same reason** (`OnInit` return + reason)
2. **`[CFG]` fingerprint** — identical `effective_config_hash`, **including locked constants**
3. **the full order-request/result trace** — every request and retcode, **including rejections**
4. **trade list** — count, entry/exit times, volumes, prices
5. **pending orders and open positions at end of run**
6. **terminal side effects** — GlobalVariables, persistence keys, files touched
7. **errors and safety alerts raised**

🔴 **Why not trade-list identity alone:** a wrapper and its parent can both open **zero** trades, so
the lists match and parity "passes" while the wrapper failed `OnInit` on a wrong generated `const`.
**An empty list is the easiest way to match.** Hence both mandatory directions —

- a **must-trade** case: a config that provably opens trades;
- a **deliberate-refusal** case: `_42_RiskPct` paired with an `SLMode` yielding no distance, which
  `MM-SAFETY-001` refuses at `OnInit`.

**Also binding:** trade-list identity, **not** summary identity · parity runs **before** any
evidence from that wrapper counts, and evidence from an unparified wrapper is **void** · parity is
per revision and re-runs whenever `core/` changes — **the same trigger as `tpl_regression`, so
share the lane pin and the runner** · and it must assert **the binary it measured is the binary it
built**.

**Point 2 is already emittable and comparable today** (`ORDER-710` + `ORDER-730`) — start there,
it is the cheapest of the seven and it fails loudly.

## Cage discipline (non-negotiable)

- `tpl_regression.ps1` CLEAN **8/8** after every `ea_template/**` edit, on the pinned lane.
- Compile **0 errors / 0 warnings across 9 targets**. The generated wrappers are **not** in
  `deploy.ps1`'s `Boss_*.mq5` discovery — if you add them, say so and re-measure the policy.
- Every new guard reports **how many times it fired**. Zero fires ⇒ write `UNTESTED`, not "passed".
- Every new checker gets a cage that is **RED first**, and `run_guard_shape_lint`'s `L0` will demand
  it be registered — that is the guard working.
- Never decide from **Model 2**. Model 1 minimum; **Model 4 where fills matter** — and for a grid,
  they do.
- Always pass a **full-surface `.set`** to a headless run.
- ⚠️ **The full tier is at 88.9s of a 90.0s budget.** A new suite must displace something or be
  measured and argued. `ORDER-820` is open on that number.

## Do NOT do in this session

- 🚫 Convert a second Boss. **Boss_14 only.**
- 🚫 Bulk-migrate `.set` files. On demand only.
- 🚫 Rename a key, or change strategy/default behaviour, under cover of the rollout.
- 🚫 Touch the S2a bundle · `MASTER_BACKLOG.md` §2 · `s2a_attestations.jsonl` · `AGENTS.md`.
- 🚫 Any `--no-verify`.
- 🚫 Issue an EA verdict. This session produces machinery, not evidence about strategies.
- 🚫 Let a wrapper's evidence count before parity passes.

## Definition of done

**Step 1 closed** (Inputs page 31, `tpl_regression` CLEAN 8/8, the other seven builds unaffected)
**and step 2 closed** (7/7 on both the must-trade and the deliberate-refusal case, lane named in
the output) — or an honest partial with the numbers measured and the exact next step. Then: ledger
`CLOSED`, `scripts/check_state.ps1` CLEAN, handoff in `_triage/`.

<sub>A Codex audit brief for the work this builds on is at
`_triage/factory_os/CODEX_S7_S8_AUDIT_BRIEF.md`. If it has been run, **read its findings before
step 1** — several of them are about `activation.py`'s hand-encoded table, which step 1 turns into
compiled `#ifdef`s.</sub>

Open with: **"อ่านไฟล์นี้ แล้วเริ่ม STEP 1 — Inputs.mqh token rollout เฉพาะ Boss_14"**
