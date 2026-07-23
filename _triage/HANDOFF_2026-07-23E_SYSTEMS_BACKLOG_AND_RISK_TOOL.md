# HANDOFF — 2026-07-23E (systems-backlog session, context full, handing off)

> Companion to `HANDOFF_2026-07-23D_TESTER_NONDETERMINISM_CLOSE.md` (a concurrent session's EA-verdict
> side of today — RSI-MR/MacdDiv/TrendRider/SS4/SS1 re-validation). **Read both** — same day, two
> parallel threads, several shared discoveries (the MT5 tester-cache bug was found independently by
> both sessions within the same hour and cross-validated).

## What this session actually was

Started as "review the Codex-proposed EA_CORE_TEMPLATE_WORKPLAN" → became "clear ROADMAP §3
systems/infra backlog" (ORDER-152 onward, explicitly NOT EA-verdict work) → **accidentally discovered
the tester input-cache + leverage bugs while working on unrelated backlog items** → most of the
session's remaining hours went into that discovery chain and its fallout (re-validation cross-checks,
a portfolio-risk-admission tool built from scratch, then two rounds of adversarial audit against it).

## Commits this session (chronological, `c6d431f` → `575e6be`, ~16 commits)

Doctrine/hygiene: `c6d431f`/`733c1db`/`4095ce9`/`739a226` (ORDER-152–160: AGENTS.md Codex-routing fix,
`expectations.csv` built, workplan rev-B, multi-account combiner, walk-forward tool, hedge/recovery
harness, Recovery-mode "(stub)" mislabel fix). `0762b12`/`52e9fcd`(mislabeled, see below)/`c8bb67e`
(ORDER-163/164: dependency audit clean, 177-param registry). `a39226a` (ORDER-162 tester-drift finding
opened). `447952d` (ORDER-171/172 MacroGate + Boss_14 cross-check, Codex ORDER-154 audit landed).
`2a5fdcc` (ORDER-170 first fix pass). `068cfda` (ORDER-169 judge-criteria reconciliation). `d5ceb18`
(DD95 backfill + ORDER-174 opened). `575e6be` (ORDER-170 re-audit round 2, also **mis-swept SS1
LondonORB files from a concurrent session** — see Known Issues below).

## 🔴 Open work, in priority order

### 1. ORDER-170 — portfolio_risk_admission.py fix round 3 (NOT closed)

Two audit rounds have each found real defects in the fix, including ones I introduced while fixing the
prior round. **Do not self-verify a third time.** Current state: `scripts/portfolio_risk_admission.py`
has 4/8 claimed fixes VERIFIED, 4 NOT VERIFIED, plus new bugs. Full detail:
`_triage/CODEX_ORDER170_RISK_ADMISSION_REAUDIT.md`. Fix these 3 SEV-1 first:
1. `build_report()`'s admission-demo path rebuilds `active_known` without basket metadata and calls
   `admit_candidate()` raw — basket collapse never reaches the admission decision, only the account
   summary. `admit_candidate()` needs a basket-aware signature or a pre-collapsed input.
2. `collapse_basket_risk_units()` keys by raw `basket_id`-or-`magic` string with no namespace
   separation — a `basket_id` colliding with an unrelated `magic` would wrongly merge two risk units.
   Needs a namespaced key (e.g. prefix basket keys distinctly from magic keys).
3. `ADMIT_REDUCED` checks the post-floor budget (upper bound) but never re-validates the full
   `max(DD95) <= est <= sum(DD95)` invariant on the emitted point — a negative correlation can emit a
   value below the lower bound. Route the final emitted point through `portfolio_dd_est()` itself
   rather than hand-rolled arithmetic, same fix pattern as SEV-1 #5 from round 1.
