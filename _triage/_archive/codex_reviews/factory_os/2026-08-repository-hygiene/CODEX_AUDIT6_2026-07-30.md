# Codex blind audit 6 — snapshot validator and relocated contract binding

Date: 2026-07-30  
Audited HEAD: `b6d9dc17`  
Mode: independent, adversarial; every repository path read-only except this report

## Executive result

`ORDER-601` is **not DONE**. The validator correctly recomputes its 13 declared reconciliation
predicates, but those predicates do not mean the global phrase `all_clear`: a persisted document with
dead fleet sensors, blind floating-risk sensors, missing deployment controls, unclassified magics and
missing attestation passes AJV and `verify_snapshot` with `all_clear=true`.

The relocation in `87af43fd` should **stand with amendments**, not be reverted. Separating a generated
reference from the design is the right context boundary, but `validate_links` is only a link-inventory
check. I made all 30 links invisible inside one HTML comment and it returned clean.

## Independent measurements

| Command | Measured result | Wall time |
|---|---:|---:|
| `gen_design_contracts.py --check` | 30 blocks; links reported clean | 0.335 s |
| `run_contract_binding_tests.py` | 22/22; historical regressions 7/7 | 0.086 s |
| `run_schema_fixtures.py` | 35/35; real v3 snapshot still fails | 11.543 s |
| `run_snapshot_validator_tests.py` | 31 fixtures + 13 deletion mutations | 0.074 s |
| `run_snapshot_validator_tests.py --prove-harness` | planted unused predicate detected | 0.073 s |

Three independent fast-tier runs were **15.2 s, 14.7 s and 14.8 s** (12/12 green). The first
exceeded the stated 15.0 s budget and still exited 0 because the budget is warning-only.

The current files measure 1,178 lines for the design and 786 lines for `CONTRACTS.md`.

---

## BLOCKER 1 — Q1: the 13 predicates are the right reconciliation predicates, but the wrong definition of `all_clear`

**Defect.** `facts_of()` extracts only `mandatory_sources`, source rows, the staleness bar and
`meta.reconciliation` (`snapshot_validator.py:112-157`). `compute()` runs its 13 predicates over only
those facts (`snapshot_validator.py:360-372`). It never reads:

- `system_health`;
- `floating_risk`;
- `deployments.gaps`;
- `unknown_magics`;
- `attestation`;
- `judge_readiness`; or
- `summary`.

That is narrower than the design's promise. The design calls `ALL CLEAR` one global rule for both
domains (`EA_LAB_FACTORY_OS_DESIGN.md:165-171`) and makes snapshot health the first Control Room result
shown to the user (`EA_LAB_FACTORY_OS_DESIGN.md:720-729`). The real writer already calculates the
alarming states:

- `NO_SENSOR` / `STALE` at `scripts/control_room_snapshot.ps1:129-143`;
- `BLIND` / `STALE` floating risk at `scripts/control_room_snapshot.ps1:311-339`;
- missing kill/judge gaps at `scripts/control_room_snapshot.ps1:392-398`;
- attestation gaps and `FILE_MISSING` at `scripts/control_room_snapshot.ps1:255-270`;
- `unknown_magics_unclassified` at `scripts/control_room_snapshot.ps1:360-369`; and
- `UNDER_RATE` judge rows at `scripts/control_room_snapshot.ps1:200-216`.

The V5 schema requires the top-level domains but gives their contents almost no contract:
`system_health` and `floating_risk` are arrays of arbitrary objects and the other domains are generic
arrays/objects (`schemas.json:599-617`). Presence is not health.

**Reproduced instance.** I built the suite's healthy `BASE`, then changed only top-level domains to:

```text
system_health:  LAB_MANAGED account, state=NO_SENSOR
floating_risk:  same account, state=BLIND
deployments:    unverified + missing_kill + missing_judge
unknown_magics: age_class=UNCLASSIFIED, last_seen=not-a-date
attestation:    state=FILE_MISSING, confidence=low
judge_readiness: rate_flag=UNDER_RATE
summary: every corresponding alarm count = 1
```

Measured output:

```text
AJV=PASS verify_snapshot=ACCEPT all_clear=True reasons=[]
```

This is not a naming nit. It is a green headline on a fleet whose risk sensor is blind and whose
kill-switch/attestation evidence is missing.

**Change.** Choose one honest contract:

