"""
gen_s2a_migration_doc.py - ORDER-600 (S2a) deliverable D2, generated from D1.

The whole document is generated, prose included, for the same reason the contract tables are: a
hand-maintained summary of a machine file drifts from it, and a reader cannot tell. The judgement
prose lives here as data; the tables are folded out of `s2a_migration.jsonl` on every run, so a row
that changes in D1 cannot leave a stale sentence behind in D2.

USAGE  tools\\python312\\python.exe _triage/factory_os/gen_s2a_migration_doc.py [--check]
"""
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check_s2a_migration as chk  # noqa: E402

DOC_PATH = '_triage/factory_os/S2A_OWNERSHIP_MIGRATION.md'

INTRO = """# S2a — Coverage ownership proposal and migration table

> **Generated** by `_triage/factory_os/gen_s2a_migration_doc.py` from
> `_triage/factory_os/s2a_migration.jsonl` (D1). Do not edit by hand — run the generator.
> `ORDER-600` · deliverables **D1 + D2** · machine acceptance =
> `_triage/factory_os/check_s2a_migration.py` (nine criteria, all green at the commit that
> introduced this file).

## What you are being asked to do

This is a **proposal about ownership**, not a change to it. Nothing in `MASTER_BACKLOG.md` has been
edited, nothing under `factory/` has been created, and no row says `APPROVED` — that value is yours to
write, in your own commit.

For each of the **27** entities the Factory OS schema defines, one row states: **where that fact lives
today**, where the design proposes it should live, and what concretely breaks if it moves or if it
does not. Twelve rows propose a move (`TRANSFER`), fifteen propose leaving things alone (`KEEP`), and
**one of the twelve is marked `REFUSED` by me rather than proposed to you** — see *What I refused*
below.

**The one decision that matters most is the first row of the table: the Coverage edge.**

## The Coverage edge, in one read

`MASTER_BACKLOG.md` §2 declares itself the owner of the coverage matrix — which EA has been tested on
which symbol × timeframe. The design proposes `factory/coverage.jsonl` become the machine source and §2
be **regenerated** from it.

Two measurements decide this, and both were taken rather than assumed:

- **Nothing machine-reads §2 today.** The only parser of `## 2. COVERAGE MATRIX` anywhere in the repo
  is `parse_section2()` inside this order's own checker. `scripts/check_state.ps1:124` opens the file
  solely to assert it contains the string `canonical entry =` (its owner banner) and never looks at the
  table; `scripts/check_block_staleness.ps1:57` only lists it as self-referential. **So the transfer
  breaks no automated reader.** The risk is human: the banner tells readers the table is
  hand-maintained, so the banner and the section header must say *"generated — edits here are
  overwritten"* in the same commit that generates it. That mitigation is part of the proposal, not an
  afterthought.
- **Leaving it costs something already.** Design §1.2 measured §2 at **7 EA rows**, last really updated
  **2026-06-27**, while `portfolio/DEPLOYMENTS.csv` carries **64** deployment rows. The two have never
  been reconciled at any granularity. The declared owner of "what is tested" is a five-week-old hand
  table describing a fleet it does not cover.

**Recommendation: approve the Coverage edge (`TRANSFER`), on the condition that the banner change ships
in the same commit as the first generation.** Everything else in this table can be decided later; this
row is what `S2` is blocked on.

## What the green checker does and does not prove

`check_s2a_migration.py` exits 0 on this data. That means: all 27 entities are accounted for by set
equality against the schema, no row is self-approved, every `current_owner` is a path that really
exists at HEAD, **every `owner_ref` hash was re-resolved from git and matched**, the Coverage edge is
present, not every row is `KEEP`, and the two coverage numbers reconcile through a mapping.

It does **not** prove the breakage analysis is any good. A checker cannot judge whether
`breaks_if_moved` names the right reader. That is the human-review checklist below, and it is the part
worth your time.

`_triage/factory_os/run_s2a_migration_tests.py` mutates this real file 24 ways — a flipped hash digit,
the Coverage edge removed, every row flipped to `KEEP`, a `LIVE` cell dropped from the mapping — and
requires each to redden the criterion it targets by name, with the unmutated file as a green control.
A green checker that cannot fail against the file it just passed is not evidence.
"""

