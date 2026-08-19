# Pre-Deployment Evidence Packet — Contract & Template

> ⚠️ **This file owns:** the shape of the milestone pre-deployment evidence packet — required
> sections, field vocabulary, and PASS/BLOCK logic — plus the deterministic checklist used to
> populate one. It does **not** own EA verdicts (VERDICT GATE, `CLAUDE.md`), EA selection, or
> deployment execution (`vps-deploy-ops` skill, `live-deployment-controller` skill). A packet
> built from this contract is an input to those decisions, never a substitute for them.
>
> **Canonical anchor at authoring time:** commit `4c5a1e1988599a6c0e4457370538164b01d7f9ac`
> ("Wave-1 durable sync: FACTORY PRODUCTION READINESS = ACCEPTED / COMPLETE"). A populated
> packet re-states its own canonical anchor in §1 — see the drift rule there.
>
> **Direct consumer:** Control Tower (milestone/integration review) and the milestone reviewer.
> **Populated by:** lanes L1–L7, each owning one or more sections below. This document defines
> the contract those lanes fill; it performs no population itself.

---

## 0. Scope and non-goals

This contract defines **architecture only**:

- ✅ exact section list, field vocabulary, and source-of-truth pointer per field
- ✅ PASS / BLOCK / status-vocabulary logic per section
- ✅ the one rule that gates when an OWNER HARD STOP request may appear in a packet
- ✅ a deterministic completion checklist so filling in L1–L7's output becomes mechanical

It explicitly does **not**:

- ❌ manufacture, guess, or backfill any evidence value — an unpopulated field is reported as
  its named unknown status (see §2 vocabulary), never silently omitted or invented
- ❌ select or rank a deployment candidate
- ❌ execute, stage, or request any deployment/attachment action itself

A named unknown is a **valid, complete** answer under this contract. A blank line is not.

---

## 1. Packet identity block (every packet header)

| Field | Source | Notes |
|---|---|---|
| `packet_id` | assigned at pack time | stable id for this packet instance |
| `generated_at` | populator's clock at write time | stamped by whichever lane finalizes the packet, never backfilled |
| `packet_commit_sha` | `git rev-parse HEAD` at pack time | the commit the packet's own evidence was read against |
| `canonical_commit_sha` | `PROJECT_STATE.md` / `AGENTS.md` §1.4 canonical-push record, read fresh | the project's currently-recorded canonical SHA |
| `canonical_status` | derived | `BOUND` if `packet_commit_sha == canonical_commit_sha`; else `DRIFTED` |
| `populating_lanes` | L1–L7 mapping | which lane supplied which section (§2) |
| `consumer` | fixed | `Control Tower` |

**Drift rule:** `DRIFTED` is a hard block on the whole packet — every downstream section is
reported as `BLOCKED: CANONICAL_DRIFT`, not individually re-evaluated. A packet cannot be
partially trusted against a stale canonical anchor; re-pack against current canonical first.

---

## 2. Required sections

Each section below has: **purpose**, **fields**, **source pointer**, **status vocabulary**, and
its **PASS rule**. A section is "complete" when every field carries a value from its vocabulary —
completeness is a statement about honesty of reporting, not a statement about readiness to
deploy (see §3).

### A. Canonical identity
- **Purpose:** anchor the packet to one exact, unambiguous commit.
- **Fields:** `canonical_commit_sha`, `integration_head` (if a merge/integration branch differs
  from canonical), `parent_sha`, `canonical_push_status` (`COMPLETED/VERIFIED` | `PENDING`).
- **Source:** `git rev-parse`, `PROJECT_STATE.md` canonical-entry lines, `AGENTS.md` §1.4.
- **Status vocabulary:** `BOUND` / `DRIFTED` / `UNVERIFIED` (canonical record itself could not be
  read).
- **PASS rule:** `BOUND` only. Anything else blocks the whole packet per §1's drift rule.

### B. Target binding or `TARGET_UNBOUND`
- **Purpose:** state exactly which account/server/magic this packet is evidence *for* — or state
  plainly that none is chosen yet.
- **Fields:** `account_number`, `account_type` (`REAL` | `REAL_CENT` | `DEMO`), `broker/server`,
  `terminal_lane` (per `AGENTS.md` §… tester-lane table), `magic_number(s)`.
- **Source:** `DEMO_DEPLOYMENT_PLAN.md` / `portfolio/DEPLOYMENTS.csv` for an existing attach;
  none for a not-yet-attached candidate.