1. **Global verdict:** retain `all_clear`, close the top-level domain row schemas, include their
   load-bearing health states in `facts_of()`, add reason codes and minimal-pair fixtures for at least
   LAB-managed `NO_SENSOR/STALE`, floating `BLIND/STALE`, unclassified unknown magic, missing
   kill/judge, and missing/low-confidence attestation. Decide explicitly whether `UNDER_RATE` is a
   blocker or a non-blocking warning.
2. **Narrow verdict:** rename the current result to `factory_reconciliation_clear` (or similarly
   narrow wording) and do not present it as Control Room health.

The existing thirteen should remain under either option; they are useful. They are not sufficient for
the current name.

---

## BLOCKER 2 — Q2: recomputation proves agreement with supplied evidence, not that the evidence or document is true

**Defect.** The commit's precise implementation claim—“the stored verdict matches its own evidence”—is
true. The broader trust claim is not. `verify_snapshot()` recomputes the verdict and per-row `fresh`
(`snapshot_validator.py:442-506`), but trusts:

- `read_ok`;
- `age_hours`;
- `path`;
- `sha256`;
- `mtime`;
- the reconciliation counts; and
- every top-level domain and `summary`.

It neither reads the source path nor hashes it, and does not derive `age_hours` from `mtime` and
`generated_at`. Everything outside `facts_of()` can be edited without changing the recomputed verdict.

**Reproduced successor to audit 5's attack.** Starting from a validator-built healthy persisted output,
I changed both source rows to:

```text
path       = Z:\definitely-missing\<name>.csv
sha256     = 0000...0000
mtime      = 2099-01-01T00:00:00
age_hours  = 0
read_ok    = true
fresh      = true
```

Measured output:

```text
AJV=PASS verify_snapshot=ACCEPT all_clear=True
```

The paths do not exist. The document is self-consistent only because every evidence statement being
recomputed was itself supplied by the document.

A second accepted lie is the BLOCKER-1 instance: its summary and top-level domains are alarming, yet
the verifier accepts because none reach `compute()`.

**Change.**

- At build time, derive `read_ok`, hash, mtime and age from the actual named source rather than accepting
  them as builder claims.
- At read time, either re-open/re-hash sources when they are available, or verify a signed/content-addressed
  evidence manifest whose creation was the trusted boundary. If neither can be done, the verifier must say
  **internally consistent**, not **honest/trustworthy**.
- Recompute `summary` from the typed top-level domains, or remove independently supplied summary counts.
- Bind `generated_at`, `mtime` and `age_hours`; three mutually inconsistent time claims must not verify.

`verify_snapshot` is still valuable: it closes the typed-verdict attack it was written for. It is not a
document authenticity check.

---

## MAJOR 3 — Q5: `NO_SCHEMA_CHECK` and arbitrary validator injection reopen schema-invalid clear verdicts

**Defect.** Both public boundaries skip schema validation when passed `NO_SCHEMA_CHECK`
(`snapshot_validator.py:412-424`, `:442-453`). Worse, the argument accepts any callable, so the claim
that skipping is a “visible, greppable” sentinel is false: `lambda instance, entity: instance` is an
equally valid no-op.

The fast computation suite explicitly aliases and uses the sentinel on every fixture
(`run_snapshot_validator_tests.py:49-53`), so schema-only guarantees are absent from the automatically
enforced computation path.

**Reproduced cases.**

1. Set `reconciliation.duplicates=-1`. The schema correctly has `minimum:0`, but neither
   `assert_decidable` nor `_positive` rejects a negative integer.

   ```text
   NO_SCHEMA_CHECK: ACCEPT, all_clear=True, reasons=[], duplicates=-1
   ajv gate:         REFUSE
   ```

2. Pass a no-op lambda instead of the sentinel:

   ```text
   build_snapshot(invalid_negative_count, lambda instance, entity: instance)
   -> ACCEPT, all_clear=True
   ```

3. Build a valid output, replace the boolean with `all_clear="yes"`, and verify with the sentinel.
   `verify_snapshot:461` coerces both values through `bool()`, so the string is accepted:

   ```text
   verify_snapshot(NO_SCHEMA_CHECK) accepted all_clear='yes' type=str
   ```

Other required fields, closed-root rules, source-row types and the version floor have the same bypass.
The recursive forbidden-key scan fixed one symptom; it cannot duplicate the whole schema.

**Change.** Do not delete the schema gate; delete the skip from the public trust boundary.

- `load_verified(path)` should hardwire the real schema validator and expose no validator parameter.
- Public `build_snapshot()` and `verify_snapshot()` should likewise validate, or be split into
  public checked functions and clearly internal pure computation helpers.
