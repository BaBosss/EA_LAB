> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **`ORDER-510` STEP 1 — the testable
> adopt-once procedure for upgrading the live fleet off its pre-132 binaries.** Written 2026-08-01,
> lane `S-2026-08-01-OPERATE`. It is a **written procedure**. Nothing in it was executed, no VPS was
> touched, no binary was copied. `ORDER-510`'s standing prohibition remains in force until the order
> closes.

# ORDER-510 STEP 1 — adopt-once, and how to rehearse it before it costs anything

## 0. What this document is for

The fleet runs binaries built before `ORDER-132`/`138`. Upgrading them is not a file copy: the new
build contains a **fail-closed gate** that refuses `OnInit` when it finds pre-132 state, and five
magics are known to carry that state. The failure looks like *"the EA went quiet"*, not like a
refusal. This procedure exists so the upgrade is a sequence with checkpoints instead of a copy
followed by a discovery.

**Everything below is read out of the source at the SHA this file was written against.** One
consequence is stated once and applies throughout: **the binaries currently running are not this
source.** Wherever a step asks what the *running* EA did, the answer comes from its Journal — never
from reading today's code. (`ORDER-510` STEP 3 makes the same demand; it is repeated here because it
is the single easiest rule in this document to forget mid-procedure.)

## 1. The gate, exactly

[`RiskControl.mqh:137-156`](../ea_template/core/RiskControl.mqh:137). `RiskControl_InitEx` returns
**false** — `OnInit` fails, the chart never starts — when **any** of four conditions holds and
`RC_AdoptLegacyHalt` is false:

| # | trigger | fires when | gated by |
|---|---|---|---|
| 1 | `legacyKill` | `Boss_<magic>_rc_kill_pending > 0.5` | `RC_PersistHalt` (default **true**) |
| 2 | `legacyHalt` | `Boss_<magic>_rc_halted > 0.5` | `RC_PersistHalt` |
| 3 | **`legacyPeak`** | `Boss_<magic>_rc_peak_eq` **merely EXISTS** — no threshold | `RC_PersistHalt` |
| 4 | `legacyHwm` | `Boss_<magic>_acct_hwm` exists | `RC_AcctDDLimitPct > 0` |

Trigger 3 is the one that decides the size of this job. It fires on **existence**, so any chart that
simply ran long enough under a pre-132 binary to record a peak equity has it. The refusal is
therefore close to the fleet's **default** state, not an exceptional one — and `RC_AdoptLegacyHalt`
defaults **false**, so refusing is the default outcome.

Key formats, which is how you tell the two vintages apart at a glance:
`Persist_LegacyKey` = `Boss_<magic>_<name>` ([`Persist.mqh:88`](../ea_template/core/Persist.mqh:88), pre-132, **no account identity**) ·
`Persist_Key` = `Boss2_<srvhash>_<login>_<symbol>_<magic>_<name>` ([`Persist.mqh:39`](../ea_template/core/Persist.mqh:39), post-132, scoped).

## 2. The two cases the gate cannot tell apart — and neither can you, from the key

The FATAL message ([`RiskControl.mqh:149-153`](../ea_template/core/RiskControl.mqh:149)) prescribes
**two different remedies**, because there are two different situations:

- **the account's own pre-132 state** ⇒ adopt once (§5-§6 below)
- **state imported from ANOTHER account** (the terminal was switched to a different login while the
  same magic ran) ⇒ **delete** the `Boss_<magic>_*` GlobalVariables via F3

And the message says why you cannot simply choose: *"magic-only keys, account identity unknown"*.
The pre-132 format encodes no login, so **the key cannot tell you which account produced it.** That
is the entire reason `ORDER-132` scoped the format in the first place.

> 🔴 **This is where `ORDER-510`'s standing prohibition and the code's own instruction appear to
> collide, and the collision has to be resolved before anyone is standing at an F3 window.** The
> order says: *do not delete `Boss_<magic>_*` GVs to "make it pass" — that discards a halt/kill state
> that may still be active.* The code says: for foreign state, delete. **Both are right, and the
> prohibition's real target is triggers 1 and 2, not trigger 3.** `rc_kill_pending`/`rc_halted` are
> live safety state and deleting them silently disarms a kill. `rc_peak_eq` is a *measurement
> baseline*. Deleting it does not disarm anything; it makes the EA re-establish its peak from current
> equity, which loses drawdown history and nothing else.
> **This is a distinction, not a permission.** It is written here so the decision is made against the
> right question, and §7 states what still has to be true before it is taken.

