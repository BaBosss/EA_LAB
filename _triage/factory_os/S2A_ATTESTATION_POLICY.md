# S2a ATTESTATION POLICY — DRAFT (ORDER-614 rev 2)

> **Status: DRAFT. Nothing here is bound yet.** This file and
> `S2A_ATTESTATION_VECTORS.jsonl` are the two artifacts ORDER-614 rev 2 asks for. They are written
> as new files so that landing them is one reviewable act; **no existing file was edited to produce
> them**, and in particular `check_s2a_attestation.py`, `s2a_attestations.jsonl` and the current
> `BUNDLE` are untouched. See §11 OPEN QUESTIONS for every judgement the lead must ratify before
> this becomes `S2A_ATTESTATION_POLICY.md`.

| | |
|---|---|
| `policy_version` | **`s2a-attestation/1`** (proposed; see OPEN-1) |
| supersedes | the prose criteria in the `check_s2a_attestation.py` module docstring (`A1`…`A8`) |
| companion corpus | `S2A_ATTESTATION_VECTORS.jsonl` — **55 vectors**, 18 green / 36 red / 1 abort |
| written against | `check_s2a_attestation.py` at HEAD `7616f2de` bundle, suite **35/35** green |

---

## 1. Why this document exists

`check_s2a_attestation.py` is a member of its own `bundle_sha256`, so **every repair to it voids
the record that authorised the previous repair.** Measured, not predicted — the digest history in
`s2a_attestations.jsonl` lines 2–6:

```
aaa5998d -> 1bd4d268 -> fa6bab35 -> 6ec25ca5 -> 7616f2de
```

Five signatures. **Four of them were for repairs that changed no rule.**

**rev 1's fix is refuted and is recorded here rather than quietly replaced.** It proposed binding a
machine-readable declaration of criteria and proving completeness by requiring every
`problems.append` site to carry a declared id. Codex broke it in one line: change a predicate to
`if False`, keep the declaration, keep the append site. Behaviour changes materially, the digest
does not, and the question *"did the semantics change?"* lands back on the author — which is
precisely what the order forbade. **A completeness check over call sites cannot see reachability.**

rev 2, adopted: bind the **policy** (this file) and the **conformance vectors** (the corpus);
leave the **implementation** outside the bundle. A behavioural change that matters shows up as a
vector that no longer reproduces. `if False` on any predicate named in §4 fails at least one
vector, because the vectors exercise the predicates rather than counting them.

---

## 2. What is bound, and what a signature is owed for

### 2.1 Proposed bundle membership — **OPEN-2**

| in the bundle | why |
|---|---|
| `_triage/factory_os/s2a_migration.jsonl` | D1 — the data the decision is about |
| `_triage/factory_os/s2a_coverage_reconciliation.json` | C8's evidence |
| `_triage/factory_os/S2A_OWNERSHIP_MIGRATION.md` | D2 — what the owner actually reads |
| `_triage/factory_os/S2A_ATTESTATION_POLICY.md` | **this file** — what the criteria MEAN |
| `_triage/factory_os/S2A_ATTESTATION_VECTORS.jsonl` | the corpus — what the criteria DO |
| `_triage/factory_os/check_s2a_migration.py` | **RATIFIED IN (§10.5 OPEN-2):** what D1’s own acceptance MEANS — it has no policy-and-vectors replacement yet, and dropping it would bind D1’s bytes while unbinding D1’s meaning |

| out of the bundle | why |
|---|---|
| `check_s2a_attestation.py` | the implementation. This is the whole change. |
| `gen_s2a_migration.py` | it produced D1, but **D1 itself is bound**, so the generator's bytes cannot change what the owner read without changing D1 too. |


### 2.2 When a signature is owed

- **Owed:** any change to the bound set above — including a change to this policy's criteria, their
  scope, their evaluation order, or the vector corpus.
- **Not owed:** any change to the implementation that keeps all `CANONICAL` vectors reproducing
  exactly. Repairs, refactors, renamed variables, better diagnostics, faster git reads.
- **Owed, and stated so nobody has to judge it:** *promoting a `PROVISIONAL` vector to `CANONICAL`,
  or adding any vector, is a change to the corpus and therefore owes a signature.* There is no
  "cosmetic vector" category and no exemption list — rev 1 died of exactly that.

### 2.3 The digest algorithm is part of the policy

```
digest = sha256( for each member in DECLARED ORDER:
                     utf8(path) || 0x00 || sha256( content with CRLF replaced by LF ) )
```

