# S2a — Coverage ownership proposal and migration table

> **Generated** by `_triage/factory_os/gen_s2a_migration_doc.py` from
> `_triage/factory_os/s2a_migration.jsonl` (D1). Do not edit by hand — run the generator.
> `ORDER-600` · deliverables **D1 + D2** · machine acceptance =
> `_triage/factory_os/check_s2a_migration.py` (nine criteria, all green at the commit that
> introduced this file).

## What you are being asked to do

This is a **proposal about ownership**, not a change to it. Nothing in `MASTER_BACKLOG.md` has been
edited, nothing under `factory/` has been created, and no row says `APPROVED` — that value is yours to
write, in your own commit.

For each of the **27** entities the Factory OS schema defines, one row states: **where that fact lives
today**, where the design proposes it should live, and what concretely breaks if it moves or if it
does not. Twelve rows propose a move (`TRANSFER`), fifteen propose leaving things alone (`KEEP`), and
**one of the twelve is marked `REFUSED` by me rather than proposed to you** — see *What I refused*
below.

**The one decision that matters most is the first row of the table: the Coverage edge.**

## The Coverage edge, in one read

`MASTER_BACKLOG.md` §2 declares itself the owner of the coverage matrix — which EA has been tested on
which symbol × timeframe. The design proposes `factory/coverage.jsonl` become the machine source and §2
be **regenerated** from it.

Two measurements decide this, and both were taken rather than assumed:

- **Nothing machine-reads §2 today.** The only parser of `## 2. COVERAGE MATRIX` anywhere in the repo
  is `parse_section2()` inside this order's own checker. `scripts/check_state.ps1:124` opens the file
  solely to assert it contains the string `canonical entry =` (its owner banner) and never looks at the
  table; `scripts/check_block_staleness.ps1:57` only lists it as self-referential. **So the transfer
  breaks no automated reader.** The risk is human: the banner tells readers the table is
  hand-maintained, so the banner and the section header must say *"generated — edits here are
  overwritten"* in the same commit that generates it. That mitigation is part of the proposal, not an
  afterthought.
- **Leaving it costs something already.** Design §1.2 measured §2 at **7 EA rows**, last really updated
  **2026-06-27**, while `portfolio/DEPLOYMENTS.csv` carries **64** deployment rows. The two have never
  been reconciled at any granularity. The declared owner of "what is tested" is a five-week-old hand
  table describing a fleet it does not cover.

**Recommendation: approve the Coverage edge (`TRANSFER`), on the condition that the banner change ships
in the same commit as the first generation.** Everything else in this table can be decided later; this
row is what `S2` is blocked on.

## What the green checker does and does not prove

`check_s2a_migration.py` exits 0 on this data. That means: all 27 entities are accounted for by set
equality against the schema, no row is self-approved, every `current_owner` is a path that really
exists at HEAD, **every `owner_ref` hash was re-resolved from git and matched**, the Coverage edge is
present, not every row is `KEEP`, and the two coverage numbers reconcile through a mapping.

It does **not** prove the breakage analysis is any good. A checker cannot judge whether
`breaks_if_moved` names the right reader. That is the human-review checklist below, and it is the part
worth your time.

`_triage/factory_os/run_s2a_migration_tests.py` mutates this real file 24 ways — a flipped hash digit,
the Coverage edge removed, every row flipped to `KEEP`, a `LIVE` cell dropped from the mapping — and
requires each to redden the criterion it targets by name, with the unmutated file as a green control.
A green checker that cannot fail against the file it just passed is not evidence.


## All 27 rows at a glance

Folded from D1 on every generation, so this table cannot drift from the data.