- Test `compute()` directly for fast arithmetic tests. Run checked build/verify integration tests through
  AJV.
- At minimum, reject anything except the canonical validator object; accepting arbitrary callables makes
  the required argument ceremonial.
- Do not use `bool()` as validation. Compare actual booleans after a mandatory schema check and retain
  defensive type checks in the trust-boundary code.

### The “AJV errors now name the defect” claim is only partly true

`_describe_ajv_errors()` prefers schema paths containing the parent entity name
(`snapshot_validator.py:520-550`). A nested failure lives under
`#/$defs/ReconciliationEvidence`, not `#/$defs/SnapshotBuilderInput`, so that filter misses it and falls
back to unrelated root-union branch noise.

For `duplicates=-1`, the measured refusal was:

```text
required at '' -> owner_type; required at '' -> hypothesis_id;
required at '' -> hypothesis_revision; required at '' -> universe_version
```

It never names `duplicates` or `minimum`. This contradicts the broad commit-message claim that the error
renderer now selects the entity's meaningful errors. Validate directly against the selected `$def` (or
route by discriminator before validation) rather than parsing a 20-branch `oneOf` error set heuristically.

---

## MAJOR 4 — Q3: the mutation table proves deletion sensitivity, not predicate correctness

**Defect.** `red_set_without()` deletes one predicate and compares the measured red fixture set with
fixture-declared `depends_on` (`run_snapshot_validator_tests.py:596-635`). That catches dead, duplicated
and unexpectedly coupled predicates. It does not catch a predicate that produces the expected answer on
the finite fixtures for the wrong rule.

**Reproduced wrong validator with a fully green suite and table.** I replaced
`MANDATORY_SOURCE_MISSING` with:

```python
def wrong_missing(f):
    if len(f.rows) >= len(f.mandatory):
        return []
    return the_missing_names(f)
```

This is wrong because an unrelated optional row can replace a missing mandatory identity while preserving
the row count. Measured:

```text
fixture_failures=0
mutation_problems=0
```

Then I replaced mandatory `dashboard` with optional `aux_notes`; the registry still required
`dashboard`, but the wrong validator returned:

```text
compute=(True, [])
```

The current fixtures test a dropped row and an empty array, but not a same-cardinality identity
substitution. Deleting the wrong predicate still reddens exactly the declared fixtures, so the mutation
table stays perfect.

**Hand-declared oracle.** `depends_on` is in the same editable test file as the fixtures
(`run_snapshot_validator_tests.py:201-224`). The harness detects a disagreement between declaration and
measurement; an author can make it green by changing the declaration to the new measured set. Exact
reason assertions provide a stronger oracle for listed instances, but neither mechanism establishes
coverage of unlisted input classes.

**`--prove-harness` scope.** It plants only an unused predicate (`run_snapshot_validator_tests.py:683-705`).
It proves the “predicate with no fixture” detector. It does not prove semantic mutants, boundary mutants,
wrong identity matching, inverted comparisons, trusted derived fields or verifier bypasses.

**The three non-predicate mechanisms are covered, but not by the table.** I independently sabotaged them:

| Sabotage | Fixtures that turned red |
|---|---:|
| `assert_decidable = no-op` | 3 |
| `derive_fresh = always true` | 3 |
| `verify_snapshot = trust input` | 5 |

So those checks are not inert. However, the committed table's “two checks it cannot cover” paragraph
omits `verify_snapshot` entirely (`SNAPSHOT_VALIDATOR_MUTATION_TABLE.md:35-39`).

**Change.**

- Add semantic mutants: count-vs-identity membership, `<`/`<=` boundaries, trust caller `fresh`, omit one
  set member, collapse duplicates, bool coercion and bypass verification.
- Add property/metamorphic tests over generated source registries: replacing any mandatory source with a
  distinct optional name must never preserve clear; order changes must preserve the result; duplicating
  a row must not hide a missing name.
- Derive dependencies from exact expected reason codes wherever possible. Keep human declarations only
  where an output attack genuinely spans predicates.
- Extend `--prove-harness` to sabotage `assert_decidable`, `derive_fresh` and `verify_snapshot`, using the
  observed red sets above.

---

## MAJOR 5 — Q4: `validate_links` can pass while the design visibly contains no contract references

**Defect.** `validate_links()` uses a regex over raw Markdown and verifies only key/anchor set membership
(`gen_design_contracts.py:441-472`). It does not parse Markdown visibility, require one link, require a
link near relevant rationale, or require the design to say anything about the entity.

