# EXPERIMENT EVENT LOG — ADOPTION GUIDE (ORDER-115)

> How a session actually uses the Contract-D event log (`scripts/experiment_event_log.ps1`).
> **Rule owner = the schemas** (`docs/memory_control/experiment_events/schema/*.json`, incl.
> `x-ea-lab-rules`) + §20.7 @ `4eb839d` — this guide is workflow only and duplicates no rule tables.
> Full behavioral history = `CODEX_ORDER105_RESULT.md` (8 blind review rounds).

## 1. When to emit events

- **Experiment-shaped orders** (EA test / optimize / validate / funnel) closed after 2026-07-17:
  emit the chain below. Per §20.3, this is the default for new work.
- Mechanical/infra/doc orders: no events (they are not experiments).
- **Backfill is forbidden** except the 3 approved historical canaries — **ST03 · Boss_16 ·
  ORDER-095/Boss_14** — and each only when that work is next picked up again (§20.3), one experiment
  chain at a time. No bulk backfill, ever.

## 2. The chain (one experiment = one `exp_*` id, events linked by `prior_event_id`)

`IDEA_CREATED → HYPOTHESIS_REGISTERED → BAR_PREREGISTERED → RUN_STARTED → RESULT_LINKED →
REVIEW_LINKED → DECISION_LINKED` — strictly in order; the utility rejects out-of-order or non-tail
appends (`stale_prior`). Corrections after the fact: `AMENDMENT_ADDED` (logical fix; the ONLY way to
change a preregistered bar) or `TOMBSTONE_ADDED` (invalidate an occurrence). Never edit a JSONL line.

**What events store: occurrence metadata + hashes + owner references ONLY.** Result/verdict text
lives with its canonical owner (taskboard/scorecard/PROJECT_STATE/DEPLOYMENTS.csv); the schema
fail-closes on forbidden prose fields. The event answers "when/who/what-inputs/where-is-the-owner",
never "what happened".

## 3. Commands (all writes go through the utility — never touch the JSONL directly)

```powershell
# 1) mint ids (once per experiment for exp_, once per event for evt_)
powershell -NoProfile -File scripts\experiment_event_log.ps1 -Command NewEventId

# 2) build the request JSON (canonical field order = x-ea-lab-rules.canonical_order).
#    owner_refs pin the owner file AT A COMMIT — use the utility's own helper (single rule source),
#    do NOT hand-roll blob hashing (PowerShell pipelines mangle raw bytes):
. scripts\experiment_event_log.ps1 -RepoRoot D:\EA_LAB     # dot-source loads helpers, runs nothing
$commit = (git rev-parse HEAD).Trim()
$rec = Get-CommittedBlobRecord -Root D:\EA_LAB -Commit $commit -Path 'AGENT_TASKBOARD.md' -Anchor 'ORDER-1xx' -RequireAnchor
#    -> $rec.BlobOid + $rec.RawSha256; anchor must literally EXIST in that blob or this throws

# 3) append (validates schema + chain + owners + evidence, atomic, locked)
powershell -NoProfile -File scripts\experiment_event_log.ps1 -Command Append -EventJsonPath req.json

# evidence first commit the artifact to git, then either:
powershell -NoProfile -File scripts\experiment_event_log.ps1 -Command RegisterEvidence -ArtifactPath path\to\file -CommitOid <sha> -MediaType text/csv
#    or atomically together with the referencing event: Append -RegisterEvidencePath ... -RegisterEvidenceCommitOid ...
#    evidence_ids = 'evd_sha256_<raw sha256>' — committed Git artifacts only (no transient paths)

# validate everything
powershell -NoProfile -File scripts\experiment_event_log.ps1 -Command Scan
```

The pre-commit hook (`[experiment-events]` → `check_experiment_events.ps1`) re-validates the staged
snapshot fail-closed, so a bad event cannot be committed even if hand-crafted.

## 4. Worked IDEA_CREATED example (verified end-to-end 2026-07-17 in a temp fixture — append `appended`, scan valid)

```powershell
$ErrorActionPreference='Stop'
# ids: the NewEventId status line is JSON
$ids = (powershell -NoProfile -File scripts\experiment_event_log.ps1 -Command NewEventId |
        Select-String '"status"').Line | ConvertFrom-Json

# owner ref via the utility's own helper
. scripts\experiment_event_log.ps1 -RepoRoot D:\EA_LAB
$commit = (git rev-parse HEAD).Trim()
$rec = Get-CommittedBlobRecord -Root D:\EA_LAB -Commit $commit -Path 'AGENT_TASKBOARD.md' -Anchor 'ORDER-1xx' -RequireAnchor

$req = [ordered]@{
  schema_version=1; event_id=$ids.details.event_id; experiment_id=$ids.details.experiment_id
  event_type='IDEA_CREATED'; actor='claude'; role='lead_judge'
  prior_event_id=$null; prior_event_sha256=$null
  artifact_hashes=[ordered]@{ea=$null;source=$null;set=$null;data=$null;tester=$null}
  trial_family=$null; trial_count=$null; evidence_ids=@()
  owner_refs=@([ordered]@{owner_type='taskboard_order';path='AGENT_TASKBOARD.md';commit_oid=$commit;blob_oid=$rec.BlobOid;raw_sha256=$rec.RawSha256;anchor='ORDER-1xx'})
  reason_code='experiment_initiated'; reason_ref='ORDER-1xx'
}
[IO.File]::WriteAllText("$pwd\req.json",($req|ConvertTo-Json -Depth 10 -Compress),(New-Object Text.UTF8Encoding($false)))
powershell -NoProfile -File scripts\experiment_event_log.ps1 -Command Append -EventJsonPath req.json
powershell -NoProfile -File scripts\experiment_event_log.ps1 -Command Scan
```