Member order is load-bearing (`B2`). CRLF normalization is load-bearing (`B3`). Both are pinned by
vectors with hermetic synthetic files, so the algorithm is testable without depending on the real
bundle's bytes.

---

## 3. Scope vocabulary — the rule stated once

Every criterion below carries exactly one scope. This distinction was paid for twice (ORDER-613 D1,
then again when A2 turned out to have the same defect A6 did):

- **`record-intrinsic`** — a claim about the RECORD ITSELF. Applies to **every** row, including
  superseded ones: it was true when the row was written or the row should not exist.
- **`in-force`** — a claim about the record's relationship to **current external state**. Applies
  **only** to the row in force for that `current_owner`. Superseded records are history. Demanding
  that history keep matching today's bytes is demanding that history be rewritten, and in an
  append-only file that is not merely wrong, it is **impossible** — the artifact could never
  survive its own evolution.
- **`global`** — a claim about the log as a whole, or about the file's bytes, not about one row.
- **`derivation`** — a rule about how the checker's own inputs are computed (which pins are stale),
  rather than about a record.
- **`precondition`** — a rule about whether a verdict can be reached at all.

---

## 4. The criteria

Evaluation order is **normative**, because the corpus asserts the exact multiset of reasons a
verdict produces. Within a row, the first criterion that fires in a marked `[stop]` group ends that
row's evaluation.

### 4.1 Load — `record-intrinsic`

| id | semantics | scope |
|---|---|---|
| **R1** | Every non-blank line of the log parses as JSON. A line that does not is reported against its line number; parsing continues. | record-intrinsic |
| **R2** | Every parsed line is a JSON **object**. A scalar or array is reported, **not raised** — "the tool broke" and "the file is wrong" must not share an outcome. | record-intrinsic |
| **R3** | A line whose **only** key is `_comment` is a header, not a record, and is skipped. The exemption is the **sole-key** form; an object carrying `_comment` **plus any other key** is a record and is held to everything below. | record-intrinsic |

### 4.2 Eligibility — `record-intrinsic`, `[stop]` group

A row that fails any of these is **ineligible**: it is reported, and it can never be the row in
force (see G2).

| id | semantics | scope |
|---|---|---|
| **R4** | Every required field is present and non-blank after stripping. Required = `bundle_sha256`, `current_owner`, `decision`, `signer`, `decided_at`, `reason`. | record-intrinsic |
| **R5** | `decision` is one of the **closed** vocabulary `APPROVED` \| `REFUSED`. | record-intrinsic |
| **R6** | `current_owner` is a `current_owner` that exists in D1. | record-intrinsic |
| **R7** | `current_owner` does not start with `EMBEDDED:` — an embedded fact owns no file and follows its parent, so the decision belongs against the parent's owner. R7 is separate from R6 because `EMBEDDED:*` values **do** appear in D1 and therefore pass R6. | record-intrinsic |
| **R8** | `REFUSED` carries a non-empty `reason`. ⚠️ **DISPUTED — see OPEN-3.** As implemented this is **unreachable**: `reason` is in R4's required set, so a blank reason fails R4 first and R8 can never fire. It has **no vector that only it can explain**, and this document says so rather than presenting it as covered. | record-intrinsic |

### 4.3 In-force criteria

Applied **only** to the row in force for each `current_owner`.