**Reproduced instance.** I constructed a design containing all 30 matched links inside one HTML comment
and no visible prose:

```text
links=30 validate_links_problems=[] visible_design_prose_lines=0
```

The same works by moving every boilerplate link to an unrelated appendix. Therefore the claimed
replacement property—“the design states this contract”—does not hold. The check establishes only “the
raw design bytes contain a matching URL.”

There is already a visible relocation regression that all current checks accept:
`EA_LAB_FACTORY_OS_DESIGN.md:505-508` says the operational entities' “fields are here” and that the
generator requires generated blocks “in this document.” Their fields and blocks are now in
`CONTRACTS.md`.

The harder historical half remains real. I independently removed `deposit` from `ExecutionKey` in an
in-memory schema copy and regenerated:

```text
binding_changed=True deposit_count_before=1 after=0
```

So the schema→`CONTRACTS.md` binding still catches that historical regression, independently of the
suite's 7/7 claim. The new weakness is the design→contract semantic/locality edge.

**Change.**

- Keep the relocation. Reverting would restore 700+ lines of generated detail to the default context and
  reintroduce generated blocks inside narrative.
- Replace 30 identical boilerplate lines with a compact, reviewable contract map: contract, design
  section, and one-sentence architectural role.
- Parse visible Markdown or explicitly reject links inside HTML comments/fenced code.
- Require exactly one primary design location per contract (additional contextual links may be allowed
  separately), and bind that location to a declared section/heading.
- Add the hidden-comment and all-links-in-one-appendix attacks as fixtures.
- Fix stale prose such as design lines 505-508.

`87af43fd` should stand **amended**.

---

## MAJOR 6 — Q6: `load_verified` is operationally unused and `x-enforced-by` mixes plans with enforcement

**Measured call graph.** Repository search found no reader calling `load_verified`. Its only real call is
the validator CLI (`snapshot_validator.py:584-597`); the remaining `verify_snapshot` calls are its own
tests. `daily_monitor`, status, digest and dashboard still read old paths directly. This is expected S4
work, but it means the “single door” is not yet a door in front of anything.

`load_verified` is not vacuous as a function—it calls the verifier—but its enforcement is vacuous until
readers are wired. `SnapshotVerdict` currently says recomputation occurs “on every READ”
(`schemas.json:657-661`), which is false in the current system.

**Governance defect.** The schema header says `x-enforced-by` constraints “MUST be enforced by the named
validator code” (`schemas.json:17`). The annotations then name unbuilt
`hypothesis_validator`, `coverage_validator`, `candidate_validator`, `attestation_validator`,
`receipt_validator`, `finding_validator` and `projection_validator`
(`schemas.json:122,255,431,483,511,559,750`). Because the schema itself defines this field as an
enforcement inventory, these are not harmless roadmap notes; they are false governance state.

Snapshot-specific truth:

- `ReconciliationEvidence`'s no-supplied-answer rule is enforced by the schema and recursive builder scan.
- `ControlRoomSnapshotV5`/`SnapshotVerdict` verdict recomputation exists, but not on every real reader.
- `SnapshotBuilderInput` claims it “refuses to compute from an input that does not validate”
  (`schemas.json:688-692`), disproved by `NO_SCHEMA_CHECK` and arbitrary no-op callables.

**Change.** Split aspiration from enforcement:

```text
x-enforcement-status: PLANNED | BUILT | WIRED
x-enforcer: snapshot_validator
x-enforcement-tests: [...]
x-enforcement-entrypoints: [...]
```

Reserve `x-enforced-by` (or status `WIRED`) for code with a failing fixture and actual production callers.
Until S4, say snapshot validation is `BUILT_NOT_WIRED`, not “every READ.” Aspirational components should
use `x-planned-enforcer`.

---

## MAJOR 7 — Q7: the tier has no enforceable budget, no headroom, and omits the authoritative schema suite

**Measured state.**

- Fast tier: 15.2, 14.7, 14.8 s; median 14.8 s, one of three over 15 s.
- `run_optimize_guard_tests.ps1`: 5.9–6.1 s, roughly 40% of the whole tier.
- Contract wrapper: 0.5 s as one displayed suite.
- AJV schema suite: 11.543 s and not in any automatic hook.

**Budget defect.** The header says the tier “refuses to grow” beyond the budget
(`run_fast_cages.ps1:35-40`), but exceeding it prints a warning and then exits 0
(`run_fast_cages.ps1:306-314`). It is an advisory threshold, not a budget.

