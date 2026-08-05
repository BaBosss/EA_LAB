# Codex blind audit — Factory OS slice **S10** (candidate identity · attestation · magic) — 2026-08-03

> Dispatched by lane `S-2026-08-03-AUDITCOV`, **pinned at commit `a87f7448`**, blind and read-only.
> Brief: [`CODEX_S10_AUDIT_BRIEF.md`](CODEX_S10_AUDIT_BRIEF.md), committed at `566772c5` **before**
> the audit ran, so what was asked is a record rather than a reconstruction.
>
> 🔴 **This is the first independent audit this slice's built code has ever had.** `ORDER-1100`
> built it; nothing outside that order had checked it until now.
>
> Every item in Part 1 was **re-measured independently by this seat after Codex raised it**, with a
> control where a control was possible. Codex is a second opinion, not an oracle, and an unverified
> audit finding is just another claim — Part 2 keeps those separate.
>
> Reproduction harness: `scratchpad/verify_s10.py` (probes 1 · 3 · 4 · 5 · 6, each with its control).
> It imports the modules and drives them in memory. **No repository file was modified by the audit or
> by the verification.**

---

## Part 1 — VERIFIED against the committed bytes

### 1.1 🔴 CRITICAL — a candidate can be built on **another strategy's evidence**, and validate clean

`candidate.py:314-361` (**C9**).

C9 resolves each cited run and compares exactly **three** fields — `lane`, `data_fingerprint`,
`model`. It never binds the manifest's `logical_symbol`, `tf`, `ex5_sha256`,
`effective_config_hash`, `parameters` or `module_set` to the run it is citing. The comment above it
explains why those three were chosen, and each reason is sound; the gap is that **nothing else was
added beside them**.

**Measured.** A manifest declaring `logical_symbol=EURUSD`, `tf=M15`, its own `ex5_sha256` and its
own `effective_config_hash`, citing a run whose `ExecutionKey` records `XAUUSD` / `H4` and the
expert `Boss_14_STRATEGY_A.ex5`:

```
validate_manifest(manifest_B, run_lookup={RUN_A}) -> []
```

**Control** — the same manifest with the lane mismatched **is** caught, so C9 is live and the probe
is not measuring a dead check.

**Consequence.** A candidate for strategy B can pin strategy A's profitable run as its own evidence
and pass every integrity check. The digest is computed correctly and protects the payload faithfully
— it protects a **false provenance statement**. Design §3.5's *"REFUSE a Candidate that does not pin
lane + data fingerprint"* is satisfied; the pin simply does not have to be a pin to **this**
candidate's own work.

### 1.2 🔴 CRITICAL — three non-assignment event types silently move the candidate

`attestation.py:90-117` (`fold`) and `:204-231` (**A6**).

A6 is the criterion the module docstring calls *"the second half with teeth"* — an `OBSERVED` event
may not move the candidate. It is written as `if event['event_type'] == 'OBSERVED'`. Meanwhile
`fold()` applies `candidate_id` from **any** event that carries it, with no event-type test.

**Measured**, over the module's own `EVENT_TYPES`:

```
baseline: CANDIDATE_ASSIGNED -> CAND-111111111111    (valid, authorized)
  ATTEST_STATE_CHANGED   ALLOWED -> fold() candidate_id = CAND-222222222222   <-- MOVED
  FROZEN                 ALLOWED -> fold() candidate_id = CAND-222222222222   <-- MOVED
  RETIRED                ALLOWED -> fold() candidate_id = CAND-222222222222   <-- MOVED
```

**The severity is real but narrower than "unauthorized".** All three are non-`OBSERVED`, so A3 does
require an `authorization_ref` and a human actor. The defect is a **semantic mismatch**: the
authorization that was given was to *change an attest state*, *freeze*, or *retire* — and what the
folded state records is a **reassignment onto a different candidate**, which the entity was rewritten
specifically to make impossible without `CANDIDATE_REASSIGNED`. `RETIRED` is the sharpest: the event
that closes a pair forever can move it onto a new candidate on its way out.

The docstring at `:95-103` records that a `frozen` flag was removed in a prior round because nothing
read it, and leaves the freeze policy as an open question for the owner. **That open question now has
a measured consequence**: `FROZEN` does not merely fail to freeze, it can reassign.

