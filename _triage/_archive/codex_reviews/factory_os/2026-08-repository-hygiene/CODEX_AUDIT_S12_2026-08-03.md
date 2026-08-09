# Codex blind audit — Factory OS slice **S12** (Telegram Control Room + Morning Brief) — 2026-08-03

> Dispatched by lane `S-2026-08-03-AUDITCOV`, **pinned at commit `a87f7448`**, blind and read-only.
> Brief: [`CODEX_S12_AUDIT_BRIEF.md`](CODEX_S12_AUDIT_BRIEF.md), committed at `566772c5` **before**
> the audit ran.
>
> 🔴 **This is the first independent audit this slice's built code has ever had.**
>
> Every item in Part 1 was **re-measured independently by this seat after Codex raised it**, with a
> control where a control was possible. Part 2 keeps the unverified claims separate.
>
> **Nothing was sent.** No transport was constructed, no `--confirm` path was reached, and no real
> credential was read or printed. The one probe involving a secret used a synthetic literal invented
> inside the harness. Reproduction: `scratchpad/verify_s12.py` + `verify_s12b.py`.

---

## 🔴 Part 0 — the finding that is not really about S12, and is the most urgent thing in this file

### 0.1 ✅ VERIFIED — a **third party's** credential is in this repository's history, and it was pushed

Codex raised this against C2 (*"no token in git"*). Re-measured, and **it is worse than reported**:
Codex established that history was not rewritten. It did not establish where that history went.

```
git log --all -G'[0-9]{8,10}:[A-Za-z0-9_-]{35}'
  cc40731c  2026-07-10  ORDER-074 ... fxDreema X-ray parser + full-corpus cards
  c7d97b6a  2026-08-03  ORDER-1200 ... the third-party credential is gone
```

`cc40731c` added a Telegram-token-shaped string inside `_triage/FXDREEMA_XRAY.md` — a 47,186-line
card file generated from a **downloaded third-party EA corpus**. It is therefore **somebody else's
bot token**, harvested from someone else's EA and committed here. `c7d97b6a` (today, a different
lane) removed it from `HEAD`, and its commit message says so.

**What the redaction did not do:**

```
git merge-base --is-ancestor cc40731c origin/master   -> YES
                             ... origin/HEAD          -> YES
                             ... and 3 origin/claude/* branches
remote: https://github.com/BaBosss/EA_LAB.git
```

**The commit is an ancestor of `origin/master`.** Removing the string at HEAD does not remove it from
a pushed history; the blob remains reachable in every clone and on the remote.

**Two things are true at once and both should be said:**

- **S12's own token is not implicated.** The four token-shaped strings still in the tracked tree at
  this pin are all in test files (`run_s11_tests.py`, `run_s12_tests.py`, `run_s12_tests.ps1`) and
  are declared fixtures. Codex checked this and so did I; no project credential value was opened.
- **C2's literal claim — "no token in git" — is refuted by history**, and the exposure is a real
  third party's, which makes it not only a hygiene problem.

**This is a handover item and it is not a code fix.** Whether that GitHub repository is public I did
not probe and will not; the remedy (history rewrite, credential revocation notice, or acceptance)
is the owner's call, and it needs to be made knowing the commit was pushed.

---

## Part 1 — VERIFIED against the committed bytes

### 1.1 🔴 CRITICAL — a finding that **reopens** after a genuine recovery is never alerted again

`notifier.py:432-464` (`dedupe_key`) · `:811-813` (`Ledger.delivered`) · `:865-869` (`deliver`).

`Ledger.delivered()` returns the set of every `(dedupe_key, channel)` ever marked `DELIVERED`, **with
no time bound** — it is the whole history. `dedupe_key` for a non-`FLAPPING` state is
`public_id|state|severity|material_revision`. So `OPEN → … → RESOLVED → OPEN` with unchanged payload
and severity produces **the same key** as the first incident, which is permanently in the delivered
set.

**Measured:**

```
first incident key = X|OPEN|CRITICAL|1
reopened      key = X|OPEN|CRITICAL|1        identical
ledger.delivered() time bound? none -- the whole history
deliver(reopened alert, 11 months later) -> outcome=SUPPRESSED_DUPLICATE, problems=0
```

**Control** — the same finding escalated `CRITICAL → REAL_MONEY` is `DELIVERED`, so the dedupe key is
live and doing the job it was rewritten for.

**Consequence.** The alert never arrives, **and the run does not count it as a problem** (`problems=0`),
so the exit code stays clean and the daily chain stays green. The same shape swallows a repeating
severity cycle (`CRITICAL → WARN → CRITICAL`) at unchanged state and revision.

This is the exact failure design §7.3 rev 1 was rewritten to prevent, displaced one axis over: rev 1
suppressed an **escalation**; the fix added `severity` and `material_revision` and closed that. It
did not close **recurrence**, because the ledger is a permanent set rather than an
incident-scoped one.

### 1.2 🔴 CRITICAL — the secret guard blocks the wire and then prints the secret it caught

