# HANDOFF — lane `S-2026-08-01-TIERATTR` (`ORDER-830` A1-A4)

> Read `_triage/HANDOFF_2026-08-01_SESSION_END.md` first for the day; this file is one lane.
> **The one sentence:** every timing number in the `ORDER-820` / `ORDER-830` thread was quoted
> without saying **which configuration produced it**, and that single omission is the whole of the
> "+8.7 s regression" *and* the whole of the "7 s intermittent swing".

## 1. What was measured, and what it refuted

`ORDER-830`'s full RESULT block is on the board — this file carries only what a reader needs to
avoid repeating the mistake.

**The suite did not grow.** Re-measured at `ddbaec95` in a real `git worktree` (never `git stash`),
three samples per cell, mode and shell held constant across both commits:

| `run_contract_binding_tests.ps1` | `ddbaec95` | HEAD | grew |
|---|---|---|---|
| worktree mode | **24.32 s** | **24.98 s** | **+0.66 s** |
| index mode | **32.78 s** | **33.48 s** | **+0.70 s** |

The `+8.7 s` that `ORDER-820` attributed to an unnamed commit is the **mode delta**, and it is the
same size at `ddbaec95` (+8.46 s) as at HEAD (+8.50 s). There was never a regression to attribute.

**Where the index-mode cost is (`A1`).** `check_registries.py`'s `check_r4` enumerates
`_triage/factory_os/*.py` + `scripts/*.ps1` + `scripts/lib/*.ps1` and reads each swept path through
its own `git show :path` — **~142 git child processes per run, 99.5 % of `main()`**, `check_r4`
alone holding ~130 of them. `ORDER-270`'s spawn pathology in a new place.

🔴 **Do not quote the counts — re-count them.** I wrote "129 paths, reads every one of them" and
both halves were wrong within the hour: it was **131** four commits later (a parallel lane added two
files), and `RESOLVER_SWEEP_EXEMPT` **skips 6**, so the sweep reads **127** plus the 1 declared
consumer (read twice) = **128 `git show` calls in `check_r4`**. The durable claim is the shape —
**one git child process per swept path, growing with the repository**.

## 2. 🔴 The trap this lane fell into, and it is the repo's own recurring one

I measured `run_fast_cages.ps1 -Hook` **by hand from PowerShell**, got 97.1 / 98.6 / 95.9 s against
the 90.0 s budget, and wrote "every hook run is over budget". Then the **real** pre-commit hook ran
the same suite, in index mode, and took **20.3 s** — cheaper than every standalone number I had.

⚠️ **The evidence is quoted here rather than cited, because the file is gitignored.**
`_triage/tier_runs/` is matched by `.gitignore:16`, so `tier_20260801_201847_24332.jsonl` is
untracked and will not survive — a citation would have left this resting on something no later
reader can open. Decisive fields: `hook: true` ·
`git_index_env: D:/EA_LAB/.git/next-index-5516.lock` · `suite: run_contract_binding_tests.ps1` ·
`seconds: 20.3` · `ref: 7777ca27…`. Any future claim resting on a tier transcript owes the same.

**There are at least three variables, not one.** Same suite, same commit, same machine, same hour:

| context | evidence mode | suite |
|---|---|---|
| PowerShell, standalone | worktree | 24.9 - 25.4 s |
| PowerShell, standalone | index | 33.4 - 34.1 s |
| git-bash, standalone | worktree | 19.9 - 20.3 s |
| git-bash, standalone | index | 25.6 - 27.2 s |
| **real pre-commit hook** | index | **20.3 s** |

- **Evidence mode** (`EA_LAB_EVIDENCE=index`, set by `run_fast_cages.ps1` **only under `-Hook`**):
  **+8.5 s**.
- **Which `git.exe` is on PATH:** `C:\Program Files\Git\cmd\git.exe` is a **45 KB shim**;
  `mingw64\bin\git.exe` is the real **4.3 MB** binary. Benchmarked from one shell so the shell is
  held constant, and **interleaved in both orders across 3 rounds** so a warm-cache ordering effect
  cannot hide in it: **+9.1 to +9.2 ms per spawn, stable to 0.1 ms**. Quote the delta, not the
  absolutes (32.7 vs 23.6 ms interleaved; 35.3 vs 25.3 ms in the first one-order run — they drift
  with load). PowerShell resolves the shim, git-bash the real binary — **and it is not PATH length**
  (PowerShell 15 entries, bash 31). At ~142 spawns that is **+1.3 s on `check_registries.py`
  alone**, ~5-9 s across the suite.
- **`GIT_INDEX_FILE`: no effect.** Pointed at a copy of `.git/index`, bash+index went 25.6 → 25.7 s.
  Probed because `ORDER-830` A2b named it as the likely cause; it is not.
