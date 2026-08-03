# Codex blind audit — Factory OS slice **S11** (Control Center shell + `SafeProjection`) — 2026-08-03

> Dispatched by lane `S-2026-08-03-AUDITCOV`, **pinned at `a87f7448`**, blind and read-only.
> Brief: [`CODEX_S11_AUDIT_BRIEF.md`](CODEX_S11_AUDIT_BRIEF.md), committed at `aeb67885` **before**
> the audit ran. First independent audit of this slice's built code.
>
> **No real value is reproduced anywhere in this file.** Every probe used a synthetic literal
> invented inside the harness. Fields are named; values are not.

---

## Part 1 — VERIFIED

### 1.1 🔴 CRITICAL — the scanner cannot tell *"scanned and found nothing"* from *"had nothing to scan with"*

`safe_projection.py:207-240` · `read_for_sender()` calls it with the **default empty list** at
`:578-579`.

**Measured**, with one synthetic account literal:

| input | hits | |
|---|---|---|
| exact literal in a value | **1** | DETECTED — **this is the control; the scanner is live** |
| **formatted** variant (`111-222-333`) | 0 | reports CLEAN |
| **split across list items** | 0 | reports CLEAN |
| as a **dict key** | 0 | reports CLEAN |
| **empty recognizer list** | 0 | reports CLEAN |

The last two rows are **indistinguishable in the return value**. A caller receiving `[]` cannot tell
whether the document was clean or whether the scan had no recognizer to work with — and
`read_for_sender()`, the sender's one door, is exactly the caller that passes none.

This is the repo's own `prohibition-disarms-its-own-check` and
`name-it-honestly-when-you-cannot-prove-it` in one place, and it is the third independent sighting of
this family today (see the S12 audit's 1.3, which is the same shape at `safe_detail`).

Codex additionally reports `secrets_of()` silently excluding every literal shorter than four
characters at `:263-270`, **with a comment that describes only one- and two-character exclusions** —
a rule-based exemption where the design asks for a closed declaration.

### 1.2 🔴 CRITICAL — the cage **requires** the secret to appear in the exception

`run_s11_tests.py:802`:

```python
assert 'balance' in str(exc) and PLANTED_ACCOUNT in str(exc), exc
```

**This is the sharpest single line either audit found today.** The S12 audit reported that
`scan_forbidden` writes the caught literal into its diagnostic and `assert_sendable` propagates it to
stderr and thence to the daily-monitor log. S11's audit found **why it is still there**: a test
asserts it.

**Consequence for whoever fixes it.** Redacting the diagnostic — the obvious and correct fix, already
modelled one function away by `notifier.safe_detail()`, which reports only the rule name — **turns
this cage red**. A corrections session that meets a red test and "repairs" it by reverting the fix
will have used the cage to reinstate the leak. The cage must be changed **in the same commit**, and
its replacement should assert the opposite: that the value is **absent** and the rule name present.

### 1.3 🟠 HIGH — `floating_risk.state` is named as a refusal and is never read

`safe_projection.py:30-34` (the module's own contract) vs `:341-376`.

The docstring names an unknown `floating_risk.state` as *the* example of a `ProjectionRefusal`,
arguing that mapping an unrecognised value onto the safe-looking one is how a future state meaning
`BREACH` renders as OK. **Measured**: the implementation reads only `floating_risk[].account` and an
optional `dd_band`. `state` is never read, and the upstream schema permits arbitrary row members
(`schemas.json:2169-2173`).

Test SP11 checks `system_health.state` and verdict reason codes only, so the input the docstring names
is uncovered.

**Consequence.** Not a privacy leak — a *silencing* one. `accounts[].sensor_state` can reach the
projection from `system_health.state` while an unrecognised `floating_risk.state` is discarded, so a
future breach state can coexist with a safe-looking projected sensor state.

### 1.4 ℹ️ A third brief error, caught by the audit — recorded, no code owed

The S6 brief told the auditor to run `preset.py --self-test`. **Measured: `preset.py` contains no
`__main__`, no `def main`, no `--self-test`, and no `argv`.** The command does not exist. (Kept here
rather than in the S6 file because it belongs with the other two brief errors this session produced —
S9's refusal-code count and S3's stale entity counts. **Three briefs were wrong and three audits
caught it**, which is the behaviour the blind arrangement exists to produce.)

---

## Part 2 — Reported by Codex, **NOT independently verified**

| # | Sev | Claim | note |
|---|---|---|---|
| 2.1 | 🔴 | **A formatted account can reach a Telegram event.** `SafeProjection.build_id` and `generated_at` are **unconstrained strings** (`schemas.json:2569-2574`); a formatted account in `build_id` passes the schema, passes `read_for_sender()`'s scan, passes `assert_sendable()`, and lands in `AlertEvent.build_id` **and** the Morning Brief text, which the transport sends. The exact unformatted form **is** caught — so formatting alone defeats it | The mechanism is 1.1, which is measured. The end-to-end path was not re-driven by this seat. **Highest-value item in Part 2** |
| 2.2 | 🟠 | **An unknown drawdown band can render `ALL CLEAR`.** `control_center.py:587-593` handles only `WATCH` and `BREACH` and neither refuses nor renders anything else, so health can find zero LIVE exceptions and emit `ALL CLEAR` while `LIVE.RISK` omits an unrecognised detector-supplied band. **`SafeProjection`'s own `DD_BAND_MAP` refuses one** — so the two halves of the same slice disagree | `DD_BAND_MAP` confirmed present by this seat; the `control_center` half not re-measured |
| 2.3 | 🟡 | **The real band pass-through is `UNTESTED`, not measured.** The fixture proves pass-through synthetically; the real-snapshot case only exercises the current no-band state. The board describes it as measured | An evidence-status defect, not a leak |

**Claims that held.** C1's allowlist is **structural** — `build()` constructs field by field
(`:393-399`) rather than copying and pruning, and the schema closes root and nested objects; that is
the right shape and it survived. C4 is scoped honestly and `SB01` passed **using the real snapshot
path**. C8 is enforced by the **absence** of dispatch/claim/closure code rather than by a switchable
flag — which is the stronger of the two.

---

## Part 3 — Execution

`run_s11_tests.py --list` = **74 scenarios**; **66 completed**, 8 blocked by the audit sandbox's
no-write rule. Environment failures, not S11 findings, and not counted as passes either.

This seat: `scratchpad/verify_s6_s11.py` — 1.1 (five inputs, with the exact-literal control), 1.2,
1.3, 1.4.

---

## Part 4 — What this changes about the slice's own acceptance

Design §10's S11 row: *"all 30 handoff acceptance scenarios · **`SafeProjection` DTO**:
forbidden-key recursive scan + synthetic secret/account fixtures"* · prohibitions: *"no dispatch,
claim, or closure from the UI; Telegram must not be able to read the full snapshot"*.

| acceptance | status |
|---|---|
| forbidden-key recursive scan | **holds for keys**; 1.1 shows the **value** half is defeated by formatting, splitting, or being a key itself |
| synthetic secret/account fixtures | **they exist, and 1.2 shows one of them pins the leak in place** |
| no dispatch/claim/closure from the UI | **holds, by absence of the code** |
| Telegram cannot read the full snapshot | **holds** — the seam is real here (`build()` is field-by-field, `read_for_sender` refuses other paths). 2.1 is not a snapshot read; it is a value **carried into** the projection legitimately |

The honest summary: **the structural half of this slice is good** — allowlist by construction, one
reader, refusal by absence. **The recognising half is where it fails**, and it fails in the direction
that reports clean.
