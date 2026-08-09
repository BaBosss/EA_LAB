# OPENING PROMPT — the factory/EA-template session (paste this whole file as the first message)

> Written 2026-08-01 by `S-2026-08-01-JUDGEFIX` (`ORDER-940`) at the user's request:
> *"ขอ prompt เปิด session ใหม่สำหรับทำ infra โรงงาน ผมอยากทำให้มันเสร็จๆไป จะได้ปรับปรุง EA template ทีเดียว"*
>
> **Why these five orders are ONE session and not five.** Every one of them ends in the same place —
> an edited `ea_template/core/*` file, a headless compile, `tpl_regression.ps1` on a pinned MT5 lane,
> and a `_vps_deploy` bundle. That cage costs ~10 minutes per round and is the reason to batch: five
> sessions pay it five times, and a template edited by two lanes at once is the collision
> `docs/SESSION_LEDGER.md` rule 4 exists to stop. **Hold ONE MT5 lane for the whole session.**

---

## Read first, in this order

1. `PROJECT_STATE.md` — §0.5 anti-drift, §3 decision log, §7 forward plan
2. `CLAUDE.md` — the VERDICT GATE (you will not issue an EA verdict here, but the guard clause applies:
   **a guard reported without a fire count is `UNTESTED` and must not be written up as passed**)
3. `docs/SESSION_LEDGER.md` — reserve a lane and commit that row BEFORE touching anything
4. `AGENTS.md` §1.5 + §5 — the tier ladder; this session is seat-only work, do not delegate money logic
5. This file's five orders, on `AGENT_TASKBOARD.md`

## Reserve like this

- One lane, one order block of 10 (parse `## ORDER-<n>` headers out of **all four** board files
  yourself — the ledger's summary line has been repaired by hand seven times and is not evidence)
- **Declare the MT5 lane in the `เลน MT5` column and hold it all session.** `ORDER-371`: numbers
  cannot be compared across MT5 installs, so every measurement below must come from the same lane.
- `owns paths` must list `ea_template/core/**`, `scripts/_test/tpl_regression.ps1`, and the specific
  board rows. 🚫 Never `MASTER_BACKLOG.md` §2, `s2a_attestations.jsonl`, or any S2a bundle member.

---

## The work, in the order it should be done

### 1. `ORDER-510` — 🔴 do this FIRST, it is a trap the other four can spring

The live fleet is running **pre-`ORDER-132`/`138` binaries** (`Boss_14` 07-16 · `Boss_17` 07-17 ·
`Boss_12` 07-18, all older than the persist scoping that landed 07-19). Proof from two independent
directions: file dates on the VPS, and the terminal's own F3 Global Variables holding only
`Persist_LegacyKey()` names with **not one `Boss2_` key**.

**The trap:** `ea_template/core/RiskControl.mqh:142` — with the defaults (`RC_PersistHalt=true`,
`RC_AdoptLegacyHalt=false`) a NEW binary meeting a legacy key returns `INIT_FAILED`. Copy the new
`.ex5` files onto those charts and **five EAs refuse to start at once**, showing nothing but a
`[RISK] FATAL` line in the Journal. On screen that reads as *"the EA is quiet"*.

> ⚠️ **Every other order in this file produces a new binary. If the deploy procedure is not settled
> first, closing them is what triggers the outage.** Do not copy any `Boss_*.ex5` to the VPS until
> this order is closed — memory `live-fleet-runs-pre-132-binaries`.

Deliverable = a written, ordered migration procedure with the user's step named at each point
(`ea_template/PERSIST_MIGRATION_ORDER132.md` exists — verify it against the trap above rather than
assuming it covers it), plus the one-command check that says whether a given chart is safe to update.

### 2. `ORDER-432` — 🔴 money path: the three remaining defects in first-lot sizing

Findings 2 and 6 are fixed (`S-2026-07-27-MONEYPATH`). **Still open: 1, 3, and the mediums 4/5.**

- **1** Wave5 sizes from the wrong side of the spread (`core/entries/Entry_Wave5.mqh:82,:114` stores
  bid for a long / ask for a short while the entry executes on the other side)
- **3** the naked-order guard is switchable off by a legal config (`_17_UseStructLevels=false` +
  `SLMode=30` ⇒ `Lab_OpenOrder` sends `sl=0`, `core/LabCore.mqh:383`)
- **4** adaptive sizing and the deposit-load gate fail **OPEN** on an unreadable balance
  (`core/RiskControl.mqh:224` returns 0 load ⇒ `:386` permits) — split the DD-adaptive half out
- **5** a failed volume-step lookup invents `0.01`

**Rules that already cost this repo money to learn:** fix, then build the cage that proves the fix,
then close — never the other way round. And the counters added under finding 6 mean you can now
state a fire count: `NO_RISK_ATR=0` on the last run, so **that guard is `UNTESTED`** — say so, do
not write it up as passing. Do not delegate any of this to qwen or Sonnet.

### 3. `ORDER-941` — the four IchiADX legs that may not be trading at all

`990066` · `990067` · `990069` show **0 closed trades in 16 days against ~1.05/week expected**;
`990068` shows 1 against ~2.3 expected. Three legs of one EA silent together is not thinness — it is
the `990025` `AllowLive=false` shape. **This is on the same chassis you are about to rebuild**, so
it belongs in this session: if the cause is in `core/`, you are already holding the file.

The user's part is one read of the Inputs tab per chart (`_06_AllowLive`, `_06_Magic` first — a wrong
magic has **no symptom at all**). Ask for **one log export covering all four** rather than four
screenshots — memory `proving-a-set-was-loaded-on-a-chart`.

