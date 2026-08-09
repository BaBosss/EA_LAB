# Codex blind audit — Factory OS slice **S6** (preset compiler + effective-config fingerprint) — 2026-08-03

> Dispatched by lane `S-2026-08-03-AUDITCOV`, **pinned at `a87f7448`**, blind and read-only.
> Brief: [`CODEX_S6_AUDIT_BRIEF.md`](CODEX_S6_AUDIT_BRIEF.md), committed at `aeb67885` **before** the
> audit ran. First independent audit of this slice's built code. No MT5 was launched.

**The brief asked for the fingerprint to be attacked in both directions — two configurations sharing
one hash, and one configuration with two. The audit found both, three times over.**

---

## Part 1 — the findings, with this seat's verification status marked per item

Codex ran and reported observed output for most of these. This seat re-measured what was cheap and
marks the rest honestly; nothing below is presented as measured by me when it was not.

### 1.1 🔴 CRITICAL — USD and **cent** configurations share both the `.set` bytes and the fingerprint

`preset.py:481-507` · `:638-657` · `scheduler.py:81-83` · `CONTRACTS.md:382-395`

The compiler validates account unit as **semantically significant** and the fingerprint **deliberately
excludes it**. `ExecutionKey` has no account-unit field either.

```
USD account:  BasketMoney=50  declared `usd`
cent account: BasketMoney=50  declared `cent`
-> same_set_bytes=True   same_hash=True
```

$50 and 50 cents. Two economically different runs can agree on expert, deposit, currency, leverage,
set hash, EX5 hash, lane, data fingerprint **and** effective-config hash, so cached USD evidence
satisfies a cent request.

**🔴 And the cage asserts the exclusion** — `run_preset_tests.py:296-300`. This is the same trap S11's
audit found at `run_s11_tests.py:802`: **the test pins the defect in place**, so a corrections session
that fixes the fingerprint will meet a red cage and must change it in the same commit rather than
revert. *(Codex-reported; not re-measured here — `preset.py` imports cleanly for this seat, so it is
cheap to settle and should be settled first.)*

This lands directly on this project's `cent-scalp` portfolio work, where cent accounts are a real
deployment class and not a hypothetical.

### 1.2 🟠 HIGH — distinct `long` values collide through float precision

`preset.py:329-332` · `:346-350`

Any numeric spelling containing an exponent goes through `float`, **including values typed `long` in
MQL**. Above 2^53 precision is gone:

```
Magic=9007199254740992e0
Magic=9007199254740993e0
-> both render 9007199254740992, same fingerprint
```

**Magic numbers are exactly the values this repo must never conflate** — `magic.py` exists because a
reused magic silently re-attributes historical deals. Codex reports the same coercion at `:556-561`
making two differing same-layer rows compare equal.

### 1.3 🟠 HIGH — the planned `sinput` safety fields are silently outside the "full" surface

`preset.py:73-76` · `:220-236` vs design **§5.4 (L610-624)**, which explicitly assigns safety
parameters to `sinput`.

The parser recognises only `input`. Given a source with `input int A` and `sinput bool Safety`, the
compiler reports a **one-key surface**, emits it as *"full"*, fingerprints it, and **neither refuses
nor names the missing safety field**.

This is the stale-surface case the S6 brief predicted under aim-point #2: *"a full-surface claim
measured against a stale surface is the original defect wearing the fix's name."* It is latent today
and arms itself the moment the design's own `sinput` conversion lands — at which point Run A with
cached `Safety=true` and Run B with `Safety=false` share one set and one fingerprint.

### 1.4 🟠 HIGH — compilation ignores the enum table `Surface` carries

`preset.py:241-250` · `:426-436` · `gen_default_preset.py:55-73`

`parse_surface` attaches an enum table derived from the same bytes it read; `compile_preset` **ignores
it** and accepts a separately supplied one, which the generator obtains by **re-reading `Inputs.mqh`**.
Two reads, two vintages:

```
surface table: Mode=0   second table: Mode=1
unchanged symbolic request `Mode=OFF`  ->  hashes_equal=False
```

One pinned symbolic configuration with **two** fingerprints — it cannot reproduce its own cached
evidence — and the corrupted run becomes comparable to an intentional numeric-1 run. This is the
mixed-vintage shape the `S13SCHEMA` lane hit in its own A3 checker the same week.

### 1.5 🟡 MEDIUM — declaration order gives one configuration two fingerprints

`preset.py:548-553` · `:653-657` — inputs are hashed in **source declaration order**, not canonical
key order:

```
{A=1, B=2} declared A,B  vs  declared B,A
-> same_mapping=True   hashes_equal=False
```

A semantically inert source reorder makes existing evidence look unrelated. Directly contradicts C6's
*"a hash difference is a CONFIG difference and never a spelling difference"* — declaration order is
spelling.

### 1.6 🟡 MEDIUM — `ToolFailure` and `PresetRefusal` collapse at the CLI boundary

`gen_default_preset.py:107-111` · `evidence.py:41-42` · `parity_run.ps1:124-135` ·
`pilot_cells.ps1:133-136`

The generator catches both and returns `1`, though the evidence contract requires **2** for tool
failure and **1** for request refusal; callers then label every non-zero *"refused"*.

This is precisely what `preset.py`'s own docstring says it keeps apart, and names the reason:
*"Collapsing them is how 'I could not read it' starts looking like 'there was nothing there'."*
**The module is right and its CLI undoes it.** A valid run blocked by a transient reader failure is
classified like a permanently invalid configuration and is not retried.

### 1.7 🟡 MEDIUM — the declared refusal set leaks raw Python exceptions

`preset.py:331-350` · `:359-364` — `_is_number` accepts non-finite/overflowing floats; converting to
int then raises an uncaught `ValueError`/`OverflowError`, outside `{PresetRefusal, ToolFailure}`.
Input `1e9999` or `nan` on a `long` exits through an unclassified traceback.

### 1.8 🔴 CRITICAL — partial presets still enter runs, and a one-key parameter map passes candidate validation

`scripts/mt5_run.ps1:98-110` · `scripts/mt5_optimize.ps1:65-69` · `candidate.py:254-257`

**This is the finding that reaches outside S6.** The compiler's *full surface or nothing* rule governs
**what it emits**, exactly as designed (C7) — and both MT5 runners accept **any** existing `.set`,
including a single-assignment one. `mt5_run.ps1`'s warning fires only when **no** file is supplied.

Codex then followed it one step further than the brief asked, into S10:

```
payload['parameters'] = {'OnlyOneKey': 1}
candidate.validate_payload(payload) -> []
```

`candidate.py`'s C7 refuses only an **empty** dict while its message claims *"parameters must be the
FULL effective surface. A partial set lets unlisted inputs be filled from the per-terminal tester
cache — the documented root cause of the ORDER-165 8/8 false drift."* **A one-key map satisfies it.**

So the brief's aim-point #7 — *"nothing refuses the 2,177 partial files, so what stops one being used
as evidence?"* — has an answer: **nothing does**, and the check that says it does is checking
non-emptiness.

### 1.9 ℹ️ The brief invented a command — **verified**, and no code is owed

The S6 brief told the auditor to run `preset.py --self-test`. **Measured by this seat**: `preset.py`
contains no `__main__`, no `def main`, no `--self-test`, no `argv`. The command does not exist.

Third brief error of the session (with S9's refusal-code count and S3's stale entity counts), and the
third one an audit caught rather than quietly worked around.

---

## Part 2 — Verification status, stated per item

| item | status |
|---|---|
| 1.9 | ✅ **re-measured by this seat** |
| 1.1 – 1.8 | **Codex-reported with observed output quoted.** `preset.py` imports cleanly in this environment, so every one of these is cheaply settleable in-process. This seat did **not** re-run them, and this file does not claim otherwise |

**The two to settle first**, because both have the same consequence for whoever fixes them: **1.1**
(its cage asserts the exclusion) and **1.8** (it reaches into S10's `validate_payload`, which
`ORDER-1260` is already open on).

## Part 3 — Execution

`run_preset_tests.py` exits **0, all 18 attack/specificity cases green.** Codex's closing observation
is the one worth keeping:

> those cases do not cover account-unit identity, exponent precision for `long`, `sinput`, mixed enum
> vintages, declaration ordering, candidate completeness, or the CLI failure taxonomy.

A fully green cage and eight findings, from the same bytes, on the same afternoon.

---

## Part 4 — What this changes about the slice's own acceptance

| design §10 acceptance | status |
|---|---|
| unknown key refused | not challenged |
| partial set refused | **holds for what the compiler EMITS** — and 1.8 shows nothing refuses a partial set *entering* a run, and the candidate check that claims to is a non-emptiness test |
| generated `.set` full-surface and deterministic | 1.3 — "full" is measured against a surface that omits `sinput`; 1.5 — determinism is not order-independent |
| `[CFG]` emits the fingerprint | not challenged |
| 🚫 must not read the terminal cache | **holds structurally for the module** (C4), and 1.8 is the cache getting in anyway, through the runner |
