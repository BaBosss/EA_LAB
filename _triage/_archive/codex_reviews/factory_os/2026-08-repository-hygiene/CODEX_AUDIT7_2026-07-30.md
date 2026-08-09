# Codex audit 7 — S2a ownership migration and ORDER-601 re-check

Date: 2026-07-30  
Audited HEAD: `c46d53c06d20ba4ea945fbde70b3065865bb19ec`  
Mode: independent, adversarial, read-only except this report  
Canonical-status note: the labels below are this audit's assessment only. This report does not edit the
taskboard, scorecard, design, or any project verdict.

## 1. Requested assessments

### ORDER-600: **NOT DONE**

The committed D1 and D2 are substantial and the current D1's pins and coverage transcription are mostly
sound. That does not close the order. I produced a replacement D1 and coverage reconciliation that:

- keeps the Coverage edge at `MASTER_BACKLOG.md`;
- makes one nonsensical transfer, `OwnerRef -> factory/universe.jsonl`;
- declares 26 of 27 entities `UNOWNED`, including entities that plainly are not;
- marks every row `REFUSED`;
- replaces all 32 non-LIVE coverage cells with 32 copies of the bare string `"junk"`; and
- uses one-character human-review fields.

The unmodified checker reported all nine criteria `[OK]` and exited `0`.

This is the same failure class ORDER-600 rev 2 was written to remove: the acceptance can still be met
while defeating the purpose. The current mutation suite is green because it does not contain this
combined semantic attack.

The human-review half is also not satisfied. Four of the twelve TRANSFER rows cite evidence that does
not establish the claimed failure; one of them states the opposite of its cited memory.

### ORDER-601: **NOT REVIEWED-able yet**

The validator implementation fixes the load-bearing defects from audit 6:

- `reconciliation_clear` is honestly narrow in the schema and module;
- a supplied answer is rejected;
- arbitrary schema-gate callables are refused;
- negative counts and boolean coercion are refused;
- focused AJV diagnostics work;
- the semantic identity-swap fixture and expanded harness are present; and
- the visible-link regressions are present.

All relevant suites are green. Its known S4 limitations are now stated honestly in the implementation:
verification proves internal consistency, not authenticity; the real v3 snapshot fails the v5 target;
and no production reader calls `load_verified()`. Those limitations do not by themselves reopen
ORDER-601.

It is not ready for `REVIEWED`, however, because the current design still contradicts that scoped
implementation:

- `_triage/EA_LAB_FACTORY_OS_DESIGN.md:953` still says S3 computes `all_clear`;
- line 1115 still marks global `ALL CLEAR` **FIXED** because `all_clear` is computed; and
- line 1179 still says the `all_clear` builder/output boundary is unspecified.

Those are current roadmap/audit-status statements, not merely an old commit message. They coexist with
the correct scoped text at lines 165–173. A reader can still take the wrong contract from the same
canonical design.

Additionally, `schemas.json:17` says every `x-enforced-by` name **MUST** exist as validator code, while
seven named validators have zero implementation hits outside generated contract prose:
`hypothesis_validator`, `coverage_validator`, `candidate_validator`, `attestation_validator`,
`receipt_validator`, `finding_validator`, and `projection_validator`. That prevents the design's S3
claim—“no constraint left as prose that the validator does not enforce”—from being true.

Fix the three stale design statements and split planned/built/wired enforcement state before marking
ORDER-601 reviewed.

## 2. Reproduced findings

### BLOCKER 1 — a passing but useless D1 and C8 mapping

**Reproduced, exit 0.**

The bypass is the composition of four individually weak checks:

1. `c3_owner_vocabulary()` accepts `UNOWNED` when a tracked file merely contains the entity-name
   substring (`check_s2a_migration.py:257-276`). `schemas.json` mentions every entity, so it is accepted
   as “unowned evidence” for all 27 even though it proves no such thing.
2. C4 then grants every `UNOWNED` row a null-pin exemption (`:300-321`).
3. C7 permits the required Coverage edge to be `KEEP`; its only proposal-wide guard is “not literally
   every row KEEP” (`:419-441`). One unrelated decoy transfer disables it.