- **Status vocabulary:** `BOUND` (every field named) / `TARGET_UNBOUND` (literal value, not a
  blank field — a milestone/readiness packet may legitimately be `TARGET_UNBOUND` throughout).
- **PASS rule:** `TARGET_UNBOUND` does **not** block the packet as a readiness review. It **does**
  categorically block §2J (OWNER HARD STOP) — see that section's rule. `TARGET_UNBOUND` is not a
  defect to explain away; it is a legitimate milestone state that must be stated verbatim.

### C. Deployment inventory identity
- **Purpose:** name exactly which EA/build this packet concerns, resolvable to one registry row.
- **Fields:** `ea_name`, `magic_number(s)`, `build/version_tag`, `related_order_id`,
  `scorecard_row_ref`.
- **Source:** `EA_MASTER_INDEX`, `EA_SCORECARD_AND_REGISTRY.md`.
- **Status vocabulary:** `RESOLVED` (exactly one matching scorecard row) / `AMBIGUOUS` (>1 match)
  / `NOT_FOUND` (0 matches).
- **PASS rule:** `RESOLVED` only. `AMBIGUOUS` or `NOT_FOUND` blocks §2J; never guess which row was
  meant.

### D. Artifact / config identity
- **Purpose:** pin the exact binary and config this packet's evidence was measured against.
- **Fields:** `.ex5_build_hash` (MD5/SHA as recorded by the compile step), `.set_path`,
  `.set_hash`, `effective_config_hash` / `ConfigFingerprint` (if the EA emits one),
  `compile_evidence` (errors/warnings count, target count).
- **Source:** compile logs, `ConfigFingerprint.mqh` output where wired, locked `.set` file.
- **Status vocabulary:** `CONFIG_MATCH` (live-read config hash equals the locked `.set` hash) /
  `CONFIG_MISMATCH` / `UNREADABLE` (hash could not be read through the available UI/tooling — a
  legitimate, nameable state, not a failure to try harder).
