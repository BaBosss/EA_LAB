# EA Research Workbook V1

Status: `REPAIRED_PENDING_CT_RENDERED_GATES_AND_INDEPENDENT_REVIEW / REPO_ONLY / PLANNING_PRESENTATION_ONLY`

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

The sole bounded source repair closes the pure/static defects and strengthens the rendered harness for blank/populated 390x844 and 1280x900 layouts, autosave/reload, corrupt/denied storage, late async navigation, grouped graphs and complete print content. The authored browser harness still requires the separately authorized Control Tower Playwright-core + Edge execution. Exact-head independent GPT Scrutiny remains mandatory after those rendered gates; no acceptance is claimed here and no further author repair budget remains.

Independent exact-head GPT Scrutiny and Control Tower integration remain required. This implementation grants no research result, optimization execution, performance, risk/default, HOLDOUT, Candidate/Grade/KINT, runtime, deployment, DEMO/LIVE, trading, owner-signature or production-hosting authority.
