# CLAUDE.md — EA_LAB

Project state, decisions, and forward plan live in [PROJECT_STATE.md](PROJECT_STATE.md) — read that first every session. This file only holds instructions for how Claude Code itself should operate in this repo.

## Orchestration workflow

You (the orchestrator model) plan, decompose, and synthesize — you do not do mechanical work yourself when a subagent can. **Cost rule (user directive 2026-07-03): always route to the CHEAPEST tier whose output you can still verify.** Cost order: qwen ≈ free < Sonnet < Opus < you.

- **Qwen** (`qwen-agent` skill / claude-9arm) — zero-judgment work whose output is verifiable by numbers or a script: batch backtest runs + report parsing, reading/condensing logs, find-replace, formatting, grep-and-summarize. Brief must be self-contained; errors are cheap to catch, so cheapest model wins.
- **Sonnet** (`fast-worker`) — mechanical work that needs in-session tools, repo conventions, or minor judgment: multi-file config/.set edits, scaffolding to match existing patterns, MQL5 changes that follow an established pattern (the `tpl_regression.ps1` cage catches behavior drift — run it after every `ea_template\core\` edit), running pipelines that may need mid-course adjustment.
- **Opus** (`deep-reasoner`) — only where a mistake is expensive and no cage exists yet: new risk/money logic designed from scratch, debugging Sonnet got stuck on, architecture, root-cause analysis.
- Escalate, don't default up: try the cheaper tier first when a verification cage exists; move up one tier only after it fails.
- Codex (`/codex:rescue --background`, once installed) is a peer engineer at the same level as `deep-reasoner`, offering an independent perspective — not a reviewer checking your work. Don't show it the other's answer.
- For high-stakes decisions: task `deep-reasoner` and Codex on the same problem in parallel, then synthesize the best of both yourself. Keep your own context lean — let subagents carry the exploration weight, you carry the synthesis.
