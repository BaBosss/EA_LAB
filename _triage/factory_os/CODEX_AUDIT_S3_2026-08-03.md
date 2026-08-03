# Codex blind audit — Factory OS slice **S3** (schema validator + negative fixtures) — 2026-08-03

> Dispatched by lane `S-2026-08-03-AUDITCOV`, **pinned at `a87f7448`**, blind and read-only.
> Brief: [`CODEX_S3_AUDIT_BRIEF.md`](CODEX_S3_AUDIT_BRIEF.md), committed at `1d225d4b` **before** the
> audit ran. First independent audit of this slice's built code.
>
> Verified items were re-measured by this seat with controls. The audit's own execution limits are
> stated in Part 3 and are **not** hidden behind a green summary.

**This slice is the one every other slice's correctness claim rests on**, so its findings propagate.
Three of the four are the same shape — **a case that cannot fail** — which is the more expensive kind,
because it reports green forever.

---

## Part 1 — VERIFIED

### 1.1 🔴 BLOCKER — `OwnerRef` does not prove it references anything, **and two independent audits found this separately**

`candidate.py:140-159` · `schemas.json:342-396`

This was raised by the **S3** audit and, independently and without either seeing the other, by the
**S10** audit (recorded there as unverified claim 2.1). Convergence from two blind reads is why it is
promoted to verified here rather than left as a claim.

**Measured**, with a ref whose commit oid, blob oid and sha256 are pure filler and whose `anchor`
contains spaces — which the schema's own prose forbids:

```
owner_ref_problems(fake_ref) -> []
CONTROL (raw_sha256 = 'NOT-A-SHA') -> caught, so the checker is live
```

And the function contains **no resolution primitive at all**:

```
mentions rev-parse       False
mentions subprocess      False
mentions git             False
mentions os.path.exists  False
mentions open(           False
```

It validates **shape**. It never resolves `commit_oid:path`, never compares `blob_oid` or
`raw_sha256` against anything, and never checks `anchor` at all despite the schema describing a
uniqueness rule for it.

**Consequence, and this is why it is a BLOCKER rather than a HIGH.** `OwnerRef` is the pin primitive
that S2's entire ownership discipline is built on, and it is embedded in hypothesis pre-registration,
`CandidateManifest.scorecard_ref`, and **deployment authorization** — the `authorization_ref` that
S10's A3 requires for every non-`OBSERVED` attestation event. A syntactically convincing but
nonexistent pin is accepted everywhere. Every statement of the form *"this artifact cites its owner"*
in this system is currently a statement about a **citation nobody resolved**.

### 1.2 🟠 HIGH — 13 of 29 entities are **skipped** by the enforcement check rather than failed by it

`check_schema_structure.py:256-258`

```python
if not isinstance(_body, dict) or not _body.get("x-enforced-by"):
    continue
```

There is no completeness inventory of which contracts must carry an enforcement declaration, so
**removing the declaration removes the contract from the check** instead of turning it red.

**Measured at this pin** — 29 `$defs`, of which **13 carry no `x-enforced-by`**:

```
CandidatePayload · EvidenceRef · ExecutionKey · IdeaRef · InstrumentProfile ·
LogicalSymbol · ModuleUse · OwnerRef · ParameterBinding · RunAttempt ·
RunJournal · SnapshotMeta · TestUniverse
```

`OwnerRef` is on that list, which is **exactly why 1.1 was invisible**. So is `ExecutionKey`, whose
own defect the S9 audit found the same day.

This is the repo's own `completeness-rollup-measured-after-topup` shape: C4's claim that
`x-enforcement-status` makes enforcement *"checkable rather than aspirational"* is not secured while a
constraint and its enforcement metadata can be deleted **together** and `check_schema_structure.py`
still prints `STRUCTURE OK`.

### 1.3 🟡 The brief's numbers were stale, and re-measuring was the right instruction

The S3 brief asked for two counts to be **re-measured rather than read**, because the suite header
states a prior measurement. Both were wrong:

| | header says | **measured at this pin** |
|---|---|---|
| `$defs` entities | 27 | **29** |
| root discriminator branches | 19 | **21** |
| per-entity cases | — | **64**, of which **33 negative** |
| entities with a declared negative | *"15 of 27 had none"* (before ORDER-611) | **29/29 have one** |