| entity | lives today | proposed | disposition | signer | state |
|---|---|---|---|---|---|
| `CandidateManifest` | `EA_SCORECARD_AND_REGISTRY.md` | `factory/candidates/` | **TRANSFER** | user (Boss) | PROPOSED |
| `CoverageCell` | `MASTER_BACKLOG.md` | `factory/coverage.jsonl` | **TRANSFER** | user (Boss) | PROPOSED |
| `Hypothesis` | `AGENT_TASKBOARD.md` | `factory/hypotheses.jsonl` | **TRANSFER** | user (Boss) | PROPOSED |
| `InstrumentProfile` | `ea_template/OPTIMIZATION_PROCEDURE_V2.md` | `factory/instrument_profiles.jsonl` | **TRANSFER** | claude (lead engineer) | PROPOSED |
| `LogicalSymbol` | `NOT_YET_BUILT` | `factory/universe.jsonl` | **TRANSFER** | user (Boss) | PROPOSED |
| `MagicAllocation` | `portfolio/DEPLOYMENTS.csv` | `factory/magic_allocations.jsonl` | **TRANSFER** | user (Boss) | PROPOSED |
| `ParameterBinding` | `docs/PARAM_REGISTRY.csv` | `factory/parameter_bindings.jsonl` | **TRANSFER** | claude (lead engineer) | PROPOSED |
| `RunTransition` | `scripts/experiment_event_log.ps1` | `factory/runs/` | **TRANSFER** | claude (lead engineer) | PROPOSED |
| `SafeProjection` | `DERIVED_NOT_PERSISTED` | `build/safe_projection.json` | **TRANSFER** | user (Boss) | PROPOSED |
| `SystemFinding` | `portfolio/control_room_snapshot.json` | `ops/findings.jsonl` | **TRANSFER** | claude (lead engineer) | PROPOSED |
| `TestUniverse` | `NO_CURRENT_OWNER` | `factory/universe.jsonl` | **TRANSFER** | user (Boss) | PROPOSED |
| `WorkReceipt` | `AGENT_TASKBOARD.md` | `ops/receipts/` | **TRANSFER** | user (Boss) | **REFUSED** |
| `CandidatePayload` | `EMBEDDED:CandidateManifest` | `EMBEDDED:CandidateManifest` | KEEP | claude (lead engineer) | PROPOSED |
| `ControlRoomSnapshotV5` | `portfolio/control_room_snapshot.json` | `portfolio/control_room_snapshot.json` | KEEP | claude (lead engineer) | PROPOSED |
| `DeploymentAttestationEvent` | `portfolio/ATTESTATION_MAP.csv` | `portfolio/ATTESTATION_MAP.csv` | KEEP | claude (lead engineer) | PROPOSED |
| `EvidenceRef` | `docs/memory_control/experiment_events/evidenc…` | `docs/memory_control/experiment_events/evidenc…` | KEEP | claude (lead engineer) | PROPOSED |
| `ExecutionKey` | `EMBEDDED:RunTransition` | `EMBEDDED:RunTransition` | KEEP | claude (lead engineer) | PROPOSED |
| `IdeaRef` | `INTAKE_QUEUE.md` | `INTAKE_QUEUE.md` | KEEP | user (Boss) | PROPOSED |
| `MetricRef` | `EMBEDDED:CoverageCell` | `EMBEDDED:CoverageCell` | KEEP | claude (lead engineer) | PROPOSED |
| `ModuleUse` | `EMBEDDED:Hypothesis` | `EMBEDDED:Hypothesis` | KEEP | claude (lead engineer) | PROPOSED |
| `OwnerRef` | `EMBEDDED:*` | `EMBEDDED:*` | KEEP | claude (lead engineer) | PROPOSED |
| `ReconciliationEvidence` | `EMBEDDED:SnapshotMeta` | `EMBEDDED:SnapshotMeta` | KEEP | claude (lead engineer) | PROPOSED |
| `RunAttempt` | `EMBEDDED:RunTransition` | `EMBEDDED:RunTransition` | KEEP | claude (lead engineer) | PROPOSED |
| `RunJournal` | `TRANSIENT` | `TRANSIENT` | KEEP | user (Boss) | PROPOSED |
| `SnapshotBuilderInput` | `_triage/factory_os/snapshot_validator.py` | `_triage/factory_os/snapshot_validator.py` | KEEP | claude (lead engineer) | PROPOSED |
| `SnapshotMeta` | `EMBEDDED:ControlRoomSnapshotV5` | `EMBEDDED:ControlRoomSnapshotV5` | KEEP | claude (lead engineer) | PROPOSED |
| `SnapshotVerdict` | `EMBEDDED:ControlRoomSnapshotV5` | `EMBEDDED:ControlRoomSnapshotV5` | KEEP | claude (lead engineer) | PROPOSED |

**KEEP = 15 · TRANSFER = 12** · 27 rows total.

## The two coverage numbers, reconciled rather than equated

`ORDER-600` requires these be reported separately **with a mapping**, because they are not the same number and equating them is how a coverage claim quietly loses a cell.

| number | value | what it counts |
|---|---|---|
| `source_rows_consumed` | **7** | EA rows in `MASTER_BACKLOG.md` §2, each consumed exactly once |
| `live_cells_only` | **8** | symbol × TF cells in the LIVE column — `ST_EA03` alone carries two (GBPUSD H1 *and* USDCAD H1), which is why 7 ≠ 8 |
| `cells_emitted` | **40** | every normalised cell, LIVE plus the "other symbols tried" column |

32 of the 40 emitted cells are marked **`UNVERIFIED_IMPORT`**, each carrying its source coordinates. They are not sloppiness — §2's last column states a symbol and an outcome but almost never a timeframe, so a symbol × TF cell cannot be built from it without guessing. Tokens like `EUR`, `AUD` and `NZD` are recorded **verbatim** for the same reason: expanding them silently would invent test coverage that was never measured.

The LIVE cells are declared independently in `gen_s2a_migration.py` **and** parsed from the file, and the generator refuses to write if the two derivations disagree — the same two-independent-derivations discipline that established 7/8 in the first place.

## Human review — the part the checker cannot do

One block per row that proposes a move. These four fields are the reviewer checklist from `ORDER-600`; read them asking *"does this name a real reader, and a real failure"* — the rev-1 acceptance called this analysis "numeric, checkable", and it is not.

### `CandidateManifest` — `EA_SCORECARD_AND_REGISTRY.md` → `factory/candidates/`

*canonical · signer: user (Boss) · state: PROPOSED*

- **Breaks if moved — names a specific reader or writer:** scripts/check_state.ps1 asserts the scorecard carries its owner banner, and scripts/check_block_staleness.ps1 treats it as the index of every verdict ever written; AGENTS.md 2 reserves verdict text in this file to Claude/the user. The transfer must therefore move IDENTITY only (the immutable bundle: ex5 + locked .set + evidence + attestation), never verdict text - design section 1.3 #7. If verdict text were copied, the scorecard and the manifest could disagree and check_state.ps1 would still pass, because it checks the banner and not the content.
- **Breaks if NOT moved — a concrete failure, with a date or trigger:** Candidate identity is currently a filename convention, and it has already failed once: ORDER-410 step 1 found TrendRider looked MISSING on the VPS purely because the deploy bundle renamed the file, and only hash matching settled what filename matching got wrong. TRIGGER: the next deploy-vs-repo reconciliation repeats that, because nothing pins a candidate to its bytes.
- **Reverse steps — executable, not "revert the commit":** 1) delete factory/candidates/. 2) point any reader back at the scorecard row id. 3) re-run scripts/check_state.ps1 (banner + no-duplicate assertions) and confirm CLEAN. The scorecard is not edited by this transfer, so no restore is needed.
- **Evidence lost — what cannot be reconstructed:** The candidate-to-bytes pin. After the reverse, a candidate can again only be identified by name, so any bundle that was renamed or recompiled in the interim can no longer be matched to the verdict that approved it - MQL5 compiles are not byte-reproducible (memory mql5-compile-not-byte-reproducible), so it cannot be recovered by rebuilding.
- **Retention window:** git history, indefinite for the manifest; but the .ex5 blobs it points at are retained only as long as the evidence store keeps them - the manifest outliving its blobs is the real risk, not the manifest being lost.

