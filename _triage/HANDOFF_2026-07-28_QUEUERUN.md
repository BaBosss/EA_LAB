# HANDOFF — 2026-07-28 `S-2026-07-28-QUEUERUN` — the ranked queue, run

> ⚠️ canonical entry = `PROJECT_STATE.md` · this file owns: **the shift note for the lane that consolidated the
> scattered handoff/board work on 2026-07-28, ranked it, and then ran the top of the ranking.** Not a queue —
> every item below has a row on the board (routing table at the end).

**Lane:** `S-2026-07-28-QUEUERUN`, block **500-509** (used **500** and **501**). Two MT5 lanes used in parallel —
`D:\Meta 5b` (Model 4) and `D:\Meta 5c` (Model 1). Two Codex blind audits dispatched. No live account touched,
no `_vps_deploy` bundle touched, nothing compiled.

---

## 1. Why this lane existed

Nine handoff files in `_triage/` and 48 rows on the board made the work look larger and more tangled than it
was. The user asked for it consolidated and ranked, then told the lane to run its own recommendation, hand the
user-only tasks to a separate session, and dispatch Codex where an audit was warranted.

**The consolidation itself was the first useful output:** of 48 board rows only about 22 were genuinely open,
and the single biggest bottleneck was not technical — it was **eight items that only the user can do**, three
of which are pure "go read a number" and unlock three separate tracks. Those went to
`_triage/USER_TASKS_2026-07-28.md` as a paste-ready brief for a separate session, deliberately **excluding**
the five items that need a decision, because mixing them is why all five keep sliding together.

---

## 2. What was measured (the EA work)

### ORDER-431 — MacdDiv_Naked USDJPY H4 · `REVIEWED` → **BUILD-ON**

First optimize this home has ever had. Ceiling **MAIN 1.18** at `_01_SwingRadius=2` → middle branch of the
pre-registered tree, so BUILD-ON stands, no arm earned a BWD run, and the cell stays open. Two levers and one
axis on one timeframe does not reach condition 2a.

**Two pre-flight traps were caught before the first run rather than diagnosed after it:**

1. The lane binary was **four hours older than its source** and did not contain `_08_UseMacdCross` — the input
   one whole arm exists to toggle. MT5 fills an unknown input from the per-terminal cache, so that arm would
   have returned identical to control and read as a clean null.
2. The source `.set` pinned **neither** gate, so BASE was not a control until both were written in explicitly.

**The finding is the number that did not move.** The RSI gate returned **exactly 250 trades against baseline's
250**, while the long/short split moved 79/171 → 66/184 and *both* gross legs shrank ~30%, turning +37.24 into
−29.96. It does not reduce participation, it **re-selects** it, tilted off the long side, and the replacements
are worse **on net**. Precisely — the first version of this sentence was wrong: gross profit fell 37% while
gross loss fell 26% in magnitude, so **losses got smaller too**; the winning side simply shrank faster.
Anyone reading the trades column alone would have filed this lever as a no-op.

> **Trade count unchanged is not evidence that a filter is inert. Check the direction split and both gross
> legs.** Catalogued as its own EDGE_CATALOG entry — the lever was built in ORDER-117 and had never been
> characterised until now.

<sub>🔧 **Reason corrected after `/scrutinize` of this lane, 2026-07-28.** The conclusion holds; the reason
first given for it did not, and this section over-sold `250 = 250` as a surprising coincidence.
`MacdDiv_Naked.mq5:110` opens with `if(HasOpenPosition()) return;` — **the EA holds one position at a time**,
so the entry rate is set by *occupancy*, not by how many signals clear the gate. A gate that **delays**
entries rather than removing them therefore lands near the same three-year total **by construction**. The
sharper and more general rule: **on a single-position EA, trade count is a weak inertness signal because it
measures occupancy, not selection.** It also cuts the other way — the MACD-cross arm falling to 28 is *more*
striking under this reading, not less, because it cut participation hard enough to break through the
occupancy floor.</sub>

