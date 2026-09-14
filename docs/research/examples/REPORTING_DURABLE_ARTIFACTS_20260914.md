# Reporting Standard V1 — Durable Artifact Closeout 2026-09-14

Status: `REPORTING_ONLY / EXTERNAL_DURABLE_ARTIFACTS / VISUAL_QA_PASS / NO_NEW_AUTHORITY`.
Canonical source ref for this closeout: `758ff8006346df9a6370ffa7636519a4eff1c854`.

The reusable reporting profiles remain the canonical design owners. Generated DOCX/PDF files are retained outside Git under `D:\EA_LAB_CONTROL\evidence\reporting-standard-v1-20260914\`; Git stores only this reference and the machine-readable manifest. This follows the repository precedent of keeping generated binaries out of canonical source history while retaining exact SHA256/byte identities.

## Accepted durable presentation artifacts

- `final/EA_LAB_B16_USDJPY_H1_R4_OWNER_DOSSIER_VISUAL_V4_FINAL_20260914.docx` — editable Single-Config owner dossier.
- `final/EA_LAB_B16_USDJPY_H1_R4_OWNER_DOSSIER_VISUAL_V4_FINAL_20260914.pdf` — owner-delivery PDF.
- `final/EA_LAB_OPTIMIZATION_REPORT_TEMPLATE_V1.docx` — editable Optimization report template.
- `final/EA_LAB_OPTIMIZATION_REPORT_TEMPLATE_V1_QA.pdf` — render-only QA companion for the template, not a separate canonical report type.

Visual QA inspected every rendered page after the image-width/table-fit repair: dossier `9/9`, optimization template `3/3`. No blank page, clipping, glyph corruption, or table overflow remained. The dossier explicitly keeps accepted native equity/Graph-tab imagery `UNAVAILABLE` rather than substituting replay evidence.

## Source and authority boundary

The dossier is a presentation of existing accepted B16 R4, Episode-unit and Swap-credit evidence only. It creates no strategy verdict, optimization permission, HOLDOUT use, Grade/KINT, Candidate, DEMO/LIVE, runtime, deployment, trading, or risk/default authority. The Optimization template preserves the mandatory R3 visual pack and the rule that BWD/HOLDOUT are not optimizer surfaces.

## Reproduction and supersession

External generator SHA256: `e79d6d3e16ab5a222b37aabb8f218b2d26913630c40e19ed7c9b4d210ea68e9f`; Word conversion helper SHA256: `4f41b24e1350155f00675f3a6ed76d1c9f64addf2e8a66787afe73ae9e971c86`. A fresh reproduction on the pinned canonical source produced the same 9/3 page counts. All nine dossier pages render byte-identically when rendered with the same Poppler settings. The Optimization template has identical normalized full-document text and the same three-page count; Word moves a BWD table row across the page-2/page-3 boundary between exports, so binary/page-pixel equality is not claimed.

The older V1 and V3 PDFs are preserved under `superseded/`. V3 is not promoted: its earlier QA exposed presentation defects and its exact matching V3 editable DOCX was not recovered. Exact hashes, source-owner pins and QA/reproduction facts are in `portfolio/REPORTING_STANDARD_V1_DURABLE_ARTIFACTS_20260914.json`.
