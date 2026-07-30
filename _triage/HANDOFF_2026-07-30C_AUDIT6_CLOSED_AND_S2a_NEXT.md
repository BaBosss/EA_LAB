# HANDOFF 2026-07-30C — audit 6 answered, the board unblocked, and S2a untouched

**Lane:** `S-2026-07-30-CONTRACTGEN*` / `BOARDPASTE` (block 600-609, now spent on 600+601)
**Commits:** `4a4d6003` → `b8b332fc` · **Predecessor:** `_triage/HANDOFF_2026-07-30B_CONTRACT_BINDING_AND_S3A.md`

---

## 1. Where to start

**Run these six first. If any is red, stop and read it — do not build on top of it.**

```
tools\python312\python.exe _triage\factory_os\gen_design_contracts.py --check
tools\python312\python.exe _triage\factory_os\run_contract_binding_tests.py
tools\python312\python.exe _triage\factory_os\run_schema_fixtures.py
tools\python312\python.exe _triage\factory_os\run_snapshot_validator_tests.py
tools\python312\python.exe _triage\factory_os\run_snapshot_validator_tests.py --prove-harness
tools\python312\python.exe _triage\factory_os\check_schema_structure.py
```

Expected: 30 blocks + all 30 design links · 25 binding cases (7/7 regressions) · 35 ajv cases · 35
fixtures + 13 mutations · the harness self-proof · STRUCTURE OK.

**The next task is `ORDER-600` (S2a), which is on the board and completely untouched.** Details in §4.

## 2. What was finished

**`ORDER-601` (S3a) is built and on the board as `DONE`, not `REVIEWED`.** `snapshot_validator.py`
computes the verdict from a `SnapshotBuilderInput`, emits a `ControlRoomSnapshotV5`, and **recomputes on
read** so a hand-authored document whose answer contradicts its own evidence is refused. 13 predicates,
one per closed reason code, with a generated mutation table (`SNAPSHOT_VALIDATOR_MUTATION_TABLE.md`).

**Blind audit 6 returned NOT DONE and was right.** Report verbatim at
`_triage/factory_os/CODEX_AUDIT6_2026-07-30.md`. All 8 findings were reproduced locally before being
fixed (`161d2033`, `a7960e08`), then a self-review found three more (`b8b332fc`).

**The headline finding was the NAME, not the arithmetic.** A snapshot with a `NO_SENSOR` fleet sensor, a
`BLIND` floating-risk sensor, missing kill/judge controls, an `UNCLASSIFIED` unknown magic and missing
attestation verified `all_clear=true` — correctly, because the verdict is computed from
`meta.reconciliation` and the source rows and nothing else. Renamed to **`reconciliation_clear`**, with the
exclusions stated in the schema, the module and design §3.

**`BACKLOG-D31`'s last item done:** the 30 contract tables moved out of the design into
`_triage/factory_os/CONTRACTS.md` (design 1807 → ~1180 lines). `validate_links` is the replacement
obligation and rejects a missing link, a dangling link, a name/anchor mismatch, and links hidden in HTML
comments or fenced code.

**The board is unblocked.** `S-2026-07-30-SENSFAN` held `AGENT_TASKBOARD.md` for six hours; it committed
(`af59056c`) and closed, and `ORDER-600`/`ORDER-601` were pasted in `d2de6b13` (183 insertions, **0
deletions**). `S-2026-07-29-NIGHTQUEUE` was marked `ABANDONED` — it had been `ACTIVE` since the previous
day and declared the board, so the collision guard was warning about a lane that had stopped.

## 3. Traps this session paid for — read before trusting any green run here

- **A lint had been CRASHING for four commits and nothing could notice.** `check_schema_structure.py`
  raised `KeyError` because ORDER-601 part 1 made `meta.reconciliation` a `$ref` and the script indexed
  `['required']` on it. Its whole design-binding section had not executed since. It was in no suite and no
  hook. **It is now wired into the fast tier** — that is the only reason a future crash gets seen.
- **Its exemption outlived what it exempted.** `OPEN_ROOT_BY_DESIGN` still named `ControlRoomSnapshotV5`
  after that root was closed, so it printed a sentence that was false and would have passed if anyone
  re-opened it. The list is now self-policing: an entry for an already-closed entity is a failure.
- **A guard can hold only while an unrelated guard is present.** The count type-checks lived inside one
  predicate, so disabling that predicate let a string count flow through every remaining equation. Moved
  to `assert_decidable`, which runs before any predicate precisely so mutating one cannot silence it.
- **Three of my own fixes shipped with no fixture**, in the commit whose message says "a check that lives
  in shell history is not a check". Found by grepping the suite for each fix rather than trusting the
  message. If you fix something here, grep the suite for it before believing the commit.
