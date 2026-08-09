# Codex blind audit #8 — ORDER-602 sign-off boundary and owner-state split

**Date:** 2026-07-30  
**Mode:** independent, adversarial, read-only except this report  
**Verdict:** **ORDER-602 NOT DONE**  
**ORDER-600 closable apart from the owner's decision?** **NO.**

The new file separation removes the old mechanical deadlock: an `APPROVED` record can now be added
without editing D1, its generator, or C2. It does **not** yet establish that the owner made the decision,
that the history is append-only, or that the owner signed the material and rules they actually reviewed.
A coordinated proposal-plus-signature input passed.

## 1. Verdict per ORDER-602 item

| Item | Verdict | Reason |
|---|---|---|
| **A — sign-off boundary** | **NOT DONE** | `authorization_ref` required by the order is absent; signer and time are unchecked free text; the digest covers D1 only; append-only is prose only. |
| **B — split `UNOWNED`** | **NOT DONE** | The closed four-state vocabulary is a real improvement, but two evidence anchors do not establish the state they authorize, and C8 still accepts arbitrary normalized cell labels as long as an unrelated source substring is present. |
| **C — three rationales** | **NOT DONE** | `RunTransition` still relies on a false replacement claim: the existing event system explicitly records `RUN_STARTED`, including one real committed event. |
| **D — stale-pin boundary** | **NOT DONE** | Any truthy JSON value, including the string `"false"`, grants the exemption; it carries no structured identification of which stale bytes were knowingly accepted. |
| **E — concurrent-input fingerprint** | **NOT DONE** | The end check reuses the cached starting HEAD, so it cannot observe HEAD moving; it fingerprints HEAD/index while several judged inputs are read from the working tree and are absent from the fingerprint. |

## 2. Simpler alternative

ORDER-600's immediate blocking decision is the Coverage transfer owned by the user. The smaller boundary
is to record that one decision in an existing owner-controlled decision surface and have D1 carry a
structured `authorization_ref` to it. A generic 23-owner sign-off subsystem can wait for the attestation
primitive already planned later in the Factory OS.

If this new log is retained, it needs to be treated as an attestation log, not as proof of a signature,
unless the repository can distinguish an owner action from an author typing the owner's name.

## 3. Findings

### BLOCKER 1 — The validator accepts a manufactured owner approval

**Reproduced.**

`AGENT_TASKBOARD.md:132` requires:

```text
proposal_sha256 · current_owner · decision · signer · decided_at · reason · authorization_ref
```

But `_triage/factory_os/check_s2a_signoff.py:44` omits `authorization_ref`. The checker validates only
that `signer` and `decided_at` stringify to non-empty values (`:82-89`). It does not resolve an owner
action, validate a time, or distinguish the proposal author from the owner.

This in-memory input was accepted with no problems:

```json
{
  "proposal_sha256": "<digest of the candidate D1>",
  "current_owner": "MASTER_BACKLOG.md",
  "decision": "APPROVED",
  "signer": "user (Boss)",
  "decided_at": "never",
  "reason": "x"
}
```

Observed output:

```text
ATTACK_B fake_approval_without_authorization_ref problems=[] current='APPROVED'
```

**Consequence:** any repository writer can make the artifact report that the user approved. The digest
proves which bytes the row names; it does not prove who approved them.

**Minimal fix:** require a structured `authorization_ref`, resolve it to a pre-existing action on an
owner-controlled surface, and reject a sign-off created in the same change as its alleged authorization.
If that provenance cannot be established locally, rename the result to an unverified attestation and do
not use it to close the owner decision.

### BLOCKER 2 — The approval does not bind what the owner read or the acceptance rules

**Reproduced by trace and composition.**

`proposal_digest()` hashes only `_triage/factory_os/s2a_migration.jsonl`
(`check_s2a_signoff.py:47-50`). It does not cover:

- `_triage/factory_os/S2A_OWNERSHIP_MIGRATION.md`, the document presented to the owner;
- `_triage/factory_os/s2a_coverage_reconciliation.json`, which carries C8's evidence;
- the generator;
- the migration checker or sign-off checker whose rules define what the approval means.

Changing any of those leaves the signature current as long as D1's bytes stay fixed. Changing a checker
after signing silently reinterprets the same decision under new rules.

**Consequence:** the owner can appear to approve one explanation and one acceptance contract while the
live gate evaluates another.

**Minimal fix:** sign a versioned bundle manifest containing hashes/blob IDs for D1, D2, the coverage
reconciliation, generator, and both validators. A rule or reviewed-document change must invalidate the
decision and require re-authorization.