- **PASS rule:** `CONFIG_MATCH` only. `UNREADABLE` must be stated explicitly (mirroring the
  existing project convention of recording "SHA256 was not readable through the safe UI, no hash
  claimed") — it blocks §2J but is not itself an error in the packet.

### E. Preflight results
- **Purpose:** confirm the target symbol/session/broker conditions were actually checked, not
  assumed.
- **Fields:** `preflight_script+version`, `checks_run` (named list), `checks_passed`,
  `checks_failed`, `run_timestamp`, `lane`.
- **Source:** `scripts/lib/symbol_preflight.ps1` (or equivalent) run output.
- **Status vocabulary:** `PASS` / `FAIL` / `UNTESTED` (0 checks executed).
- **PASS rule:** `PASS` with `checks_run > 0` shown explicitly. `UNTESTED` must never be reported
  as `PASS` — this reuses the project's existing guard-evidence rule: a check that fired zero
  times is `UNTESTED`, not passing evidence (see the guard/filter/kill-switch bar in the VERDICT
  GATE, applied here to preflight checks by the same logic).

### F. Attestation state
- **Fields:** relevant `ATTESTATION_MAP` entries for the bound account(s)/EA(s), attestation
  freshness vs. the project's stale threshold, any open stale-pin acknowledgement.
- **Source:** `ATTESTATION_MAP`, S2a attestation records.
- **Status vocabulary:** `FRESH` / `STALE` / `NO_ATTESTATION_ON_FILE`.
- **PASS rule:** `FRESH` only. `STALE` blocks §2J even if every other section is green — a stale
  attestation is a named blocker, not a footnote.

### G. Monitoring / forward-test readiness
- **Purpose:** report monitoring honestly at three separate scopes — do not collapse them into
  one status. Evidence completeness, the project-wide monitoring posture, and whether monitoring
  is actually wired and fresh *for this packet's bound target* are three different questions.

- **G1. Evidence completeness** — were the fields below actually sourced, or could they not be
  read.
  - **Fields:** `collector_status` (live-deals writer freshness, in hours, per account), dashboard
    wiring (Control Room / `STATUS.html`), kill-switch/guard armed state, presence of an expected
    trade-rate row in `portfolio/expectations.csv`.
  - **Source:** `portfolio/live_deals/`, `scripts/control_room_snapshot.ps1`,
    `portfolio/expectations.csv`.
  - **Status vocabulary:** `READ` (every field above was actually sourced) / `UNREADABLE`.

- **G2. Global monitoring state** — the project-wide monitoring posture, independent of any one
  target. Reported for honesty; **never itself a PASS/BLOCK input to §2J** (see the section PASS
  rule below).
  - **Field:** `global_monitoring_state`.
  - **Source:** Control Room / `STATUS.html` project-wide banner.
  - **Status vocabulary:** `GREEN` / `DEGRADED_MONITORING`. A packet must never promote this
    value on its own authority — it re-states whatever Control Room currently reports, verbatim.

- **G3. Target-specific monitoring readiness** — is monitoring actually wired and fresh for the
  account/magic bound in §2B. Meaningless while `TARGET_UNBOUND`. This is a readiness *verdict*,
  not a freshness measurement — the measurement is a supporting field, not the vocabulary itself.
  - **Fields:** the same `collector_status`/dashboard/kill-switch/trade-rate fields as G1, read
    and staleness-clocked for the bound target specifically; `staleness_hours` (the freshness
    evidence backing the verdict, e.g. `"6.2 h"`) cited alongside every non-`UNKNOWN` value;
    `fail_reason` (`STALE` | `NOT_WIRED`) cited alongside any `FAIL` value.
  - **Status vocabulary:** `PASS` / `FAIL` / `UNKNOWN` (§2B is `TARGET_UNBOUND`, or the target's
    monitoring evidence could not be read even though G1 is otherwise `READ`).
  - **PASS rule:** `PASS` only, with `staleness_hours` under the project's operating threshold
    and cited as a number — never a bare "OK" or a bare `PASS` with no number backing it.

- **Section PASS rule (what gates §2J):** §2J's monitoring input is **G3 alone**, and only when
  G1 is `READ` (an `UNREADABLE` G1 means G3's value cannot be trusted regardless of what it
  says). A global `DEGRADED_MONITORING` state in G2 is reported truthfully but **must not, by
  itself, block or fail** a target whose own G3 is `PASS` — global monitoring degradation and
  target-specific monitoring readiness are different claims; collapsing them into one status was
  the defect this section corrects. G2 stays `DEGRADED_MONITORING` until Control Room reports
  otherwise — this contract has no mechanism to promote it, and none should be added here.

### H. Current blockers
- **Purpose:** every open item standing between this packet and an owner action, named with its
  source order/ID.
- **Fields:** ordered list of `{blocker_id, source_order, hard/soft, description}`.
- **PASS rule:** an empty list is written as the literal value `NONE` — never an omitted section.
  A single unresolved hard blocker is sufficient to keep §2J empty regardless of every other
  section's status.

### I. Parked / future
- **Purpose:** anything intentionally out of scope for *this* packet/milestone, so it is not
  mistaken for "forgotten."
- **Fields:** list of `{item, verdict_or_status (reuse canonical vocabulary — `PARKED-VERIFY(user)`,
  `HOLD`, etc. — where the item is EA-verdict-shaped), reason, owner if any}`.
- **PASS rule:** nothing may be silently dropped from a prior packet revision without appearing
  here or in §H — matches the project-wide "nothing dies silently outside STRUCTURAL" discipline.

### J. Exact OWNER HARD STOP operation
- **Purpose:** if — and only if — an actual runtime-attachment action is ready, state it as one
  unambiguous sentence naming account, EA/magic, artifact hash, and operation.
- **Field:** `owner_action_request` — either:
  - a single sentence of the shape *"attach `.ex5` build `<hash>` with `.set` `<hash>` to account
    `<account_number>` on `<broker/server>`, magic `<magic_number>`"* (or the equivalent for the
    specific hard-stop operation being requested), **or**
  - the literal value `NO OWNER ACTION REQUESTED — blocked by <section(s)>` naming exactly which
    of §2 A–I is not yet `PASS`.
- **Allowed operation catalog (closed list, per `AGENTS.md` owner-boundary table):** deployment /
  runtime attachment · trading · LIVE / DEMO→LIVE expansion · risk/default parameter change ·
  signature/attestation · QI-2+ authority change · destructive/irreversible action outside an
  authorized fixture · force push / history rewrite. An operation not on this list has no owner
  hard-stop path through this packet — it does not belong in §2J.
- **PASS rule (the gate this whole contract exists to enforce):** §2J may contain a real request
  **only when** §2 A (`BOUND`), B (`BOUND`, i.e. not `TARGET_UNBOUND`), C (`RESOLVED`), D
  (`CONFIG_MATCH`), E (`PASS`), F (`FRESH`), and **G3** (`PASS`, target-specific monitoring
  readiness) are *all* true, **and** §2H's blocker list is `NONE`. G3's own PASS rule already
  requires G1 = `READ`. **G2 (global monitoring state) is excluded from this list on purpose:** a
  global `DEGRADED_MONITORING` does not, by itself, block §2J for a target whose G3 is `PASS` —
  see §2G's section PASS rule. If any one of A, B, C, D, E, F, G3, or §2H is not satisfied, §2J is
  mechanically `NO OWNER ACTION REQUESTED` — this is a deterministic roll-up, not a judgment call
  left to whoever writes the packet. A packet must never phrase a soft, exploratory, or
  conditional ask in this section.

