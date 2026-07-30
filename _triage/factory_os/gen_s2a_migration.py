"""
gen_s2a_migration.py - ORDER-600 (S2a) deliverable D1, generated rather than hand-written.

WHY A GENERATOR AND NOT A HAND-WRITTEN JSONL
  D1 carries two kinds of field, and they must not be produced the same way:

    MECHANICAL  owner_ref {path, commit_oid, blob_oid, raw_sha256} - there is exactly one correct
                value and git knows it. Hand-typing these is how audit 5's null migration passed a
                criterion it had no business passing: a plausible constant looks identical to a real
                hash until something recomputes it. So this script asks git, every run.
    JUDGEMENT   current_owner / disposition / breaks_if_moved / breaks_if_not_moved / reverse_steps
                - no tool can derive these. They are written below, per entity, by name.

  The split is the point. `check_s2a_migration.py` C4 re-resolves every ref from git, so a hash this
  script gets wrong fails immediately; nothing protects the judgement columns except review, which is
  why D2 states them in prose for a human to accept or refuse.

WHAT IT WRITES
  _triage/factory_os/s2a_migration.jsonl                 27 rows, one per schema entity
  _triage/factory_os/s2a_coverage_reconciliation.json     the C8 two-number reconciliation

USAGE  tools\\python312\\python.exe _triage/factory_os/gen_s2a_migration.py [--check]
       --check regenerates in memory and exits 1 if the files on disk differ (drift guard).
"""
import hashlib
import io
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_s2a_migration as chk  # noqa: E402  -- reuse its parser and its path constants

DESIGN = '_triage/EA_LAB_FACTORY_OS_DESIGN.md'

# ---------------------------------------------------------------------------------------------
# Signers. C6 demands exactly ONE signer per distinct current_owner, which is the right semantics:
# the owner of a FILE signs everything proposed about that file, whatever each row's disposition is.
# Assignment rule, applied consistently: a file whose write permission AGENTS.md 2 reserves to
# "Claude / the user", or that declares itself a source of truth a human maintains, is signed by the
# USER; a generated projection or a script-owned artifact is signed by the lead.
USER = 'user (Boss)'
LEAD = 'claude (lead engineer)'

SIGNERS = {
    'MASTER_BACKLOG.md': USER,
    'EA_SCORECARD_AND_REGISTRY.md': USER,
    'AGENT_TASKBOARD.md': USER,
    'INTAKE_QUEUE.md': USER,
    'portfolio/DEPLOYMENTS.csv': USER,
    chk.UNOWNED: USER,
    'portfolio/control_room_snapshot.json': LEAD,
    'portfolio/ATTESTATION_MAP.csv': LEAD,
    'docs/memory_control/experiment_events/evidence-manifest.jsonl': LEAD,
    'ea_template/OPTIMIZATION_PROCEDURE_V2.md': LEAD,
    'docs/PARAM_REGISTRY.csv': LEAD,
    'scripts/experiment_event_log.ps1': LEAD,
    '_triage/factory_os/snapshot_validator.py': LEAD,
}

KEEP_EMBEDDED = ('this fact is a sub-object of another entity and owns no file of its own, so there '
                 'is no storage to transfer; it moves if and only if its parent moves')
NO_BLOB_EMBEDDED = ('embedded in a parent entity - there is no blob of its own to pin (ORDER-600 '
                    'rev 4 exemption)')
NO_BLOB_UNOWNED = ('no artifact holds this fact at HEAD, so there is no blob to pin (ORDER-600 '
                   'rev 5 UNOWNED form)')
KEEP_REVERSE = ('nothing is moved by a KEEP, so there is no forward step to undo; reversing this '
                'row means deleting the read-only projection that reads the owner and unregistering '
                'its reader - the owner file itself is never written by this proposal')
KEEP_NO_LOSS = 'nothing - no data moves, so no evidence leaves its current home'
KEEP_RETENTION = ('indefinite - the owner file is unchanged by this row, so nothing enters a '
                  'retention window')

# ---------------------------------------------------------------------------------------------
# The 27 rows. `owner` is the current_owner; owner_ref is recomputed from it below.
# EMBEDDED rows are written first, compactly, because their judgement is genuinely uniform - the
# alternative would be 9 paraphrases of one sentence, which is the "24 copies of the same string"
# that audit 5 rejected. Stating it once and pointing at it is more honest than varying the wording.
EMBEDDED = [
    ('CandidatePayload', 'CandidateManifest', 'canonical'),
    ('ExecutionKey', 'RunTransition', 'canonical'),
    ('MetricRef', 'CoverageCell', 'canonical'),
    ('ModuleUse', 'Hypothesis', 'canonical'),
    ('RunAttempt', 'RunTransition', 'canonical'),
    ('ReconciliationEvidence', 'SnapshotMeta', 'canonical'),
    ('SnapshotMeta', 'ControlRoomSnapshotV5', 'canonical'),
    ('SnapshotVerdict', 'ControlRoomSnapshotV5', 'derived'),
]

# OwnerRef is the design's universal pinning primitive: 12 entities embed it. Naming one parent would
# be a false precision, so it uses the rev-5 `EMBEDDED:*` form, whose parent list the checker verifies
# against the $ref graph.
OWNERREF_PARENTS = ['CandidateManifest', 'CoverageCell', 'DeploymentAttestationEvent', 'Hypothesis',
                    'IdeaRef', 'InstrumentProfile', 'MagicAllocation', 'ParameterBinding',
                    'RunJournal', 'RunTransition', 'SystemFinding', 'WorkReceipt']

