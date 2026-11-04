# Custom EA Intake V1 — offline source / preset / research-reference adapter

**Status: COMMITTED WORKER SOURCE CANDIDATE ONLY; CT review/integration outstanding.**
Authority: read-only file catalog and hash checks. **Not** an alternative Strategy Registry, EA Template, Builder, Factory, Monitor, optimization runner or deployment authority. This tool never runs MT4/MT5, compiles an EA, changes an account/magic/risk default, publishes runtime data, issues verdicts, or touches HOLDOUT.

## Real source scope and intended landing zone

Source corpus: `D:\EA_LAB\my_custom_eas\`. Existing six-digit external hash facts come from original files, not a Git commit: the user's older raw corpus was intentionally untracked (~386 MB). Existing `ea_projects/` folders are **external references, not moved**. Do not `git add my_custom_eas/` in bulk. Preserve historical source revisions, EX4/EX5, SETs, rejected models and unknown source licensing.

This worker provides three CLI surfaces, using Python 3.12 standard library. It writes only explicitly requested outputs:

```powershell
$Tool = "D:\EA_LAB_CONTROL\w\ct-custom-ea-intake-v1-20261015\tools\custom_ea_intake"
python "$Tool\intake.py" scan `
  --root "D:\EA_LAB\my_custom_eas" `
  --legacy-index "D:\EA_LAB\my_custom_eas\CUSTOM_EA_INDEX.csv" `
  --projects "D:\EA_LAB\ea_projects" `
  --out "D:\EA_LAB_CONTROL\evidence\ct-custom-ea-intake-v1-20261015\scan_NEXT"
python "$Tool\intake.py" draft --input "OWNER_EXPORTED_BUILDER_DRAFT.json" --out "OUTPUT_DRAFT_REF.json"
python "$Tool\intake.py" init --root "D:\EA_LAB\my_custom_eas" --strategy-id "RSI_MR_001"
python -m unittest discover -s "$Tool\tests" -p "test_*.py" -v
```

- `scan` reads source/binary/Preset bytes to compute SHA256, catalogs physical files, identifies *identical bytes* (not identical strategy), checks old 98-row CSV mappings without changing it, reads all .set parameters including MT5 `value||start||step||stop||Y/N` fields, sanitizes credential-named values, references 63 external projects by path and gives an **unverified-only** research projection. It refuses a pre-existing output and cannot put output inside the corpus or project trees. Audit files from prior scans physically present inside the corpus are counted and separately labelled `prior_audit_files`; they are not a new EA.
- `draft` imports only an offline M1 `LOCAL_DRAFT_UNVERIFIED`, `ENTRY_ONLY` JSON with every plan disabled. It emits a source-hashed **DRAFT_NOT_SUBMITTED** reference, with `can_submit=false` and `can_execute=false`. This is not a Builder UI change. No parameter defaults, contract approval or catalog binding are inferred.
- `init` is an **explicit local scaffolding command** for *new* EA StrategyIDs, creating `06_Template_Converted/<StrategyID>/{origin,spec,src,presets,runs,reports}` and `links.json`. All mechanics, Factory approval, broker, magic, risk, preset and run/report references begin null/empty. It refuses an existing target and invalid IDs. Do NOT run this automatically on the historical corpus.

## Scan output / single-fact ownership

| Output | Source-bound meaning |
|---|---|
| `SOURCE_FILES.csv` | Every file's relative path, byte count, SHA256, kind; physical file facts only |
| `LEGACY_CROSSWALK.csv` | Every original catalog row, scoped candidate files, unresolved reasons and proposed chassis text only |
| `EXACT_DUPLICATE_BYTES.csv` | Duplicate byte hashes; absolutely no semantic dedupe |
| `PRESETS.csv`, `PRESET_PARAMETERS.csv` | Raw .set names, values and optimizer lattice; binding is always UNRESOLVED |
| `EXTERNAL_PROJECTS.csv` | Unmoved old project directory references, no new canonical EA IDs |
| `INTAKE_SUMMARY.json` | Counts, failures, scope, explicit missing acceptance gates |
| `RESEARCH_MONITOR_PROJECTION_DRAFT.json` | **Unpublished** draft projection; strategy/build/run/report links null; never feed this as Live status |

All provisional IDs are `CAND-...` **NOT** approved StrategyID/FamilyID/VariantID. For AI bot index rows with generic `02_AI_Generated_Bots` path, do not silently assign one of its binary files; the entire mapping remains `UNRESOLVED_BROAD_FOLDER`. Manual source/semantic review and identity acceptance is required before Entry conversion.

## Native run/report integrity link (separate opt-in command)

```powershell
python "$Tool\run_binding.py" --manifest "EXACT_RUN_EVIDENCE_MANIFEST.json" --out "RUN_REFERENCE_UNREVIEWED.json"
```

Input JSON schema: `EA_LAB_RUN_EVIDENCE_INPUT_V1`. Required nonblank strings:
`strategy_id`, `variant_id`, `build_id`, `run_id`, `symbol`, `timeframe`, `tester_model`, `window_start`, `window_end`; `stage` is one of MODEL1/MODEL4/OPTIMIZATION/BWD/OOS/HOLDOUT. Required `artifacts` entries each have an absolute `path` and exact `sha256`: `source`, `compiled_ea`, `preset`, `native_report`, `native_graph`. Optional entries follow same structure: `optimizer_xml`, `report_markdown`, `report_pdf`, `deal_ledger`. A run must be **already authorized and completed** before making this manifest. This tool simply rehashes and validates file existence, refuses tampering, and emits an `UNREVIEWED` reference with null performance and no upload/publishing. Source/EX5/preset hash verification does **not** prove native process/tester/build/data quality, complete graph semantics or acceptance.

Backtest/report authority is owned by `docs/research/EA_REPORT_SCHEMA.md` and `docs/research/EA_REPORT_LADDER.md`. Respect stage-specific plot requirements (R1 heatmap and participation; R2 selected equity/DD; R3 optimization surface; full Candidate pack), with actual native graph vs reconstructed chart distinguished. MT5 real test identity and scientific acceptance remain in the CT Harness/research contract. This tool is intentionally unable to issue native results, performance grades or a DEMO/LIVE promotion.

Existing single central Monitor/owner WebApp has separate source and runtime/publisher owners. The projection is an **adapter candidate**, not a second Monitor or an update to `MONITOR_HUB.html`. The CT must review the proper source adapter, preserve UNKNOWN for stale/absent data, and independently accept authenticated/runtime publication before any display claims.

## Gating for CT merge

1. Confirm fresh `origin/master == git ls-remote`, no unrelated source overlap, incumbent author/Registry admission, clean isolated branch HEAD and changed paths.
2. Execute Python positive/negative suite and physical census against the same source corpus and compare to older Audit (original 1,148 files plus generated audit files). Verify no source changes.
3. Review source/hashes, path/secret handling, unsafe JSON, duplicate and output overwrite cases; independent exact-HEAD scrutiny required under the current task contract.
4. After CT-only verified integration, CT may authorize a separate read-only UI adapter intake. **Do not make this tool itself the monitor publisher or Factory author.**
5. A separate owner-scoped T3 permit is needed for native MT5, HOLDOUT, real Submit, Factory, publisher runtime switch, or trading.