- **~5 s between git-bash+index (25.7 s) and the real hook (20.3 s) is still unexplained.**

### And the number that actually settles `ORDER-820`

Reproducing `.githooks/pre-commit:220` exactly — `sh` → `powershell.exe -NoProfile
-ExecutionPolicy Bypass -File scripts/_test/run_fast_cages.ps1 -Hook` — full tier, three
consecutive samples at `7e4d8361`, machine idle:

| how the SAME script was invoked | suites | commit | full tier |
|---|---|---|---|
| **from `sh`, `-Hook` — the hook's own line** | 17 | `7e4d8361` | **83.3 · 86.4 · 87.2 s** |
| **from `sh`, `-Hook`** | 17 | `60a6eb12` | **87.1 · 87.2 · 90.1 s** ← one **over** |
| from PowerShell, `-Hook` | 17 | `585a23a5` | **95.1 · 97.6 · 97.6 s** |
| from PowerShell, `-Hook` | 16 | earlier | 95.9 · 97.1 · 98.6 s |
| from PowerShell, no `-Hook` | 16 | earlier | 87.5 · 89.8 s |

**The verdict is "ON THE LINE", not "inside":** six samples through the hook's own invocation span
**83.3 - 90.1 s against 90.0 s**, and one is over. The solid part is the **gap** — rows 2 and 3 are
the controlled pair (same 17 suites, one commit apart, same `-Hook`, only the shell differs):
**~9 s, three times the budget's headroom.**

🔴 **`ORDER-820`'s headline — "the full tier is OVER its enforced budget on every sample" — is not
supported by any measurement taken the way git invokes it.** Its six samples carry no record of how
they were launched, and the spread between invocations (83-98 s) is wider than the spread between
its samples. **This does not prove the tier is safe** — it proves the budget has been argued from
numbers whose provenance nobody wrote down.

<sub>Every row carries its commit because **HEAD moved twice during these measurements** — parallel
lanes commit during a 90-second run. That also explains why `run_front_guard_evidence_tests.ps1`
went red in 3 of ~12 full-tier runs and green every time it was run alone: **it judges `HEAD`, and
`HEAD` moved underneath it.** Routed to `ORDER-731`.</sub>

## 3. 🚫 What must NOT be carried forward from this lane

- ❌ **Do not quote my 97.1 / 98.6 / 95.9 s as "what a committer pays".** They are a manual
  `-Hook` invocation from PowerShell — the most expensive configuration measured, and not the one
  git runs. `ORDER-820`'s own five samples (91.1-93.6 s) and its sixth (87.8 s) have **no recorded
  invocation** either, so none of the six can be assigned to a configuration now.
- ❌ **Do not read 83.3-90.1 s as "the tier is fine" either.** Six samples, one machine, one
  evening, **one of them over the line**, and ~5 s still unexplained between that invocation and a
  real hook. What is established is narrower and more useful: **a tier total with no stated
  invocation and commit is not evidence**, and every number in this thread was one — mine included,
  until this review put the commit in every row.
- ❌ **Do not quote any per-entry number without its mode.** The two-mode table now lives in
  `scripts/_test/run_contract_binding_tests.ps1`'s own header, above the entry list, so the next
  reader hits it before quoting.

## 4. Two things a later lane will want and would otherwise re-derive

- **A fresh worktree cannot run this tier.** `tools/python312/python.exe` is committed (34 files)
  but `python312.zip` — the stdlib — is matched by `.gitignore:85 *.zip`, so the checked-out
  interpreter dies with *"Python path configuration"*. Copy the zip across. The wrapper's header
  calls the interpreter *"committed in-repo"*; it is committed except for the part that runs.
- **`run_s2a_gate.py` drifted 2.57 → 4.94 s** with the memoization its comment describes still in
  place. Second-largest entry in the wrapper, and nobody has attributed it.

## 6. 📌 AUDIT BRIEF — for the independent (non-author) audit `ORDER-830` still owes

> **Status: NOT urgent, nothing gates on it.** `ORDER-830` is `DONE`, its acceptance C1-C4 is met,
> and `REVIEWED` is needed only to archive the row. Written 2026-08-01 because **Codex quota was
> out** and the owner chose to wait rather than spend a second Fable pass. Whoever picks this up:
> you are the **third** pass — a `/scrutinize` self-review (7 fixes) and a **Fable-seat** review
> (7 more, `F1-F7`) already ran and are both closed. **Your value is being a different vendor, not
> being another careful reader** — go where a different set of blind spots would look.