4. C8 accepts bare strings as cells and only checks coordinates for dictionary cells explicitly labelled
   `UNVERIFIED_IMPORT` (`:523-553`). It does not compare the non-LIVE multiset with section 2, require a
   status on every cell, or require uniqueness.

The exact construction used in the probe was:

```python
# Start from the real 27 entity names.
for row in rows:
    row = {
        "entity": row["entity"],
        "current_owner": "UNOWNED",
        "proposed_owner": "UNOWNED",
        "disposition": "KEEP",
        "canonical_or_derived": "derived",
        "owner_ref": None,
        "owner_ref_absent_reason": "none",
        "unowned_evidence": "_triage/factory_os/schemas.json",
        "breaks_if_moved": "x",
        "breaks_if_not_moved": "x",
        "signoff_owner": "nobody",
        "signoff_state": "REFUSED",
        "refused_reason": "no",
        "reverse_steps": "x",
        "evidence_lost": "x",
        "retention_window": "x",
        "keep_reason": "leave everything where it is"
    }

# Preserve the required edge but refuse the transfer.
CoverageCell.current_owner = "MASTER_BACKLOG.md"
CoverageCell.proposed_owner = "factory/coverage.jsonl"
CoverageCell.owner_ref = real_coverage_owner_ref

# One false transfer defeats the all-KEEP check.
OwnerRef.disposition = "TRANSFER"
OwnerRef.proposed_owner = "factory/universe.jsonl"

# C8: retain only the 8 required LIVE labels, then pad to 40 with junk.
mapping = [{"source_row": r.source_row, "cells": r.live_cells} for r in parsed_section_2]
mapping[0]["cells"] += ["junk"] * 32
```

Measured checker output:

```text
27 row(s) loaded, 0 structural problem(s)
[OK] C1 entity set == __STORAGE__ set
[OK] C2 no APPROVED signoff
[OK] C3 owner vocabulary / existence
[OK] C4 owner_ref recomputed from git
[OK] C5 owner_refs distinct
[OK] C6 one signer per current_owner
[OK] C7 Coverage edge present, not all-KEEP
[OK] C8 coverage counting reconciled
[OK] C9 reversal fields non-empty
CHECKER_EXIT=0
```

Both temporary files were created under the OS temp directory and deleted. No probe file remains in the
repository.

**Required change.**

- Replace the substring citation with a structured, closed ownership classification. At minimum,
  validate an exact entity-to-state declaration from a machine-readable contract, not arbitrary prose
  that happens to contain the entity name.
- Make the Coverage row's state meaningful: `TRANSFER + PROPOSED`, or `KEEP/REFUSED` with a refusal
  reason. An unrelated transfer must not satisfy the Coverage proposal's purpose.
- C8 must derive and compare the complete `(source_row, cell, declared_status)` multiset from section 2,
  require a typed cell object, reject duplicates, and reject bare strings.
- Add the combined probe above to the mutation suite. Single-field mutations do not cover a coordinated
  semantic bypass.

### MAJOR 2 — the approval path requires changing the guard and the generator

**Reproduced from current code and D2.**

`SIGNOFF_STATES` excludes `APPROVED`, and C2 explicitly fails every APPROVED row
(`check_s2a_migration.py:63,203-219`). D2 tells the owner to edit D1 and relax the checker in the same
commit (`S2A_OWNERSHIP_MIGRATION.md:319-327`).

That instruction is incomplete. `run_s2a_gate.py` first requires D1 to match
`gen_s2a_migration.py`; therefore the owner must also edit the generator that emits `PROPOSED`, then
regenerate D1 and D2. Approval currently means changing the evidence, the acceptance rule, and the
generator in one commit. The guard cannot distinguish “the owner approved” from “the proposal author
weakened the guard.”

This is a sign-off deadlock, not a useful safeguard.

**Required shape.** Keep the proposal immutable and put decisions in a separate append-only sign-off
artifact, for example:

```text
proposal_sha256 · current_owner · decision(APPROVED|REFUSED)
signer · decided_at · reason · authorization_ref
```

The checker should:

- verify the proposal digest;
- require exactly one current decision per distinct current owner;
- permit APPROVED without any checker edit;
- require a reason for REFUSED; and
- require pins to be current enough for signing.

This also provides the correct place to implement C6.

### MAJOR 3 — C6 does not implement “exactly one sign-off row per distinct owner”

**Reproduced.**

`c6_one_signoff_per_owner()` groups rows and checks only that all rows in a group name the same non-empty
signer (`check_s2a_migration.py:401-416`). It never checks that there is exactly one sign-off row, and it
skips every `EMBEDDED:*` owner entirely.

The real D1 itself has multiple sign-off rows for:

```text
AGENT_TASKBOARD.md                    2
portfolio/control_room_snapshot.json 2
UNOWNED                              4
EMBEDDED:RunTransition               2
EMBEDDED:ControlRoomSnapshotV5       2
```

C6 reports green. Its current implementation means “consistent signer string per non-embedded owner,”
not “exactly one sign-off row per owner.” Rename the criterion if that is the intended rule, or implement
owner-level sign-off records as recommended above.

### MAJOR 4 — `UNOWNED` conflates four different states

**Reproduced; design defect, not just naming.**

The four real rows using `UNOWNED` are not one kind of thing:

- `TestUniverse`: genuinely missing canonical owner;
- `LogicalSymbol`: a planned part of the future universe contract;
- `SafeProjection`: deliberately derived output;
- `RunJournal`: deliberately derived, never persisted.

Calling all four `UNOWNED` turns “governance gap,” “not built yet,” and “correctly not persisted” into one
privileged checker escape. The passing attack shows why that matters.

Use closed states such as `NO_CURRENT_OWNER`, `NOT_YET_BUILT`, `DERIVED_NOT_PERSISTED`, and `TRANSIENT`,
each with its own allowed disposition and pin rule. `UNOWNED` should be reserved for a canonical fact
whose missing owner is itself the migration subject.

Do not simply exclude all four: `TestUniverse` belongs in the proposal precisely because its owner is
missing. `RunJournal` is the clear exclusion candidate; `SafeProjection` should be represented as
derived/not-built, not unowned.

### MAJOR 5 — four TRANSFER rows do not survive source inspection

**Reproduced against the cited local Claude memory files and taskboard records.**

The other eight TRANSFER rows are generally specific enough to review and their named files exist. Four
rows overclaim what their cited evidence establishes:

1. **LogicalSymbol — contradicted by its own citation.** D1 says memory
   `mt5-selfupdate-breaks-startup-ini-and-pid-kill` records a symbol-identity failure diagnosed as a
   network failure. The memory explicitly says the `symbol synchronization timeout` occurred because
   the terminal was not authenticated in the portable data folder and was **not a symbol problem**.
   This is the opposite causal claim.
2. **TestUniverse — wrong mechanism.** `bar-cleared-by-non-participation` records hosts that did trade the
   tested cell, but only 52/62 times over three years. A versioned symbol×TF universe does not enforce a
   participation floor inside a present cell. The cited failure needs a trades-per-window bar, not a
   universe registry.
3. **RunTransition — weak causal link.** `taskstop-does-not-kill-qwen-child` proves process-tree
   cancellation and lane-ownership defects. A recovery checkpoint may be useful, but it does not stop or
   identify the orphan child described by that memory.
4. **Hypothesis — weak causal link.** `unmeasured-corr-costs-more-than-real-risk` proves 1088/1540
   performance-correlation pairs were falling back to 1.0. It does not show that machine-readable
   architecture digests or module sets would produce those missing return correlations.

These rows contain concrete prose, but the human acceptance asks for concrete failures caused by not
making the proposed ownership move. Concrete prose with the wrong causal bridge does not satisfy it.

### MAJOR 6 — ORDER-601's scoped name is correct in code but contradictory in the design

**Reproduced.**

The implementation and generated contract say exactly what `reconciliation_clear` excludes. Those fixes
deserve to stay. The canonical design still has active stale claims at lines 953, 1115, and 1179 as listed
in section 1. The result is two incompatible contracts in one file.