### `CoverageCell` — `MASTER_BACKLOG.md` → `factory/coverage.jsonl`

*canonical · signer: user (Boss) · state: PROPOSED*

- **Pin (`owner_ref.path`) — NOT the same file as `current_owner`:** `factory/coverage.jsonl` · The canonical bytes MOVED: section 2 of MASTER_BACKLOG.md is now GENERATED from factory/coverage.jsonl (gen_coverage.py; the transfer landed in a424e90b at 2026-07-30T23:46:07+07:00, touching 9 files and NOT this table -- section 2's own banner dates the change 2026-07-31). owner_ref exists to answer ONE question -- "have the bytes this proposal is about changed since the owner read them?" (N1-N4 in S2A_ATTESTATION_POLICY.md) -- so it must pin the file that now holds those bytes, or it asks the question about the wrong file and reports STALE every time an unrelated line of the backlog moves. current_owner is DELIBERATELY left as MASTER_BACKLOG.md and is not a candidate for the same move: the append-only attestation log references it (R6 -- all 7 historical records name this owner and would become ineligible, unrepairably, because the log cannot be rewritten), and check_s2a_migration.py C7 keys the existence of the Coverage edge on it. So the two fields are answering two different questions and now say so.
- **Breaks if moved — names a specific reader or writer:** MEASURED 2026-07-30: nothing machine-reads section 2, so no automated reader breaks. The only parser of "## 2. COVERAGE MATRIX" anywhere in the repo is _triage/factory_os/check_s2a_migration.py:parse_section2, written for this order. scripts/check_state.ps1:124 opens MASTER_BACKLOG.md only to assert it contains the string "canonical entry =" (the owner banner) and never looks at the table; scripts/check_block_staleness.ps1:57 only lists the file as self-referential so that citing a verdict inside it is not read as staleness. The break is therefore HUMAN: the file's own banner says it owns the coverage matrix, so anyone who trusts the banner would keep hand-editing a table that had become generated output. Mitigation must be part of the transfer - the banner and the section header have to say "generated from factory/coverage.jsonl; edits here are overwritten" in the same commit that generates it.
- **Breaks if NOT moved — a concrete failure, with a date or trigger:** Already happening, not hypothetical. Design section 1.2 measured section 2 at 7 EA rows whose last real update was 2026-06-27, while portfolio/DEPLOYMENTS.csv carries 64 deployment rows; the two have never been reconciled at any granularity. So the declared owner of "which EA is tested on which symbol x TF" is a hand table five weeks stale against the fleet. TRIGGER: the next coverage question ("which symbol x TF is still untested?") is answered from that table - and the 2026-07-30 ORDER-430 finding that BWD passes were being read off trade counts nobody had looked at is the same failure mode one layer up: a number is trusted because it is written down somewhere canonical.
- **Reverse steps — executable, not "revert the commit":** 1) git revert the generation commit, which restores section 2 to its pre-transfer bytes (it is tracked, so the prior table is recoverable exactly). 2) delete factory/coverage.jsonl. 3) remove the "generated - do not edit" line from the section-2 header and the owner banner. 4) re-run scripts/check_state.ps1 and confirm the owner-banner assertion at line 124 still passes. No step depends on data that only exists after the transfer.
- **Evidence lost — what cannot be reconstructed:** Nothing, if the transfer is done as a generation from the existing table: the pre-transfer section 2 stays in git history and is recoverable by blob. What CANNOT be reconstructed is the provenance of any cell that was hand-edited after the transfer and before the reverse - those edits are overwritten by the next generation with no record that they existed, which is exactly the risk the "generated" banner exists to prevent.
- **Retention window:** git history, indefinite - section 2 is a tracked file, so every pre-transfer revision is permanently addressable by commit+blob. No separate retention is required.

### `Hypothesis` — `AGENT_TASKBOARD.md` → `factory/hypotheses.jsonl`

*canonical · signer: user (Boss) · state: PROPOSED*

- **Breaks if moved — names a specific reader or writer:** Nothing reads pre-registration mechanically today, and the transfer is deliberately partial, so the risk is duplication rather than breakage. Design section 1.3 #1 rules that the causal claim, falsifier and acceptance STAY in the taskboard row and factory/hypotheses.jsonl holds only machine-read fields plus a preregistration_ref. The reader that would break if that rule is ignored is .githooks/pre-commit, which enforces taskboard structure on every commit: a second copy of the claim would drift from the row the hook validates, and the hook cannot see the copy.
- **Breaks if NOT moved — a concrete failure, with a date or trigger:** NARROWED after Codex audit 7. The previous version cited unmeasured-corr-costs-more-than-real-risk (1088 of 1540 pairs still on a default 1.0) as though machine-readable hypothesis structure would produce those numbers. It would not: those are RETURN correlations and they come from trade series, not from an architecture digest. The memory is real; the bridge to this entity was not. What this row can support: shared STRUCTURE is currently invisible to any tool. Whether two EAs use the same module set or the same architecture exists only as prose inside taskboard rows, so "these two are the same strategy wearing different parameters" cannot be asked mechanically - and that is the cheap screen that should run BEFORE the expensive return-correlation measurement, not a replacement for it. TRIGGER: the next cohort added to the portfolio without a structural dedupe.
- **Reverse steps — executable, not "revert the commit":** 1) delete factory/hypotheses.jsonl. 2) drop the preregistration_ref column from any consumer written against it. 3) run .githooks/pre-commit against a taskboard edit to confirm the structure assertions still pass. No taskboard row is rewritten by this transfer, so there is nothing to restore there.
- **Evidence lost — what cannot be reconstructed:** The revision chain: if a hypothesis is revised only in the jsonl and the file is deleted, which revision produced a given run can no longer be reconstructed - the taskboard row holds the claim but not the revision counter.
- **Retention window:** git history, indefinite while the file is tracked. It must be tracked from its first commit for that to hold - an untracked jsonl has no retention at all.