For the NEXT event in the chain, set `prior_event_id` to the previous event's id and
`prior_event_sha256` to that event's canonical line hash (read it back via a `Scan`-validated
snapshot or keep the append responses); the utility rejects any wrong/non-tail prior.

Requirements that trip people (rule owner = schema; listed here as pointers only): actor↔role pairs
are pinned (`claude`=`lead_judge`, `codex`=`peer_engineer`, `zcode`=`batch_runner`, `user`=`owner`) ·
`reason_ref` must match `^(ORDER|ADR|EXP|RUN)-…` · `artifact_hashes` become required progressively
(`source` at HYPOTHESIS, all five from BAR_PREREGISTERED on) · `RESULT_LINKED`/`REVIEW_LINKED` need
≥1 evidence id · `DECISION_LINKED` only by `user`/`claude` with a scorecard/PROJECT_STATE/DEPLOYMENTS
owner_ref · timestamps are utility-assigned UTC (monotonic per file, no backdating past a rotated month).

## 5. Iron rules (from §20.7 + Contract D — repeated because they are cheap to violate)

1. Every write via the utility. No direct JSONL edits — corrections = `AMENDMENT_ADDED`/`TOMBSTONE_ADDED`.
2. No result/verdict prose in events. Owner files own the words; events own hashes + refs.
3. Preregistered bar is immutable — changing it = `AMENDMENT_ADDED` with the new bar's owner ref.
4. Evidence = committed Git artifacts (resolve at commit+blob+raw sha256). Ignored/transient paths are rejected.
5. No backfill outside the 3 canaries. The log starts living with the next real experiment.
6. `Disable`/`Enable`/`Recover` need explicit authorization refs — physical recovery is a locked,
   quarantined state machine; never hand-repair a corrupt month.

## 6. Rough edges found in dogfood #1 (ORDER-091C-D1g, exp_93d9457a — first real experiment)

Hard-won gotchas so the next experiment doesn't rediscover them. Rule owner is still the schema/util;
these are workflow patches.

**Artifacts & evidence**
- **`data` has no git artifact (MT5 tick history isn't committable).** Write a small committed
  *data-provenance descriptor* (symbol·TF·window·model·server) and use ITS sha256 for `data`. Template:
  `_triage/ORDER091C_D1G_DATA_PROVENANCE.md`.
- **`ea` (the .ex5) and other binaries are gitignored, yet `ea` must be a registered evidence artifact
  (= committed blob).** Force-commit the exact tested binary: `git add -f <path>.ex5`. Verify it's
  byte-identical to what the tester actually ran (sha256) before trusting the hash.
- **Evidence `path` pattern forbids parens and spaces** — the repo's `(EXP)_Name/(EXP)_Name.mq5|.ex5`
  filenames can't be registered directly. Stage **paren-free copies** at a clean path (e.g.
  `_mt5_auto/ab_sets/<order>/Name.mq5`) and register those.
- **Multi-arm A/B → one artifact hash.** An experiment with several .set/.ini arms still has ONE
  `set`/`tester` slot per event. Pick a **canonical treatment set** + a **canonical tester-config file**
  (`D1G_tester_canonical.ini`) for the hashes; per-arm variations live in the taskboard/results-CSV owner,
  not the event.
- **Evidence is content-keyed but stores `commit_oid`.** Registering the SAME content again after HEAD
  moved (unrelated commits) → `reference_invalid: different canonical locator`. **Register each artifact
  once**; on re-runs, reuse the known `raw_sha256` (don't re-register). Pin `-CommitOid` to a **full
  40-hex** sha (short form is rejected).

**Owner anchors**
- **Anchor must occur EXACTLY once in the blob, and can't contain spaces.** Order IDs repeated in the
  body break this — a commit-tag line (`` `[tag] ORDER-...` ``), a `### ORDER-... RESULT` subheader, etc.
  Keep the bare ID **once** (the header); reference it elsewhere as the short form (`D1g`).
- Owner-file edits move the blob, so re-derive `blob_oid/raw_sha256` at the current commit each event
  (the util's `Get-CommittedBlobRecord` does this).

**Chaining & tooling**
- **`prior_event_sha256` is not exposed by `Append`/`Scan` output.** Compute it: read the month JSONL,
  take the last line's bytes **excluding the trailing LF**, sha256 them. (Reusable helper `TailSha` /
  `LineShaOf` in `_mt5_auto/d1g_event_chain.ps1`.)
- **The util prints status to the console, not the PowerShell pipeline.** In-process `& $util` does NOT
  capture it — call the util as a **child process** (`& powershell -NoProfile -File $util ... | Out-String`)
  and regex the JSON out.
- **Amending a preregistered bar works and is cheap** — `AMENDMENT_ADDED` with `target_event_id` +
  `target_event_sha256` = the BAR event's line sha, `reason_code=logical_correction`. Used here to change
  Model-4→Model-1 (tooling constraint) *before* seeing results. Do the visible taskboard amendment too.

**Concurrency**
- Under a shared worktree, a commit can **race** (a path-limited commit landed a stale blob once). After
  any owner-file commit that an event will reference, **verify the committed blob** (`git cat-file blob
  HEAD:<path> | grep -c <anchor>`) before emitting the event.
