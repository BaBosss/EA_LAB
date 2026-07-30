# User-side tasks — 2026-07-31 (overnight Factory OS tranche)

Owner: **user**. Claude cannot do these from its seat. One section per task.

---

## 1. The Coverage approval now pins bytes that executing it changed — 🔴 **the approval mechanism is self-invalidating, and only you can unblock it**

**Status:** the transfer itself is **done and verified** (`ORDER-610`, commit in the range below).
Nothing is broken and no cage is disarmed. What is owed is one line from you.

### What happened, in three sentences

You approved moving `MASTER_BACKLOG.md` §2 to `factory/coverage.jsonl`. Your approval record pins
`MASTER_BACKLOG.md` at blob **`ca909b693a4c`** — the bytes you were looking at when you decided.
**Executing the approval changed those bytes**, so `check_s2a_attestation.py` now reports your
approval as resting on a *stale pin* — it is objecting to the change it authorized.

### Why Claude did not just fix it

Every route available from this seat is worse than asking:

| route | why it was refused |
|---|---|
| write `"stale_pin_acknowledged": true` into the log myself | that line carries `signer: user (Boss)`. Writing it would be **manufacturing your words** — the exact defect blind audit 8 raised as BLOCKER 1. |
| re-pin `D1` with `gen_s2a_migration.py` | `s2a_migration.jsonl` is one of the **six files bound by `bundle_sha256`**. Re-pinning changes the digest, which **voids your approval outright**. |
| repair `check_s2a_attestation.py` so approvals stop self-invalidating | that file is **inside its own bundle**. Editing it voids every attestation it holds — including yours. |

So the failure is reported as an **ADVISORY**, loudly, on every run, with this file named. It is not
swallowed: `check_coverage_transfer.py` downgrades it **only** when the attestation's sole complaint
is that one pin on that one path **and** the transfer independently verifies. Five negative fixtures
cover the ways it must refuse to fire (a second problem present · a different owner path · a
different failure · a transfer that does not verify · nothing to downgrade).

### What you can do — pick one

**Option A — acknowledge the pin (smallest, keeps everything as it is).** Append one line to
`_triage/factory_os/s2a_attestations.jsonl`. `check_s2a_attestation.py` recomputes every value in it,
so a wrong blob is rejected rather than believed:

```bash
tools\python312\python.exe _triage\factory_os\check_s2a_attestation.py --template
```

then add `"stale_pin_acknowledged": true` and a `"stale_pin_acknowledgement"` object naming
`{path, pinned_blob, current_blob}`.

**Option B — treat it as a contract defect and have it fixed properly.** The general problem is that
**every** approved `TRANSFER` in D1 will do this: approving a move and then executing the move always
moves the pinned bytes. A durable fix distinguishes *"the pinned bytes changed"* from *"the pinned
bytes changed **into** the state this record approved"*. That requires editing a bundled file, which
voids the current approval — so it costs you a re-decision either way, and it should be its own Order.

**Recommendation: A now, B as an Order later.** A costs one line and unblocks nothing else; B is the
right long-term shape but it should not be paid for in the middle of a tranche.

<sub>🔎 **Worth noticing about how this was found:** the transfer commit **passed its own pre-commit
gate and went red on the very next read** — at commit time `HEAD` still carried the old blob, so the
pin was current; one second later it was not. That is the third instance in this lineage of a guard
that is green at its own introducing commit (memory `drift-guard-regenerating-against-head`). It was
not caught by review. It was caught by running the gate again afterwards.</sub>

---

## 2. Still open from 2026-07-30 — the consolidated Codex audit

Unchanged: see `_triage/USER_TASKS_2026-07-30.md` §1. The overnight tranche adds to that one pass
rather than requesting a separate review; the brief for it is
`_triage/factory_os/CODEX_FINAL_FACTORY_OS_AUDIT_BRIEF_2026-07-31.md`.
