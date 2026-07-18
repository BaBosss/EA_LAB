# ORDER-132 — Persist GlobalVariable migration (live/demo terminals)

**Applies to:** every Boss-template EA (Boss_11..18 wrappers + derived deploy bundles)
compiled after ORDER-132. **Tester is unaffected** (GVs sandboxed per pass — regression
numbers cannot move).

## What changed

| | Pre-132 (legacy) | Post-132 (scoped) |
|---|---|---|
| Key format | `Boss_<magic>_<name>` | `Boss2_<srvhash4>_<login>_<symbol>_<magic>_<name>` |
| Halt/kill state | 2 flags: `rc_halted`, `rc_kill_pending` | 1 enum: `rc_state` (0 RUNNING / 1 KILL_PENDING / 2 HALTED) |
| Other keys | `rc_peak_eq`, `acct_hwm` | same names, scoped format |
| Write checking | fire-and-forget | checked + `GlobalVariablesFlush()` on kill/halt transitions |

`srvhash4` = 4-hex djb2 checksum of `ACCOUNT_SERVER` (full server name would blow the
63-char GV name limit). **Why:** Codex F4 — magic-only keys let a terminal that switched
accounts (or one magic reused on two symbols) inherit another instance's halt/kill state
and reconcile a kill against the WRONG account's positions.

## Auto-migration (first attach of a post-132 binary)

On `OnInit` with `RC_PersistHalt=true` (default):

1. `rc_peak_eq` / `acct_hwm`: legacy value copied to the scoped key **once** (only if the
   scoped key doesn't exist), then the legacy key is **deleted**.
2. `rc_halted` / `rc_kill_pending`: read once, collapsed into scoped `rc_state`
   (kill_pending wins over halted), then both legacy keys are **deleted**.
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
   state).
3. Attach the post-132 build on **demo**; check the Experts journal for the
   `[PERSIST] migrated ...` lines; F3 should now show `Boss2_*` keys and no `Boss_*`
   keys for that magic.
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
- Kangaroo pair-close residual state (ORDER-132 F3) is **in-memory only** — nothing to
  migrate; after a restart the residual leg simply rejoins normal grid management.