The MACD-cross gate replicated ORDER-217's XAU result on a second symbol **at exactly the point that entry
predicted it would survive** — a host with trades to spare. 250 → 28. So the participation cost belongs to the
gate, not the host, and the entry's advice is narrowed rather than confirmed: at ~11% retention you need
roughly 600+ trades per window before the gated arm is measurable, and nothing in this family is close.

<sub>Accidental confirmation worth keeping: the re-run BASE reproduced ORDER-205's **1.08 at 250 trades to the
digit** on a *different* binary, which independently re-proves the ORDER-217 `[08]` block is inert when off,
and shows the tester repeats exactly **within one lane** — supporting ORDER-371's problem being cross-install
specifically rather than general nondeterminism.</sub>

### ORDER-430 — host search · `REVIEWED` → **two hosts cleared the bar** (verdict amended same day — see below)

Seven Model-4 control runs on one pinned set. AUDCAD (BWD 2.20) and XAUUSD (BWD 2.29) were marked QUALIFIED
exactly as written. They should not have been, and **the tell is a relationship, not any single number**:

| | passed BWD | failed BWD |
|---|---|---|
| trades | 62 · 52 | 343 · 473 · 363 |
| BWD DD% | 1.70 · 1.86 | 12.56 · 11.96 · 15.58 |

**The hosts that clear BWD are the ones that were barely in the market during it.** A grid taking 52 trades
across three stress years at under 2% drawdown is thin evidence of resilience. The `n >= 30` floor — which this
lane pre-registered itself — screens out *having no trades*, not *having too few to interpret*, and both hosts
came back **under 1.0 on MAIN** (0.93, 0.95). **That is a real caveat on how to read the A/B delta. It is not a
reason to void a pass the bar already granted** — see the correction below.

⇒ **This is where I got it wrong, and a blind Codex audit caught it the same day.** I concluded "no usable
host" and parked ORDER-236. **That is moving the goalposts after seeing the numbers**: the pre-registered bar
says `BWD >= 1.20 at >= 30 trades = QUALIFIED`, both hosts met it, and **the order I wrote myself says to take
the highest-BWD qualified host into ORDER-236 by changing `-Symbol` only**. My reasoning was also loose —
"losing less" is a measurable lever effect; what I actually meant is that it is not enough to *deploy*, which is
a different statement from "cannot be measured".

⇒ **Corrected: ORDER-236 is UN-PARKED and proceeds on XAUUSD H1** (BWD 2.29, the highest qualified). No set
rebuilding — the A/B sets share the CTRL's lineage, which is why ORDER-430 ran one file across seven symbols.
The sample-size concern survives as a **reading caveat written onto every delta** (host MAIN is 0.95, BWD n is
52, so report trade counts and do not over-read small deltas), and the `n >= 30` floor is raised **for the next
order**, not retroactively against a pass it already granted. AUDCAD H1 is available as a replication host.

⚠️ Read together with ORDER-236, the chassis now has three legs measured on the `B14_AB_off` parity config and
none clears both windows. **That indicts the A/B base config, not the deployed demo legs**, which run different
sets — the same caveat ORDER-236 already carried.

### 🟢 GBPJPY — the claim I wrongly rejected, and the guard evidence it turned out to be

**This section originally read "the claim that was not accepted". It was retracted the same day after a blind
Codex audit, and the correction matters more than anything else on this page.**

The run truncated at **2020-03-12** with a 93.5% idle tail and 24.95% equity drawdown. `check_truncated_run.ps1`
flagged `[SUSPECT]` and refused the metrics — the cage doing its job. The runner attributed the truncation to
the risk cage firing and cited a log line with a timestamp. **I searched that log, found nothing, and recorded
the citation as unverifiable.** That was wrong.

The file is **UTF-16LE** (BOM `ff fe`). Every search I ran was byte/UTF-8 oriented and **could not have matched
anything in it**. Read with the right encoding it contains `HARD KILL` twice, `GBPJPY` 368 times, and `[RISK]`
twice:

```
20394 | 2020.03.12 07:45:59   [RISK] HARD KILL: DD 25.01% >= 25.00% (profile 2) -> closing all
20399 | 2020.03.12 07:45:59   [RISK] HARD KILL complete: broker flat verified -> halt (persisted)
```

