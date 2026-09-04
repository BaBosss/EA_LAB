---
name: locked-ea-analyzer
description: Behavioral analysis of a closed/protected commercial EA (compiled .ex4/.ex5, no source available) — confirm whether it's actually protected, recover ground-truth parameters without decompiling, infer its principle of operation from Strategy Tester Journal logs, cross-check against public vendor info, and smoke-screen/validate it across symbols. Also the entry point for building an ORIGINAL EA "inspired by" a locked EA's observed behavior. Use when the user asks to "analyze this EA in detail" / "วิเคราะห์ EA ตัวนี้อย่างละเอียด", wants to know how a closed-source EA works, whether it can be copied/extended, or wants it tested broadly across symbols. Trigger proactively whenever a compiled-only .ex4/.ex5 with no accompanying source shows up as the subject of analysis.
---

# Locked EA Analyzer

Behavioral reverse-engineering of a closed-source EA — never its code, only what it legitimately
exposes: saved presets, tester logs, its own printed input dump, and public vendor info. Everything
here is accessible to any owner via the MT4/5 GUI already; this skill just does it systematically.

## Legal/IP boundary — hold this for the whole session
Never attempt to decompile or crack a protected file. All analysis is behavioral. If the user wants to
"build on" a locked EA, the deliverable is an ORIGINAL EA inspired by the observed principle, built
fresh through `strategy-and-risk` → `mql-code-generator` — never a literal source clone. If the observed
behavior combines multiple high-risk mechanisms, apply `strategy-and-risk`'s own L1–L5 risk-combination
rubric transparently (Grid+Martingale+Hedge = L5 = REFUSE) and redesign down to an allowed level rather
than reproducing the risky combination as-is.

## Workflow

### 1. Confirm it's actually protected
Extract strings from the binary before assuming decompile is off the table:
```powershell
$bytes = [System.IO.File]::ReadAllBytes($path)
$ascii = [System.Text.Encoding]::ASCII.GetString($bytes)
$utf16 = [System.Text.Encoding]::Unicode.GetString($bytes)
# regex [\x20-\x7E]{4,} on both — high-entropy noise, zero readable strings = genuinely
# encrypted/obfuscated. Plaintext strings present = normally compiled, not specially
# protected — but still don't decompile logic; behavioral analysis is still the right approach.
```

### 2. Never trust "it's locked" from one earlier test alone
A prior NO_REPORT/SKIP from headless backtesting may be a broker/account license mismatch, not a
categorical block. Re-test under the CURRENT active login before concluding it can't be backtested.
Check `tester\logs\<date>.log` for "loaded successfully" / order open-close lines from ANY recent
run (even a different session) as evidence it runs in Strategy Tester when authorized.

### 3. Recover ground-truth parameters without decompiling
Three plaintext sources exist even for protected EAs:
- Saved `.set` preset under `MQL4/Presets/` or `MQL5/Presets/`
- `tester/<ExpertName>.ini` if a manual optimization was ever set up (`,F=`/`,1=`/`,2=`/`,3=` ranges
  hint which params the user already considered worth tuning)
- The Journal's own auto-printed `<EA> inputs: Param=val; Param=val; ...` line on every load

Cross-reference against what the user calls the parameters informally — confirm nickname-to-real-param
mapping EXPLICITLY with the user rather than guessing, and don't assume a nickname implies a hidden
parameter that isn't in the ground truth.

### 4. Infer the principle of operation from Journal behavior, not code
Entry mechanism (market/pending, single/dual-sided), how position count grows (grid spacing — fixed vs
tiered), lot-sizing pattern order-to-order (fit qualitatively: fixed/linear/geometric/hybrid — don't
over-fit an exact formula from a handful of points, flag it needs numeric fitting if precision matters),
exit mechanism (single-order vs whole-basket — grep for multiple close lines sharing one timestamp as
the tell for basket-level exit).