`safe_projection.py:233-235` · `notifier.py:643-647` (`assert_sendable`) · `notifier.py` `main()`.

`scan_forbidden()` builds its `KNOWN_SECRET` hit as
`'carries a literal taken from the full snapshot: %s' % secret` — **the literal value is in the
diagnostic**. `assert_sendable()` joins those hits into a `ProjectionLeak` message.

**Measured**, with a well-formed `AlertEvent` and a synthetic account number (first attempt failed
the SHAPE layer and proved nothing; rebuilt so the literal layer is actually under test):

```
assert_sendable raised ProjectionLeak   (so the send IS blocked -- C8 holds)
secret present in the exception text?   True
  "the planned alerts carry 1 forbidden item(s): $[0].text [KNOWN_SECRET]
   carries a literal taken from the full snapshot: <SECRET-WAS-HERE>"
```

`main()` **does not mention `ProjectionLeak` at all**, so it is not a handled path — the exception
propagates as an uncaught traceback, and the CLI is invoked by `daily_monitor.ps1`, which appends
child output to a log file.

**Consequence.** C8 works: the value never reaches Telegram. It reaches the **console and the daily
log** instead, which is three of the four surfaces design §10's prohibition names (*"git / logs /
generated HTML / chat"*). The guard's success path is safe and its **failure path is the leak**.

**And the same fix is already present one function away, which is what makes this a defect rather
than a design choice:** `safe_detail()` at `:825-846` deliberately reports **only the rule name**
(`h[1]`), for exactly this reason, and its docstring explains it. `assert_sendable` interpolates all
three elements.

### 1.3 🟠 HIGH — `safe_detail()` cannot see the secrets it exists to catch

`notifier.py:841` — `safe_projection.scan_forbidden([str(text)])`, called with **no
`known_secrets`**.

`scan_forbidden` has three layers; the `KNOWN_SECRET` layer iterates a list that is empty on this
call, so only `VALUE_SHAPE` rules can fire.

**Measured:**

```
safe_detail('boom 50391234567') -> 'boom 50391234567'      (unchanged)
secret present? True
```

The docstring is honest — it says *"the same **value-shape** rules the projection uses"* — so this is
not a false claim. It is the **`prohibition-disarms-its-own-check` shape**: the layer that catches an
account number typed into an allowed field has no input at the one boundary that writes to the
ledger file. A transport exception carrying a bare account number or numeric chat id is written to
`ops/delivery_ledger.jsonl` verbatim. Canonical bot-token shapes **are** caught; bare numeric
delivery credentials are not.

### 1.4 🟠 HIGH — the "hard seam" is a call-order convention, not an invariant

`notifier.py:849-889` (`deliver`) · `:1091` (`PUBLIC_API`).

**Measured:**

```
deliver is in PUBLIC_API?           True
deliver calls assert_sendable?      False
deliver calls scan_forbidden?       False
deliver sends ev['text'] directly?  True
```

The module docstring's seam — *"It cannot leak what it was never handed"* — holds for the **CLI**,
which calls `assert_sendable()` first. It does not hold for the **module interface**, which declares
`deliver()` public and lets any caller hand it a constructed event whose free-form `text` is sent
unscanned.

`imports_of()` cannot cover this either: `io`, `os`, `subprocess` and `snapshot_validator` are
already in `ALLOWED_IMPORTS`, so an AST import allowlist proves the *declared* closure, not
non-reachability.

### 1.5 🟠 HIGH — one torn line in the ledger or journal stops **every** later alert

`notifier.py:801-808` (`Ledger.load`) and the journal reader.

Both apply unguarded `json.loads()` to every line.

**Measured** — a ledger whose last line is truncated mid-write:

```
Ledger.load -> JSONDecodeError: Unterminated string starting at: line 1 column 40
```

The exception is raised **before any delivery decision is made**, so nothing is planned, nothing is
sent, and nothing is recorded about why. Power loss, process kill, disk exhaustion or a concurrent
append all produce a partial last line, and these are append-only runtime files written by a
scheduled job on a workstation that hibernates.

### 1.6 🟠 HIGH — a missing credential is logged as a NOTE and the chain stays green

`notifier.py:870-877` (exit 4 / `UNCONFIGURED`) · `scripts/daily_monitor.ps1:95-99`.

```powershell
if ($notifyExit -eq 4) {
    "NOTE: a Telegram channel is not configured yet ... deliberately NOT marking the chain
     unhealthy (ORDER-219 rule: a daily red gets muted)." | Add-Content $log
}
```

The rationale is stated and it is a real one — a permanently-red daily check gets ignored. But
**exit 4 carries one meaning for two very different situations**: *"Control Room is not provisioned
yet"* and *"the established EMERGENCY credential has disappeared"*. The second is a fleet that has
gone silent on `CRITICAL` and `REAL_MONEY`, reported as a NOTE.

`notifier.py` is right that `UNCONFIGURED` is *"a stated failure, not a silent skip"* — the statement
is made, and then the integration deliberately discards it. Neither half is wrong on its own; the
pair is.