### 1.3 🔴 CRITICAL — the attestation log's append-only claim is not enforced, and `verify_log`'s own docstring is false

`attestation.py:283-294`.

`verify_log()` replays `validate_event` over the log's **current** contents. There is no chain hash,
no prefix pin, and no comparison against any previously-recorded state. Editing an existing event's
`candidate_id` in place changes nothing any criterion reads: A2 (id uniqueness) still holds, A5
(ordering) still holds, and A6 only fires for `OBSERVED`.

**Measured:**

```
verify_log(original, candidate=A) -> []
verify_log(edited,   candidate=B) -> []
fold(original) = CAND-111111111111
fold(edited)   = CAND-222222222222
```

The docstring one line above the function says:

> *"A store that was appended to correctly re-validates; one that was EDITED does not."*

**That sentence is false for the edit class that matters most.** The module's append-only argument —
*"the append-only claim of a store is worth exactly as much as the absence of a function that could
break it"* — is correct about **this module**, and does not constrain a text editor, another script,
or a merge. `verify_log` is what was supposed to cover that gap, and it does not.

### 1.4 🟠 HIGH — the "closed set" of legacy magic exceptions can take a fourth member

`magic.py:145-151` (**M6**, per-row) and `:178-187` (**M6**, across the store).

M6 defines membership of the closed set as *"`imported_in_cutover: true` **and** every legacy row
shares one `allocated_at_commit`"*. It never binds membership to the three magics the design,
`PROJECT_STATE.md` §0.5 and the module docstring all name (`990103`, `991001`, `991002`). A fourth
legacy row that **reuses the original cutover OID** therefore satisfies both halves.

**Measured against the real store** (60 rows, legacy = `[990103, 991001, 991002]`):

```
validate_allocation(fourth, reusing the cutover oid)      -> []
store_problems(real + fourth)                             -> []
inventory_problems(inventory + the new collision, rows)   -> []
```

**Control** — the same row stamped with a *different* commit **is** refused, so M6 is live.

**Consequence.** Two strategies can be given one magic permanently, their deals become
indistinguishable in account history, and `magic.py verify` — and therefore `check_state.ps1` —
report clean. The exact-three assertion in `run_s10_tests.py:676-681` mitigates this **only while
that cage runs against the same bytes**; it is not part of the production verifier.

The three magics are named in prose in three places and **derived in none**. That is the same
hand-copy shape the ledger's own drift record is about.

### 1.5 🟠 HIGH — an ACTIVE deployment with a malformed or blank magic vanishes from every uniqueness check

`magic.py:73-90` (`read_inventory`) and the same filter in `scripts/check_state.ps1`.

Rows whose magic is not `.isdigit()` are **skipped silently**. There is no refusal for an `ACTIVE`
deployment carrying a blank or malformed magic.

**Measured** — three ACTIVE rows (`993000`, `993000x`, blank):

```
read_inventory -> 1 row
accounts_by_magic -> {993000: ['5039123']}
```

Two live deployments disappeared with no refusal, no warning and no count.

The docstring calls the filter *"load-bearing"* and says *"Measured on the real file, this drops
exactly the rows with no magic and nothing else"*. **That measurement was true when it was taken and
is a statement about the file's past**, not a property the filter enforces. This is precisely the
repo's own `unreadable-input-must-refuse-not-skip` shape, inside the module that owns global
uniqueness for a real-money magic.

### 1.6 🟡 MEDIUM — the documented allocation path cannot stay green

`magic.py:230-270` (`allocate`) vs `gen_magic_allocations.py:108-125` (`--check`).

`allocate()` correctly stamps a new GLOBAL allocation with the **current** commit. `--check` then
requires the whole store to reconcile against a fresh cutover import, which observes two commits and
refuses. So the supported allocator succeeds and the registered cage must fail.

**Consequence** is behavioural rather than immediate: an operator who needs a magic through the
documented path finds the cage red, and the two available workarounds are a hand-edit or a false
cutover provenance. This is the `feedback-audit-rule-rationale-not-compliance` shape — a guard that
refuses valid work teaches people to route around it.

---

## Part 2 — Reported by Codex, **NOT independently verified**

Recorded as claims to check. Two could not be reproduced in the auditor's sandbox for stated
environmental reasons, which is not evidence either way.

