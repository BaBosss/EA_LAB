# EA Research Workbook V1

Status: `SOURCE_ACCEPTED_REVIEWED_REPO_ONLY_NOT_DEPLOYED / PLANNING_PRESENTATION_ONLY`

The Research Workbook is one owner-editable planning document inside the existing Mobile Report Hub. It does not execute a tester, create an executable `.set`, change canonical research evidence, approve a stage, unlock HOLDOUT, deploy an EA, or attest an owner decision.

## Entry and ownership

- Open the existing Monitor and choose **EA Lab → Open Research Workbook**, or navigate to `#research`.
- The active bottom tab remains EA Lab; this is not a sixth dashboard.
- Canonical Monitor data remains read-only. The workbook is stored only in the current browser under the `ea_lab.research_workbook.v1.*` namespace.
- The blank template selects no EA, parent, Home, strategy, range, result, threshold, risk default, or verdict.
- A downloaded workbook is a planning artifact. Cross-device/cloud synchronization is not provided.

## Content model

The lossless JSON document contains:

1. campaign/revision and exact family/EA/variant/parent/source/build/config identity;
2. hypothesis, observation, benefit/cost, objective, falsifier, constraints, negative history, provenance and direct consumer;
3. separate BUY/SELL, indicator/timing/finality, entry, position/grid/stack, sizing, recovery/hedge, exit and safety semantics plus a source-labelled flow;
4. a full typed parameter inventory with source defaults, proposed baselines, fixed/search state, dependencies and hypothesis-specific range/enum plans;
5. explicit logical/broker Symbol + TF rows, proposed Home/discovery roles, editable DRAFT tester/environment assumptions and MAIN/BWD/HOLDOUT roles;
6. multiple named MAIN-only optimizer-set plans covering coarse, region, refine, neighbours, locked center and sensitivity stages without producing commands or executable sets;
7. one-change filter/module and explicit interaction plans, with risk/hedge/recovery changes kept owner-reserved;
8. a roadmap of declarations, dependencies, entry/exit gates, expected results, falsifiers, outputs, execution state and acceptance state—never a dispatch queue;
9. an owner-entered `UNVERIFIED` result ledger, typed native/reconstructed time series, sensitivity inputs, published-evidence references and existing Monitor detail links;
10. source-qualified empty-state graphs and a printable report with observations, interpretations, decisions, missing gates, limitations and next action kept separate.

## Persistence and revision rules

Edits use debounced local autosave; an explicit Save remains available. Partial rows and temporarily incomplete ranges are preserved as drafts instead of being silently reset. Edits remain in memory when storage is denied. Corrupt stored bytes are preserved and never silently overwritten; the blank in-memory fallback remains editable and downloadable. Import is parsed and validated before replacing the in-memory draft; duplicate keys, dangerous prototype keys, oversize documents, unsupported schemas, unsafe evidence links and authority-forging values are refused.

**New revision** first writes the complete previous draft to an immutable history key. If that key already exists or storage cannot preserve it, revision creation stops. It never overwrites frozen local history. Download before revising when browser storage is unavailable.

The Monitor's 60-second/online/offline refresh updates only the workbook's Monitor-truth token while the route is open. It does not rebuild the form, discard unsaved data or move focus.

## Validation and graph rules

- Structural validation is not source-hash recomputation, evidence verification, approval or readiness.
- Every supplied SHA256 is exactly 64 hex characters even when its locator is blank. Normalized locator conflicts are checked globally within the same artifact kind, while source and built-binary bindings remain deliberately separate. Canonical 40-hex refs are references, never accepted in SHA256 fields.
- Repeated locator/hash conflicts, invalid ranges/counts, missing optimizer parameter references, non-finite/boolean numeric values, malformed UTC series points, forged verification, BWD/HOLDOUT search and unsafe links fail visibly.
- Profit factor is `gross_profit / abs(gross_loss)`; zero loss is `UNDEFINED_ZERO_LOSS`, never zero or infinity. PF is never averaged.
- Descriptive comparison requires matching installation lineage, data, symbol, TF, model, window, currency, source and build identity. Otherwise it is visibly `INCOMPARABLE`; no winner is selected.
- Named optimizer plans show a prospective inclusive Cartesian estimate only when all selected range/enum axes are determinate; `UNKNOWN` never becomes an invented pass count, and genetic execution is not predicted.
- Graph selectors expose one compatible result group, metric, series/scale group and sensitivity group at a time. Currency equity/balance and percent DD never share a scale; run/lineage/source/kind/unit labels remain visible, timestamps use proportional UTC spacing, and all imported/manual points remain `UNVERIFIED`. Missing or incompatible groups stay `UNAVAILABLE`; net profit is never reconstructed and presented as native equity.
- User-entered result rows remain `OWNER_ENTERED_UNVERIFIED`. Existing published records open through the unchanged `#detail/<id>` route and native report/graph renderer.

