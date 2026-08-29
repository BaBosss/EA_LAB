# Source Intake and Registry

`source_registry.jsonl` contains promoted research sources whose provenance can be checked deterministically. Local tracked sources are SHA-256 bound.

`drive_intake_20260829.csv` is a **read-only intake inventory**, not a source registry. It records the 26 direct files currently in the owner-supplied Google Drive folder. Items remain intake-only until their content identity is confirmed and, where needed, a stable hash/provenance record is available.

`drive_batch1_hash_receipt_20260829.csv` records SHA-256 over exact downloaded PDF bytes for the seven Batch 1 full-text sources plus the two 151 Trading Strategies objects used for duplicate proof. The two 151 objects are byte-identical by SHA-256; this is evidence only and does not authorize deletion.

`drive_batch2_hash_receipt_20260829.csv` records SHA-256 over exact downloaded PDF bytes for the five Batch 2 full-text sources covering mean reversion, contradictory momentum, execution timing, benchmark liquidity and relative-strength rotation.

Triage labels are navigation only:

- `CORE_*` — prioritize for later deep extraction;
- `SUPPORT_*` — useful contextual/counterevidence research;
- `PENDING_CLASSIFICATION` — title/abstract not yet inspected in this bounded pass;
- `REJECT_UNRELATED` — source content already inspected and outside the EA trading corpus;
- `*_DUPLICATE_CANDIDATE` — metadata suggests duplication but byte/hash proof is not yet available;
- `*_DUPLICATE_CONFIRMED` — exact bytes have matching SHA-256; deletion still requires separate authorization.

No intake label is an EA or Factory verdict.