### BLOCKER 3 — “Append-only” is not enforced

**Reproduced.**

The header says never edit or delete a previous line
(`_triage/factory_os/s2a_signoff.jsonl:1`), but `check()` simply overwrites
`current[current_owner]` in file order (`check_s2a_signoff.py:79-119`). The test at
`run_s2a_signoff_tests.py:147-152` proves only “last line wins”; it does not test immutability.

I checked the same current approval with (a) an earlier `REFUSED` line present and (b) that line deleted:

```text
ATTACK_D prior_line_removed
  both_problems=[]
  removed_problems=[]
  both_current='APPROVED'
  removed_current='APPROVED'
```

**Consequence:** the artifact can lose or rewrite the history it claims to preserve while remaining
green.

**Minimal fix:** in the staged candidate, require the HEAD version of the log to be an exact raw-byte
prefix. Add a previous-record hash/sequence if the log also needs standalone tamper evidence. The
negative fixture must edit and delete an established line, not merely append a superseding line.

### MAJOR 4 — A passing-but-useless proposal can be paired with the manufactured approval

**Reproduced. This is the coordinated attack requested by the brief.**

Starting from the real D1 and reconciliation, entirely in memory:

```python
for row in d1:
    for key in (
        "breaks_if_moved", "breaks_if_not_moved", "reverse_steps",
        "evidence_lost", "retention_window"
    ):
        row[key] = "x"
    if row["disposition"] == "KEEP":
        row["keep_reason"] = "x"
    row["signoff_owner"] = "someone"

for cell in every_UNVERIFIED_IMPORT_cell:
    cell["cell"] = unique("MEANINGLESS-CELL")
    # leave source_token and source_coordinates unchanged
```

Observed:

```text
ATTACK_A nine_criteria_problems='' meaningless_cells=32
```

The same attacked D1 digest plus the fake approval from BLOCKER 1 produced:

```text
ATTACK_B fake_approval_without_authorization_ref problems=[] current='APPROVED'
```

The generator drift step does not provide a semantic oracle: if the generator emits this shape, D1
matches it. The human-review disclaimer at `check_s2a_migration.py:1051-1054` is honest, but the new
sign-off boundary does not require or bind evidence that the human review happened.

**Why C8 passed:** `_triage/factory_os/check_s2a_migration.py:748-757` requires only that
`source_token` be a substring of the raw source column. It never proves that the declared normalized
`cell` was derived from that token. A traceable token and a meaningless label can coexist.

**Consequence:** the pair reads as a valid, approved migration while the material a reader needs is
garbage.

**Minimal fix:** bind the owner decision to the reviewed bundle and its human-review record. For C8,
derive the normalized label deterministically from the exact raw token; if parsing is not possible,
store the raw token as `UNPARSED` rather than accepting a caller-invented label.

### MAJOR 5 — `stale_pin_acknowledged` repeats the free-text-exemption defect in a new type

**Reproduced.**

`check_s2a_signoff.py:111` uses generic truthiness:

```python
if owner in stale_owners and not row.get("stale_pin_acknowledged"):
```

Against the real stale `AGENT_TASKBOARD.md` notes, this input passed:

```json
{
  "current_owner": "AGENT_TASKBOARD.md",
  "decision": "APPROVED",
  "signer": "user (Boss)",
  "decided_at": "not-a-date",
  "reason": "x",
  "stale_pin_acknowledged": "false"
}
```

Observed:

```text
ATTACK_C string_false_stale_ack problems=[] current='APPROVED'
```

**Consequence:** an input that visually says false grants the bypass. Even literal `true` records
neither the stale blob nor the current blob the owner accepted.

**Minimal fix:** require the JSON boolean `true` by identity and require a structured acknowledgement
for every applicable note: owner path, pinned blob, current blob/missing state, reason, and
`authorization_ref`. Recompute and compare those values.

### MAJOR 6 — E cannot detect the HEAD movement it claims to detect

**Reproduced without touching the repository.**

`head_oid()` resolves HEAD once and memoizes it (`check_s2a_migration.py:170-182`).
`input_fingerprint()` calls that memoized function (`:185-202`). The end-of-run comparison
(`:1037-1043`) therefore compares the starting HEAD with the starting HEAD.

With a probe returning `head-A` on the first HEAD read and `head-B` on the next possible read:

```text
first= ('head-A', '<same-index-hash>')
second= ('head-A', '<same-index-hash>')
equal= True
rev_parse_HEAD_calls= 1
```

