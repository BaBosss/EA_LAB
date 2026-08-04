# OPENING PROMPT — the corrections lane, part 4. Five of the nine are repaired; `ORDER-1260`, `1261`, `1265` have never been touched.

> Written 2026-08-04 by lane `S-2026-08-04-CORRECT3`, which closed **`ORDER-1269` (#1 + #3, plus the
> tier wiring the order required)** and **`ORDER-1267` (#1 + Part 2)**. `_triage/PROMPT_NEXT_SESSION_CORRECTIONS.md`
> is still the map. Parts 2 and 3 are still worth reading for the cage trap and the budget. This file
> records what moved, and the four things it learned that change how you should approach the rest.

---

## §0 — 🔴 READ THIS FIRST: what is live, and the one mistake this lane made

`S-2026-08-04-S13E` was `ACTIVE` alongside this lane the whole session and committed repeatedly
(`18041974`, `c772b12f`). **Verify in `docs/SESSION_LEDGER.md` rather than trusting this line**, but
plan for concurrency either way.

🔴 **THE MISTAKE, AND IT IS THE MOST USEFUL THING IN THIS FILE.** My reservation commit `633a6414`
carries **128 lines of `S13E`'s `AGENT_TASKBOARD.md` work** (rows `ORDER-1300` · `1301` · `1302`,
the `ORDER-1273` closure). Cause: the reservation landed with a malformed message and I repaired it
with **`git commit --amend` WITHOUT A PATHSPEC**, which commits the *whole index* — and `S13E` had
staged the board in the **40 seconds** between my two runs. Nothing of theirs was lost; the
provenance is wrong. Disclosed in the ledger and in `d65763d3`.

> **The lesson is narrower than "path-limit your commits" — I DID path-limit, and it held.**
> It is `--amend`, and any other command that silently drops the pathspec. If you must repair a
> commit message, `git commit --amend -o -- <path>` or accept the ugly message.

I did **not** repair it with `reset --soft`: history rewrite is a standing prohibition, a second
writer was moving the branch tip, and rewriting to fix an attribution line would risk their commit.
Third occurrence in this chain after `eda48dd8` and `99c73bd9`.

---

## §1 — What is DONE, so you do not re-derive it

| order | state | one line |
|---|---|---|
| **`ORDER-1264`** | ✅ DONE `14276944` | a lost `x-enforced-by` reddens instead of vanishing |
| **`ORDER-1263`** | ✅ DONE `007e9f65` | `OwnerRef` resolves — R1 blob · R2 identity · R3 sha256 · R4 anchor |
| **`ORDER-1268`** | ✅ DONE `e5d81804` + `b14c7b84` | a partial surface is refused on the evidence path |
| **`ORDER-1269`** | ✅ **#1 + #3 DONE** `e272a34b` · `ddf3153f` · `929f3b18` | the pin instrument changed; **#2 and #4 still OPEN** |
| **`ORDER-1267`** | ✅ **#1 + Part 2 DONE** `446f7539` | the leak scanner can tell CLEAN from BLIND; **#2 still OPEN** |
| **`ORDER-1266`** | ⏳ **2 of 7** `26746f04` | **#1 is analysed, not done — part 3's §3 is still the right brief** |

### 🎯 Four findings that should change how you open the next one

**1. 🔴 A REPAIR CAN CARRY A HIDDEN OWNER SIGNATURE, AND THE OBVIOUS FORM OF `ORDER-1269` #3 DID.**
My first commit of #3 withheld the failing row from what `check()` *returns*. That broke **29 of the
68 canonical vectors** in `S2A_ATTESTATION_VECTORS.jsonl`, which declare
`expected_current: {OWNER.md: {decision: APPROVED}}` for records their own `expected_reasons`
refuses — **the defect, written into the signed policy corpus**. That file is a **BUNDLE MEMBER**, so
editing it changes the digest, fails F1, and costs the owner a signature to repair a *display bug*.
The escape was in the ratified wording, which is exact: *"the exit code is already honest; **the line
a human reads** is not."* Conformance never reads printed output.

> **Before repairing anything in `_triage/factory_os/`, ask which of the six bundle members your
> change touches.** They are listed in `check_s2a_attestation.py:BUNDLE`. And run
> `run_s2a_conformance.py` — I did not, before that first commit, and nothing else caught it because
> none of those checkers were on the commit path until `929f3b18`.

**2. 🔴 MEASUREMENT KILLED MY FIRST DESIGN TWICE, IN BOTH ORDERS.** For `ORDER-1269` #1 I designed a
byte-prefix pin (treat the coverage store as append-only). The pinned blob *is* a byte-exact prefix
of HEAD, so it would have gone green — but `ec47f37d` **rewrote 16 existing lines in place** when
those cells changed state. The store **mutates**, it does not merely grow, so it would have worked
today and reintroduced the toll silently later. For `ORDER-1267` the "layer not run" notice was first
a pseudo-hit, then stderr; **both were wrong** (see §3).

