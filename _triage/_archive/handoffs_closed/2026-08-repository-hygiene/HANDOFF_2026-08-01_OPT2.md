# HANDOFF — lane `S-2026-08-01-OPT2` (2026-08-01), block 800-809, no MT5 lane

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this is a **shift-change note, not a queue**
> (Decision log 2026-07-26). Every forward-looking item has a home — the routing table at the
> bottom says which.

## The one-line state

**`ORDER-731` option 2 is LANDED and owner-signed (`c66d5e57`, record line 9, bundle `d88f795b`).
All three gates that were RED are GREEN at HEAD, the full tier is 16/16, and the post-landing
adversarial review found NO blocker.** Item 2 (the tier abort) remains OPEN, untouched by this lane.

## What landed, and the two traps that were caught on the way

1. **Option 2 re-read:** the ratified idea "move the Coverage owner to `factory/coverage.jsonl`"
   is UNEXECUTABLE as literally stated — moving `current_owner` fails **R6** for all historical
   records (measured 7 eligible → 0, unrepairable in an append-only log) and erases **C7**'s
   Coverage edge. What landed instead: **the pin (`owner_ref`) follows the canonical bytes; the
   owner field stays.** Precedent: the transfer commit `a424e90b` never touched D1, and re-pinning
   has precedent (`59a27f97`). The second whole-file pin (F5 via the permanent STALE note) is gone;
   record line 9 needs no acknowledgement at all.
2. **Trap 1 (worker's first pass):** notes derived on `owner_ref.path` but matched on
   `current_owner` ⇒ F2–F5 silently inert for the one owner that matters. Closed with the
   `owner_ref_paths`/`note_for_owner` mapping; proven to fire on drift (F2/F3/F4/F5 each by name)
   and stay silent today; measured no-op for every other row.
3. **Trap 2 (seat's review):** the policy header still carried the pre-landing corpus counts —
   shape 4 in the row that says "counted, not typed". Recounted (69/21/47/1); that recount is the
   only reason the signed digest moved `9054c1a1 → d88f795b`, and the record's `recorded_by`
   states the sequence verbatim.

## Where the toll now sits (measured)

- Appends to `MASTER_BACKLOG.md` outside §2: **free** (probed on the landed state).
- Edits inside §2 / `gen_coverage.py --apply`: **one signature** (the §2 section pin — option A).
- `factory/coverage.jsonl` drift: fires F2 on line 9 ⇒ one ack signature; that file has **1 commit
  ever** vs the backlog's 31/14d (~31× fewer signature events). NOTE: once such an ack exists it
  becomes a whole-file front-guard pin on `factory/coverage.jsonl` until re-acked — true, and not
  yet stated in §4.5 (batched below).

## Do not do these

- ❌ Do not copy line 8's `stale_pin_acknowledgement` into any future record. It passes the checker
  green (no note exists for `MASTER_BACKLOG.md`, so F3–F5 never read it) and **resurrects the
  whole-file toll at the front guard** (M3). Until M3 is fixed, an ack's `path` must be a path some
  D1 row pins.
- ❌ Do not take the next record from `--template` as-is: it omits `expected_post_state` (the §2
  pin silently evaporates — M2) and, on drift, guides the signer to an ack path F3 refuses (M1).
- ❌ Do not add a D1 row that pins `MASTER_BACKLOG.md` without fixing M4 first — the sorted-first
  tie-break would silently flip enforcement back to the busy file.
- ❌ Do not edit any bundle member (D1 · D2 · reconciliation · `check_s2a_migration.py` · POLICY ·
  VECTORS) without budgeting one signature — unchanged rule, current digest `d88f795b`.

## Routing — every forward-looking item has a home

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| option 2 (pin follows canonical bytes · note mapping · owner-signed line 9 · gates green) | DONE |
| M1–M4 from the post-landing review — one implementation pass, non-bundle files, zero signatures; full specs with file:line on the `ORDER-731` row | ORDER-731 |
| stale-count batch for the NEXT signature (§7 "19 green" · §9 "35" · §1 "five signatures" · G4 "F1–F11" · §4.2 "7 records" · corpus line-1 "DRAFT" header · state the ack-becomes-pin consequence in §4.5) | ORDER-731 |
| per-row re-pin capability for `gen_s2a_migration.py` (write-mode regeneration re-pins all 14 rows; six advisory notes were reset as a side effect) | ORDER-731 |
| `ORDER-731` item 2 — the tier abort; wake condition as corrected by lane `PINFIX3B`, untouched here | ORDER-731 |
| a module should DECLARE the paths it reads | ORDER-761 |
| the locked-constant half of design §5.6 | ORDER-730 |

## Other lanes

None were `ACTIVE`. The `PINFIX3` / `PINFIX3B` handoffs of the same day carry the option-A story
and its correction; this lane closes the arc they opened.