| id | semantics | scope | stops the row? |
|---|---|---|---|
| **F1** | `bundle_sha256` equals the digest of the current bundle (§2.3). If D1, D2, the reconciliation, this policy or the corpus changed after the record was written, the record no longer describes what is on disk and must be re-made against the current bytes. | in-force | **yes** |
| **F2** | If the owner's pin carries a note (N1 or N2), the record must set `stale_pin_acknowledged` to the **JSON boolean** `true` — identity, not truthiness, because the string `"false"` once granted the exemption — **and** carry a `stale_pin_acknowledgement` **object**. | in-force | no |
| **F3** | `stale_pin_acknowledgement.path` equals the path the note is on. | in-force | no (elif after F2) |
| **F4** | `stale_pin_acknowledgement.pinned_blob` equals the blob D1 pins for that path, **recomputed from D1**, not believed. | in-force | no (elif) |
| **F5** | `stale_pin_acknowledgement.current_blob` equals the blob HEAD has for that path — or the **literal string `MISSING`** when the path is absent at HEAD. Recomputed from HEAD, not believed. | in-force | no (elif) |
| **F6** | If `expected_post_state` is present it is an **object** naming a non-empty `path` and a non-empty `blob`. | in-force | no |
| **F7** | `expected_post_state.path` equals `current_owner`. A record may only make a claim about the file it decides for; binding anything else lets the approved target sit in a state nobody approved while the criterion stays green. | in-force | no (elif) |
| **F8** | `expected_post_state.blob` is a **40-character lowercase hex** oid and is not the literal `MISSING`. `MISSING` and an abbreviated oid are both accepted by git as arguments and neither is a statement about content. | in-force | no (elif) |
| **F9** | `expected_post_state.path` exists at HEAD. | in-force | no (elif) |
| **F10** | `expected_post_state.path` resolves to a **blob** at HEAD, not a **tree**. A directory has no content a decision could have approved, and git returns a tree oid happily. | in-force | no (elif) |
| **F11** | HEAD's blob at `expected_post_state.path` equals `expected_post_state.blob`. This is what turns an acknowledgement from a blanket exemption ("these bytes moved, fine") into a claim about a **specific** post-state. | in-force | no (elif) |

### 4.4 Global — the log as a whole

| id | semantics | scope |
|---|---|---|
| **G0** | An empty or partial log is **VALID**, not an error: it means no decision is recorded yet. | global |
| **G1** | Exactly one decision is **in force** per distinct `current_owner`: the **last eligible** line for that owner. Append-only, last line wins. | global |
| **G2** | An **ineligible** row (§4.2) can never become the row in force. Eligibility and in-force must be computed from **one** list built by **one** predicate — otherwise appending a single malformed line demotes the real decision to "superseded" and lets it skip every in-force criterion. | global |
| **G3** | When the row in force fails a `[stop]` criterion, the **superseded** row must not be reported as the current decision. The honest report is *"the record in force (line N) did not verify"*, naming the in-force line. ⚠️ **partial as implemented — see OPEN-4.** | global |
| **G4** | Superseded rows are exempt from every `in-force` criterion (F1–F11) and are still printed as history. | global |
| **G5** | **Append-only:** the bytes committed at HEAD must be a byte **prefix** of the bytes that are **STAGED**. Appending passes; editing or deleting anything already committed fails. | global |
| **G6** | A log not yet committed at HEAD has no history to protect: append-only is silent. (Reading both sides from git created a bootstrap deadlock — the suite failed because the log was not committed, and it could not be committed because the suite failed.) | global |
| **G7** | A path that is **tracked** but unreadable from the index is a **TOOL FAILURE**, reported by name. "I could not read it" must never share an outcome with "there is nothing to enforce". An **untracked** path falls back to the working tree, because there is nothing staged to judge. | global |
| **G8** | CRLF is normalized to LF on **both** sides of the G5 comparison before it is made. | global |

**The snapshot G5 judges is the INDEX, not the working tree**, and that is a criterion in its own
right (`G5-SNAPSHOT` in the corpus), pinned in **both** directions: a deletion present only in the
staged bytes is RED even though the working copy is intact, and a legal append in the staged bytes
is GREEN even though the working copy is truncated. One direction alone is satisfied by "red
whenever staged and worktree differ", which is a different rule.

### 4.5 Note derivation — `derivation`

The checker's stale-pin input is **derived**, and the derivation is part of this policy so that the
implementation that computes it can also leave the bundle.

| id | semantics | scope |
|---|---|---|
| **N1** | A D1 `owner_ref` whose `path` is **absent at HEAD** produces a note of kind `MISSING`. A proposal whose subject no longer exists is moot and a signer must not have to notice that unaided. | derivation |
| **N2** | A D1 `owner_ref` whose HEAD blob **differs** from `blob_oid` produces a note of kind `STALE`. | derivation |
| **N3** | A pin **equal** to HEAD produces **no** note. (Specificity: a rule that noted everything would demand an acknowledgement from every record and prove nothing.) | derivation |
| **N4** | A note applies to a record by **path identity**, never by containment. A note on `docs/OWNER.md.bak` must not demand an acknowledgement from `OWNER.md` — a substring test standing in for an identity test is the exact weakness that produced ORDER-602 H4. | derivation |

Both note kinds (`MISSING` and `STALE`) demand acknowledgement under F2. This is intentional and is
stated because it is not obvious from the names.

### 4.6 Bundle digest — `global`

