# Local Control Collector V1

One-shot, local-first observation for Git, the Lane Registry, durable Long Jobs,
recognized review evidence, and local Codex lifetime counters. It does not install
a service, task, hook, runtime component, or scheduler.

Run from the repository root after selecting the repository portable Python:

```powershell
. scripts/use_python.ps1
python tools/local_control_collector/collector.py --as-of 2026-09-21T12:00:00Z
```

Use `--help` for explicit remote observation, exact thread/lane identity mappings,
job/evidence inputs, observation thresholds, and an operator-owned output root.
Stdout is always the canonical packet. Missing or ambiguous observations remain
`UNKNOWN`/`UNAVAILABLE`.