### `InstrumentProfile` — `ea_template/OPTIMIZATION_PROCEDURE_V2.md` → `factory/instrument_profiles.jsonl`

*canonical · signer: claude (lead engineer) · state: PROPOSED*

- **Breaks if moved — names a specific reader or writer:** No script parses this document - it is procedure prose read by humans and by Claude, so nothing mechanical breaks. Design section 1.3 #4 restricts the new artifact to the broker/lane mapping layer plus a content_hash so a Candidate pins profile CONTENT rather than a mutable id. The break if that scope is exceeded is silent and expensive: baseline semantics copied into a jsonl would diverge from the procedure that backtest-optimize-rigor actually follows, and no test compares the two.
- **Breaks if NOT moved — a concrete failure, with a date or trigger:** The broker/lane mapping does not exist in machine-readable form, and the cost is measured: memory btc-tick-data-differs-per-mt5-install records the same EA, .set and window returning different PF across two MT5 installs, which is why cross-install comparison had to be banned outright (ORDER-371). TRIGGER: any A/B whose two legs land on different lanes - the ban is currently enforced by discipline, not by a profile a tool can check.
- **Reverse steps — executable, not "revert the commit":** 1) delete factory/instrument_profiles.jsonl. 2) drop the content_hash field from any Candidate written against it. 3) confirm ea_template/OPTIMIZATION_PROCEDURE_V2.md is byte-unchanged (git diff must be empty) - this transfer never edits it.
- **Evidence lost — what cannot be reconstructed:** The content_hash pin. After a reverse, a Candidate references a profile by id again, so if the profile is edited there is no way to tell which content a past run used.
- **Retention window:** git history, indefinite; profiles must be append-only rather than edited in place, or the content_hash pins something that no longer exists.

### `LogicalSymbol` — `NOT_YET_BUILT` → `factory/universe.jsonl`

*canonical · signer: user (Boss) · state: PROPOSED*

- **Breaks if moved — names a specific reader or writer:** Nothing reads it because it does not exist; design section 1.4 area (line 225) states the mapping - "LogicalSymbol -> broker symbol per lane (XAUUSD | GOLD | XAUUSDm; DE40 traded as GER40)" - and decision 26 keeps LogicalSymbol separate from the broker string. The risk on creation is that the mapping is embedded in the universe file and then copied into .set generation, giving two answers for one symbol.
- **Breaks if NOT moved — a concrete failure, with a date or trigger:** CORRECTED after Codex audit 7, which caught this row citing a memory for the OPPOSITE of what it says. The removed claim was that mt5-selfupdate-breaks-startup-ini-and-pid-kill records "a symbol-identity failure diagnosed as a network one". That memory says the reverse in as many words: the "symbol synchronization timeout" was NOT a symbol problem at all - the terminal was simply never authorised, because a login made without /portable stores credentials in a different data folder. Citing it here inverted its causality to make it support a symbol registry. The honest statement of the gap: the logical-to-broker symbol mapping exists only as per-script convention, so nothing can mechanically check that two runs traded the same instrument. The concrete cost on record is ORDER-371, which had to BAN cross-install comparison outright after memory btc-tick-data-differs-per-mt5-install measured the same EA, .set and window returning different PF on two MT5 installs. That ban is enforced by discipline today; a versioned symbol identity is what would let a tool enforce it. TRIGGER: the next A/B whose two legs land on different lanes (D:\Meta 5 / 5b / 5c).
- **Reverse steps — executable, not "revert the commit":** 1) delete factory/universe.jsonl (shared with TestUniverse - if only this fact is being reversed, remove the symbol-alias block and leave the mandatory set). 2) revert readers to their per-script alias handling, which is still present because nothing is removed by this proposal.
- **Evidence lost — what cannot be reconstructed:** Which broker string a past run actually traded, for any run recorded only by logical symbol after the transfer. Before the transfer that information is implicit in the report file; after a reverse, rows written in between have no way to name the alias.
- **Retention window:** git history, indefinite; aliases must be added, never rewritten, because a rewritten alias retroactively changes what a past run is understood to have traded.

### `MagicAllocation` — `portfolio/DEPLOYMENTS.csv` → `factory/magic_allocations.jsonl`

*canonical · signer: user (Boss) · state: PROPOSED*