**3. 🎯 THE FAST TIER CAUGHT WHAT HAND-RUNNING COULD NOT.** `run_s11_tests.py` and `run_s12_tests.py`
were green every time I ran them by hand and returned **`exit -1 SUITE THREW`** under the hook,
because `.ps1` wrappers run under `$ErrorActionPreference='Stop'` and **any stderr from a native
command is a thrown error**. Memory `thai-output-kills-a-suite-inside-the-hook`, one channel over.
**Run the `.ps1` wrapper, not just the `.py`, before you believe a suite is green.**

**4. 🎯 THE BLAST RADIUS WAS FOUND BY RUNNING, AND ONE CALLER WAS PRODUCTION.** Making an empty
recognizer list a refusal caught **twelve** call sites — and one of them is notifier's `probe`
branch, which sets no secrets *because a delivery probe exists to prove the alert path still runs
when the snapshot is broken*. It genuinely has nothing to derive from, on exactly the run you most
want to succeed. **`grep` for callers before changing a default; then run everything anyway.**

---

## §2 — 🔴 The cage state, because two were armed and both are now spent

`run_s11_tests.py` SP07 — **FLIPPED, not reverted** (`446f7539`). It required the refusal to
**restate** the account it had just refused to let travel. It now requires the **rule named** and the
**value absent**. Do not "fix" it back.

`run_preset_tests.py:296-300` — **still untouched, and part 3's §3 is still the correct brief.** It is
`ORDER-1266` #1 and it is NOT the cage-flip the older handoff described. Read part 3 §3 in full
before touching it: the two configurations hash the same **because the rendered bytes are the same**,
MT5's `.set` format has no unit, and `ORDER-710` made that preimage a **cross-language contract**.
If the answer is that the fingerprint stays unit-free, the case must be **NARROWED, not flipped** —
keep the comparison, delete its stated reason.

**Two cases I narrowed this session, both with the false stated reason deleted and the assertion
kept** — the same move, offered as the worked example:
- `run_s2a_attestation_tests.py` M1 specificity read *"no note today"* — an assertion about the state
  of the **world**, which a legitimate 16-row append reddened with nothing wrong.
- the M1 fire-direction fixture moved `STALE` → `MISSING`, because a STALE note on that path is now
  exempt and the case would otherwise have tested the path-mapping **through a door that no longer
  opens**.

---

## §3 — What is left, with what is measured and what is not

**`ORDER-1269` #2 and #4 — OPEN.**
`#2` the generated §2.1 of `S2A_OWNERSHIP_MIGRATION.md` still instructs the three-file deadlock, and
it **regenerates** from `gen_s2a_migration_doc.py:142-155`, so editing the `.md` fixes nothing.
⚠️ **Both that doc and the generator are BUNDLE MEMBERS** — see finding 1.
`#4` `check_attested_pin_staged.pinned_expectations()` derives a pin only from `expected_post_state`,
so a record without one pins nothing at the front guard. **Partly closed through one door only:** the
new exemption refuses a record with no post-state claim. The front guard itself is untouched.

**`ORDER-1267` #2 — OPEN, and confirmed by reading rather than assumed.** `floating_risk.state` is
named in the module's own contract as **the** example of a refusal and is never read; the only
`state` `build()` consults is the `system_health` row's. A future state meaning BREACH can coexist
with a safe-looking `sensor_state`.
**Also declared open:** the **split-value** gap — a secret spread across two fields is still not
caught. `SP16` **asserts that gap is open**, so closing it produces a failing case rather than
silence. It is not attempted because catching it needs the document concatenated, and with
`secrets_of` admitting any 4-character literal that is a false-positive engine.

**`ORDER-1266`** — `#3` LATENT · `#5` mechanism confirmed by reading, reproducer **not run** · `#4`
and `#6` **not measured**. Part 3 §3 has the full brief and the `EXECUTION_KEY_FIELDS` half still
arrives with a store migration into `factory/**`.

**`ORDER-1260`** (five defects on the money path), **`ORDER-1261`** (a reopened incident silenced
forever) and **`ORDER-1265`** are **still untouched from the original nine.**

---

## §4 — The tier changed, and you inherit the numbers

`ORDER-1269` required `run_s2a_gate` + `check_coverage_transfer` back on the commit path. They are,
as **`scripts/_test/run_s2a_cages.ps1`** — **only those two** of the fourteen entries `ORDER-1252`
moved off, in a wrapper selected only by S2a paths, so that order is honoured rather than reversed.

