# Source Intake and Registry

`source_registry.jsonl` contains promoted research sources whose provenance can be checked deterministically. Local tracked sources are SHA-256 bound.

`drive_intake_20260829.csv` is a **read-only intake inventory**, not a source registry. It records the 26 direct files currently in the owner-supplied Google Drive folder. Items remain intake-only until their content identity is confirmed and, where needed, a stable hash/provenance record is available.

Triage labels are navigation only:

- `CORE_*` — prioritize for later deep extraction;
- `SUPPORT_*` — useful contextual/counterevidence research;
- `PENDING_CLASSIFICATION` — title/abstract not yet inspected in this bounded pass;
- `REJECT_UNRELATED` — source content already inspected and outside the EA trading corpus;
- `*_DUPLICATE_CANDIDATE` — metadata strongly suggests duplication but deletion/dedup requires byte/hash proof.

No intake label is an EA or Factory verdict.