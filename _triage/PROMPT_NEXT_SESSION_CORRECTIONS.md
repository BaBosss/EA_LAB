# OPENING PROMPT — the corrections session. The audit coverage is finished; this lane repairs.

> Written 2026-08-03 by lane `S-2026-08-03-AUDITCOV`, which audited and **fixed nothing**, on purpose.
> The owner split build / audit / repair three ways. **You are the third seat.**
>
> Read `_triage/factory_os/CODEX_AUDIT_<slice>_2026-08-03.md` for **S10 · S12 · S9 · S3 · S6 · S11**
> (and `S2` if it landed — see §D). Those files are the evidence. This prompt is the map.

---

## §0 — Before you plan anything, three things that will bite

### 0.1 🔴 Two cages ASSERT the defects you are about to fix

```
run_s11_tests.py:802      assert 'balance' in str(exc) and PLANTED_ACCOUNT in str(exc), exc
run_preset_tests.py:296-300   asserts account unit is EXCLUDED from the fingerprint
```

Fixing the secret-in-exception leak (`ORDER-1261` #2 / `ORDER-1267`) turns the first red. Fixing the
USD/cent fingerprint collision (`ORDER-1266` #1) turns the second red.

**A session that meets a red test and "repairs" it by reverting has used the cage to reinstate the
bug.** Change each cage in the **same commit** as its fix, and make the replacement assert the
opposite — value **absent**, rule name **present**; account unit **inside** the fingerprint.

### 0.2 🔴 The order you fix things in matters, because one defect hides four others

`ORDER-1263` (`OwnerRef` resolves nothing) is under `ORDER-1264`, `ORDER-1260` and S2's whole
subject. And `ORDER-1264` #1 (13 of 29 entities are **skipped** by the enforcement check rather than
failed) is **why 1263 stayed invisible**. Fix 1264 first or you will fix 1263 and have nothing that
notices when it regresses.

### 0.3 A second lane may still be live

`S-2026-08-03-S13D` held `AGENT_TASKBOARD.md`, `parity.py`, `check_pilot_acceptance.py`,
`run_s13_tests.py`, `scripts/optimize_guard.ps1` and `scripts/_test/**` today. **Check
`docs/SESSION_LEDGER.md` first.** If it is still ACTIVE, note that `git commit -- <path>` commits the
**working tree** of that path, so a concurrent writer's in-progress edit to the same file rides along
— it happened to this lane today (`99c73bd9` carried a block of mine). The fix that worked:
`scratchpad/stage_mine.py`, which stages hunk-by-hunk into the **index** and commits the index.

---

## §A — The orders this lane opened. All evidence is committed; none of it is repaired.

| order | slice | one line |
|---|---|---|
| **`ORDER-1263`** 🔴 | S2·S3·S10 | **`OwnerRef` validates shape and resolves nothing** — the pin primitive under S2's ownership discipline and under `authorization_ref`. **Do this one first after 1264** |
| **`ORDER-1264`** | S3 | a contract that loses `x-enforced-by` **vanishes from the check** instead of reddening it — 13 of 29 |
| **`ORDER-1260`** 🔴 | S10 | five defects on the money path — a candidate can cite **another strategy's run** and validate clean |
| **`ORDER-1261`** 🔴 | S12 | five defects — a **reopened incident is silenced forever**, and the secret guard prints what it catches |
| **`ORDER-1262`** 🔴 | repo | **a third party's Telegram credential is in pushed history.** **OWNER DECISION — do not act from a lane** |
| **`ORDER-1265`** | S9 | the cache identity does not match what the driver runs; the kill matrix cannot stop where the defects live |
| **`ORDER-1266`** | S6 | the fingerprint is broken **both** ways — USD≡cent, `long` collisions, declaration order |
| **`ORDER-1267`** | S11 | the leak scanner reports CLEAN on a formatted account **and on having no recognizer at all** |
| **`ORDER-1268`** 🔴 | S6·S10 | **nothing refuses a partial `.set` entering a run**, and the check that claims to is a non-emptiness test |

**Verification status is marked per item inside every audit file.** Part 1 = re-measured by the audit
lane, with a control where one was possible. Part 2 = Codex's claim, not re-measured, and the file
says why. **Do not promote a Part 2 item by fixing it** — measure it first, or you are repairing
something nobody has shown to be broken.

---

## §B — The handover list this lane INHERITED and did not work

Carried verbatim from `_triage/PROMPT_NEXT_SESSION_AUDIT.md` §C. These come from the earlier Codex
A+B audit (`CODEX_AUDIT_A_B_2026-08-03.md`) and are still owed:

1. **Correct the carried-loss claim in all six places.** The tester books a force-closed position as
   a closed deal, so it **is** inside `gross_loss` and inside PF. Rewrite as *concentration*, not
   *concealment*. Places: `pilot_carried.py` docstring · `pilot_cells.ps1` header/notes/footer · the
   `ORDER-1230` board row §4 · `PROMPT_NEXT_SESSION_S13C.md`.
2. **Fix `_rollup_main()`** so a case failing its direction or anchor check cannot feed the roll-up,
   and make `--rollup` enforce the lane/symbol/window/model equality only `main()` checks today.
   **Ship the cage case first** — `run_parity_tests.py` calls `rollup()` directly and never
   `_rollup_main()`, which is why it was invisible.
3. **Either implement the three missing §8.4 parity cases or stop claiming §8.6 item 3.**
4. **Make financing real or rename the field.** `financing_deducted.applied: true` while `net_profit`
   is unchanged is a field that lies. On BTCUSD H1 the deduction flips the sign.
5. **Check `ExitMode=22` + `_2_SuppressLegTP=false`.** If per-leg broker TPs were live, the pilot
   measured a hybrid architecture and several narrative claims need rewriting.
6. **Record the second falsifier limb as unmeasured.** *"worst-case single loss > 15 % equity at real
   sizing"* was never measured, so most cells are `NOT EVALUABLE`, not "met"/"not met".

---

## §C — The 13C audit: what is auditable and what does not exist yet

The audit prompt named *"the parity result manifest first, because §8.6 items 3–4 will be resting on
it"*. **Measured today, and the answer is that it is not built:**

```
ORDER-1255 (the manifest) = OPEN
git diff a87f7448..HEAD -- _triage/factory_os/parity.py factory/parity/   -> empty
```

`ORDER-1255`'s own body states the obstacle: `factory/parity/*/wrapper.json` name their reports under
`_mt5_auto/reports/`, which `.gitignore:70` ignores, so the committed manifests point at files not in
the repo and `--rollup` reproduces only on the machine that ran it. **There is nothing to audit until
that is designed.** Not deferred for collision reasons — it does not exist.

**What of 13C IS auditable, and is unchanged since the pin `a87f7448`** (measured: `git diff` empty on
all three): `factory/coverage.jsonl` (the 16 registered cells) · `_triage/factory_os/schemas.json`
(the `MetricRef` nullable-`pf` + required `pf_state` change) · `gen_pilot_cells.py`.

⚠️ One 13C gap was **already found by the S13D lane itself**, so do not re-commission it:
`ORDER-1272` — `gen_pilot_cells.py --check` is the only thing standing between the coverage store and
a hand edit, **and nothing runs it**.

---

## §D — S2 was audited TWICE, and the second read is in Part 5 of its file

All seven slices are audited; `CODEX_AUDIT_S2_2026-08-03.md` exists and **Part 5 is not optional
reading** — the first dispatch produced an independent report containing **two findings the second
does not**, both verified:

- the **strongest reproducer of `ORDER-1263` produced all day**: an `authorization_ref` whose `path`
  is `VISION.md`, whose `blob_oid` is `PROJECT_STATE.md`'s, and whose `raw_sha256` is unrelated,
  accepted on a `CANDIDATE_ASSIGNED`. Use that as the regression case, not a filler-oid one.
- `check_attested_pin_staged.pinned_expectations()` pins **only** from `expected_post_state`, so the
  front guard **had no pin for `factory/coverage.jsonl`** when the 16 rows landed → `ORDER-1269` #4.

⚠️ **And a correction that matters to how you read this handoff.** I originally wrote that the first
S2 run *"stalled at 51 tool calls without ever producing a report"*. **It had not stalled — it was
slow.** It was idle for over a minute, my size-based poller called that finished, I abandoned it, and
it resumed and completed at 1.21 MB. The re-dispatch was unnecessary; it was also lucky, because two
independent reads of the same slice is worth more than one.

**Use `scratchpad/collect_codex.py` and note what it now does:** a run is finished when the
transcript carries a `task_complete` payload, **not** when the file stops growing. `last` REFUSES a
transcript without one. The lesson survives the correction intact — **size was the wrong signal
either way**; what changed is that the failure it caused was a *premature abandonment*, not a lost
result.

---

## Standing rules that did not change

- 🚫 No EA verdict from automation — design §10 stops S13 at `EVIDENCE_COMPLETE`.
- 🚫 Do not raise `$FullTierBudgetSeconds` (pinned 120.0s).
- 🚫 Do not edit a cage to make its own FAIL go away. **See §0.1 — this is the session where that
  temptation actually arrives.**
- 🚫 `MASTER_BACKLOG.md` §2 outside an owner-approved `gen_coverage --apply` · `AGENTS.md` ·
  `PROJECT_STATE.md` · any `.set` migration · any magic allocate/renumber/retire.
- **Reserve your order block and commit the reservation before using a number.** Re-derive from BOTH
  tests: every `## ORDER-<n>` across all four board files **and** every reserved block in the ledger.
  As of this lane's close the highest in use is **`ORDER-1272`** and blocks through **1279** are
  taken — **derive it yourself rather than trusting that sentence.**
- **A criterion is committed in its own commit, before the run that resolves it.**

Open with: **"`_triage/PROMPT_NEXT_SESSION_CORRECTIONS.md` ทำต่อเลย — เริ่มที่ ORDER-1264 แล้ว 1263"**
