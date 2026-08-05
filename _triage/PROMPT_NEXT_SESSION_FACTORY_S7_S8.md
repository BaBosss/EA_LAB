# OPENING PROMPT — Factory OS slices S7 → S8 (paste this whole file as the first message)

> Written 2026-08-01 by `S-2026-08-01-FACTORYPROMPT` at the owner's request. **This is the Factory OS
> session, not the template/money-path one** — that is `_triage/PROMPT_NEXT_SESSION_TEMPLATE_FACTORY.md`
> and it was already run by lane `S-2026-08-01-TEMPLATE`.
>
> **Why S7 → S8 and not "finish S1-S15".** Measured 2026-08-01 against the boards and
> `_triage/factory_os/`: **S1-S4 done · S5 ~90% · S6 ~90% · S7-S10 0% · S11/S12 ~15% (CR-track
> precursors only) · S13 0% · S14 ~50% · S15 0%** ≈ **44% by slice count, and lower by effort** because
> the three heaviest (S8 wrapper+parity, S9 scheduler, S13 pilot) are untouched.
> **S8 is where the owner's actual goal lands** — *"อยากปรับปรุง EA template ทีเดียว"*. The Thin Wrapper
> generator is what makes one template edit reach all eight Boss builds; today they are edited by hand,
> one at a time. S7 is its precondition. Everything after S8 can be re-planned once S8 exists.

---

## Two decisions the owner ratified on 2026-08-01 — do not re-open them

They are recorded in `PROJECT_STATE.md` §3 (binding) and `_triage/EA_LAB_FACTORY_OS_DESIGN.md` §11.
Restated here because this session is the first one they bind:

1. **Inputs.mqh token-guard rollout = PER-BOSS, starting with Boss_14.** One build at a time; the next
   Boss is its own step, not a continuation of the same commit. **Two conventions coexisting is EXPECTED,
   not drift** — if you write a guard that reports "partially rolled out" as a failure, the cheapest way
   to satisfy it is to roll back, which is the opposite of what was decided. A build counts as converted
   only when `tpl_regression` is CLEAN **on the lane that compiled it**.
2. **Old `.set` policy = FAIL-LOUD + a separate migration tool.** Unknown/removed key ⇒ a refusal **that
   names the key**; never a skipped line, never a default substituted underneath. The migration tool
   writes a NEW file, never in place, and reports every key changed/dropped/unmappable. **The 2,177
   tracked `.set` are not bulk-migrated** — they fail loudly when used and migrate on demand.

---

## Read first, in this order

1. `PROJECT_STATE.md` — §0.5 anti-drift · §3 decision log (**the two rows dated 2026-08-01 above**)
2. `_triage/EA_LAB_FACTORY_OS_DESIGN.md` — **§5.3, §5.4, §5.5, §5.6** are this session's specification.
   §5.5 is the load-bearing one and is quoted in full below because getting it wrong is the failure mode.
3. `AGENTS.md` §1.5 + §5 — tier ladder. **Generator and parity code is seat work**; batch runs go to
   qwen/ZCode (design decision 77).
4. `docs/SESSION_LEDGER.md` — reserve a lane and commit that row as your first commit.

## Before you start — verify, do not assume

- **Check whether `ORDER-730` (S6, locked constants) actually landed.** Lane `S-2026-08-01-TEMPLATE` had
  it queued. If it is still open, **close it first** — S7's registry has to describe locked constants
  that the fingerprint already covers, or the two will disagree on what "locked" means.
- **Check `ORDER-630`'s `AWAITING OWNER on the universe store`** (S5). If that is still owed, find out
  whether S7 can proceed without it rather than discovering mid-slice that it cannot.
- Re-derive your order block by parsing `## ORDER-<n>` out of **all four** board files. The ledger's
  summary line has been hand-repaired seven times and is not evidence.
- **Hold ONE MT5 lane and declare it.** `ORDER-371`: numbers do not transfer across MT5 installs, and
  §5.5's own known trap is `tpl_regression` compiling into one lane and measuring another.
- The regression cage is **`scripts/tpl_regression.ps1`** — the earlier prompt file named
  `scripts/_test/tpl_regression.ps1`, which does not exist. Corrected here.

---

## S7 — Parameter registry extension + Operator/Research surface, **Boss_14 only**

**Acceptance (from the slice table, unchanged):** `param_registry_check` CLEAN · **zero `UNKNOWN` on
Boss_14's Operator surface** · an old `.set` either migrates or **fails loudly**.
**Prohibitions:** no key renames · no strategy/logic change of any kind.

**The state table this must satisfy (design §5.4)** — three places must tell one story, or the optimizer
is being told two:

| State | In the wrapper | In the registry | `optimize_guard` |
|---|---|---|---|
| active tunable | `input` | `role=TUNABLE`, `surface=OPERATOR` | ALLOW |
| precedence member | `input` | `role=TUNABLE` + `precedence_owner` | ALLOW unless superseded **in this run** |
| locked by hypothesis | `const` (not an input) | `role=LOCKED` | REFUSE — not sweepable, not even present |
| safety | `sinput` | `role=SAFETY` | REFUSE always |
| inert on this build | absent | `role=INACTIVE` | REFUSE |

