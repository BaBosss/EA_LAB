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
tools/python312/python.exe tools/knowledge_reader/reader.py query --repo <repo> --ref <pin> --expected-sha <pin> --index build/sb_reader_preview/knowledge_index.json --question "BWD risk" --ea <name> --variant <variant> --build <id> --config <set> --symbol <symbol> --timeframe <tf> --window <from-to> --data-source <identity> --output build/sb_reader_preview/context_packet.json
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

## Repair1 provenance boundary (SBR-001..005)

Build reconstructs allowed exact Git objects and explicitly expected draft-manifest bytes. It emits
`knowledge_index.json` and `knowledge_binding.js` together. The binding is generated with trusted application
assets; it is not a signature, an internet attestation, or authority supplied by document prose. Deploy/copy
both through the same verified artifact manifest. If an attacker can replace the application/binding itself,
this local reader cannot authenticate that replacement; the operator must verify the delivered artifacts.

Export and query do NOT trust a JSON pin alone. Both require `--repo --ref --expected-sha` and reconstruct
all content against the exact sources again. When the index includes drafts, both also require the same
`--prepared-packet --prepared-manifest-sha256` pair. Any body/path/ID/authority or other substantive drift
refuses. Only the export-generation timestamp may differ because reconstruction is a fresh local observation.

Browser loading requires the generated binding digest and matches it to the complete canonical JSON data.
The Monitor view additionally requires the validated Monitor pin; missing/malformed report index fails visibly.
Offline HTML has a binding embedded by the source-revalidating exporter and remains independent of Monitor.
Query packet functions require verified, unmodified data. A blank question is refused, even though empty search
may still browse the library. No-match is not proof that no historical experiment exists.

Primary `source_ids` are declared source_id metadata or exact registry-locator ownership, never regex matches
inside prose/filenames. Other mentioned sources are not silently assigned as the document's primary source.
The prepared input root and its lexical ancestors are checked for symlink/junctions BEFORE resolving or reading
its manifest; all declared file paths are guarded separately. No source intake approval follows.