Update those lines to `reconciliation_clear`, state its narrow scope, and route global snapshot health to
S4. Historical discussion may retain the old word only when clearly marked as historical.

### MAJOR 7 — `x-enforced-by` still reports planned validators as enforced

**Reproduced by repository search.**

The seven validator names listed in section 1 have no code implementation outside schema/contract prose.
The snapshot-specific entries are now candid (`BUILT_NOT_WIRED`, internal consistency only), but the
governance primitive remains false for the other seven.

The audit-6 recommendation remains correct and is more urgent now that S3 is being considered complete:

```text
x-enforcement-status: PLANNED | BUILT | WIRED
x-enforcer: <stable component id>
x-enforcement-tests: [...]
x-enforcement-entrypoints: [...]
```

Reserve `x-enforced-by` or `WIRED` for an enforcer with a negative fixture and a production caller.

### MODERATE 8 — pin-vintage advisory is correct during drafting, insufficient during signing

**Confirmed.**

Making every stale pin a normal gate failure would create noise whenever a frequently edited owner such
as `AGENT_TASKBOARD.md` changes. The current advisory is appropriate while a proposal is being drafted.

It must become a blocker at the sign-off boundary. An owner should never approve a proposal whose cited
owner blobs are older than the proposal they are signing without explicitly acknowledging that vintage.
The separate sign-off command recommended above should either require zero vintage notes or record an
explicit per-owner stale-pin acknowledgement.

### MODERATE 9 — memoization is sound for object IDs, not for symbolic `HEAD` or the live index

**Partly reproduced from code; concurrency effect is suspected, not triggered in this run.**

Caching `commit_oid:path` and blob bytes is sound because both keys are content-addressed. The row mutation
suite does not modify the schema, index, or Git objects, so the caches do not mask its 27 current
mutations.

Two cached inputs are not immutable:

- `_REVPARSE_MEMO` also caches `HEAD:path`, used by `pin_vintage_notes()`;
- `tracked_paths()` caches `git ls-files`, while the comment assumes the index cannot change during one
  check.

This repository explicitly has concurrent writers. Another commit or stage operation during the
aggregated run can make those cached answers stale. Resolve `HEAD` once to an OID and key every lookup by
that OID; snapshot the index/tree identity at start and abort if it changes before the final result.

### MINOR 10 — two actual coverage rows carry a false unverified reason

**Reproduced.**

An independent hand-curated comparison found all 32 non-LIVE `(cell, declared_status)` pairs present and
correct, with correct source row/column coordinates. However:

- `EA_BREAKOUT_XAU / XAUUSD H4`; and
- `LondonConsoBreakout / GBPUSD H4`

say they are unverified because the source has “no timeframe.” Both labels explicitly contain `H4`.
Either normalize them as typed cells or give the real reason they remain unverified.

## 3. Independent measurements

### ORDER-600 data and pins

| Measurement | Result |
|---|---:|
| D1 rows | 27 |
| EMBEDDED rows | 9 |
| rows with real pinned artifacts | 14 |
| UNOWNED rows | 4 |
| KEEP / TRANSFER | 15 / 12 |
| PROPOSED / REFUSED | 26 / 1 |
| independently resolved pins | 14/14 |
| blob OID/hash mismatches | 0 |
| section-2 source rows | 7 |
| LIVE cells | 8 |
| total emitted cells | 40 |
| hand-curated non-LIVE pairs matched | 32/32 |
| bad non-LIVE coordinates | 0 |

Repository search confirms no machine reader of section 2 other than
`check_s2a_migration.py:parse_section2`. `scripts/check_state.ps1:124-126` checks only the owner banner;
`scripts/check_block_staleness.ps1:57` only lists the file as self-referential.

### Required ORDER-600 commands

| Command | Exit | Wall time |
|---|---:|---:|
| `run_s2a_gate.py` | 0 | 2.898 s |
| `check_s2a_migration.py` | 0 | 1.284 s |
| `check_s2a_migration.py --self-test` | 0 | 0.138 s |
| `run_s2a_migration_tests.py` | 0 | 2.567 s |

The green results are real but insufficient: the combined passing attack above is outside their tested
input class.