- **Breaks if moved — names a specific reader or writer:** This is the most-read file in the table and the transfer must NOT move deployment status. Real readers, verified 2026-07-30: scripts/check_state.ps1 (parses it as the inventory, asserts required columns and no duplicate account|magic), scripts/control_room_snapshot.ps1, scripts/live_dashboard.ps1, scripts/lib/monitor_coverage.ps1, scripts/mris/mris_exposure.ps1, scripts/check_precommit_staged.ps1. Design section 1.1 keeps the CSV as the write path and section 1.3 #8 limits the new artifact to a RESERVATION log that references Deployment. If it copied status, all six readers would keep reading the CSV while the jsonl drifted, and check_state.ps1's uniqueness check would not see the second copy.
- **Breaks if NOT moved — a concrete failure, with a date or trigger:** Magic reservation is currently implicit: a number is "taken" once it appears in a row of a deployed EA, so there is no way to reserve one before deploying. The failure this invites is on the board now - ORDER-511 was opened because the template EA sits on default magic 990001 and is ABSENT from DEPLOYMENTS.csv, i.e. a live magic that the inventory cannot see. TRIGGER: the next EA attached before its row is written.
- **Reverse steps — executable, not "revert the commit":** 1) delete factory/magic_allocations.jsonl. 2) revert any reader switched to it (the CSV was never demoted, so each reader's old code path is intact). 3) run scripts/check_state.ps1 and confirm "no duplicate account|magic in inventory" and the 64-row parse still pass.
- **Evidence lost — what cannot be reconstructed:** Reservations that never became deployments. A magic reserved and then abandoned exists only in the allocation log - the CSV records deployments, so after a reverse there is no record that the number was ever spoken for, and it can be reissued to a second EA.
- **Retention window:** git history, indefinite. Reservations must never be hard-deleted even when released, because a released-and-reissued magic is indistinguishable from a duplicate to every reader listed above.

### `ParameterBinding` — `docs/PARAM_REGISTRY.csv` → `factory/parameter_bindings.jsonl`

*canonical · signer: claude (lead engineer) · state: PROPOSED*

- **Breaks if moved — names a specific reader or writer:** The registry is machine-read on every commit: .githooks/pre-commit and .githooks/fast_tier_pathspec select on it, scripts/optimize_guard.ps1 reads it together with docs/PARAM_LINKAGE.md to classify parameters, and scripts/param_registry_check.ps1 and scripts/gen_param_linkage.ps1 both consume it. Design section 1.1 says EXTENDED, NOT REPLACED. A transfer that moved the parameter definitions rather than adding a binding layer would break the pre-commit tier itself, which is the worst possible failure surface: the guard that would catch the mistake is the thing being broken.
- **Breaks if NOT moved — a concrete failure, with a date or trigger:** Concrete and measured: design section 1.2 records 177/184 OptimizeStage and 181/184 SafeRange values as UNKNOWN, so the registry cannot answer "what may this parameter be set to" for 96% of identifiers. TRIGGER: every optimize run - the guard classifies from PARAM_LINKAGE override pairs while the safe range it would need is blank, which is how a grid gets built outside the range that contains the answer (memory grid-answer-outside-the-grid).
- **Reverse steps — executable, not "revert the commit":** 1) delete factory/parameter_bindings.jsonl. 2) revert scripts/optimize_guard.ps1 to read PARAM_LINKAGE.md alone. 3) run scripts/_test/run_optimize_guard_tests.ps1 and scripts/param_registry_check.ps1 - both must be CLEAN before the reverse is considered done, because this path is pre-commit-load-bearing.
- **Evidence lost — what cannot be reconstructed:** Any binding that was only ever recorded in the jsonl - i.e. every safe range and stage filled in after the transfer. Those were never in the CSV, so a reverse discards the discovery work rather than restoring it.
- **Retention window:** git history, indefinite. Before deleting, the filled-in ranges must be written back into PARAM_REGISTRY.csv or the reverse is destructive, not neutral.

### `RunTransition` — `scripts/experiment_event_log.ps1` → `factory/runs/`

*canonical · signer: claude (lead engineer) · state: PROPOSED*

- **Breaks if moved — names a specific reader or writer:** Design section 1.3 #5 splits this deliberately: the experiment event log OWNS the occurrence timeline and factory/runs/ owns ONLY the scheduler recovery checkpoint. The readers that break if the timeline moves are scripts/check_experiment_events.ps1 and scripts/_test/run_order105_negative_tests.ps1, both of which read the event log and its evidence manifest. Note the current_owner here is the SCRIPT, not a data file: the transition shape lives in the writer today, and the monthly JSONL it appends to is the store - so "moving" it means giving the scheduler its own checkpoint file, not relocating history.
- **Breaks if NOT moved — a concrete failure, with a date or trigger:** NARROWED after Codex audit 7. The previous version cited taskstop-does-not-kill-qwen-child as the cost, which does not follow: that memory records a process-tree cancellation defect (a "stopped" worker whose child kept holding the MT5 lane and committing), and a recovery checkpoint neither stops nor identifies an orphan child. Real incident, wrong causal bridge. CORRECTED AGAIN after Codex audit 8, which caught the REPLACEMENT being false too. The second version claimed the event log "records completed occurrences" so an interrupted run leaves no trace. That is wrong on the facts: docs/memory_control/experiment_events/schema/event-v1.schema.json defines RUN_STARTED, the lifecycle includes it, _mt5_auto/d1g_event_chain.ps1 emits it as the pre-run event, and events-2026-07.jsonl carries a real committed one. I replaced a wrong causal bridge with a wrong fact and called it a correction. The narrow claim that survives: the event log records that a run STARTED, but carries no resumable state - no attempt counter, no last-completed-step, no lease - so after an interruption it can say THAT a run began and not WHERE it got to. That is the gap factory/runs/ is scoped to, and design section 1.3 #5 already limits this transfer to exactly that: the scheduler recovery checkpoint, and nothing else. TRIGGER: the next interrupted overnight batch that has to be restarted rather than resumed.
- **Reverse steps — executable, not "revert the commit":** 1) delete factory/runs/. 2) remove the checkpoint write from the scheduler. 3) run scripts/check_experiment_events.ps1 to confirm the event log is unaffected - it must be, because this transfer never writes to it.
- **Evidence lost — what cannot be reconstructed:** In-flight state for any run that was interrupted and not yet folded into the event log: the attempt counter and the last completed step. The event log records completed occurrences, so a half-finished run leaves no trace there.
- **Retention window:** per-run, until the run completes and its occurrence is written to the event log; the checkpoint is safe to prune after that, and MUST be pruned or it becomes a second, stale copy of the timeline.

### `SafeProjection` — `DERIVED_NOT_PERSISTED` → `build/safe_projection.json`