| | |
|---|---|
| full tier before | **88.1s** of 120.0s, 28 suites — *one sample, and recorded as one* |
| full tier after | **97.5 / 98.4 / 95.5 → median 97.5s** of 120.0s, 29 suites, 0 failed |
| the new suite alone | `-Timing`, `EA_LAB_EVIDENCE=index`: **7.82 / 7.61 / 8.11 → median 7.82s** |

**22.5s of headroom against the PINNED 120.0s.** `$FullTierBudgetSeconds` is not raised and must not
be. Both tables are re-derivable with `-Timing`; the ~1.1s gap against `ORDER-1252`'s recorded
5.4 + 1.3 estimate is kept visible in both files rather than tidied.

⚠️ `factory/coverage.jsonl` and `MASTER_BACKLOG.md` now select that suite, so **`S13E`'s
`gen_pilot_cells.py --apply` commits pay ~7s**. That is deliberate: those are the commits that can
invalidate the transfer acceptance.

---

## §5 — 🔴 ADDED AFTER THE FACT: the independent review found NINE defects in this lane's own work

**Read `ORDER-1310` before anything else in this file.** After the handoff below was written, the
owner asked for an independent review of these two repairs. It found **nine** defects; **six are
regressions this lane introduced**, and **five were reproduced by me before the row was written**.

The two that matter most are both in the guard I **narrowed**, and the brief had ranked exactly that
as the thing to hunt:

- **the exemption accepts ANY reproducible section of the owner file, not the approved one** — a
  post-state claim naming an unrelated stable heading buys it. Reproduced.
- **"for that row only" is false — it is PATH-scoped, not row-scoped.** Latent today (no such pair
  exists in D1), real tomorrow. Reproduced.

Plus a **latent daily-build breaker**: the normalisation added for formatted values makes
`open_lots=0.05` normalise to `005`, which occurs inside a normalised timestamp. The real snapshot
still builds — verified — so it is data-dependent, not a live outage.

And one of my own new cases **cannot discriminate**: the case labelled for F14 always dies at F13,
proven by a surviving mutation. Evidence = `_triage/factory_os/CODEX_AUDIT_CORRECT3_2026-08-04.md`.

> 🚫 **Do not fix #1 or #3 by narrowing further in a hurry — a rushed narrowing is what produced
> them.** #3 is contained. #1 is a real design question and its answer must not be a hardcoded
> section heading.

## §6 — Suggested order

1. **`ORDER-1310`** — the review findings, and they take precedence because six of them are damage
   this lane did. Within it: **#6 first** (latent build breaker, cheapest real risk), then #3, #1, #9.
2. **`ORDER-1267` #2** — small, self-contained, and the module's own contract already says what the
   right behaviour is.
3. **`ORDER-1260`** — five defects on the **money path**, and the largest untouched 🔴.
4. **`ORDER-1261`** — a reopened incident silenced forever.
5. **`ORDER-1269` #2** — read finding 1 in §1 first; it is two bundle members.
6. **`ORDER-1266` #1** — only the `EXECUTION_KEY_FIELDS` half, only after checking whether `S13E` has
   released `factory/**`, and only with the store migration planned rather than discovered.

---

## Standing rules that did not change

- 🚫 No EA verdict from automation — design §10 stops S13 at `EVIDENCE_COMPLETE`.
- 🚫 Do not raise `$FullTierBudgetSeconds` (pinned 120.0s).
- 🚫 Do not edit a cage to make its own FAIL go away. **Narrow it and delete its false stated reason,
  or flip it and assert the opposite — in the same commit as the fix.**
- 🚫 Do not re-add `run_enforcement_status_tests.py` to the tier before it mutates a **copy**
  (`ORDER-1283`). **Check the ORDER-1283 question — "does this cage write to a tracked file?" —
  BEFORE wiring anything onto the commit path, not after.**
- 🚫 `MASTER_BACKLOG.md` §2 outside an owner-approved `gen_coverage --apply` · `AGENTS.md` ·
  `PROJECT_STATE.md` · `s2a_attestations.jsonl` · any `.set` migration · any magic
  allocate/renumber/retire · any history rewrite.
- 🚫 **`git commit --amend` without a pathspec.** See §0.
- **Reserve your order block and commit the reservation before using a number. Re-derive from BOTH
  tests** — every `## ORDER-<n>` across all four board files **and** every reserved block in the
  ledger. At this file's writing the highest in use is **`ORDER-1310`** (opened by this lane out of
  its own block for the review findings) and **`1310-1319` was held by this lane**, so the next free
  block is **`1320-1329`** — **derive it yourself rather than trusting that sentence.** It has been hand-repaired nine times and was stale by twenty-one blocks once.
- **A criterion is committed in its own commit, before the run that resolves it.**

---

Open with: **"`_triage/PROMPT_NEXT_SESSION_CORRECTIONS_4.md` ทำต่อเลย — จองบล็อกใหม่ก่อน · เริ่มที่ ORDER-1267 #2 แล้ว 1260"**