ROWS = [
    # ---------------------------------------------------------------- THE COVERAGE EDGE (the point)
    dict(
        entity='CoverageCell',
        owner='MASTER_BACKLOG.md',
        proposed='factory/coverage.jsonl',
        disposition='TRANSFER',
        canonical_or_derived='canonical',
        breaks_if_moved=(
            'MEASURED 2026-07-30: nothing machine-reads section 2, so no automated reader breaks. '
            'The only parser of "## 2. COVERAGE MATRIX" anywhere in the repo is '
            '_triage/factory_os/check_s2a_migration.py:parse_section2, written for this order. '
            'scripts/check_state.ps1:124 opens MASTER_BACKLOG.md only to assert it contains the '
            'string "canonical entry =" (the owner banner) and never looks at the table; '
            'scripts/check_block_staleness.ps1:57 only lists the file as self-referential so that '
            'citing a verdict inside it is not read as staleness. The break is therefore HUMAN: the '
            'file\'s own banner says it owns the coverage matrix, so anyone who trusts the banner '
            'would keep hand-editing a table that had become generated output. Mitigation must be '
            'part of the transfer - the banner and the section header have to say "generated from '
            'factory/coverage.jsonl; edits here are overwritten" in the same commit that generates it.'
        ),
        breaks_if_not_moved=(
            'Already happening, not hypothetical. Design section 1.2 measured section 2 at 7 EA rows '
            'whose last real update was 2026-06-27, while portfolio/DEPLOYMENTS.csv carries 64 '
            'deployment rows; the two have never been reconciled at any granularity. So the declared '
            'owner of "which EA is tested on which symbol x TF" is a hand table five weeks stale '
            'against the fleet. TRIGGER: the next coverage question ("which symbol x TF is still '
            'untested?") is answered from that table - and the 2026-07-30 ORDER-430 finding that '
            'BWD passes were being read off trade counts nobody had looked at is the same failure '
            'mode one layer up: a number is trusted because it is written down somewhere canonical.'
        ),
        reverse_steps=(
            '1) git revert the generation commit, which restores section 2 to its pre-transfer bytes '
            '(it is tracked, so the prior table is recoverable exactly). '
            '2) delete factory/coverage.jsonl. '
            '3) remove the "generated - do not edit" line from the section-2 header and the owner '
            'banner. '
            '4) re-run scripts/check_state.ps1 and confirm the owner-banner assertion at line 124 '
            'still passes. '
            'No step depends on data that only exists after the transfer.'
        ),
        evidence_lost=(
            'Nothing, if the transfer is done as a generation from the existing table: the pre-transfer '
            'section 2 stays in git history and is recoverable by blob. What CANNOT be reconstructed '
            'is the provenance of any cell that was hand-edited after the transfer and before the '
            'reverse - those edits are overwritten by the next generation with no record that they '
            'existed, which is exactly the risk the "generated" banner exists to prevent.'
        ),
        retention_window=(
            'git history, indefinite - section 2 is a tracked file, so every pre-transfer revision is '
            'permanently addressable by commit+blob. No separate retention is required.'
        ),
    ),
    # ---------------------------------------------------------------- other TRANSFERs
    dict(
        entity='Hypothesis',
        owner='AGENT_TASKBOARD.md',
        proposed='factory/hypotheses.jsonl',
        disposition='TRANSFER',
        canonical_or_derived='canonical',
        same_blob_reason=('the taskboard is the current owner of two different facts in this table '
                          '(Hypothesis pre-registration and WorkReceipt order state), so both rows '
                          'legitimately pin the same blob'),
        breaks_if_moved=(
            'Nothing reads pre-registration mechanically today, and the transfer is deliberately '
            'partial, so the risk is duplication rather than breakage. Design section 1.3 #1 rules '
            'that the causal claim, falsifier and acceptance STAY in the taskboard row and '
            'factory/hypotheses.jsonl holds only machine-read fields plus a preregistration_ref. '
            'The reader that would break if that rule is ignored is .githooks/pre-commit, which '
            'enforces taskboard structure on every commit: a second copy of the claim would drift '
            'from the row the hook validates, and the hook cannot see the copy.'
        ),
        breaks_if_not_moved=(
            'No machine can currently answer "which hypotheses share an architecture digest or module '
            'set", because those fields exist only inside prose rows. TRIGGER: the next time a '
            'correlation question is asked across EAs - the concrete precedent is memory '
            'unmeasured-corr-costs-more-than-real-risk, where 1088 of 1540 pairs were still sitting '
            'on a default correlation of 1.0 because nothing held the machine-readable structure '
            'needed to compute them.'
        ),
        reverse_steps=(
            '1) delete factory/hypotheses.jsonl. '
            '2) drop the preregistration_ref column from any consumer written against it. '
            '3) run .githooks/pre-commit against a taskboard edit to confirm the structure '
            'assertions still pass. No taskboard row is rewritten by this transfer, so there is '
            'nothing to restore there.'
        ),
        evidence_lost=(
            'The revision chain: if a hypothesis is revised only in the jsonl and the file is deleted, '
            'which revision produced a given run can no longer be reconstructed - the taskboard row '
            'holds the claim but not the revision counter.'
        ),
        retention_window=(
            'git history, indefinite while the file is tracked. It must be tracked from its first '
            'commit for that to hold - an untracked jsonl has no retention at all.'
        ),
    ),
    dict(
        entity='CandidateManifest',
        owner='EA_SCORECARD_AND_REGISTRY.md',
        proposed='factory/candidates/',
        disposition='TRANSFER',
        canonical_or_derived='canonical',
        breaks_if_moved=(
            'scripts/check_state.ps1 asserts the scorecard carries its owner banner, and '
            'scripts/check_block_staleness.ps1 treats it as the index of every verdict ever written; '
            'AGENTS.md 2 reserves verdict text in this file to Claude/the user. The transfer must '
            'therefore move IDENTITY only (the immutable bundle: ex5 + locked .set + evidence + '
            'attestation), never verdict text - design section 1.3 #7. If verdict text were copied, '
            'the scorecard and the manifest could disagree and check_state.ps1 would still pass, '
            'because it checks the banner and not the content.'
        ),
        breaks_if_not_moved=(
            'Candidate identity is currently a filename convention, and it has already failed once: '
            'ORDER-410 step 1 found TrendRider looked MISSING on the VPS purely because the deploy '
            'bundle renamed the file, and only hash matching settled what filename matching got '
            'wrong. TRIGGER: the next deploy-vs-repo reconciliation repeats that, because nothing '
            'pins a candidate to its bytes.'
        ),
        reverse_steps=(
            '1) delete factory/candidates/. '
            '2) point any reader back at the scorecard row id. '
            '3) re-run scripts/check_state.ps1 (banner + no-duplicate assertions) and confirm CLEAN. '
            'The scorecard is not edited by this transfer, so no restore is needed.'
        ),
        evidence_lost=(
            'The candidate-to-bytes pin. After the reverse, a candidate can again only be identified '
            'by name, so any bundle that was renamed or recompiled in the interim can no longer be '
            'matched to the verdict that approved it - MQL5 compiles are not byte-reproducible '
            '(memory mql5-compile-not-byte-reproducible), so it cannot be recovered by rebuilding.'
        ),
        retention_window=(
            'git history, indefinite for the manifest; but the .ex5 blobs it points at are retained '
            'only as long as the evidence store keeps them - the manifest outliving its blobs is the '
            'real risk, not the manifest being lost.'
        ),
    ),
    dict(
        entity='MagicAllocation',
        owner='portfolio/DEPLOYMENTS.csv',
        proposed='factory/magic_allocations.jsonl',
        disposition='TRANSFER',
        canonical_or_derived='canonical',
        breaks_if_moved=(
            'This is the most-read file in the table and the transfer must NOT move deployment '
            'status. Real readers, verified 2026-07-30: scripts/check_state.ps1 (parses it as the '
            'inventory, asserts required columns and no duplicate account|magic), '
            'scripts/control_room_snapshot.ps1, scripts/live_dashboard.ps1, '
            'scripts/lib/monitor_coverage.ps1, scripts/mris/mris_exposure.ps1, '
            'scripts/check_precommit_staged.ps1. Design section 1.1 keeps the CSV as the write path '
            'and section 1.3 #8 limits the new artifact to a RESERVATION log that references '
            'Deployment. If it copied status, all six readers would keep reading the CSV while the '
            'jsonl drifted, and check_state.ps1\'s uniqueness check would not see the second copy.'
        ),
        breaks_if_not_moved=(
            'Magic reservation is currently implicit: a number is "taken" once it appears in a row of '
            'a deployed EA, so there is no way to reserve one before deploying. The failure this '
            'invites is on the board now - ORDER-511 was opened because the template EA sits on '
            'default magic 990001 and is ABSENT from DEPLOYMENTS.csv, i.e. a live magic that the '
            'inventory cannot see. TRIGGER: the next EA attached before its row is written.'
        ),
        reverse_steps=(
            '1) delete factory/magic_allocations.jsonl. '
            '2) revert any reader switched to it (the CSV was never demoted, so each reader\'s old '
            'code path is intact). '
            '3) run scripts/check_state.ps1 and confirm "no duplicate account|magic in inventory" '
            'and the 64-row parse still pass.'
        ),
        evidence_lost=(
            'Reservations that never became deployments. A magic reserved and then abandoned exists '
            'only in the allocation log - the CSV records deployments, so after a reverse there is '
            'no record that the number was ever spoken for, and it can be reissued to a second EA.'
        ),
        retention_window=(
            'git history, indefinite. Reservations must never be hard-deleted even when released, '
            'because a released-and-reissued magic is indistinguishable from a duplicate to every '
            'reader listed above.'
        ),
    ),
    dict(
        entity='ParameterBinding',
        owner='docs/PARAM_REGISTRY.csv',
        proposed='factory/parameter_bindings.jsonl',
        disposition='TRANSFER',
        canonical_or_derived='canonical',
        breaks_if_moved=(
            'The registry is machine-read on every commit: .githooks/pre-commit and '
            '.githooks/fast_tier_pathspec select on it, scripts/optimize_guard.ps1 reads it together '
            'with docs/PARAM_LINKAGE.md to classify parameters, and scripts/param_registry_check.ps1 '
            'and scripts/gen_param_linkage.ps1 both consume it. Design section 1.1 says EXTENDED, '
            'NOT REPLACED. A transfer that moved the parameter definitions rather than adding a '
            'binding layer would break the pre-commit tier itself, which is the worst possible '
            'failure surface: the guard that would catch the mistake is the thing being broken.'
        ),
        breaks_if_not_moved=(
            'Concrete and measured: design section 1.2 records 177/184 OptimizeStage and 181/184 '
            'SafeRange values as UNKNOWN, so the registry cannot answer "what may this parameter be '
            'set to" for 96% of identifiers. TRIGGER: every optimize run - the guard classifies from '
            'PARAM_LINKAGE override pairs while the safe range it would need is blank, which is how '
            'a grid gets built outside the range that contains the answer (memory '
            'grid-answer-outside-the-grid).'
        ),
        reverse_steps=(
            '1) delete factory/parameter_bindings.jsonl. '
            '2) revert scripts/optimize_guard.ps1 to read PARAM_LINKAGE.md alone. '
            '3) run scripts/_test/run_optimize_guard_tests.ps1 and scripts/param_registry_check.ps1 '
            '- both must be CLEAN before the reverse is considered done, because this path is '
            'pre-commit-load-bearing.'
        ),
        evidence_lost=(
            'Any binding that was only ever recorded in the jsonl - i.e. every safe range and stage '
            'filled in after the transfer. Those were never in the CSV, so a reverse discards the '
            'discovery work rather than restoring it.'
        ),
        retention_window=(
            'git history, indefinite. Before deleting, the filled-in ranges must be written back into '
            'PARAM_REGISTRY.csv or the reverse is destructive, not neutral.'
        ),
    ),
    dict(
        entity='RunTransition',
        owner='scripts/experiment_event_log.ps1',
        proposed='factory/runs/',
        disposition='TRANSFER',
        canonical_or_derived='canonical',
        breaks_if_moved=(
            'Design section 1.3 #5 splits this deliberately: the experiment event log OWNS the '
            'occurrence timeline and factory/runs/ owns ONLY the scheduler recovery checkpoint. The '
            'readers that break if the timeline moves are scripts/check_experiment_events.ps1 and '
            'scripts/_test/run_order105_negative_tests.ps1, both of which read the event log and its '
            'evidence manifest. Note the current_owner here is the SCRIPT, not a data file: the '
            'transition shape lives in the writer today, and the monthly JSONL it appends to is the '
            'store - so "moving" it means giving the scheduler its own checkpoint file, not '
            'relocating history.'
        ),
        breaks_if_not_moved=(
            'A killed run cannot be resumed, because no checkpoint is persisted. This has already '
            'cost real time: memory taskstop-does-not-kill-qwen-child records a worker that was '
            '"stopped" while its child kept holding the MT5 lane and committing, and the only way '
            'that was detected was by reading tasklist and git log afterwards. TRIGGER: the next '
            'interrupted overnight batch.'
        ),
        reverse_steps=(
            '1) delete factory/runs/. '
            '2) remove the checkpoint write from the scheduler. '
            '3) run scripts/check_experiment_events.ps1 to confirm the event log is unaffected - it '
            'must be, because this transfer never writes to it.'
        ),
        evidence_lost=(
            'In-flight state for any run that was interrupted and not yet folded into the event log: '
            'the attempt counter and the last completed step. The event log records completed '
            'occurrences, so a half-finished run leaves no trace there.'
        ),
        retention_window=(
            'per-run, until the run completes and its occurrence is written to the event log; the '
            'checkpoint is safe to prune after that, and MUST be pruned or it becomes a second, '
            'stale copy of the timeline.'
        ),
    ),
    dict(
        entity='InstrumentProfile',
        owner='ea_template/OPTIMIZATION_PROCEDURE_V2.md',
        proposed='factory/instrument_profiles.jsonl',
        disposition='TRANSFER',
        canonical_or_derived='canonical',
        breaks_if_moved=(
            'No script parses this document - it is procedure prose read by humans and by Claude, so '
            'nothing mechanical breaks. Design section 1.3 #4 restricts the new artifact to the '
            'broker/lane mapping layer plus a content_hash so a Candidate pins profile CONTENT rather '
            'than a mutable id. The break if that scope is exceeded is silent and expensive: '
            'baseline semantics copied into a jsonl would diverge from the procedure that '
            'backtest-optimize-rigor actually follows, and no test compares the two.'
        ),
        breaks_if_not_moved=(
            'The broker/lane mapping does not exist in machine-readable form, and the cost is '
            'measured: memory btc-tick-data-differs-per-mt5-install records the same EA, .set and '
            'window returning different PF across two MT5 installs, which is why cross-install '
            'comparison had to be banned outright (ORDER-371). TRIGGER: any A/B whose two legs land '
            'on different lanes - the ban is currently enforced by discipline, not by a profile a '
            'tool can check.'
        ),
        reverse_steps=(
            '1) delete factory/instrument_profiles.jsonl. '
            '2) drop the content_hash field from any Candidate written against it. '
            '3) confirm ea_template/OPTIMIZATION_PROCEDURE_V2.md is byte-unchanged (git diff must be '
            'empty) - this transfer never edits it.'
        ),
        evidence_lost=(
            'The content_hash pin. After a reverse, a Candidate references a profile by id again, so '
            'if the profile is edited there is no way to tell which content a past run used.'
        ),
        retention_window=(
            'git history, indefinite; profiles must be append-only rather than edited in place, or '
            'the content_hash pins something that no longer exists.'
        ),
    ),
    dict(
        entity='SystemFinding',
        owner='portfolio/control_room_snapshot.json',
        proposed='ops/findings.jsonl',
        disposition='TRANSFER',
        canonical_or_derived='canonical',
        same_blob_reason=('the snapshot is the current owner of two facts in this table - the '
                          'projection itself (ControlRoomSnapshotV5) and detector state '
                          '(SystemFinding) - so both rows pin the same blob by construction'),
        breaks_if_moved=(
            'Design section 1.3 #10 keeps detector STATE owned by the snapshot and gives '
            'ops/findings.jsonl only stable identity and lifecycle. Readers of the snapshot that '
            'would break if state moved: scripts/daily_monitor.ps1, scripts/lib/monitor_coverage.ps1, '
            'scripts/_test/run_monitor_integrity_tests.ps1, and '
            '_triage/factory_os/snapshot_validator.py. The specific hazard is that a finding whose '
            'lifecycle says RESOLVED while the snapshot still reports it firing would be an '
            'authoritative contradiction, and the monitor-integrity suite compares snapshots, not '
            'snapshots-against-a-second-store.'
        ),
        breaks_if_not_moved=(
            'A finding has no identity across runs, so it cannot be acknowledged, deferred, or '
            'proven fixed - each snapshot restates it as new. The cost is on record: memory '
            'stale-detector-masked-by-advisory-label describes a detector reporting 8 of 56 for an '
            'unknown period, and memory guard-disarmed-by-prose-reported-as-note describes a guard '
            'parsing zero rows and reporting NOTE. TRIGGER: the next detector regression - with no '
            'lifecycle, "this has been firing for four commits" is not a question the data can '
            'answer, which is precisely how that one survived.'
        ),
        reverse_steps=(
            '1) delete ops/findings.jsonl. '
            '2) revert readers to taking finding state from the snapshot directly. '
            '3) run scripts/_test/run_monitor_integrity_tests.ps1 and confirm it passes. '
            'The snapshot is generated by scripts/control_room_snapshot.ps1 and is not edited by '
            'this transfer, so it needs no restore.'
        ),
        evidence_lost=(
            'The acknowledgement and resolution history - who accepted a finding and when it was '
            'declared fixed. The snapshot holds only the current state, so after a reverse the '
            'question "was this ever acknowledged" becomes unanswerable.'
        ),
        retention_window=(
            'indefinite for resolved findings. A resolved finding that is deleted is indistinguishable '
            'from one that never fired, which would erase exactly the four-commit-blind-spot evidence '
            'the lifecycle exists to keep.'
        ),
    ),
    dict(
        entity='WorkReceipt',
        owner='AGENT_TASKBOARD.md',
        proposed='ops/receipts/',
        disposition='TRANSFER',
        signoff_state='REFUSED',
        canonical_or_derived='canonical',
        same_blob_reason=('the taskboard is the current owner of two different facts in this table '
                          '(Hypothesis pre-registration and WorkReceipt order state), so both rows '
                          'legitimately pin the same blob'),
        refused_reason=(
            'REFUSED BY THIS TABLE, not by the design. Design section 1.3 #9 states that opening this '
            'writer needs an AGENTS.md 2 permission change THE USER MUST RATIFY FIRST. AGENTS.md 2 '
            'currently allows an agent to write only its own order row on the taskboard, and '
            'reserves new orders to Claude/the user. Proposing the transfer now would be proposing '
            'a writer that the governance file forbids, so the honest state is REFUSED-pending-'
            'ratification rather than PROPOSED. This is the one row in the table that must not be '
            'signed as-is, and it is deliberately not uniform with the other eleven TRANSFERs.'
        ),
        breaks_if_moved=(
            'The taskboard is enforced mechanically on every commit: .githooks/pre-commit validates '
            'its structure, scripts/check_taskboard_archive.ps1 walks its archive chain, '
            'scripts/lib/b1_guard.ps1 requires a docs/memory_control/B1_DATASET.csv row in the same '
            'commit as any REVIEWED transition, and scripts/_test/run_statusclass_tests.ps1 cages the '
            'status classifier. A receipt store that duplicated order status would drift from all '
            'four. Design section 1.3 #9 is explicit that where an ORDER-* exists the taskboard owns '
            'title/status/owner/acceptance and the receipt only REFERENCES it.'
        ),
        breaks_if_not_moved=(
            'A commitment made in chat that never became an ORDER has no home, so it is invisible to '
            'every guard above. The measured cost is repetition: memory '
            'grep-destination-before-tasking-user records ORDER-230 being answered four hours BEFORE '
            'its order was written and then re-queued to the user twice more, the second such case '
            'in three days. TRIGGER: the next chat commitment that is not written as an order.'
        ),
        reverse_steps=(
            '1) delete ops/receipts/. '
            '2) revert the AGENTS.md 2 permission row to its pre-ratification text. '
            '3) run .githooks/pre-commit, scripts/_test/run_statusclass_tests.ps1 and '
            'scripts/_test/run_b1_guard_tests.ps1 - all three must pass, since they are the guards '
            'the receipt store sits beside.'
        ),
        evidence_lost=(
            'Chat-only commitments recorded nowhere else. Because they never became orders, deleting '
            'the receipt store erases them entirely - there is no second copy in the taskboard to '
            'fall back to, which is the whole reason the entity was proposed.'
        ),
        retention_window=(
            'not applicable until the user ratifies the AGENTS.md 2 change; no receipt may be written '
            'before then, so nothing is yet in a retention window.'
        ),
    ),
    # ---------------------------------------------------------------- UNOWNED (rev 5)
    dict(
        entity='TestUniverse',
        owner=chk.UNOWNED,
        proposed='factory/universe.jsonl',
        disposition='TRANSFER',
        canonical_or_derived='canonical',
        unowned_evidence=DESIGN,
        breaks_if_moved=(
            'Nothing breaks, because nothing reads it - there is no artifact to break. Design '
            'section 1.3 #2 is the audited verdict: "genuinely unowned. No canonical artifact exists '
            'for a versioned mandatory symbol x TF set." This row therefore CREATES a first owner '
            'rather than moving one, and the only risk is the mirror image of a transfer risk: the '
            'new file becomes a second de-facto coverage list competing with MASTER_BACKLOG.md '
            'section 2. The Coverage edge row above must land first or together, so that coverage '
            'cells and the universe they are drawn from have one source each.'
        ),
        breaks_if_not_moved=(
            '"Mandatory symbol x TF" is not expressible, so a screen can silently skip a cell and '
            'nothing notices. This is measured, not theoretical: memory '
            'bar-cleared-by-non-participation found hosts that "passed" BWD on 52-62 trades over '
            'three years while failing hosts took 343-473, i.e. a bar cleared by absence from the '
            'market - and there is no universe definition against which "did this actually trade the '
            'mandatory set" could be checked. TRIGGER: the next both-window screen.'
        ),
        reverse_steps=(
            '1) delete factory/universe.jsonl. '
            '2) unregister any reader. Nothing is restored because nothing was moved - this row '
            'creates an owner where design section 1.3 says none exists, so the reverse is a plain '
            'deletion and cannot damage an existing owner.'
        ),
        evidence_lost=(
            'The version history of the mandatory set: which symbol x TF cells were mandatory at the '
            'time a past screen ran. That is unreconstructable after deletion, because it exists '
            'nowhere else today - which is the same reason the fact is unowned.'
        ),
        retention_window=(
            'git history, indefinite, and the file must be versioned rather than edited in place - a '
            'mandatory set that is mutated silently is worse than none, because past verdicts would '
            'appear to have been judged against the current set.'
        ),
    ),
    dict(
        entity='LogicalSymbol',
        owner=chk.UNOWNED,
        proposed='factory/universe.jsonl',
        disposition='TRANSFER',
        canonical_or_derived='canonical',
        unowned_evidence=DESIGN,
        breaks_if_moved=(
            'Nothing reads it because it does not exist; design section 1.4 area (line 225) states '
            'the mapping - "LogicalSymbol -> broker symbol per lane (XAUUSD | GOLD | XAUUSDm; DE40 '
            'traded as GER40)" - and decision 26 keeps LogicalSymbol separate from the broker string. '
            'The risk on creation is that the mapping is embedded in the universe file and then '
            'copied into .set generation, giving two answers for one symbol.'
        ),
        breaks_if_not_moved=(
            'CORRECTED after Codex audit 7, which caught this row citing a memory for the OPPOSITE '
            'of what it says. The removed claim was that '
            'mt5-selfupdate-breaks-startup-ini-and-pid-kill records "a symbol-identity failure '
            'diagnosed as a network one". That memory says the reverse in as many words: the '
            '"symbol synchronization timeout" was NOT a symbol problem at all - the terminal was '
            'simply never authorised, because a login made without /portable stores credentials in '
            'a different data folder. Citing it here inverted its causality to make it support a '
            'symbol registry. '
            'The honest statement of the gap: the logical-to-broker symbol mapping exists only as '
            'per-script convention, so nothing can mechanically check that two runs traded the same '
            'instrument. The concrete cost on record is ORDER-371, which had to BAN cross-install '
            'comparison outright after memory btc-tick-data-differs-per-mt5-install measured the '
            'same EA, .set and window returning different PF on two MT5 installs. That ban is '
            'enforced by discipline today; a versioned symbol identity is what would let a tool '
            'enforce it. TRIGGER: the next A/B whose two legs land on different lanes '
            '(D:\\Meta 5 / 5b / 5c).'
        ),
        reverse_steps=(
            '1) delete factory/universe.jsonl (shared with TestUniverse - if only this fact is being '
            'reversed, remove the symbol-alias block and leave the mandatory set). '
            '2) revert readers to their per-script alias handling, which is still present because '
            'nothing is removed by this proposal.'
        ),
        evidence_lost=(
            'Which broker string a past run actually traded, for any run recorded only by logical '
            'symbol after the transfer. Before the transfer that information is implicit in the '
            'report file; after a reverse, rows written in between have no way to name the alias.'
        ),
        retention_window=(
            'git history, indefinite; aliases must be added, never rewritten, because a rewritten '
            'alias retroactively changes what a past run is understood to have traded.'
        ),
    ),
    dict(
        entity='SafeProjection',
        owner=chk.UNOWNED,
        proposed='build/safe_projection.json',
        disposition='TRANSFER',
        canonical_or_derived='derived',
        unowned_evidence=DESIGN,
        breaks_if_moved=(
            'Nothing exists to break: no file, and no code computes it. Design section 1.3 naming '
            'rule places generated projections under build/ and states they are never edited. The '
            'real hazard on creation is the one design section 1.2 already caught once - '
            'scripts/live_dashboard.ps1 held a global $BaseEquity = 10000 as one denominator for six '
            'accounts while portfolio/ACCOUNTS.csv records 100000 for 463666728 and blank for five. A '
            'projection that recomputes such a constant locally instead of reading the owner '
            'reintroduces exactly that bug.'
        ),
        breaks_if_not_moved=(
            'There is no vetted read surface, so every consumer reads raw owners and re-derives its '
            'own numbers - which is how the $BaseEquity divergence above survived across six '
            'accounts. TRIGGER: the next dashboard or status surface added; STATUS.html and '
            'STATUS.md are already recorded in design section 1.2 as stale and disagreeing with '
            'fresher sources.'
        ),
        reverse_steps=(
            '1) delete build/safe_projection.json and its generator. '
            '2) point consumers back at the owners directly. Nothing is restored, because nothing was '
            'moved: this is a derived artifact and the owners were never demoted.'
        ),
        evidence_lost=(
            'Nothing that is not recomputable. It is derived by definition, so a deleted projection '
            'can be regenerated from its owners - provided the generator is reverted with it. If the '
            'generator is deleted but a past projection is not, the stale file becomes an '
            'unfalsifiable claim, which is the failure mode to guard.'
        ),
        retention_window=(
            'none required - regenerate on demand. Under build/ it should not be committed at all, '
            'so there is nothing to retain and nothing to go stale in git.'
        ),
    ),
    dict(
        entity='RunJournal',
        owner=chk.UNOWNED,
        proposed=chk.UNOWNED,
        disposition='KEEP',
        canonical_or_derived='derived',
        # Codex audit 7: the declared evidence for RunJournal is the SCHEMA, which states the claim
        # ("Never persisted, never written") outright. The design does not.
        unowned_evidence='_triage/factory_os/schemas.json',
        keep_reason=(
            'correctly owned by nobody, now and after: the schema declares it x-derived and '
            '"NONE - derived by folding the RunTransition lines of one run_id. Never persisted, never '
            'written." Persisting a fold of an append-only log creates a second copy that can '
            'disagree with the log, so KEEP here means "never give this an owner", which is a '
            'decision rather than a default - and it is the reason this row is the only UNOWNED + '
            'KEEP in the table.'
        ),
        breaks_if_moved=(
            'Persisting it WOULD break the guarantee that RunTransition is the single append-only '
            'truth for a run. The reader that makes this concrete is any consumer of the folded '
            'state: given a stored journal and the transitions it came from, nothing recomputes one '
            'from the other, so a divergence would be invisible. This is the defect shape this '
            'slice has hit three times in one day - recompute one half, trust the other.'
        ),
        breaks_if_not_moved=(
            'Nothing. Folding on read is O(transitions per run_id) and no measurement suggests that '
            'is a cost; if it ever becomes one, the fix is a build/ projection under the section-1.3 '
            'naming rule, not an owner.'
        ),
        reverse_steps=(
            'None required - nothing is created. To reverse the DECISION (i.e. to start persisting '
            'it) the steps would be: 1) add the store, 2) add a recompute-on-read check that folds '
            'the transitions and refuses a stored journal that disagrees, 3) only then let any '
            'reader trust the stored copy.'
        ),
        evidence_lost=(
            'Nothing, because nothing is stored. The evidence remains the RunTransition lines, whose '
            'retention is governed by that row rather than this one.'
        ),
        retention_window=(
            'not applicable - never persisted, so it never enters a retention window. Its inputs are '
            'retained by the RunTransition row.'
        ),
    ),
    # ---------------------------------------------------------------- KEEPs on real owners
    dict(
        entity='ControlRoomSnapshotV5',
        owner='portfolio/control_room_snapshot.json',
        proposed='portfolio/control_room_snapshot.json',
        disposition='KEEP',
        canonical_or_derived='derived',
        same_blob_reason=('the snapshot is the current owner of two facts in this table - the '
                          'projection itself and detector state (SystemFinding) - so both rows pin '
                          'the same blob by construction'),
        keep_reason=(
            'design section 1.1 is explicit: scripts/control_room_snapshot.ps1 -> '
            'portfolio/control_room_snapshot.json "is already the single-projection pattern the '
            'handoff asks for. Extend it; do not write a second one." The v4/v5 schema migration is '
            'a change of SHAPE, not of owner, and belongs to S4.'
        ),
        breaks_if_moved=(
            'scripts/daily_monitor.ps1, scripts/lib/monitor_coverage.ps1, '
            'scripts/_test/run_monitor_integrity_tests.ps1 and '
            '_triage/factory_os/snapshot_validator.py all read this path; a second projection would '
            'split them. NOTE, measured while writing this row: the schema x-owner-file says '
            '"(EXISTING, v4 at HEAD)" but the file at HEAD carries "version": 3, and design '
            'section 1.1 also says v3. The prose is wrong about the version - filed as an observation '
            'for S4, not fixed here, because this order writes a proposal about ownership and the '
            'version is not an ownership fact.'
        ),
        breaks_if_not_moved=(
            'Nothing about OWNERSHIP. The open defects on this artifact are S4 items already named in '
            'the predecessor handoff (the real snapshot still fails the V5 schema; verify_snapshot '
            'proves internal consistency rather than authenticity; no reader calls load_verified). '
            'None of them is fixed by changing owner, which is why this row is KEEP.'
        ),
        reverse_steps=KEEP_REVERSE,
        evidence_lost=KEEP_NO_LOSS,
        retention_window=KEEP_RETENTION,
    ),
    dict(
        entity='SnapshotBuilderInput',
        owner='_triage/factory_os/snapshot_validator.py',
        proposed='_triage/factory_os/snapshot_validator.py',
        disposition='KEEP',
        canonical_or_derived='derived',
        keep_reason=(
            'transient by contract - the schema says "NONE - transient. Produced by the snapshot '
            'builder, consumed by snapshot_validator, never persisted." Its only home today is the '
            'module that defines and validates its shape, and that module is a real tracked file, so '
            'this row names a genuine current owner rather than taking the UNOWNED exemption.'
        ),
        breaks_if_moved=(
            'Persisting the builder input would create a third artifact between the sources and the '
            'snapshot, and _triage/factory_os/snapshot_validator.py would then have two candidate '
            'inputs with no rule for which wins. The suite that would NOT catch it is '
            '_triage/factory_os/run_snapshot_validator_tests.py, which drives the validator with '
            'fixtures rather than from a store.'
        ),
        breaks_if_not_moved=(
            'Nothing today. The named gap is wiring, not ownership: BUILT_NOT_WIRED - no reader calls '
            'load_verified(), so the single door is not yet in front of anything. That is a '
            'BACKLOG-D30 item and is not addressed by giving this shape a file.'
        ),
        reverse_steps=KEEP_REVERSE,
        evidence_lost=KEEP_NO_LOSS,
        retention_window=KEEP_RETENTION,
    ),
    dict(
        entity='EvidenceRef',
        owner='docs/memory_control/experiment_events/evidence-manifest.jsonl',
        proposed='docs/memory_control/experiment_events/evidence-manifest.jsonl',
        disposition='KEEP',
        canonical_or_derived='canonical',
        keep_reason=(
            'design section 1.3 #6: owned, with its own schema, and "no new index. Register through '
            'the existing utility." The manifest already stores exactly the {path, commit_oid, '
            'blob_oid, raw_sha256} shape this order recomputes for every owner_ref, so it is the '
            'precedent for the pinning discipline rather than a candidate for replacement.'
        ),
        breaks_if_moved=(
            'scripts/experiment_event_log.ps1 writes it, scripts/check_experiment_events.ps1 '
            'validates it, and scripts/_test/run_order105_negative_tests.ps1 asserts its negative '
            'cases. A second index would break the pin that makes evidence addressable, and the '
            'negative suite would keep passing against the old one.'
        ),
        breaks_if_not_moved=(
            'Nothing. Design section 1.3 #6 says only the blob STORE location is arguably new, which '
            'is a storage question and not an ownership one.'
        ),
        reverse_steps=KEEP_REVERSE,
        evidence_lost=KEEP_NO_LOSS,
        retention_window=KEEP_RETENTION,
    ),
    dict(
        entity='DeploymentAttestationEvent',
        owner='portfolio/ATTESTATION_MAP.csv',
        proposed='portfolio/ATTESTATION_MAP.csv',
        disposition='KEEP',
        canonical_or_derived='canonical',
        keep_reason=(
            'design section 1.1 reuses this file directly for Candidate/Deployment identity '
            '(section 5.6). The schema\'s x-owner-file also mentions an "append-only event log" '
            'beside the CSV; that log is NOT proposed here, because no PLANNED_PATHS entry declares '
            'it and inventing a destination inside a proposal is how a table starts proposing things '
            'nobody scoped. The gap is recorded in breaks_if_not_moved instead.'
        ),
        breaks_if_moved=(
            'scripts/control_room_snapshot.ps1 reads this CSV to attribute a deployment to a bundle; '
            'moving it would break the snapshot\'s attestation column, which is one of the six '
            'sensors the reconciliation verdict is computed from.'
        ),
        breaks_if_not_moved=(
            'Attestation has no history: the CSV holds the current mapping, so "when did this magic '
            'start running this bundle" is unanswerable. That is not hypothetical - memory '
            'live-fleet-runs-pre-132-binaries records the live fleet running pre-ORDER-132 binaries '
            'with the finding established from disk dates and terminal Global Variables rather than '
            'from any attestation record, and memory attach-verify-gate-and-binary records a crypto '
            'leg dead silently for three days behind a bundled .set with AllowLive=false. TRIGGER: '
            'the next binary-vs-repo divergence.'
        ),
        reverse_steps=KEEP_REVERSE,
        evidence_lost=KEEP_NO_LOSS,
        retention_window=KEEP_RETENTION,
    ),
    dict(
        entity='IdeaRef',
        owner='INTAKE_QUEUE.md',
        proposed='INTAKE_QUEUE.md',
        disposition='KEEP',
        canonical_or_derived='canonical',
        keep_reason=(
            'design section 1.3 #11 is unusually direct: the file "opens by declaring itself the '
            'single place for every new source/strategy drop", so there is to be "no ops/ideas.csv". '
            'Stable ID and exact-URL dedupe are added AS COLUMNS on the existing owner, and the '
            'Factory OS holds only a read projection.'
        ),
        breaks_if_moved=(
            'No script reads INTAKE_QUEUE.md - verified 2026-07-30, git grep over scripts/ and '
            '.githooks/ returns nothing - so the break would be entirely human, and worse for it: '
            'the file instructs the user where to drop new EAs. A competing ops/ideas.csv would mean '
            'drops landing in a queue nobody processes.'
        ),
        breaks_if_not_moved=(
            'Duplicate intake is possible because nothing enforces exact-URL dedupe; the corpus '
            'memories exist specifically to stop re-hunting the same sources (quantcorner, '
            'fxdreema, ssrn-151, wobr are each recorded as "do not re-hunt"). TRIGGER: the next '
            'corpus drop. This is a COLUMN addition on this owner, not a transfer, which is why the '
            'row is KEEP.'
        ),
        reverse_steps=KEEP_REVERSE,
        evidence_lost=KEEP_NO_LOSS,
        retention_window=KEEP_RETENTION,
    ),
]