| id | semantics |
|---|---|
| **B1** | The digest is computed by the algorithm in §2.3. |
| **B2** | Member **order** is load-bearing: the same members in a different order digest differently. |
| **B3** | Content is **CRLF-normalized** before hashing, so a Windows checkout does not void every record. |
| **B4** | The **member list** is the table in §2.1. ⚠️ **B4 has no vector and cannot have one** — it is a declaration, not a computation. Its only enforcement is that changing it changes this document, which changes the digest, which owes a signature. Stated rather than implied, per `GUARD_SHAPES.md`: *the guard's own limits are stated in the guard.* |

### 4.7 Precondition

| id | semantics | scope |
|---|---|---|
| **X1** | If D1 is absent there is no proposal to attest to: the run **aborts with exit 2**, distinct from both 0 and 1, so "no proposal" can never be read as "the log is valid" or as "a record is wrong". | precondition |

---

## 5. The conformance corpus — schema and runner contract

One JSON object per line in `S2A_ATTESTATION_VECTORS.jsonl`. A line whose only key is `_comment` is
not a vector (same rule as R3, deliberately).

```jsonc
{
  "vector_id":   "V-F7-001",
  "isolates":    "F7",                  // the criterion this vector is DESIGNED to isolate
  "isolation":   "unique" | "minimal-pair:<other vector_id>" | "none",
  "status":      "CANONICAL" | "PROVISIONAL",
  "description": "why this vector exists, in the terms of the defect it descends from",
  "input": {
    "attestations": [ <record object> | {"_raw_line": "<verbatim text>"} , ... ],
    "context": {
      "d1_present": true,
      "d1_rows":    [ {"entity": "...", "current_owner": "...",
                       "owner_ref": {"path": "...", "blob_oid": "<40hex>"} | null} ],
      "head_blobs": { "<path>": {"kind": "blob"|"tree", "oid": "<40hex>"} },
      "current_bundle_sha256": "<64hex>",         // XOR with bundle_files
      "bundle_files":  [ {"path": "...", "content": "..."} ],   // XOR with current_bundle_sha256
      "append_only":   { "path": "...", "committed": "<text>"|null, "staged": "<text>"|null,
                         "worktree": "<text>", "tracked": true, "index_readable": true }
    }
  },
  "expected_exit":            0 | 1 | 2,
  "expected_reasons":         ["F7@1", ...],
  "expected_current":         { "<owner>": {"line": 1, "decision": "APPROVED"|"UNVERIFIED"} },
  "expected_bundle_sha256":   "<64hex>",
  "note":                     "..."
}
```

**Runner contract — normative:**

1. `attestations` is materialized as the log file, one line per element, `\n`-terminated, in order.
   **Line numbers in `expected_reasons` are 1-based indices into this list.** A `_raw_line` element
   is written verbatim (this is how R1 and R2 are expressible at all — a malformed line cannot be
   expressed as a JSON object).
2. `context` is a **synthetic world**. `d1_owners`, the D1 pins and the vintage notes are all
   **derived** from `d1_rows` + `head_blobs` by N1–N4; they are never supplied directly. `head_blobs`
   is the whole of git as far as a vector is concerned: a path absent from the map does not exist at
   HEAD, `kind: "tree"` is a directory, `kind: "blob"` is a file at `oid`.
3. Exactly one of `current_bundle_sha256` and `bundle_files` is present. When `bundle_files` is
   present the digest is **computed** from it by §2.3, and `expected_bundle_sha256` asserts the
   result directly, so B1–B3 are pinned without reference to the real bundle.
4. `expected_reasons` is compared as an **order-insensitive multiset**. Each entry is `"<id>"` or
   `"<id>@<line>"`; an entry without `@line` matches any line but still consumes exactly one
   problem. **Extra problems and missing problems are both FAIL.** An implementation that reports
   the right verdict for the wrong reason does not conform.
4b. A **precondition failure** (exit 2) produces no `problems` list at all. By convention the
   corpus reports it as the single reason `X1`, so that `expected_reasons` is never empty for a
   non-zero exit — an empty reason list on a red run is indistinguishable from a runner that
   failed to collect reasons.
5. `expected_current`, when present, asserts the resolved in-force decision per owner. It is what
   makes G1–G4 observable at all — they change *which row is in force*, not *whether the run is red*.
6. `context.append_only` is evaluated **independently** of `input.attestations`. See §6 limitation 5.
7. `status: "PROVISIONAL"` vectors are **not** part of the frozen corpus and do not gate conformance.