**When building an ORIGINAL EA from the inferred principle — the recipe is load-bearing, don't
"improve" it blindly.** A survivor's edge often depends on the exact recipe that looks like its
*weakness*. RSI-from-pips passed every gate WITH no stop loss + fixed-pip spacing + per-position
virtual TP + linear lot. Our rebuild "improved" all four at once (real SL + ATR spacing + basket-$
exit + LOG lot) and lost the cross-regime edge — the safety we added was exactly what made the
original robust across regimes (it held through drawdown instead of realizing the stop). Lesson: when
reproducing a survivor, change **one thing at a time** and re-validate, and treat every default you
inherit as a hypothesis with a cost, not a free improvement. Two self-inflicted traps we hit and you
should pre-empt: (1) we swapped linear lot for a near-flat LOG factor and prematurely declared the
rebuild "regime-dead" — it was a bad *parameter*, not a dead strategy (proper lot law → PF 2.6-3.0 in
the same window); (2) we then swept only 2 of ~6 parameter dimensions and again nearly concluded
before touching the grid-spacing lever the user had explicitly flagged. Enumerate every structural
lever (entry threshold, spacing, SL width, TP, lot law, symbol) and confirm which are actually swept
before writing any verdict — "PARKED/dead" claims are only as complete as the dimensions you moved.

**Signal-edge vs recovery-mechanics test (do this before believing any grid/martingale EA).**
A profitable grid can be profitable for two very different reasons: (a) a real entry edge the grid
merely harvests, or (b) pure averaging-down/martingale recovery that manufactures wins by increasing
size into drawdown. They look identical on the equity curve but only (a) is deployable. Separate them
by *neutralizing the lot escalation*: rebuild (or set) the lot law to FIXED/flat and re-run the same
window. PF holds → the signal has edge. PF collapses below 1 → the profit was recovery mechanics, the
"strategy" is just a martingale wearing a signal costume (confirmed both ways: FZ2 PF 3.05→0.36 when
its multiplier was zeroed = REJECT; RSI-from-pips kept its edge under a flat law = real signal). This
same test caught a false-alarm on our OWN rebuild — see build-side note in step 4.

### 5. Web-search the EA name before assuming it's unique
Cheap "free/cracked EA" sites frequently host the same binary — tells you it's likely not exclusive
even if paid for, gives a vendor-published description to cross-check your inference against, and
sometimes the original author has a blog/forum post (check mql5.com/en/blogs) with extra strategy
color and their own backtest caveats.

**Binary signature tell:** extract strings and look for a builder URL. `https://fxdreema.com` (or
similar no-code-builder signatures) present + otherwise-noise strings = the EA was assembled from that
builder's stock blocks, which (i) map 1:1 to the recovered input names, (ii) means it is almost
certainly not exclusive/proprietary, and (iii) lets you cross-check the mechanism against the builder's
public template library (e.g. fxDreema's "Grid RSI 900 PIP" template matched our recovered
`Lots_plus_at_pips=90` exactly).

### 6. Smoke-screen across symbols, then read the PATTERN not just the table
When testing across many symbols, a clean pattern by instrument volatility/style is often the real
finding (e.g. passes on low-vol range-bound pairs, rejects on trending/volatile instruments) — state
that pattern explicitly, it's more useful than the raw ranked table alone. Hand the batch execution to
the `ea-screener` subagent or a qwen batch; full single-EA rigor (optimize → IS/OOS → MC) goes through
`backtest-optimize-rigor` / `ea-optimization-orchestrator` / the `ea-validator` subagent as usual.

## Gotcha catalog (all confirmed firsthand, not theoretical)

- **Model 2 ("open prices") can badly misrepresent grid/martingale/basket-exit EAs.** No intrabar path
  simulated. Same params showed PF 0.65/DD 102% under Model 2 vs PF 0.87/DD 79% under Model 0 — same
  conclusion direction, but Model 2 overstated severity. Model 2/Open Prices is **diagnostic-only**; its PF/net/DD/trades cannot judge the first-pass broad screen or any strategy outcome. Use Model 1 / 1 Minute OHLC at minimum for the broad screen, and require frozen Model-4 MAIN+BWD before Candidate eligibility.
