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
