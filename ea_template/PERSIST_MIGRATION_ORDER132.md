# ORDER-132 — Persist GlobalVariable migration (live/demo terminals)

**Applies to:** every Boss-template EA (Boss_11..18 wrappers + derived deploy bundles)
compiled after ORDER-132. **Tester is unaffected** (GVs sandboxed per pass — regression
numbers cannot move).

## What changed

| | Pre-132 (legacy) | Post-132 (scoped) |
|---|---|---|
| Key format | `Boss_<magic>_<name>` | `Boss2_<srvhash8>_<login>_<symbol>_<magic>_<name>` |
| Halt/kill state | 2 flags: `rc_halted`, `rc_kill_pending` | 1 enum: `rc_state` (0 RUNNING / 1 KILL_PENDING / 2 HALTED) |
| Other keys | `rc_peak_eq`, `acct_hwm` | same names, scoped format |
| New keys (Boss_16 only) | — | `k16_pair_a` / `k16_pair_b` / `k16_pair_ok` (commit marker, ORDER-138 #2) — in-flight overlap pair-close intent; auto-cleared once both legs are broker-confirmed closed. Legs are only trusted under the marker (torn write = intent discarded, complete-or-none) |
| Close-all intent keys (ORDER-138 #3) | — (memory-only pre-138) | `exit_closeall` (chassis basket exits) / `k16_closeall` (Boss_16) — armed+flushed **before** the first close is sent, cleared only after broker-flat proof **and a confirmed key delete** (138b F4); a restart mid-liquidation resumes closing instead of returning residual legs to normal management. **Degraded mode (deliberate):** if the arm write itself fails, the close still proceeds — flattening a losing basket must never be hostage to a GV write; the only loss is restart-resumption, and the failure is logged loudly |
| TTL keep-alive scope (138b F9) | — | daily re-touch covers `rc_state` / `rc_peak_eq` / `acct_hwm` (RiskControl_PersistRefresh); **armed intent keys** (`exit_closeall` / `k16_closeall` / pair record) are re-touched every ~60s **while the liquidation retries**. A symbol that stops ticking gets neither retouches nor retries — if an intent could sit unresolved for ~4 weeks with zero ticks, expect the GV to expire (known limitation, logged design trade-off) |
| Write checking | fire-and-forget | checked + `GlobalVariablesFlush()` on kill/halt transitions + **daily TTL keep-alive** (MT5 expires GVs ~4 weeks after last use — 132b Codex R3) |

`srvhash8` = 8-hex djb2 checksum of `ACCOUNT_SERVER` (full server name would blow the
63-char GV name limit; 132b widened from 4-hex after Codex flagged 16-bit aliasing).
`OnInit` refuses a live/demo attach **fail-closed** if a scoped key would exceed the
63-char limit (extreme symbol/login/magic lengths — 132b Codex P1). **Why scoped:**
Codex F4 — magic-only keys let a terminal that switched accounts (or one magic reused
on two symbols) inherit another instance's halt/kill state and reconcile a kill against
the WRONG account's positions.

## Auto-migration (first attach of a post-132 binary)

On `OnInit` with `RC_PersistHalt=true` (default):

0. **ORDER-138 #1 + 138b gate (fail-closed):** if **any legacy key this init would
   read** exists — active `Boss_<magic>_rc_kill_pending=1` / `..._rc_halted=1`,
   `..._rc_peak_eq` (any value), or `..._acct_hwm` (when `RC_AcctDDLimitPct>0`) — and
   the input `RC_AdoptLegacyHalt=false` (default), **OnInit refuses the attach** —
   nothing is migrated or deleted. Rationale: legacy keys are magic-only (no account
   identity); a terminal that switched logins would otherwise adopt *another
   account's* state — an active kill/halt closes the wrong positions, and a foreign
   higher-equity `rc_peak_eq` makes KillDD liquidate the current account on the first
   tick (Codex ORDER-138 audit F1). The journal `[RISK] FATAL` line names the key(s)
   and both resolutions. *Inactive* (0.0) kill/halt leftovers do not trip the gate.
1. `rc_peak_eq` / `acct_hwm`: legacy value copied to the scoped key **once** (only if the
   scoped key doesn't exist), then the legacy key is **deleted** — behind the step-0
   consent gate.
2. `rc_halted` / `rc_kill_pending`: read once, collapsed into scoped `rc_state`
   (kill_pending wins over halted), then both legacy keys are **deleted** —
   **requires `RC_AdoptLegacyHalt=true` when the legacy state is active** (step 0).
3. `GlobalVariablesFlush()` makes it durable. Journal logs every step as
   `[PERSIST] migrated legacy ...` / `[RISK] migrated legacy halt/kill flags ...`.
4. A migrated `KILL_PENDING` resumes close-all reconciliation exactly like a restart
   mid-kill did before — if the account is already flat, the first tick verifies and
   latches HALTED.
5. **DryRun instances never write or delete** — they log what they *would* migrate.

Legacy keys are deleted (not kept) deliberately: a surviving magic-only key could be
re-imported later by a *different* account login in the same terminal — the exact F4
contamination class. Consequence: **rolling back to a pre-132 binary loses persisted
state** (the old binary looks for legacy keys that no longer exist). Hence the snapshot
step below.

## Operator checklist (do this per terminal, demo first — ห้าม upgrade live ก่อนผ่าน demo)

1. **Before upgrading:** Tools → Global Variables (F3) → screenshot/export every `Boss_*`
   row (this is the rollback record).
2. If the terminal **ever switched accounts** while a Boss EA was attached: delete stale
   `Boss_<magic>_*` rows that belong to the *other* account **before** attaching the new
   binary (a migrated `rc_kill_pending=1` will close matching symbol+magic positions on
   the *current* account — that is correct for in-place upgrades, wrong for imported
   state). **ORDER-138 #1 enforces this:** with an active legacy kill/halt present the
   EA refuses to start until you either delete the foreign rows (contamination case)
   or set `RC_AdoptLegacyHalt=true` (in-place upgrade of *this* account's own state).
3. Attach the post-132 build on **demo**. If step 0's gate trips on this terminal's own
   pre-132 halt/kill state: set `RC_AdoptLegacyHalt=true` in the .set **for this upgrade
   attach only**, confirm migration, then **set it back to `false`** (leaving it true
   would re-enable blind adoption on a future account switch — the exact bug this gate
   closes). Check the Experts journal for the `[PERSIST] migrated ...` lines; F3 should
   now show `Boss2_*` keys and no `Boss_*` keys for that magic.
4. Restart the terminal once; confirm state survives (HALT stays halted, peak retained —
   journal prints the restore line with the exact `Boss2_..._rc_state` key name).
5. Only then roll the same binary to live terminals.
6. **Manual un-halt (post-132):** delete the `Boss2_..._rc_state` GV (exact name is in
   the HALT log line) — the old advice "delete `Boss_<magic>_rc_halted`" no longer
   applies.

## Live inventory notes (2026-07-19)

- **Boss_14 GBPJPY (live):** has `RC_PersistHalt=true` state → follows checklist above.
- **ST03 (Boss_15):** removed from live 159475669 (ORDER-118 CLOSED-OBSOLETE) — no live
  GVs to migrate; demo instances follow the same checklist.
- Kangaroo pair-close intent (ORDER-132b Codex K2) **is persisted** (`k16_pair_a/b`) —
  a restart mid-liquidation resumes closing both legs; restored tickets are re-validated
  against symbol+magic before any close. New keys, no legacy form → nothing to migrate.
- **ORDER-138 #2:** pair legs written by a *pre-138* post-132 binary have no
  `k16_pair_ok` commit marker — a post-138 restart discards them (logged as torn
  intent) and the legs return to normal basket management under the cage. **Before
  upgrading a Boss_16 instance:** check F3 for `Boss2_..._k16_pair_a/b` rows (and the
  journal for an unresolved `[K16] pair-close intent` line). If present, a pair
  liquidation is in flight — wait until it resolves (keys auto-clear) or the basket is
  flat before swapping the binary (Codex ORDER-138 audit F8).