**Read, in this order:** `AGENT_TASKBOARD.md` → `ORDER-830`'s `RESULT` block (A1 · A2 · A2b · A3 ·
A4 · Handed forward) and then `ORDER-820`'s correction box · this file §1-§4 ·
`scripts/_test/run_contract_binding_tests.ps1` header comment block (the two-mode table).

**🚫 Do NOT re-run the measurements.** They cost ~50 minutes of wall clock and the conclusions do
not depend on re-running them — they depend on whether the *inferences drawn from them* hold.

**The four questions worth a different vendor's eyes:**

1. **Is the mode/shell decomposition actually complete?** Two variables were found (+8.5 s evidence
   mode, 5-9 s shell/git-binary) and one ruled out (`GIT_INDEX_FILE`, no effect). **~4-5 s between
   `sh`+`-Hook` (24.5-26.0 s) and a real pre-commit hook (20.3 s) is still unexplained** and is
   attributed to nothing. Is there a third variable, or is the 20.3 s figure itself suspect?
2. **Does `A2`'s inference survive a hostile read?** The claim is: the suite grew **+0.7 s**
   (measured), therefore `ORDER-820`'s +8.7 s was the mode delta (**inference**, labelled as such,
   because **no measured configuration reproduces its 22.9 s**). Attack it: is there a reading where
   a real regression is hiding inside a mode difference?
3. **Is `A1` naming the right operation?** `check_r4`'s sweep is 99.5 % of `main()` in index mode —
   but the fix candidate handed to `ORDER-820` (one `git cat-file --batch` for ~128 per-path
   `git show` spawns) has **not** been prototyped. Would it actually work through
   `evidence.py`'s `read_committed` contract, which has a no-fallback rule and a decode/CRLF step
   per path?
4. **Was anything left worse than it was found?** Specifically: the wrapper header now carries a
   hand-maintained two-mode table with **no cage**, in a repo whose most-repeated defect is exactly
   that (`BACKLOG-D29`). It is marked *"re-count, do not quote"* — is that mitigation enough, or
   did this order add a new drift surface while documenting one?

**Already known and NOT worth your time:** the counts drifted 129→131 within the hour (fixed, and
the fix is to stop quoting integers) · `PARKED` was not in the status vocabulary (fixed) · the tier
transcript evidence is gitignored (fields quoted inline) · `run_front_guard_evidence_tests.ps1` is
flaky under concurrent lanes because it judges `HEAD` (routed to `ORDER-731`).

**One loose number for you to settle if you want a concrete deliverable:** lane `WRFIX` recorded a
**seventh** full-tier sample — **100.0 s, suite at 34.8 s** — in its ledger cell only, with **no
invocation recorded**. It exceeds every configuration `ORDER-830` measured. *Inference, not
measurement:* 34.8 s ≈ PowerShell+index (33.4-34.1 s) **+ the ~0.5 s suite `S14GRANT` added**, and
100.0 s ≈ PowerShell `-Hook` (97.6 s) + the same, so it most likely fits the PowerShell population
exactly rather than widening any swing. **Nobody has confirmed that.** Confirming or refuting it is
a clean, bounded task and it settles the last open number in the thread.

## 5. Routing

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| A1 named (129 paths, 142 git spawns) · A2 (no regression, +0.7 s) · A2b (mode + shell, not variance) · A3 (residual is 1-2 s of process starts) · A4 (wrapper comments repaired) | ORDER-830 |
| the budget question REOPENED: six samples 83.3-90.1s through the hook's own invocation (ON THE LINE, one over) vs 95.1-98.6s from PowerShell — re-establish C2's premise before spending anything on it, and restate C3 as three runs through `.githooks/pre-commit`'s own line with commit and shell stated | ORDER-820 |
| the ~5s still unexplained between `sh`+`-Hook` and a real hook | ORDER-820 |
| the git-shim lever: `cmd\git.exe` costs +9.1..9.2 ms/spawn vs `mingw64\bin\git.exe` — nobody has measured which one a real hook resolves | ORDER-820 |
| lane WRFIX's **seventh tier sample (100.0 s, suite 34.8 s)** lives only in its ledger cell, **exceeds every configuration `ORDER-830` measured** (max 34.1 s), and carries no invocation record — put it on the order with its invocation stated, or discount it explicitly | ORDER-820 |
| `run_front_guard_evidence_tests.ps1` red in 3 of ~12 full-tier runs, green alone — it judges `HEAD` and parallel lanes move `HEAD` during a 90-second run | ORDER-731 |
| the named candidate fix: one `git cat-file --batch` in `evidence.py` instead of 129 `git show` spawns | ORDER-820 |
| `run_s2a_gate.py` 2.57 → 4.94 s, unattributed | ORDER-820 |
| a module should DECLARE the paths it reads | ORDER-761 |
| the tier abort, armed and waiting to recur | ORDER-731 |