**Why the corpus is hermetic.** No vector references a real path, a real blob, the real D1 or the
real bundle. If a vector had to be regenerated whenever D1 or HEAD moved, the corpus would
reproduce the signature loop this order exists to end — the failure mode would just have a new
name. Every oid in the corpus is a synthetic constant (`1111…`, `aaaa…`, `ffff…`).

---

## 6. What the vectors can and cannot guarantee

**This section is required by the order and is the reason the design is acceptable. It must not be
softened.**

**Full semantic equivalence between two implementations is not achievable** without binding the
implementation itself or possessing a complete executable specification. This policy binds neither.
**The vectors bound what is TESTED, not what is POSSIBLE.**

Concretely:

1. **A conforming implementation may differ on any input the corpus does not contain.** The corpus
   is 55 points in an input space that is not finite. Two implementations that reproduce all 55 can
   still disagree about the 56th.
2. **`if False` is caught only where a vector exercises the predicate.** That is the mechanism, and
   it is a real one — every criterion in §4 has at least one vector whose expected result changes
   if its predicate is neutralized (§7). It is **not** a proof that no neutralization exists: it is
   a proof that the neutralizations the corpus covers are caught.
3. **The corpus cannot see code that is not reached by any vector.** A new criterion added to the
   implementation, firing on inputs no vector produces, is invisible to conformance. It would make
   the implementation *stricter* than the policy, which is a real divergence the corpus does not
   detect. The only defence is the rule in §2.2 that a criterion change is a policy change.
4. **Reasons are matched by criterion id, not by semantics.** An implementation that emits `F7` for
   the right inputs while its message says something else conforms. The id mapping is a **reporting
   convention** the runner needs, not evidence — rev 1's mistake was treating exactly such a
   declaration as proof, and this policy uses it only for matching.
5. **Append-only is modelled separately from the records.** In production, G5's subject bytes and
   the parsed records are the same file. In the corpus they are two independent context fields, so
   a vector cannot express "the staged bytes contain a record the parser then rejects". This is a
   deliberate simplification and a real gap.
6. **The corpus says nothing about who made a decision.** Neither does the artifact. This
   repository commits under a single git identity, so nothing here separates the owner from any
   other writer. Do not cite an attestation record as a signature.
7. **`B4` — the bundle member list — is unvectorable** (§4.6). If a member is silently dropped from
   the implementation's list, every vector still passes.
8. **The corpus does not prove the criteria are the RIGHT criteria.** It proves an implementation
   reproduces them.

**What it does buy, stated as plainly:** a repair to the implementation that keeps all `CANONICAL`
vectors reproducing costs **no signature**, and a repair that changes any of the 55 documented
behaviours cannot land silently. That is weaker than rev 1 pretended to give and stronger than
rev 1 actually gave.

---

## 7. Coverage — criterion → vectors

`unique` = there is a vector whose expected result **only** that criterion can explain.
`minimal-pair` = the criterion is isolated by two vectors differing on exactly **one** input axis;
this is stated instead of claiming uniqueness, because a derivation rule (N1, N2) can only be
observed through the criterion it feeds.

