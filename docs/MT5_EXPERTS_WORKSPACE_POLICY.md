# MT5 EXPERTS WORKSPACE POLICY

Owner-ratified operational policy: 2026-08-29 Asia/Bangkok.

## 1. Purpose

`MQL5\Experts` is a deployment / compile / test surface. It is **not** the canonical source archive and it is not a long-term collection folder.

Canonical EA_LAB source and durable evidence stay in the repository or another explicitly managed archive. MT5 receives only the files needed for the current compile, test, or authorized runtime purpose.

This policy does not change deployment, DEMO/LIVE, trading, risk, or owner hard-stop authority.

## 2. Reserved MT5 locations

- `Experts\EALabTpl\` — managed EA Template / Boss compile-test mirror. Write it through `ea_template\deploy.ps1`; do not manually curate individual files inside it.
- `Experts\ORDER353_EQ\` — protected ORDER-353 evidence/runtime lineage until that order is formally closed.
- `Experts\NewsGuard\` — protected project-specific surface; not a generic scratch folder.
- `Experts\Boss_14_GridLog.ex5` — managed compatibility artifact generated from the canonical `EALabTpl` build; do not manually replace or rename it.
- `Experts\EA_LAB_TEST\ORDER-<id>\...` — order-owned scratch/test surface for bounded legacy, imported, probe, or fixture work that does not belong in `EALabTpl`.

Do not place new generic EA_LAB files directly in the `Experts` root.
## 3. Canonical naming

Use the directory to express lifecycle/status. Keep the EA logical filename stable.

For new EA_LAB-authored files:

- use ASCII letters, digits, and underscores where practical;
- prefer stable logical names such as `Boss_14_GridLog`;
- Factory hypothesis/generated identities may use the accepted pattern such as `B14_H01_r1`;
- use `_revNN` only for an existing versioned lineage that already relies on that convention;
- do not create names containing `FINAL`, `NEW`, `LATEST`, `OLD`, `ORI`, `COPY`, `(1)`, random dates, or status words merely to describe workflow state;
- do not rename an accepted/current runtime or evidence identity for cosmetic cleanup. If a rename is functionally required, update every consumer and rerun impacted acceptance.

Third-party/opaque imported binaries keep their original filename in the archive/inbox. A test order may preserve that filename inside its isolated order folder rather than pretending it is an EA_LAB canonical identity.

## 4. Where new tests go

### Template / Boss / Factory path

If the source belongs to `ea_template`, use the existing managed path:

`ea_template source -> ea_template\deploy.ps1 -> Experts\EALabTpl -> compile -> tester`

Do not manually copy a second Boss binary to the `Experts` root just to test it.
### Legacy / imported / one-off probe path

Create an order-owned tree:

`Experts\EA_LAB_TEST\ORDER-<id>\<logical-or-original-name>...`

Preserve the relative include tree needed by the source. Example: if the `.mq5` contains `#include "core\Risk.mqh"`, copy the required `core\Risk.mqh` below the same order folder rather than flattening the files.

Launch the tester with the exact nested Expert path. `-AllowLegacyIdentity` is permitted only when the task explicitly classifies the run as non-green legacy/fixture evidence. Normal acceptance evidence still requires the repository's build/config identity rules.

At order close: preserve required source/evidence in canonical storage first, then remove the order-owned test mirror under the applicable cleanup authority. Do not leave completed scratch trees in `Experts` indefinitely.

## 5. File-type rules

| Type | Canonical retention | Need in `MQL5\Experts`? |
|---|---|---|
| `.mq5` | Keep canonical EA_LAB source in Git | Only when compiling/rebuilding there or when a managed deployment mirrors it |
| `.mqh` | Keep canonical headers/libraries in Git | **Yes when referenced by a `.mq5` being compiled there**; no for runtime-only use of an already-built `.ex5` |
| `.ex5` | Keep only artifacts required by current build/evidence/runtime policy | Yes for execution/test; avoid historical piles and duplicate root copies |
| `.set` | Keep accepted/reproducible config in the repo/evidence location | Usually no; `mt5_run.ps1` can consume an explicit set path |
| `.log` | Preserve only evidence that has a direct consumer | No long-term storage in `Experts`; compile/test logs are transient or belong with evidence |

An `.ex5` does not load `.mqh` files at runtime. Headers are compile-time dependencies.
## 6. External / third-party collections

Course bundles, downloaded robots, cracked/reference EAs, vendor examples, and other unrelated collections should live **outside** `MQL5\Experts` until a specific bounded test selects them.

Recommended archive root for later cleanup/migration:

`D:\EA_ARCHIVE\MT5\`

This is an organizational recommendation only; moving or deleting existing material requires the applicable bounded cleanup authorization.

## 7. Control Tower test-placement contract

Before any MT5 test, the Control Tower/worker must classify the EA:

1. `EA_TEMPLATE_MANAGED` -> use `EALabTpl` through `ea_template\deploy.ps1`.
2. `CURRENT_PROTECTED_RUNTIME_OR_EVIDENCE` -> use the already-declared protected path; do not duplicate/rename it casually.
3. `LEGACY_IMPORTED_PROBE_FIXTURE` -> use `EA_LAB_TEST\ORDER-<id>\...` and preserve required relative dependencies.
4. `THIRD_PARTY_NOT_SELECTED` -> keep outside `Experts`; do not execute merely because the file exists.

Every test contract should record the exact `Expert` path, tester lane, source/ref identity, set/config path, and whether identity is normal or explicitly legacy/non-green.

No worker may use the `Experts` root as a general scratchpad.
## 8. Existing clutter migration rule

Existing root files are not deleted merely because they violate the new layout. Classify them first as:

- `KEEP_PROTECTED` — current managed/runtime/evidence identity;
- `KEEP_CURRENT` — current test/development dependency;
- `MOVE_ARCHIVE` — useful historical or third-party material that does not belong in MT5 runtime folders;
- `DELETE_CANDIDATE` — reproducibly disposable test/log/duplicate material;
- `UNKNOWN_REVIEW` — insufficient evidence.

Migration must preserve current accepted binaries and any file still referenced by active scripts/orders. Cosmetic tidiness is never sufficient reason to break an accepted identity.