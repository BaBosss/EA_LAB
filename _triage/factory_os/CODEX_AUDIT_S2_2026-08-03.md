# Codex blind audit — Factory OS slice **S2** (ownership migration + `OwnerRef` discipline) — 2026-08-03

> Dispatched by lane `S-2026-08-03-AUDITCOV`, **pinned at `a87f7448`**, blind and read-only.
> Brief: [`CODEX_S2_AUDIT_BRIEF.md`](CODEX_S2_AUDIT_BRIEF.md), committed at `aeb67885` **before** the
> audit ran. Seventh and last of the coverage set.
>
> ⚠️ **This audit was dispatched twice.** The first attempt ran 51 tool calls and **stopped without
> ever producing a report** after getting stuck on a harness needing a writable temp dir. The retry
> brief told it to record an execution limit in one line and continue statically. It did.

**Codex's headline: C1, C2, C4, C5, C6 and C7 are not established as claimed. C3 is stated honestly
in the checker and contradicted by its consumers.**

---

## 🎯 Part 0 — the withheld diagnosis, and what it proves about the method

Alone among the seven briefs, S2's told the auditor that `run_s2a_gate` F2 and
`check_coverage_transfer` A8 were **RED at the pin**, said outright that the cause was being
withheld, and asked for an independent diagnosis.

**It diagnosed it correctly, from the bytes, with no prompting** — the same mechanism `ORDER-1257`
recorded:

```
52a17570: attestation line 10 appended; bundle and section valid
5e78ebc3: 16 Coverage rows legitimately appended
           factory/coverage.jsonl  e049faca -> c6287ff5
F2 RED -> A8 RED
```

And it went **further than the existing record**, with a framing worth keeping:

> D1 line 10 pins the **entire `factory/coverage.jsonl` blob**, while the attestation pins the
> **generated section of `MASTER_BACKLOG.md`**. The pin covers an **evolving whole store**; the
> authorized action concerned a **migration and a generated section**. So *"every store update
> creates another owner-attestation toll."*

That is a sharper statement of the problem than *"sixth occurrence of
`approval-pinning-self-invalidates`"*: it identifies **granularity mismatch** as the cause, which
tells the corrections seat what to change. **Withholding the answer bought a better one.**

---

## Part 1 — VERIFIED by this seat

### 1.1 🔴 `OwnerRef` resolves nothing — **the THIRD independent audit to find this today**

`candidate.py:140-159` · `CONTRACTS.md:120-124`

S3 found it, S10 raised it as its own claim, and **S2 found it again without seeing either**. Already
recorded and verified with a control in `ORDER-1263`; S2 adds two consumers the other two did not
name:

- `check_pilot_acceptance.py:177-190` reads `blob_oid` **directly and ignores the claimed `path`,
  `commit_oid` and `raw_sha256`**.
- The **strong** resolution logic **does exist** — `check_s2a_migration.py:522-536` — but applies
  **only to the migration table's own `owner_ref` fields**, never to `OwnerRef`s embedded in Factory
  artifacts.

That second point matters for the fix: the resolver is already written. It is scoped to one file.

### 1.2 🟠 HIGH — the owner-facing document still instructs the deadlock C5 claims was removed

`S2A_OWNERSHIP_MIGRATION.md:337-340` — **measured by this seat:**

```
337  - **approve** -> set `signoff_state` to `APPROVED` on that row of
339    guard exists to stop *me* writing it, so the criterion has to be relaxed to accept the
       owner's act in the same commit that records your approval.
```

Policy §2.1 calls this document *"what the owner actually reads"*. It tells the owner to **relax the
acceptance criterion in the same commit that records the approval** — which is
`guard-removed-in-the-commit-that-reddens-it`, written as an instruction, in the document the owner
is handed. Meanwhile `check_s2a_attestation.py:18-21` claims the opposite (approval costs one
appended line, no rule or generator edit) and `check_s2a_migration.py:356-364` (C2) **still refuses**
the `APPROVED` state the document prescribes.

Following the bound instructions produces an approval that succeeded **by weakening its own checker**.
The same obsolete text is **generated** by `gen_s2a_migration_doc.py:142-155`, so it will regenerate.

### 1.3 🟡 MEDIUM — a record whose pin failed still prints `APPROVED`

`check_s2a_attestation.py:549-686` — **measured by this seat**, running the checker at HEAD:

```
line 10 of output:  MASTER_BACKLOG.md (Coverage edge) -> APPROVED by user (Boss) (line 10)
line 14 of output:  -> F2 line 10 attests for 'MASTER_BACKLOG.md' whose pin is STALE ...
```