**Folding assessment.** Folding saved one extra PowerShell process, so the saving is real but small. It
did not eliminate Python startup: the wrapper invokes the Python executable separately for all four
scripts (`run_contract_binding_tests.ps1:71-96`). The `d8920e57` message's claim that the fourth script
“pays no process” is false. It pays no *additional PowerShell wrapper* process. The fold also hides four
component timings under one 0.5 s row, making the per-suite table less diagnostic even though the total
remains honest.

**Enforcement gap.** `run_schema_fixtures.py` is explicitly excluded from the wrapper
(`run_contract_binding_tests.ps1:20-32`). Thus the quoted 35 cases are manual. A schema edit can trigger
the fast tier, run the computation tests with `NO_SCHEMA_CHECK`, and never run the authoritative
nonnegative/closed-object/AJV checks.

**Change.**

1. Keep 15 s as an operator-experience target unless the user chooses another number, but call it advisory
   or enforce a non-flaky policy such as a three-run median in a dedicated benchmark. A single noisy
   15.2 s commit should not fail unpredictably.
2. Use the D32 dependency map to run only suites affected by staged paths instead of running all 12 when
   any guarded path changes. A Factory schema edit does not need six seconds of optimize-guard cases.
3. Load AJV/schema once and validate all 35 cases in one process. The measured 11.5 s is dominated by one
   AJV subprocess per case (`run_schema_fixtures.py:425-448`), not schema complexity. Once batched, put it
   on the automatic schema/validator path.
4. Emit sub-script timings from the contract wrapper; folding should not erase cost attribution.
5. Do not add the next cage to the current all-suites tier: measured headroom is effectively zero.

---

## MAJOR 8 — Q8: S4 needs both a registry and explicit missing rows; logical `name` is identity, `path` is location

**Current defect.** `FileMeta` returns `$null` when a file does not exist
(`control_room_snapshot.ps1:56-60`), and the writer filters nulls out
(`control_room_snapshot.ps1:383-389`). Therefore “mandatory file missing,” “collector forgot to enumerate
it,” and “source was never expected” collapse into absence.

The registry is necessary because it independently states the expected universe. Without it, a writer
that drops both a row and its expectation can still produce 0==0. But the writer should also stop making
a known missing source disappear: explicit state gives operators a direct reason and preserves the
instrument's observation.

The current row shape cannot express that cleanly. Absence means `MANDATORY_SOURCE_MISSING`; a present
row with `read_ok=false` means `MANDATORY_SOURCE_UNREADABLE`. If the writer begins emitting a row for a
missing path, it would be mislabeled unreadable unless the contract gains an existence/state fact.

**Recommendation.**

- Maintain `mandatory_sources` as a unique registry of stable logical names.
- Change the writer to enumerate descriptors such as `{name, path}` and always emit one row for every
  mandatory descriptor.
- Add a closed source state or `exists` field:
  - `MISSING`: path does not exist;
  - `UNREADABLE`: exists but cannot be read/hashed/parsed;
  - `READABLE`: evidence captured, then freshness derived.
- Treat a registry name with no emitted row as a separate collector/instrument failure, not merely the
  same file-missing state.
- Remove the redundant per-row `mandatory` flag once readers migrate; membership in the registry is the
  authority.

Use **`name` as identity** and **`path` as a locator/evidence field**. Paths change across machines,
worktrees and migrations; logical source roles (`deployments`, `dashboard`, `attestation`) remain stable.
The verifier should enforce name uniqueness and the name→path mapping owned by the builder configuration,
then hash the path it actually read.

---

## Additional spec mismatch

ORDER-601 requires “exact membership both ways between `mandatory_sources` and `sources`”
(`ORDERS_S2a_S3a_DRAFT.md:148-150`). The implementation deliberately accepts an optional source outside
the registry (`run_snapshot_validator_tests.py:98-120`) and only rejects it when its row claims
`mandatory=true` (`snapshot_validator.py:259-264`). Either the order means exact membership and is not
met, or it means exact membership only for mandatory rows and should be amended before closure. Do not
silently call the difference DONE.

## Final verdicts

**ORDER-601: NOT DONE — a globally alarming and evidentially false snapshot still verifies with `all_clear=true`, and the public schema gate remains skippable.**

**`87af43fd`: STAND WITH AMENDMENTS — keep `CONTRACTS.md`, but replace link presence with visible, contextual contract mapping and add the hidden-link regression cases.**
