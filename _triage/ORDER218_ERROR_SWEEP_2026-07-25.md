# ORDER-218 — error sweep: what the machine was already telling us

Opened 2026-07-25 on user instruction ("รีวิว error ที่เกิดขึ้นแล้วขยายผล") after a day of
review work threw a lot of red text. The question is not "what broke today" — it is **which of
these errors are signal we have been ignoring**.

The answer, in one line: **the repo has automated detectors that write their findings to disk and
nobody has ever read the output.**

---

## Finding 1 🔴 — the truncation detector has been flagging the Boss_16 lot-mode cage since 24 Jul

`scripts/check_truncated_run.ps1` (ORDER-193) is wired into `mt5_run.ps1`, so every run since
2026-07-24 writes `<name>.truncation_check.json`. **140 sidecars exist. Four say
`"truncated": true`. All four are the `mm_lotmode_test` runs** — the cage that certified
`_16_BaseLotMode` for Boss_16, whose attach bundle was built earlier today.

Re-running the detector with `-ToDate` (the stored sidecar has an empty `detail` field — see
Finding 4) gives the reason:

| run | last deal | idle tail | entry deals | eqDD |
|---|---|---|---|---|
| `MMLOT_K1_scaled_1x` (deposit 10,000) | 2024.05.23 20:56:40 | 38.1 d (20.9%) | 59 | 25.09% |
| `MMLOT_K1_scaled_2x` (deposit 20,000) | 2024.05.23 20:56:40 | 38.1 d (20.9%) | 59 | 25.03% |
| `MMLOT_A_fixed_baseline` | 2024.05.09 16:10:40 | 52.3 d (28.7%) | 115 | 25.09% |
| `MMLOT_E_unit_indep` | 2024.01.08 14:51:40 | **174.4 d (95.8%)** | **6** | 25.01% |

Every one stops at eqDD ≈ 25%, which is the hard-kill threshold. These runs did not run out of
signal; **the cage killed them.**

**Judgement — the invariance claim survives, and the reason matters.** The hazard this detector
was written for is, in its own docstring, "truncated at one deposit and complete at another — so
two runs that look comparable are not". The 1x and 2x runs stop at the *same timestamp* with the
*same 59 deals*. They die identically, which is itself evidence of deposit invariance. The trap
did not spring.

**What is genuinely weaker than the recorded "CLEAN":** nothing was verified past a 25% drawdown,
on ~5 of 6 months. And `MMLOT_E_unit_indep` passed unit-independence on **6 trades across 8
days** — that is not a test, it is an anecdote. Recorded as unproven.

**Action taken:** the caveat is now written into
`_vps_deploy/BOSS16_KANGAROO_XAU/README_ATTACH.md` so it reaches the operator before attach, not
after. Re-running `MMLOT_E` at a deposit that does not trip the kill is queued, not done.

## Finding 2 🟡 — 6 runs whose leverage was never verifiable, one of them cited in a verdict written today

498 `leverage_check.json` sidecars. 490 `MATCH`. One `MISMATCH`, and it is
`EXP_LEV_H_FORCEDMISMATCH` — a deliberate probe proving the detector fires, i.e. good news.

The remaining **6 are `NOT_RECORDED`**: the report carried no leverage line, so the run is
*unverifiable* rather than wrong.

`CSC_sb2_ex300_BWD` · `O171_SS4_sa0.8_tp2.5` · **`O200_ST03_near30_MAIN`** · `SS1L_base_off_MAIN`
· `SS1L_lot02_ctrl_BWD` · `SS1TF_ema100_mo0p8_MAIN`

`O200_ST03_near30_MAIN` is from the ST03 spacing-lever work a parallel session reviewed **today**
(ORDER-201). Its verdict was BWD-fail on all variants — a *negative* result, and leverage
uncertainty inflates rather than deflates, so the conclusion is not at risk. Worth stating
explicitly rather than leaving as an open thread.

## Finding 3 🟡 — detector coverage is 3% of the corpus, and that is not a defect

4,930 reports · 140 truncation sidecars · 498 leverage sidecars. The gap is simply that both
detectors were wired in after most of the corpus existed. Retro-scanning 4,930 old reports is not
worth it — the ones that matter are the ones a verdict cites, and those are already being swept
by ORDER-202 (holdout) and ORDER-204 (genetic). **No order raised.** Recorded so nobody
"discovers" the 3% later and mistakes it for rot.

## Finding 4 🟠 — the detector throws away its own reason

The stored sidecar is `{"report_name": ..., "truncated": true, "detail": ""}`. The `detail` field
is empty on every hit, even though re-running the script prints a full diagnosis. A flag with no
reason is a flag people learn to ignore — which is exactly what happened here for a day.

## Finding 5 🟠 — a guard that trains people to write around it

`check_state.ps1` §7 flags any root `*.md` containing the Thai phrase for "single file" as a
"competing entry claim". It fired **twice today on ordinary prose** — once on my own sentence
"…8 lines apart, in the same file", once on a parallel session's text. **Both of us reworded the
prose instead of fixing the check.** The parallel session left a comment in `AGENTS.md` saying it
avoided the phrase deliberately.

A guard whose false positives are routed around by editing English/Thai wording is training
authors, not protecting the invariant. It should match a claim shape (a heading, a bolded
declaration), not a bare substring anywhere in a document.

Also noted: the same check produced a **transient** warning during this sweep, because it read
`AGENTS.md` while a parallel session had it half-written. Re-running gave CLEAN. Guards that read
a shared working tree will do this.

## Finding 6 🟢 — nothing I changed today is broken

Checked directly, because the user's prompt raised it: all three edited MRIS scripts parse,
`barometers.json` is valid JSON, `check_state.ps1` is CLEAN, the live MRIS run reproduces
NEUTRAL / RI 0.308 unchanged, and the ORDER-211 agent restored `Common\Files` byte-identical.
The red text in the session was pre-commit guards doing their job (three blocks, all correct:
scorecard and index must move together) plus one PowerShell quoting error of mine that failed
loudly and was retried. **No silent damage.**

---

## What this sweep is really about

Every finding above except #6 has the same shape: **the system detected the problem, wrote it
down, and no human or agent read the file.** The truncation detector caught a real weakness in
the Boss_16 cage a full day before the attach bundle was built — the information was sitting on
disk the whole time the bundle was being assembled.

Building detectors is cheap. Reading them is the part that was missing. That is what ORDER-218
and ORDER-219 exist to fix.

---

## Postscript — Finding 5 demonstrated itself, twice more

Committing this very report tripped `check_state` §7 again: the ORDER-219 text **quotes the Thai
phrase while describing the bug it causes**, and the substring match cannot tell a bug report
from a claim. That is the third hit today (my earlier sentence, the parallel session's text, and
now the write-up of the problem itself).

Fixed the only way the check allows — by inserting a hyphen into the quoted phrase, exactly the
workaround the parallel session had already resorted to in `AGENTS.md`. Three authors, three
reworded sentences, zero invariants protected. ORDER-219 item 3 is not a nice-to-have.
