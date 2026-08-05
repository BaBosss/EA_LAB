# Codex blind audit brief — Factory OS slice **S6** (preset compiler + effective-config fingerprint)

> Written 2026-08-03 by lane `S-2026-08-03-AUDITCOV`. **You are the independent brain.**
>
> This slice's built code has **never been independently audited**. Nothing here tells you what any
> previous session concluded, deliberately. Attack the claims; do not restate them.

---

## 0. Read at a PINNED commit · READ-ONLY

```bash
git show a87f7448:<path>
```

Do not edit, create, stage or commit anything. Do not write to `ea_template/`, `_mt5_auto/`,
`factory/` or `.git/`. **Do not launch an MT5 terminal.** Your deliverable is a report on stdout.

## 1. What you are auditing, in one sentence

The compiler that turns a pinned configuration into a `.set` file, under one rule — **full surface
or nothing** — plus the fingerprint that is supposed to make "same hash ⇒ same configuration" true.

**The stake, measured before the module was written:** of **2,177** tracked `.set` files, **zero**
carry the build's full input surface; median 14 keys, max 134. Every unlisted input is filled at run
time from the **per-terminal tester cache**. So a partial `.set` is not a smaller preset — it is a
preset with an unknown remainder, and two terminals disagree about what it means. That mechanism is
the documented root cause of a measured 8/8 false drift in this repo. If this compiler's full-surface
rule or its fingerprint has a hole, backtest results stop being comparable and nothing announces it.

## 2. Read these, in this order

| | |
|---|---|
| `_triage/EA_LAB_FACTORY_OS_DESIGN.md` | **§5.7** (preset compiler) · **§5.6** (effective configuration fingerprint) · **§5.3–5.4** (allowlist, locked/inactive declaration) · **§10** the **S6** row |
| `_triage/factory_os/CONTRACTS.md` | `Preset` and anything it references |
| `_triage/factory_os/TIER_SNAPSHOT_DESIGN.md` | §2 / §3.3 — the LIBRARY category, and why a library that defaults its evidence source becomes a second decider of which bytes count |
| `AGENT_TASKBOARD.md` | row **`ORDER-700`** |

## 3. The artifacts

| file | what it decides |
|---|---|
| `_triage/factory_os/preset.py` | the compiler, `render_value` canonicalisation, `Surface` and its enum table, the two refusal kinds |
| `_triage/factory_os/gen_default_preset.py` | the generator |
| `_triage/factory_os/run_preset_tests.py` | the cage |
| `_triage/factory_os/evidence.py` | the `EvidenceSource` this module is handed rather than opens |

## 4. The claims — refute these

| # | claim | where |
|---|---|---|
| C1 | **full surface or nothing** — a partial set is refused, not emitted smaller | the emit path |
| C2 | an **unknown key is refused** (design §10's acceptance) | `render_value` / the key check |
| C3 | the emitted `.set` is **deterministic** — same request, same bytes | the emit path |
| C4 | **"must not read the terminal cache" is structural, not promised** — this module opens no path of its own; the caller hands it an `EvidenceSource` | the LIBRARY category claim |
| C5 | `PresetRefusal` (a verdict about the request) and `ToolFailure` (a reader could not answer) are **kept apart on purpose**, because collapsing them makes *"I could not read it"* look like *"there was nothing there"* | the two exception types |
| C6 | **canonicalisation means a hash difference is a CONFIG difference and never a spelling difference** — `300`, `300.0` and `3e2` are one value through one function | `render_value`, the fingerprint |
| C7 | it **does not judge the 2,177 existing files** — it refuses only what it emits, deliberately, because a guard that refuses valid work is the one that gets switched off | the scope statement |

## 5. Where to aim

1. **C6 is the highest-value target and it cuts both ways.** Find two *different* configurations
   with the *same* fingerprint (a collision — evidence silently shared between them), and one
   configuration with *two* fingerprints (a spurious difference — cached evidence never reused).
   Attack through: numeric spellings beyond the three named, string vs numeric enum members,
   booleans, negative zero, precision loss on large or fractional values, key ordering, trailing
   whitespace, and case.
2. **C1's "full surface" is only as good as its idea of *the* surface.** Where does the compiler
   learn how many inputs the build has? If that comes from a generated file, what happens when the
   build changes and the file does not — does the compiler refuse, or emit a "full" surface that is
   now short? A full-surface claim measured against a stale surface is the original defect wearing
   the fix's name.
3. **C4 is a structural claim, so test it structurally.** Grep the module for every file-opening
   primitive and every import that can open one, transitively. One direct read defeats it.
4. **C5's separation.** Find the path where a `ToolFailure` is caught and turned into a refusal, or
   where a refusal is reported in a way a caller would read as "nothing to do". Check the CLI exit
   codes: do the two kinds actually land on different codes, and does every caller distinguish them?
5. **C3's determinism.** Is it determinism of *content* or of *bytes*? Line endings, encoding, BOM,
   float formatting, and dict iteration order are each a way for content-determinism to be claimed
   while bytes differ. This repo has already lost a suite to a stray UTF-8 BOM in a generated file.
6. **`Surface` carrying its enum table.** An enum table is a hand-written mapping. Is it derived
   from anything, or is it a second copy of a truth that lives in MQL5 source? If a symbol is added
   to the EA and not here, what happens — a refusal, or a silently wrong render?
7. **C7's scope limit is a good decision that creates a real gap.** Nothing refuses the 2,177
   partial files. So what stops a partial `.set` from being used *as evidence* elsewhere in the
   pipeline? Follow the consumers. If the answer is "nothing", that is a finding about the system
   even though it is not a defect in this module — file it as exactly that.
8. **The refusal set.** For every refusal this module can raise, construct the input. Any that
   cannot be constructed is decoration; any refusal path that returns something outside the declared
   set is worse.

## 6. How to reproduce

```bash
tools/python312/python.exe _triage/factory_os/run_preset_tests.py
```
```bash
tools/python312/python.exe _triage/factory_os/preset.py --self-test
```

⚠️ Two suites unrelated to S6 (`run_s2a_gate` F2, `check_coverage_transfer` A8) are **known red at
this pin** for a reason already recorded elsewhere. Not your finding.

## 7. What a finding must contain

`file:line` · the configuration or input that exposes it · the consequence stated as *which two runs
become wrongly comparable* or *which run's evidence is silently unrepeatable* · and a reproducing
command where you can produce one.

Rank by severity, and keep **"two configs share a fingerprint"** separate from **"one config has
two"** — the first corrupts evidence, the second only wastes it.
