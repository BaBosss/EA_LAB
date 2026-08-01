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

**Where the index-mode cost is (`A1`).** `check_registries.py`'s `check_r4` enumerates **129
committed paths** (33 `_triage/factory_os/*.py` + 91 `scripts/*.ps1` + 5 `scripts/lib/*.ps1`) and
reads **every one** through its own `git show :path` — **142 git child processes per run, 99.5 % of
the script's wall time**, `check_r4` alone holding 130 of them. `ORDER-270`'s spawn pathology in a
new place.

## 2. 🔴 The trap this lane fell into, and it is the repo's own recurring one

I measured `run_fast_cages.ps1 -Hook` **by hand from PowerShell**, got 97.1 / 98.6 / 95.9 s against
the 90.0 s budget, and wrote "every hook run is over budget". Then the **real** pre-commit hook ran
the same suite, in index mode, and took **20.3 s** — cheaper than every standalone number I had.
Transcript: `_triage/tier_runs/tier_20260801_201847_24332.jsonl` (`hook: true`,
`git_index_env: .git/next-index-5516.lock`, `seconds: 20.3`).

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
  held constant: **35.3 vs 25.3 ms per spawn**. PowerShell resolves the shim, git-bash the real
  binary — **and it is not PATH length** (PowerShell has 15 entries, bash 31). At 142 spawns that is
  **+1.4 s on `check_registries.py` alone**, and ~5-8 s across the suite.
- **`GIT_INDEX_FILE`: no effect.** Pointed at a copy of `.git/index`, bash+index went 25.6 → 25.7 s.
  Probed because `ORDER-830` A2b named it as the likely cause; it is not.
- **~5 s between git-bash+index (25.7 s) and the real hook (20.3 s) is still unexplained.**

### And the number that actually settles `ORDER-820`

Reproducing `.githooks/pre-commit:220` exactly — `sh` → `powershell.exe -NoProfile
-ExecutionPolicy Bypass -File scripts/_test/run_fast_cages.ps1 -Hook` — full tier, three
consecutive samples at `7e4d8361`, machine idle:

| how the SAME script was invoked | suites | full tier |
|---|---|---|
| **from `sh`, `-Hook` — the hook's own line** | 17 | **83.3 · 86.4 · 87.2 s — every one INSIDE 90.0 s** |
| from PowerShell, `-Hook` | 16 | 95.9 · 97.1 · 98.6 s — every one over |
| from PowerShell, no `-Hook` | 16 | 87.5 · 89.8 s |

🔴 **`ORDER-820`'s headline — "the full tier is OVER its enforced budget on every sample" — is not
supported by any measurement taken the way git invokes it**, and the cheap column is the *bigger*
tier (a parallel lane, `7e4d8361`, added a 17th suite mid-measurement). Its six samples carry no
record of how they were launched, and the spread between invocations (83-98 s) is wider than the
spread between its samples. **This does not prove the tier is safe.** It proves the budget has been
argued from numbers whose provenance nobody wrote down.

## 3. 🚫 What must NOT be carried forward from this lane

- ❌ **Do not quote my 97.1 / 98.6 / 95.9 s as "what a committer pays".** They are a manual
  `-Hook` invocation from PowerShell — the most expensive configuration measured, and not the one
  git runs. `ORDER-820`'s own five samples (91.1-93.6 s) and its sixth (87.8 s) have **no recorded
  invocation** either, so none of the six can be assigned to a configuration now.
- ❌ **Do not read the 83.3-87.2 s as "the tier is fine" either.** It is three samples, one machine,
  one evening, and there is still ~5 s between that invocation and a real hook nobody has explained.
  What is established is narrower and more useful: **a tier total with no stated invocation is not
  evidence**, and every number in this thread was one.
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

## 5. Routing

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| A1 named (129 paths, 142 git spawns) · A2 (no regression, +0.7 s) · A2b (mode + shell, not variance) · A3 (residual is 1-2 s of process starts) · A4 (wrapper comments repaired) | ORDER-830 |
| the budget question REOPENED: 83.3-87.2s through the hook's own invocation vs 95.9-98.6s from PowerShell — re-establish C2's premise before spending anything on it, and restate C3 as three runs through `.githooks/pre-commit`'s own line | ORDER-820 |
| the ~5s still unexplained between `sh`+`-Hook` and a real hook | ORDER-820 |
| the named candidate fix: one `git cat-file --batch` in `evidence.py` instead of 129 `git show` spawns | ORDER-820 |
| `run_s2a_gate.py` 2.57 → 4.94 s, unattributed | ORDER-820 |
| a module should DECLARE the paths it reads | ORDER-761 |
| the tier abort, armed and waiting to recur | ORDER-731 |