# ---------------------------------------------------------------------------------------------
def git_out(*args):
    p = subprocess.run(('git',) + args, capture_output=True)
    if p.returncode != 0:
        raise SystemExit('git %s failed: %s' % (' '.join(args), p.stderr.decode('utf-8', 'replace')))
    return p.stdout


def head_oid():
    return git_out('rev-parse', 'HEAD').decode().strip()


# Memoized for the same content-addressed reason as in check_s2a_migration.py, and measured for the
# same reason: run_s2a_migration_tests.py PART 2 calls build_rows() three times per run, each
# resolving ~14 pins with 2 git spawns apiece. Un-memoized that took the suite from 2.9s to 5.1s and
# the tier to 18.8s. A `commit:path` cannot change its answer inside one process.
_REF_MEMO = {}


def owner_ref_for(path, commit):
    """RECOMPUTED, never typed: resolve the blob at `commit` and hash its actual bytes."""
    key = (commit, path)
    if key not in _REF_MEMO:
        blob = git_out('rev-parse', '%s:%s' % (commit, path)).decode().strip()
        raw = git_out('cat-file', 'blob', blob)
        _REF_MEMO[key] = {'path': path, 'commit_oid': commit, 'blob_oid': blob,
                          'raw_sha256': hashlib.sha256(raw).hexdigest()}
    return dict(_REF_MEMO[key])