### 4. `ORDER-730` — the locked-constant half of the config fingerprint (design §5.6)

The `[CFG]` fingerprint covers every input the build exposes and **no locked constant**, which is why
the manifest still labels it `surface_only`. Closing this is what lets the label change — and the
label must not change before it is true (`ORDER-710` honoured that deliberately).

### 5. `ORDER-761` — a module should DECLARE the paths it reads

Five hand-widenings of the tier's trigger map so far, plus `ConfigFingerprint.mqh` matching no suite
at all while holding half a cross-language contract. `GUARDED_INPUTS = (...)` per module, unioned by
`PART 4b`'s existing import-closure walk. **Take this LAST** — it changes what the tier runs, so
landing it mid-session makes every earlier measurement in the session hard to compare.

---

## Cage discipline for this session (non-negotiable)

- **`tpl_regression.ps1` after every `ea_template/core/**` edit**, on the pinned lane, with the
  binaries asserted fresh first. CLEAN 8/8 or the change does not land.
- Compile must be **0 errors / 0 warnings on 9 targets** — a warning here has hidden a real defect before.
- **Never report or decide from Model 2.** Model 1 minimum; Model 4 for anything fill-sensitive.
- An MT5 headless run without `-SetFile` may carry values from the previous run — always send a
  `.set` that specifies **every** value (memory `mt5-tester-cache-nondeterminism`).
- A guard you add must come with **how many times it fired**. Zero fires = `UNTESTED`, and it goes in
  the write-up as `UNTESTED`.

## Do NOT do in this session

- 🚫 Any `--no-verify` (the last one was owner-approved and is on the record; do not add a second)
- 🚫 Touch the S2a bundle, `MASTER_BACKLOG.md` §2, or `AGENTS.md` — all cost an owner signature
- 🚫 Copy any `Boss_*.ex5` to the VPS before `ORDER-510` is closed
- 🚫 Issue an EA verdict — this is a template/infra session; the funnel work belongs to a lane that
  holds the funnel's paths
- 🚫 Re-run `ORDER-830`'s tier measurements (~50 min); they are parked for a Codex audit

## Definition of done for the session

Each order either **closed with its cage green and its numbers stated**, or handed on with the exact
next step and what was measured. Then: ledger row `CLOSED`, `scripts/check_state.ps1` CLEAN, working
tree clean of this session's work, and a handoff written in `_triage/`.

Open with: **"อ่านไฟล์นี้แล้วเริ่มจาก ORDER-510"**
