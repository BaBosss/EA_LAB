# EA_LAB Report Visual QA Checklist V1

Status: `CANONICAL REPORT QA CHECKLIST / PRESENTATION ONLY / NO NEW AUTHORITY`

Use this after evidence/narrative correctness is already established. Visual QA cannot upgrade research evidence or override the exact contract.

## A. Evidence labels

- [ ] Every chart identifies its evidence class: native accepted, reconstructed accepted, derived diagnostic, replay visual-only, or unavailable.
- [ ] No replay or regenerated MT5 graph is presented as accepted evidence unless metrics/hash/provenance are acceptance-equivalent.
- [ ] Native floating-equity claims are not inferred from closed-deal balance reconstruction.
- [ ] Missing graphs remain visibly missing; no fabricated curve fills the gap.
- [ ] Every decision-critical figure can be traced to exact JSON/CSV/report/hash identity.

## B. Front / executive readability

- [ ] First page answers EA/config identity, status, key findings, decision and authority ceiling.
- [ ] Front graphic/page uses the target page aspect ratio; no stretched dashboard screenshot.
- [ ] No text or card is clipped, overlapped, or pushed outside page margins.
- [ ] Executive summary is understandable without reading raw parameter tables.
- [ ] The report type is explicit: `SINGLE_CONFIG` or `OPTIMIZATION`.

## C. Diagram / chart readability

- [ ] D1 workflow appears when meaningful fixed-config evidence exists.
- [ ] D2-C Risk/Position Engine appears for grid/recovery/multi-position/dynamic sizing/hedge systems.
- [ ] One chart has one primary message; avoid mixed scales that require guesswork.
- [ ] Axis/unit labels are visible; chart legends do not cover data.
- [ ] Wide diagrams/heatmaps use landscape or another dimension-safe layout.
## D. Grid / exposure visibility

For GRID/MULTI-POSITION reports:
- [ ] L1...Ln lot ladder is visible.
- [ ] Max concurrent positions/depth is visible.
- [ ] Max aggregate lots is visible.
- [ ] Grid span is visible or explicitly unavailable.
- [ ] Basket/episode/concentration evidence is visible when available.
- [ ] DD episode count / underwater duration is clearly distinguished from native floating EqDD.

## E. Document rendering

Render both the editable document and final PDF before delivery.

- [ ] No blank or accidental one-line pages.
- [ ] No orphan heading separated from its chart/table.
- [ ] Tables fit page width and remain legible.
- [ ] Embedded images are actually present after export; placeholder/linked-image failures are rejected.
- [ ] PDF and DOCX page order match.
- [ ] Page count is plausible and stable after export.
- [ ] Create a contact-sheet or page thumbnails and inspect every page visually.
- [ ] Re-open a sample of large/wide pages at full size, not only thumbnail size.

## F. Links / traceability / closeout

- [ ] External references are separated from EA_LAB evidence and labeled background/education only.
- [ ] Internal refs/paths identify exact evidence, not a stale chat snapshot.
- [ ] `Evidence -> Interpretation -> Decision` remains visually separable.
- [ ] Known Unknowns and `NOT RUN` states are visible.
- [ ] Final binary names include EA/experiment/report type/version/date or another deterministic identity.
- [ ] Superseded drafts are not presented as final outputs.

Final QA state is `PASS` only when both content and rendered presentation pass. A presentation defect is `D_EXECUTION_INCOMPLETE` for the report package, not a strategy failure.