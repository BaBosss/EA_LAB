# Core Seat Protocol v8 — owner-ratified 2026-11-02

**Status:** owner-ratified governance text. It does **not** change the routing in `AGENTS.md` §1.1/§1.5 (A9 is
only a proposal) and it does not activate any runtime.

**Ratification:**
- **Owner's words (Thai, verbatim):** "งั้น อนุมัติ v8 เลย จะได้ไม่เสียเวลาทำไปเลย ค่อยให้ v8 ให้ codex review
  แล้วแก้ทีหลัง"
- **Meaning:** approve v8 now; Codex reviews it later, and any fixes follow as an amendment.
- **Custody copy:** `D:\EA_LAB_PRESERVE\20261102_protocol\CORE_SEAT_PROTOCOL_v8_OWNER_RATIFIED_20261102.md`,
  SHA-256 `a6035ecf2a2cce68f93765945334a8c39a77ac1a8c313ffc4ce63e58f521b733`.
- **The ratified text below is byte-identical to that custody copy.**

**Review trail:**

| Draft | Reviewer | Verdict |
|---|---|---|
| v1, v4 | ChatGPT | REVISE |
| v5, v6 | Codex | REVISE |
| v5, v7 | ChatGPT | ACCEPT WITH NAMED FIXES; the v7 review states it is "not a Codex verdict" |
| v8 | Codex | not yet reviewed; deferred by the owner |

**Covered by this ratification:**
- the protocol text;
- the A7 interim rule: the stricter canonical gate stays in force, including `docs/PIPELINE.md` rows 3 and 9;
- the A8.7 RED scope and its clearance criteria.

**Still separate owner decisions:**
- A9 routing;
- A10.5 replay scope;
- A10.9 runtime activation;
- the A8.8 watchdog host;
- A11, unpausing `ea-lab-agy`;
- any in-EA allowlist;
- any reset or clean of the primary checkout.

## Quick card (summary only — where it differs, the ratified text below wins)
1. **Boot** (as `START_HERE.md` §1):
   - start from `origin/master`;
   - with no named assignment and valid lease you are `ROLE_UNVERIFIED_READ_ONLY`.
2. **Unit of work:**
   - the owner assigns;
   - the author works in its own worktree under a lease;
   - a reviewer who is not the author freezes the exact SHA;
   - the Seat integrates;
   - runtime and real money need separate acceptance, and the owner decides.
3. **Report** five dimensions (execution, evidence, acceptance, integration, runtime). Any can be `UNKNOWN`
   or `NOT_APPLICABLE`.
4. **Quota loss:**
   - the agent that stops commits only if its contract and gates allow, and otherwise preserves its WIP;
   - a successor may read first;
   - before writing, the successor proves the source SHA, the contract and lease, that no in-flight job is on
     the same slice, and the accepted evidence it relies on (A4a);
   - a HANDOFF file is information, not permission.
5. **Batch resume:** automatic resume is unavailable on canonical until R4 is integrated. A new state directory
   bypasses nothing.
6. **Money:**
   - REAL attach needs an `ACCOUNTS.csv` row, a `DEPLOYMENTS.csv` row with hashes, and owner approval;
   - an unknown magic, unknown account, stale feed, unregistered exposure or overdue judge is RED;
   - RED freezes new approvals, acknowledgement does not clear it, and nothing auto-closes.

## Amendment 1 (2026-11-02) - Codex v8 review finding F1

This amendment supersedes the bundled ratification wording in A10.4. The 2026-11-02 ratification covers the protocol text, the A7 interim stricter-gate rule, and the A8.7 RED scope and clearance criteria. A9 remains an unapproved proposal. Migration that preserves current routing does not require A9 approval; all applicable reconciliation, pilot, replay-scope and acceptance gates remain mandatory.