*derived · signer: user (Boss) · state: PROPOSED*

- **Breaks if moved — names a specific reader or writer:** Nothing exists to break: no file, and no code computes it. Design section 1.3 naming rule places generated projections under build/ and states they are never edited. The real hazard on creation is the one design section 1.2 already caught once - scripts/live_dashboard.ps1 held a global $BaseEquity = 10000 as one denominator for six accounts while portfolio/ACCOUNTS.csv records 100000 for 463666728 and blank for five. A projection that recomputes such a constant locally instead of reading the owner reintroduces exactly that bug.
- **Breaks if NOT moved — a concrete failure, with a date or trigger:** There is no vetted read surface, so every consumer reads raw owners and re-derives its own numbers - which is how the $BaseEquity divergence above survived across six accounts. TRIGGER: the next dashboard or status surface added; STATUS.html and STATUS.md are already recorded in design section 1.2 as stale and disagreeing with fresher sources.
- **Reverse steps — executable, not "revert the commit":** 1) delete build/safe_projection.json and its generator. 2) point consumers back at the owners directly. Nothing is restored, because nothing was moved: this is a derived artifact and the owners were never demoted.
- **Evidence lost — what cannot be reconstructed:** Nothing that is not recomputable. It is derived by definition, so a deleted projection can be regenerated from its owners - provided the generator is reverted with it. If the generator is deleted but a past projection is not, the stale file becomes an unfalsifiable claim, which is the failure mode to guard.
- **Retention window:** none required - regenerate on demand. Under build/ it should not be committed at all, so there is nothing to retain and nothing to go stale in git.

### `SystemFinding` — `portfolio/control_room_snapshot.json` → `ops/findings.jsonl`

*canonical · signer: claude (lead engineer) · state: PROPOSED*

- **Breaks if moved — names a specific reader or writer:** Design section 1.3 #10 keeps detector STATE owned by the snapshot and gives ops/findings.jsonl only stable identity and lifecycle. Readers of the snapshot that would break if state moved: scripts/daily_monitor.ps1, scripts/lib/monitor_coverage.ps1, scripts/_test/run_monitor_integrity_tests.ps1, and _triage/factory_os/snapshot_validator.py. The specific hazard is that a finding whose lifecycle says RESOLVED while the snapshot still reports it firing would be an authoritative contradiction, and the monitor-integrity suite compares snapshots, not snapshots-against-a-second-store.
- **Breaks if NOT moved — a concrete failure, with a date or trigger:** A finding has no identity across runs, so it cannot be acknowledged, deferred, or proven fixed - each snapshot restates it as new. The cost is on record: memory stale-detector-masked-by-advisory-label describes a detector reporting 8 of 56 for an unknown period, and memory guard-disarmed-by-prose-reported-as-note describes a guard parsing zero rows and reporting NOTE. TRIGGER: the next detector regression - with no lifecycle, "this has been firing for four commits" is not a question the data can answer, which is precisely how that one survived.
- **Reverse steps — executable, not "revert the commit":** 1) delete ops/findings.jsonl. 2) revert readers to taking finding state from the snapshot directly. 3) run scripts/_test/run_monitor_integrity_tests.ps1 and confirm it passes. The snapshot is generated by scripts/control_room_snapshot.ps1 and is not edited by this transfer, so it needs no restore.
- **Evidence lost — what cannot be reconstructed:** The acknowledgement and resolution history - who accepted a finding and when it was declared fixed. The snapshot holds only the current state, so after a reverse the question "was this ever acknowledged" becomes unanswerable.
- **Retention window:** indefinite for resolved findings. A resolved finding that is deleted is indistinguishable from one that never fired, which would erase exactly the four-commit-blind-spot evidence the lifecycle exists to keep.

### `TestUniverse` — `NO_CURRENT_OWNER` → `factory/universe.jsonl`

*canonical · signer: user (Boss) · state: PROPOSED*

- **Breaks if moved — names a specific reader or writer:** Nothing breaks, because nothing reads it - there is no artifact to break. Design section 1.3 #2 is the audited verdict: "genuinely unowned. No canonical artifact exists for a versioned mandatory symbol x TF set." This row therefore CREATES a first owner rather than moving one, and the only risk is the mirror image of a transfer risk: the new file becomes a second de-facto coverage list competing with MASTER_BACKLOG.md section 2. The Coverage edge row above must land first or together, so that coverage cells and the universe they are drawn from have one source each.
- **Breaks if NOT moved — a concrete failure, with a date or trigger:** NARROWED after Codex audit 7, which found the previous version reaching for a failure this entity does not prevent. It cited bar-cleared-by-non-participation (hosts that "passed" BWD on 52-62 trades over three years) as if a universe registry would have caught it. It would not: those hosts DID trade the tested cell, just rarely, and the fix for that is a trades-per-window participation floor - a BAR, which CLAUDE.md says only the user may ratify. Wrong mechanism, right-sounding prose. The true gap is narrower and still real: there is no versioned statement of which symbol x TF cells are MANDATORY, so "this screen skipped a cell" is not a question any tool can ask. The measured instance is in this order's own data: MASTER_BACKLOG.md section 2 carries 7 EA rows and 8 LIVE cells against a 64-row deployment inventory, and no artifact says which cells SHOULD have been covered - so the gap between them cannot be computed, only eyeballed. TRIGGER: the next coverage question that asks what is missing rather than what was run.
- **Reverse steps — executable, not "revert the commit":** 1) delete factory/universe.jsonl. 2) unregister any reader. Nothing is restored because nothing was moved - this row creates an owner where design section 1.3 says none exists, so the reverse is a plain deletion and cannot damage an existing owner.
- **Evidence lost — what cannot be reconstructed:** The version history of the mandatory set: which symbol x TF cells were mandatory at the time a past screen ran. That is unreconstructable after deletion, because it exists nowhere else today - which is the same reason the fact is unowned.
- **Retention window:** git history, indefinite, and the file must be versioned rather than edited in place - a mandatory set that is mutated silently is worse than none, because past verdicts would appear to have been judged against the current set.

