# `factory/parity/` — the parity evidence design §8.4 asks for, as it was actually produced

Produced 2026-08-03 by lane `S-2026-08-03-S13RUN` (`ORDER-1230`), by
`scripts/parity_run.ps1` — one directory per case, each holding the two manifests
`parity.py` judges (`wrapper.json` / `parent.json`), the agent-log **slice** each run
appended, and the full-surface `.set` both sides were handed.

**The verdict lives at the case-set level, not the case level**, and reading the per-case
exit codes as pass/fail will mislead you. `parity.py`'s own header states why: a clean run
raises no errors so point 7 has nothing to compare, and a refused attach places no orders
so points 2–6 have nothing to compare. **No single case can exercise all seven points.**
`ROLLUP.txt` is the transcript of the judgement that counts:

```
tools/python312/python.exe _triage/factory_os/parity.py --rollup \
  factory/parity/must-trade factory/parity/deliberate-refusal \
  factory/parity/cage-fires factory/parity/locked-absent
```

Result on 2026-08-03: **the case set satisfies design §5.5** — every point exercised by a
real observation in at least one case, none differs, both mandatory directions present.
Lane `D:\Meta 5` (primary/roaming), `XAUUSD H1 2024.01.01..2024.07.01`, model 1, one
window, one model, both sides.

| case | kind | what it contributed that no other case could |
|---|---|---|
| `must-trade` | must-trade | `end_state` — the only case whose window ends with positions open (3 `end of test` deals per side). 61 deals, so "it traded" is observed and not assumed |
| `deliberate-refusal` | deliberate-refusal | `alerts` — both sides refuse at `OnInit` on `_41_FixedLot=0.0`, for the **same** reason, which is what lets points 2–6 read `N/A-REFUSED` instead of `UNTESTED` |
| `cage-fires` | must-trade | `side_effects` — arms the account-DD gate at 0.3 % so it trips **inside** the window and both sides write real `[RISK]` lines. On the pinned config the gate is at 12 %, never fires, and this point had nothing to compare |
| `locked-absent` | neutral | **excluded from the contract by `parity.py` itself** — it is *expected* to differ, and its disagreement is the evidence (`_2_MaxHoldBars=5` is honoured by the parent and compiled away in the wrapper) |

Wrapper Inputs page: **29**. Parent: **116**. That asymmetry is the point of the rollout;
what has to match is the *effective* configuration, which point 2 checks — triangularly,
against the compiler's expected hash as well as against the other side.

## 🔴 What is NOT in this directory, and why it matters to whoever wires §8.6 items 3–4

Each manifest's `report` field names a file under `_mt5_auto/reports/`, and
**`.gitignore:70` ignores that whole directory.** The manifests here are therefore
committed evidence pointing at *uncommitted* artifacts: re-running `--rollup` works on the
machine that produced the runs and cannot work on a fresh clone.

So §8.6 items 3 and 4 must **not** be wired by pointing `check_pilot_acceptance` at these
directories and re-reading the reports — that is a checker whose passing depends on local
scratch surviving, which is the shape of a guard that goes quietly inert
(memory `prove-the-instrument-can-see-the-file`). The stub entry in
`check_pilot_acceptance.py` already names the right answer: a **parity result manifest**,
whose schema is `parity.py`'s to own, carrying the per-point verdicts and the case kinds,
with the checker driving `parity.verdict_for_case` rather than becoming a second reader of
the tester output. `ROLLUP.txt` is the human-readable stand-in for that manifest and is
deliberately **not** presented as one — it has no schema and nothing validates it.

Until that manifest exists, items 3 and 4 stay `BLOCKED` in the report, which is the
honest state: the runs happened and passed, and the checker still cannot see them.