Independently measured by this seat for the first two. **The coverage story is genuinely good** —
every entity has a negative aimed at a real schema keyword. The stale counts are a documentation
defect, and 1.2 and 1.4 are why "has a negative" is not the same as "is protected".

---

## Part 2 — Reported by Codex, **NOT independently verified**

| # | Sev | Claim | why unverified |
|---|---|---|---|
| 2.1 | 🟠 | **`OwnerRef`'s own negative fixture cannot detect 1.1.** The positive at `run_schema_fixtures.py:50-51` uses deliberately fabricated oids and hashes; the negative at `:541-545` changes only `raw_sha256` to `NOT-A-SHA`. So the pair proves the regex exists and nothing else — never implementing referential integrity changes neither outcome. C1 therefore reports coverage for the most-referenced contract while its load-bearing property stays absent forever. | Not separately re-measured, but it is the direct corollary of 1.1 (which is measured) plus the fixture's shape, and this seat's own control probe used the **same** mutation and behaved as described. Very likely correct |
| 2.2 | 🟠 | **The closed-object inventory does not cover every entity**, though `run_schema_cages.ps1:24-26` claims *"across every entity"*. `check_schema_structure.py:76-92` checks only root-routed definitions plus a one-off for `SnapshotMeta`, omitting **`CandidatePayload` · `ExecutionKey` · `MetricRef` · `ModuleUse` · `ReconciliationEvidence` · `RunAttempt` · `SnapshotVerdict`**. Their per-entity negatives test unrelated constraints — `ModuleUse` tests only a token pattern — so removing `unevaluatedProperties:false` leaves every cage green while unknown fields become accepted on records S5, S9 and S10 embed. | Not re-measured. **Codex is explicit that no entity currently lacks `unevaluatedProperties:false`** — the finding is that several removals could not make the cage fail, not that anything is open today |

**Claims not refuted:** C2 (21 root branches, unique discriminator constants matching the root enum,
unknown entities rejected) · C3 (`reconciliation_clear` is a one-field delta asserting the exact
`unevaluatedProperties` error path) · C5 (for routed entities the isolation harness preserves
`$defs`, `$ref`, `required` and closure; valid helper objects passing the harness and failing the
root is **intentional**, because helpers are not standalone root documents) · C6 (the contract
binding suite passed all 25 cases including the seven named semantic regressions).

---

## Part 3 — Execution limits, stated rather than smoothed over

**Zero fixtures reached `ajv` in this audit run.** The prescribed command failed before validation:
the auditor's read-only sandbox had no writable temp directory, **and `ajv-cli` is absent from
`PATH`**.

Codex's own words for this are worth keeping: *"This is fail-closed — no false green — but it
prevents independent execution certification."* The 29/29 negative-coverage figure in 1.3 is
therefore **static inspection**, not an ajv-observed result, and this file does not upgrade it.

That absence is itself a finding-shaped observation and lands squarely on aim-point #7 of the brief:
**a validator whose external dependency is missing must fail loudly, and here it did.** What is *not*
established is what the suite does when `ajv-cli` is missing on a machine where the tier runs — the
brief asked, and the answer did not arrive because the run stopped earlier for a different reason.
Left open deliberately rather than assumed.

| | |
|---|---|
| `run_contract_binding_tests.py` | 25/25 including all seven regressions |
| `run_schema_fixtures.py` | **did not reach ajv** — see above |
| this seat | `scratchpad/verify_s9_s3.py` — 1.1 (with control), 1.2, 1.3 |

---

## Part 4 — What this changes about the slice's own acceptance

Design §10's S3 row asks for: every entity rejects at least one crafted bad instance · the root
discriminator rejects an unknown `entity` · `reconciliation_clear` computed and a supplied value
rejected · *"every constraint this slice claims is enforced by a validator that exists"*.

| acceptance | status |
|---|---|
| every entity rejects a crafted bad instance | **29/29 by static inspection** — and 2.1 shows "has a negative" and "the negative can detect the defect" are different properties |
| root discriminator rejects unknown `entity` | **holds** (C2) |
| `reconciliation_clear` computed, supplied value rejected | **holds** (C3) |
| every claimed constraint has a validator that exists | 🔴 **not secured** — 1.2 lets the claim and its checker be deleted together, and 1.1 is a live instance of a constraint that is written down and enforced by nothing |
