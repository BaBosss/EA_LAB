# Codex blind audit brief — Factory OS slice **S10** (candidate identity · attestation · magic)

> Written 2026-08-03 by lane `S-2026-08-03-AUDITCOV`. **You are the independent brain.**
>
> This slice's built code has **never been independently audited**. Nothing in this brief tells you
> what any previous session concluded about it, and that omission is deliberate — earlier audits on
> this project re-found two real defects precisely because they could not see anyone's answer.
> If you find yourself agreeing with a claim, say *why the evidence supports it*, not *that it is
> stated*.

---

## 0. Read at a PINNED commit, not at HEAD

Another lane is writing in this repository. **Read every file through:**

```bash
git show a87f7448:<path>
```

`a87f7448` is the pin. If a path does not exist at that commit, say so rather than falling back
to the working tree.

## 0b. This audit is READ-ONLY

Do not edit, stage, commit, or create any file in this repository. Do not run any command that
writes to `factory/`, `ops/`, `_mt5_auto/`, or `.git/`. Running the read-only python cages listed
in §6 is fine — they take no arguments that write. Your entire output is a report on stdout.

## 0c. Vocabulary note, so it does not slow you down

This is a **trading-strategy research repository**. Its test suites label deliberately-corrupted
fixtures `ATTACK` — standard mutation-testing vocabulary here, meaning *"mutate the input and prove
the checker refuses it."* `scripts/_test/run_s10_tests.ps1` contains 7 such labels and
`run_s10_tests.py` 2. There is no security exploit anywhere in this slice; the adversary in every
one of those cases is a future careless writer, not an attacker.

---

## 1. What you are auditing, in one sentence

Three stores that together decide **which strategy a live trading account is running, and under
which numeric identifier its historical deals are attributed** — a candidate manifest whose digest
is recomputed on every read, an append-only attestation log of `(account, magic)` → candidate, and
a magic-number allocation store with a closed legacy-exception list.

**The stake:** `991001` is on **real money**. A magic silently re-attributed, a candidate manifest
whose digest check can be walked past, or an automation-appended event that moves a deployment onto
a different strategy without a human in the loop, all end at the same place — money running
something nobody authorised, with the audit trail agreeing that it is fine.

## 2. Read these, in this order

| | |
|---|---|
| `_triage/EA_LAB_FACTORY_OS_DESIGN.md` | **§3.5** (Candidate lifecycle) · **§3.6** (Deployment/monitor/judge) · **§3.7** (Champion–Challenger) · **§4.5** (candidate identity, from L490) · **§4.6** (magic allocation) · **§4.7** (`DeploymentAttestationEvent`) · **§4.8** (attribution key) · **§10** the **S10** row |
| `_triage/factory_os/CONTRACTS.md` | `CandidateManifest` · `MetricRef` · `OwnerRef` · `MagicAllocation` · `DeploymentAttestationEvent` |
| `PROJECT_STATE.md` | **§0.5** — the owner's 2026-08-01 amendment that magic scope is GLOBAL, and the condition it attaches |
| `AGENT_TASKBOARD.md` | row **`ORDER-1100`** (L1518) — the order this slice was built under |

## 3. The artifacts

| file | what it decides |
|---|---|
| `_triage/factory_os/candidate.py` | the `candidate_digest` payload field set, its validation, and the recompute-on-read |
| `_triage/factory_os/attestation.py` | which events may be appended by which actor, and the `fold()` that turns a log into "what this deployment IS" |
| `_triage/factory_os/magic.py` | allocation, the cutover import, and the two-direction legacy-exception check |
| `_triage/factory_os/gen_magic_allocations.py` | the generator that produced the store from `portfolio/DEPLOYMENTS.csv` |
| `scripts/lib/magic_guard.ps1` | the bridge `check_state.ps1` calls, which calls `magic.py` |
| `_triage/factory_os/run_s10_tests.py` · `scripts/_test/run_s10_tests.ps1` | the cage and its wrapper |
| `factory/magic_allocations.jsonl` · `factory/attestations.jsonl` · `factory/candidates/**` | the live stores |

## 4. The claims — refute these

Each is a claim the built code makes about itself, quoted from its own module docstring or from the
design's acceptance row. Your job is to find the input, state, actor or call order that breaks it.