REV5 = """## Two amendments I made to the order before writing any data

The acceptance was already amended once (rev 4) because three clauses could not all hold. Writing the
data surfaced two more of the same shape — a rule that cannot be obeyed for a measured subset of the
27. Both are recorded in `ORDERS_S2a_S3a_DRAFT.md` as **rev 5**, amended *before* the data rather than
quietly reinterpreted while building.

1. **D1's declared path pointed outside the slice.** `factory_os/s2a_migration.jsonl` was implemented
   literally as a **repo-root** `factory_os/` — a directory that does not exist, and where no other
   artifact of this slice lives. Every sibling path here carries the `_triage/` prefix, and D2's own
   declared path in the same list carries it. Corrected to `_triage/factory_os/`; nothing was created
   at the repo root.
2. **A genuinely unowned fact had no legal `current_owner`.** Measured from the schema's `$ref` graph
   rather than its prose: **9** entities are embedded in a parent, **14** have a real artifact holding
   the fact today, and **4** — `TestUniverse`, `LogicalSymbol`, `SafeProjection`, `RunJournal` — have
   **neither a file nor a parent**. Design §1.3 #2 says outright that Test Universe is *"genuinely
   unowned"*. For those four the rule allowed only: name a real file (a false claim about today),
   claim a parent (false — nothing references them), or omit the row (fails set equality). So
   `UNOWNED` is now legal — **and deliberately not a free pass**, because an unguarded sentinel would
   let all 27 rows out of the existence check and reinstate the null migration under a new name:
   - `unowned_evidence` must name a tracked file, **and the checker opens it and requires the entity to
     actually be mentioned there.** A claim that the design says so is not enough.
   - `UNOWNED` + `KEEP` additionally requires `canonical_or_derived = derived`. A *canonical* fact that
     nobody owns and nobody is proposed to own is drift, and must not be signable as "keep". Exactly
     one row qualifies (`RunJournal`, which is derived by folding an append-only log and correctly gets
     no owner ever).

   **While there, every `EMBEDDED:<Parent>` claim is now verified against the `$ref` graph** — the
   parent must really reference the child. This caught a stale number being carried forward: the
   handoff said 12 entities were embedded and listed `WorkReceipt`, which owns `ops/receipts/`. The
   graph says **9**. The prose count was wrong; the graph is not.
"""

CLOSING = """## What I refused, and why it is not an omission

`WorkReceipt` is the one row whose `signoff_state` is **`REFUSED`** rather than `PROPOSED`.

Design §1.3 #9 states that opening this writer needs an **`AGENTS.md` §2 permission change the user
must ratify first**. `AGENTS.md` §2 currently lets an agent write only its own order row on the
taskboard and reserves new orders to Claude/the user. Proposing the transfer now would mean proposing
a writer the governance file forbids. `REFUSED-pending-ratification` is the honest state, and it is
recorded on the row in `refused_reason`.

This matters beyond the one row: a table where all twelve `TRANSFER`s are uniformly `PROPOSED` is
indistinguishable from a table nobody thought about.

## Observations found while writing this, not fixed here

- **The schema's own prose is wrong about a version.** `ControlRoomSnapshotV5`'s `x-owner-file` says
  `portfolio/control_room_snapshot.json (EXISTING, v4 at HEAD)`. The file at HEAD carries
  `"version": 3`, and design §1.1 also says v3. Not fixed here — this order writes a proposal about
  ownership, and a schema version is not an ownership fact. Routed to **S4**, which owns the v4→v5
  migration and is already blocked on the real snapshot failing the schema.
- **`INTAKE_QUEUE.md` has no machine reader at all** (`git grep` over `scripts/` and `.githooks/`
  returns nothing), which is why its row is `KEEP`: design §1.3 #11 adds stable-ID and URL-dedupe
  columns *to the existing owner* rather than creating `ops/ideas.csv`.

## How to approve or refuse

`signoff_state` is yours. Per row, in your own commit:

- **approve** → set `signoff_state` to `APPROVED` on that row of
  `_triage/factory_os/s2a_migration.jsonl`. Note the checker refuses `APPROVED` **by design** — that
  guard exists to stop *me* writing it, so the criterion has to be relaxed to accept the owner's act
  in the same commit that records your approval. That relaxation is deliberately not pre-built, so it
  cannot be used before you have decided.
- **refuse** → set `signoff_state` to `REFUSED` and add a `refused_reason`. A refusal with a stated
  reason closes the question; silence leaves it open and it comes back.

Regenerate this document with
`tools\\python312\\python.exe _triage/factory_os/gen_s2a_migration_doc.py` after any edit to D1, and
`--check` will tell you if the two have drifted apart.
"""