| criterion | vectors | isolation |
|---|---|---|
| POSITIVE | `V-POS-001` | unique |
| G0 | `V-G0-001` | unique |
| R1 | `V-R1-001` | unique |
| R2 | `V-R2-001` | unique |
| R3 | `V-R3-001` (sole-key skipped) · `V-R3-002` (non-sole-key is a record) | minimal pair |
| R4 | `V-R4-001` | unique |
| R5 | `V-R5-001` | unique |
| R6 | `V-R6-001` | unique |
| R7 | `V-R7-001` | unique |
| R-SCOPE | `V-RSCOPE-001` | unique |
| **R8** | `V-R8-001` | **none — OPEN-3** |
| F1 | `V-F1-001` | unique |
| F2 | `V-F2-001` · `V-F2-002` (string `"false"`) · `V-F2-003` (flag without object) · `V-F2-004` CONTROL | unique + control |
| F3 | `V-F3-001` | unique |
| F4 | `V-F4-001` | unique |
| F5 | `V-F5-001` · `V-F5-002` (the `MISSING` literal branch) | unique |
| F6 | `V-F6-001` (bare string) · `V-F6-002` (object missing `blob`) | unique |
| F7 | `V-F7-001` | unique |
| F8 | `V-F8-001` (`MISSING`) · `V-F8-002` (abbreviated) · `V-F8-003` (uppercase) | unique |
| F9 | `V-F9-001` | unique |
| F10 | `V-F10-001` | unique |
| F11 | `V-F11-001` · `V-F11-002` CONTROL | minimal pair |
| G1 | `V-G1-001` | unique |
| G2 | `V-G2-001` | unique |
| G3 | `V-G3-001` | unique |
| G4 | `V-G4-001` (old bundle) · `V-G4-002` (no ack) · `V-G4-004` (post-state) · `V-G4-003` **not a loophole** | unique |
| G5 | `V-G5-002` (edit) · `V-G5-003` (delete) · `V-G5-001` CONTROL | unique + control |
| G5-SNAPSHOT | `V-G5-004` (staged-only deletion RED) · `V-G5-005` (worktree-only truncation GREEN) | unique, both directions |
| G6 | `V-G6-001` | unique |
| G7 | `V-G7-001` (tracked, unreadable) · `V-G7-002` (untracked fallback) | unique |
| G8 | `V-G8-001` | unique |
| N1 | `V-N1-001` | minimal pair with `V-POS-001` |
| N2 | `V-N2-001` | minimal pair with `V-POS-001` |
| N3 | `V-N3-001` | unique |
| N4 | `V-N4-001` | unique |
| B1 | `V-B1-001` | unique |
| B2 | `V-B2-001` | unique |
| B3 | `V-B3-001` | unique |
| **B4** | — | **none, and cannot have one** (§4.6) |
| X1 | `V-X1-001` | unique |

**Two criteria are declared with no uniquely-explaining vector, and both are named above rather
than padded.** `GUARD_SHAPES.md` shape 3: *a criterion nobody names is a criterion nobody tested* —
and a criterion listed as covered when it is not is worse, because it reads as coverage.

---

## 8. How this maps onto ORDER-614 rev 2's acceptance

| | claim | evidence, and where it is still owed |
|---|---|---|
| **E1** | bundle binds policy + vectors, implementation outside | §2.1 declares it. **The digest-behaviour negatives (reword a comment ⇒ unchanged · change a declared scope ⇒ changed) are not demonstrated by these two files** — they are properties of the landed bundle list and must be shown when it lands. `if False` ⇒ a vector fails: §7 shows every criterion has an exercising vector; the permanent fixture this requires is **not built here** (OPEN-6). |
| **E2** | every criterion has ≥1 vector only it can explain | §7, **with two honest exceptions named** (R8, B4) rather than concealed. |
| **E3** | the five historical digests stay resolvable, lines 2–6 not invalidated again | These files are **new** and edit nothing, so at this moment nothing is invalidated. **Landing them changes the bundle and therefore voids line 6** — that is the one signature the order says it costs. The five historical digests remain resolvable because no bundled file's history is rewritten. |
| **E4** | D1 in-force scoping and D2 `expected_post_state` survive unchanged | §3 + §4.3 restate them verbatim in scope and demand; `V-G4-00x` and `V-F6…F11` are the same fixtures the existing suite already holds green. **This changes what is bound, never what is demanded.** |

---

## 9. Relationship to the existing suite

`run_s2a_attestation_tests.py` (**35** assertions, 0 BAD, counted from the run output at
`7616f2de` — `grep -c '\[OK \]'` = 35, `grep -c '\[BAD\]'` = 0) is **not** replaced by this
corpus and should not be deleted when it lands. The two do different jobs:

- the suite proves the implementation behaves correctly **against the real repository** — real D1,
  real HEAD, the real log's A7 state;
- the corpus proves **any** implementation reproduces the documented behaviour **hermetically**.

Every negative the suite holds is represented in the corpus. Three things the corpus has that the
suite does not: the digest algorithm (B1–B3), note derivation (N1–N4), and X1.

---

## 10. Guard-shape pre-flight for this draft

Run against `docs/GUARD_SHAPES.md` before the lead reads it, because a policy document that
recreates a defect shape is worse than no policy.

