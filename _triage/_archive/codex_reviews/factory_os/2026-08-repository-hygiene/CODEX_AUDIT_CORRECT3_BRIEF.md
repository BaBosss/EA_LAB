# Codex review brief — the `S-2026-08-04-CORRECT3` repairs (`ORDER-1269`, `ORDER-1267`)

> Written 2026-08-04 by the lane that made these changes. **You are the independent reviewer.**
> This is a review of MY OWN work in this repository, by its owner's request. Nothing here tells you
> what I concluded about correctness — only what I changed and what I claim. **Try to falsify the
> claims; do not restate them.**

---

## 0. Scope, and how to read it

Read-only. Do not edit, create, stage or commit anything. Do not write to `factory/`, `_triage/`
or `.git/`. Your deliverable is a report on stdout.

The eleven commits under review, oldest first:

```
633a6414  reserve the lane
d65763d3  disclose a commit-hygiene error (read this one; it is part of the review)
e272a34b  ORDER-1269 #3, FIRST FORM -- superseded by ddf3153f
ddf3153f  ORDER-1269 #1 + #3 reworked
929f3b18  ORDER-1269 limb 2: two checkers back onto the pre-commit path
6f52e6a2  board row for ORDER-1269
46b629f3  extend the lane's declared paths
446f7539  ORDER-1267 #1 + Part 2
13c175c1  board row for ORDER-1267
f78d30e0  handoff
7cc841dd  close the lane
```

```bash
git show <sha>                       # any single commit
git diff 826be53c 7cc841dd -- <path> # net effect; note another lane's commits interleave
```

⚠️ A second lane (`S-2026-08-04-S13E`) committed to this same branch throughout. Its commits are in
that range and are **not** mine — check authorship against the list above before attributing
anything.

## 1. What this work is, in one sentence

This repository builds an internal dashboard and notification pipeline for a personal algorithmic
trading lab. One component derives a **reduced, allowlist-only projection** of an internal status
document so that a chat-notification sender can render a daily summary **without** the operator's
broker account numbers, balances or position sizes travelling to a third-party messaging service.
The changes under review harden that data-minimisation boundary, plus an unrelated approval-record
subsystem.

**The stake.** These are guards. A guard that reports "checked, all clear" when it did not actually
run is worse than no guard, because it converts an unknown into a false assurance. Most of what you
are reviewing is exactly that failure mode, so the review question is nearly always *"can this check
still fail, and does it fail for the reason it says?"*

## 2. `ORDER-1267` — field-shape validation and recognizer coverage

Files: `_triage/factory_os/safe_projection.py`, `notifier.py`, `schemas.json`,
`run_schema_fixtures.py`, `run_s11_tests.py`, `run_s12_tests.py`.

**Claims to falsify:**

1. `scan_forbidden()` previously returned an identical empty result for *"the document is clean"*
   and *"I was given no recognizer list to compare against"*. The parameter now has three states —
   a populated list, an explicit `NO_KNOWN_SECRETS_AVAILABLE` declaration, and anything else empty
   which is now refused. **Is the sentinel reachable in a way that silently disables comparison?
   Is the refusal branch actually reachable, or has some caller made it dead?**
2. Comparison is now done on a normalised form (lowercased, non-alphanumerics removed) so that a
   value written with separators is still matched. **What does this normalisation cost?** The build
   path derives its comparison list from the source document, admitting any literal of 4+
   characters — I claim the false-positive rate is unchanged in practice because the suites and the
   real document still pass, which is weaker than a proof. **Construct a realistic document where
   normalisation causes a false refusal, if one exists.**
3. Dictionary *keys* are now compared as text, not only against a fixed name list.
4. `build_id` and `generated_at` were unconstrained strings in the schema and are now regex-
   constrained. I claim both patterns are derived from their producers
   (`snapshot_build.compute_build_id`, `scripts/control_room_snapshot.ps1`). **Verify that
   independently, and look for any other producer or historical value that these patterns would now
   reject.** A pattern that is too tight breaks a legitimate build.
5. The refusal message no longer restates the matched value; it reports length and last three
   characters. Test case `SP07` was inverted in the same commit and now asserts the value is
   **absent**. **Is the refusal still diagnosable from what it does print?**
6. A record of which comparison layers did not run is kept as module state (`LAYERS_NOT_RUN`) and
   printed by the CLI's `check` verb. It is deliberately not written to stderr — under the
   PowerShell wrappers, `$ErrorActionPreference='Stop'` turns any stderr from a child process into
   a thrown error. **Is module-level mutable state the right carrier here? It is not reset between
   calls except by the suites; find where that leaks.**