CHECKLIST_FIELDS = (
    ('breaks_if_moved', 'Breaks if moved — names a specific reader or writer'),
    ('breaks_if_not_moved', 'Breaks if NOT moved — a concrete failure, with a date or trigger'),
    ('reverse_steps', 'Reverse steps — executable, not "revert the commit"'),
    ('evidence_lost', 'Evidence lost — what cannot be reconstructed'),
    ('retention_window', 'Retention window'),
)


def esc(s):
    return str(s).replace('|', '\\|')


def short(s, n=68):
    s = str(s)
    return s if len(s) <= n else s[:n - 1] + '…'


def build(rows, cov):
    out = [INTRO, '']
    # ---------------------------------------------------------------- the summary table
    out.append('## All 27 rows at a glance\n')
    out.append('Folded from D1 on every generation, so this table cannot drift from the data.\n')
    out.append('| entity | lives today | proposed | disposition | signer | state |')
    out.append('|---|---|---|---|---|---|')
    order = {'TRANSFER': 0, 'RETIRE': 1, 'KEEP': 2}
    for r in sorted(rows, key=lambda r: (order.get(r['disposition'], 9), r['entity'])):
        state = r['signoff_state']
        if state == 'REFUSED':
            state = '**REFUSED**'
        disp = r['disposition']
        if disp == 'TRANSFER':
            disp = '**TRANSFER**'
        out.append('| `%s` | `%s` | `%s` | %s | %s | %s |'
                   % (r['entity'], esc(short(r['current_owner'], 46)),
                      esc(short(r['proposed_owner'], 46)), disp,
                      esc(r['signoff_owner']), state))
    counts = {}
    for r in rows:
        counts[r['disposition']] = counts.get(r['disposition'], 0) + 1
    out.append('')
    out.append('**%s** · %d rows total.'
               % (' · '.join('%s = %d' % (k, counts[k]) for k in sorted(counts)), len(rows)))
    out.append('')

    # ---------------------------------------------------------------- coverage reconciliation
    out.append('## The two coverage numbers, reconciled rather than equated\n')
    out.append('`ORDER-600` requires these be reported separately **with a mapping**, because they are '
               'not the same number and equating them is how a coverage claim quietly loses a cell.\n')
    out.append('| number | value | what it counts |')
    out.append('|---|---|---|')
    out.append('| `source_rows_consumed` | **%d** | EA rows in `MASTER_BACKLOG.md` §2, each consumed '
               'exactly once |' % cov['source_rows_consumed'])
    out.append('| `live_cells_only` | **%d** | symbol × TF cells in the LIVE column — `ST_EA03` alone '
               'carries two (GBPUSD H1 *and* USDCAD H1), which is why 7 ≠ 8 |'
               % cov['live_cells_only'])
    out.append('| `cells_emitted` | **%d** | every normalised cell, LIVE plus the "other symbols '
               'tried" column |' % cov['cells_emitted'])
    out.append('')
    unv = sum(1 for m in cov['mapping'] for c in m['cells']
              if isinstance(c, dict) and c.get('status') == 'UNVERIFIED_IMPORT')
    out.append('%d of the %d emitted cells are marked **`UNVERIFIED_IMPORT`**, each carrying its source '
               'coordinates. They are not sloppiness — §2\'s last column states a symbol and an outcome '
               'but almost never a timeframe, so a symbol × TF cell cannot be built from it without '
               'guessing. Tokens like `EUR`, `AUD` and `NZD` are recorded **verbatim** for the same '
               'reason: expanding them silently would invent test coverage that was never measured.\n'
               % (unv, cov['cells_emitted']))
    out.append('The LIVE cells are declared independently in `gen_s2a_migration.py` **and** parsed from '
               'the file, and the generator refuses to write if the two derivations disagree — the same '
               'two-independent-derivations discipline that established 7/8 in the first place.\n')

    # ---------------------------------------------------------------- per-TRANSFER detail
    out.append('## Human review — the part the checker cannot do\n')
    out.append('One block per row that proposes a move. These four fields are the reviewer checklist '
               'from `ORDER-600`; read them asking *"does this name a real reader, and a real failure"* '
               '— the rev-1 acceptance called this analysis "numeric, checkable", and it is not.\n')
    for r in sorted(rows, key=lambda r: r['entity']):
        if r['disposition'] != 'TRANSFER':
            continue
        flag = '  🚫 **REFUSED**' if r['signoff_state'] == 'REFUSED' else ''
        out.append('### `%s` — `%s` → `%s`%s\n'
                   % (r['entity'], r['current_owner'], r['proposed_owner'], flag))
        out.append('*%s · signer: %s · state: %s*\n'
                   % (r['canonical_or_derived'], r['signoff_owner'], r['signoff_state']))
        if r.get('refused_reason'):
            out.append('> **Why refused:** %s\n' % r['refused_reason'])
        for key, label in CHECKLIST_FIELDS:
            out.append('- **%s:** %s' % (label, r[key]))
        out.append('')

    # ---------------------------------------------------------------- KEEP rows, compact
    out.append('## The `KEEP` rows, and why each is a choice rather than a default\n')
    out.append('`ORDER-600` treats an all-`KEEP` table as the null migration, so every `KEEP` carries a '
               'named reason. Nine of these are entities embedded in a parent — they own no file, so '
               'there is no storage to transfer, and each parent claim is verified against the schema '
               '`$ref` graph rather than believed.\n')
    out.append('| entity | lives today | why KEEP |')
    out.append('|---|---|---|')
    for r in sorted(rows, key=lambda r: r['entity']):
        if r['disposition'] != 'KEEP':
            continue
        out.append('| `%s` | `%s` | %s |' % (r['entity'], esc(short(r['current_owner'], 40)),
                                             esc(short(r.get('keep_reason', ''), 300))))
    out.append('')
    out.append(REV5)
    out.append(CLOSING)
    return '\n'.join(out).rstrip() + '\n'


def main(argv):
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    os.chdir(root)
    if not os.path.exists(chk.MIGRATION_PATH):
        print('[ABORT] %s does not exist - D2 is generated FROM D1, so there is nothing to render.'
              % chk.MIGRATION_PATH)
        return 2
    rows = [json.loads(l) for l in io.open(chk.MIGRATION_PATH, encoding='utf-8') if l.strip()]
    cov = json.load(io.open(chk.COVERAGE_PATH, encoding='utf-8'))
    text = build(rows, cov)
    if '--check' in argv:
        got = io.open(DOC_PATH, encoding='utf-8').read() if os.path.exists(DOC_PATH) else None
        if got != text:
            print('[STALE] %s differs from what the generator produces (re-run without --check)'
                  % DOC_PATH)
            return 1
        print('[OK] %s matches D1' % DOC_PATH)
        return 0
    with io.open(DOC_PATH, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(text)
    print('[WROTE] %s (%d lines from %d rows)' % (DOC_PATH, text.count('\n') + 1, len(rows)))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