- **Headless run without an explicit `-SetFile` does not reliably mean "compiled defaults."** MT4/5 can
  silently carry over whatever params were LAST used on that terminal for that EA. Always pass a fully
  specified `.set` — never rely on omission to mean defaults.
- **MT4 headless/ini-triggered OPTIMIZATION can be silently non-functional** — a batch can "finish" N
  passes in seconds and discard all of them as "insignificant" (check the Journal for that exact
  phrase) without actually computing anything. Workaround: skip the built-in optimizer, run each combo
  as an individual single backtest instead (reliable), loop/delegate, aggregate to CSV. Sanity-check
  one combo standalone before trusting a big batch.
- **Reconcile against the user's live experience, don't just report a backtest number.** If a backtest
  shows materially worse than live experience, check WHEN in the backtest window the stress event
  occurred (grep Journal for "Stop Out" / stress markers + simulated date) against how long the user
  has actually traded live. Stress concentrated before their live start isn't a contradiction — it
  means their live sample hasn't hit that regime yet, which is itself a forward-looking risk finding
  worth stating explicitly (surviving N months isn't evidence of safety against a regime not yet faced).

## Handoff map
| Need | Skill/subagent |
|---|---|
| Full IS/OOS/MC rigor on the winning symbol/config | `backtest-optimize-rigor`, `ea-optimization-orchestrator` |
| Broad symbol fan-out smoke screen | `ea-screener` subagent |
| Single-EA optimize→validate→verdict pipeline | `ea-validator` subagent |
| Design an original EA inspired by the observed principle | `strategy-and-risk` (apply its L1–L5 rubric) → `mql-code-generator` |
| Register the final verdict | `EA_SCORECARD_AND_REGISTRY.md` |


---

## 🔒 TECHNIQUES ADDED 2026-07-10 (จากเคส Gold_Kangaroo/Silver Kangaroo — ORDER-070)

1. **Journal inputs line = ground truth ฟรี**: MT4/MT5 tester พิมพ์ input ทั้งหมด+ค่า ตอนโหลด EA
   ทุกครั้ง — ได้ input list เต็มโดยไม่ต้องเปิด GUI/บันทึก .set
2. **Strings-extraction → product-family fingerprint**: ดึง string จาก .ex4/.ex5 (ไม่ใช่ decompile)
   → เจอ builder signature (เช่น fxdreema.com) + เอา**ชื่อ input** ไป web search — ชื่อ input คือ
   ลายนิ้วมือระบุตระกูลสินค้าแม่นมาก (จับ Gold Kangaroo = Silver Kangaroo family ได้ด้วยวิธีนี้)
3. **Flat-lot probe กับตัว locked**: ถ้า multiplier/escalation เป็น input → ปิดแล้วรัน = แยก entry-edge
   จาก recovery-illusion ได้โดยไม่ต้องมี source (Kangaroo flat 5.71 > ladder 4.86 = เขียวจริง)
4. **Crack/redistribution check**: ถ้า web search เจอเว็บแจก "unlimited version" หลายเจ้า → copy ที่มี
   เกือบแน่ว่า crack → นโยบายแล็บ: ห้ามรันเงินจริง (security-DQ) — เส้นทางที่ถูกคือ rebuild-inspired
5. **ระวังสมมุติฐานจาก marketing**: "cap 10 ไม้" โฆษณา ≠ นับจริงจาก log (เจอ 14) · "TP 160 pips" อาจเป็น
   pip-sum ไม่ถ่วง lot ที่ยอมปิดขาดทุนสุทธิ (= DD-release แฝง) — ทุก claim ต้องนับจากไม้จริง