**Known gap, declared rather than hidden:** a value split across two separate fields is still not
matched. `SP16` asserts that gap is open. **Tell me if you think that assertion is the wrong shape.**

## 3. `ORDER-1269` — an approval record whose pin covered a growing store

Files: `_triage/factory_os/check_s2a_attestation.py`, `run_s2a_attestation_tests.py`,
`scripts/_test/run_s2a_cages.ps1`, `scripts/_test/run_fast_cages.ps1`, `.githooks/fast_tier_pathspec`.

Background you need: a migration table records, for each fact, which file owns it and a pin (a git
blob id) of that file's bytes at the moment the owner reviewed them. A separate append-only log
records the owner's decision, bound to a digest over a fixed bundle of files. When the pinned bytes
move, the checker demands a fresh acknowledgement from the owner.

**Claims to falsify:**

1. One row's pin points at the **destination** of a transfer that has already been executed, so the
   pinned file changing is the approved outcome rather than the record going out of date. That
   whole-blob check is now not enforced **for that row only**, and only when a section-scoped
   post-state claim on the current owner re-resolves successfully on the same run. **This is the
   riskiest change in the set: it is a guard being narrowed. Try to construct a document that gets
   the exemption without deserving it.** The predicate is `disposition == TRANSFER` **and**
   `owner_ref.path == proposed_owner`. I claim it selects exactly one of 29 rows — verify, and
   consider what a future row could look like.
2. `--template` routes through the same predicate so the owner-facing instructions and the checker
   cannot disagree. **Can they still disagree?**
3. A record that failed its own checks was printed as `APPROVED` four lines above its own failure.
   The demotion is applied at the **print** (`reported_decision()`), deliberately **not** to what
   `check()` returns, because the returned value is asserted by a conformance corpus that is itself
   inside the signed bundle — changing it would invalidate the owner's recorded decision.
   **Commit `e272a34b` is the version that did it the other way and is superseded by `ddf3153f`;
   both are in the range so you can see the difference. Was the correction the right call, or is
   the returned value now misleading to some future caller?** Enumerate the callers.
4. The per-row problem count is snapshotted so that an unrelated malformed line elsewhere in the log
   does not demote a record that verified. **Find an ordering where that snapshot is wrong.**

## 4. Test wiring and the time budget

`929f3b18` puts two checkers back onto the pre-commit path in a new wrapper
`scripts/_test/run_s2a_cages.ps1`, selected only by paths related to that subsystem.

- I claim neither entry writes to a tracked file (all writes go to `mkstemp` temporaries), which
  matters because two lanes commit concurrently here and a check that mutates a tracked file on the
  commit path is a data-loss path. **Verify by reading, not by trusting the header.**
- The declared trigger paths were produced by the repo's own dependency sweep. **Is anything these
  two entries read still undeclared?**
- Timings in the file header: the wrapper alone `7.82 / 7.61 / 8.11s`; the whole tier
  `97.5 / 98.4 / 95.5s` against a fixed 120.0s ceiling, up from a single sample of `88.1s`.
  **Re-derive with `-Timing` if you want; tell me if the "before" number being one sample rather
  than three undermines the comparison.**

## 5. The commit-hygiene error, which is in scope

`633a6414` carries about 128 lines of the other lane's board file. Cause: a malformed commit message
repaired with `git commit --amend` **without a pathspec**, which commits the whole index, while the
other lane had staged that file seconds earlier. I chose to disclose it (`d65763d3`) rather than
rewrite history, on the grounds that a rewrite on a branch tip another process is moving risks that
process's commit in order to fix an attribution line.

**Was that the right call?** If you think a safe repair existed, say exactly what it is and what it
would have risked.

## 6. What I would most like you to look for

Ranked, and this is where I think the risk actually is:

1. **§3 claim 1** — a narrowed guard is the easiest thing in this set to get wrong. If the exemption
   is reachable by a document that should not have it, that is the finding of the review.
2. **§2 claim 2** — I asserted a cost ("no new false refusals") from suites passing, which is not a
   measurement of the space.
3. **§2 claim 6** — process-global mutable state used as a reporting channel.
4. Anything in the new or modified test cases that **cannot fail**. Several cases were narrowed
   rather than deleted this session; a narrowed case that can no longer discriminate is silence
   wearing a green tick. Check that each new case fails when the code it covers is reverted.