Also worth closing while in there (SEV-2, cheaper): nan/inf P&L values bypass the `CORRUPT` sentinel
(Python's `float()` accepts them) — add an `isfinite` check in `_num()`. `admit_candidate()` should
validate its own numeric inputs instead of trusting callers. The self-test suite needs mutation-style
tests for the admission path specifically (Codex proved the type/finite guard inside `portfolio_dd_est`
has zero regression coverage by removing it and still getting 11/11 PASS).

**After fixing: THIRD blind audit required before REVIEWED.** Codex CLI direct (not the Agent-tool
dispatch — it stalled/detached twice today, see Known Issues) worked once the user ran it manually.
Model in use: `gpt-5.6-sol`, `model_reasoning_effort=high` (from `~/.codex/config.toml`).

### 2. ORDER-174 — correlation is never actually measured (blocks ORDER-170's real-world usefulness)

`scripts/portfolio_risk_admission.py`'s `compute_corr_matrix()` reads `portfolio/live_deals/` only. The
ORDER-154 DESIGN (see `AGENT_TASKBOARD.md`, full original text, not just the taskboard's own
abridgment) specified correlation from `_mt5_auto/corr_monthly.py`, which parses **backtest reports**.
Because the current cohort only has ~1 month of live data (need 4 minimum), **every pair correlation
falls back to the 1.0 default**, so `portfolio_dd_est` for every account collapses to a naive sum —
right now 463666728 reads 87.39% and 415573666 reads 56.20% against a 25% budget. **These are
worst-case ceilings, not risk estimates — do not use them to pull or resize any EA until this is
fixed.** Fix: extend `compute_corr_matrix()` to also accept backtest-derived correlation (reuse
`_mt5_auto/corr_monthly.py` / `scripts/corr_matrix.py`, don't rewrite), live wins over backtest when
both exist, and the report must show which quality tier backed each pair. **Do not start this until
ORDER-170 closes — same file, avoid the two colliding.**

### 3. DD95 backfill remainder

17/48 magics filled this session (see `portfolio/expectations.csv`), derived from the *fresh*
full-pinned reports produced during today's re-validation (not the old cache-polluted evidence — that
distinction matters, see the tester-cache lesson below). Still UNKNOWN: MT4 cent-account EAs
(deliberately out of scope — different toolchain, lab doesn't certify those accounts), the dead ST03
family, blank-magic UNVERIFIED rows, IchiADX basket siblings (correctly — DD95 lives on the primary
leg only). Not urgent, but feeds directly into ORDER-170/174's usefulness.

## Lessons this session paid for (read before repeating them)

**Git index races are real, not theoretical — happened 3+ times.** Two sessions writing
`git add`/`git commit` against the same shared working tree during a slow (~2-3min) pre-commit hook can
interleave: a commit can land with one session's message but another session's staged content
(`52e9fcd`), or sweep in unrelated files that happened to be staged at execution time (`575e6be` picked
up a concurrent session's SS1 LondonORB deploy files — legitimate work, just mis-attributed under this
session's commit message; nothing lost, just document it if you notice one). **Mitigation that
actually worked:** run `git diff --cached --stat` immediately before every `git commit` call, not just
after `git add` — but even that has a race window, so also check the resulting commit's file list
against what you intended right after. If it doesn't match, that's not a crisis, just add a short
provenance-correction note wherever the taskboard/PROJECT_STATE references that commit.

**Order-number collisions happened twice** (ORDER-152 claimed by two unrelated pieces of work
simultaneously; ORDER-166–169 likewise) — always re-check `grep -oE "^## ORDER-[0-9]+" AGENT_TASKBOARD.md
| grep -oE "[0-9]+" | sort -n | tail -3` for the TRUE current max immediately before opening a new
order, not the number you remember from earlier in the conversation.

**A specific `check_state.ps1` false positive bit me 3 times**: the Thai needle `ไฟล์เดียว` (part of the
single-source-of-truth guard) matches as a bare substring, so ordinary prose like "the exact same file"
in Thai can trip it even with no authority-claim intent. If `check_state.ps1 -Strict` reports
"competing entry claim" and you didn't write anything claiming canonical-source status, grep for
`ไฟล์เดียว` — it's almost certainly this false positive, not a real violation. Reword around it, don't
suppress the check.

**Background subagents stalled/detached without reporting at least 5 times today** (both my own
dispatches and, per the other session's handoff, theirs too) — see memory
`subagent-no-background-wait.md`, already updated with today's specific new failure mode (an MT5-batch
task, not just corpus scans). When a Codex re-audit via the Agent tool detaches without a report twice
in a row, stop retrying the same way — have the user run it directly via Codex CLI instead, which
worked immediately.

**The MT5 tester-cache bug (ORDER-165, see the other session's handoff for full detail) means: any
backtest report older than today's baseline re-pin should be treated with suspicion**, especially for
grid/stacking EAs run with a partial `.set`. Cross-reference `ea_template/regression_baseline.csv`
(re-pinned today) before trusting an old number that "looks weird."

## Ready-to-paste prompt for the next session

```
เปิดงานต่อจาก session ก่อนหน้า (2026-07-23, context เต็มแล้ว) — อ่านตามลำดับนี้ก่อนเริ่ม:

1. CLAUDE.md → PROJECT_STATE.md (ดู last-updated entry ล่าสุดของวันนี้)
2. AGENT_TASKBOARD.md — ไล่หา ORDER เลขสูงสุดจริงก่อนเปิดอะไรใหม่ (อย่าเดาจาก context เก่า)
3. _triage/HANDOFF_2026-07-23E_SYSTEMS_BACKLOG_AND_RISK_TOOL.md (ไฟล์นี้ — งานสาย infra/systems)
4. _triage/HANDOFF_2026-07-23D_TESTER_NONDETERMINISM_CLOSE.md (งานสาย EA-verdict คู่ขนาน วันเดียวกัน)

งานที่ค้างเรียงตามความสำคัญ:

1. **ORDER-170** (scripts/portfolio_risk_admission.py) — ยังไม่ปิด ผ่าน audit มา 2 รอบ เจอบั๊กจริงทั้ง
   2 รอบ (รอบ 2 เจอ SEV-1 ใหม่ 3 ข้อ อ่านรายละเอียดที่ _triage/CODEX_ORDER170_RISK_ADMISSION_REAUDIT.md)
   แก้ 3 SEV-1 ที่เหลือ (basket collapse ไม่ถึง admission path, basket_id/magic namespace ชนกันได้,
   ADMIT_REDUCED ไม่เช็ค lower bound ของค่าที่ emit จริง) แล้ว **ต้องส่ง blind audit รอบ 3** ก่อนปิด —
   ห้าม self-verify. ใช้ Codex CLI ตรงๆ (model gpt-5.6-sol จาก ~/.codex/config.toml) ไม่ใช่ Agent tool
   dispatch (หลุดไม่รายงาน 2 รอบมาแล้ววันนี้).

2. **ORDER-174** — ต่อ correlation ให้อ่านจาก backtest report ได้ (ไม่ใช่แค่ live_deals ที่ข้อมูลยังบาง
   เกินไป) ตาม design เดิมของ ORDER-154 ที่ระบุ _mt5_auto/corr_monthly.py — ทำหลัง ORDER-170 ปิดเท่านั้น
   (แตะไฟล์เดียวกัน). จนกว่าจะแก้ ตัวเลข portfolio_dd_est ปัจจุบัน (87.39%/56.20%) = เพดาน ไม่ใช่ค่าจริง
   ห้ามใช้ตัดสินใจถอด/ย่อ EA ใดๆ

3. อ่าน "Lessons this session paid for" ในไฟล์นี้ก่อนทำงานต่อ — โดยเฉพาะเรื่อง git index race
   (เช็ค git diff --cached --stat ก่อน commit ทุกครั้ง) และ false-positive checker (ไฟล์เดียว)

ห้าม: แตะ verdict ของ EA ใดๆ นอกเหนือจากที่ระบุไว้แล้วในบอร์ด, แก้ DEPLOYMENTS.csv/scorecard โดยไม่ผ่าน
VERDICT GATE, commit โดยไม่ได้ตรวจ staged diff ก่อน (index race เจอมาแล้ว 3 ครั้งวันนี้)
```