Path, timestamp and wording match the runner's citation exactly, and the master tester journal carries the same
pair. **The runner was right; I was wrong, and I published that error to the board, a commit message, an
append-only `B1_DATASET` row, this handoff, and the user twice.**

**What this actually is:** the strongest piece of guard evidence this lab has — the 25% hard kill **observed
firing on real ticks** during the COVID crash, closing flat, verifying flat with the broker, and persisting the
halt. It is the exact counterpart to ORDER-490, where the reject arm has never been seen. ⚠️ **Do not inflate
it**: this is one event, not a safety certificate. The VERDICT GATE still wants a base control and a fire count
before a guard claim is written up as passed.

> 🔴 **The lesson, and it is mine.** The signal was in front of me: searching for `GBPJPY` in the log of a
> GBPJPY run returned **zero**, and I recorded that as corroborating my conclusion when it was proof my reading
> tool was broken. Memory `guard-disarmed-by-prose-reported-as-note` states the rule plainly — **"cannot read
> the input" must always be distinguished from "there is nothing there"** — and I had that memory. **New rule:
> before rejecting a citation, prove the instrument can see the file at all by searching for a token that must
> be present (a symbol, an EA name). If that also returns zero, the instrument is wrong, not the claim.**

**What the order should say next time:** instruct the runner to use the tool that emits an evidence file
(`check_truncated_run.ps1 -TesterLog <path>`) rather than to read a log — not because reading a log is
unreliable, but because a script parses with the correct encoding while a later reviewer may not.

## 3. What the two Codex audits changed

Both dispatched blind, both with their load-bearing claims re-checked against the source by this lane rather
than taken on trust. Both held.

### ORDER-490 — the audit corrected the order's own headline

The order said guard **G4 had never been observed executing**. Wrong, and wrong in the direction that sends the
next person hunting dead code. `g_w5_n_signalled` increments at line 218; the guard runs at 211 and its
rejection arm returns at 213. **So `signalled=26` is proof G4 ran at least 26 times and accepted every time.**
What has never been observed is the **rejection arm** — and "the guard is dead code" versus "the reject branch
is untested" need completely different fixes.

**Bigger than the ticket, and currently without an owner:** `Wave5_SLValid()` reads `SYMBOL_TRADE_STOPS_LEVEL`
and point **only** — no tick size, no freeze level — and `ExitManager.mqh:134` validates the *unnormalized*
price one line before `NormalizeDouble`. Verified independently: `TICK_SIZE` appears only at line 513 on an
unrelated path, `FREEZE_LEVEL` is absent from the file. **Passing G4 does not mean the submitted SL is valid**,
so "preventive, not detective" claims more than the code does.

Also refuted: the assumption carried in `HANDOFF_2026-07-27_AUDIT_REPAIR.md` §3 that these guards cannot be
forced in the tester. `SYMBOL_TRADE_STOPS_LEVEL` is settable on a custom symbol. A two-arm test is written into
the row with **both directions pre-registered** — must-fire and must-stay-silent.

### ORDER-421 — `REVIEWED`, and it was never "three cases red"

Fixture drift only; the production guard is sound. The synthetic repo copies the real pre-commit hook but its
seed never stubbed the checkers that hook calls, so a synthetic commit died before ever reaching the guard
under test. `check_order_collision` entered the hook in `ad470945` (2026-07-26), which dates the breakage
exactly; `check_handoff_contract` followed in `b5d71e47`. **Neither commit touched the suite, and nothing makes
the fixture track the hook's dependency list — adding one guard silently broke the cage of another.**

The "empty detail" was never empty: stdout is blank when the hook fails and `TrimEnd` does not trim the front,
so the message was pushed to the next line.

**And the exception was a throw, so the suite stopped at case 15.** With the stubs in place it runs to
completion at **105 cases**. This was never three failures out of fifteen — it was **90 cases, 86%, that had
not executed since 2026-07-26.** A cage protecting a commit-blocking guard had been running at 14% of itself
for two days.

Verified under two deliberately different machine states: **103/105 exit 1** with three MT5 terminals
generating ticks, **105/105 `ALL CASES PASSED` exit 0** on a confirmed-idle machine.

---

## 4. Two new orders, both found by accident