def build_rows(pins=None):
    """pins: {entity: commit_oid} to honour instead of HEAD.

    WHY THIS PARAMETER EXISTS -- a defect I shipped and caught one commit later.
    `--check` originally regenerated against HEAD and compared. That made the drift guard go RED on
    every commit AFTER the one that generated D1: HEAD had moved, so every recomputed `commit_oid`
    differed and the guard reported STALE for a reason that is not drift. A pre-commit check that
    fails for an unrelated reason is exactly how someone ends up reaching for --no-verify.

    The confusion was between two different questions, and only the first belongs to this guard:
      1. is D1's CONTENT still what the generator produces?   <- real drift, must be enforced
      2. is D1's PIN at the current HEAD?                     <- must NOT be required. A pin is a
         historical claim ("at commit X this owner was this blob"); pinning would be pointless if it
         had to track HEAD. C4 already asks the right question of a pin -- does it still RESOLVE and
         does the blob still hash to what is recorded -- and an old pin passes that correctly.
    So --check honours the recorded pins and compares everything else. Moving the pins forward needs
    no flag: a plain (write-mode) run always re-pins at HEAD, which is the deliberate act.
    (/scrutinize removed a `--repin` switch here that only suppressed pin-honouring INSIDE --check --
    i.e. it re-created the very bug described above, and did nothing at all outside --check. A flag
    whose documented purpose is already the default behaviour is surface that can only mislead.)
    """
    commit = head_oid()
    out = []
    for e, parent, cd in EMBEDDED:
        out.append({
            'entity': e,
            'current_owner': 'EMBEDDED:%s' % parent,
            'proposed_owner': 'EMBEDDED:%s' % parent,
            'disposition': 'KEEP',
            'keep_reason': KEEP_EMBEDDED,
            'canonical_or_derived': cd,
            'owner_ref': None,
            'owner_ref_absent_reason': NO_BLOB_EMBEDDED,
            'breaks_if_moved': ('nothing can move independently: %s is a sub-object of %s and has no '
                                'storage of its own. Verified against the schema $ref graph rather '
                                'than its prose.' % (e, parent)),
            'breaks_if_not_moved': ('nothing - it is not proposed for transfer. It follows %s '
                                    'wherever that row goes.' % parent),
            'signoff_owner': LEAD,
            'signoff_state': 'PROPOSED',
            'reverse_steps': ('none - nothing is moved. Reversing the PARENT row (%s) reverses this '
                              'one with it, by construction.' % parent),
            'evidence_lost': 'nothing - no data moves',
            'retention_window': ('follows %s; this fact has no independent retention because it has '
                                 'no independent storage' % parent),
        })
    out.append({
        'entity': 'OwnerRef',
        'current_owner': 'EMBEDDED:*',
        'proposed_owner': 'EMBEDDED:*',
        'embedded_in': OWNERREF_PARENTS,
        'disposition': 'KEEP',
        'keep_reason': ('the design\'s universal pinning primitive - %d entities embed it, so naming '
                        'a single parent would be false precision. It owns no file and cannot: it IS '
                        'the pin (commit + blob + sha256) that lets an artifact hold a fact it does '
                        'not own, per design section 1.3.' % len(OWNERREF_PARENTS)),
        'canonical_or_derived': 'canonical',
        'owner_ref': None,
        'owner_ref_absent_reason': NO_BLOB_EMBEDDED,
        'breaks_if_moved': ('it cannot move - it is a field shape, not a record. If its definition '
                            'changed, all %d embedding entities would need re-pinning at once, and '
                            'the reader that would catch a bad pin is '
                            '_triage/factory_os/check_s2a_migration.py C4 plus '
                            'scripts/check_experiment_events.ps1 for the evidence manifest, which '
                            'already stores this exact shape.' % len(OWNERREF_PARENTS)),
        'breaks_if_not_moved': 'nothing - not proposed for transfer.',
        'signoff_owner': LEAD,
        'signoff_state': 'PROPOSED',
        'reverse_steps': ('none - nothing is moved. A change to the pin shape would be reversed by '
                          'reverting the schema commit and re-running gen_design_contracts.py '
                          '--check, which fails if the design and schema disagree.'),
        'evidence_lost': 'nothing - no data moves',
        'retention_window': ('follows each embedding entity; the pin has no storage and therefore no '
                             'retention of its own'),
    })
    for spec in ROWS:
        owner = spec['owner']
        row = {
            'entity': spec['entity'],
            'current_owner': owner,
            'proposed_owner': spec['proposed'],
            'disposition': spec['disposition'],
            'canonical_or_derived': spec['canonical_or_derived'],
            'breaks_if_moved': spec['breaks_if_moved'],
            'breaks_if_not_moved': spec['breaks_if_not_moved'],
            'signoff_owner': SIGNERS[owner],
            'signoff_state': spec.get('signoff_state', 'PROPOSED'),
            'reverse_steps': spec['reverse_steps'],
            'evidence_lost': spec['evidence_lost'],
            'retention_window': spec['retention_window'],
        }
        if owner == chk.UNOWNED:
            row['owner_ref'] = None
            row['owner_ref_absent_reason'] = NO_BLOB_UNOWNED
            row['unowned_evidence'] = spec['unowned_evidence']
        else:
            row['owner_ref'] = owner_ref_for(owner, (pins or {}).get(spec['entity']) or commit)
        for k in ('keep_reason', 'same_blob_reason', 'refused_reason'):
            if spec.get(k):
                row[k] = spec[k]
        out.append(row)
    return out