| # | claim | where |
|---|---|---|
| C1 | `candidate_digest` is **recomputed and compared on every read**, and the payload it covers **does not contain it** | `candidate.read_manifest` / `canonical_payload` |
| C2 | there is **no second serializer** — `candidate.py` imports `scheduler.canonical()` and `scheduler.normalize_numbers()` and defines none of its own, and the cage *measures* that dependency by swapping each out | `candidate.py` L~494 rationale, `run_s10_tests.py` |
| C3 | the payload is a **closed set of fifteen fields**; both a missing and an unknown field are refused | `PAYLOAD_FIELDS`, `validate_payload` |
| C4 | **no non-`OBSERVED` attestation event without a human authorization ref** — and its second half: an `OBSERVED` event that MOVES `candidate_id` is refused (`A6`) | `attestation.validate_event` |
| C5 | both stores are **append-only enforced by the absence of a rewrite path** — "no function in this module changes an existing row's `magic`", "there is no rewrite path in this module" | `magic.py` / `attestation.py` docstrings |
| C6 | the legacy exception list is checked in **both directions** — every real collision declared (sensitivity) *and* every declared exception a real collision (specificity) | `magic.inventory_problems` |
| C7 | **legacy is a closed set, not a category**: after the cutover commit, minting a new `LEGACY_ACCOUNT_SCOPED` row is refused (`M6`) | `magic.validate_allocation` / `store_problems` |
| C8 | `check_state.ps1` enforces the GLOBAL rule through **one implementation**, handed **judged bytes** rather than a repo path | `scripts/lib/magic_guard.ps1` → `magic.py` |

## 5. Where to aim — the shapes this project has been burned by before

Use these as lenses, not as findings. Each names a failure mode with a real precedent here.

1. **A guard whose success condition is unreachable, or whose failure condition is.** For every
   refusal in `validate_payload`, `validate_event` and `validate_allocation`: construct the input
   that should trip it. If you cannot construct one, the criterion is decoration. Conversely, find
   any criterion that **cannot return PASS**.
2. **Sensitivity without specificity.** C6 claims both directions. Does the *specificity* direction
   actually have a case that fails when it is deleted, or does it only have a case that passes?
3. **An equality test on free text.** A check written as `value == 'FORBIDDEN'` never fires on a
   field whose contents are a sentence. Which of these checks compare enums (correct) and which
   compare prose (silently inert)?
4. **A prohibition that disarms its own check.** Removing an input on principle can leave the
   checker that reads it dead — and reporting `CLEAN` on a file it never saw.
5. **Recompute-on-read that is not on every read.** C1 says *every* read. Enumerate every path by
   which a manifest's bytes reach a consumer — CLI, import, another module, a PowerShell caller —
   and check the digest is compared on each. One bypass is enough.
6. **`fold()` as the real authority.** C4 constrains what may be *appended*. Does `fold()` also
   constrain what may be *believed*? A sequence of individually-legal events that folds to a state
   no single event could have set is the interesting case. Try: `RETIRED` then more events; two
   `CANDIDATE_ASSIGNED` for one pair; events out of chronological order; a duplicate `event_id`.
7. **Ordering assumptions in an append-only log.** Is `fold()` sensitive to file order, to `at`
   timestamps, or to both — and do they have to agree?
8. **The store-vs-inventory join.** `magic.py` reads `portfolio/DEPLOYMENTS.csv`. What happens when
   the inventory has a magic the store does not, when the CSV has a duplicate, when a field is
   empty, when an account id is formatted differently on two rows?
9. **The three legacy magics are named in prose in three places** (design §4.6, the module docstring,
   `PROJECT_STATE.md` §0.5). Are they *derived* anywhere, or are all three hand-copies of each other
   that would drift together silently?
10. **Digest sensitivity.** C1/C2 are only worth something if the digest actually moves for the
    mutations that matter. Which single-field mutations of a payload leave the digest unchanged?
    Pay attention to numeric normalization (`10000` vs `10000.0`), to `None` vs absent, to unicode,
    and to nested `OwnerRef` / `MetricRef` objects.

## 6. How to reproduce

```bash
tools/python312/python.exe _triage/factory_os/run_s10_tests.py
```
```bash
tools/python312/python.exe _triage/factory_os/magic.py verify
```
```bash
tools/python312/python.exe _triage/factory_os/candidate.py --self-test
```
```bash
tools/python312/python.exe _triage/factory_os/attestation.py --self-test
```

`scripts/_test/run_fast_cages.ps1` runs the whole tier — **it is slow and it writes a transcript, so
do not run it**. `run_s10_tests.py --list` prints the criterion count; the order row deliberately
does not restate it, so if you want the number, measure it.

⚠️ Two suites unrelated to S10 (`run_s2a_gate` F2, `check_coverage_transfer` A8) are **known red at
this pin** for a reason already recorded elsewhere. If you see them fail, that is not your finding —
ignore them and say you ignored them.

## 7. What a finding must contain

`file:line` · the **input, actor or call order** that exposes it · the consequence stated in terms of
*what a live deployment would end up running* or *which deals get attributed to which strategy* ·
and, where you can, a **command that reproduces it**. A finding you cannot reproduce is a
hypothesis — label it as one and file it anyway.

Rank by severity. Separate **"this is wrong"** from **"this is unproven"** — they are different
findings and the second is not a lesser version of the first.

## 8. No lane is needed

Everything here is source plus python cages. This audit needs **no MT5 terminal and no backtest**.
If you think a finding requires a tester run to settle, say so explicitly and stop there — the MT5
lane is a single contended resource and must be taken deliberately, not assumed free.