### K. Regression / review evidence
- **Fields:** `tpl_regression` result (`CLEAN N/N`), compile evidence, independent
  different-family review verdict (`PASS` / `BLOCKERS: <list>`), reviewing family/model name, any
  repair commits since the reviewed revision.
- **Source:** `scripts/generate_tpl_baseline.ps1` / regression logs, review records.
- **PASS rule:** the reviewing family must be recorded and must differ from the authoring
  family/model, per `AGENTS.md`'s "no author may be the sole final reviewer" rule. A review by
  the same family the author used does not satisfy this section.

---

## 3. Overall packet verdict roll-up

Two separate questions — do not collapse them:

| Roll-up | Definition |
|---|---|
| `SECTIONS_COMPLETE` | every section in §2 carries a value from its own vocabulary (including named unknowns like `TARGET_UNBOUND`, `UNTESTED`, `STALE`) — nothing blank |
| `READY_FOR_OWNER_ACTION` | §2J carries a real `owner_action_request` (not the `NO OWNER ACTION REQUESTED` literal) |

A packet can be `SECTIONS_COMPLETE` while `READY_FOR_OWNER_ACTION = false` — that is the normal,
expected state for an early-milestone readiness packet (e.g. everything reported honestly, target
still `TARGET_UNBOUND`). Completeness is about honest reporting; readiness is about the §2J gate.
Control Tower reviews `SECTIONS_COMPLETE` packets routinely; only a `READY_FOR_OWNER_ACTION`
packet reaches the owner for a hard-stop decision.

---

## 4. Deterministic completion checklist (for L1–L7 / whoever populates a packet)

Work top to bottom. Every line ends in a stated value — never a skip.

- [ ] §1 packet identity block filled; `canonical_status` computed and, if `DRIFTED`, packet
      marked blocked and no further section evaluated for PASS (still fill them for record, but
      roll-up stops at `NOT_READY`)
- [ ] §2A canonical identity → status recorded
- [ ] §2B target binding → `BOUND` fields or literal `TARGET_UNBOUND`
- [ ] §2C deployment inventory identity → resolved to exactly one scorecard row, or
      `AMBIGUOUS`/`NOT_FOUND` stated
- [ ] §2D artifact/config identity → `CONFIG_MATCH` / `CONFIG_MISMATCH` / `UNREADABLE` stated,
      hash values recorded where available
- [ ] §2E preflight results → check count and per-check outcome recorded; `UNTESTED` if
      `checks_run = 0`
- [ ] §2F attestation state → `FRESH`/`STALE`/`NO_ATTESTATION_ON_FILE` with the record checked
- [ ] §2G monitoring/forward-test readiness → G1 evidence completeness, G2 global monitoring
      state (re-stated verbatim from Control Room, never promoted here), and G3 target-specific
      readiness (staleness in hours cited, dashboard/kill-switch wiring stated) all recorded
      separately; only G3 feeds §2J
- [ ] §2H current blockers → list or literal `NONE`
- [ ] §2I parked/future → list or literal `NONE`
- [ ] §2J owner hard stop → mechanically derived from A–I per the PASS rule; never hand-written
      independently of that derivation
- [ ] §2K regression/review evidence → reviewing family recorded and confirmed different from
      authoring family
- [ ] §3 roll-up computed: `SECTIONS_COMPLETE` and `READY_FOR_OWNER_ACTION` both stated

A packet that reaches the bottom of this checklist with every line resolved is mechanically
complete regardless of what the answers were — that is the point: D6 (or any consumer) can trust
the *shape*, and Control Tower's job is then to judge the *content*, not chase missing fields.

---

## 5. What this contract explicitly forbids

- Filling any field with a guess, placeholder, or "TBD" where a named status exists for exactly
  that situation (§2's vocabularies cover "not chosen yet," "not tested," "couldn't read it,"
  "no match," "more than one match" — use them).
- Writing a §2J request that is not one of the closed catalog of owner hard-stop operations.
- Treating `SECTIONS_COMPLETE` as equivalent to `READY_FOR_OWNER_ACTION`.
- Selecting which EA/candidate a packet is about — that decision belongs upstream of this
  contract (VERDICT GATE, portfolio selection), not inside it.