---

## Part 2 — Reported by Codex, **NOT independently verified**

| # | Sev | Claim | why unverified |
|---|---|---|---|
| 2.1 | 🟠 | **`probe --id` can send and persist an account number or chat id.** A numeric value supplied as the probe id is copied into the message *and* into `dedupe_key`, which is persisted to the ledger. Probe mode deliberately uses `secrets=()`. | Reproduction requires the forbidden `probe --confirm` transport path. Consistent with 1.3's measured mechanism. |
| 2.2 | 🟠 | **B1 can stay green while a credential enters the next commit.** `run_s12_tests.ps1:110` — `git grep` without `--cached` (staged-but-not-in-worktree), `*.jsonl` and `_triage/chatgpt_convs/*` excluded, a permissive `99` matching-line ceiling where the comments describe exact closed counts, and `git grep -c` counting **lines** not occurrences. | Mutation would require repository writes. **Given Part 0, this is the item most worth settling** — B1 is the guard that is supposed to make "no token in git" checkable. |
| 2.3 | 🟠 | **FLAPPING prevents its own two-check recovery.** `control_center.py:666` — the FLAPPING test runs *before* the two-check recovery rule, so a finding at three recurrences that then goes healthy twice stays FLAPPING until the recurrences age out. | Not re-measured. |
| 2.4 | 🟠 | **FLAPPING reminders become permanent silence after 24h.** Once earlier appearances age out of the recurrence window, state recomputes as `OPEN` — a key already delivered before FLAPPING, therefore suppressed forever. Same root as 1.1. | Not re-measured; mechanism is the one 1.1 confirms. |
| 2.5 | 🔴 | **A transient alert that first fails is never queued for retry.** The failed run still appends the `OPEN` observation to the journal; the next observation becomes a silent `HEALTHY_1_OF_2`, and a later run may send a *recovery* for an incident that was never delivered. Cases L04/L10 retry the retained event but never re-run `observe()`. | No permitted fixture-free command constructs the sequence. |
| 2.6 | 🟡 | **An unchanged fleet gets only its first Morning Brief.** `compute_build_id()` excludes generation time by design, so unchanged evidence keeps one build id; the brief key is `BRIEF\|build_id`, already delivered. | Not re-measured. Note this one is arguably correct behaviour for a *brief* and a defect for a *daily* brief — worth an owner decision rather than a fix. |
| 2.7 | 🟡 | **Failure details and receipts do not enforce "never a chat id"**, and a URL-encoded or split token defeats exact replacement in `scrub()` and the canonical-token regex. | Partially covered: 1.3 measures the `safe_detail` half. The split/encoded-token half is not measured. |

**Claims that resisted attack.** C9 (no threshold computed — `dd_pct_band` is passed through, never
derived) survived. C3 holds **for the first one-way severity change** — which is what it was built
for, and 1.1 is the case it does not cover. C6 (OpenClaw not in the path) holds for current runtime
behaviour, with the caveat in 1.4 about what an AST allowlist can prove.

---

## Part 3 — Executed checks

| | |
|---|---|
| `run_s12_tests.py --list` | 66 cases |
| `run_s12_tests.py` | attempted; **11 tempfile-dependent cases could not run** in the auditor's read-only sandbox. Environmental, not S12 evidence — this file does not claim the suite passed |
| `scripts/_test/run_s12_tests.ps1` | attempted; blocked by the machine's script execution policy in the auditor's context |
| this seat's re-measurement | `scratchpad/verify_s12.py` + `verify_s12b.py` — probes 1.1 · 1.2 · 1.3 · 1.4 · 1.5, with controls |
| git history probe | ancestry only; **no credential value was opened, printed or reconstructed** |

`ops/delivery_ledger.jsonl` and `ops/finding_journal.jsonl` **do not exist at the pinned commit**, by
design (`B2` keeps runtime state out of git). One consequence should be recorded plainly: the
*"one real message delivered by hand"* receipt cited by `ORDER-1180` has **no independently
checkable committed evidence**. That is a limit of the arrangement, not a claim that it did not
happen.

---

## Part 4 — What this changes about the slice's own acceptance

| design §10 acceptance | status after this audit |
|---|---|
| alerts work with OpenClaw stopped | **holds** (C6) |
| dedupe key includes severity + material revision | **holds** — and 1.1 shows the key is not the whole dedupe: the ledger's unbounded delivered-set is |
| per-channel delivery ledger | **exists**; 1.5 shows one torn line disables it and everything downstream |
| one recovery message | **holds** for the tested path; 2.3/2.5 are unverified challenges to it |
| escalation is never swallowed | **holds for escalation, fails for recurrence** (1.1, measured with a control) |
| 🚫 no token in git/log/HTML/chat | **git: refuted** (0.1, third-party credential, pushed) · **log: refuted** (1.2, 1.3) · chat/HTML: not challenged |
| 🚫 OpenClaw not in the path | **holds** |