F2–F14 problems are appended but **do not stop the row being assigned into `current`** (`:686`), and
the `UNVERIFIED` cleanup at `:695-701` only fires when the row is not the latest. The process exits
non-zero, so a **script** is safe; a **human or a consumer reading the resolved decision line** is
told `APPROVED` for a record whose exact-byte pin did not verify.

---

## Part 2 — Reported by Codex, **NOT independently verified**

| # | Sev | Claim | note |
|---|---|---|---|
| 2.1 | 🔴 | **An `APPROVED` record may contain no approved post-state.** `expected_post_state` is absent from the required set (`check_s2a_attestation.py:79-81`) and validated only `if eps is not None` (`:544-550`); the policy makes it optional (`S2A_ATTESTATION_POLICY.md:177`), and the front guard then creates **no target-file pin** (`check_attested_pin_staged.py:146-161`). A row can acknowledge the stale `factory/coverage.jsonl` pin while **making no claim at all about the `MASTER_BACKLOG.md` section the approval is nominally for** | Codex supplies a full reproducer. **The highest-value Part 2 item** — it is the difference between an approval that binds bytes and one that binds nothing |
| 2.2 | 🟠 | **Consumers turn an explicitly non-authoritative attestation into owner authorization.** `check_s2a_attestation.py:8-16` says the log cannot distinguish an owner action from an author typing the owner's name. `check_coverage_transfer.py:595-614` calls it *"the approval that authorized this transfer"*; `AGENT_TASKBOARD.md` calls the rows owner signatures and proof the owner approved. Every attestation commit carries the **same `patip` identity** the checker cites as incapable of proving provenance | This is the S2 brief's aim-point #4 answered: the limit is stated in **one docstring** and forgotten by **every consumer**. Not re-measured, but the disclaimer text was read directly during briefing and matches |
| 2.3 | 🟠 | **The transfer has executed and the migration model cannot record it.** `s2a_migration.jsonl:10` still says `current_owner: MASTER_BACKLOG.md` / `disposition: TRANSFER` / `signoff_state: PROPOSED`, while `factory/coverage.jsonl:1` **declares itself canonical**. The policy admits (`:134-164`) there is no `EXECUTED`/`TRANSFERRED`/`previous_owner`/`executed_at` state, and that moving `current_owner` makes every historical attestation fail R6 permanently | **Refutes C1 and C2 as machine-enforced properties.** The table cannot answer who owns Coverage now |
| 2.4 | 🟠 | **Conformance binds the implementation to the editable corpus, not to the policy.** `run_s2a_conformance.py:42-47,374-399` loads the vector file and a hard-coded version string and **never reads `S2A_ATTESTATION_POLICY.md`**; its mutation harness (`:402-441`) removes emitted reason IDs from observed output rather than mutating predicates. The policy itself admits **R8 is unreachable**, **B4 has no vector**, **F13's non-UTF-8 branch has no vector**. Commits `212c0555` and `c66d5e57` edited policy, corpus, implementation and attestation log **together** | Directly answers aim-points #2 and #3. *"Frozen"* here means **author-controlled and re-attested**, not independently frozen |

---

## Part 3 — Execution

| | |
|---|---|
| `check_s2a_migration.py` | exit 0 — nine local D1 criteria held, three stale-pin advisories |
| `check_s2a_attestation.py` | **exit 1 on F2 for line 10** — the expected RED |
| `check_coverage_transfer` A8, invoked directly | RED, for the same reason |
| `check_attested_pin_staged.py` | static inspection confirms it reads the **staged index**, not the working tree (`:78-120`, `:252-281`) — **aim-point #7 answered, and it holds** |
| conformance / attestation-test / migration-test / aggregate-gate | **could not execute** — no usable temp directory. Stopped after the first bounded failure and continued statically, as the retry brief instructed |

No repository file was edited, created, staged or committed.

---

## Part 4 — What this changes about the slice's own acceptance

| design §10 acceptance | status |
|---|---|
| every artifact holds owned facts only as a pinned `OwnerRef`, **zero mutable copies** | 🔴 **not established** — 1.1 (the pin resolves nothing) and 2.3 (Coverage is mutable through `factory/coverage.jsonl` while the table still names `MASTER_BACKLOG.md` as owner) |
| owner-by-owner sign-off recorded | **recorded, and 2.2 is what the record is worth** |
| 🚫 may not demote any owner without its owner's approval | 🔴 **not machine-enforced** (2.3) |

**The one thing that came out stronger than expected:** `check_attested_pin_staged.py` reads the
staged index rather than the working tree. That was aim-point #7 and it is the shape this repo has
been burned by repeatedly. It holds here.