### `WorkReceipt` — `AGENT_TASKBOARD.md` → `ops/receipts/`  🚫 **REFUSED**

*canonical · signer: user (Boss) · state: REFUSED*

> **Why refused:** REFUSED BY THIS TABLE, not by the design. Design section 1.3 #9 states that opening this writer needs an AGENTS.md 2 permission change THE USER MUST RATIFY FIRST. AGENTS.md 2 currently allows an agent to write only its own order row on the taskboard, and reserves new orders to Claude/the user. Proposing the transfer now would be proposing a writer that the governance file forbids, so the honest state is REFUSED-pending-ratification rather than PROPOSED. This is the one row in the table that must not be signed as-is, and it is deliberately not uniform with the other eleven TRANSFERs.

- **Breaks if moved — names a specific reader or writer:** The taskboard is enforced mechanically on every commit: .githooks/pre-commit validates its structure, scripts/check_taskboard_archive.ps1 walks its archive chain, scripts/lib/b1_guard.ps1 requires a docs/memory_control/B1_DATASET.csv row in the same commit as any REVIEWED transition, and scripts/_test/run_statusclass_tests.ps1 cages the status classifier. A receipt store that duplicated order status would drift from all four. Design section 1.3 #9 is explicit that where an ORDER-* exists the taskboard owns title/status/owner/acceptance and the receipt only REFERENCES it.
- **Breaks if NOT moved — a concrete failure, with a date or trigger:** A commitment made in chat that never became an ORDER has no home, so it is invisible to every guard above. The measured cost is repetition: memory grep-destination-before-tasking-user records ORDER-230 being answered four hours BEFORE its order was written and then re-queued to the user twice more, the second such case in three days. TRIGGER: the next chat commitment that is not written as an order.
- **Reverse steps — executable, not "revert the commit":** 1) delete ops/receipts/. 2) revert the AGENTS.md 2 permission row to its pre-ratification text. 3) run .githooks/pre-commit, scripts/_test/run_statusclass_tests.ps1 and scripts/_test/run_b1_guard_tests.ps1 - all three must pass, since they are the guards the receipt store sits beside.
- **Evidence lost — what cannot be reconstructed:** Chat-only commitments recorded nowhere else. Because they never became orders, deleting the receipt store erases them entirely - there is no second copy in the taskboard to fall back to, which is the whole reason the entity was proposed.
- **Retention window:** not applicable until the user ratifies the AGENTS.md 2 change; no receipt may be written before then, so nothing is yet in a retention window.

## The `KEEP` rows, and why each is a choice rather than a default

`ORDER-600` treats an all-`KEEP` table as the null migration, so every `KEEP` carries a named reason. Nine of these are entities embedded in a parent — they own no file, so there is no storage to transfer, and each parent claim is verified against the schema `$ref` graph rather than believed.

| entity | lives today | why KEEP |
|---|---|---|
| `CandidatePayload` | `EMBEDDED:CandidateManifest` | this fact is a sub-object of another entity and owns no file of its own, so there is no storage to transfer; it moves if and only if its parent moves |
| `ControlRoomSnapshotV5` | `portfolio/control_room_snapshot.json` | design section 1.1 is explicit: scripts/control_room_snapshot.ps1 -> portfolio/control_room_snapshot.json "is already the single-projection pattern the handoff asks for. Extend it; do not write a second one." The v4/v5 schema migration is a change of SHAPE, not of owner, and belongs to S4. |
| `DeploymentAttestationEvent` | `portfolio/ATTESTATION_MAP.csv` | design section 1.1 reuses this file directly for Candidate/Deployment identity (section 5.6). The schema's x-owner-file also mentions an "append-only event log" beside the CSV; that log is NOT proposed here, because no PLANNED_PATHS entry declares it and inventing a destination inside a proposal is… |
| `EvidenceRef` | `docs/memory_control/experiment_events/e…` | design section 1.3 #6: owned, with its own schema, and "no new index. Register through the existing utility." The manifest already stores exactly the {path, commit_oid, blob_oid, raw_sha256} shape this order recomputes for every owner_ref, so it is the precedent for the pinning discipline rather th… |
| `ExecutionKey` | `EMBEDDED:RunTransition` | this fact is a sub-object of another entity and owns no file of its own, so there is no storage to transfer; it moves if and only if its parent moves |
| `IdeaRef` | `INTAKE_QUEUE.md` | design section 1.3 #11 is unusually direct: the file "opens by declaring itself the single place for every new source/strategy drop", so there is to be "no ops/ideas.csv". Stable ID and exact-URL dedupe are added AS COLUMNS on the existing owner, and the Factory OS holds only a read projection. |
| `MetricRef` | `EMBEDDED:CoverageCell` | this fact is a sub-object of another entity and owns no file of its own, so there is no storage to transfer; it moves if and only if its parent moves |
| `ModuleUse` | `EMBEDDED:Hypothesis` | this fact is a sub-object of another entity and owns no file of its own, so there is no storage to transfer; it moves if and only if its parent moves |
| `OwnerRef` | `EMBEDDED:*` | the design's universal pinning primitive - 12 entities embed it, so naming a single parent would be false precision. It owns no file and cannot: it IS the pin (commit + blob + sha256) that lets an artifact hold a fact it does not own, per design section 1.3. |
| `ReconciliationEvidence` | `EMBEDDED:SnapshotMeta` | this fact is a sub-object of another entity and owns no file of its own, so there is no storage to transfer; it moves if and only if its parent moves |
| `RunAttempt` | `EMBEDDED:RunTransition` | this fact is a sub-object of another entity and owns no file of its own, so there is no storage to transfer; it moves if and only if its parent moves |
| `RunJournal` | `TRANSIENT` | correctly owned by nobody, now and after: the schema declares it x-derived and "NONE - derived by folding the RunTransition lines of one run_id. Never persisted, never written." Persisting a fold of an append-only log creates a second copy that can disagree with the log, so KEEP here means "never g… |
| `SnapshotBuilderInput` | `_triage/factory_os/snapshot_validator.py` | transient by contract - the schema says "NONE - transient. Produced by the snapshot builder, consumed by snapshot_validator, never persisted." Its only home today is the module that defines and validates its shape, and that module is a real tracked file, so this row names a genuine current owner ra… |
| `SnapshotMeta` | `EMBEDDED:ControlRoomSnapshotV5` | this fact is a sub-object of another entity and owns no file of its own, so there is no storage to transfer; it moves if and only if its parent moves |
| `SnapshotVerdict` | `EMBEDDED:ControlRoomSnapshotV5` | this fact is a sub-object of another entity and owns no file of its own, so there is no storage to transfer; it moves if and only if its parent moves |

