# Second Brain — source-pinned gap audit and feedback draft V1

Status: **PROPOSED SOURCE / RESEARCH_ONLY / NOT AN INTAKE OR TEST ACCEPTANCE**.
This is a bounded consumer of the existing Second Brain Reader, not a new wiki, registry,
Experiment Memory, Factory workflow, Monitor, or autonomous research agent.

## What exists and what this adds

- Existing: `knowledge/00_indexes/SECOND_BRAIN_INDEX.md`, source registry, research cards,
  negative knowledge, exact-ref `tools/knowledge_reader/reader.py` and QI experiment owners.
- Added: `tools/knowledge_reader/gap_audit.py` produces one read-only JSON gap/feedback
  **draft** pinned to a 40-hex Git commit. It reuses the Reader's verified index and
  query packet, links relevant knowledge and negative memory, lists library health,
  and optionally verifies a single already-tracked experiment evidence file by SHA256.
- Not added: any automatic knowledge ingestion, test/run/optimization command, evidence
  mutation, second result/strategy registry, LLM interpretation, risk/grade, Monitor
  publisher, watcher or persistent service.

## Invocation

Use the clean worktree or repository with the exact locally available commit:

```powershell
python tools/knowledge_reader/gap_audit.py --repo D:\EA_LAB --ref <exact40sha> --expected-sha <same40sha> --question "Grid" --ea B17 --symbol XAUUSD --output D:\EA_LAB_CONTROL\evidence\manual_sb_gap_draft.json
```

Optional *tracked Git evidence* (all three required as a group):
`--experiment-id <id> --evidence-path docs/research/<tracked-file> --evidence-sha256 <lowercase64hex>`.
Allowed evidence roots are only `docs/memory_control/experiment_events/`,
`factory/runs/`, and `docs/research/`. Non-tracked/external receipts must
stay in their existing governed evidence owner; until independently qualified
the draft must say `NO_EVIDENCE_SUPPLIED`, **not** turn an external path into proof.

## Result vocabulary

- `RESEARCH_ONLY_DRAFT_NOT_IMPORTED` / `DRAFT_NOT_IMPORTED`: a discussion artifact,
  not canonical knowledge or an accepted Factory decision.
- `POINTER_VERIFIED_CONTENT_NOT_ADJUDICATED`: tracked bytes match the pinned hash.
  Does **not** establish correct build/config, model, tester fidelity, MAIN/BWD,
  sample quality, metrics, selection rule or a PASS verdict.
- `NO_KEYWORD_MATCH` and `NEGATIVE_MEMORY_NO_KEYWORD_MATCH`: retrieval gaps only,
  never proof that no existing experiment/failed hypothesis exists.
- Library problems are surfaced from the existing index, not silently corrected.
- `test_verdict`, `performance_grade`, and `candidate_status` remain null.
  Automatic actions always remain the empty array.

## Review-to-knowledge handoff (outside this tool)

1. An EA worker queries exact pinned Second Brain, negative knowledge and existing QI/event owners.
2. Main CT checks current Git, registry/resource owners and prerequisite research freeze.
3. Only separately authorized Harness tests produce real evidence, reports and graphs.
4. A human/qualified reviewer checks the raw receipt, source identity and contradictions.
5. Existing `ea-research-intake` may then propose a reviewed synthesis update through
   the ordinary Git/reviewer/CT path. **Never append experiment authority to `knowledge/`
   automatically**. Preserve failed experiments and rejected hypotheses.
6. Only Main CT can integrate eligible source; this draft alone is never an acceptance receipt.

## Deterministic proof

`python -m unittest tools.knowledge_reader.tests.test_gap_audit -v`
plus existing Reader/Second Brain tests and precommit gates. No MT5, Factory,
HOLDOUT, Real Submit, deployment, risk change, or LIVE action is authorized.
