# Codex blind audit A + B — 2026-08-03

> Dispatched by lane `S-2026-08-03-S13SIZE` after it closed, **pinned at commit `aa024f2a`** because
> `S-2026-08-03-S13SCHEMA` was already ACTIVE and editing the same paths. Both audits were blind:
> Codex was given the design, the code and the committed evidence, and was **not** told what any
> previous session concluded.
>
> 🔴 **This file records findings against `ORDER-1230` / `ORDER-1240`, several of which are
> confirmed defects in what those orders wrote and claimed.** Every item marked ✅ VERIFIED below was
> re-measured independently after Codex raised it — Codex is a second opinion, not an oracle, and an
> unverified audit finding is just another claim.

---

## Part 1 — Findings VERIFIED against the committed bytes

### 1.1 ✅ VERIFIED — "PF does not include positions the tester force-closed" is **FALSE**

`ORDER-1230` and `ORDER-1240` state, in `scripts/pilot_carried.py`'s docstring, in
`scripts/pilot_cells.ps1`'s header, in two commit messages, on the `ORDER-1230` board row and in the
handoff, that under `SL_NONE` a carried basket's loss "never enters the ratio".

**It does.** Re-measured on `B14-H01-r1/XAUUSD/H4` at the build-default lot:

```
gross_profit  2999.84
gross_loss    -483.24
carried       -479.20
2999.84 / 483.24 = 6.2078  ->  matches the reported PF of 6.21
if carried were truly excluded, PF would be 742.53
```

The tester books a force-closed position as a **closed deal**, so it lands in `gross_loss` and
therefore inside PF. `net_profit == gross_profit + gross_loss` exactly, which is the same fact from
the other side.

**The `carried` field is still worth having — its meaning is different.** It shows that ~99 % of that
cell's entire gross loss came from **three** positions at the window edge. That is *concentration*,
not *concealment*: the PF is one endpoint event away from being a different number. Every place that
describes it as hidden-from-PF must be corrected to describe it as concentrated-at-the-edge.

**The process lesson, which is the expensive part:** the claim was propagated to six places before
anyone divided `gross_profit` by `gross_loss` once. An arithmetic claim is checkable in one line and
must be checked before it is written down, let alone repeated.

### 1.2 ✅ VERIFIED — the sizing criterion's pre-registration is **not provable from the repository**

`ORDER-1240`'s commit says *"the criterion was written and committed BEFORE the sweep ran"*.

```
git log aa024f2a --diff-filter=A -- scripts/pilot_sizing_sweep.ps1              -> 080de7c0
git log aa024f2a --diff-filter=A -- factory/runs/pilot/_sizing/sizing_sweep_result.json -> 080de7c0
```

Both first appear in **the same commit**. In wall-clock the criterion genuinely was written first,
but the repository cannot demonstrate it, and for a pre-registration *unprovable* and *absent* are
worth the same. This is precisely the failure `ORDER-1220` exists to prevent, repeated one order
later by the same seat.

**Rule going forward: a criterion is committed in its own commit, before the run that resolves it.**

### 1.3 ✅ VERIFIED — `_rollup_main()` discards every per-case verdict

`_triage/factory_os/parity.py`:

```
L446  passed, _reasons = verdict_for_case(kind, obs_a, obs_b, points)
L449  passed = False                      # on a compiler-anchor failure
L452  cases.append((name, kind, points))  # <- `passed` is NOT passed on
L461  else 'PASS' if passed               # only used for this case's own printed label
L464  ok, lines = rollup(cases)           # sees AGREE/DIFFER and kind strings only
```

So a case that fails its **direction** check — a `must-trade` case that opened nothing, or a
`deliberate-refusal` case that attached cleanly — still contributes its points and its `kind` string
to the roll-up, and the roll-up can still return green. Compiler-anchor failures are discarded the
same way.

`parity.py:556-558` states the opposite in its own docstring: *"Nothing here re-judges a case — the
per-case verdicts are the input, so a case that failed cannot be rescued by the roll-up."* **The
per-case verdicts are not the input.**

`main()`'s lane / symbol / period / window / model equality checks (`parity.py:485-495`) also exist
only on the single-case path, so `--rollup` does not enforce them either.

---

## Part 2 — Findings reported by Codex, NOT yet independently verified

Recorded as **claims to check**, not as facts. Ranked.

