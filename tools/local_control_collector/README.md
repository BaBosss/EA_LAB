# Local Control Collector V1

One-shot, local-first observation for Git, the Lane Registry, durable Long Jobs,
recognized review evidence, and local Codex lifetime counters. It does not install
a service, task, hook, runtime component, or scheduler.

Run from the repository root after selecting the repository portable Python:

```powershell
. scripts/use_python.ps1
python tools/local_control_collector/collector.py --as-of 2026-09-21T12:00:00Z
```

Routine Registry collection reads every lane JSON once without invoking the Registry
script. Stdout is a compact route packet: active lanes plus explicitly focused/current lanes, and at most 30 Codex thread rows selected deterministically from recent focus/current identities, top valid deltas, recent exact-mapped active-lane threads, and a recent fallback. Historical exact mappings do not bypass this hard route bound. Counts still cover every valid lane and every observed thread.

Use repeated `--focus-lane`, `--current-lane`, or exact `--thread-identity` inputs for
routing focus. `--deep-registry-audit` opts into one canonical Audit call (never a Get
loop). `--full-detail` emits every valid Registry and Codex row to stdout. When an
external `--output-root` is supplied, the full observation is durably create-only
there even though stdout remains compact. Missing or ambiguous observations remain
`UNKNOWN`/`UNAVAILABLE`.