🔴 **The precedence row is a repaired P0, not a detail.** `classification=OVERRIDE` means *member of a
precedence chain*, **not** *dead* — reading it as dead refused three working dials on 2026-07-30 and the
only way past was a flag that also disabled the checks that had evidence. Whether a member is dead is
decided **per run from the sibling values**, and the generator and the guard must read the **same table**.

**Do this in S7 as well, because decision 2 above lands here:** the `.set` reader's unknown-key path must
refuse and name the key. Write the RED case first — an old Boss_14 `.set` with a removed key must fail
with that key in the message, and a valid one must still load. A refusal you have not seen fire is
`UNTESTED` (CLAUDE.md VERDICT GATE guard clause), and this one is easy to see fire.

---

## S8 — Thin Wrapper generator + the 7-point parity harness

**Acceptance:** all parity cases including **must-trade** and **deliberate-refusal** · the wrapper
contains **zero logic** · regenerating produces a **byte-identical** `.mq5`.
**Prohibitions:** no wrapper edited by hand · no generation step that cannot be re-run.

### The parity contract (design §5.5) — all seven, or it is not parity

A Thin Wrapper is valid **iff**, on one lane, one data fingerprint, one window and one model, the wrapper
and the **parent Boss configured with the wrapper's effective config** agree on **all seven**:

1. **init result** — both attach, or both refuse **for the same reason** (`OnInit` return + reason code)
2. **`[CFG]` effective-config fingerprint** — identical `effective_config_hash`, **including locked constants**
3. **the full order-request/result trace** — every request and retcode, **including rejected attempts**, not just fills
4. **trade list** — count, entry/exit times, volumes, prices
5. **pending orders and open positions at end of run**
6. **terminal-side effects** — GlobalVariables written, persistence keys, files touched
7. **errors and safety alerts raised**

🔴 **Why not trade-list identity alone** — the audit's counter-example is the one that matters: a wrapper
and its parent can both open **zero** trades, so the lists match and parity "passes", while the wrapper
actually failed `OnInit` on a wrong generated `const`, or wrote a different persistence key. **An empty
list is the easiest way to match.** Hence the two mandatory directions:
- a **must-trade case** — a config that provably opens trades, so an empty run cannot pass;
- a **deliberate-refusal case** — a config that must fail the attach (e.g. `_42_RiskPct` mis-paired with
  an `SLMode` yielding no distance, which `MM-SAFETY-001` refuses at `OnInit`) — proving parity
  distinguishes *refused* from *silent*.

**Also binding:** trade-list identity, **not** summary identity — PF/net/DD matching while trade lists
differ is two strategies agreeing on one window (memory `inert-axis-fake-plateau`) · parity runs **before**
any evidence from that wrapper counts, and evidence from an unparified wrapper is **void** · parity is
per revision and re-runs whenever `core/` changes — **the same trigger as `tpl_regression`, so share the
lane pin and the runner** · and parity must assert **the binary it measured is the binary it built**.

---

## Cage discipline (non-negotiable)

- `tpl_regression.ps1` CLEAN **8/8** after every `ea_template/**` edit, on the pinned lane, binaries
  asserted fresh **before** measuring.
- Compile **0 errors / 0 warnings across 9 targets**.
- Every new guard reports **how many times it fired**. Zero fires ⇒ write `UNTESTED`, not "passed".
- Every new checker gets a cage that is **RED first** — and `run_guard_shape_lint.py`'s `L0` will demand
  the checker be registered; that is the guard working, not an obstacle.
- Never decide from **Model 2**. Model 1 minimum; Model 4 where fills matter.
- Always pass a **full-surface `.set`** to a headless run (memory `mt5-tester-cache-nondeterminism`).

## Do NOT do in this session

- 🚫 Convert a second Boss. **Boss_14 only** — that is the ratified rollout shape.
- 🚫 Bulk-migrate `.set` files. On demand only.
- 🚫 Rename a key, or change any strategy logic, under cover of a registry refactor.
- 🚫 Touch the S2a bundle · `MASTER_BACKLOG.md` §2 · `s2a_attestations.jsonl` · `AGENTS.md` — every byte
  costs an owner signature.
- 🚫 Any `--no-verify`.
- 🚫 Start S9-S15. When S8 is green, **stop and re-plan** — S8 changes what the remaining slices cost.
- 🚫 Issue an EA verdict. This session produces machinery, not evidence about strategies.

## Definition of done

**S7 closed** (`param_registry_check` CLEAN · zero `UNKNOWN` on Boss_14's Operator surface · the
unknown-key refusal observed firing) **and S8 closed** (7/7 parity on both the must-trade and the
deliberate-refusal case · wrapper regenerates byte-identical · `tpl_regression` CLEAN 8/8) — or an honest
partial with the numbers measured and the exact next step. Then: ledger `CLOSED`,
`scripts/check_state.ps1` CLEAN, handoff in `_triage/`.

Open with: **"อ่านไฟล์นี้ แล้วเช็คก่อนว่า ORDER-730 ปิดหรือยัง จากนั้นเริ่ม S7"**