| shape | check |
|---|---|
| **1** — reads the wrong bytes | G5's snapshot is declared (**index**, worktree only when untracked) and pinned in both directions. Every context field in §5 names which snapshot it models. |
| **2** — names not values | R5, R7 and B4 are closed vocabularies stated as **allowlists**. F4/F5/F11 compare **recomputed values**, never the presence of a field. §6.4 states plainly that reason-ids are matched as **names** and are therefore not evidence. |
| **3** — cannot fail | **Two instances found and reported, not hidden:** R8 is unreachable (OPEN-3) and B4 is unvectorable (§4.6). A third is flagged at OPEN-5 (the `pinned and` guard in F4). |
| **4** — a claim without measuring it | 55 / 18 / 36 / 1 were counted from the generated file, not typed. The digest constants in the corpus were computed, not invented. The five-digest history was read from `s2a_attestations.jsonl`. |
| **5** — the repair graded by the finding it closes | This draft is a **repair to a guard**, so the pre-flight applies to it. The engagement assertion is `V-POS-001` + the 18 green vectors: if the new machinery were inert or over-strict, they fail. The specificity assertions are `V-N3-001`, `V-N4-001`, `V-G5-005`, `V-F2-004`, `V-F11-002` — each fails if the repair over-reaches onto inputs the original counter-example never touched. |

---

## 10.5 RATIFICATION AT LANDING (2026-07-31) -- what was decided, by whom

The owner delegated the landing decisions to the lead's recommendation ("ทำตามที่นายแนะนำได้เลย"),
and these are the calls, so the signed document carries them rather than a chat transcript:

- **OPEN-1** version = `s2a-attestation/1`, declared in this file's header and in the runner.
- **OPEN-2** `check_s2a_migration.py` **STAYS IN the bundle** (the conservative reading, against
  §2.1's first draft): this policy absorbed only its `pin_vintage_notes` semantics (N1-N4). Its
  OWN criteria -- what D1's acceptance MEANS -- have no policy-and-vectors replacement, and
  dropping it would bind D1's bytes while unbinding D1's meaning. It leaves when it gets the
  same treatment. `gen_s2a_migration.py` leaves as proposed (its output is bound).
- **OPEN-3** R8: `REQUIRED` stays exactly as it is; the unreachable branch is DELETED. Making
  `reason` conditionally required would change what is demanded, which E4 forbids. R8 stays in
  §4 as DISPUTED with its PROVISIONAL vector, so the criterion's history is not erased.
- **OPEN-5** the dead `pinned and` guard in F4's branch is deleted.
- **OPEN-7** the `R*/F*/G*/N*/B*/X*` scheme is adopted; the implementation now emits these ids.
- **OPEN-8** the invalid-JSON message now carries the `R1` prefix and a `line N` token.
- **OPEN-10** renamed to the final names BEFORE the digest was computed, as required.
- **OPEN-4 / OPEN-6 status:** the runner and the permanent mutation harness ARE built
  (`run_s2a_conformance.py`, outside the bundle); G3's partial coverage is frozen as-is by the
  corpus and remains flagged, not silently fixed -- fixing it changes behaviour and therefore
  owes its own vector-and-signature round.

## 11. OPEN QUESTIONS FOR THE LEAD

Every judgement call made in these two files, and every place ground truth could not be determined
from the repository. **None of these were decided on the owner's behalf.**

**OPEN-1 · the policy version string.** Proposed `s2a-attestation/1`. Ratify the name and decide
whether the version is a field inside this document (bound by the digest, so a version bump owes a
signature — which is correct but means the bump and the change are one act) or a separate register.

**OPEN-2 · does `check_s2a_migration.py` leave the bundle?** This is the largest judgement in the
draft. *For leaving:* it is an implementation, and the only semantics the attestation depends on
(`pin_vintage_notes`) are now written down as N1–N4 and exercised by vectors. *For staying:* it also
defines what D1's own acceptance MEANS (C2 refusing `APPROVED` inside D1, the C4 pin rules), and
nothing in this policy or corpus covers those — dropping it binds D1's **bytes** while leaving
D1's **meaning** unbound. `gen_s2a_migration.py` is the easier call and I propose dropping it. **I
did not decide this; §2.1 states my proposal and this note states the cost.** If the answer is
"stays", then a repair to `check_s2a_migration.py` still costs a signature and the order is only
partly satisfied — which should be said in the order rather than discovered later.

**OPEN-3 · R8 is unreachable.** Measured: `reason` is in `REQUIRED`, so `good(decision='REFUSED',
reason='')` fails **R4**, never R8 — the existing suite's case labelled *"A5 REFUSED with no
reason"* asserts the substring `'is missing'`, which is **R4's message**. This is guard shape 3
sitting in the criterion list since ORDER-602. Two resolutions, both needing ratification:
(a) **delete R8** and state in R4 that a reason is required for every decision — honest, and loses
nothing that is enforced today; (b) **make `reason` conditionally required** (mandatory for
`REFUSED`, optional for `APPROVED`), which gives R8 real content and a uniquely-explaining vector,
but **changes what is demanded of a record** and therefore is not a repair — it is a policy change
that owes a signature and contradicts E4's *"never what is demanded"*. `V-R8-001` is marked
`PROVISIONAL` until this is answered.

**OPEN-4 · G3 is partial, and the corpus records it as-is.** Only the criteria that **stop** the
row (F1, and the eligibility group) leave the owner reported as `UNVERIFIED`. A row that fails
F2–F11 is still reported as the current decision — with problems printed and exit 1, so it is not a
green bypass, but the printed line says `APPROVED` for a record that did not verify. That is the
same class as Codex round 2 Spec 9, fixed only for the `continue` paths. **The corpus freezes
current behaviour** (`V-F2-001` etc. expect `APPROVED`). If the lead wants the honest report for
all criteria, that is an implementation change **and** a corpus change, and it owes a signature.

**OPEN-5 · a dead guard inside F4.** The implementation only compares `pinned_blob` when D1
actually has a pin for that path (`if pinned and ...`). Under N1/N2 a note can only be derived from
a pin, so the guard is unreachable — a defensive `and` that reads as a check. Either delete it or
declare the case it defends. Not fixed here (implementation edit).

**OPEN-6 · the permanent `if False` fixture is not built.** E1 requires the neutralized-predicate
case to be *"a permanent fixture"*. §7 shows every criterion is exercised, which is the raw
material, but the **runner** that materializes a vector into a temp log + a fake git resolver, and
the mutation harness that neutralizes each predicate in turn and requires ≥1 vector to fail, are
**not written** — this task was scoped to the two artifacts. That harness is the acceptance, not a
claim about it, and it belongs in the same landing.

**OPEN-7 · the id scheme is new.** The implementation today emits `A1`, `A2`, `A4`, `A5`, `A6`,
`A8`; this policy splits them to predicate granularity (`R4`, `R5`, `F1`, `F2`…`F11`) because
`if False` on a *sub*-predicate is invisible at `A6` granularity. The mapping is `A1 → R1,R2,R3,R4,
R5` · `A2 → F1` · `A3 → G1` · `A4 → R6,R7` · `A5 → R8` · `A6 → F2,F3,F4,F5` · `A7 → G5,G6,G7,G8` ·
`A8 → F6…F11`. Ratify the scheme, or ratify keeping the `A*` names with sub-letters. **Renaming
touches the implementation only, not what is demanded.**

**OPEN-8 · one criterion of the current implementation has no id at all.** The invalid-JSON message
(`"…is not valid JSON: …"`) carries no criterion prefix, so it cannot be matched by the runner
contract in §5.4. I assigned it `R1`. This requires an implementation change to emit the prefix.

**OPEN-9 · `--template` is out of scope.** The `--template` branch prints a ready-made line and
exits 0. I did not write a criterion or a vector for it: it produces no verdict. If the lead wants
the template's **shape** pinned (so a field cannot silently vanish from what the owner is handed),
that is a criterion and needs a vector.

**OPEN-10 · file names at landing.** These drafts are `S2A_ATTESTATION_POLICY.md` /
`S2A_ATTESTATION_VECTORS.jsonl` so they edit nothing. §2.1 assumes they land as
`S2A_ATTESTATION_POLICY.md` / `S2A_ATTESTATION_VECTORS.jsonl`. **The bundle binds paths as well as
content** (§2.3 hashes the path), so the rename must happen *before* the digest the owner signs is
computed, not after.

**OPEN-11 · ground truth I could not determine from the files.** (a) Whether the owner intends the
attestation to keep covering `gen_s2a_migration.py` for a reason not written down anywhere I could
find — the `BUNDLE` comment says *"what produced D1"* and no order explains why the producer must
be bound when its output already is. (b) Whether `EMBEDDED:*` (the literal star, present in D1 as a
`current_owner`) is meant to be reachable by R7 — it starts with `EMBEDDED:` so it is refused, but
whether it is a real owner row or a placeholder is not stated in D1. (c) The exact intended
semantics of a `MISSING`-kind note under F2: it currently demands the same acknowledgement as
`STALE`, which is defensible, but nothing states it was decided rather than inherited.
