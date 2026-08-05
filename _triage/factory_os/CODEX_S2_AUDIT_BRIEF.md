# Codex blind audit brief — Factory OS slice **S2** (ownership migration + `OwnerRef` discipline)

> Written 2026-08-03 by lane `S-2026-08-03-AUDITCOV`. **You are the independent brain.**
>
> This slice's built code has **never been independently audited**. Nothing here tells you what any
> previous session concluded, deliberately. Attack the claims; do not restate them.

---

## 0. Read at a PINNED commit · READ-ONLY

```bash
git show a87f7448:<path>
```

Do not edit, create, stage or commit anything. Do not write to `factory/`, `_triage/` or `.git/`.
Your deliverable is a report on stdout.

## 1. What you are auditing, in one sentence

The rule that **every Factory artifact holds an owned fact only as a pinned `OwnerRef`, never as a
mutable copy** — plus the migration table that records who owns what, and the attestation log that
records a decision about the proposal, bound to the exact bytes it was written about.

**The stake.** `OwnerRef` is the pin primitive every other entity in this system references. If a
pin can be satisfied by the wrong bytes, or can be silently skipped, then every downstream claim of
the form *"this artifact cites its owner"* is a claim about a citation nobody checked. This slice is
also the one that decides what an **approval** means in this repository, which is the most abusable
concept in it.

## 2. 🔴 One thing this brief will not do for you

**`run_s2a_gate` F2 and `check_coverage_transfer` A8 are RED at this pin.** I am telling you they are
red and I am **deliberately not telling you why**, because the cause is squarely inside this slice's
subject matter and an independent diagnosis is worth more than a confirmation of mine.

**Diagnose the red yourself.** Do not assume it is benign, do not assume it is a transient, and do
not assume it is unrelated to the design question. If you conclude it is a routine consequence of
some other lane's work, say what makes it routine.

## 3. Read these, in this order

| | |
|---|---|
| `_triage/EA_LAB_FACTORY_OS_DESIGN.md` | **§1.1–1.4** (current-state ownership map — who owns what, and what is genuinely unowned) · **§4** preamble on generated contracts · **§10** the **S2** row |
| `_triage/factory_os/CONTRACTS.md` | `OwnerRef` first, then every entity that embeds one |
| `_triage/factory_os/S2A_ATTESTATION_POLICY.md` | version `s2a-attestation/1` — the criteria, their semantics, their scope (record-intrinsic vs in-force vs global) and their evaluation order |
| `_triage/factory_os/S2A_OWNERSHIP_MIGRATION.md` | the migration document |
| `AGENT_TASKBOARD.md` | rows **`ORDER-602`** and **`ORDER-614`** |

## 4. The artifacts

| file | what it decides |
|---|---|
| `_triage/factory_os/check_s2a_migration.py` | the migration acceptance rules, including **C2** which refuses `APPROVED` inside D1 |
| `_triage/factory_os/check_s2a_attestation.py` | the append-only attestation log's criteria — **the implementation of the policy, not the policy** |
| `_triage/factory_os/run_s2a_conformance.py` | what holds the implementation to `S2A_ATTESTATION_POLICY.md` against the frozen corpus |
| `_triage/factory_os/S2A_ATTESTATION_VECTORS.jsonl` | the frozen corpus — what the criteria *do* |
| `_triage/factory_os/run_s2a_gate.py` | the gate |
| `_triage/factory_os/gen_s2a_migration.py` · `gen_s2a_migration_doc.py` | the generators |
| `_triage/factory_os/s2a_migration.jsonl` · `s2a_attestations.jsonl` · `s2a_coverage_reconciliation.json` | the stores |
| `_triage/factory_os/check_attested_pin_staged.py` | the front guard that enforces a pin at commit time |

## 5. The claims — refute these

