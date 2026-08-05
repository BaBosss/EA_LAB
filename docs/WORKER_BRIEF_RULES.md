# Worker brief rules — what makes a delegated batch survive

> Written 2026-08-05 by lane `S-2026-08-04-QUOTA4`, from **six** delegated-batch failures in one
> session, not from theory. Every rule here cites the run that produced it.
>
> ⚠️ **This file is not `AGENTS.md` and does not override it.** Promoting any of this into `AGENTS.md`
> is the owner's call or another lane's — this lane is forbidden from touching that file.

## 0. The rule that replaces trust: run the checker

`scripts/check_sweep_inputs.ps1` reads what each report's **own Inputs page** records and refuses when
a set of reports that is supposed to be a sweep did not actually vary.

```powershell
powershell -File D:\EA_LAB\scripts\check_sweep_inputs.ps1 `
  -ReportGlob 'D:\EA_LAB\_mt5_auto\reports\O1411_PVT2_*.htm' `
  -Parameter _02_SlAtrMult,_01_AtrPeriod
```

Exit `0` clean · `1` a real defect · `2` **could not check** — deliberately never conflated with `0`.

**Why it exists.** On 2026-08-04 a 25-cell sweep was preceded by **15 reports, each named for a
different parameter pair, every one of which had run the untouched baseline** and returned the
identical `PF 1.17 / 211 trades / net 149.01`. Reading those files would have produced the conclusion
*"both axes are inert"* — the exact opposite of the truth, supported by fifteen mutually consistent
reports. Nothing caught it. It was avoided by an accident of filename parsing.

⇒ **A report carrying a plausible number is not evidence that the intended configuration ran.**
Only the Inputs read-back is. Run the checker on every sweep before reading a single result.

## 1. Never ask a worker to reproduce raw tool output

This is the rule that actually governs whether a batch finishes. The worker's context holds its
system prompt, the brief, and **every tool call and every tool result**. Asking it to also *write out*
the raw parse output pushes that text through its context a second time.

Measured, same tier, same night:

| batch | runs | brief asked for raw output? | outcome |
|---|---|---|---|
| ORDER-236 XAUUSD | 8 | yes | survived |
| host screen | **12** | yes | **died** |
| AUDCAD replication | 20 | yes | died |
| **ORDER-1411 CELL 2** | **40** | **no — one compact row per run** | **survived** |
| ORDER-1411 sweep | 70 | no | died |

**12 died while 40 survived, so run count is not the variable.** Ask for one compact row per run:
`| param | value | PF | trades | DD% | net | report path |`. Nothing else.

<sub>The ceiling itself is real: every death reported the identical `input_tokens = 99073`. That is the
worker's own transcript — not MT5, not the repo. Each run+parse pair costs roughly 1-2k of it.</sub>

## 2. Append on parse, never hold results to the end

Four batches died *after* completing their runs, while writing their summary. The ones that had been
told to append each row the moment it parsed lost nothing; the ones that held results lost the
summary and had to be re-parsed by the lead seat.

> Append each row to the output file the moment it parses. If you die mid-batch the finished rows
> must already be on disk.

## 3. Do not delegate a job that is mostly waiting

`ORDER-1411` STAGE 3 was **two** Model-4 runs. The worker exited `0` while the tester was still
running, having produced no report at all.

The variable is not "Model 4" — three earlier batches ran 8, 8 and 10 Model-4 runs through workers
successfully. It is that a job with **very few, very long steps** gives the worker nothing to do but
wait, and it stops waiting. Run those from the orchestrator directly.

## 3b. 2026-08-05: two more instances, and the second one produced NOTHING

Both `ORDER-236 STEP 3` batches hit the identical `input_tokens = 99073`. Recorded because the second
one is the first instance the rules above did **not** help with, and saying so is more useful than
adding a rule that has not been measured.

| batch | brief followed §1 and §2? | sets it had to BUILD | runs completed | rows saved |
|---|---|---|---|---|
| STAGE 1 (probe, Model 1) | yes | **11** | **12 of 12** | 11 — the 12th recovered from disk |
| STAGE 2 (grid, Model 4) | yes | **2** | **0** | **0** |

**So none of the obvious variables explains it.** Not run count (§1 already established that). Not the
number of files built — the batch that built **eleven** finished every run and the batch that built
**two** finished none. Not Model 4 by itself (§3), and not the brief's structure, which was the same
shape in both.

What is left, and it is stated as an open question rather than a rule: **the ceiling is the same
number every time, and where a batch dies inside it is not predictable from the brief.** §2 (append on
parse) is what decides the *cost* of a death — it turned one death into the loss of a single row and
the other into the loss of nothing at all, because nothing had been produced yet.

⇒ Practical consequence, and it is the one thing this instance does justify: **when a batch dies
having produced zero artefacts, do not re-dispatch it unchanged.** Run it from the orchestrator. The
12 Model-4 runs STAGE 2 needed were run directly by the lead seat afterwards, which is what §3 already
says for jobs that are mostly waiting.

## 4. When qwen is genuinely the wrong size, escalate one step

Per `CLAUDE.md`'s cost ladder (qwen ≈ free < Sonnet < Codex ≈ Opus), the fallback for a batch that
cannot be made to fit is **Sonnet (`fast-worker`)** — larger context, in-session tools. Escalate, do
not default up: with rule 1 applied, 40 runs fit qwen comfortably, so most batches never need it.

## 5. Prohibitions that belong in every batch brief

- No verdict, no `pass`/`dead`/`good`/`bad`/`best`/`edge` language. Numbers and pre-registered labels
  only. Judgement is the order's, not the runner's.
- Never touch a `2026` window (holdout), any `.mq5`, `ea_template\core\`, anything under
  `_vps_deploy\`, or any board/scorecard/state file.
- Never `git commit` or `git push`. Never recompile. Never copy to a VPS.
- Copy a `.set` out before editing it; never edit the original in place.
- Name the lane explicitly and name the lane the batch must **not** touch.