| # | Severity | Finding |
|---|---|---|
| 2.1 | 🔴 | **The committed parity run is not the §8.4 case set.** `CONTRACTS.md` `META_parity_cases` requires **seven** cases; `parity_run.ps1` implements **four**. Missing: the pilot `.set` on XAUUSD H4, the changed-locked-value + regenerate case, and the byte-identical `.mq5` regeneration case. The refusal seam was also substituted (`_41_FixedLot=0` instead of the RiskPct/SLMode pairing) — that substitution *is* documented in `parity_run.ps1`, but the missing three cases are not. ⇒ **"parity passes" as reported by `ORDER-1230` is over-stated: it passed the four cases that were run, and §8.6 item 3 asks for all of §8.4.** |
| 2.2 | 🔴 | **Crypto financing is annotated, never deducted.** `pilot_cells.ps1` writes a `financing_deducted` object with `applied: true` but never changes `net_profit` or PF, and the probe arms get no financing object at all. The file header claims *"its `net_profit` is the ADJUSTED figure with the raw one kept beside it"* — the code sets `net_profit = net_profit_raw = raw`. Codex reports BTCUSD H1 net 535.90 against financing −763.68, i.e. **the sign flips**. ⇒ §8.6 item 10 is failed, not satisfied. |
| 2.3 | 🔴 | **The tested config is not a clean basket-exit architecture.** `ExitMode=22` (`EXIT_ATR_TP`) with `_2_SuppressLegTP=false` gives individual legs broker take-profits. If so, the pilot measures a hybrid per-leg-TP + basket-target mechanism, and several narrative claims about basket-only behaviour do not hold. |
| 2.4 | 🟠 | **H01's falsifier is an OR and its second limb was never measured.** *"flat-lot PF ≥ escalated PF **or** worst-case single loss > 15 % equity at real sizing"*. No record carries largest basket loss, worst-case loss %, or any evidence that 0.03 is "real sizing". Max equity DD is not worst-case single loss. ⇒ cells where flat-lot PF is *lower* are **NOT EVALUABLE**, not "not met". |
| 2.5 | 🟠 | **No single-entry arm exists.** The causal claim compares against *"a single entry"*; the flat-lot arm is still an ATR-spaced multi-entry grid. What was measured is escalation-vs-flat-sizing, not distribution-vs-one-entry. |
| 2.6 | 🟠 | **Points 3, 6 and 7 observe proxies, not their contracted subjects.** Orders reads the HTML table only (rejected requests that never become report rows are invisible); side-effects matches `[PERSIST\|RISK\|MG]` log prose and never reads GlobalVariables or files; alerts matches four fixed prefixes. `sorted(set(...))` also discards order and multiplicity, so one alert and two identical alerts compare equal. |
| 2.7 | 🟠 | **`N/A-REFUSED` can erase asymmetric evidence.** `_cmp()` returns `UNTESTED` when *either* side is `None`, and a shared fatal string then converts it to `N/A-REFUSED`, which `verdict_for_case()` ignores. A truncated wrapper report against a populated parent report can pass. Init also parses only the fatal text, never the `OnInit` return code, and treats "no recognised fatal" as ATTACHED without any positive attach marker. |
| 2.8 | 🟠 | **`trades` counts legs, not baskets.** No basket count is recorded, so `n=100` must not be read as 100 independent observations. |
| 2.9 | 🟠 | **`run_parity_tests.py` skips the load-bearing paths.** No Orders-difference case; the roll-up test calls `rollup()` directly and never `_rollup_main()`, so 1.3 above is invisible to it; the anchor test calls `anchor_reasons()` directly and still passes if the roll-up stops enforcing anchors. Codex names several assertions that stay green with the logic under them deleted. |
| 2.10 | 🟡 | **No executable identity is pinned in the cell records** — expert paths and config hashes, but no `.ex5` hash. |
| 2.11 | 🟡 | **The data fingerprint is incomplete by admission** — design §6.4 requires a `Bases\` state marker; `pilot_cells.ps1` documents that it is omitted. |
| 2.12 | 🟡 | **"On a ranging instrument" is not operationalized** — four heterogeneous symbols, no pre-registered regime classification. Selecting the favourable cells later would be post-hoc relabelling. |

---

## Part 3 — What the audits AGREED with

Codex independently reached, without being told:

- The build-default matrix's flat-lot probes are **vacuous** — the escalated arm used one volume,
  reached L2, and produced identical deals, so PF equality means nothing.
- The first matrix's comparison was **confounded** — wrapper baseline against parent flat-lot differs
  in binary *and* lever.
- USDJPY H1's PF is correctly stored as **undefined rather than zero**.
- Neither hypothesis is **verdict-grade**: MAIN-only, Model 1, no BWD, no Model 4, no MC.
- **H02 is not evaluated at all** — no equal-DD matching, no hedge-fire count, no evidence the
  opposite-direction lock ever engaged.

Its §8.6 tally, independently derived: **items 1, 8 and 13 satisfied; the other eleven not.** That is
stricter than this project's own report (4 PASS) — the difference is item 2, which Codex judges "not
fully evidenced" because byte-identical regeneration was not demonstrated by the evidence it was
given.

---

## Part 4 — Audit coverage across the slices, as of 2026-08-03

Derived from the audit artifacts present in `_triage/factory_os/`.

| | slices |
|---|---|
| **Built code independently audited** | **S4 · S5** (batch 1) · **S7 · S8** · **S13** (this file) |
| **Design audited before code existed** | `AUDIT3-8` · `BLIND_AUDIT` · `REAUDIT` · `ROUND2` · `FINAL` — slice numbers inside these are *references*, not coverage |
| 🔴 **Built, never independently audited** | **S2 · S3 · S6 · S9 · S10 · S11 · S12** |

Two of the seven gaps carry more risk than the rest: **S10** touches magic reservation and deployment
attestation — the money path — and **S12** handles a Telegram token. `CLAUDE.md` already requires a
Codex second opinion for money-path work.

---

## Part 5 — Vocabulary hazard worth knowing before the next audit

`scripts/_test/**` and `_triage/factory_os/run_*_tests.py` use **`ATTACK`** as the standard label for
negative test cases — `run_parity_tests.py` alone contains 16. Audit B was pointed straight at that
file. It completed without incident this time, but a brief that is itself clean does not make the
audit safe: **the refusal risk comes from what the auditor reads, not from what the brief says.**
Renaming those case labels to `NEGATIVE` / `MUTATION` would remove the hazard and lose nothing.