| # | claim | where |
|---|---|---|
| C1 | every Factory artifact holds owned facts **only as a pinned `OwnerRef`** — **zero mutable copies** (design §10's acceptance) | the migration checks |
| C2 | **no owner may be demoted without its owner's approval** (design §10's prohibition) | the acceptance rules |
| C3 | this is an **attestation log, not proof of an owner decision**, and must never be described as one — nothing here can distinguish an owner action from an author typing the owner's name, and that is **measured**: the repository commits under a single git identity, so authorship cannot separate them either | `check_s2a_attestation.py` |
| C4 | the criteria live in the **policy**, not in the code's docstring, and `run_s2a_conformance.py` holds the implementation to it — because a prose copy would drift, and an earlier header **had already drifted** (a criterion was unreachable and the header did not know) | the policy binding |
| C5 | recording a decision **no longer requires editing the evidence, the acceptance rule and the generator in one commit** — approving costs one appended line, while `check_s2a_migration` **C2** keeps refusing `APPROVED` inside D1 | the deadlock fix |
| C6 | the attestation is **bound to the exact bytes it was written about** | the pin mechanism |
| C7 | the frozen corpus is what the criteria **do**, so a criterion that changes meaning fails conformance rather than passing quietly | `S2A_ATTESTATION_VECTORS.jsonl` |

## 6. Where to aim

1. **C6 is the claim the red gate is standing next to. Start there.** What exactly does the pin
   cover — a path, a blob, a section, a byte range? And what is the relationship between *the bytes
   an approval pins* and *the bytes that approval authorises someone to change*? Work out whether
   that relationship can be self-defeating, and under which sequence of legitimate actions.
2. **C4's conformance binding.** Does `run_s2a_conformance.py` compare the implementation's
   *behaviour* against the corpus, or its *text* against the policy? Only the first can catch a
   criterion that became unreachable. Then: is every criterion in the policy **reachable** — can each
   one both PASS and FAIL on some vector? A criterion that cannot FAIL is decoration; one that
   cannot PASS makes its condition structurally impossible to satisfy.
3. **C7's "frozen" corpus.** What enforces frozen? If a vector can be edited in the same commit as
   the criterion it constrains, the corpus is a mirror rather than a cage. Check the history of the
   file for edits that accompany criterion changes.
4. **C3 is an unusually honest claim — audit whether the *rest of the system* honours it.** Grep for
   every place that reads `s2a_attestations.jsonl` or reports on it. Does any of them describe the
   result as a sign-off, an approval, or an authorization, in prose or in a field name? A limit
   stated in one docstring and forgotten by every consumer is not a limit.
5. **C1's "zero mutable copies" is a measurement, so measure it.** Enumerate the Factory artifacts
   and find the owned facts they carry. Is there a check that *finds* copies, or only one that
   validates the `OwnerRef`s that are present? Those are very different guarantees: the second is
   satisfied by an artifact that has no `OwnerRef` at all.
6. **`OwnerRef` field-level attacks.** It carries `path`, `commit_oid`, `blob_oid`, `raw_sha256`.
   Which of those are actually verified on read, and by whom? Construct a ref where `path` points at
   one file and `blob_oid` at another's content; one where the commit is real but does not contain
   the path; one where `raw_sha256` disagrees with `blob_oid`. Which are caught?
7. **`check_attested_pin_staged.py` is a commit-time front guard.** Does it read the **staged index**
   or the **working tree**? A guard that judges the working tree while the commit carries the index
   is checking a document that is not the one being committed.
8. **C5's one-appended-line approval.** Cheap approval is good for the deadlock and dangerous for
   everything else. What stops a non-owner appending that line? Given C3's honest answer (nothing
   can), what *else* in the system treats the line as if something could?

## 7. How to reproduce

```bash
tools/python312/python.exe _triage/factory_os/run_s2a_conformance.py
```
```bash
tools/python312/python.exe _triage/factory_os/run_s2a_attestation_tests.py
```
```bash
tools/python312/python.exe _triage/factory_os/run_s2a_migration_tests.py
```
```bash
tools/python312/python.exe _triage/factory_os/run_s2a_gate.py
```

## 8. What a finding must contain

`file:line` · the record, sequence or state that exposes it · the consequence stated as *which owned
fact can be changed without its owner*, or *which approval can be satisfied by something that is not
one* · and a reproducing command where you can produce one.

Rank by severity. Keep **"this pin can be satisfied by the wrong bytes"** separate from **"this
approval means less than its readers think"** — the second is a documentation defect with money
consequences and is easy to under-rate.