Review record for v8 (Codex, GPT-6, read-only): protocol text ACCEPT WITH NAMED FIXES (F1 above); canonical commit `94badcc9` ACCEPT; local entry banners REVISE, then revised per F2-F5 and left uncommitted on local master. Review copies with SHA-256 manifest: `D:\EA_LAB_PRESERVE\20261102_protocol\` (`CODEX_V8_REVIEW_VERBATIM.md`, `CHATGPT_V7_REVIEW_VERBATIM.md`).

---

## Ratified text (verbatim)

# EA_LAB One-System Operating Protocol — DRAFT v8, final ratification text (not committed)

> **v8 = v7 plus five text fixes from the ChatGPT review of v7** (verdict: ACCEPT WITH NAMED FIXES; the review
> says it is "not a Codex verdict"). Only A4, A6, A7, A8.7 and A10.0 changed. The exact delta is in Part D, and
> everything else is v7 text, unchanged. No new mechanism or field is added.

> **Review history (corrected in v7 — v6 misstated it):**
>
> | Draft | Reviewer | Verdict | What it asked for |
> |---|---|---|---|
> | v1 | ChatGPT | REVISE | C1–C2, H3–H5, M6 → v3 |
> | v4 | ChatGPT | REVISE | F1–F7 → v5 |
> | v5 | **Codex** | **REVISE** | six findings X1–X6 (Part B3) |
> | v5 | ChatGPT | ACCEPT WITH NAMED FIXES | six named fixes + Q7 → v6 |
> | v6 | **Codex** | **REVISE** | P1 ×3, P2 ×3, four wording items (Part C) |
>
> v6 called the ChatGPT review "the final review" and listed only its six fixes. The owner pasted the same
> ChatGPT text under both the "Codex" and the "GPT" headings, so Codex's own v5 findings were never
> applied. v7 applies **both** Codex reviews (v5 and v6). Part C maps every finding to the v7 text and says
> plainly which are fixed, which are partial, and what remains for runtime.
>
> Author: Claude, draft author only. Nothing here changes authority: `origin/master`, `AGENTS.md`, the Lane
> Registry state machine, owner hard stops and the VERDICT GATE keep their current owners and text.

---------------------------------------------------------------------------------------------------
## PART A — PROTOCOL TEXT

### A0. Facts
- Divergence: local `bc5ba5cd` is 70 ahead of and 1,017 behind `origin/master` `82d049e4`.
- Commit subject tags since 6ae8a5f1:
  - local: `[codex]` 34, `[claude]` 18, `[agy]` 14;
  - origin: `[chatgpt]` 586, `[codex]` 203.
- **Tags do not identify the tool or model.** For example, `ORDER-1685.md:3` names the AGY lead as
  "Claude Sonnet5.5Medium" running inside Antigravity.
- Four different "current" revisions exist:
  - primary `bc5ba5cd`;
  - origin `82d049e4`;
  - DailyMonitor runtime `cb57c666`;
  - MCP snapshot `fee98333` (STALE_BY_AGE).
- `factory/work_receipts.jsonl` holds only a header line. Durable-job, Registry and review receipts are kept separately.
- R4 is `ACCEPTED_OFFLINE` only.
- Latest snapshot of 159503454, server time 2026-11-02 02:01:55:
  - shows no exposure from 20101–20105;
  - the owner reports removing those EAs; their attach state has not been verified.
- The Codex heartbeat automation `ea-lab-agy`:
  - is `PAUSED`, runs every 30 minutes when enabled;
  - is bound to one Codex thread (`target_thread_id`) and, by its prompt, to `ORDER-1685`.

### A1. Principle, transfers, and continuations
Roles belong to functions: `Seat`, `Author`, `Reviewer`, `Batch Runner` and `Owner`, and the owner assigns
them. Each of the three **transfers** below is a separate act. Each needs its own owner instruction naming its
scope, and none implies another.

| Transfer | What moves | What does not move |
|---|---|---|
| Seat rotation | coordination + integration authority | any running job, author lease, or reviewer identity |
| Author reassignment (precedent `ORDER-1685`) | the remaining scope of one contract | the Seat, or the review of code that author already wrote |
| Reviewer substitution (precedent R4: GPT-6 for quota-exhausted Codex) | one review of one frozen head | the original reviewer's verdict record (`CODEX_REVIEW.md` untouched) |

A **continuation** is not a transfer, and its four kinds are different acts. The table below describes the
mechanisms that already exist; nothing new is built.

| Continuation | What it is | Existing behaviour (OBSERVED) | New owner instruction? |
|---|---|---|---|
| Desktop conversation continuation | the same agent resumes its own interrupted work in its own session | no durable job identity; only the session itself | no, inside the same approved contract, scope and role; the A4 checks still apply |
| Long Job intake | reading what a prior Long Job left behind | `resume_work.py` is read-only: "never starts/retries a job, writes canonical state, or grants authority" | no (it is a read) |
| Successor attempt | a **new** attempt at the same contract after the prior one is reconciled | `start_long_job.ps1:52` refuses an existing job ID, so a successor is a new job ID; the prior record stays untouched | no, inside the same approved contract, scope and role, **after** A4 reconciliation |
| Batch-state resume | `run_batch.ps1` continuing an existing state directory | gated only at local `bc5ba5cd` (A4) | **unavailable on canonical** until R4 is integrated |

A role change, a scope change, or anything that touches an owner hard stop needs a new owner instruction.

Seat rotation also follows `AGENTS.md:11`:
- an explicit owner instruction;
- a serialized handoff;
- a Registry check;
- a rotation receipt in `SEAT_LOG.md`.

If the state is unknown, the agent stays `ROLE_UNVERIFIED_READ_ONLY`.

### A2. Workspaces
- `origin/master` is the only integration line, and only the Seat integrates.
- **Target state:** every writer works in a registered worktree cut from origin.
- **The cutover waits until the worktree compatibility pilot (A10 step 6) passes.**
  - Until then the primary checkout keeps its current role and stays the only status publisher.
  - The reason is that `make_status.ps1:15-20,134-140` allows OneDrive publication only from `D:\EA_LAB`.
- No MT5 tester or runtime change happens during the governance migration.

### A3. Lanes — no state-machine or schema change
- The Lane Registry is the lane system for new work. Its existing states and transitions are unchanged:
  `READY, RUNNING, WAITING, PAUSED, REVIEW, FROZEN, INTEGRATING, DONE, BLOCKED` (`lane_registry.ps1`).
- **Phase 1 adds zero fields.** The lane's existing task contract and evidence path point to the handoff
  artifact.
- Optional `handoff_ref` and `handoff_sha256` fields come later, and only after:
  - schema, transition and publisher compatibility tests;
  - owner approval;
  - independent review.
- `docs/SESSION_LEDGER.md` is frozen for new work **only after** all of these are reconciled:
  - its active contracts;
  - owned paths;
  - tester reservations;
  - local-only commits;
  - staged artifacts.
- The ledger has about 111 `ACTIVE` mentions and documents its own stale blocks, so declaring it frozen is not enough.
- Historical contracts stay intact until each one is reconciled.

### A4. Interruption, quota loss, resume
- **A handoff file is information, not authorization.** A chat thread, a Registry state, a process record and
  a handoff file are four separate observations.
- **Read-only discovery and intake may precede execution identity reconciliation.** The full A4 preconditions
  apply before any state-changing continuation, successor attempt, new dispatch, or reassignment. Read-only
  inspection alone never grants execution or write authority.
- Before any state-changing continuation (A1), successor attempt, new dispatch or reassignment, confirm all of the
  following:
  - exact execution identity;
  - liveness of the original process/session;
  - the current lease;
  - source and artifact hashes;
  - the outcome of the prior attempt;
  - current authorization;
  - that the continuation does not duplicate running work.
- **Resume protection is a property of an exact source SHA, not of a script name.**
  - **Codex CLI Long Jobs:** durable job identity, and an intake adapter that reads the prior attempt and never
    retries (OBSERVED).
  - **`run_batch.ps1` at local `bc5ba5cd` (913 lines)** has these R4 resume gates: `IDENTITY_MISMATCH`, artifact
    mismatch/missing, `UNVERIFIED`, orphan `running`.
  - **Canonical `origin/master` (489 lines) lacks those R4 resume gates.**
  - **Until the reviewed R4 protections are integrated, automatic batch resume is unavailable.**
    - Any continuation or fresh attempt first requires reconciliation of the prior attempt and explicit coverage
      by the existing execution contract.
    - Starting with a new state directory does not bypass these checks. It does not prove that the old process
      stopped, it does not prevent duplicate work, and it grants no additional execution budget.
  - No new mechanism is written; R4 integration (A10) is the path.
- **Recovery after a lost session:**
  - recovery starts from the last durable receipt that actually exists;
  - a successor may write **its own recovery observation**: what it observed, where, when, at which SHA;
  - that observation may never be presented as the original agent's handoff or attestation.
- Anything unknown fails closed to read-only.
- **An agent that is stopping:**
  - commits only when the existing contract and its required gates permit (for example, `ORDER-1685:14`
    requires cages, a fresh compile and a full `tpl_regression` CLEAN before a core commit);
  - otherwise preserves its WIP, index state and available evidence, without forcing a commit;
  - pushes a lane branch only if its contract permits;
  - never pushes canonical.

### A4a. Admission boundary (mandatory before A10 clean replay, workflow cutover, or any new actor)
Before a new actor takes a task or edits source, including a replayed local item, these four facts are proven
and recorded in the lane's evidence:
1. the exact source identity: canonical SHA, local SHA if replaying, and file SHA-256 for the slice;
2. the existing contract and lease that cover it, or proof that none exist;
3. the state of any in-flight job or session on the same slice (A4 liveness);
4. which accepted evidence the work rests on, and the scope of that acceptance (for example, R4 =
   `ACCEPTED_OFFLINE` only).

**Rules that follow:**
- If any item is missing, there is no admission (`ROLE_UNVERIFIED_READ_ONLY`).
- **Proving that no contract or lease exists permits discovery only; it does not authorize source mutation.**
- **Write admission requires an authorized assignment and an applicable valid lease.**
- A governance-authority change takes effect only after owner ratification. Admission never substitutes for it.

### A5. Completion is reported in dimensions (presentation only)
Every board row, report and handoff states each dimension with an evidence path. **Every dimension also
accepts `UNKNOWN` (not yet observed) and `NOT_APPLICABLE` (does not apply to this unit).** An empty cell is
never read as a value.

| Dimension | Values (existing vocabulary) + `UNKNOWN` · `NOT_APPLICABLE` |
|---|---|
| Execution | COMPLETE · FAILED · INTERRUPTED (`EXECUTION_COMPLETE_UNACCEPTED` = COMPLETE + acceptance pending) |
| Source/Evidence | READY (`SOURCE_READY_NOT_ACCEPTED`) · INCOMPLETE · UNVERIFIED |
| Acceptance | PENDING · ACCEPTED_OFFLINE · SCRUTINY_FAIL (the scope is always stated) |
| Canonical integration | NOT_INTEGRATED · INTEGRATED |
| Runtime | NOT_ACTIVATED · VERIFIED_ACTIVE · FAILED |

**The original verdict is preserved.** A later review, reviewer substitution, re-run or successor attempt adds a
**new** record that references the earlier one. It never edits or replaces the earlier verdict. Precedent: the R4
substitute review is "not a Codex verdict" and `CODEX_REVIEW.md` stays untouched.

These dimensions are not a state machine, and no stage implies the next. Registry `DONE` is a lane
disposition, not runtime activation. The strategy lifecycle (`BUILD-ON … LIVE`) stays in the VERDICT GATE and
is never merged with this table.

### A6. Evidence: classified per artifact, by acceptance and custody, not by location or vendor

| Class | What | Custody rule |
|---|---|---|
| Canonical | decisions, rules, verdicts, accepted manifests, rotation receipts | git `origin/master` |
| Accepted external evidence | durable-job results, independent review receipts, native tester output, deal exports, snapshots | Preserved at authorized, stable custody paths and immutable once cited. The applicable canonical owner manifests reference each file with an exact SHA-256 binding, and the raw bytes need not be in git. `START_HERE.md` routes readers to the canonical owners; it is not itself a universal evidence manifest. |
| Cited, not yet in custody | any artifact that a contract, receipt, review or acceptance cites, wherever it lives today: TEMP, AGY `brain/`, a ChatGPT chat, a Codex rollout, Claude memory | Copied to a named store and hashed, or declared irrecoverable. Its evidential weight is whatever the citing record gave it, no more. |
| Scratch | uncited vendor-private material, uncommitted edits, unaccepted notes | no authority |

**Classification is per artifact.** A whole store is never classified at once. A chat, a rollout or an AGY report
is scratch only while nothing cites it. Once it is cited, it is "cited, not yet in custody" until it has been
copied and hashed.

**%TEMP% is never custody.** Three facts show why:
- `ORDER-1685.md` names a TEMP file as its controlling handoff.
- 22 local docs cite TEMP paths.
- Cited TEMP evidence has already been lost.

**The following recovered evidence is preserved** (owner-approved, 2026-11-02) in
`D:\EA_LAB_PRESERVE\20261102_temp_evidence\`:
- **Cited pass.** Local docs cite 140 TEMP paths.
  - 47 still existed and were copied: `_MANIFEST_SHA256.txt`, 1,526 files, re-verified by the reviewer.
  - 93 were already gone: `_gone_temp_paths.txt`.
- **Uncited pass.** 55 EA_LAB, GPT-6 and R4 TEMP items modified since 2026-10-01 were copied to `uncited/`.
  - `_MANIFEST_SHA256_uncited.txt` lists 475 files; the reviewer verified 475/475.
  - `_SELECTION_uncited.tsv` lists the 55 selected items, with manifest and on-disk file counts for each.
  - 49 of the 55 items contain files. The other 6 are directories that were already empty at the source:
    `EA_LAB_GPT6_BINARY19_*`, `EA_LAB_GPT6_INDEP_42_*`, `EA_LAB_GPT6_OPT26_*`, `EA_LAB_GPT6_PARSER23_*`,
    and two `ea-lab-order1667-legacy-evidence-*` directories.
- **Not recovered:** the cited raw receipts that were gone before preservation, including the one the reviewer
  calls F01. Those artifacts are irrecoverable unless another copy turns up.
- **This is custody only.** Copying an item does not make it accepted.

### A7. Review independence
- Independence follows **exact source provenance**, not vendor label or original role. This is the procedural
  independence of `AGENTS.md` §1.5.
- A former author may review a different author's change only if all three hold:
  - a source-slice provenance check has been done;
  - the review scope is frozen separately;
  - the reviewer does not approve code it authored.
- The receipt records the actual tool and model, because commit tags do not identify them.
- ⚑ **Conflict for the owner** (v8: the conflict is also inside canonical, not only between lineages):
  - `ORDER-1685.md` on the local lineage says "Different-family review remains mandatory";
  - origin `AGENTS.md` §1.5 defines independence as procedural;
  - **origin `docs/PIPELINE.md:46,52`** still requires "different-family review for high-risk code" (boundary 3)
    and an "independent different-family review" for demo → live (boundary 9).
  - **Rule until resolved:** origin `AGENTS.md` defines independence as procedural and evidentiary, while the
    current canonical `docs/PIPELINE.md` still contains explicit different-family review gates for specified
    high-risk and DEMO-to-LIVE transitions. Until the Owner ratifies and the canonical owners reconcile these
    provisions, every applicable stricter task-specific or pipeline gate remains in force. No prior acceptance is
    retroactively weakened.

### A8. Money safety
**Ownership of records (existing; `PROJECT_STATE.md:306,308`):**
- `portfolio/DEPLOYMENTS.csv` is the deployment inventory: account / EA / magic / status / kill / judge.
- `portfolio/ACCOUNTS.csv` holds account-level governance, sensor and SLA metadata.
- A8 reads both and creates no third registry.

1. **Pre-attach gate:**
   - nothing is attached to a REAL account without all three of:
     - an `ACCOUNTS.csv` row for the account;
     - a `DEPLOYMENTS.csv` row with account, magic, symbol, and `.ex5`/`.set` SHA-256;
     - owner approval;
   - at attach time, proof that the chart runs that binary and that set;
   - ⚑ an in-EA identity stamp or allowlist is risk/runtime logic and needs owner approval.
2. **Account coverage (`ACCOUNTS.csv`):**
   - every account that appears in any snapshot or deal export maps to an `ACCOUNTS.csv` row;
   - a REAL account with no row is RED.
3. **Magic coverage (`DEPLOYMENTS.csv`):**
   - any magic in a REAL account's whole deal history is RED unless it is registered for that account or covered
     by an authorized exception;
   - there is no rolling window.
4. **Feed coverage (`ACCOUNTS.csv` sensor/SLA):**
   - each covered account's export and snapshot is fresher than its SLA, one day by default;
   - this check is separate from last-deal age.
5. **Exposure (`DEPLOYMENTS.csv`):** open positions and pending orders are reconciled per account and per magic.
6. **Judges (`DEPLOYMENTS.csv`):** `ACTIVE` rows past their judge date without a recorded judgment are RED.
7. **RED scope and clearance:**
   - **Account-attributable RED** freezes new deployment approvals only for the affected accounts.
   - **A monitoring failure** that prevents reliable attribution or portfolio-wide coverage (for example a missing
     heartbeat or an unreadable feed) freezes new deployment approvals across all REAL accounts, subject to
     explicit Owner ratification (⚑).
   - **Clearance requires all four of:**
     - restored and independently verified coverage;
     - fresh evidence;
     - a recorded incident disposition;
     - the applicable Owner authorization.
   - Acknowledgement alone does not clear RED.
8. **Delivery and external watchdog:**
   - one line reaches the owner every day, including OK days;
   - a missing day is an incident;
   - **the freshness check runs in a different failure domain from the dev machine**, because a second task on
     the same machine dies with it:
     - the machine publishes a heartbeat (time, source SHA, RED/OK) to a location reachable from outside;
     - an external checker alerts the owner when the heartbeat is stale;
     - the checker can be a cloud-scheduled job, or a task on the VPS (already a separate machine);
     - ⚑ the owner chooses the host and channel.
   - Today `EA_LAB_MonitorV31_Refresh` returns 0 while `EA_LAB_DailyMonitor` returns 1, and the success marker
     is dated 2026-07-31. A same-machine success did not reveal the failure.
9. **Response:**
   - an incident acknowledgement records that the owner saw the incident;
   - an authorized exception records what the owner allows, with its scope and expiry;
   - the two are separate records;
   - nothing is closed automatically.
10. **Status:**
    - this section may be described as working only after a test proves coverage and alert delivery;
    - fixture: the real 991901 timeline must raise RED on 10-19;
    - until then every A8 item is DOCUMENTED_ONLY.

### A9. Routing — proposed, not in force
Current canonical routing (Gemini-first, `AGENTS.md:28-37,108-113`) stays in force. The v4 §8 table becomes a
**proposal for owner ratification**. Each row needs a capability proof before it takes effect:
- Codex as code reviewer — evidence: the R1–R3 defect findings;
- Claude Code for EA-evidence review — needs an availability proof;
- Qwen for batch runs — needs a current capacity proof.

### A10. Migration — staged, nothing destructive, nothing pushed in bulk
0. **Now:**
   - **Before ratification, apply only existing canonical write-admission and preservation rules.** Do not admit
     new unreconciled or conflicting writes to the primary checkout. Existing authorized contracts and the status
     publisher (`make_status.ps1`, A2) retain their current rights. (AGY already stopped on 2026-11-01 by owner
     instruction.)
   - Any new general prohibition on primary-checkout writing takes effect only through an explicit Owner-approved
     governance change, after active ownership and execution reconciliation (step 3).
   - Open incident records for 991901 and 20101–20105.
   - Verify the attach state on the VPS.
1. **Preserve (local only, no push):**
   - make a `git bundle` of `master`, which keeps the history;
   - archive the untracked and dirty paths with a SHA-256 manifest, stored outside `D:\EA_LAB`;
   - leave the staged Hermes index (29 entries) untouched.
2. **Inventory → classify → scan:**
   - classify each preserved artifact (A6, per artifact) as keep, historical or discard-candidate;
   - flag the Boss number collisions: origin already has Boss_20 GoldTimeBomb, Boss_21 GridFibo and Boss_22
     WickDisplacement, while local has different Boss_20/21/22;
   - scan for secrets/PII and enforce size limits.
3. **Reconcile active contracts** before anything is replayed.
   - **Scope:** the SESSION_LEDGER reservations 1660–1669 and 1680–1689, and the AGY successor block 1700–1709 (A3).
   - **Check each one, one by one, for:**
     - order ownership;
     - tester leases;
     - session identity;
     - source slices;
     - the staged Hermes index;
     - handoff and review receipts.
   - Counting `ACTIVE` words is not reconciliation.
   - A7 conflicts are ruled case by case here.
4. ⚑ **Owner ratifies** this protocol text, the A7 conflict rule, the A8.7 RED scope and the A9 routing. No
   governance-authority change (role table, lane-system freeze, adapter rewrite) takes effect before this.
5. ⚑ **Owner approves the scope** of what is replayed.
6. **Worktree compatibility pilot (offline):**
   - check hooks, git config, tool paths, MT5 DataDir/terminal binding, tester lane lock, binary identity and the
     status publisher;
   - **the pilot decides** whether the existing publisher works from a worktree as it is, needs a repair, or
     needs a replacement;
   - no writer leaves the primary checkout until the publisher works for the chosen layout.
7. **Clean replay through the A4a admission boundary:**
   - each approved item goes into a lane worktree from origin as a normal contract;
   - R4 integration is one such lane, with dependency reconciliation;
   - each lane passes its own acceptance gate, because protocol ratification does not accept any of them.
8. **Reviewed governance cutover:**
   - writers move to worktrees;
   - SESSION_LEDGER is frozen (A3 conditions);
   - adapters shrink;
   - **archiving is per artifact**: an artifact (an AGY report included) is archived only after the references to
     it are moved and its acceptance bindings are preserved, with no blanket "historical" label for a whole group.
9. **Money-safety runtime activation (A8)**, as its own hard stop:
   - implement;
   - test with the fixture;
   - independent review;
   - integrate;
   - ⚑ scheduled-task change, with rollback;
   - ⚑ external watchdog host.

**Not waiting for ratification:**
- steps 0–2, as read-only inspection or preservation;
- work under contracts that are already approved, which proceeds under its own gates (A10.0).

Creating an archive or bundle, or writing an incident record, still needs authority under an existing contract or
an owner instruction. This list does not authorize every step 0–2 action automatically.

Step 9 does not depend on steps 6–8 and may run as soon as its own contract is approved.

The primary checkout is never reset or cleaned without a separate owner instruction (owner-reserved).

### A11. The heartbeat automation `ea-lab-agy`
- **State:** it stays `PAUSED`. It is already bound to one Codex thread and, by its prompt, to `ORDER-1685`.
- **Before unpausing:**
  - its binding is re-checked against the current lane and contract (A4a);
  - ⚑ the owner instructs the unpause.
- **Running is not reviewing:**
  - following new deliveries over time is allowed;
  - any **review** it performs freezes the exact candidate (SHA + artifacts) at review time;
  - it does not need to pin one HEAD for its whole lifetime.

---------------------------------------------------------------------------------------------------
## PART B — DISPOSITION MATRIX (earlier rounds)

**How to read this matrix.** Every item below was **AGREED**. "Agreed" does not mean "done": later Codex
reviews showed that some were only partly implemented. The current status of each item is in Part C. No reviewer
has closed every finding.

### B1. Corrections A–F (ChatGPT, on the Codex workflow vs v3)
| # | Correction | Ruling | Where in v7 |
|---|---|---|---|
| A | Seat transfer ≠ worker transfer | AGREED | A1 |
| B | Preserve local-only work, no second authority | AGREED | A3, A10.1–5 |
| C | Quota loss / interrupted sessions fail closed | AGREED | A4 (protection is per exact SHA) |
| D | Evidence by acceptance + custody | AGREED | A6 |
| E | Independence follows source authorship | AGREED, ⚑ owner decision | A7 |
| F | Separate completion states, no second registry | AGREED | A5 |

### B2. ChatGPT v4 review, F1–F7
| # | Finding | Ruling | Where in v7 |
|---|---|---|---|
| F1 | Rescue push risks loss or leak | AGREED | A10.1–7 |
| F2 | `ACTIVE` is not a valid state | AGREED, verified | A3 |
| F3 | Handoff depends on capabilities lost with quota | AGREED | A4 |
| F4 | A linear ladder is wrong | AGREED | A5 |
| F5 | Worktree cutover without compatibility proof | AGREED, verified | A2, A10.6 |
| F6 | Money-safety blind spots | AGREED | A8 |
| F7 | Routing defaults conflict with canonical | AGREED | A9 |
| Fact 1 | `[chatgpt]` 586, not 583 | AGREED, verified (BOM-prefixed subjects) | A0 |
| Fact 6 | A snapshot is not proof of detach | AGREED | A0, A10.0 |

### B3. Codex v5 review, X1–X6 (missed by v6; applied in v7)
| # | Finding | Ruling | Where in v7 |
|---|---|---|---|
| X1 | Migration ordering | AGREED | A10 order (v6), plus the freeze scope (v7) |
| X2 | Transfer and resume semantics | AGREED, verified (`resume_work.py`, `start_long_job.ps1:52`) | A1 continuation table, A4 |
| X3 | The stopping agent was forced to commit | AGREED, verified (`ORDER-1685:14`) | A4 stopping rule |
| X4 | Account ownership / RED scope | AGREED, verified (`PROJECT_STATE.md:306,308`) | A8 ownership, A8.2–7 |
| X5 | Completion dimensions lack UNKNOWN/N-A and verdict preservation | AGREED | A5 |
| X6 | Evidence classification / archive was done by group | AGREED | A6 per-artifact rule, A10.8 |

### B4. Codex-specific risks the reviews did not name (v7 correction to B3.3 of v6)
1. **TEMP as custody.** The `ORDER-1685` controlling handoff lived only in TEMP. It is now preserved (A6).
2. **Same-checkout concurrent writers.** The Codex Desktop → AGY handoff happened inside one primary checkout
   that both agents wrote, and path-limited commits do not protect shared files (`SESSION_LEDGER.md:19`).
   → A2, A10.0.
3. **Heartbeat automation.** v6 called it "unbound"; that was wrong. It is `PAUSED` and bound to one thread and
   to `ORDER-1685`. The real risk is unpausing it against a lane or contract that has since changed. → A11.
4. **Tag-based identity.** `[claude]` on local master includes Claude models run inside Antigravity, so an
   independence check based on tags would be wrong. → A7.

### B5. Owner approvals and hard stops implicated (v7 numbering)
- A7: the independence-rule conflict.
- A8.1: any in-EA allowlist or identity stamp (risk logic).
- A8.7: the RED scope.
- A8.8: the external watchdog host and channel.
- A9: routing changes.
- A10.4: protocol ratification.
- A10.5: the replay scope.
- A10.9: the scheduled-task change (a runtime hard stop, with rollback).
- A11: unpausing `ea-lab-agy`.
- Any reset or clean of the primary checkout (owner-reserved).

DEMO, LIVE and real-money decisions are unchanged.

---------------------------------------------------------------------------------------------------
## PART C — DELTA MATRIX v6 → v7 (Codex v6 review: REVISE)

### C1. Blocking findings
| # | Sev | Finding | Fix in v7 | Status |
|---|---|---|---|---|
| 1 | P1 | A10.0 froze the primary checkout while A10 let existing contracts continue there | A10.0 now stops **new unreconciled write work** only. Existing approved contracts and the publisher continue under their own gates, and stopping one requires step 3 reconciliation. | FIXED (text) |
| 2 | P1 | A4 offered "re-run from scratch" as a way around identity protection | Codex's wording adopted verbatim: automatic batch resume is unavailable until R4 is integrated, and a new state directory bypasses nothing. "Has no identity protection" became "lacks the R4 resume gates". | FIXED (text) |
| 3 | P1 | A4 forced the stopping agent to commit | Commit only when the contract and its gates permit (`ORDER-1685:14`); otherwise preserve WIP, index state and evidence. A successor may write its own recovery observation with provenance. | FIXED (text) |
| 4 | P2 | A1 called a Long Job continuation "the same attempt" | A1 continuation table separates conversation continuation, Long Job intake (read-only), successor attempt (new job ID) and batch-state resume (unavailable on canonical) | FIXED (text), verified against `resume_work.py` and `start_long_job.ps1:52` |
| 5 | P2 | X4, X5 and X6 were still open | A8 ownership split and RED scope; A5 adds UNKNOWN/N-A and verdict preservation; A6 and A10.8 work per artifact | FIXED (text); RED scope ⚑ owner |
| 6 | P2 | A4a allowed "no lease exists" to look like write permission | A4a adds the discovery-only rule, and write admission requires an assignment plus a valid lease | FIXED (text) |

### C2. Wording items
| Item | Fix in v7 |
|---|---|
| "Everything is in …" overstated custody | A6 now reads "the following recovered evidence is preserved", and the unrecovered raw receipts (incl. F01) are named as not recovered. |
| The heartbeat was not unbound | A0, A11 and B4.3 corrected: PAUSED and bound; follow-up tracking and review freezing are separate steps. |
| A publisher replacement was presumed | A10.6: the pilot decides between reuse, repair and replacement. |
| "Nothing is disputed" implied every finding was closed | Removed. Part B states that "agreed" ≠ "done", and Part C carries the status. |
| The count of 55 could not be checked from the manifest alone | `_SELECTION_uncited.tsv` (SHA-256 `dd375fd9…0c5c41`) lists all 55 items: 49 with files, totalling 475, plus 6 directories that were already empty at the source (checked against the TEMP originals). |
| The review history was misstated | Corrected in the header table. |

### C3. What v7 does **not** claim
- **Runtime:** nothing in A8 is working. It is all DOCUMENTED_ONLY until the A8.10 fixture and alert-delivery
  test pass.
- **The watchdog:** the separate failure domain is design only. Neither the host nor alert delivery has been proven.
- **Evidence custody:** custody is partial. Some raw receipts cited before preservation are irrecoverable.
- **R4:** R4 is `ACCEPTED_OFFLINE` at `bc5ba5cd` only. It is not integrated and not native-proven.
- **Scope of this round:** document readiness and runtime readiness remain separate questions. v7 answers only
  the first.

---------------------------------------------------------------------------------------------------
## PART D — DELTA MATRIX v7 → v8 (ChatGPT review of v7: ACCEPT WITH NAMED FIXES, "not a Codex verdict")

| # | Sev | Finding | Fix in v8 | Verified by Claude |
|---|---|---|---|---|
| 1 | P1 | A7 missed that canonical itself still has different-family gates | A7 names `docs/PIPELINE.md:46,52` and adopts the reviewer's replacement text: the stricter gate stays in force until reconciled, and no prior acceptance is weakened | `git show 82d049e4:docs/PIPELINE.md`: row 3 "different-family review for high-risk code"; row 9 "independent different-family review" |
| 2 | P2 | A4 preconditions blocked read-only intake | Read-only discovery may come first. The full preconditions gate every state-changing step, and inspection grants no authority. | — (text) |
| 3 | P2 | A8.7 had no clearance criteria | The rule now separates account-attributable RED from monitoring failure, and clearance needs all four conditions; an acknowledgement does not clear | — (text); system-wide scope still ⚑ owner |
| 4 | P2 | A10.0 made the draft effective before ratification | Before ratification only existing canonical rules apply. A new prohibition needs an owner-approved governance change, and steps 0–2 do not authorize themselves. | — (text) |
| 5 | wording | A6 used `START_HERE.md` as if it were the evidence manifest | Custody moves to the canonical owner manifests with SHA-256; `START_HERE.md` is a router | — (text) |

**Left as the reviewer recorded it:** the provenance of the original Codex v5 review cannot be checked from the
pasted text, so the review-history row stays as the owner and Codex v6 reported it.

**Readiness scope:** this round covers document readiness only. Runtime readiness is still unproven: R4
integration, the worktree pilot, monitoring, the watchdog and the real-account controls.