## 3. The discriminator you actually have

Not the key. Two things:

**(a) The value, read against the account it sits on.** `ORDER-510` STEP 3 already recorded the
anomaly: `Boss_990120_rc_peak_eq` and `Boss_990001_rc_peak_eq` both read **10136.29** on an account
whose equity is **~99,944** after a 90,000 deposit on 2026-07-25 — and the key's last write is
2026-07-26 17:02, **after** the deposit. A peak-equity figure that did not move across a 10× deposit
is not tracking that account.
**What it is evidence OF is not settled, and this procedure does not need it settled to proceed.**
Both readings are dangerous in opposite directions and both are answerable only from the Journal of
the binary that wrote it:
- if the value is a *foreign, poorer* account's peak → DD measured from it is negative (equity above
  peak) → the kill line is **too loose**, and has been for as long as the key has been wrong
- if a *foreign, richer* account's peak had landed instead → DD would read enormous → **kill on the
  first tick**, which is exactly the liquidation scenario `ORDER-138`'s comment names as the reason
  the gate exists

**(b) A census taken before anything is upgraded** — §4.

## 4. Pre-flight: the read-only census (`ORDER-510` SECOND BLOCKER)

Per terminal, **Tools → Global Variables (F3)**: list every name matching `Boss_<magic>_*` — i.e.
**magic-only, no account scoping** — and record the count and value per magic. Read-only. No binary
change. Do this **before** any upgrade.

| account | type | template magics | legacy-GV status |
|---|---|---|---|
| `463666728` | DEMO | 14 | ✅ cleared (user deleted 4 stale `rc_peak_eq` 2026-07-28) |
| `415573666` | DEMO | 9 | 🔴 UNCHECKED |
| `141049900` | **REAL_CENT** | 4 | 🔴 UNCHECKED |
| `159475669` | **REAL_CENT** | 2 | 🔴 UNCHECKED |
| `159503454` | **REAL_CENT** | 1 | 🔴 UNCHECKED |

**Four unchecked, three of them real money.** An empty list for an account means the upgrade is safe
*for that account* and generalises to nothing else: `463666728` had 14 template charts and only **4**
legacy keys, so the key is written under narrower conditions than "a chart ran". Population size is
measured per terminal, never inferred — and *"the other accounts probably look like this one"* is not
a measurement.

## 5. The rehearsal — build the fixture, then run it for free

`ORDER-510` requires this be proven on a demo terminal that **creates the legacy key itself**, not on
a real account. Two things make that practical, and the second is not in the order:

**5.1 The fixture is trivial, because trigger 3 fires on existence.** You do not need to reproduce a
pre-132 binary. On a demo terminal, F3 → add a variable named exactly
`Boss_<magic>_rc_peak_eq` with any value, where `<magic>` is the demo chart's `_0_Magic`. That
reproduces the refusal precisely, because [`Persist_HasLegacy`](../ea_template/core/Persist.mqh:90)
tests nothing but the name.

> `ea_template/tests/PersistMigrate_Test.mq5` cannot be used for this. It is **tester-only and
> refuses chart attach** ([`:26`](../ea_template/tests/PersistMigrate_Test.mq5:26)) because it calls
> `GlobalVariablesDeleteAll`, which on a live terminal would wipe every Boss safety GV. It is
> evidence about the tester's sandboxed GV space, never about terminal behaviour — which is what
> `ORDER-510` means when it says this gate **has never been observed firing** where it matters.

**5.2 There is a no-write rehearsal already in the code.** `DryRun`
([`Inputs.mqh:130`](../ea_template/core/Inputs.mqh:130) — *"log intents, no orders"*) is honoured by
the migration path: with `DryRun=true`, `Persist_MigrateLegacy` prints
`[PERSIST] DryRun: would migrate <legacy> -> <scoped> (<value>) - skipped (no writes in DryRun)`
and **writes nothing** ([`Persist.mqh:124`](../ea_template/core/Persist.mqh:124),
[`:135`](../ea_template/core/Persist.mqh:135)). The gate is checked *before* migration and consults
only `RC_AdoptLegacyHalt`, so:

**`RC_AdoptLegacyHalt=true` + `DryRun=true` = the gate passes, the exact migration is printed, and
nothing is written.** That is a full rehearsal of the real step, on the real terminal, at zero state
cost — and it names the value that would be adopted *before* you consent to adopting it.