There is a second seam: the fingerprint covers HEAD and `git ls-files -s`, while the judged schema,
D1, reconciliation, and `MASTER_BACKLOG.md` are opened from the working tree
(`check_s2a_migration.py:246`, `:263`, `:617`, `:652`, `:778`). An unstaged concurrent edit changes
the evidence without changing either fingerprint component.

**Consequence:** the run can combine cached answers and working-tree inputs from different moments and
still print a verdict.

**Minimal fix:** keep a pinned starting HEAD for cache keys, but perform a fresh `git rev-parse HEAD` at
the end. Fingerprint the exact bytes of every working-tree input read, or read all judged inputs from
one immutable snapshot.

### MAJOR 7 — One of C's repaired rationales still contradicts the source

**Reproduced by opening the cited source.**

The `RunTransition` row says the experiment event log “records completed occurrences” and therefore a
half-finished run leaves no trace (`s2a_migration.jsonl:15`). But:

- `docs/memory_control/experiment_events/schema/event-v1.schema.json:104` defines `RUN_STARTED`;
- the lifecycle includes it at `:111`;
- `docs/memory_control/experiment_events/events-2026-07.jsonl:4` contains a real committed
  `RUN_STARTED`;
- `_mt5_auto/d1g_event_chain.ps1:2,66` describes and emits it as the pre-run event.

The scheduler may still lack an automatic recovery checkpoint, but that is a different and narrower
claim. The replacement prose again reaches for a true gap through a false causal bridge.

**Consequence:** C's acceptance (“the evidence actually establishes the claimed failure”) is not met.

**Minimal fix:** state the measurable gap: which scheduler paths fail to emit `RUN_STARTED` before
launch, or which recovery fields (`attempt`, last completed step, lease) the existing event contract
cannot represent. Do not say the event system records only completed occurrences.

### MODERATE 8 — The closed owner-state list limits the old attack, but two anchors do not prove their state

**Verified by trace; not claimed as a scalable 27-row bypass.**

The closed `UNOWNABLE` map at `check_s2a_migration.py:135-143` is materially stronger than audit 7's
“file mentions entity” check: only four entities can receive the exemption, and their disposition
rules differ. The old 27-row escalation is closed.

However, validation at `:382-387` proves only that a hard-coded substring remains somewhere in the
cited file. Two anchors do not establish the state they authorize:

- `LogicalSymbol` uses `"broker symbol per lane"` to authorize `NOT_YET_BUILT`;
- `SafeProjection` uses `"Generated projections go to"` to authorize
  `DERIVED_NOT_PERSISTED`.

Those phrases describe shape/location, not non-existence or persistence state. The checker comment calls
them claim sentences, but they are not.

**Consequence:** the state assignment remains a judgement embedded in validator code, with a source
fragment that can stay green while the judgement is false.

**Minimal fix:** recompute what can be recomputed (planned path absent, schema marks derived/transient,
no tracked owner exists). Route genuinely non-computable ownership judgements through the same
authorization boundary rather than presenting a substring as proof.

## 4. What I checked and found sound

- All three commands required by the brief returned exit 0.
- The full S2a gate reported seven green steps, 32/32 mutations caught, loader/advisory/drift controls
  green.
- C2 still rejects `APPROVED` inside D1.
- A changed D1 digest invalidates an old decision.
- The broad 27-row `UNOWNED` attack no longer scales: only four closed entities may use owner states,
  and their state/disposition/derived constraints are distinct.
- A fabricated cell relabelled `LIVE` is now rejected.
- Stale-pin notes are structured and exact-path matched; the `.bak` substring false alarm is fixed.
- An `EMBEDDED:` pseudo-owner decision is rejected.
- The sign-off test leaves the real log byte-unchanged.
- Hashing index content instead of `.git/index` mtime removes the self-reported ordinary-commit false
  alarm, although it does not complete E.

## 5. What the brief could have steered this audit away from

- “Audit 7's blocker and all its findings are fixed” was treated as a claim, not a premise. The
  `RunTransition` source contradiction and E's cached-HEAD defect sit outside the primary sign-off
  questions and would have been missed by accepting that sentence.
- The brief explicitly excluded the stale design `all_clear` lines and false `x-enforced-by` names; I
  did not re-report them.
- “No security dimension” correctly excludes external attack analysis, but it cannot remove the local
  governance question the brief itself asks: whether the artifact distinguishes an owner decision from
  another repository writer typing the owner's name. It currently does not.

## Final verdict

**NOT DONE.** The largest reason is that the new “sign-off” artifact proves neither owner action nor an
append-only history, and it can approve a coordinated passing-but-useless proposal. `ORDER-600` is not
closable yet, even setting aside the owner's still-missing decision.
