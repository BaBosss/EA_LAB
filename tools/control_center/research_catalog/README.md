# Research Evidence Shelf v1

Direct consumer: owner / existing Control Tower inspecting research without MT5.
Read-only implementation candidate; independent CT review and intake pending.

```powershell
. ./scripts/use_python.ps1
python tools/control_center/research_catalog/catalog.py --repo . --sha <exact-pushed-SHA> --as-of 2026-09-12T12:00:00Z --out <new-outside-repo-directory>
python -m unittest discover -s tools/control_center/research_catalog -p 'test_*.py' -v
```

The output includes the existing Report V3 index/artifacts and `research_shelf.json`.
No new frontend or source registry is created. The shelf can be consumed by the
existing Monitor through a later integration seam. The caller must verify pushed
canonicality; the builder checks the exact supplied Git commit, not remote acceptance.

Only existing Report V3 extractors enroll EA records. Unsupported Factory packages
do not become evidence by discovery alone. All graph copying and package validation
go through the existing Report V3 pipeline. The internal `project_index` function
accepts its verified in-memory result; it is not an arbitrary JSON import boundary.
Each record preserves source path/hash/SHA, EA/family/variant/home/basis/model,
source-backed setup/config/parameters, separate MAIN/BWD metrics and graph states,
and an explicit missing-field list. Inventory provenance joins the enclosing
index's hashed master source on exact path and SHA.

The shelf does not rank EAs or reinterpret research verdicts. Acceptance is always
`NOT_DERIVED_BY_SHELF`. Source build IDs remain UNKNOWN when the existing Report V3
read model does not expose them; no build is inferred from a report filename.
Legacy reports without date-window or installation provenance retain those gaps.
Model2/unknown models and refused packages expose no performance through this DTO.
Metrics retain their original field names (including `eqdd_pct`, `dd_pct`, `cycles`).
Cycles do not become baskets. Existing graph hrefs remain under their verified
SHA/package/EA/role/content namespace; browser consumers must retain Report V3's
byte-hash and image-decoding checks. This adapter does not authorize a new graph UI.

`select` requires an exact EA/basis/canonical-SHA/record-hash token. Async callers
must retain the token of the current selection and discard older responses.
`comparison` refuses incomplete or unequal installation/build/model/home/window
lineage. Even matching lineage adds no verdict or comparison of its own.

Real pinned-base test: 22 records; H08 package integrity validated / review UNKNOWN,
lane3, exact changed `_16_RsiLow` parameter, two MISSING graphs. No historical
backtest, native asset regeneration or tester process was invoked.