> ⛔ **The one condition that makes the rehearsal safe, and it is not optional.** `DryRun` suppresses
> **closes as well as opens** ([`Execution.mqh:315`](../ea_template/core/Execution.mqh:315),
> [`:338`](../ea_template/core/Execution.mqh:338), [`:374`](../ea_template/core/Execution.mqh:374),
> [`:380`](../ea_template/core/Execution.mqh:380), [`:389`](../ea_template/core/Execution.mqh:389),
> [`:399`](../ea_template/core/Execution.mqh:399), [`:476`](../ea_template/core/Execution.mqh:476)).
> An EA in DryRun **will not exit its basket.** Rehearse only while the leg is **FLAT** — the same
> condition `ORDER-511` established for a magic re-pin, for the same class of reason.

## 6. The live adopt-once sequence, per magic

Run only after §4 (census) and §5 (rehearsal on demo) are both done, and only while the leg is FLAT.

1. **Snapshot** — record every `Boss_<magic>_*` name and value from F3, and the account equity, into
   the order's evidence file. This is the only copy of the pre-migration state that will exist.
2. **Attach once** with `RC_AdoptLegacyHalt=true`, `DryRun=false`, everything else at the locked `.set`.
3. **Verify in the Journal** — `[PERSIST] migrated legacy Boss_<magic>_rc_peak_eq -> Boss2_<scope>_rc_peak_eq (<value>)`
   ([`Persist.mqh:141`](../ea_template/core/Persist.mqh:141)). The printed value must equal the value
   snapshotted in step 1. **A different value means stop** — something else wrote in between.
4. **Verify in F3** — the `Boss2_…` key now exists and the `Boss_<magic>_…` key is **gone** (migration
   deletes the legacy key after a confirmed copy, [`Persist.mqh:117`](../ea_template/core/Persist.mqh:117)).
   Both halves are checked: a `Boss2_` key appearing while the legacy key survives is a partial
   migration, not a success.
5. **Set `RC_AdoptLegacyHalt` back to `false`** and restart the chart. It must start **cleanly**.
   > 🔴 **CORRECTION 2026-08-02, found by the first real run.** This step used to add *"and it is
   > the only step that proves the consent flag was not left standing."* **That is false.** By the
   > time step 5 runs, the legacy key is **gone** — step 4 verified exactly that — so the gate has
   > nothing to fire on and the chart starts cleanly **whether the flag is `true` or `false`**. The
   > clean start proves the state is scoped; it proves nothing at all about the flag.
   > **What does prove it:** `RC_AdoptLegacyHalt` is one of the build's inputs, so it is inside the
   > `[CFG] effective_config_hash` the EA prints at every attach. If the digest at step 5 **differs**
   > from the digest at step 2, the configuration really changed — and since the two `.set` files
   > differ in that one input, the flag is what changed. Compare the two `[CFG] input surface:`
   > lines. A step that cannot fail is not a check (`GUARD_SHAPES` shape 5), and this one could not.
6. Record: magic · account · snapshotted value · migrated value · journal timestamps · F3 before/after.

**Precedent that this end-state is real, not theoretical:** `990016` on `463666728` was attached
2026-07-28 with `RC_PersistHalt=true` **and** `RC_AdoptLegacyHalt=false` and **started cleanly** —
i.e. the fail-closed gate does not fire once an account is clean. That is one account, and it
generalises to nothing (§4).

## 7. When deletion is the correct branch

Only when **all** of these hold, and the first is not inferable from the key (§2):

1. the state is established as **foreign** — the account did not produce it
2. `rc_kill_pending` and `rc_halted` are **absent or 0.0** for that magic, read from F3 and recorded
   — i.e. there is no live kill/halt to discard
3. the deletion is recorded with the same snapshot discipline as §6 step 1
4. **the owner has approved it for that specific magic.** These are real-money accounts and this
   branch discards state rather than converting it.

Condition 1 is the hard one and this document does not pretend otherwise: on the evidence available
today the `10136.29` reading (§3a) is *consistent with* foreign state and is **not proof of it**.
It is a `PENDING-EVIDENCE` item, answerable from the Journal of the running binary.

## 8. Two refusals that are NOT this gate, and will be blamed on it

- **Default magic.** The current build returns `INIT_FAILED` when `_0_Magic == 990001` outside the
  tester ([`LabCore.mqh:254-257`](../ea_template/core/LabCore.mqh:254) — the `ORDER-129` guard). Any
  chart still wearing the compiled default refuses to start under the new binary **regardless of any
  legacy key**. <sub>The board cites this guard at `LabCore.mqh:235-239`; that reference has drifted
  — it is `254-257` at this SHA. Same drift class the boards already record; noted rather than
  silently corrected in passing.</sub>