- **ORDER-500** — `B1_DATASET.csv` parses as **83 order rows, not 84**. <sub>(Scope narrowed on review: the
  *trailing-newline* half of this defect healed as a side effect of this lane's own B1 appends, which write a
  leading newline when one is missing. What remains is the glued `ORDER-412` row, the absent repair path, and
  the absent field-count assertion.)</sub> ORDER-280's row is glued onto the tail
  of ORDER-412's quoted `notes` with no line break, so a reader sees one row of 25 fields and ORDER-280 is
  absent. The one-newline repair was written and verified, and the ORDER-144 append-only guard **correctly
  blocked it**; it was not bypassed and the working tree was restored byte-for-byte. The exposed gap is that
  `regression_baseline.csv` has an audited escape hatch and **B1 has none**, so the only routes are
  `--no-verify` or leaving the file broken. Three options with costs are in the row — **the choice widens what
  a Contract D dataset permits, so it is the user's, not a runner's.** Separately: the guard checks that bytes
  were only *added*, never that what was added is a *row*.
- **ORDER-501** — the event-log cage fails 2 concurrency cases **only under load** (`events=144 expected=150`).
  Filed rather than dismissed as flaky, because "timing-sensitive test" and "events genuinely lost under
  contention" are different problems and one observation cannot separate them — and this repo's normal state is
  an MT5 batch running while other lanes commit, which is precisely how ORDER-500 happened.

---

## 5. Things this lane got wrong, caught before they landed

- Nearly recorded *"the suite prints failure and exits 0"* — a serious claim. The `0` belonged to the trailing
  `echo` in the lane's own command; the real exit was **1**.
- The Python heredoc silently mangled `logs\20260728.log` into an octal escape. Caught by reading the rendered
  line back, not by trusting the write.
- The `check_state` entry-claim guard tripped on new Thai prose containing its needle inside an unrelated
  sentence. Used the sanctioned `ENTRY-CLAIM-OK` marker rather than editing the prose until the check went
  quiet — which is what the guard's own comment asks for.

---

## ปลายทางของทุกรายการ

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| MacdDiv USDJPY H4 optimized once; ceiling 1.18, BUILD-ON stands | ORDER-431 (REVIEWED) |
| RSI gate re-selects rather than filters; trade count is not an inertness test | EDGE_CATALOG (new entry) |
| MACD-cross participation cost is the gate's property, not the host's | EDGE_CATALOG (ORDER-217 entry, replication note) |
| Host search: 2 hosts qualified; verdict amended after audit — the n>=30 floor is raised for the NEXT order, not retroactively | ORDER-430 (REVIEWED, amended) |
| Caged lever pair proceeds on XAUUSD H1, with sample-size caveats on every delta | ORDER-236 (UN-PARKED, STEP 2 ready) |
| GBPJPY truncation = risk-cage hard kill, **verified in the log** (my rejection of the citation was wrong, retracted) | ORDER-430 (amended) — no re-run needed |
| G4 runs and accepts; only its rejection arm is UNTESTED | ORDER-490 (header corrected, still OPEN) |
| G4 ignores tick size + freeze level and validates before normalization | ORDER-490 — **new, no owner yet** |
| ORDER-105 cage: fixture drift fixed, 105/105 green | ORDER-421 (REVIEWED) |
| Event-log cage red only under load | ORDER-501 |
| B1_DATASET row lost to a missing newline; no sanctioned repair path | ORDER-500 — **needs the user's choice** |
| ORDER-340 closed on 07-27, header never flipped | DONE (archived) |
| USER: log in `/portable` on 463666728 + 69424711 | ORDER-400 → `_triage/USER_TASKS_2026-07-28.md` |
| USER: read currency + balance on 463666728 | ORDER-230 → same brief |
| USER: hash + mtime every `.ex5` on the VPS | ORDER-410 → same brief |
| USER decision: MacroGate 990120 · the 30-trade bar · PERSIST_MIGRATION · Meta 5b tick history | ORDER-232 · 235 · 234 · 371 (deliberately NOT in the brief) |
| Ledger "numbers used" block is still hand-maintained | BACKLOG-D29 |