- **Two of my own probes were wrong before the code was.** A delta helper wrote `age` onto rows whose
  field is `age_hours`, so four "negatives" were identical to the healthy positive; and `--prove-harness`
  planted into a set the analysis rebuilt from an import-time snapshot, so the plant was discarded.
- **`sed -i` on a status column hit another lane's row**, because every lane's row ends in the same
  spelling. Anchor row edits on the row's own unique text. Recovered free because the row was already
  committed. See memory `shared-worktree-concurrent-writers` hazard #8.
- **The tier is over budget on some runs and exits 0 anyway.** Three runs: 15.5 / 14.7 / 14.8, median
  14.8 against a 15.0s **advisory** threshold. Quote a median of ≥3 runs; never one number. My earlier
  single-run 14.0s readings were luck.

## 4. `ORDER-600` — the next piece, and what makes it hard

On the board, `OPEN`, **no work done**. Full spec in the board row and in
`_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md`. In one sentence: `MASTER_BACKLOG.md` §2 owns the coverage
matrix today; the design proposes `factory/coverage.jsonl` become the machine source with §2 regenerated
from it, and **this order does not perform that transfer** — it produces the proposal and the migration
table its owner signs or refuses.

Three things decide whether it is real work, and audit 5 wrote them to be un-gameable:

1. **A migration table must actually propose a migration.** Rev 1 could be closed with 24 rows all naming
   `schemas.json` as `current_owner` and proposing nothing — including not proposing the Coverage transfer
   the order exists to prepare.
2. **The Coverage edge row must exist and not every `disposition` may be `KEEP`.** Reporting DONE with an
   all-KEEP table is explicitly prohibited.
3. **`signoff_state = APPROVED` is the owner's act, in their own commit.** Do not write it.

**It ends at the user's desk by design.** Budget the session for producing a proposal a human can accept
or reject in one read, not for landing a change.

## 5. Open, and who owns it

**Nothing is blocking on the user right now.** `ORDER-600` will need their sign-off when it is written,
and `ORDER-601` needs an independent re-check before it can go `REVIEWED` — it is `DONE` precisely because
the work, the audit response and the judgement all came from one seat, and self-certifying an hour after a
blind audit said NOT DONE is the anchoring the protocol exists to prevent.

**Named and deliberately unfixed, all routed to S4:**
- `verify_snapshot` proves **internal consistency, not authenticity**. `read_ok` / `age_hours` / `path` /
  `sha256` / `mtime` and the counts are builder claims taken at face value, so rows pointing at a
  nonexistent drive with `mtime 2099` are accepted. Closing it means deriving them from the real file and
  re-hashing, or a content-addressed evidence manifest.
- **No reader calls `load_verified()`.** The "single door" is not yet in front of anything, and
  `x-enforced-by` now says `BUILT_NOT_WIRED` rather than "on every READ".
- **`reconciliation_clear` is not fleet health.** Making it global needs health contracts for
  `system_health`, `floating_risk`, `deployments.gaps`, `unknown_magics`, `attestation` and
  `judge_readiness` — all `array of arbitrary object` today.
- **The real snapshot still fails the schema.** `run_schema_fixtures.py` prints the measured gap; S4 is
  not done until that line reads PASSES. Deciding whether `path` or `name` is the source identity is part
  of it (Codex recommends `name` as identity, `path` as locator).

**Two enforcement gaps worth fixing early:**
- `run_schema_fixtures.py` is now **1.8s** (was 11.5s — batched into one ajv process) but is **still in no
  hook**, because the tier has zero headroom. The 35 cases are enforced by nothing automatic. The real fix
  is **per-path suite selection** from `$SUITE_GUARDS`: a schema edit should not pay 5.8s of optimize-guard.
- `x-enforced-by` still names `hypothesis_validator`, `coverage_validator`, `candidate_validator`,
  `attestation_validator`, `receipt_validator`, `finding_validator`, `projection_validator` — none of which
  exist. The schema header defines that field as an enforcement inventory, so those are false governance
  state. Codex proposes splitting `x-enforcement-status: PLANNED | BUILT | WIRED`.

<!-- HANDOFF-ROUTING -->

| item | routes to |
|---|---|
| S3a validator + computation suite + mutation table, built and blind-audited | ORDER-601 |
| All 8 audit-6 findings reproduced and fixed, plus 3 found by self-review | ORDER-601 |
| Independent re-check owed before ORDER-601 can go REVIEWED | ORDER-601 |
| Contract tables relocated to CONTRACTS.md; validate_links is the replacement obligation | BACKLOG-D31 |
| x-enforced-by names 7 validators that do not exist; split PLANNED/BUILT/WIRED | BACKLOG-D31 |
| S2a ownership proposal + migration table — untouched, next task | ORDER-600 |
| Authenticity, wiring load_verified, global fleet-health verdict, real snapshot passing | BACKLOG-D30 |
| Per-path suite selection; tier at median 14.8s of a 15.0s advisory budget, ajv suite unwired | BACKLOG-D32 |