# ---------------------------------------------------------------------------------------------
# C8. The LIVE cells are DECLARED here and CROSS-CHECKED against check_s2a_migration.parse_section2.
# Deriving them with the same parser the checker uses would make C8's LIVE-subset assertion
# tautological; declaring them and demanding the two derivations agree is the discipline that
# produced the trusted 7/8 in the first place. If they disagree, this script refuses to write.
DECLARED_LIVE = {
    'Matchagrid MG_v1': ['CHFJPY M15'],
    'NuiIndy RSI+ADX': ['EURUSD H1'],
    'ST_EA03 MACD': ['GBPUSD H1', 'USDCAD H1'],
    'Gold Reaper 4.3': ['XAUUSD H1'],
    'EA_BREAKOUT_XAU': ['XAUUSD H1'],
    'LondonConsoBreakout': ['GBPUSD H1'],
    'EA_RUNNER_ST03 (framework)': ['GBPUSD H1'],
}

# Every non-LIVE cell in section 2's last column: (label, declared status, SOURCE TOKEN).
#
# The third element is Codex audit 7's fix and it is the point of the whole structure: it is the exact
# substring of section 2 the cell was derived from, and the checker requires it to appear verbatim in
# that row's other-symbols column. Before this, C8 counted cells and believed them -- 32 copies of the
# bare string "junk" passed.
#
# It also forced two cells to become honest. `XAUUSD H4` and `GBPUSD H4` were labelled UNVERIFIED_IMPORT
# "because the source states no timeframe", which is the opposite of true: the source states ONLY the
# timeframe ("H4 = smoke", "H4 yang mai long"), and it is the SYMBOL that is inherited from the row's
# LIVE cell. Their source token is `H4`, and their reason now says so.
#
# Labels are verbatim from the table - 'EUR', 'AUD', 'NZD' stay as written precisely because they are
# ambiguous and must not be silently expanded into currency pairs that were never tested.
OTHER = {
    'Matchagrid MG_v1': [],
    'NuiIndy RSI+ADX': [('GBPUSD', 'REJECT_DD37', 'GBPUSD'),
                        ('USDJPY', 'REJECT_WIPEOUT', 'USDJPY'),
                        ('AUDJPY', 'REJECT_WIPEOUT', 'AUDJPY')],
    'ST_EA03 MACD': [('EUR', 'REJECT', 'EUR'), ('USDJPY', 'REJECT', 'USDJPY'),
                     ('EURJPY', 'REJECT', 'EURJPY'), ('XAU', 'REJECT', 'XAU'),
                     ('GBPJPY', 'REJECT', 'GBPJPY'), ('EURGBP', 'REJECT', 'EURGBP'),
                     ('AUD', 'REJECT', 'AUD'), ('NZD', 'REJECT', 'NZD'),
                     ('GBPCAD', 'REJECT', 'GBPCAD'), ('EURCAD', 'REJECT', 'EURCAD'),
                     ('CADJPY', 'REJECT', 'CADJPY'),
                     ('GBPCHF', 'PASS_BUT_CORRELATED', 'GBPCHF')],
    'Gold Reaper 4.3': [],
    'EA_BREAKOUT_XAU': [('US30', 'DEAD', 'US30'), ('WTI', 'DEAD', 'WTI'),
                        ('BRENT', 'DEAD', 'BRENT'), ('XAGUSD', 'DEAD', 'XAGUSD'),
                        ('GBPJPY', 'DEAD', 'GBPJPY'),
                        ('USDJPY', 'REJECT_AFTER_OPTIMIZE', 'USDJPY'),
                        ('XAUUSD H4', 'SMOKE_IN_PROGRESS', 'H4')],
    'LondonConsoBreakout': [('EURUSD', 'DROPPED', 'EURUSD'), ('GBPJPY', 'DEAD', 'GBPJPY'),
                            ('GBPCAD', 'DEAD', 'GBPCAD'), ('EURGBP', 'DEAD', 'EURGBP'),
                            ('USDCAD', 'DEAD', 'USDCAD'),
                            ('GBPUSD H4', 'NOT_ATTEMPTED', 'H4')],
    'EA_RUNNER_ST03 (framework)': [('USDCAD', 'FAIL', 'USDCAD'), ('EUR', 'FAIL', 'EUR'),
                                   ('AUD', 'FAIL', 'AUD'), ('NZD', 'FAIL', 'NZD')],
}


