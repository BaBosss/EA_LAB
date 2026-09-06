# Knowledge validation tools

These offline tools close two bounded consumer seams without activating QI-2, Factory, MT5, or trading policy.

## Offline replay data qualification

```powershell
. scripts\use_python.ps1
$python = Assert-PortablePython -Root $PWD
& $python tools\knowledge_validation\offline_replay_validator.py --input <package.json>
```

The input schema is `ea_lab_offline_replay_package/1`. It requires a dataset/version, source snapshot SHA-256, explicit coverage interval/state, versioned clock mapping, decision time, and revision records with `available_at_utc`. Output selects only records known at the decision time. `QUALIFIED_*` means data/time contract only; it never means historical coverage, EA replay, strategy benefit, or a trading policy is qualified.

Exit codes: `0` qualified data package, `1` refused package, `2` unreadable/invalid JSON input.

## Research handoff validation

```powershell
& $python tools\knowledge_validation\research_handoff_validator.py `
  --repo $PWD `
  --input knowledge\11_readiness_evals\SECOND_BRAIN_READINESS_HANDOFF_EXACT749.json
```

The validator reads citations from the handoff's exact Git commit, checks anchors and registered `source_id` values, requires contradictions, negative memory, abstentions, required semantics, and a research-only next action for all six questions. Unknown or semantics-required fields block execution readiness. It never writes strategy, hypothesis, experiment, event, verdict, or deployment stores.

Exit codes: `0` valid research-only handoff, `1` refused handoff, `2` unreadable/invalid JSON input. A `PASS` proves source binding and structural completeness; it does not prove that a human/model interpretation is semantically correct.

Run focused checks with `powershell -File scripts\_test\run_knowledge_validation_tests.ps1 -RepoRoot <root>`.
