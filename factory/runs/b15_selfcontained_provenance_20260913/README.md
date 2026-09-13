# B15 self-contained provenance package

PACKAGE STATUS: worker deterministic checks PASS; independent review pending.
STRATEGY STATUS: unchanged. The original screen and exhausted salvage are not reopened.
Authority: PACKAGING_ONLY_NO_STRATEGY_AUTHORITY.

Run with Python 3.12+ and its standard library, from any directory:

```text
python -B <package>/validate.py --audit
python -B <package>/test_package.py
```

The validator reads only this package. `--audit` actively denies all external file
opens, writes, network and process calls after stdlib initialization. Pure byte
parsers are adapted from the exact canonical sources saved in
`provenance/tools/`; canonical helper files elsewhere are not imported.
The 26 checks include physical mutation/deletion in an order-owned temporary
package copy, path attacks with refreshed outer hashes, all three input maps,
relocation and a runtime I/O guard. Temporary fixtures are removed; existing
package bytes are verified unchanged.

`report_package_manifest.json` uses the canonical integrity schema and covers
every file except itself. `provenance_manifest.json` records exact copied hashes,
sizes, source paths and acquisition locators. Those historical locators are data,
never filesystem/Git dependencies. The candidate Git identity is the outer trust
anchor. An attacker replacing the validator and all manifests is outside an
unkeyed hash inventory's guarantee.

`cells.json` is the current package-local evidence map. `historical/` and the
copied historical provenance receipts retain old bytes and claims for inspection,
including unsuccessful salvage checks. Their absolute paths and old manifest
entries are historical descriptions, not current evidence references or acceptance.
The small original shared build/identity/log containers are retained solely to
check the B15 extracts; no other family's performance is interpreted.

GBPUSD/H4, MT5-lane3 / D:\Meta 5c, Model1, leverage 1:100, deposit USD10000,
Optimization=0 and ForwardMode=0 are preserved. MAIN 2023-2025: PF 0.28,
net -357.84, 13 tickets, native maximal EqDD 5.83%. BWD 2020-2022: PF 2.12,
net +137.96, 24 tickets, native maximal EqDD 6.37%. Set/INI/report = 157/157/157;
set and INI lexical values match exactly, while report numeric lexical formatting
uses the historical Decimal normalization. No input is dropped or guessed.
Canonical parser output is preserved including its existing zero defaults for
unsupported fields; those zeros are not new measurements. Headline fields are
independently contract-pinned; year/participation calculations reproduce exactly.

Four R1 SVGs are exact copied derived presentation views, source-bound by report
hash and reproduced byte-for-byte. All eight native images remain MISSING and
graph closure INCOMPLETE. L0 entry tags MAIN=5 / BWD=6 are not baskets.
Independent baskets/episodes, sample adequacy, exposure, immutable Bases history,
original launch INI path and historical loaded EX5 memory remain UNKNOWN.

`ex5_observation.json` records the single acquisition-time retained binary read.
The receipt-matched bytes are labeled PACKAGING_TIME_RETAINED_ARTIFACT_MATCH.
Later validation hashes only `raw/retained/Boss_15_ST03.ex5`. Current runtime
absence/change is irrelevant; the snapshot is not historical loaded-memory proof.
`.gitignore` narrowly exposes this evidence binary for normal Control Tower intake;
`.gitattributes` prevents Git newline conversion of exact evidence bytes.

Fresh-clone status: PENDING_COMMIT. After committing and freezing the package,
Control Tower runs:

```text
python -B <package>/test_fresh_clone.py <full-candidate-HEAD-SHA>
```

This requires a clean committed package, bundles only HEAD, creates a non-shared
clone, requires rejected object a0a3b5b13cb5b1f4b9585954b91ee89ac17f5dc2 to be
absent, then runs validation/audit and the negative tests. The fresh-clone program
is a post-commit test harness and is not imported by the final validator.

MT5_runs=0. No compile, rerun, retune, optimization, HOLDOUT, deployment or trading.
implementation_passes=1; repair_budget=0/1 (independent-review repair unused).
Worker startup tests exposed adapter initialization/serialization issues; they
were corrected during initial authoring without changing acquired evidence.