def build_coverage():
    parsed = chk.parse_section2()
    if parsed is None:
        raise SystemExit('parse_section2 found no section 2 - refusing to write a reconciliation '
                         'against nothing')
    # Two independent derivations must agree, or nothing is written.
    parsed_map = {r['source_row']: r['live_cells'] for r in parsed}
    if set(parsed_map) != set(DECLARED_LIVE):
        raise SystemExit('source rows disagree.\n  parsed  : %s\n  declared: %s'
                         % (sorted(parsed_map), sorted(DECLARED_LIVE)))
    for row, cells in sorted(parsed_map.items()):
        if cells != DECLARED_LIVE[row]:
            raise SystemExit('LIVE cells disagree for %r.\n  parsed  : %s\n  declared: %s'
                             % (row, cells, DECLARED_LIVE[row]))
    mapping = []
    for r in parsed:
        row = r['source_row']
        cells = [{'cell': c, 'status': 'LIVE', 'column': 'LIVE cell'}
                 for c in DECLARED_LIVE[row]]
        for sym, status, token in OTHER[row]:
            symbol_inherited = token != sym.split()[0]
            cells.append({
                'cell': sym,
                'status': 'UNVERIFIED_IMPORT',
                'declared_status': status,
                'column': 'symbol other-tried -> result',
                # the order requires source coordinates, not just the label
                'source_coordinates': {
                    'file': 'MASTER_BACKLOG.md',
                    'section': chk.SECTION2_HEADING,
                    'source_row': row,
                    'column_index': 5,
                },
                # verbatim substring of the source column; C8 re-finds it there
                'source_token': token,
                'why_unverified': (
                    ('the source states only the timeframe %r; the SYMBOL is inherited from this '
                     'row\'s LIVE cell rather than stated in the source, so the pairing is an '
                     'inference' % token) if symbol_inherited else
                    ('the cell states a symbol and an outcome but no timeframe, so a symbol x TF '
                     'cell cannot be constructed from it without guessing')),
            })
        mapping.append({'source_row': row, 'cells': cells})
    return {
        'note': ('ORDER-600 C8. Two numbers with a mapping between them, NEVER equated. '
                 'source_rows_consumed counts EA rows in MASTER_BACKLOG.md section 2; cells_emitted '
                 'counts normalised cells across both the LIVE column and the other-tried column. '
                 'They differ by construction: ST_EA03 alone carries two LIVE cells.'),
        'recomputed_from': {'file': 'MASTER_BACKLOG.md', 'section': chk.SECTION2_HEADING,
                            'parser': '_triage/factory_os/check_s2a_migration.py:parse_section2'},
        'source_rows_consumed': len(mapping),
        'cells_emitted': sum(len(m['cells']) for m in mapping),
        'live_cells_only': sum(len(DECLARED_LIVE[m['source_row']]) for m in mapping),
        'mapping': mapping,
    }