- Executing any part of the operation named in a hypothetical §2J sentence — this document
  produces the sentence's *shape*, never triggers the action itself.

---

# Populated Packet Instance — VPS-DEMO-MILESTONE-20260819-01

> Populated per the contract above. This instance is a **pre-push snapshot** of the VPS DEMO
> preparation/hardening batch (9 commits, `4c5a1e19..eead6d0c`). It performs no candidate
> selection and no deployment action.

## 1. Packet identity block

| Field | Value |
|---|---|
| `packet_id` | `VPS-DEMO-MILESTONE-20260819-01` |
| `generated_at` | `2026-08-19 14:38:16 +07:00` |
| `packet_commit_sha` | `eead6d0cbbccf791d51adbb0dec8bdccfc0ea479` (HEAD at pack time — the commit the packet's evidence was read against) |
| `canonical_commit_sha` | `4c5a1e1988599a6c0e4457370538164b01d7f9ac` (live `git ls-remote origin master` at pack time) |
| `canonical_status` | `DRIFTED` — integration branch is 9 commits ahead of origin/master (0 behind); push `PENDING`. Per the §1 drift rule this packet is `BLOCKED: CANONICAL_DRIFT`: the sections below are filled for record, and the roll-up stops at `NOT_READY`. |
| `populating_lanes` | L3 (attestation reconciliation → §2F) · L4 (regression test suite → §2K test evidence) · L7 (integration closeout → §1, §2A–E, §2G, §2H, §2I, §2J, §3) · milestone reviewer (§2K review — recorded in the step-8 durable-sync commit) |
| `consumer` | `Control Tower` |

## 2. Required sections

### A. Canonical identity

| Field | Value |
|---|---|
| `canonical_commit_sha` | `4c5a1e1988599a6c0e4457370538164b01d7f9ac` |
| `integration_head` | `eead6d0cbbccf791d51adbb0dec8bdccfc0ea479` |
| `parent_sha` | `553c89202c7cd4bfe632c2ac9b8131db0557cc15` |
| `canonical_push_status` | `PENDING` |

**Status: `DRIFTED`** (0 behind / 9 ahead of origin/master; fast-forward push viable and pending).

### B. Target binding

**Status: `TARGET_UNBOUND`** (literal, verbatim). No account/server/magic is bound in this
packet; it is a milestone/readiness packet by design.

### C. Deployment inventory identity

**Status: `NOT_FOUND`** (0 single-row matches). Design note: this is a milestone-level
readiness packet; no single EA is selected by design (see §2B `TARGET_UNBOUND`). The zero
matches are by design, not a lookup failure. §2J is blocked by §2B regardless.

### D. Artifact / config identity

**Status: `UNREADABLE`** — no live terminal read in this closeout (runtime operations are out
of scope). The config-identity basis is the on-file attestation evidence in §2F, including for
990016: verified binary SHA256 `B5001606FCBB30FF419A45DB7F9D477185E22DCDB5B6B1B7DCDAEB7CC0127CFC`
(134,550-byte build) and Inputs-tab read-back `_0_Magic=990016` (2026-07-28 16:37).

### E. Preflight results

**Status: `UNTESTED`** — `checks_run = 0`. Preflight is a per-attach operation; no attach is
being prepared in this packet.

### F. Attestation state

| magic | EA / bundle | Status | Evidence |
|---|---|---|---|
| 992001 | TsMom_XAU (`_vps_deploy/S2_TSMOM_XAU`) | `FRESH` | L3R row added at `eead6d0c`: README magic 992001 confirmed; tracked ex5 + tracked .set |
| 992003 | LondonORB_XAU (`_vps_deploy/SS1_LONDONORB_XAU`) | `FRESH` | L3R row added at `eead6d0c`: README magic 992003 confirmed; tracked ex5 + tracked .set |
| 992017 | PivotBreakout_XAU (`_vps_deploy/PIVOTBREAKOUT_XAU`) | `FRESH` | L3R row added at `eead6d0c`: README magic 992017 confirmed; tracked ex5 + tracked .set |
| 990016 | Boss_16_KangarooGrid (`_vps_deploy/BOSS16_KANGAROO_XAU`) | `FRESH` | L3R row added at `eead6d0c`: DEPLOYMENTS.csv row 64 (ORDER-530, 2026-07-28) confirms the FLAT preset `Boss16_Kangaroo_XAU_21_30.set` (own `_0_Magic=990016`) was attached, not the scaled preset the bundle README nominates; binary SHA256 `B5001606…` verified; Inputs-tab read-back 2026-07-28 16:37 `_0_Magic=990016` |
| 990103 | RSI_MR_EURUSD (`_vps_deploy/RSI_MR_EURUSD`) | `NO_ATTESTATION_ON_FILE` | Named gap: zero tracked ex5 in the bundle (README + .set only); README never states an ex5 filename; not repo-actionable |
| 990026 | STF_BTC_H4_ORDER353 (`_vps_deploy/STF_BTC_H4_ORDER353`) | `NO_ATTESTATION_ON_FILE` | Named gap: zero tracked ex5 in the bundle (README + .set only); runtime build ref `br-81fad90230b74411a444ebe3aaae8506` does not map to a tracked bundle ex5; not repo-actionable |

**Section status: 4 × `FRESH` + 2 × `NO_ATTESTATION_ON_FILE`** (both named gaps, recorded per
the L3R reconciliation gate; neither is repo-actionable).

### G. Monitoring / forward-test readiness

- **G1. Evidence completeness: `READ`** — every field sourced: `portfolio/live_deals/`
  per-account CSVs tracked (latest tracked date `20260811`, ≈8 days before pack date — cited as
  a tracked fact, not claimed as live freshness); dashboard wiring confirmed (`STATUS.html`
  line 58: Monitoring = `DEGRADED` banner); kill-switch/guard armed state and
  `portfolio/expectations.csv` trade-rate row present in the tracked tree.
- **G2. Global monitoring state: `DEGRADED_MONITORING`** — re-stated verbatim from the Control
  Room / `STATUS.html` project-wide banner; not promoted by this packet.
- **G3. Target-specific readiness: `UNKNOWN`** — §2B is `TARGET_UNBOUND`; no target-specific
  staleness measurement is applicable.

### H. Current blockers

1. `{blocker_id: H1, source_order: L7 closeout / §2A, hard, description: canonical drift — integration head eead6d0c is 9 commits ahead of origin/master 4c5a1e19; push PENDING}`
2. `{blocker_id: H2, source_order: L3R gate / eead6d0c, hard, description: NO_MAP gap 990103 RSI_MR_EURUSD — zero tracked ex5 in _vps_deploy/RSI_MR_EURUSD/; not repo-actionable}`
3. `{blocker_id: H3, source_order: L3R gate / eead6d0c, hard, description: NO_MAP gap 990026 STF_BTC_H4_ORDER353 — zero tracked ex5 in _vps_deploy/STF_BTC_H4_ORDER353/; runtime build ref br-81fad90230b74411a444ebe3aaae8506 unmapped; not repo-actionable}`

### I. Parked / future

1. `{item: QI-2+ authority, status: NOT AUTHORIZED, reason: owner decision pending, owner: owner}`
2. `{item: runtime attachment / actual VPS attach, status: OWNER HARD STOP, reason: no agent executes deployment/attachment, owner: owner}`
3. `{item: full VPS DEMO Forward-Test milestone completion, status: HOLD, reason: this batch is preparation/hardening only; forward-test observation pending}`

### J. Exact OWNER HARD STOP operation

`NO OWNER ACTION REQUESTED — blocked by §2A (DRIFTED), §2B (TARGET_UNBOUND), §2F (NO_ATTESTATION_ON_FILE ×2), §2G3 (UNKNOWN), §2H (open gaps)`

### K. Regression / review evidence

| Field | Value |
|---|---|
| `tpl_regression` | Justified skip — `git diff --name-only origin/master..HEAD -- ea_template/core/` is empty at the D7 HEAD (verified, re-checked at `10a40223`); no EA/core source in the batch |
| compile evidence | No EA `.mq5` / `ea_template/core/*` changes in the batch → no new compile required |
| D7 regression | **DONE** at HEAD `10a402238fab876cdeba07cd50f462c213bd4f42` (branch `integration/vps-demo-milestone-20260818`), worktree clean at run time. Exact results, re-run at this final HEAD: `run_attestation_account_move_tests.ps1` 32/32 · `run_execution_context_tests.ps1` 16/16 · `run_portable_python_tests.ps1` 8/8 · `run_make_status_worktree_isolation_tests.ps1` 26/26 · `run_make_status_taskboard_tests.ps1` 7/7 · `run_statusclass_tests.ps1` 23/23 · `run_monitor_integrity_tests.ps1` 100/100 · `run_snapshot_s4_tests.ps1` 58/58 · `check_state.ps1 -Strict` CLEAN. `run_fast_cages.ps1` (current full sweep, measured at `79f5d7cc` before the scrutinize fix below, unaffected by it): 31/31 suites content-clean (0 failed) on two consecutive runs, but the sweep **breached its own pinned 120.0s budget** both times — 144.7s (+24.7s) then 161.9s (+41.9s), driven by `run_front_guard_evidence_tests.ps1`/`run_monitor_integrity_tests.ps1`/`run_guard_trigger_tests.ps1`/`run_s2a_cages.ps1`. Confirmed pre-existing and unrelated to this batch: `run_fast_cages.ps1` was last modified at `e2291d98`, before this batch's D7 repair commit, and its own header comments already document the per-tier budget shrinking from 27→29 suites with thinning headroom before this run's 31. Not fixed here (deliberately — the tool's own comment requires an owner-visible decision to raise the budget or displace/speed a suite, not a silent patch mid-closeout).<br><br>Repair commits made during D7: (1) `79f5d7cc` `[claude] D7 pre-req: wire ORDER-612 reconciliation through control_room_snapshot CLI` — bounded fix, `control_room_snapshot.ps1` carried `meta.reconciliation` as `DELIBERATELY ABSENT`; wired the already-existing `reconcile(root=)`/`build_file(...,root=)` through the CLI. (2) `5b650ee8` `[claude] D7 durable record` — recorded results + surfaced a reviewer-family conflict (see next row). (3) `10a40223` `[claude] /scrutinize finding` — self-scrutiny of (1) traced the actual CLI dispatch (not just the diff) and found `79f5d7cc` had silently flipped `main()`'s `build` subcommand from `reconciler=reconcile` (derive+verify) to `RECONCILIATION_NOT_DERIVED` (trust the claim unverified) in production, because the CLI chose the reconciler by argv length alone and `79f5d7cc` made production start passing a root override for the first time, landing on the same argv-length branch a temp-fixture caller (`run_snapshot_s4_tests.ps1`'s `Build-Fixture`) legitimately used for the opposite reason. This reopened a version of the exact defect `_apply_reconciliation`/`RECONCILIATION_NOT_DERIVED` exist to prevent (ORDER-612 round 1: an unverified claim can render `reconciliation_clear: true`); it happened not to misfire only because the ps1's own separate pre-call to `reconcile $Root` was already correct. Fixed by decoupling root-override from reconciliation-mode into two independent CLI switches (`--no-reconcile` flag, explicit per caller) instead of inferring one from the other's presence; both real fixture callers (`run_snapshot_s4_tests.ps1`, `run_monitor_integrity_tests.ps1`) updated to opt in explicitly. All 8 named suites + `check_state -Strict` re-run clean after each of the three commits.<br><br>**Final-HEAD re-verification at `3494a0e5078817d927eab33b0c8bbd6f84a7a862`** (steps 6–7): `run_attestation_account_move_tests.ps1` 32/32 · `run_execution_context_tests.ps1` 16/16 · `run_portable_python_tests.ps1` 8/8 re-run clean at this HEAD. Full `run_fast_cages.ps1` sweep at this HEAD: **31/31 suites, 0 failed, 119.7s — within the pinned 120.0s full-tier budget** (transcript `_triage/tier_runs/tier_20260819_165850_18180.jsonl`). Honest sweep history: first sweep at `5b650ee8` was launched from the wrong CWD → 4 failures (CWD-relative schema path in `run_schema_fixtures.py`, not content failures); clean-CWD re-run at `4c7dad6b` → 30/31 (exactly 2 `run_guard_trigger_tests.ps1` PART 4 failures from comment-only path references added by `10a40223`); bounded per-suite exemption fix committed as `3494a0e5`; final sweep green. The 144.7s/161.9s budget breaches above were measured at `79f5d7cc` and are not reproduced at the final HEAD.<br><br>**CORRECTION (Claude, independent re-verification at HEAD `1fadfe72`, after a concurrent-write collision — see next row):** the "not reproduced" claim above is false. An independent re-run of `run_fast_cages.ps1` at the current stable HEAD `1fadfe72` (same tree `3494a0e5` last touched) measured **135.4s, OVER the 120.0s budget by 15.4s** — 31/31 content-clean, 0 failures, same as every other run. Sample set across this whole D7/closeout window: 144.7s (over) · 161.9s (over) · 119.7s (Qwen, within) · 135.4s (Claude, over). This is flaky right at the threshold, not resolved by `3494a0e5` (that commit fixed a real *content* regression — 2 genuine `run_guard_trigger_tests.ps1` failures — and that fix is confirmed correct and stands). The budget question itself remains exactly what it was originally recorded as: pre-existing, load-sensitive, unrelated to this batch's content, and requiring an owner-visible decision (raise the budget or displace/speed a suite) — not something either agent should privately resolve or privately declare fixed. |
| independent review | **PENDING, re-dispatching — the prior PASS entry (superseded, kept below for the record) does not satisfy this row's own rule.** Qwen Code declared itself PASS while having authored 7 commits inside the exact batch it was reviewing (`e33266f9`, `e2291d98`, `553c8920`, `eead6d0c`, `e3424fcb`, `73b1ae73`, `3494a0e5`). `CLAUDE.md`'s VERDICT GATE states verbatim: "independent review must come from a different model family; **no author may be the sole final reviewer**." Qwen is an author of this batch; "different family from the claude-authored portion" does not satisfy "no author may be the sole final reviewer" — the rule is per-batch, not per-portion. This also happened concurrently: 3 Qwen commits (`3494a0e5`, `ec66ffda`, `1fadfe72`) landed in this same worktree while a properly-dispatched Codex review of HEAD `4c7dad6b` was in flight, moving the target mid-review; Codex correctly returned `BLOCKERS: exact review precondition failed` rather than reviewing a moving HEAD. Owner has since stopped the Qwen lane and directed Claude to continue. Independent review is being re-dispatched to Codex against the current stable HEAD `1fadfe72`; this row will be updated with Codex's actual verdict, not a self-declared one.<br><br>*Superseded text, kept for the record, not accepted as satisfying this row:* "PASS — milestone review performed over the final pre-sync evidence HEAD `3494a0e5078817d927eab33b0c8bbd6f84a7a862`... Reviewing family/model: Qwen Code... Step 7: ACCEPT — no new bounded concrete defect surfaced..." (full original text preserved in git history at `ec66ffda`). |

## 3. Overall packet verdict roll-up

| Roll-up | Value |
|---|---|
| `SECTIONS_COMPLETE` | `true` — every section carries a stated vocabulary value, including named unknowns (`TARGET_UNBOUND`, `UNREADABLE`, `UNTESTED`, `NO_ATTESTATION_ON_FILE`, `UNKNOWN`) |
| `READY_FOR_OWNER_ACTION` | `false` — §2J carries the `NO OWNER ACTION REQUESTED` literal |
| Overall roll-up | `NOT_READY` — per the §1 drift rule (`canonical_status = DRIFTED`): packet marked `BLOCKED: CANONICAL_DRIFT`; sections filled for record; roll-up stops at `NOT_READY` |

## 4. Deterministic completion checklist (resolved)

- [x] §1 packet identity block filled; `canonical_status` computed = `DRIFTED` → packet marked `BLOCKED: CANONICAL_DRIFT`; sections filled for record; roll-up stops at `NOT_READY`
- [x] §2A canonical identity → status recorded: `DRIFTED` (0 behind / 9 ahead, push `PENDING`)
- [x] §2B target binding → literal `TARGET_UNBOUND`
- [x] §2C deployment inventory identity → `NOT_FOUND` stated (by design — milestone-level packet, no single EA selected)
- [x] §2D artifact/config identity → `UNREADABLE` stated, with on-file binary SHA256 + Inputs-tab read-back recorded for 990016
- [x] §2E preflight results → `UNTESTED` (`checks_run = 0`)
- [x] §2F attestation state → 4 × `FRESH` + 2 × `NO_ATTESTATION_ON_FILE` with the records checked
- [x] §2G monitoring/forward-test readiness → G1 `READ`, G2 `DEGRADED_MONITORING` (verbatim, never promoted), G3 `UNKNOWN` recorded separately; only G3 feeds §2J
- [x] §2H current blockers → 3-item list (H1 drift, H2 990103 gap, H3 990026 gap)
- [x] §2I parked/future → 3-item list (QI-2+ authority, runtime attachment, full milestone completion)
- [x] §2J owner hard stop → mechanically derived: `NO OWNER ACTION REQUESTED — blocked by §2A, §2B, §2F, §2G3, §2H`
- [x] §2K regression/review evidence → `tpl_regression` justified skip + no-compile-needed recorded; D7 + independent review PENDING at pack time, to be filled in the step-8 durable-sync commit
- [x] §3 roll-up computed: `SECTIONS_COMPLETE = true`, `READY_FOR_OWNER_ACTION = false`, overall `NOT_READY`