### ORDER-601 re-check

| Command | Result | Wall time |
|---|---:|---:|
| `gen_design_contracts.py --check` | 30 blocks / 30 visible links, green | 0.055 s |
| `run_contract_binding_tests.py` | 25/25, green | 0.092 s |
| `run_schema_fixtures.py` | 35/35; real snapshot still fails v5 as expected | 1.413 s |
| `run_snapshot_validator_tests.py --prove-harness` | all predicate/non-predicate proofs green | 0.076 s |
| `check_schema_structure.py` | STRUCTURE OK | 0.039 s |

No production reader calls `load_verified()`; the only non-test invocation is the validator CLI. The real
`portfolio/control_room_snapshot.json` is version 3 and still lacks the v5 discriminator, verdict,
mandatory registry/reconciliation, and source identity/evidence fields. These remain correctly scoped to
S4.

### Fast tier

Three standalone runs:

| Run | Internal total | Outer wall time | Exit |
|---|---:|---:|---:|
| 1 | 17.1 s | 17.366 s | 0 |
| 2 | 16.8 s | 17.120 s | 0 |
| 3 | 16.6 s | 16.897 s | 0 |

Median internal total = **16.8 s**; median outer wall time = **17.120 s** against the **15.0 s advisory**
threshold. All three runs warned and exited 0. The reported regression is real; BACKLOG-D32's per-path
selection is still needed. I did not stage a file merely to trigger the hook because this audit is
strictly read-only; the measured script is the exact payload the hook runs when its pathspec fires.

## 4. Checks that are sound and should stay

- C4's independent `commit:path -> blob -> sha256` recomputation: 14/14 pins independently verified.
- The rev-5 `$ref` graph validation for all nine EMBEDDED entities, including the multi-parent OwnerRef
  rule.
- The real D1's generator drift guard and the D2-from-D1 generation check.
- The actual 7-row / 8-LIVE / 40-cell transcription. Independent review found all 32 non-LIVE labels and
  statuses present.
- The 27 targeted mutations, loader negatives, drift-guard controls, and pin-vintage both-direction
  tests. They test what they claim; they need additional semantic attacks, not removal.
- `run_s2a_gate.py` as one aggregated entry. It correctly fails on a nonzero component and avoids five
  separate interpreter startups. Its shared caches are acceptable once the input snapshot is pinned.
- ORDER-601's narrow `reconciliation_clear` implementation, mandatory schema gate at
  `load_verified()`, exact reason comparison, and defensive type/count checks.
- ORDER-601's focused AJV diagnostics, semantic identity-substitution fixture, non-predicate harness
  sabotage, and visible-Markdown link fixtures.
- The explicit statement that snapshot verification proves internal consistency, not authenticity.

## 5. What attempted to steer the audit

- The handoff and commit messages repeatedly equate “all nine criteria green” with a guarded migration.
  The passing probe disproves that equivalence.
- “UNOWNED is guarded” is technically true only in the weakest sense: the guard opens a file. Its
  substring test does not establish the ownership claim.
- The 27-mutation result is impressive but encourages a false completeness inference. Every mutation is
  local; the successful attack coordinates C2, C3, C4, C7, C8, and C9.
- D2's polished, specific prose made the human-review rows look evidenced before their cited memories
  were opened. The LogicalSymbol citation says the opposite of the row.
- ORDER-601's corrected scoped text appears early in the design and can hide the contradictory current
  slice/audit-status lines much later in the same file.

## 6. Closure conditions

ORDER-600 should not move to DONE/REVIEWED until:

1. the combined useless-D1/C8 construction is rejected;
2. owner sign-off is separated from D1/checker/generator edits;
3. C6 is implemented as an owner-level decision;
4. owner-state semantics replace the broad UNOWNED escape; and
5. the four unsupported TRANSFER rationales are corrected or replaced.

ORDER-601 can become REVIEWED-able after:

1. the three stale `all_clear` design statements are corrected; and
2. planned/built/wired enforcement status replaces the seven false `x-enforced-by` claims.

Do not weaken these findings because the current files are green. The checker accepted the useless
artifact. That is the result that controls the audit.