- **`AllowLive=false`.** A leg that never trades looks identical from the outside. This has already
  cost two clock resets (`990025`/`990030`) and one on `990303`.

All three failure modes present as *"the EA is quiet"*. **Any post-upgrade check that concludes "it
is running" from the absence of an error line is not a check** — read the Journal for the `[INIT]`
line and confirm the chart announced itself.

## 9. What STEP 2 owes when it runs

The five magics carrying legacy keys: `990208` (Boss_14 GBPJPY — **the one queued for real money**) ·
`990120` · `990301` · `990302` · `990001`. STEP 2 walks all five, then closes `ORDER-234`.
Per-magic the record must show: census before · rehearsal output · the six items of §6 · and the
chart's `[INIT]` line after the final restart.

## 10. Prohibitions (inherited from `ORDER-510`, unchanged)

- ❌ copy / rebuild / overwrite any `Boss_*.ex5` on the VPS while `ORDER-510` is open
- ❌ leave `RC_AdoptLegacyHalt=true` standing after the migration
- ❌ delete `Boss_<magic>_*` GVs to "make it pass" — §7 is the only route, and it is not that
- ❌ conclude that any EA "is behaving correctly" by reading the current source, when the binary
  running is not built from it
- ❌ run the rehearsal (§5) on a leg that is not FLAT — DryRun suppresses exits

---

## 11. Verification pass, 2026-08-01 (`S-2026-08-01-TEMPLATE`) — checked, not assumed

The factory-session prompt asked for this document to be **verified against the trap rather than
assumed to cover it**. Every claim above was re-read at the line. Result: **the procedure holds** —
and three things it does not say were found, two of which change what an operator does at the
terminal.

**What was confirmed at the line, unchanged:** the four triggers and their gating
([`RiskControl.mqh:137-156`](../ea_template/core/RiskControl.mqh:137)) · both key formats
([`Persist.mqh:88`](../ea_template/core/Persist.mqh:88) / [`:39`](../ea_template/core/Persist.mqh:39)) ·
`Persist_HasLegacy` testing nothing but the name ([`:90`](../ea_template/core/Persist.mqh:90)) ·
the DryRun rehearsal writing nothing ([`:133-137`](../ea_template/core/Persist.mqh:133)) ·
`DryRun` defaulting false ([`Inputs.mqh:130`](../ea_template/core/Inputs.mqh:130)) ·
`RC_PersistHalt` default **true** and `RC_AdoptLegacyHalt` default **false** ·
the `ORDER-129` default-magic refusal ([`LabCore.mqh:254-257`](../ea_template/core/LabCore.mqh:254)) ·
`PersistMigrate_Test` refusing chart attach ([`:26`](../ea_template/tests/PersistMigrate_Test.mq5:26)).

### 11.1 🔴 §6 names the wrong journal line for a chart refused by trigger 1 or 2

§6 step 3 tells the operator to look for `[PERSIST] migrated legacy Boss_<magic>_rc_peak_eq -> …`.
That line only ever appears for **trigger 3** (and for trigger 4, via the same helper). Legacy
`rc_kill_pending`/`rc_halted` are **not migrated** — they are *consumed*: read once, folded into the
new single `rc_state` enum, and the legacy flags then deleted
([`RiskControl.mqh:167-186`](../ea_template/core/RiskControl.mqh:167)). The line to verify on such a
chart is

```
[RISK] migrated legacy halt/kill flags -> Boss2_<scope>_rc_state=<1|2>
```

([`:176`](../ea_template/core/RiskControl.mqh:176)). An operator following §6 literally on a
kill/halt chart finds no `[PERSIST] migrated` line, and the honest reading of that — *"the migration
did not happen, stop"* — would be wrong. **All four triggers are cleared by one adopt-once attach**;
they just announce themselves in three different ways. `acct_hwm` is migrated by the same helper from
[`RiskControl_AcctGateInit`](../ea_template/core/RiskControl.mqh:81), which runs at
[`:212`](../ea_template/core/RiskControl.mqh:212) — outside the `RC_PersistHalt` block, so trigger 4
clears even with `RC_PersistHalt=false`.

### 11.2 🔴 The DryRun rehearsal is *quieter* on the dangerous triggers, and it parks the EA in KILL-PENDING

§5.2's rehearsal is real, but its output is not uniform:

| refused by | what `RC_AdoptLegacyHalt=true` + `DryRun=true` prints |
|---|---|
| trigger 3 `rc_peak_eq` | `[PERSIST] DryRun: would migrate … (<value>)` — **names the value** |
| trigger 4 `acct_hwm` | same line, via the same helper |
| trigger 1 `rc_kill_pending` | **no `[PERSIST]` line at all** — the `rc_state` write is `!DryRun`-gated ([`:173`](../ea_template/core/RiskControl.mqh:173)); what appears instead is `[RISK] KILL-PENDING restored from persist` ([`:194`](../ea_template/core/RiskControl.mqh:194)) |
| trigger 2 `rc_halted` | likewise `[RISK] HALT restored from persist (peak …)` ([`:201`](../ea_template/core/RiskControl.mqh:201)) |

So the rehearsal **does not name the kill/halt value it would adopt** — that number comes from the
F3 census (§4), not from the journal. And the second half matters more: those two paths set
`g_rc_kill_pending` / `g_rc_halted` **before** the DryRun check, so the rehearsed EA is now sitting in
kill-pending with **closes suppressed** ([`Execution.mqh:315`](../ea_template/core/Execution.mqh:315)
and siblings). §5's *"rehearse only while FLAT"* was written for a different reason and happens to
cover this — but on a kill/halt chart it is not a precaution, it is the whole safety margin.

### 11.3 Line-reference drift, recorded not silently patched

`RC_AdoptLegacyHalt` is at [`Inputs.mqh:499`](../ea_template/core/Inputs.mqh:499), not `:497`
(`RC_PersistHalt` at `:484` is correct). §6 step 4 cites `Persist.mqh:117` for "migration deletes the
legacy key after a confirmed copy"; `:117` is the function header and the delete itself is
[`:140`](../ea_template/core/Persist.mqh:140). Neither changes any instruction.

## 12. The one-command check

`scripts/check_persist_legacy.ps1` turns the §4 census into a verdict, so the question *"is this
chart safe to update"* has an answer that is not a human re-reading four trigger conditions at an F3
window.

```bash
powershell -File scripts/check_persist_legacy.ps1 -GvDump census_415573666.txt -Account 415573666
```

Input is a text file with one GlobalVariable per line, in whatever shape and encoding the terminal
produced — **UTF-16LE with no BOM is sniffed and read**, which is not decoration: that encoding is
precisely how a byte-oriented reader comes back with zero matches forever and reports *"nothing
found"* as a clean bill of health (memory `prove-the-instrument-can-see-the-file`).

- `exit 0` — no magic in the census fires the gate. Safe **for this census, this terminal, this
  moment**; it generalises to no other account.
- `exit 1` — at least one magic fires. The report names which trigger, and separately flags any
  **live** `rc_kill_pending`/`rc_halted` as state that adopt-once converts and deletion would disarm.
- `exit 2` — the check could not be performed. This includes **a census that parsed nothing at all**:
  that is indistinguishable from an empty file, a wrong path, or an encoding the reader mishandled,
  so it is refused rather than certified. `-AssertDumpComplete` lets the operator certify an empty F3
  by hand, and the report then states that the conclusion rests on that assertion and not on evidence.

It reproduces the gate's **specificity**, not just its sensitivity: an inactive `rc_kill_pending=0.0`
is benign residue that the gate does not fire on, so the check calls that chart SAFE and says why.
Trigger 4 depends on `RC_AcctDDLimitPct`, which no census can contain — undeclared, an `acct_hwm` hit
is reported `CONDITIONAL` and **counted as unsafe**; `-AcctDDLimitPct <n>` resolves it either way.
With `-Account`, `DEPLOYMENTS.csv` is consulted so the report also names the magics it **cleared**
and any legacy magic with no inventory row (the `990001` shape, `ORDER-511`).

Cage: `scripts/_test/run_persist_legacy_tests.ps1`, **30 cases, green**, with as many must-ALLOW
cases as must-REFUSE. Four mechanisms were neutralised one at a time in a copy of the checker to
prove the cases discriminate; the suite's header records what each probe did, including the one where
the exit code did **not** move and only a count assertion caught the defect.

⚠️ **What it is not.** It reads a census; it does not read a terminal. It cannot see `_06_AllowLive`,
it cannot see which binary is installed, and a chart it calls SAFE can still refuse to start for
either reason in §8. `exit 0` is *"this gate will not stop you"*, never *"the upgrade will work"*.