| # | Sev | Claim | why it is unverified |
|---|---|---|---|
| 2.1 | 🔴 | **Authorization and actor identity are forgeable data fields.** `owner_ref_problems()` checks field presence and hash *syntax* only — it never resolves the commit/blob, never confirms the path exists, and never establishes that the referenced text authorized *this* account/magic/candidate. `append_event()` trusts a caller-supplied `"actor": "user"`. Codex reports `owner_ref_problems(zero-filled but syntactically valid ref) -> []`. | Not re-measured here. ⚠️ **Note the overlap with an existing, ratified project position:** `check_s2a_attestation.py` already states that nothing in this repo can distinguish an owner action from an author typing the owner's name, because the repository commits under a **single git identity**. If that reasoning transfers, 2.1 is a *known and accepted* limit for the actor half — but the **unresolved `OwnerRef`** half is a separate claim and is not covered by it. Worth settling explicitly rather than by analogy. |
| 2.2 | 🟠 | **Allocation and attestation appends are check-then-write races.** Neither writer locks across reread → validate → append. Two processes can both select the same free magic and both succeed. | Codex states it did not execute this: a realistic reproducer needs temp file writes its sandbox disallowed. |
| 2.3 | 🟠 | **`check_state.ps1` judges staged bytes with worktree code.** `scripts/lib/magic_guard.ps1:64-77` correctly feeds *judged* inventory and allocation bytes, but loads `magic.py` itself from the **worktree path**. Stage a weakened `magic.py`, keep a strong worktree copy, and the hook tests the wrong implementation. | Not executed — reproduction necessarily writes a temporary git index/object, which the brief prohibited. **This is the highest-value item in Part 2**: it is the same staged-versus-worktree family the comments around it claim to have closed, and it would let a weakened rule commit green. |
| 2.4 | 🟡 | **C1 is not enforced on any deployment-consumer path.** `read_manifest()` recomputes correctly, but pinned search found **no production caller**; `attestation.py` accepts any syntactically valid `CAND-…` without resolving a manifest; there are no committed `factory/candidates/**` files and `factory/attestations.jsonl` does not exist at this pin. So recompute-on-read is demonstrated **for the CLI reader**, not for the path that decides what an account runs. | Partially corroborated in passing (the stores are indeed absent at the pin) but not systematically searched by this seat. |

**Codex found no counterexample** to C2 (the shared serializer), C3 (fifteen-field payload closure),
or C6 (the two-direction legacy comparison) taken in isolation. C6's *specificity* direction survived
attack; 1.4 above is a defect in **M6's membership rule**, not in M4/M5.

---

## Part 3 — Executed checks

| | |
|---|---|
| `magic.py verify` | exit 0 — 60 allocations, 63 inventory rows with numeric magics, legacy `[990103, 991001, 991002]` |
| `candidate.py --self-test` | exit 0 |
| `attestation.py --self-test` | exit 0 |
| `run_s10_tests.py` | Parts 1 and 1b passed in the auditor's sandbox, then **stopped at Part 1c** for want of a writable temp directory. **Incomplete evidence, not a cage failure** — the suite was not run to completion by the audit, and this file does not claim it was |
| this seat's re-measurement | `scratchpad/verify_s10.py` — probes 1.1 · 1.2 · 1.3 · 1.4 · 1.5, each with a control |

No repository file, index, or git object was modified by the audit or by the verification.

---

## Part 4 — What this changes about the slice's own acceptance

Design §10's S10 row asks for four things. Measured against them:

| acceptance | status after this audit |
|---|---|
| candidate digest recomputed and compared on read | **holds in `read_manifest`**, but see 2.4 — no production caller was found, so it is unexercised where it would matter |
| no non-`OBSERVED` attestation event without a human authorization ref | **holds as written** — and 1.2 shows the rule was written on the wrong axis: the ref is required, and it does not have to be a ref that authorized *the thing that happened* |
| `check_state.ps1` stays green | **green, and 1.4 + 1.5 are two ways it stays green while being wrong** |
| legacy magic exceptions preserved | **preserved, not closed** (1.4) |

The prohibition *"no renumbering of a live magic"* is genuinely enforced by the absence of a
renumber function, exactly as the docstring argues. That argument is sound where the module is the
only writer; 1.3 is what happens when it is not.