## Security and authority ceiling

The module uses no dynamic code execution, remote scripts, backend, runner, shell/command export, arbitrary link navigation, credential fields or server/Git write. Dynamic values are HTML-escaped. Spreadsheet-leading formula characters are neutralized by the exported helper if a future reviewed table export uses it; V1 exports the complete typed JSON workbook only.

`Copy review request` produces plain local clipboard text and explicitly states that the request is not an attestation. `Printable report` regenerates a wrapped text projection of every field, row and table plus current charts/diagnostics, then invokes the browser print dialog; form-control clipping is not used as the report and no PDF engine is added.

## Repair 1/1 status

The original bounded repair and earlier owner-supplemental corrections remain preserved as spent historical evidence. The first exact-head GPT Scrutiny failed HIGH on revision-ID collisions, zero-loss PF handling, and invalid graph provenance. The first bounded correction closed the revision and graph findings; the next exact-head recheck failed HIGH only on a narrower `WB-METRIC-001` case where gross profit was unavailable but gross loss was exactly zero and a PF was supplied. Under Boss's explicit instruction to finish those findings, the final same-finding correction now detects zero loss before gross-profit availability, refuses supplied PF whenever PF cannot be numerically derived, prevents invalid exports from reimporting as valid, and prints explicit `UNDEFINED_ZERO_LOSS` / invalid-PF status. Focused checks pass 93/93; the updated Workbook rendered flow and existing Monitor regression pass. Final independent exact-head GPT Scrutiny returned `SCRUTINY_PASS / HIGH / ALLOW_SOURCE_ONLY_INTEGRATION` at `ce5f057c1f5472a686fb1e9006551a9e402c617b`; it explicitly confirmed all three findings closed and no directly related material regression.

Source acceptance is complete; this documentation records the accepted state for normal FF repository integration only. Production Monitor publishing has not been performed. The accepted source remains a planning/presentation workbook, not a research result, optimization executor, performance claim, risk/default policy, HOLDOUT permission, Candidate/Grade/KINT decision, runtime deployment, DEMO/LIVE or trading action, or owner signature.

## Exact acceptance evidence

- Accepted source: `ce5f057c1f5472a686fb1e9006551a9e402c617b`.
- Final source review: `D:\EA_LAB_CONTROL\evidence\ct-ea-research-workbook-review3-ro-20260919\REVIEW_RESULT.json`; SHA256 `6217064a8a355d21b0bf97b5192ead2ca5e56c8aeca7fe30165f8687c4c5d7a9`; `SCRUTINY_PASS / HIGH`.
- Frozen manifest: same directory `EVIDENCE_MANIFEST.json`; SHA256 `d61d9bce144d467f872b64607ee44fe116a3f6e115bfa2017ff1c58548562ad8`; binds 13 source files and 20 final evidence files.
- Final reviewer job: `ct-ea-research-workbook-review3-ro-20260-20260919T122320Z-944fe954`; terminal `COMPLETE`, exit/postcondition 0. Runner completion alone is not acceptance; the explicit review verdict controls.
- Existing initial failure and narrower PF recheck failure remain in their original evidence roots. No other exhausted package is reopened.
- Use the accepted Monitor source/isolated preview via `EA Lab -> Open Research Workbook` or `#research`. Older running/hosted Monitor versions do not acquire this feature merely because source is accepted. Drafts and saved revisions are local to the current browser; use Download plan/Import plan to transfer them.