## Two amendments I made to the order before writing any data

The acceptance was already amended once (rev 4) because three clauses could not all hold. Writing the
data surfaced two more of the same shape — a rule that cannot be obeyed for a measured subset of the
27. Both are recorded in `ORDERS_S2a_S3a_DRAFT.md` as **rev 5**, amended *before* the data rather than
quietly reinterpreted while building.

1. **D1's declared path pointed outside the slice.** `factory_os/s2a_migration.jsonl` was implemented
   literally as a **repo-root** `factory_os/` — a directory that does not exist, and where no other
   artifact of this slice lives. Every sibling path here carries the `_triage/` prefix, and D2's own
   declared path in the same list carries it. Corrected to `_triage/factory_os/`; nothing was created
   at the repo root.
2. **A genuinely unowned fact had no legal `current_owner`.** Measured from the schema's `$ref` graph
   rather than its prose: **9** entities are embedded in a parent, **14** have a real artifact holding
   the fact today, and **4** — `TestUniverse`, `LogicalSymbol`, `SafeProjection`, `RunJournal` — have
   **neither a file nor a parent**. Design §1.3 #2 says outright that Test Universe is *"genuinely
   unowned"*. For those four the rule allowed only: name a real file (a false claim about today),
   claim a parent (false — nothing references them), or omit the row (fails set equality). So
   `UNOWNED` is now legal — **and deliberately not a free pass**, because an unguarded sentinel would
   let all 27 rows out of the existence check and reinstate the null migration under a new name:
   - `unowned_evidence` must name a tracked file, **and the checker opens it and requires the entity to
     actually be mentioned there.** A claim that the design says so is not enough.
   - `UNOWNED` + `KEEP` additionally requires `canonical_or_derived = derived`. A *canonical* fact that
     nobody owns and nobody is proposed to own is drift, and must not be signable as "keep". Exactly
     one row qualifies (`RunJournal`, which is derived by folding an append-only log and correctly gets
     no owner ever).

   **While there, every `EMBEDDED:<Parent>` claim is now verified against the `$ref` graph** — the
   parent must really reference the child. This caught a stale number being carried forward: the
   handoff said 12 entities were embedded and listed `WorkReceipt`, which owns `ops/receipts/`. The
   graph says **9**. The prose count was wrong; the graph is not.

## What I refused, and why it is not an omission

`WorkReceipt` is the one row whose `signoff_state` is **`REFUSED`** rather than `PROPOSED`.

Design §1.3 #9 states that opening this writer needs an **`AGENTS.md` §2 permission change the user
must ratify first**. `AGENTS.md` §2 currently lets an agent write only its own order row on the
taskboard and reserves new orders to Claude/the user. Proposing the transfer now would mean proposing
a writer the governance file forbids. `REFUSED-pending-ratification` is the honest state, and it is
recorded on the row in `refused_reason`.

This matters beyond the one row: a table where all twelve `TRANSFER`s are uniformly `PROPOSED` is
indistinguishable from a table nobody thought about.

## Observations found while writing this, not fixed here

- **The schema's own prose is wrong about a version.** `ControlRoomSnapshotV5`'s `x-owner-file` says
  `portfolio/control_room_snapshot.json (EXISTING, v4 at HEAD)`. The file at HEAD carries
  `"version": 3`, and design §1.1 also says v3. Not fixed here — this order writes a proposal about
  ownership, and a schema version is not an ownership fact. Routed to **S4**, which owns the v4→v5
  migration and is already blocked on the real snapshot failing the schema.
- **`INTAKE_QUEUE.md` has no machine reader at all** (`git grep` over `scripts/` and `.githooks/`
  returns nothing), which is why its row is `KEEP`: design §1.3 #11 adds stable-ID and URL-dedupe
  columns *to the existing owner* rather than creating `ops/ideas.csv`.

## How to approve or refuse

`signoff_state` is yours. Per row, in your own commit:

- **approve** → set `signoff_state` to `APPROVED` on that row of
  `_triage/factory_os/s2a_migration.jsonl`. Note the checker refuses `APPROVED` **by design** — that
  guard exists to stop *me* writing it, so the criterion has to be relaxed to accept the owner's act
  in the same commit that records your approval. That relaxation is deliberately not pre-built, so it
  cannot be used before you have decided.
- **refuse** → set `signoff_state` to `REFUSED` and add a `refused_reason`. A refusal with a stated
  reason closes the question; silence leaves it open and it comes back.

Regenerate this document with
`tools\python312\python.exe _triage/factory_os/gen_s2a_migration_doc.py` after any edit to D1, and
`--check` will tell you if the two have drifted apart.
