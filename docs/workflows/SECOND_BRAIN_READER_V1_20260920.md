# Second Brain Reader / Owner Access V1

## Boundary

Frozen read/navigation/advisory over curated `knowledge/`. It is not a registry, verdict engine, AI router,
crawler, runtime control plane, strategy authority, or future-runtime promise. Draft visibility is not approval.

## Deterministic export

Use repository Python (`scripts/use_python.ps1` or `tools/python312/python.exe`):

```powershell
tools/python312/python.exe tools/knowledge_reader/reader.py build --repo <repo> --ref <40-hex> --expected-sha <same-40-hex> --output build/sb_reader_preview/knowledge_index.json
```

Optional draft overlay requires `--prepared-packet` and `--prepared-manifest-sha256`. The tool verifies manifest
bytes, every declared file, containment, duplicates and hashes before consuming only derived source-note/card
Markdown. Rows remain `DRAFT_NOT_IMPORTED`; machine paths are omitted.

Canonical documents come only from exact Git objects, so dirty checkout bytes do not affect the export. Missing
knowledge/registry, malformed or duplicate IDs, pin mismatch, curated symlinks, unsafe paths and packet tampering
fail closed. Git registry locators are hash-checked; external locators are `EXTERNAL_NOT_VERIFIED`.

After the source commit exists, create the file:// artifact using the same module/styles:

```powershell
tools/python312/python.exe tools/knowledge_reader/reader.py export --repo <repo> --ref <pin> --expected-sha <pin> --index build/sb_reader_preview/knowledge_index.json --output build/sb_reader_preview/READ_SECOND_BRAIN.html
```

It embeds escaped JSON, makes no fetch, executes no document content and accepts only HTTP(S) source links.
Controller may later install reviewed exports additively under
`D:\EA_LAB_CONTROL\readers\second-brain\versions\<pin>`; this contract does not install/host/schedule/activate.

## Query / EA problem packet

```powershell
tools/python312/python.exe tools/knowledge_reader/reader.py query --index build/sb_reader_preview/knowledge_index.json --question "BWD risk" --ea <name> --variant <variant> --build <id> --config <set> --symbol <symbol> --timeframe <tf> --window <from-to> --data-source <identity> --output build/sb_reader_preview/context_packet.json
```

Unknown fields stay `null`. English uses exact tokens (`EA` does not match `Seafood`); Thai uses substring.
Results carry pin, source IDs, hashes and excerpts. Negative knowledge is listed or explicit `NO_MATCH`.
No edit, test, verdict, confidence or PF grade is inferred.

## Monitor and organization

Monitor mounts the same module at `#knowledge` and loads `knowledge_index.json` independently of its operational
index. Knowledge failure is visible but cannot break other views. Preserve the four-store model and intake flow
in `knowledge/00_indexes/HOW_TO_USE_SECOND_BRAIN_TH.md`.

## V1 limits

- Keyword/title/body/topic/source search only; no semantic/vector retrieval.
- Safe Markdown subset; document HTML/scripts never execute.
- External blobs cannot be rehashed offline and remain labeled.
- Link health covers curated canonical Markdown only, not real-time health.
- Source publication/availability time remains source-defined; build time is non-authority.