def render(rows, cov):
    jsonl = ''.join(json.dumps(r, ensure_ascii=True, sort_keys=True) + '\n' for r in rows)
    covtxt = json.dumps(cov, ensure_ascii=True, indent=2, sort_keys=True) + '\n'
    return jsonl, covtxt


def main(argv):
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)
    pins = None
    if '--check' in argv and os.path.exists(chk.MIGRATION_PATH):
        pins = {}
        for line in io.open(chk.MIGRATION_PATH, encoding='utf-8'):
            if not line.strip():
                continue
            obj = json.loads(line)
            if obj.get('owner_ref'):
                pins[obj['entity']] = obj['owner_ref']['commit_oid']
    rows = build_rows(pins)
    cov = build_coverage()
    jsonl, covtxt = render(rows, cov)
    if '--check' in argv:
        bad = 0
        for path, want in ((chk.MIGRATION_PATH, jsonl), (chk.COVERAGE_PATH, covtxt)):
            got = io.open(path, encoding='utf-8').read() if os.path.exists(path) else None
            if got != want:
                print('[STALE] %s differs from what this generator produces' % path)
                bad = 1
            else:
                print('[OK] %s matches the generator' % path)
        return bad
    for path, text in ((chk.MIGRATION_PATH, jsonl), (chk.COVERAGE_PATH, covtxt)):
        with io.open(path, 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(text)
        print('[WROTE] %s' % path)
    print('  %d rows · %d source rows · %d cells emitted (%d LIVE)'
          % (len(rows), cov['source_rows_consumed'], cov['cells_emitted'], cov['live_cells_only']))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
